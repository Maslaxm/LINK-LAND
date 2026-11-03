import { createClient } from '@supabase/supabase-js';

const url = process.env.SUPABASE_URL;
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
const email = (process.env.SUPER_ADMIN_EMAIL ?? 'ishanews7@gmail.com').trim().toLowerCase();
const password = process.env.SUPER_ADMIN_PASSWORD;

if (!url || !serviceRoleKey) {
  console.error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY.');
  process.exit(1);
}

if (!password || password.length < 8) {
  console.error('Set SUPER_ADMIN_PASSWORD to a password of at least 8 characters.');
  process.exit(1);
}

const supabase = createClient(url, serviceRoleKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});

async function findUserByEmail(target) {
  let page = 1;
  while (page <= 20) {
    const { data, error } = await supabase.auth.admin.listUsers({ page, perPage: 1000 });
    if (error) throw error;
    const found = data.users.find((user) => user.email?.toLowerCase() === target);
    if (found) return found;
    if (data.users.length < 1000) return null;
    page += 1;
  }
  return null;
}

let user = await findUserByEmail(email);

if (!user) {
  const { data, error } = await supabase.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: { full_name: 'LINK-LAND Super Admin' },
  });
  if (error) throw error;
  user = data.user;
  console.log(`Created Supabase Auth user ${email}.`);
} else {
  const { error } = await supabase.auth.admin.updateUserById(user.id, {
    password,
    email_confirm: true,
  });
  if (error) throw error;
  console.log(`Updated password for existing Supabase Auth user ${email}.`);
}

const { error: profileError } = await supabase.from('profiles').upsert(
  {
    id: user.id,
    email,
    full_name: 'LINK-LAND Super Admin',
    role: 'super_admin',
    is_active: true,
  },
  { onConflict: 'id' },
);

if (profileError) throw profileError;

console.log(`Assigned role super_admin to ${email}. Password is stored only in Supabase Auth.`);
