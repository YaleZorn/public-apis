alter table waitlist add column if not exists confirm_expires_at timestamptz;

-- Expire any outstanding magic-link tokens (force re-request).
update waitlist
set confirm_expires_at = now() - interval '1 minute'
where confirm_token is not null and confirm_expires_at is null;
