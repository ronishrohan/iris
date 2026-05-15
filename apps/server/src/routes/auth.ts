import { Hono } from 'hono';
import { z } from 'zod';
import { supabaseAdmin } from '../lib/supabase.js';

export const auth = new Hono();

const signupSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8),
});

auth.post('/signup', async (c) => {
  const body = signupSchema.parse(await c.req.json());
  const { data, error } = await supabaseAdmin.auth.admin.createUser({
    email: body.email,
    password: body.password,
    email_confirm: true,
  });
  if (error) return c.json({ error: error.message }, 400);
  return c.json({ user: { id: data.user.id, email: data.user.email } });
});

const loginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8),
});

auth.post('/login', async (c) => {
  const body = loginSchema.parse(await c.req.json());
  const { data, error } = await supabaseAdmin.auth.signInWithPassword({
    email: body.email,
    password: body.password,
  });
  if (error) return c.json({ error: error.message }, 401);
  return c.json({ session: data.session });
});
