-- TickTrust — Initial Schema Migration
-- Run in Supabase SQL Editor

-- ── Extensions ───────────────────────────────────────────────────────────────
create extension if not exists "uuid-ossp";
create extension if not exists "pg_cron";

-- ── parents ──────────────────────────────────────────────────────────────────
create table public.parents (
  id            uuid primary key default uuid_generate_v4(),
  supabase_uid  uuid references auth.users(id) on delete cascade,
  email         text not null,
  name          text not null,
  created_at    timestamptz not null default now()
);

alter table public.parents enable row level security;

create policy "parent sees own row"
  on public.parents for all
  using (supabase_uid = auth.uid());

-- ── children ─────────────────────────────────────────────────────────────────
create table public.children (
  id                uuid primary key default uuid_generate_v4(),
  parent_id         uuid not null references public.parents(id) on delete cascade,
  name              text not null,
  offline_mode      text not null default 'strict' check (offline_mode in ('strict','lenient')),
  offline_grace_min int  not null default 30,
  created_at        timestamptz not null default now()
);

alter table public.children enable row level security;

create policy "parent manages own children"
  on public.children for all
  using (
    parent_id in (
      select id from public.parents where supabase_uid = auth.uid()
    )
  );

-- ── devices ──────────────────────────────────────────────────────────────────
create table public.devices (
  id           uuid primary key default uuid_generate_v4(),
  child_id     uuid not null references public.children(id) on delete cascade,
  name         text not null,
  type         text not null check (type in ('iphone','ipad','mac')),
  apns_token   text,
  last_seen_at timestamptz,
  created_at   timestamptz not null default now()
);

alter table public.devices enable row level security;

create policy "parent manages own devices"
  on public.devices for all
  using (
    child_id in (
      select c.id from public.children c
      join public.parents p on p.id = c.parent_id
      where p.supabase_uid = auth.uid()
    )
  );

-- ── managed_apps ─────────────────────────────────────────────────────────────
create table public.managed_apps (
  id            uuid primary key default uuid_generate_v4(),
  device_id     uuid not null references public.devices(id) on delete cascade,
  bundle_id     text not null,
  app_name      text not null,
  daily_minutes int  not null default 60 check (daily_minutes > 0),
  enabled       bool not null default true,
  created_at    timestamptz not null default now(),
  unique (device_id, bundle_id)
);

alter table public.managed_apps enable row level security;

create policy "parent manages own apps"
  on public.managed_apps for all
  using (
    device_id in (
      select d.id from public.devices d
      join public.children c on c.id = d.child_id
      join public.parents  p on p.id = c.parent_id
      where p.supabase_uid = auth.uid()
    )
  );

-- device agent can read its own managed_apps
create policy "device agent reads own apps"
  on public.managed_apps for select
  using (true);  -- scoped by device API key in Edge Functions

-- ── time_accounts ────────────────────────────────────────────────────────────
create table public.time_accounts (
  id              uuid primary key default uuid_generate_v4(),
  child_id        uuid not null references public.children(id) on delete cascade,
  managed_app_id  uuid not null references public.managed_apps(id) on delete cascade,
  date            date not null default current_date,
  used_minutes    int  not null default 0 check (used_minutes >= 0),
  bonus_minutes   int  not null default 0 check (bonus_minutes >= 0),
  debt_minutes    int  not null default 0 check (debt_minutes >= 0),
  created_at      timestamptz not null default now(),
  unique (child_id, managed_app_id, date)
);

alter table public.time_accounts enable row level security;

create policy "parent reads own time accounts"
  on public.time_accounts for all
  using (
    child_id in (
      select c.id from public.children c
      join public.parents p on p.id = c.parent_id
      where p.supabase_uid = auth.uid()
    )
  );

create policy "device agent reads time accounts"
  on public.time_accounts for select
  using (true);

create policy "device agent updates time accounts"
  on public.time_accounts for update
  using (true);

create policy "device agent inserts time accounts"
  on public.time_accounts for insert
  with check (true);

-- ── time_entries ─────────────────────────────────────────────────────────────
create table public.time_entries (
  id              uuid primary key default uuid_generate_v4(),
  device_id       uuid not null references public.devices(id) on delete cascade,
  managed_app_id  uuid not null references public.managed_apps(id) on delete cascade,
  started_at      timestamptz not null,
  ended_at        timestamptz,
  duration_minutes int,
  created_at      timestamptz not null default now()
);

alter table public.time_entries enable row level security;

create policy "parent reads own time entries"
  on public.time_entries for all
  using (
    device_id in (
      select d.id from public.devices d
      join public.children c on c.id = d.child_id
      join public.parents  p on p.id = c.parent_id
      where p.supabase_uid = auth.uid()
    )
  );

create policy "device agent writes time entries"
  on public.time_entries for all
  using (true);

-- ── launch_checks ────────────────────────────────────────────────────────────
create table public.launch_checks (
  id                uuid primary key default uuid_generate_v4(),
  device_id         uuid not null references public.devices(id) on delete cascade,
  managed_app_id    uuid not null references public.managed_apps(id) on delete cascade,
  checked_at        timestamptz not null default now(),
  result            text not null check (result in ('allowed','blocked','offline_blocked','offline_allowed')),
  minutes_remaining int
);

