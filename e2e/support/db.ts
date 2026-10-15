import { execFileSync } from 'node:child_process';
import path from 'node:path';

const ROOT = path.resolve(__dirname, '..', '..');

/** Runs a query in the compose Postgres and returns its trimmed stdout (-At: bare values). */
export function sql(query: string): string {
  return execFileSync(
    'podman',
    ['compose', 'exec', '-T', 'postgres', 'psql', '-U', 'yvoty', '-d', 'yvoty', '-At', '-c', query],
    { cwd: ROOT, encoding: 'utf8' },
  ).trim();
}

/** Rows of an identification table owned by the user with this e2e email. */
export function countRows(
  table: 'identifications' | 'identification_images' | 'identification_results',
  email: string,
): number {
  const owner = table === 'identifications' ? 'i.id = t.id' : 'i.id = t.identification_id';
  return Number(
    sql(
      `SELECT count(*) FROM ${table} t JOIN identifications i ON ${owner} ` +
        `JOIN users u ON u.id = i.user_id WHERE u.email = '${email}'`,
    ),
  );
}
