-- OpenPianos — Postgres schema (Neon).
-- Matches spec/SCHEMA.md and PLAN.md's data-model section. Applied per branch
-- (main = openpianos.net, dev = dev.openpianos.net). PostGIS optional for now:
-- lat/lon b-tree indexes carry a 20k-row map fine; enable postgis when
-- ambassador polygon queries move server-side.

create table venues (
  id         text primary key,
  name       text not null,
  lat        double precision,
  lon        double precision,
  website    text,
  hours      text,
  operator_account text, -- verified claim (FK added after accounts below)
  created_at timestamptz not null default now()
);

create table pianos (
  id             text primary key,              -- permanent opaque id (slug); never reused
  name           text not null,
  lat            double precision not null,
  lon            double precision not null,
  address        text,
  city           text,
  region         text,
  country        text,
  venue_id       text references venues(id),
  access         text not null default 'public' check (access in ('public','bookable','ask')),
  hours          text,
  status         text not null default 'active' check (status in ('active','temporary','needs_verification','removed')),
  active_from    date,
  active_until   date,
  instrument     text,
  notes          text,
  canonical      boolean not null default false, -- ambassador-verified into the open dataset
  protected      boolean not null default false, -- ambassador-only editing (wiki page protection)
  merged_into    text references pianos(id),     -- redirect at read time; id keeps resolving
  created_by     text,                           -- account id or anon identity id
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  last_verified_at timestamptz,                  -- cache over verifications
  last_verified_by text
);
create index pianos_geo on pianos (lat, lon);
create index pianos_canonical on pianos (canonical) where merged_into is null;
create index pianos_country on pianos (country);

-- wiki history: one row per change, MediaWiki-style full snapshots.
-- revert = write an old snapshot as a NEW revision; history is append-only.
create table revisions (
  id         bigint generated always as identity primary key,
  piano_id   text not null references pianos(id),
  actor      text,                                -- account id
  anon_id    text,                                -- cookie-backed temporary identity
  kind       text not null check (kind in ('create','edit','revert','status','merge','protect')),
  snapshot   jsonb not null,                      -- the full piano record at this revision
  note       text,
  created_at timestamptz not null default now()
);
create index revisions_piano on revisions (piano_id, created_at desc);
create index revisions_feed on revisions (created_at desc);

-- the freshness stream, separate from edits. a partner app's QR-verified
-- visit arrives here through the write API.
create table verifications (
  id         bigint generated always as identity primary key,
  piano_id   text not null references pianos(id),
  verdict    text not null check (verdict in ('present','gone')),
  method     text not null check (method in ('gps','qr','photo','phone','operator','api')),
  actor      text,
  anon_id    text,
  source     text not null default 'site',        -- site | partner app slug
  lat        double precision,                    -- where the verifier stood
  lon        double precision,
  created_at timestamptz not null default now()
);
create index verifications_piano on verifications (piano_id, created_at desc);
create index verifications_feed on verifications (created_at desc);

create table accounts (
  id            text primary key,                 -- username
  display       text,
  email         text unique,
  email_verified boolean not null default false,
  pw_salt       text,
  pw_hash       text,
  google_sub    text unique,
  apple_sub     text unique,
  role          text not null default 'contributor' check (role in ('contributor','ambassador','admin')),
  created_at    timestamptz not null default now()
);

-- Wikipedia-style temporary identities for signed-out contributors:
-- attribution + rate limiting without storing raw IPs.
create table anon_identities (
  id         text primary key,                    -- random token, cookie-backed
  created_at timestamptz not null default now(),
  last_seen  timestamptz not null default now()
);

-- one row per (account, scope); multiple ambassadors per scope = multiple rows.
create table ambassadors (
  id         bigint generated always as identity primary key,
  account_id text not null references accounts(id),
  scope_type text not null check (scope_type in ('piano','venue','city','region','country')),
  scope_ref  text not null,                       -- piano id, venue id, or place name
  status     text not null default 'requested' check (status in ('requested','approved','revoked')),
  color      text,
  why        text,
  created_at timestamptz not null default now(),
  approved_at timestamptz,
  unique (account_id, scope_type, scope_ref)
);
create index ambassadors_scope on ambassadors (scope_type, scope_ref) where status = 'approved';

create table comments (
  id         bigint generated always as identity primary key,
  piano_id   text not null references pianos(id),
  actor      text,
  anon_id    text,
  body       text not null,
  hidden     boolean not null default false,
  created_at timestamptz not null default now()
);
create index comments_piano on comments (piano_id, created_at desc);

create table media (
  id         bigint generated always as identity primary key,
  piano_id   text not null references pianos(id),
  r2_key     text not null,
  kind       text not null check (kind in ('photo','video')),
  poster_key text,
  actor      text,
  anon_id    text,
  moderation text not null default 'pending' check (moderation in ('pending','approved','rejected')),
  created_at timestamptz not null default now()
);
create index media_piano on media (piano_id, created_at desc);

-- import crosswalk: re-imports update the same piano instead of duplicating,
-- and hand-merges survive every re-sync.
create table piano_sources (
  piano_id   text not null references pianos(id),
  source     text not null,                       -- e.g. 'pianos.pub', 'osm'
  source_ref text not null,
  primary key (source, source_ref)
);
create index piano_sources_piano on piano_sources (piano_id);

-- Derived, not stored:
--  * canonical exports (GeoJSON/CSV/SQLite) = select from pianos
--    where canonical and merged_into is null;
--  * the API changes feed = revisions + verifications by created_at with a cursor.

alter table venues add constraint venues_operator_fk foreign key (operator_account) references accounts(id);
