-- Phase 1: game_zones + checkpoints. Map content only — no match state, no
-- coordinates that identify a *player*. Read-only to clients (grants/policies
-- below never add insert/update/delete), matching the Data model table:
-- Realtime? no. Client writes? no.
--
-- No PostGIS: boundary/excluded-area geometry is stored as plain GeoJSON in
-- jsonb and rendered client-side. Point-in-polygon and radius checks (later,
-- Phase 7 checkpoint capture) are a ~12-line haversine_m() away — an
-- extension would be overkill for under ten checkpoints (see plan:
-- Explicitly not built).

create table public.game_zones (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  description text not null default '',
  recommended_players text not null default '',
  -- GeoJSON Polygon: {"type":"Polygon","coordinates":[[[lng,lat], ...]]}
  boundary_polygon jsonb not null,
  -- array of {"reason": text, "polygon": <GeoJSON Polygon>} — kept flat
  -- rather than full GeoJSON Feature objects, since nothing here needs to
  -- round-trip through a general GeoJSON toolchain.
  excluded_areas jsonb not null default '[]'::jsonb,
  -- Every gameplay number lives here, snapshotted onto matches.config at
  -- match creation (see plan: Data model). Keys match the plan's canonical
  -- list; transport_cooldown_ms is enriched with max_stations/max_stops
  -- alongside cooldown_ms per role/mode — the plan only named the top-level
  -- key, and jsonb absorbs the richer shape without a migration.
  config jsonb not null,
  created_at timestamptz not null default now()
);

create table public.checkpoints (
  id uuid primary key default gen_random_uuid(),
  zone_id uuid not null references public.game_zones(id) on delete cascade,
  name text not null,
  description text not null default '',
  category text not null check (
    category in ('landmark', 'park', 'transport_interchange', 'hawker_centre', 'public_plaza', 'attraction')
  ),
  lat double precision not null,
  lng double precision not null,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create index checkpoints_zone_id_idx on public.checkpoints (zone_id, sort_order);

alter table public.game_zones enable row level security;
alter table public.checkpoints enable row level security;

-- Map content carries no privacy concern — every authenticated (including
-- anonymous) user may browse zones before joining a match. RLS is used here
-- for consistency with the rest of the schema's "RLS is the sole boundary"
-- invariant, even though a bare grant would behave identically for a table
-- with no per-row sensitivity.
create policy "game_zones readable by authenticated" on public.game_zones
  for select to authenticated using (true);

create policy "checkpoints readable by authenticated" on public.checkpoints
  for select to authenticated using (true);

grant select on public.game_zones to authenticated;
grant select on public.checkpoints to authenticated;

-- ---------------------------------------------------------------------------
-- Seed: MANHUNT: CENTRAL — the real Alpha map (PRD §7). Provisional boundary
-- and checkpoints per plan Open Question #2: expect to redraw after the
-- first walk. Config values are the PRD §4 Alpha recommendations.
-- ---------------------------------------------------------------------------

insert into public.game_zones (slug, name, description, recommended_players, boundary_polygon, excluded_areas, config)
values (
  'manhunt_central',
  'MANHUNT: CENTRAL',
  'Civic District, Bras Basah and the Marina Bay fringe. Provisional boundary — expect to redraw after the first field test.',
  '3-8',
  '{
    "type": "Polygon",
    "coordinates": [[
      [103.8400, 1.2790],
      [103.8590, 1.2790],
      [103.8590, 1.2970],
      [103.8400, 1.2970],
      [103.8400, 1.2790]
    ]]
  }'::jsonb,
  '[{
    "reason": "Central Expressway corridor — not safely walkable, excluded for gameplay.",
    "polygon": {
      "type": "Polygon",
      "coordinates": [[
        [103.8415, 1.2798],
        [103.8432, 1.2798],
        [103.8432, 1.2818],
        [103.8415, 1.2818],
        [103.8415, 1.2798]
      ]]
    }
  }]'::jsonb,
  '{
    "match_duration_ms": 5400000,
    "head_start_ms": 600000,
    "reveal_interval_ms": 300000,
    "reveal_grace_ms": 60000,
    "reveal_precision_m": 50,
    "checkpoints_required": 3,
    "checkpoint_radius_m": 50,
    "checkpoint_dwell_ms": 60000,
    "checkpoint_min_samples": 3,
    "checkpoint_visibility": "count_only",
    "transport_cooldown_ms": {
      "runner": {
        "mrt": {"max_stations": 2, "cooldown_ms": 1200000},
        "bus": {"max_stops": 3, "cooldown_ms": 1200000}
      },
      "hunter": {
        "mrt": {"max_stations": 3, "cooldown_ms": 900000},
        "bus": {"max_stops": 4, "cooldown_ms": 900000}
      }
    },
    "runner_transport_visibility": "hidden",
    "sample_interval_ms": 15000,
    "max_dark_ms": 1200000,
    "capture_confirm_timeout_ms": 60000,
    "sample_retention_days": 7
  }'::jsonb
)
on conflict (slug) do nothing;

