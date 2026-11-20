alter table stacks add column if not exists expires_at timestamptz;

update stacks
set expires_at = created_at + interval '7 days'
where expires_at is null;

create table if not exists pro_tokens (
  token text primary key,
  email text not null,
  created_at timestamptz not null default now()
);

create index if not exists pro_tokens_email_idx on pro_tokens (email);
create index if not exists stacks_expires_at_idx on stacks (expires_at);
