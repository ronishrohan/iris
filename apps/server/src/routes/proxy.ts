import { Hono } from 'hono';
import { requireAuth } from '../middleware/auth.js';
import { rateLimit } from '../middleware/rateLimit.js';
import { streamDeepSeek, teeWithUsageTracking } from '../lib/deepseek.js';
import { recordUsage } from '../lib/usage.js';

export const proxy = new Hono();

proxy.use('*', requireAuth);
proxy.use('*', rateLimit);

proxy.post('/chat/completions', async (c) => {
  const user = c.get('user');
  const body = await c.req.json();

  const upstream = await streamDeepSeek(body);

  if (!upstream.ok || !upstream.body) {
    return c.json({ error: `upstream ${upstream.status}` }, 502);
  }

  const stream = teeWithUsageTracking(upstream.body, (u) => {
    if (!u) return;
    recordUsage({
      userId: user.id,
      model: u.model,
      inputTokens: u.promptTokens,
      outputTokens: u.completionTokens,
    }).catch((e) => console.error('[usage] record failed', e));
  });

  return new Response(stream, {
    status: 200,
    headers: {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      Connection: 'keep-alive',
    },
  });
});