alter table public.launch_checks enable row level security;

create policy "parent reads own launch checks"
  on public.launch_checks for select
  using (
    device_id in (
      select d.id from public.devices d
      join public.children c on c.id = d.child_id
      join public.parents  p on p.id = c.parent_id
      where p.supabase_uid = auth.uid()
    )
  );

create policy "device agent inserts launch checks"
  on public.launch_checks for insert
  with check (true);

-- ── bonus_grants ─────────────────────────────────────────────────────────────
create table public.bonus_grants (
  id              uuid primary key default uuid_generate_v4(),
  child_id        uuid not null references public.children(id) on delete cascade,
  managed_app_id  uuid references public.managed_apps(id) on delete set null,  -- null = all apps
  minutes         int  not null check (minutes > 0),
  granted_by      uuid not null references public.parents(id),
  granted_at      timestamptz not null default now(),
  date            date not null default current_date
);

alter table public.bonus_grants enable row level security;

create policy "parent manages own bonus grants"
  on public.bonus_grants for all
  using (
    granted_by in (
      select id from public.parents where supabase_uid = auth.uid()
    )
  );

-- ── kill_events ──────────────────────────────────────────────────────────────
create table public.kill_events (
  id              uuid primary key default uuid_generate_v4(),
  device_id       uuid not null references public.devices(id) on delete cascade,
  managed_app_id  uuid not null references public.managed_apps(id) on delete cascade,
  killed_at       timestamptz not null default now(),
  reason          text not null check (reason in ('limit','parent','debt')),
  confirmed_at    timestamptz  -- null = unconfirmed
);

alter table public.kill_events enable row level security;

create policy "parent reads own kill events"
  on public.kill_events for select
  using (
    device_id in (
      select d.id from public.devices d
      join public.children c on c.id = d.child_id
      join public.parents  p on p.id = c.parent_id
      where p.supabase_uid = auth.uid()
    )
  );

create policy "device agent writes kill events"
  on public.kill_events for all
  using (true);

-- ── Indexes ──────────────────────────────────────────────────────────────────
create index idx_children_parent        on public.children(parent_id);
create index idx_devices_child          on public.devices(child_id);
create index idx_managed_apps_device    on public.managed_apps(device_id);
create index idx_time_accounts_child    on public.time_accounts(child_id);
create index idx_time_accounts_date     on public.time_accounts(date);
create index idx_time_entries_device    on public.time_entries(device_id);
create index idx_time_entries_started   on public.time_entries(started_at);
create index idx_launch_checks_device   on public.launch_checks(device_id);
create index idx_launch_checks_checked  on public.launch_checks(checked_at);
create index idx_kill_events_device     on public.kill_events(device_id);
create index idx_kill_events_killed     on public.kill_events(killed_at);
create index idx_bonus_grants_child     on public.bonus_grants(child_id);
create index idx_bonus_grants_date      on public.bonus_grants(date);

-- ── Daily reset function ─────────────────────────────────────────────────────
create or replace function public.ticktrust_daily_reset()
returns void language plpgsql security definer as $$
declare
  yesterday date := current_date - 1;
  today     date := current_date;
begin
  -- For every managed app that had a time_account yesterday,
  -- carry forward overage as debt into today's account
  insert into public.time_accounts (child_id, managed_app_id, date, debt_minutes)
  select
    ta.child_id,
    ta.managed_app_id,
    today,
    greatest(0,
      ta.used_minutes
      - ma.daily_minutes
      - ta.bonus_minutes
      + ta.debt_minutes
    )
  from public.time_accounts ta
  join public.managed_apps ma on ma.id = ta.managed_app_id
  where ta.date = yesterday
    and ta.used_minutes > 0
  on conflict (child_id, managed_app_id, date)
  do update set
    debt_minutes = excluded.debt_minutes;

  -- Close any orphaned open time_entries from yesterday
  update public.time_entries
  set
    ended_at         = date_trunc('day', now()),
    duration_minutes = extract(epoch from (date_trunc('day', now()) - started_at))::int / 60
  where ended_at is null
    and started_at < date_trunc('day', now());

  -- Clean up launch_checks older than 30 days
  delete from public.launch_checks
  where checked_at < now() - interval '30 days';
end;
$$;

-- ── pg_cron: midnight reset ───────────────────────────────────────────────────
-- Runs at 00:00 UTC daily (adjust if Arne's family is always in Germany: use 23:00 UTC = midnight CET)
select cron.schedule(
  'ticktrust-daily-reset',
  '0 23 * * *',  -- 23:00 UTC = midnight CET (Berlin)
  'select public.ticktrust_daily_reset()'
);

-- ── Realtime ─────────────────────────────────────────────────────────────────
-- Enable realtime for parent app live updates
alter publication supabase_realtime add table public.time_accounts;
alter publication supabase_realtime add table public.kill_events;
alter publication supabase_realtime add table public.bonus_grants;
