import type { MiddlewareHandler } from 'hono';
import { supabaseAdmin } from '../lib/supabase.js';

declare module 'hono' {
  interface ContextVariableMap {
    user: { id: string; email: string | null };
  }
}

export const requireAuth: MiddlewareHandler = async (c, next) => {
  const header = c.req.header('Authorization');
  if (!header?.startsWith('Bearer ')) {
    return c.json({ error: 'missing bearer token' }, 401);
  }
  const token = header.slice(7);
  const { data, error } = await supabaseAdmin.auth.getUser(token);
  if (error || !data.user) {
    return c.json({ error: 'invalid token' }, 401);
  }
  c.set('user', { id: data.user.id, email: data.user.email ?? null });
  await next();
};
