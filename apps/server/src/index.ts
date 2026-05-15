import { serve } from '@hono/node-server';
import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { logger } from 'hono/logger';
import { health } from './routes/health.js';
import { proxy } from './routes/proxy.js';
import { me } from './routes/me.js';
import { auth } from './routes/auth.js';

const app = new Hono();

app.use('*', logger());
app.use('*', cors({ origin: '*' }));

app.route('/health', health);
app.route('/auth', auth);
app.route('/me', me);
app.route('/v1', proxy);

const port = Number(process.env.PORT ?? 8787);
serve({ fetch: app.fetch, port }, (info) => {
  console.log(`Iris server listening on http://localhost:${info.port}`);
});
