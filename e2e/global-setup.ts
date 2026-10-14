import { execSync } from 'node:child_process';
import path from 'node:path';

import { BACKEND_URL, FAKE_PLANTNET_URL, MINIO_URL } from './support/urls';

const ROOT = path.resolve(__dirname, '..');

async function waitFor(url: string, timeoutMs: number): Promise<void> {
  const deadline = Date.now() + timeoutMs;
  let last = '';
  while (Date.now() < deadline) {
    try {
      const res = await fetch(url);
      if (res.ok) return;
      last = `HTTP ${res.status}`;
    } catch (err) {
      last = String(err);
    }
    await new Promise((r) => setTimeout(r, 1000));
  }
  throw new Error(`Timed out waiting for ${url} (last: ${last})`);
}

export default async function globalSetup(): Promise<void> {
  // With E2E_SKIP_COMPOSE the caller is responsible for a stack whose backend points at fake-plantnet.
  if (!process.env.E2E_SKIP_COMPOSE) {
    execSync('podman compose up -d --build --force-recreate', {
      cwd: ROOT,
      stdio: 'inherit',
      // Shell env beats .env in compose interpolation: e2e can never hit the real Pl@ntNet.
      env: { ...process.env, PLANTNET_BASE_URL: 'http://fake-plantnet:8100' },
    });
  }
  await waitFor(`${BACKEND_URL}/health`, 120_000);
  await waitFor(`${FAKE_PLANTNET_URL}/health`, 60_000);
  await waitFor(`${MINIO_URL}/minio/health/live`, 60_000);
}
