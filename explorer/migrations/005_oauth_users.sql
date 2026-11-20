create table if not exists users (
  id bigserial primary key,
  email text unique,
  name text not null default '',
  avatar_url text not null default '',
  created_at timestamptz not null default now(),
  last_login_at timestamptz not null default now()
);

create table if not exists oauth_accounts (
  provider text not null,
  provider_user_id text not null,
  user_id bigint not null references users(id) on delete cascade,
  raw_email text,
  created_at timestamptz not null default now(),
  primary key (provider, provider_user_id)
);

create table if not exists sessions (
  token_hash text primary key,
  user_id bigint not null references users(id) on delete cascade,
  expires_at timestamptz not null,
  created_at timestamptz not null default now()
);

create index if not exists sessions_user_id_idx on sessions (user_id);
create index if not exists sessions_expires_at_idx on sessions (expires_at);

create table if not exists oauth_states (
  state text primary key,
  provider text not null,
  code_verifier text,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null
);
