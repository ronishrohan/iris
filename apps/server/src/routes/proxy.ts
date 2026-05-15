import { Hono } from 'hono';
import { requireAuth } from '../middleware/auth.js';
import { rateLimit } from '../middleware/rateLimit.js';
import { streamDeepSeek } from '../lib/deepseek.js';

export const proxy = new Hono();

proxy.use('*', requireAuth);
proxy.use('*', rateLimit);

proxy.post('/chat/completions', async (c) => {
  const body = await c.req.json();

  // Force-disable BYOK key passthrough; we use our server-side key.
  const upstream = await streamDeepSeek(body);

  if (!upstream.ok || !upstream.body) {
    return c.json({ error: `upstream ${upstream.status}` }, 502);
  }

  return new Response(upstream.body, {
    status: 200,
    headers: {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      Connection: 'keep-alive',
    },
  });
});
