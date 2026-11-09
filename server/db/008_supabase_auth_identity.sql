-- Supabase Auth owns passwords when AUTH_PROVIDER=supabase.
-- Keep app_users.id equal to auth.users.id; do not store Supabase passwords here.
ALTER TABLE app_users ALTER COLUMN password_hash DROP NOT NULL;
