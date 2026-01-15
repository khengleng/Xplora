DROP INDEX IF EXISTS idx_users_username_active;
ALTER TABLE users DROP COLUMN IF EXISTS password_hash;
