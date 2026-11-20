alter table waitlist add column if not exists confirm_sent_at timestamptz;
alter table waitlist add column if not exists last_confirm_ip text;

alter table stacks add column if not exists creator_key text;

create table if not exists mail_quota (
  day date primary key,
  sent int not null default 0
);

create table if not exists feedback (
  id bigserial primary key,
  created_at timestamptz not null default now(),
  email text,
  message text not null,
  category text not null default 'general',
  client_key text,
  status text not null default 'new'
);

create index if not exists feedback_created_at_idx on feedback (created_at desc);
create index if not exists stacks_creator_key_idx on stacks (creator_key);
create index if not exists rate_limits_window_start_idx on rate_limits (window_start);
