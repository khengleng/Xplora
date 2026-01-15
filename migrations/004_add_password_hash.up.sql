-- Add password_hash column to users table
ALTER TABLE users ADD COLUMN IF NOT EXISTS password_hash VARCHAR(255);

-- Create index for faster username lookups during login
CREATE INDEX IF NOT EXISTS idx_users_username_active ON users(username, is_active, is_locked) WHERE is_active = true AND is_locked = false;
