import { Hono } from 'hono';
import { requireAuth } from '../middleware/auth.js';
import { db } from '../lib/db.js';
import { usageLogs } from '../schema/usage.js';
import { and, eq, gte, sql } from 'drizzle-orm';

export const me = new Hono();

me.use('*', requireAuth);

me.get('/', (c) => {
  const user = c.get('user');
  return c.json({ user });
});

me.get('/usage', async (c) => {
  const user = c.get('user');
  const since = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
  const rows = await db
    .select({
      model: usageLogs.model,
      inputTokens: sql<number>`sum(${usageLogs.inputTokens})::int`,
      outputTokens: sql<number>`sum(${usageLogs.outputTokens})::int`,
      requests: sql<number>`count(*)::int`,
    })
    .from(usageLogs)
    .where(and(eq(usageLogs.userId, user.id), gte(usageLogs.createdAt, since)))
    .groupBy(usageLogs.model);
  return c.json({ since: since.toISOString(), usage: rows });
});
