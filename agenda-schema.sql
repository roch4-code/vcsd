-- Supabase / PostgreSQL setup for the Dr. Amigo patient scheduling page.
-- The website uses patient_appointments. Older generic tables are kept intact.
create extension if not exists btree_gist;

create table if not exists public.patient_appointments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  patient_name text not null check (length(trim(patient_name)) between 2 and 100),
  service_name text not null check (length(trim(service_name)) between 2 and 100),
  notes text not null default '' check (length(notes) <= 400),
  terms_accepted_at timestamptz not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  status text not null default 'pending' check (status in ('pending','confirmed','cancelled','completed','no_show')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_at > starts_at),
  exclude using gist (tstzrange(starts_at, ends_at, '[)') with &&)
    where (status in ('pending','confirmed'))
);

alter table public.patient_appointments add column if not exists terms_accepted_at timestamptz;
create index if not exists patient_appointments_user_start_idx on public.patient_appointments (user_id, starts_at);
create index if not exists patient_appointments_start_idx on public.patient_appointments (starts_at);
alter table public.patient_appointments enable row level security;
revoke all on public.patient_appointments from public, anon, authenticated;
grant select on public.patient_appointments to authenticated;
drop policy if exists patient_appointments_read_own on public.patient_appointments;
create policy patient_appointments_read_own on public.patient_appointments for select to authenticated
  using (user_id = (select auth.uid()));

-- All writes derive user_id from the auth session; clients cannot write table rows directly.
create or replace function public.create_patient_appointment(
  p_patient_name text, p_service_name text, p_notes text, p_starts_at timestamptz, p_terms_accepted boolean
) returns uuid
language plpgsql security definer set search_path = public, extensions, pg_temp
as $$
declare v_id uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required' using errcode = '42501'; end if;
  if p_terms_accepted is distinct from true then raise exception 'Terms acceptance required' using errcode = '22023'; end if;
  if length(trim(coalesce(p_patient_name,''))) not between 2 and 100
    or length(trim(coalesce(p_service_name,''))) not between 2 and 100
    or length(coalesce(p_notes,'')) > 400
  then raise exception 'Invalid appointment details' using errcode = '22023'; end if;
  if p_starts_at <= now()
    or extract(minute from p_starts_at at time zone 'America/Sao_Paulo') <> 0
    or extract(second from p_starts_at at time zone 'America/Sao_Paulo') <> 0
    or extract(hour from p_starts_at at time zone 'America/Sao_Paulo') not between 8 and 18
  then raise exception 'Invalid appointment time' using errcode = '22023'; end if;
  insert into public.patient_appointments(user_id, patient_name, service_name, notes, starts_at, ends_at, terms_accepted_at)
  values(auth.uid(), trim(p_patient_name), trim(p_service_name), coalesce(p_notes,''), p_starts_at, p_starts_at + interval '1 hour', now())
  returning id into v_id;
  return v_id;
exception when exclusion_violation then
  raise exception 'Esse horário já foi ocupado. Escolha outro.' using errcode = '23P01';
end;
$$;

create or replace function public.move_patient_appointment(p_appointment_id uuid, p_starts_at timestamptz, p_terms_accepted boolean)
returns uuid
language plpgsql security definer set search_path = public, extensions, pg_temp
as $$
declare v_id uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required' using errcode = '42501'; end if;
  if p_terms_accepted is distinct from true then raise exception 'Terms acceptance required' using errcode = '22023'; end if;
  if p_starts_at <= now()
    or extract(minute from p_starts_at at time zone 'America/Sao_Paulo') <> 0
    or extract(second from p_starts_at at time zone 'America/Sao_Paulo') <> 0
    or extract(hour from p_starts_at at time zone 'America/Sao_Paulo') not between 8 and 18
  then raise exception 'Invalid appointment time' using errcode = '22023'; end if;
  update public.patient_appointments
  set starts_at = p_starts_at, ends_at = p_starts_at + interval '1 hour', status = 'pending', terms_accepted_at = now(), updated_at = now()
  where id = p_appointment_id and user_id = auth.uid() and status in ('pending','confirmed')
  returning id into v_id;
  if v_id is null then raise exception 'Appointment not found or not editable' using errcode = '42501'; end if;
  return v_id;
exception when exclusion_violation then
  raise exception 'Esse horário já foi ocupado. Escolha outro.' using errcode = '23P01';
end;
$$;

create or replace function public.cancel_patient_appointment(p_appointment_id uuid)
returns uuid language plpgsql security definer set search_path = public, extensions, pg_temp
as $$
declare v_id uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required' using errcode = '42501'; end if;
  update public.patient_appointments set status = 'cancelled', updated_at = now()
  where id = p_appointment_id and user_id = auth.uid() and status in ('pending','confirmed')
  returning id into v_id;
  if v_id is null then raise exception 'Appointment not found or not cancellable' using errcode = '42501'; end if;
  return v_id;
end;
$$;

-- Returns occupied start times only, without exposing patient or treatment data.
create or replace function public.list_busy_slots(p_from timestamptz, p_to timestamptz)
returns table(starts_at timestamptz)
language sql stable security definer set search_path = public, extensions, pg_temp
as $$
  select a.starts_at from public.patient_appointments a
  where auth.uid() is not null
    and a.status in ('pending','confirmed') and a.starts_at >= p_from and a.starts_at < p_to
$$;

do $$
begin
  -- Revoke old overloads only when they exist, so upgrades do not abort.
  if to_regprocedure('public.create_patient_appointment(text,text,text,timestamptz)') is not null then
    execute 'revoke all on function public.create_patient_appointment(text,text,text,timestamptz) from public, anon, authenticated';
  end if;
  if to_regprocedure('public.move_patient_appointment(uuid,timestamptz)') is not null then
    execute 'revoke all on function public.move_patient_appointment(uuid,timestamptz) from public, anon, authenticated';
  end if;
end;
$$;

-- SECURITY DEFINER functions are executable by PUBLIC by default; explicitly revoke
-- that default and grant only the authenticated role.
revoke all on function public.create_patient_appointment(text,text,text,timestamptz,boolean) from public, anon, authenticated;
revoke all on function public.move_patient_appointment(uuid,timestamptz,boolean) from public, anon, authenticated;
revoke all on function public.cancel_patient_appointment(uuid) from public, anon, authenticated;
revoke all on function public.list_busy_slots(timestamptz,timestamptz) from public, anon, authenticated;
grant execute on function public.create_patient_appointment(text,text,text,timestamptz,boolean) to authenticated;
grant execute on function public.move_patient_appointment(uuid,timestamptz,boolean) to authenticated;
grant execute on function public.cancel_patient_appointment(uuid) to authenticated;
grant execute on function public.list_busy_slots(timestamptz,timestamptz) to authenticated;


