import { createClient } from '@supabase/supabase-js';

const url = process.env.SUPABASE_URL;
const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!url || !serviceKey) {
  console.warn('[supabase] SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY missing — auth will fail.');
}

export const supabaseAdmin = createClient(url ?? '', serviceKey ?? '', {
  auth: { autoRefreshToken: false, persistSession: false },
});
