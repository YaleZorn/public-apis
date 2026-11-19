create table if not exists waitlist (
  email text primary key,
  created_at timestamptz not null default now(),
  source text not null default 'web'
);

create table if not exists stacks (
  code text primary key,
  items jsonb not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists stacks_updated_at_idx on stacks (updated_at desc);
