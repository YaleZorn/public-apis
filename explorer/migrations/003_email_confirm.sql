alter table waitlist add column if not exists confirm_token text;
alter table waitlist add column if not exists confirmed_at timestamptz;

create unique index if not exists waitlist_confirm_token_uidx
  on waitlist (confirm_token)
  where confirm_token is not null;

create table if not exists rate_limits (
  bucket_key text primary key,
  window_start timestamptz not null,
  hit_count int not null default 0
);
