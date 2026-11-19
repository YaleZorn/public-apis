create table if not exists subscriptions (
  user_id bigint primary key references users(id) on delete cascade,
  email text not null,
  stripe_customer_id text unique,
  stripe_subscription_id text unique,
  status text not null default 'inactive',
  price_id text not null default '',
  current_period_end timestamptz,
  cancel_at_period_end boolean not null default false,
  updated_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index if not exists subscriptions_email_idx on subscriptions (email);
create index if not exists subscriptions_status_idx on subscriptions (status);
create index if not exists subscriptions_customer_idx on subscriptions (stripe_customer_id);