insert into public.checkpoints (zone_id, name, description, category, lat, lng, sort_order)
select z.id, c.name, c.description, c.category, c.lat, c.lng, c.sort_order
from public.game_zones z
cross join (values
  ('National Gallery Singapore', 'Landmark — former Supreme Court & City Hall building.', 'landmark', 1.2903, 103.8517, 1),
  ('Fort Canning Park', 'Park atop Fort Canning Hill.', 'park', 1.2954, 103.8455, 2),
  ('City Hall MRT Interchange', 'Transport interchange — North-South / East-West lines.', 'transport_interchange', 1.2931, 103.8520, 3),
  ('Chinatown Complex Market & Food Centre', 'Hawker centre.', 'hawker_centre', 1.2820, 103.8437, 4),
  ('Raffles Place Park', 'Public plaza in the financial district.', 'public_plaza', 1.2838, 103.8511, 5),
  ('Clarke Quay', 'Riverside entertainment district.', 'attraction', 1.2906, 103.8460, 6)
) as c(name, description, category, lat, lng, sort_order)
where z.slug = 'manhunt_central'
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- Seed: TEST_ZONE — tiny area + compressed timings so the Dart integration
-- suite (test/server/) can run a full match in ~3 minutes of real time (see
-- plan: Verification). Not meant to be walked; only ever driven by
-- SimulatedLocationProvider or the server test suite's direct RPC calls.
-- ---------------------------------------------------------------------------

insert into public.game_zones (slug, name, description, recommended_players, boundary_polygon, excluded_areas, config)
values (
  'test_zone',
  'TEST_ZONE',
  'Automated-test-only zone: compressed timings, tiny area.',
  '1-4',
  '{
    "type": "Polygon",
    "coordinates": [[
      [103.8510, 1.2895],
      [103.8525, 1.2895],
      [103.8525, 1.2910],
      [103.8510, 1.2910],
      [103.8510, 1.2895]
    ]]
  }'::jsonb,
  '[]'::jsonb,
  '{
    "match_duration_ms": 180000,
    "head_start_ms": 10000,
    "reveal_interval_ms": 15000,
    "reveal_grace_ms": 5000,
    "reveal_precision_m": 100,
    "checkpoints_required": 1,
    "checkpoint_radius_m": 30,
    "checkpoint_dwell_ms": 5000,
    "checkpoint_min_samples": 1,
    "checkpoint_visibility": "count_only",
    "transport_cooldown_ms": {
      "runner": {
        "mrt": {"max_stations": 2, "cooldown_ms": 20000},
        "bus": {"max_stops": 3, "cooldown_ms": 20000}
      },
      "hunter": {
        "mrt": {"max_stations": 3, "cooldown_ms": 15000},
        "bus": {"max_stops": 4, "cooldown_ms": 15000}
      }
    },
    "runner_transport_visibility": "hidden",
    "sample_interval_ms": 2000,
    "max_dark_ms": 30000,
    "capture_confirm_timeout_ms": 10000,
    "sample_retention_days": 1
  }'::jsonb
)
on conflict (slug) do nothing;

insert into public.checkpoints (zone_id, name, description, category, lat, lng, sort_order)
select z.id, c.name, c.description, c.category, c.lat, c.lng, c.sort_order
from public.game_zones z
cross join (values
  ('Test Checkpoint A', 'Automated-test checkpoint.', 'landmark', 1.2900, 103.8515, 1),
  ('Test Checkpoint B', 'Automated-test checkpoint.', 'landmark', 1.2905, 103.8520, 2)
) as c(name, description, category, lat, lng, sort_order)
where z.slug = 'test_zone'
on conflict do nothing;
