import type { MiddlewareHandler } from 'hono';

// In-memory token bucket. Replace with Redis in production.
type Bucket = { tokens: number; updated: number };
const buckets = new Map<string, Bucket>();

const RPM = Number(process.env.PLAN_FREE_RPM ?? 5);

export const rateLimit: MiddlewareHandler = async (c, next) => {
  const user = c.get('user');
  if (!user) return c.json({ error: 'unauthenticated' }, 401);
  const now = Date.now();
  const bucket = buckets.get(user.id) ?? { tokens: RPM, updated: now };
  const refill = Math.floor((now - bucket.updated) / 60000) * RPM;
  bucket.tokens = Math.min(RPM, bucket.tokens + refill);
  bucket.updated = now;
  if (bucket.tokens <= 0) {
    buckets.set(user.id, bucket);
    return c.json({ error: 'rate limit exceeded' }, 429);
  }
  bucket.tokens -= 1;
  buckets.set(user.id, bucket);
  await next();
};
