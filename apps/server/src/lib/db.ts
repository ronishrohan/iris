import { drizzle } from 'drizzle-orm/node-postgres';
import pg from 'pg';

const url = process.env.DATABASE_URL;
if (!url) {
  console.warn('[db] DATABASE_URL missing — DB-backed features will fail.');
}

export const pool = new pg.Pool({ connectionString: url });
export const db = drizzle(pool);
