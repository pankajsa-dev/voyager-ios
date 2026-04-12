-- ============================================================
-- Voyager — Supabase Schema
-- Run this in: Supabase Dashboard → SQL Editor → New query
-- ============================================================

-- ── Extensions ───────────────────────────────────────────────
create extension if not exists "uuid-ossp";

-- ── Profiles ─────────────────────────────────────────────────
-- Mirrors auth.users, populated on sign-up via trigger
create table public.profiles (
    id              uuid        primary key references auth.users(id) on delete cascade,
    name            text        not null default '',
    email           text        not null default '',
    avatar_url      text,
    home_city       text,
    bio             text,
    travel_prefs    text[]      default '{}',
    visited_countries text[]    default '{}',
    trips_completed int         not null default 0,
    created_at      timestamptz not null default now()
);
alter table public.profiles enable row level security;
create policy "Users can view own profile"   on public.profiles for select using (auth.uid() = id);
create policy "Users can update own profile" on public.profiles for update using (auth.uid() = id);

-- Auto-create profile on sign-up
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
    insert into public.profiles (id, name, email)
    values (
        new.id,
        coalesce(new.raw_user_meta_data->>'full_name', ''),
        coalesce(new.email, '')
    );
    return new;
end;
$$;
create trigger on_auth_user_created
    after insert on auth.users
    for each row execute procedure public.handle_new_user();

-- ── Destinations ─────────────────────────────────────────────
-- Curated list (read-only for users, admin-managed)
create table public.destinations (
    id                  uuid        primary key default uuid_generate_v4(),
    name                text        not null,
    country             text        not null,
    country_code        char(2)     not null,
    continent           text        not null,
    tagline             text        not null default '',
    overview            text        not null default '',
    category            text        not null,
    tags                text[]      default '{}',
    image_urls          text[]      default '{}',
    rating              numeric(3,2) not null default 0,
    review_count        int         not null default 0,
    latitude            double precision not null,
    longitude           double precision not null,
    best_months         int[]       default '{}',
    avg_budget_per_day  numeric(10,2) not null default 0,
    currency            char(3)     not null default 'USD',
    language            text        not null default '',
    timezone            text        not null default '',
    created_at          timestamptz not null default now()
);
alter table public.destinations enable row level security;
create policy "Anyone can view destinations" on public.destinations for select using (true);

-- ── Saved destinations (user wishlist) ───────────────────────
create table public.saved_destinations (
    id              uuid        primary key default uuid_generate_v4(),
    user_id         uuid        not null references auth.users(id) on delete cascade,
    destination_id  uuid        not null references public.destinations(id) on delete cascade,
    created_at      timestamptz not null default now(),
    unique (user_id, destination_id)
);
alter table public.saved_destinations enable row level security;
create policy "Users manage own saved destinations" on public.saved_destinations
    using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ── Trips ─────────────────────────────────────────────────────
create table public.trips (
    id                  uuid        primary key default uuid_generate_v4(),
    user_id             uuid        not null references auth.users(id) on delete cascade,
    title               text        not null,
    destination_id      uuid        references public.destinations(id),
    destination_name    text        not null,
    cover_image_url     text,
    start_date          date        not null,
    end_date            date        not null,
    status              text        not null default 'Upcoming',
    notes               text        not null default '',
    itinerary_days      jsonb       not null default '[]',
    total_budget        numeric(12,2) not null default 0,
    currency            char(3)     not null default 'USD',
    is_shared           boolean     not null default false,
    created_at          timestamptz not null default now(),
    updated_at          timestamptz not null default now()
);
alter table public.trips enable row level security;
create policy "Users manage own trips" on public.trips
    using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ── Bookings ──────────────────────────────────────────────────
create table public.bookings (
    id                  uuid        primary key default uuid_generate_v4(),
    user_id             uuid        not null references auth.users(id) on delete cascade,
    trip_id             uuid        references public.trips(id) on delete set null,
    type                text        not null,
    status              text        not null default 'Confirmed',
    title               text        not null,
    provider_name       text        not null default '',
    booking_reference   text        not null default '',
    confirmation_number text        not null default '',
    start_date          timestamptz not null,
    end_date            timestamptz,
    total_price         numeric(12,2) not null default 0,
    currency            char(3)     not null default 'USD',
    passenger_names     text[]      default '{}',
    document_urls       text[]      default '{}',
    notes               text        not null default '',
    created_at          timestamptz not null default now()
);
alter table public.bookings enable row level security;
create policy "Users manage own bookings" on public.bookings
    using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ── Expenses ──────────────────────────────────────────────────
