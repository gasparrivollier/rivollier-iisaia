import { expect, test, type APIRequestContext, type Page } from '@playwright/test';

import { registerViaApi, seedToken } from '../support/auth';
import { countRows, imageOrgans, sql } from '../support/db';
import { byId } from '../support/flutter';
import { makePng } from '../support/images';
import { BACKEND_URL, FAKE_PLANTNET_URL } from '../support/urls';

const GOOD = makePng(1024, 1024);
const SMALL = makePng(100, 100);

type Shot = { buffer: Buffer; organ?: string };

function form(shots: Shot[]): FormData {
  const fd = new FormData();
  shots.forEach((s, i) => {
    fd.append('images', new Blob([new Uint8Array(s.buffer)], { type: 'image/png' }), `p${i}.png`);
    fd.append('organs', s.organ ?? 'auto');
  });
  return fd;
}

async function identifyViaApi(request: APIRequestContext, token: string, shots: Shot[]) {
  return request.post(`${BACKEND_URL}/identify`, {
    headers: { Authorization: `Bearer ${token}` },
    multipart: form(shots),
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
    const res = await identifyViaApi(request, token, [{ buffer: GOOD }]);
    expect(res.status()).toBe(200);
    const body = await res.json();

    expect(body.project).toBe('all');
    expect(body.results).toHaveLength(10);
    expect(body.results[0]).toMatchObject({
      rank: 1,
      scientific_name_without_author: 'Murraya paniculata',
      family: 'Rutaceae',
    });
    expect(body.images).toHaveLength(1);
    expect(body.images[0].predicted_organ).toBe('flower');
    expect(body.images[0].organ).toBe('auto');

    // The presigned URL must be fetchable from outside compose (public host, not minio:9000).
    expect(body.images[0].url).toContain('127.0.0.1:9000');
    const photo = await request.get(body.images[0].url);
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
      multipart: form([{ buffer: GOOD }]),
    });
    expect(none.status()).toBe(401);
    const garbage = await identifyViaApi(request, 'not-a-jwt', [{ buffer: GOOD }]);
    expect(garbage.status()).toBe(401);
    expect(garbage.headers()['www-authenticate']).toBe('Bearer');
  });

  test('invalid images are rejected and leave no rows', async ({ request }) => {
    const { token, email } = await registerViaApi(request);
    const small = await identifyViaApi(request, token, [{ buffer: SMALL }]);
    expect(small.status()).toBe(422);
    const notImage = await identifyViaApi(request, token, [{ buffer: Buffer.from('hello, not an image') }]);
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
    const res = await identifyViaApi(request, token, [{ buffer: GOOD }]);
    expect(res.status()).toBe(429);
    expect(res.headers()['retry-after']).toBeTruthy();
    expect(countRows('identifications', email)).toBe(0);
  });

  test('a Pl@ntNet outage is a 502 and leaves no rows', async ({ request }) => {
    const { token, email } = await registerViaApi(request);
    await forceNextPlantnetStatus(request, 503);
    const res = await identifyViaApi(request, token, [{ buffer: GOOD }]);
    expect(res.status()).toBe(502);
    expect(countRows('identifications', email)).toBe(0);
  });

  test('three photos with organs are stored in order with their predictions', async ({
    request,
  }) => {
    const { token, email } = await registerViaApi(request);
    const res = await identifyViaApi(request, token, [
      { buffer: GOOD, organ: 'flower' },
      { buffer: makePng(900, 900), organ: 'leaf' },
      { buffer: makePng(1000, 800), organ: 'auto' },
    ]);
    expect(res.status()).toBe(200);
    const body = await res.json();
    expect(body.images.map((i: { organ: string }) => i.organ)).toEqual(['flower', 'leaf', 'auto']);
    expect(body.images.map((i: { sort_order: number }) => i.sort_order)).toEqual([0, 1, 2]);
    for (const img of body.images) {
      expect((await request.get(img.url)).status()).toBe(200);
    }
    expect(countRows('identifications', email)).toBe(1);
    expect(countRows('identification_images', email)).toBe(3);
    expect(countRows('identification_results', email)).toBe(10);
    // fake-plantnet replays its recorded predictions: flower, habit, flower, ... by position
    expect(imageOrgans(email)).toBe('flower:flower,leaf:habit,auto:flower');
  });

  test('invalid sets are rejected with a message naming the problem and leave no rows', async ({
    request,
  }) => {
    const { token, email } = await registerViaApi(request);
    const cases: Array<[string, Shot[], RegExp]> = [
      ['six photos', Array.from({ length: 6 }, () => ({ buffer: GOOD })), /At most 5/],
      ['unknown organ', [{ buffer: GOOD }, { buffer: GOOD, organ: 'petal' }], /Photo 2/],
      ['bad photo among good', [{ buffer: GOOD }, { buffer: SMALL }, { buffer: GOOD }], /Photo 2/],
    ];
    for (const [label, shots, message] of cases) {
      const res = await identifyViaApi(request, token, shots);
      expect(res.status(), label).toBe(422);
      expect((await res.json()).detail, label).toMatch(message);
    }
    // organ count mismatch: two photos, one organ tag
    const fd = new FormData();
    fd.append('images', new Blob([new Uint8Array(GOOD)], { type: 'image/png' }), 'a.png');
    fd.append('images', new Blob([new Uint8Array(GOOD)], { type: 'image/png' }), 'b.png');
    fd.append('organs', 'auto');
    const mismatch = await request.post(`${BACKEND_URL}/identify`, {
      headers: { Authorization: `Bearer ${token}` },
      multipart: fd,
    });
    expect(mismatch.status()).toBe(422);
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
    await expect(byId(page, 'shot-count')).toContainText('1/5');
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

  test('add three shots, tag them, remove one, identify; organs and order reach the DB', async ({
    page,
    request,
  }) => {
    const { token, email } = await registerViaApi(request);
    await openCapture(page, token);

    await choosePhoto(page, GOOD, 'one.png');
    await choosePhoto(page, makePng(900, 900), 'two.png');
    await choosePhoto(page, makePng(1000, 1000), 'three.png');
    await expect(byId(page, 'shot-count')).toContainText('3/5');

    await byId(page, 'shot-0-organ-flower').click();
    await byId(page, 'shot-1-organ-bark').click();
    await byId(page, 'shot-2-organ-leaf').click();
    await byId(page, 'shot-1-remove').click(); // drop two.png (bark)
    await expect(byId(page, 'shot-count')).toContainText('2/5');

    await byId(page, 'identify-submit').click();
    await expect(byId(page, 'results-list')).toBeVisible();
    await expect(byId(page, 'results-list')).toContainText('Murraya paniculata');

    expect(countRows('identification_images', email)).toBe(2);
    // one.png (flower) and three.png (leaf) stay paired with their organs, in order;
    // predictions are fake-plantnet's recorded first two: flower, habit
    expect(imageOrgans(email)).toBe('flower:flower,leaf:habit');
  });

  test('the organ banner names the photo Pl@ntNet detected it in', async ({ page, request }) => {
    const { token } = await registerViaApi(request);
    await openCapture(page, token);
    await choosePhoto(page, GOOD);
    await byId(page, 'identify-submit').click();
    await expect(byId(page, 'results-list')).toBeVisible();
    await expect(page.getByText(/We detected a/)).toContainText('photo 1');
  });

  test('a sixth photo cannot be added and a removed slot can be reused', async ({
    page,
    request,
  }) => {
    const { token } = await registerViaApi(request);
    await openCapture(page, token);
    for (let i = 0; i < 5; i++) await choosePhoto(page, GOOD, `p${i}.png`);
    await expect(byId(page, 'shot-count')).toContainText('5/5');

    // The sixth click opens no file chooser.
    const chooser = page.waitForEvent('filechooser', { timeout: 1500 }).then(
      () => 'opened',
      () => 'none',
    );
    await byId(page, 'pick-photo').click({ force: true });
    expect(await chooser).toBe('none');

    await byId(page, 'shot-4-remove').click();
    await expect(byId(page, 'shot-count')).toContainText('4/5');
    await choosePhoto(page, GOOD, 'again.png');
    await expect(byId(page, 'shot-count')).toContainText('5/5');
  });

  test('a bad photo among good ones is refused in the browser and nothing is sent', async ({
    page,
    request,
  }) => {
    const { token, email } = await registerViaApi(request);
    const sent: string[] = [];
    page.on('request', (req) => {
      if (req.url().endsWith('/identify')) sent.push(req.method());
    });
    await openCapture(page, token);
    await choosePhoto(page, GOOD, 'good.png');
    await choosePhoto(page, SMALL, 'tiny.png');
    await expect(byId(page, 'identify-error')).toContainText('tiny.png');
    await expect(byId(page, 'shot-count')).toContainText('1/5');
    expect(sent).toEqual([]);
    expect(countRows('identifications', email)).toBe(0);
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
