alter table pro_tokens add column if not exists expires_at timestamptz;

update pro_tokens
set expires_at = created_at + interval '7 days'
where expires_at is null;

create index if not exists pro_tokens_expires_at_idx on pro_tokens (expires_at);