create table public.expenses (
    id              uuid        primary key default uuid_generate_v4(),
    user_id         uuid        not null references auth.users(id) on delete cascade,
    trip_id         uuid        not null references public.trips(id) on delete cascade,
    title           text        not null,
    amount          numeric(12,2) not null,
    currency        char(3)     not null default 'USD',
    category        text        not null,
    date            date        not null default current_date,
    notes           text        not null default '',
    receipt_url     text,
    created_at      timestamptz not null default now()
);
alter table public.expenses enable row level security;
create policy "Users manage own expenses" on public.expenses
    using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ── Packing items ─────────────────────────────────────────────
create table public.packing_items (
    id              uuid        primary key default uuid_generate_v4(),
    user_id         uuid        not null references auth.users(id) on delete cascade,
    trip_id         uuid        not null references public.trips(id) on delete cascade,
    name            text        not null,
    category        text        not null,
    quantity        int         not null default 1,
    is_packed       boolean     not null default false,
    is_essential    boolean     not null default false,
    created_at      timestamptz not null default now()
);
alter table public.packing_items enable row level security;
create policy "Users manage own packing items" on public.packing_items
    using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ── Seed: sample destinations ─────────────────────────────────
insert into public.destinations (name, country, country_code, continent, tagline, overview, category, tags, image_urls, rating, review_count, latitude, longitude, best_months, avg_budget_per_day, currency, language, timezone) values
('Paris',       'France',      'FR', 'Europe',    'The City of Light', 'Romance, art, and world-class cuisine await in the French capital.', 'City',      '{"Food","Art","Romance","Shopping"}', '{}', 4.8, 12400, 48.8566,   2.3522,  '{4,5,6,9,10}',    180, 'EUR', 'French',   'Europe/Paris'),
('Bali',        'Indonesia',   'ID', 'Asia',      'Island of the Gods', 'Lush rice terraces, ancient temples, and stunning beaches.',          'Beach',     '{"Temples","Surfing","Wellness","Nature"}', '{}', 4.7, 18900, -8.4095, 115.1889, '{4,5,6,7,8,9}',   80,  'IDR', 'Balinese', 'Asia/Makassar'),
('Tokyo',       'Japan',       'JP', 'Asia',      'Neon and Tradition', 'A dazzling metropolis where ancient temples meet futuristic tech.',   'City',      '{"Food","Technology","Culture","Anime"}', '{}', 4.9, 22100, 35.6762, 139.6503, '{3,4,10,11}',     150, 'JPY', 'Japanese', 'Asia/Tokyo'),
('Santorini',   'Greece',      'GR', 'Europe',    'Jewel of the Aegean','Iconic whitewashed villages perched on dramatic volcanic cliffs.',    'Beach',     '{"Views","Wine","Sunsets","Sailing"}', '{}', 4.8, 9800, 36.3932,  25.4615,  '{5,6,7,8,9}',     200, 'EUR', 'Greek',    'Europe/Athens'),
('New York',    'USA',         'US', 'Americas',  'The City That Never Sleeps', 'Skyscrapers, world-class museums, Broadway, and Central Park.','City',  '{"Food","Culture","Shopping","Art"}', '{}', 4.7, 31200, 40.7128, -74.0060, '{4,5,6,9,10,11}', 250, 'USD', 'English',  'America/New_York'),
('Machu Picchu','Peru',        'PE', 'Americas',  'Lost City of the Incas','Ancient Incan citadel set high in the Andes Mountains.',          'Adventure', '{"History","Hiking","Mountains","Culture"}','{}', 4.9, 14300, -13.1631,-72.5450, '{5,6,7,8,9}',     120, 'PEN', 'Spanish',  'America/Lima'),
('Kyoto',       'Japan',       'JP', 'Asia',      'Soul of Japan',      'Thousands of classical Buddhist temples and stunning bamboo groves.', 'Culture',   '{"Temples","Gardens","Tea","History"}', '{}', 4.8, 16700, 35.0116, 135.7681, '{3,4,10,11}',     130, 'JPY', 'Japanese', 'Asia/Tokyo'),
('Maldives',    'Maldives',    'MV', 'Asia',      'Paradise on Earth',  'Crystal-clear lagoons, coral reefs, and overwater bungalows.',       'Beach',     '{"Diving","Snorkeling","Luxury","Romance"}','{}', 4.9, 8700, 3.2028, 73.2207,  '{11,12,1,2,3,4}', 350, 'MVR', 'Dhivehi',  'Indian/Maldives');
