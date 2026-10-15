import { expect, test } from '@playwright/test';

import { PASSWORD, registerViaApi, seedToken, storedToken, uniqueEmail } from '../support/auth';
import { byId, fillField } from '../support/flutter';
import { BACKEND_URL } from '../support/urls';

test.describe('auth API', () => {
  test('register, login (any email case) and /auth/me round-trip', async ({ request }) => {
    const email = uniqueEmail('rt');
    const reg = await request.post(`${BACKEND_URL}/auth/register`, {
      data: { email, password: PASSWORD, display_name: 'Round Trip' },
    });
    expect(reg.status()).toBe(201);

    const login = await request.post(`${BACKEND_URL}/auth/login`, {
      data: { email: email.toUpperCase(), password: PASSWORD },
    });
    expect(login.status()).toBe(200);
    const { access_token } = await login.json();

    const me = await request.get(`${BACKEND_URL}/auth/me`, {
      headers: { Authorization: `Bearer ${access_token}` },
    });
    expect(me.status()).toBe(200);
    expect(await me.json()).toMatchObject({ email, display_name: 'Round Trip' });
  });

  test('duplicate email is 409 and a wrong password is 401', async ({ request }) => {
    const { email } = await registerViaApi(request);
    const dup = await request.post(`${BACKEND_URL}/auth/register`, {
      data: { email, password: PASSWORD, display_name: 'Again' },
    });
    expect(dup.status()).toBe(409);
    const bad = await request.post(`${BACKEND_URL}/auth/login`, {
      data: { email, password: 'not-the-password' },
    });
    expect(bad.status()).toBe(401);
  });

  const badAuth: Array<[string, Record<string, string>]> = [
    ['missing', {}],
    ['garbage', { Authorization: 'Bearer not-a-jwt' }],
    ['non-bearer', { Authorization: 'Basic YTpi' }],
  ];
  for (const [label, headers] of badAuth) {
    test(`/auth/me rejects a ${label} token with 401`, async ({ request }) => {
      const res = await request.get(`${BACKEND_URL}/auth/me`, { headers });
      expect(res.status()).toBe(401);
      expect(res.headers()['www-authenticate']).toBe('Bearer');
    });
  }

  test('/auth/me rejects a token with a tampered signature', async ({ request }) => {
    const { token } = await registerViaApi(request);
    const [h, p, s] = token.split('.');
    const flipped = `${h}.${p}.${s.slice(0, 5)}${s[5] === 'A' ? 'B' : 'A'}${s.slice(6)}`;
    const res = await request.get(`${BACKEND_URL}/auth/me`, {
      headers: { Authorization: `Bearer ${flipped}` },
    });
    expect(res.status()).toBe(401);
  });
});

test.describe('auth UI', () => {
  test('signed-out visitors land on the login screen', async ({ page }) => {
    await page.goto('/');
    await expect(byId(page, 'login-title')).toBeVisible();
  });

  test('register, reload, sign out and sign back in', async ({ page }) => {
    const email = uniqueEmail('ui');
    await page.goto('/');
    await byId(page, 'go-to-register').click();
    await expect(byId(page, 'register-title')).toBeVisible();

    await fillField(page, 'register-display-name', 'Playwright Pat');
    await fillField(page, 'register-email', email);
    await fillField(page, 'register-password', PASSWORD);
    await byId(page, 'register-submit').click();
    await expect(byId(page, 'diary-title')).toBeVisible();
    expect(await storedToken(page)).toMatch(/^[\w-]+\.[\w-]+\.[\w-]+$/);

    await page.reload();
    await expect(byId(page, 'diary-title')).toBeVisible();

    await byId(page, 'logout').click();
    await expect(byId(page, 'login-title')).toBeVisible();
    expect(await storedToken(page)).toBeNull();

    await fillField(page, 'login-email', email);
    await fillField(page, 'login-password', PASSWORD);
    await byId(page, 'login-submit').click();
    await expect(byId(page, 'diary-title')).toBeVisible();
  });

  test('a wrong password shows an error and stays on login', async ({ page, request }) => {
    const { email } = await registerViaApi(request);
    await page.goto('/');
    await fillField(page, 'login-email', email);
    await fillField(page, 'login-password', 'not-the-password');
    await byId(page, 'login-submit').click();
    await expect(byId(page, 'login-error')).toBeVisible();
    // Scoped to the error node: Flutter also mirrors the text into an aria-live announcer.
    await expect(byId(page, 'login-error')).toHaveText('Wrong email or password.');
    await expect(byId(page, 'diary-title')).toHaveCount(0);
  });

  test('a garbage stored token is discarded and the user lands on login', async ({ page }) => {
    await seedToken(page, 'not-a-jwt');
    await page.goto('/');
    await expect(byId(page, 'login-title')).toBeVisible();
    expect(await storedToken(page)).toBeNull();
  });
});
