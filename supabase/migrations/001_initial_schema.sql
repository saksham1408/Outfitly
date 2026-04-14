-- ============================================================
-- Outfitly Phase 1: Profiles, Style Preferences, Catalog
-- Run this in Supabase SQL Editor (Dashboard > SQL Editor)
-- ============================================================

-- ── Profiles ──
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  phone text,
  full_name text,
  avatar_url text,
  onboarding_complete boolean default false,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

alter table public.profiles enable row level security;

create policy "Users can read own profile"
  on public.profiles for select
  using (auth.uid() = id);

create policy "Users can update own profile"
  on public.profiles for update
  using (auth.uid() = id);

create policy "Users can insert own profile"
  on public.profiles for insert
  with check (auth.uid() = id);

-- Auto-create profile on signup
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, phone)
  values (new.id, coalesce(new.phone, new.email));
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ── Style Preferences ──
create table if not exists public.style_preferences (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  preferred_styles text[] default '{}',
  preferred_fabrics text[] default '{}',
  preferred_colors text[] default '{}',
  preferred_occasions text[] default '{}',
  budget_range text,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique (user_id)
);

alter table public.style_preferences enable row level security;

create policy "Users can read own preferences"
  on public.style_preferences for select
  using (auth.uid() = user_id);

create policy "Users can upsert own preferences"
  on public.style_preferences for insert
  with check (auth.uid() = user_id);

create policy "Users can update own preferences"
  on public.style_preferences for update
  using (auth.uid() = user_id);

-- ── Categories ──
create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  image_url text,
  sort_order int default 0,
  created_at timestamptz default now()
);

alter table public.categories enable row level security;

create policy "Categories are publicly readable"
  on public.categories for select
  using (true);

-- ── Products ──
create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  category_id uuid references public.categories(id),
  name text not null,
  description text,
  base_price numeric(10,2) not null,
  images text[] default '{}',
  fabric_options text[] default '{}',
  is_featured boolean default false,
  is_active boolean default true,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

alter table public.products enable row level security;

create policy "Products are publicly readable"
  on public.products for select
  using (is_active = true);

-- ── Seed Categories ──
insert into public.categories (name, slug, sort_order) values
  ('Shirts', 'shirts', 1),
  ('Trousers', 'trousers', 2),
  ('Suits', 'suits', 3),
  ('Kurtas', 'kurtas', 4),
  ('Sherwanis', 'sherwanis', 5),
  ('Blazers', 'blazers', 6)
on conflict (slug) do nothing;

-- ── Seed Products ──
insert into public.products (category_id, name, description, base_price, fabric_options, is_featured) values
  ((select id from public.categories where slug = 'shirts'), 'Classic Oxford Shirt', 'Timeless Oxford weave, perfect for office and casual wear.', 2499.00, '{"Cotton Oxford","Linen Blend","Supima Cotton"}', true),
  ((select id from public.categories where slug = 'shirts'), 'Mandarin Collar Shirt', 'Modern mandarin collar with a clean silhouette.', 2799.00, '{"Cotton Poplin","Chambray","Silk Blend"}', true),
  ((select id from public.categories where slug = 'shirts'), 'Linen Casual Shirt', 'Breathable linen for the Indian summer.', 2299.00, '{"Pure Linen","Cotton Linen","Khadi Linen"}', false),
  ((select id from public.categories where slug = 'trousers'), 'Tailored Chinos', 'Slim-fit chinos with a premium finish.', 2199.00, '{"Stretch Cotton","Cotton Twill","Linen Cotton"}', true),
  ((select id from public.categories where slug = 'trousers'), 'Formal Trousers', 'Sharp creased formal trousers for the boardroom.', 2699.00, '{"Wool Blend","Poly-Viscose","Terry Rayon"}', false),
  ((select id from public.categories where slug = 'suits'), 'Two-Piece Business Suit', 'Impeccably tailored two-piece suit.', 12999.00, '{"Merino Wool","Poly-Wool","Italian Linen"}', true),
  ((select id from public.categories where slug = 'kurtas'), 'Lucknowi Chikan Kurta', 'Hand-embroidered Lucknowi chikankari.', 3999.00, '{"Cotton Voile","Georgette","Modal Silk"}', true),
  ((select id from public.categories where slug = 'kurtas'), 'Silk Festive Kurta', 'Rich silk kurta for weddings and festivals.', 5499.00, '{"Raw Silk","Art Silk","Banarasi Silk"}', true),
  ((select id from public.categories where slug = 'sherwanis'), 'Royal Wedding Sherwani', 'Regal sherwani with intricate embroidery.', 18999.00, '{"Jacquard Silk","Brocade","Velvet"}', true),
  ((select id from public.categories where slug = 'blazers'), 'Casual Linen Blazer', 'Relaxed-fit linen blazer for summer evenings.', 5999.00, '{"Pure Linen","Cotton Linen","Khadi"}', false)
on conflict do nothing;
