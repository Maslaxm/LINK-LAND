-- ============================================================================
-- LINK-LAND - complete Supabase schema
-- Run this file in the Supabase SQL editor on a fresh project.
-- It creates tables, helper functions, triggers, RLS policies, storage buckets,
-- indexes and reservation/payment workflows.
-- ============================================================================

begin;

create extension if not exists pgcrypto;

-- ----------------------------------------------------------------------------
-- Guard helpers (seed / service-role bypass for business triggers)
-- ----------------------------------------------------------------------------
create or replace function public.guards_bypassed()
returns boolean
language sql
stable
as $$
  select coalesce(current_setting('app.bypass_guards', true), '') = 'on'
      or session_user in ('postgres', 'supabase_admin')
      or coalesce(auth.jwt() ->> 'role', '') = 'service_role';
$$;

-- ----------------------------------------------------------------------------
-- Tables
-- ----------------------------------------------------------------------------
create table if not exists public.admins (
  id uuid primary key default gen_random_uuid(),
  email text not null unique,
  role text not null default 'editor' check (role in ('super_admin', 'editor', 'agent')),
  active boolean not null default true,
  full_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text not null,
  full_name text,
  role text not null default 'user'
    check (role in ('super_admin', 'admin', 'manager', 'staff', 'agent', 'user')),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.agents (
  id uuid primary key default gen_random_uuid(),
  email text unique,
  full_name text not null,
  phone text,
  whatsapp text,
  photo text,
  bio text,
  city text,
  agency_name text,
  verified boolean not null default false,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.listings (
  id uuid primary key default gen_random_uuid(),
  title_so text not null,
  title_en text,
  description_so text,
  description_en text,
  type text not null check (type in ('land', 'house')),
  purpose text not null check (purpose in ('sale', 'rent')),
  price numeric(14, 2) not null check (price >= 0),
  currency text not null default 'USD',
  rent_period text check (rent_period in ('monthly', 'yearly')),
  size_m2 numeric(12, 2) check (size_m2 is null or size_m2 >= 0),
  bedrooms integer check (bedrooms is null or bedrooms >= 0),
  bathrooms integer check (bathrooms is null or bathrooms >= 0),
  city text not null,
  district text,
  address text,
  latitude double precision,
  longitude double precision,
  status text not null default 'pending' check (status in ('draft', 'pending', 'available', 'reserved', 'sold', 'rented', 'rejected')),
  rejection_reason text,
  featured boolean not null default false,
  featured_until timestamptz,
  verified boolean not null default false,
  agent_id uuid references public.agents (id) on delete set null,
  whatsapp text,
  phone text,
  views integer not null default 0,
  created_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.listing_images (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.listings (id) on delete cascade,
  url text not null,
  storage_path text,
  alt text,
  sort_order integer not null default 0,
  is_cover boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.inquiries (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid references public.listings (id) on delete set null,
  agent_id uuid references public.agents (id) on delete set null,
  name text not null,
  phone text not null,
  message text not null,
  status text not null default 'new' check (status in ('new', 'contacted', 'closed')),
  is_read boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.settings (
  id integer primary key default 1 check (id = 1),
  site_name text not null default 'LINK-LAND',
  logo_url text,
  tagline_so text,
  tagline_en text,
  default_whatsapp text,
  phone text,
  email text,
  address text,
  facebook text,
  instagram text,
  tiktok text,
  twitter text,
  youtube text,
  footer_so text,
  footer_en text,
  about_so text,
  about_en text,
  default_currency text not null default 'USD',
  deposit_amount numeric(12, 2) not null default 100,
  listing_fee numeric(12, 2) not null default 10,
  featured_fee numeric(12, 2) not null default 25,
  featured_days integer not null default 30,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.payment_settings (
  method text primary key check (method in ('evc_plus', 'edahab', 'zaad', 'cash', 'bank')),
  merchant_number text,
  account_name text,
  instructions_so text,
  instructions_en text,
  enabled boolean not null default false,
  updated_at timestamptz not null default now()
);

create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid references public.listings (id) on delete set null,
  agent_id uuid references public.agents (id) on delete set null,
  customer_name text not null,
  customer_phone text not null,
  amount numeric(14, 2) not null default 0 check (amount >= 0),
  currency text not null default 'USD',
  method text not null check (method in ('evc_plus', 'edahab', 'zaad', 'cash', 'bank')),
  purpose text not null default 'deposit' check (purpose in ('deposit', 'listing_fee', 'featured_boost')),
  reference text,
  provider text,
  provider_txn_id text,
  proof_image_url text,
  status text not null default 'pending' check (status in ('pending', 'confirmed', 'rejected', 'refunded')),
  notes text,
  confirmed_by uuid,
  confirmed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ----------------------------------------------------------------------------
-- Indexes
-- ----------------------------------------------------------------------------
create index if not exists listings_status_idx on public.listings (status);
create index if not exists listings_purpose_type_idx on public.listings (purpose, type);
create index if not exists listings_city_idx on public.listings (lower(city));
create index if not exists listings_district_idx on public.listings (lower(district));
create index if not exists listings_price_idx on public.listings (price);
create index if not exists listings_created_idx on public.listings (created_at desc);
create index if not exists listings_agent_idx on public.listings (agent_id);
create index if not exists listings_featured_idx on public.listings (featured, featured_until);
create index if not exists listing_images_listing_idx on public.listing_images (listing_id, sort_order);
create index if not exists inquiries_listing_idx on public.inquiries (listing_id);
create index if not exists inquiries_agent_idx on public.inquiries (agent_id, created_at desc);
create index if not exists inquiries_status_idx on public.inquiries (status);
create index if not exists payments_listing_idx on public.payments (listing_id);
create index if not exists payments_agent_idx on public.payments (agent_id, created_at desc);
create index if not exists payments_status_idx on public.payments (status);
create index if not exists payments_method_idx on public.payments (method);
create index if not exists payments_created_idx on public.payments (created_at desc);
create unique index if not exists payments_provider_txn_uniq
  on public.payments (provider, provider_txn_id)
  where provider_txn_id is not null;
create index if not exists agents_active_idx on public.agents (active);
create unique index if not exists agents_email_lower_uniq on public.agents (lower(email)) where email is not null;
create unique index if not exists admins_email_lower_uniq on public.admins (lower(email));
create unique index if not exists profiles_email_lower_uniq on public.profiles (lower(email));
create index if not exists profiles_role_idx on public.profiles (role);

-- ----------------------------------------------------------------------------
-- Auth helpers (all read the caller JWT and bypass RLS through SECURITY DEFINER)
-- ----------------------------------------------------------------------------
create or replace function public.jwt_email()
returns text
language sql
stable
as $$
  select lower(coalesce(auth.jwt() ->> 'email', ''));
$$;

create or replace function public.profile_role()
returns text
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select p.role from public.profiles p
  where p.id = auth.uid() and p.is_active
  limit 1;
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = auth.uid()
      and p.is_active
      and p.role in ('super_admin', 'admin', 'manager', 'staff', 'agent')
  );
$$;

create or replace function public.admin_role()
returns text
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select public.profile_role();
$$;

create or replace function public.is_staff()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select coalesce(public.admin_role() in ('super_admin', 'admin', 'manager', 'staff'), false);
$$;

create or replace function public.is_payment_manager()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select coalesce(public.admin_role() in ('super_admin', 'admin', 'manager'), false);
$$;

create or replace function public.can_manage_agents()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select coalesce(public.admin_role() in ('super_admin', 'admin'), false);
$$;

create or replace function public.is_super_admin()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select coalesce(public.admin_role() = 'super_admin', false);
$$;

create or replace function public.current_agent_id()
returns uuid
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select a.id from public.agents a
  where lower(a.email) = public.jwt_email() and a.active
  limit 1;
$$;

create or replace function public.is_published(p_status text)
returns boolean
language sql
immutable
as $$
  select p_status in ('available', 'reserved', 'sold', 'rented');
$$;

-- ----------------------------------------------------------------------------
-- Generic triggers
-- ----------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create or replace function public.normalize_admin_email()
returns trigger
language plpgsql
as $$
begin
  new.email := lower(trim(new.email));
  return new;
end;
$$;

create or replace function public.normalize_agent_email()
returns trigger
language plpgsql
as $$
begin
  if new.email is not null then
    new.email := lower(trim(new.email));
  end if;
  return new;
end;
$$;

drop trigger if exists admins_normalize_email on public.admins;
create trigger admins_normalize_email
  before insert or update on public.admins
  for each row execute function public.normalize_admin_email();

drop trigger if exists agents_normalize_email on public.agents;
create trigger agents_normalize_email
  before insert or update on public.agents
  for each row execute function public.normalize_agent_email();

drop trigger if exists profiles_normalize_email on public.profiles;
create trigger profiles_normalize_email
  before insert or update on public.profiles
  for each row execute function public.normalize_admin_email();

drop trigger if exists profiles_updated_at on public.profiles;
create trigger profiles_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

drop trigger if exists admins_updated_at on public.admins;
create trigger admins_updated_at
  before update on public.admins
  for each row execute function public.set_updated_at();

drop trigger if exists agents_updated_at on public.agents;
create trigger agents_updated_at
  before update on public.agents
  for each row execute function public.set_updated_at();

drop trigger if exists listings_updated_at on public.listings;
create trigger listings_updated_at
  before update on public.listings
  for each row execute function public.set_updated_at();

drop trigger if exists inquiries_updated_at on public.inquiries;
create trigger inquiries_updated_at
  before update on public.inquiries
  for each row execute function public.set_updated_at();

drop trigger if exists settings_updated_at on public.settings;
create trigger settings_updated_at
  before update on public.settings
  for each row execute function public.set_updated_at();

drop trigger if exists payment_settings_updated_at on public.payment_settings;
create trigger payment_settings_updated_at
  before update on public.payment_settings
  for each row execute function public.set_updated_at();

drop trigger if exists payments_updated_at on public.payments;
create trigger payments_updated_at
  before update on public.payments
  for each row execute function public.set_updated_at();

-- Protect the last active super admin and protect agent-managed columns -----
create or replace function public.protect_admins()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if public.guards_bypassed() then
    return coalesce(new, old);
  end if;

  if tg_op = 'DELETE' then
    if old.role = 'super_admin' and old.active
       and not exists (
         select 1 from public.admins
         where role = 'super_admin' and active and id <> old.id
       ) then
      raise exception 'Cannot remove the last active super admin';
    end if;
    return old;
  end if;

  if old.role = 'super_admin' and old.active
     and (new.role <> 'super_admin' or new.active = false)
     and not exists (
       select 1 from public.admins
       where role = 'super_admin' and active and id <> old.id
     ) then
    raise exception 'Cannot demote the last active super admin';
  end if;

  return new;
end;
$$;

drop trigger if exists admins_protect on public.admins;
create trigger admins_protect
  before update or delete on public.admins
  for each row execute function public.protect_admins();

create or replace function public.protect_profiles()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if public.guards_bypassed() then
    return coalesce(new, old);
  end if;

  if tg_op = 'DELETE' then
    if old.role = 'super_admin' and old.is_active
       and not exists (
         select 1 from public.profiles
         where role = 'super_admin' and is_active and id <> old.id
       ) then
      raise exception 'Cannot remove the last active super admin';
    end if;
    return old;
  end if;

  if old.role = 'super_admin' and old.is_active
     and (new.role <> 'super_admin' or new.is_active = false)
     and not exists (
       select 1 from public.profiles
       where role = 'super_admin' and is_active and id <> old.id
     ) then
    raise exception 'Cannot demote the last active super admin';
  end if;

  return new;
end;
$$;

drop trigger if exists profiles_protect on public.profiles;
create trigger profiles_protect
  before update or delete on public.profiles
  for each row execute function public.protect_profiles();

create or replace function public.protect_agent_columns()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if public.guards_bypassed() or public.can_manage_agents() then
    return new;
  end if;

  -- Agents may only edit their public profile fields.
  new.email := old.email;
  new.verified := old.verified;
  new.active := old.active;
  new.created_at := old.created_at;
  return new;
end;
$$;

drop trigger if exists agents_protect_columns on public.agents;
create trigger agents_protect_columns
  before update on public.agents
  for each row execute function public.protect_agent_columns();

-- Listing workflow -----------------------------------------------------------
create or replace function public.listings_guard_insert()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if public.guards_bypassed() then
    new.created_by := coalesce(new.created_by, auth.uid());
    return new;
  end if;

  if public.is_staff() then
    new.created_by := auth.uid();
    -- Admin/staff-created listings are public immediately. Draft and rejected
    -- remain explicit hidden states; a pending default is promoted to available.
    if new.status = 'pending' then
      new.status := 'available';
    end if;
    return new;
  end if;

  -- Agent-created listings always require approval.
  new.agent_id := public.current_agent_id();
  if new.agent_id is null then
    raise exception 'Agent profile not found for this account';
  end if;
  new.status := 'pending';
  new.rejection_reason := null;
  new.featured := false;
  new.featured_until := null;
  new.verified := false;
  new.created_by := auth.uid();
  return new;
end;
$$;

drop trigger if exists listings_guard_insert on public.listings;
create trigger listings_guard_insert
  before insert on public.listings
  for each row execute function public.listings_guard_insert();

create or replace function public.listings_guard_update()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if public.guards_bypassed() or public.is_staff() then
    return new;
  end if;

  -- Agent edits go back into the moderation queue and cannot touch protected
  -- columns.
  new.agent_id := old.agent_id;
  new.status := 'pending';
  new.rejection_reason := null;
  new.featured := old.featured;
  new.featured_until := old.featured_until;
  new.verified := old.verified;
  new.created_by := old.created_by;
  new.created_at := old.created_at;
  return new;
end;
$$;

drop trigger if exists listings_guard_update on public.listings;
create trigger listings_guard_update
  before update on public.listings
  for each row execute function public.listings_guard_update();

-- Inquiries ------------------------------------------------------------------
create or replace function public.inquiries_guard_insert()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_agent uuid;
begin
  if length(trim(coalesce(new.name, ''))) < 2 then
    raise exception 'Please enter a valid name';
  end if;
  if length(regexp_replace(coalesce(new.phone, ''), '[^0-9]', '', 'g')) < 7 then
    raise exception 'Please enter a valid phone number';
  end if;
  if length(trim(coalesce(new.message, ''))) < 3 then
    raise exception 'Please enter a message';
  end if;

  if new.listing_id is not null then
    select l.agent_id into v_agent
    from public.listings l
    where l.id = new.listing_id;

    if not found then
      raise exception 'This listing is not available';
    end if;
    new.agent_id := v_agent;
  else
    new.agent_id := null;
  end if;

  new.status := 'new';
  new.is_read := false;
  return new;
end;
$$;

drop trigger if exists inquiries_guard_insert on public.inquiries;
create trigger inquiries_guard_insert
  before insert on public.inquiries
  for each row execute function public.inquiries_guard_insert();

-- Payments -------------------------------------------------------------------
create or replace function public.payments_guard_insert()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_agent uuid;
  v_amount numeric;
  v_enabled boolean;
begin
  if public.guards_bypassed() then
    return new;
  end if;

  if length(trim(coalesce(new.customer_name, ''))) < 2 then
    raise exception 'Please enter a valid name';
  end if;
  if length(regexp_replace(coalesce(new.customer_phone, ''), '[^0-9]', '', 'g')) < 7 then
    raise exception 'Please enter a valid phone number';
  end if;
  if length(trim(coalesce(new.reference, ''))) < 3 then
    raise exception 'Transaction reference is required';
  end if;

  if new.listing_id is not null then
    select l.agent_id into v_agent
    from public.listings l
    where l.id = new.listing_id and public.is_published(l.status);

    if not found then
      raise exception 'This listing is not available';
    end if;
    new.agent_id := v_agent;
  elsif new.purpose in ('deposit', 'featured_boost') then
    raise exception 'A listing is required for this payment';
  end if;

  select ps.enabled into v_enabled
  from public.payment_settings ps
  where ps.method = new.method;

  if not coalesce(v_enabled, false) then
    raise exception 'This payment method is not available';
  end if;

  if new.purpose = 'deposit' then
    select s.deposit_amount into v_amount from public.settings s where s.id = 1;
  elsif new.purpose = 'listing_fee' then
    if not public.is_payment_manager() then
      raise exception 'Not allowed';
    end if;
    select s.listing_fee into v_amount from public.settings s where s.id = 1;
  elsif new.purpose = 'featured_boost' then
    if not public.is_payment_manager() then
      raise exception 'Not allowed';
    end if;
    select s.featured_fee into v_amount from public.settings s where s.id = 1;
  else
    raise exception 'Invalid payment purpose';
  end if;

  new.amount := coalesce(v_amount, 0);
  if new.amount <= 0 then
    raise exception 'Invalid payment amount';
  end if;

  new.currency := coalesce(nullif(trim(new.currency), ''), 'USD');
  new.status := 'pending';
  new.confirmed_by := null;
  new.confirmed_at := null;
  return new;
end;
$$;

drop trigger if exists payments_guard_insert on public.payments;
create trigger payments_guard_insert
  before insert on public.payments
  for each row execute function public.payments_guard_insert();

create or replace function public.payments_apply_status()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.status = 'confirmed' and old.status is distinct from 'confirmed' then
    if new.purpose = 'deposit' and new.listing_id is not null then
      update public.listings
      set status = 'reserved'
      where id = new.listing_id and status = 'available';
    elsif new.purpose = 'featured_boost' and new.listing_id is not null then
      update public.listings
      set featured = true,
          featured_until = now() + make_interval(
            days => coalesce((select featured_days from public.settings where id = 1), 30)
          )
      where id = new.listing_id;
    end if;
  elsif new.status in ('rejected', 'refunded') and old.status = 'confirmed' then
    if new.purpose = 'featured_boost' and new.listing_id is not null then
      update public.listings
      set featured = false, featured_until = null
      where id = new.listing_id;
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists payments_apply_status on public.payments;
create trigger payments_apply_status
  after update on public.payments
  for each row execute function public.payments_apply_status();

-- ----------------------------------------------------------------------------
-- RPCs
-- ----------------------------------------------------------------------------
create or replace function public.increment_listing_views(p_id uuid)
returns void
language sql
security definer
set search_path = public, pg_temp
as $$
  update public.listings
  set views = views + 1
  where id = p_id and public.is_published(status);
$$;

create or replace function public.submit_payment(
  p_listing_id uuid,
  p_customer_name text,
  p_customer_phone text,
  p_method text,
  p_reference text,
  p_proof_url text default null,
  p_purpose text default 'deposit'
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_id uuid := gen_random_uuid();
begin
  insert into public.payments (
    id, listing_id, customer_name, customer_phone, amount, currency,
    method, purpose, reference, proof_image_url, status
  ) values (
    v_id, p_listing_id, p_customer_name, p_customer_phone, 0, 'USD',
    p_method, coalesce(p_purpose, 'deposit'), p_reference, p_proof_url, 'pending'
  );

  return v_id;
end;
$$;

create or replace function public.expire_featured_listings()
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_count integer;
begin
  update public.listings
  set featured = false
  where featured = true
    and featured_until is not null
    and featured_until < now();

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

create or replace function public.bootstrap_super_admin(p_email text)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_id uuid;
  v_email text;
begin
  if p_email is null or position('@' in p_email) = 0 then
    raise exception 'A valid email is required';
  end if;

  v_email := lower(trim(p_email));
  select u.id into v_id from auth.users u where lower(u.email) = v_email limit 1;

  if v_id is null then
    raise exception 'Create this user in Supabase Authentication first, then run this function';
  end if;

  insert into public.profiles (id, email, role, is_active, full_name)
  values (v_id, v_email, 'super_admin', true, 'LINK-LAND Super Admin')
  on conflict (id) do update
    set email = excluded.email,
        role = 'super_admin',
        is_active = true,
        updated_at = now();
end;
$$;

revoke all on function public.bootstrap_super_admin(text) from public;
revoke all on function public.expire_featured_listings() from public;
grant execute on function public.increment_listing_views(uuid) to anon, authenticated;
grant execute on function public.submit_payment(uuid, text, text, text, text, text, text) to anon, authenticated;
grant execute on function public.expire_featured_listings() to service_role;

-- Auto-expire featured listings (only when pg_cron is installed) -------------
do $cron$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    if not exists (select 1 from cron.job where jobname = 'link-land-expire-featured') then
      perform cron.schedule(
        'link-land-expire-featured',
        '15 * * * *',
        'select public.expire_featured_listings();'
      );
    end if;
  else
    raise notice 'pg_cron is not enabled. Use the expire-featured edge function or enable pg_cron.';
  end if;
exception when others then
  raise notice 'Could not schedule featured expiry: %', sqlerrm;
end;
$cron$;

-- ----------------------------------------------------------------------------
-- Row Level Security
-- ----------------------------------------------------------------------------
alter table public.admins enable row level security;
alter table public.profiles enable row level security;
alter table public.agents enable row level security;
alter table public.listings enable row level security;
alter table public.listing_images enable row level security;
alter table public.inquiries enable row level security;
alter table public.settings enable row level security;
alter table public.payment_settings enable row level security;
alter table public.payments enable row level security;

-- admins ---------------------------------------------------------------------
drop policy if exists admins_select on public.admins;
create policy admins_select on public.admins
  for select to authenticated
  using (public.is_super_admin() or lower(email) = public.jwt_email());

drop policy if exists admins_super_write on public.admins;
create policy admins_super_write on public.admins
  for all to authenticated
  using (public.is_super_admin())
  with check (public.is_super_admin());

-- profiles -------------------------------------------------------------------
drop policy if exists profiles_select_self_or_super on public.profiles;
create policy profiles_select_self_or_super on public.profiles
  for select to authenticated
  using (id = auth.uid() or public.is_super_admin());

drop policy if exists profiles_super_write on public.profiles;
create policy profiles_super_write on public.profiles
  for all to authenticated
  using (public.is_super_admin())
  with check (public.is_super_admin());

-- agents ---------------------------------------------------------------------
drop policy if exists agents_public_read on public.agents;
create policy agents_public_read on public.agents
  for select to anon, authenticated
  using (active = true or public.is_admin());

drop policy if exists agents_super_write on public.agents;
create policy agents_super_write on public.agents
  for all to authenticated
  using (public.can_manage_agents())
  with check (public.can_manage_agents());

drop policy if exists agents_self_update on public.agents;
create policy agents_self_update on public.agents
  for update to authenticated
  using (lower(email) = public.jwt_email() and public.is_admin())
  with check (lower(email) = public.jwt_email() and public.is_admin());

-- listings -------------------------------------------------------------------
drop policy if exists listings_public_read on public.listings;
create policy listings_public_read on public.listings
  for select to anon, authenticated
  using (public.is_published(status));

drop policy if exists listings_staff_all on public.listings;
create policy listings_staff_all on public.listings
  for all to authenticated
  using (public.is_staff())
  with check (public.is_staff());

drop policy if exists listings_agent_read on public.listings;
create policy listings_agent_read on public.listings
  for select to authenticated
  using (agent_id = public.current_agent_id());

drop policy if exists listings_agent_insert on public.listings;
create policy listings_agent_insert on public.listings
  for insert to authenticated
  with check (
    public.admin_role() = 'agent'
    and agent_id = public.current_agent_id()
  );

drop policy if exists listings_agent_update on public.listings;
create policy listings_agent_update on public.listings
  for update to authenticated
  using (agent_id = public.current_agent_id())
  with check (agent_id = public.current_agent_id());

drop policy if exists listings_agent_delete on public.listings;
create policy listings_agent_delete on public.listings
  for delete to authenticated
  using (agent_id = public.current_agent_id());

-- listing images -------------------------------------------------------------
drop policy if exists listing_images_public_read on public.listing_images;
create policy listing_images_public_read on public.listing_images
  for select to anon, authenticated
  using (
    exists (
      select 1 from public.listings l
      where l.id = listing_id and public.is_published(l.status)
    )
  );

drop policy if exists listing_images_staff_all on public.listing_images;
create policy listing_images_staff_all on public.listing_images
  for all to authenticated
  using (public.is_staff())
  with check (public.is_staff());

drop policy if exists listing_images_agent_read on public.listing_images;
create policy listing_images_agent_read on public.listing_images
  for select to authenticated
  using (
    exists (
      select 1 from public.listings l
      where l.id = listing_id and l.agent_id = public.current_agent_id()
    )
  );

drop policy if exists listing_images_agent_write on public.listing_images;
create policy listing_images_agent_write on public.listing_images
  for all to authenticated
  using (
    exists (
      select 1 from public.listings l
      where l.id = listing_id and l.agent_id = public.current_agent_id()
    )
  )
  with check (
    exists (
      select 1 from public.listings l
      where l.id = listing_id and l.agent_id = public.current_agent_id()
    )
  );

-- inquiries ------------------------------------------------------------------
drop policy if exists inquiries_public_insert on public.inquiries;
create policy inquiries_public_insert on public.inquiries
  for insert to anon, authenticated
  with check (true);

drop policy if exists inquiries_staff_all on public.inquiries;
create policy inquiries_staff_all on public.inquiries
  for all to authenticated
  using (public.is_staff())
  with check (public.is_staff());

drop policy if exists inquiries_agent_read on public.inquiries;
create policy inquiries_agent_read on public.inquiries
  for select to authenticated
  using (agent_id = public.current_agent_id());

drop policy if exists inquiries_agent_update on public.inquiries;
create policy inquiries_agent_update on public.inquiries
  for update to authenticated
  using (agent_id = public.current_agent_id())
  with check (agent_id = public.current_agent_id());

drop policy if exists inquiries_agent_delete on public.inquiries;
create policy inquiries_agent_delete on public.inquiries
  for delete to authenticated
  using (agent_id = public.current_agent_id());

-- settings -------------------------------------------------------------------
drop policy if exists settings_public_read on public.settings;
create policy settings_public_read on public.settings
  for select to anon, authenticated
  using (true);

drop policy if exists settings_super_write on public.settings;
create policy settings_super_write on public.settings
  for all to authenticated
  using (public.is_super_admin())
  with check (public.is_super_admin());

-- payment settings -----------------------------------------------------------
drop policy if exists payment_settings_public_read on public.payment_settings;
create policy payment_settings_public_read on public.payment_settings
  for select to anon, authenticated
  using (enabled = true or public.is_admin());

drop policy if exists payment_settings_super_write on public.payment_settings;
create policy payment_settings_super_write on public.payment_settings
  for all to authenticated
  using (public.is_super_admin())
  with check (public.is_super_admin());

-- payments -------------------------------------------------------------------
drop policy if exists payments_public_insert on public.payments;
create policy payments_public_insert on public.payments
  for insert to anon, authenticated
  with check (
    status = 'pending'
    and confirmed_by is null
    and length(trim(customer_name)) >= 2
    and length(regexp_replace(customer_phone, '[^0-9]', '', 'g')) >= 7
  );

drop policy if exists payments_staff_all on public.payments;
create policy payments_staff_all on public.payments
  for all to authenticated
  using (public.is_payment_manager())
  with check (public.is_payment_manager());

drop policy if exists payments_agent_read on public.payments;
create policy payments_agent_read on public.payments
  for select to authenticated
  using (agent_id = public.current_agent_id());

-- ----------------------------------------------------------------------------
-- Grants (RLS still applies)
-- ----------------------------------------------------------------------------
grant usage on schema public to anon, authenticated;
grant select on public.listings, public.listing_images, public.agents,
  public.settings, public.payment_settings to anon, authenticated;
grant insert on public.inquiries, public.payments to anon, authenticated;
grant select, insert, update, delete on public.listings, public.listing_images,
  public.inquiries to authenticated;
grant select, update, delete on public.payments to authenticated;
grant select on public.admins to authenticated;
grant insert, update, delete on public.admins, public.agents,
  public.settings, public.payment_settings to authenticated;
grant select on public.profiles to authenticated;
grant insert, update, delete on public.profiles to authenticated;

-- ----------------------------------------------------------------------------
-- Storage buckets + policies
-- ----------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'listing-images', 'listing-images', true, 10485760,
  array['image/jpeg', 'image/png', 'image/webp', 'image/avif']
)
on conflict (id) do update
  set public = true,
      file_size_limit = 10485760,
      allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp', 'image/avif'];

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'payment-proofs', 'payment-proofs', false, 5242880,
  array['image/jpeg', 'image/png', 'image/webp', 'application/pdf']
)
on conflict (id) do update
  set public = false,
      file_size_limit = 5242880,
      allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp', 'application/pdf'];

drop policy if exists "link_land_listing_images_read" on storage.objects;
create policy "link_land_listing_images_read" on storage.objects
  for select to anon, authenticated
  using (bucket_id = 'listing-images');

drop policy if exists "link_land_listing_images_insert" on storage.objects;
create policy "link_land_listing_images_insert" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'listing-images' and public.is_admin());

drop policy if exists "link_land_listing_images_update" on storage.objects;
create policy "link_land_listing_images_update" on storage.objects
  for update to authenticated
  using (
    bucket_id = 'listing-images'
    and (public.is_staff() or owner = auth.uid())
  )
  with check (bucket_id = 'listing-images' and public.is_admin());

drop policy if exists "link_land_listing_images_delete" on storage.objects;
create policy "link_land_listing_images_delete" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'listing-images'
    and (public.is_staff() or owner = auth.uid())
  );

drop policy if exists "link_land_payment_proofs_insert" on storage.objects;
create policy "link_land_payment_proofs_insert" on storage.objects
  for insert to anon, authenticated
  with check (bucket_id = 'payment-proofs');

drop policy if exists "link_land_payment_proofs_read" on storage.objects;
create policy "link_land_payment_proofs_read" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'payment-proofs'
    and (
      public.is_payment_manager()
      or exists (
        select 1 from public.payments p
        where p.proof_image_url = storage.objects.name
          and p.agent_id = public.current_agent_id()
      )
    )
  );

drop policy if exists "link_land_payment_proofs_delete" on storage.objects;
create policy "link_land_payment_proofs_delete" on storage.objects
  for delete to authenticated
  using (bucket_id = 'payment-proofs' and public.is_payment_manager());

commit;
