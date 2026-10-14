import { expect, test } from '@playwright/test';

import { BACKEND_URL, FAKE_PLANTNET_URL } from '../support/urls';

test('backend /health reports ok with the database connected', async ({ request }) => {
  const res = await request.get(`${BACKEND_URL}/health`);
  expect(res.status()).toBe(200);
  expect(await res.json()).toEqual({ status: 'ok', db: 'ok' });
});

test('fake-plantnet replays the recorded identify response', async ({ request }) => {
  const res = await request.post(`${FAKE_PLANTNET_URL}/v2/identify/all?api-key=e2e`, {
    multipart: {
      images: { name: 'leaf.jpg', mimeType: 'image/jpeg', buffer: Buffer.from('fake') },
      organs: 'auto',
    },
  });
  expect(res.status()).toBe(200);
  const body = await res.json();
  expect(body.bestMatch).toBe('Murraya paniculata (L.) Jack');
  expect(body.results.length).toBeGreaterThan(0);
});

test('app loads and shows the Diary', async ({ page }) => {
  await page.goto('/');
  await expect(page.locator('[flt-semantics-identifier="diary-title"]')).toBeVisible();
  await expect(page.getByText('My Diary')).toBeVisible();
});
