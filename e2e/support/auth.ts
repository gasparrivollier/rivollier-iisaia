import type { APIRequestContext, Page } from '@playwright/test';

import { BACKEND_URL } from './urls';

export const PASSWORD = 'correct-horse-42';

/** shared_preferences on web stores values JSON-encoded under a `flutter.` prefix. */
export const TOKEN_STORAGE_KEY = 'flutter.auth_token';

/** Unique per call: compose volumes persist between runs, so fixed emails would 409. */
export function uniqueEmail(tag: string): string {
  return `e2e-${tag}-${Date.now()}-${Math.floor(Math.random() * 1e6)}@example.com`;
}

export async function registerViaApi(
  request: APIRequestContext,
  email: string = uniqueEmail('api'),
): Promise<{ token: string; email: string }> {
  const res = await request.post(`${BACKEND_URL}/auth/register`, {
    data: { email, password: PASSWORD, display_name: 'E2E Tester' },
  });
  if (res.status() !== 201) throw new Error(`register failed: ${res.status()} ${await res.text()}`);
  return { token: (await res.json()).access_token, email };
}

/** Puts a token in browser storage before the app boots (re-applied on every navigation). */
export async function seedToken(page: Page, token: string): Promise<void> {
  await page.addInitScript(
    ([key, value]) => window.localStorage.setItem(key, JSON.stringify(value)),
    [TOKEN_STORAGE_KEY, token] as const,
  );
}

export async function storedToken(page: Page): Promise<string | null> {
  const raw = await page.evaluate((key) => window.localStorage.getItem(key), TOKEN_STORAGE_KEY);
  return raw === null ? null : (JSON.parse(raw) as string);
}
