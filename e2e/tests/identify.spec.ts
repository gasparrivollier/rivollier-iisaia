import { expect, test, type APIRequestContext, type Page } from '@playwright/test';

import { registerViaApi, seedToken } from '../support/auth';
import { countRows, sql } from '../support/db';
import { byId } from '../support/flutter';
import { makePng } from '../support/images';
import { BACKEND_URL, FAKE_PLANTNET_URL } from '../support/urls';

const GOOD = makePng(1024, 1024);
const SMALL = makePng(100, 100);

async function identifyViaApi(request: APIRequestContext, token: string, buffer: Buffer) {
  return request.post(`${BACKEND_URL}/identify`, {
    headers: { Authorization: `Bearer ${token}` },
    multipart: { image: { name: 'p.png', mimeType: 'image/png', buffer } },
  });
}

async function forceNextPlantnetStatus(request: APIRequestContext, status: number) {
  const res = await request.post(`${FAKE_PLANTNET_URL}/_control/next-status`, { data: { status } });
  expect(res.ok()).toBeTruthy();
}

/** Signed-in browser on the Capture screen. */
async function openCapture(page: Page, token: string) {
  await seedToken(page, token);
  await page.goto('/');
  await expect(byId(page, 'diary-title')).toBeVisible();
  await byId(page, 'capture-fab').click();
  await expect(byId(page, 'pick-photo')).toBeVisible();
}

/** Clicks "choose photo" and answers the native file chooser with an in-memory PNG. */
async function choosePhoto(page: Page, buffer: Buffer, name = 'plant.png') {
  const [chooser] = await Promise.all([
    page.waitForEvent('filechooser'),
    byId(page, 'pick-photo').click(),
  ]);
  await chooser.setFiles({ name, mimeType: 'image/png', buffer });
}

test.describe('identify API', () => {
  test('a photo yields ranked results, a working image URL and rows in all three tables', async ({
    request,
  }) => {
    const { token, email } = await registerViaApi(request);
    const res = await identifyViaApi(request, token, GOOD);
    expect(res.status()).toBe(200);
    const body = await res.json();

    expect(body.project).toBe('all');
    expect(body.results).toHaveLength(10);
    expect(body.results[0]).toMatchObject({
      rank: 1,
      scientific_name_without_author: 'Murraya paniculata',
      family: 'Rutaceae',
    });
    expect(body.image.predicted_organ).toBe('flower');

    // The presigned URL must be fetchable from outside compose (public host, not minio:9000).
    expect(body.image.url).toContain('127.0.0.1:9000');
    const photo = await request.get(body.image.url);
    expect(photo.status()).toBe(200);
    expect(photo.headers()['content-type']).toBe('image/png');
    expect((await photo.body()).length).toBe(GOOD.length);

    expect(countRows('identifications', email)).toBe(1);
    expect(countRows('identification_images', email)).toBe(1);
    expect(countRows('identification_results', email)).toBe(10);
    expect(
      sql(
        `SELECT plantnet_version FROM identifications i JOIN users u ON u.id=i.user_id WHERE u.email='${email}'`,
      ),
    ).toBe('2026-03-20 (7.5)');
  });

  test('requests without a valid token are rejected with 401', async ({ request }) => {
    const none = await request.post(`${BACKEND_URL}/identify`, {
      multipart: { image: { name: 'p.png', mimeType: 'image/png', buffer: GOOD } },
    });
    expect(none.status()).toBe(401);
    const garbage = await identifyViaApi(request, 'not-a-jwt', GOOD);
    expect(garbage.status()).toBe(401);
    expect(garbage.headers()['www-authenticate']).toBe('Bearer');
  });

  test('invalid images are rejected and leave no rows', async ({ request }) => {
    const { token, email } = await registerViaApi(request);
    const small = await identifyViaApi(request, token, SMALL);
    expect(small.status()).toBe(422);
    const notImage = await identifyViaApi(request, token, Buffer.from('hello, not an image'));
    expect(notImage.status()).toBe(422);
    const missing = await request.post(`${BACKEND_URL}/identify`, {
      headers: { Authorization: `Bearer ${token}` },
      multipart: { other: 'x' },
    });
    expect(missing.status()).toBe(422);
    expect(countRows('identifications', email)).toBe(0);
  });

  test('a Pl@ntNet 429 is passed through with Retry-After and leaves no rows', async ({
    request,
  }) => {
    const { token, email } = await registerViaApi(request);
    await forceNextPlantnetStatus(request, 429);
    const res = await identifyViaApi(request, token, GOOD);
    expect(res.status()).toBe(429);
    expect(res.headers()['retry-after']).toBeTruthy();
    expect(countRows('identifications', email)).toBe(0);
  });

  test('a Pl@ntNet outage is a 502 and leaves no rows', async ({ request }) => {
    const { token, email } = await registerViaApi(request);
    await forceNextPlantnetStatus(request, 503);
    const res = await identifyViaApi(request, token, GOOD);
    expect(res.status()).toBe(502);
    expect(countRows('identifications', email)).toBe(0);
  });
});

test.describe('identify UI', () => {
  test('choose a photo, identify, see ranked results and persisted rows', async ({
    page,
    request,
  }) => {
    const { token, email } = await registerViaApi(request);
    await openCapture(page, token);

    await choosePhoto(page, GOOD);
    await expect(page.getByRole('img', { name: 'plant.png' })).toBeVisible();
    await byId(page, 'identify-submit').click();

    await expect(byId(page, 'results-list')).toBeVisible();
    // The list is lazy (only on-screen tiles are in the semantics tree); all 10 rows are
    // asserted in the DB below.
    await expect(byId(page, 'results-list')).toContainText('Murraya paniculata');
    await expect(byId(page, 'results-list')).toContainText('Rutaceae');
    await expect(byId(page, 'results-photo')).toBeVisible();

    expect(countRows('identifications', email)).toBe(1);
    expect(countRows('identification_results', email)).toBe(10);
  });

  test('an undersized photo is rejected in the browser before any request', async ({
    page,
    request,
  }) => {
    const { token, email } = await registerViaApi(request);
    await openCapture(page, token);

    await choosePhoto(page, SMALL, 'tiny.png');
    await expect(byId(page, 'identify-error')).toContainText('at least 800');
    expect(countRows('identifications', email)).toBe(0);
  });

  test('a Pl@ntNet 429 shows the limit message and the user can retry', async ({
    page,
    request,
  }) => {
    const { token, email } = await registerViaApi(request);
    await openCapture(page, token);
    await choosePhoto(page, GOOD);

    await forceNextPlantnetStatus(request, 429);
    await byId(page, 'identify-submit').click();
    await expect(byId(page, 'identify-error')).toContainText('limit');
    expect(countRows('identifications', email)).toBe(0);

    await byId(page, 'identify-submit').click(); // fake-plantnet's 429 was one-shot
    await expect(byId(page, 'results-list')).toBeVisible();
    expect(countRows('identifications', email)).toBe(1);
  });

  test('a session that dies mid-flow returns the user to login', async ({ page, request }) => {
    const { token, email } = await registerViaApi(request);
    await openCapture(page, token);
    await choosePhoto(page, GOOD);

    // Backend now rejects the still-unexpired token: the user no longer exists.
    sql(`DELETE FROM users WHERE email = '${email}'`);
    await byId(page, 'identify-submit').click();

    await expect(byId(page, 'login-title')).toBeVisible();
    const stored = await page.evaluate(() => window.localStorage.getItem('flutter.auth_token'));
    expect(stored).toBeNull();
  });
});
