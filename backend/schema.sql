create extension if not exists pgcrypto;

create table if not exists users (
  id text primary key,
  apple_user_identifier text unique,
  email text,
  display_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table users add column if not exists email text;

create table if not exists form_analysis_records (
  id uuid primary key default gen_random_uuid(),
  user_id text not null references users(id) on delete cascade,
  schema_version integer not null default 1,
  local_identifier text not null,
  analyzed_at timestamptz not null,
  exercise_name text not null,
  exercise_type text not null check (exercise_type in ('squat', 'deadlift', 'bench_press')),
  video_duration double precision not null check (video_duration >= 0),
  source_platform text not null check (source_platform in ('ios', 'watchos', 'android', 'huawei')),
  score integer not null check (score between 0 and 100),
  issues jsonb not null default '[]'::jsonb,
  metrics jsonb not null default '[]'::jsonb,
  recommendation text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, local_identifier)
);

create index if not exists idx_form_analysis_records_user_analyzed_at
  on form_analysis_records (user_id, analyzed_at desc);

create index if not exists idx_form_analysis_records_user_exercise_type
  on form_analysis_records (user_id, exercise_type);
