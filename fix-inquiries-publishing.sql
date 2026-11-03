-- LINK-LAND hotfix: public inquiry submissions + immediate publishing of
-- admin/staff-created listings.
--
-- Run this once in the Supabase SQL Editor. It is safe to re-run.

begin;

-- 1. Let website visitors insert inquiries -----------------------------------
alter table public.inquiries enable row level security;

drop policy if exists inquiries_public_insert on public.inquiries;
create policy inquiries_public_insert on public.inquiries
  for insert to anon, authenticated
  with check (true);

grant usage on schema public to anon, authenticated;
grant insert on public.inquiries to anon, authenticated;

-- 2. Accept inquiries for every existing listing ------------------------------
-- A hidden/pending listing still must not throw "This listing is not available".
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

-- 3. Admin/staff listings publish immediately --------------------------------
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
    if new.status = 'pending' then
      new.status := 'available';
    end if;
    return new;
  end if;

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

-- 4. Publish existing pending listings created by admin/staff ----------------
update public.listings l
set status = 'available',
    rejection_reason = null,
    updated_at = now()
from public.profiles p
where l.created_by = p.id
  and p.role in ('super_admin', 'admin', 'manager', 'staff')
  and l.status = 'pending';

commit;

select id, title_so, status, created_at
from public.listings
order by created_at desc
limit 10;
