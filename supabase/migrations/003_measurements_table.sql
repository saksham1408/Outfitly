-- ============================================================
-- Outfitly Phase 2: Measurements table
-- Run this in Supabase SQL Editor
-- ============================================================

create table if not exists public.measurements (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  -- Upper body
  chest numeric(5,1),
  waist numeric(5,1),
  shoulder numeric(5,1),
  sleeve_length numeric(5,1),
  shirt_length numeric(5,1),
  neck numeric(5,1),
  -- Lower body
  trouser_waist numeric(5,1),
  hip numeric(5,1),
  thigh numeric(5,1),
  inseam numeric(5,1),
  trouser_length numeric(5,1),
  -- Meta
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique (user_id)
);

alter table public.measurements enable row level security;

create policy "Users can read own measurements"
  on public.measurements for select
  using (auth.uid() = user_id);

create policy "Users can insert own measurements"
  on public.measurements for insert
  with check (auth.uid() = user_id);

create policy "Users can update own measurements"
  on public.measurements for update
  using (auth.uid() = user_id);
