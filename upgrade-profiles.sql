-- ============================================================================
-- LINK-LAND - profiles / role-based admin upgrade
-- Run once on an existing database AFTER schema.sql has already been applied.
-- Safe to re-run.
--
-- This file never stores passwords. Passwords live only in Supabase Auth.
-- Create the super admin Auth account first, then run this file or call:
--   select public.bootstrap_super_admin('ishanews7@gmail.com');
-- ============================================================================

begin;

select set_config('app.bypass_guards', 'on', false);

-- Profiles --------------------------------------------------------------------
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

create unique index if not exists profiles_email_lower_uniq on public.profiles (lower(email));
create index if not exists profiles_role_idx on public.profiles (role);

create or replace function public.normalize_admin_email()
returns trigger
language plpgsql
as $$
begin
  new.email := lower(trim(new.email));
  return new;
end;
$$;

drop trigger if exists profiles_normalize_email on public.profiles;
create trigger profiles_normalize_email
  before insert or update on public.profiles
  for each row execute function public.normalize_admin_email();

drop trigger if exists profiles_updated_at on public.profiles;
create trigger profiles_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- Copy old allow-list rows to profiles for matching Auth users -----------------
insert into public.profiles (id, email, full_name, role, is_active)
select
  u.id,
  lower(u.email),
  coalesce(a.full_name, u.raw_user_meta_data ->> 'full_name'),
  case a.role
    when 'super_admin' then 'super_admin'
    when 'editor' then 'admin'
    when 'agent' then 'agent'
    else 'staff'
  end,
  a.active
from auth.users u
join public.admins a on lower(a.email) = lower(u.email)
on conflict (id) do update
  set email = excluded.email,
      full_name = coalesce(excluded.full_name, public.profiles.full_name),
      role = excluded.role,
      is_active = excluded.is_active,
      updated_at = now();

-- Ensure the requested main super admin gets the role once the Auth user exists
insert into public.profiles (id, email, full_name, role, is_active)
select
  u.id,
  lower(u.email),
  coalesce(u.raw_user_meta_data ->> 'full_name', 'LINK-LAND Super Admin'),
  'super_admin',
  true
from auth.users u
where lower(u.email) = 'ishanews7@gmail.com'
on conflict (id) do update
  set email = excluded.email,
      role = 'super_admin',
      is_active = true,
      updated_at = now();

-- Role helpers ----------------------------------------------------------------
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

-- Protect the last active super admin -----------------------------------------
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

-- Agent column protection now follows profile roles ---------------------------
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

  new.email := old.email;
  new.verified := old.verified;
  new.active := old.active;
  new.created_at := old.created_at;
  return new;
end;
$$;

-- Payment workflow guard ------------------------------------------------------
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

-- Bootstrap function (profile only, never the password) -----------------------
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

-- RLS -------------------------------------------------------------------------
alter table public.profiles enable row level security;

drop policy if exists profiles_select_self_or_super on public.profiles;
create policy profiles_select_self_or_super on public.profiles
  for select to authenticated
  using (id = auth.uid() or public.is_super_admin());

drop policy if exists profiles_super_write on public.profiles;
create policy profiles_super_write on public.profiles
  for all to authenticated
  using (public.is_super_admin())
  with check (public.is_super_admin());

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

drop policy if exists payments_staff_all on public.payments;
create policy payments_staff_all on public.payments
  for all to authenticated
  using (public.is_payment_manager())
  with check (public.is_payment_manager());

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

grant select on public.profiles to authenticated;
grant insert, update, delete on public.profiles to authenticated;

select set_config('app.bypass_guards', 'off', false);

commit;
