-- =====================================================
-- VIVASAYI: Password Auth Migration (v2 - Safe Re-import)
-- Ethana thadava import pannalum error varaadhu
-- (IF NOT EXISTS - MariaDB support pannum, InfinityFree MariaDB 11.x OK)
-- =====================================================

-- 1. Password column (already iruntha skip aagum)
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS password_hash VARCHAR(255) NULL AFTER phone;

-- 2. API token column (already iruntha skip aagum)
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS api_token VARCHAR(64) NULL AFTER password_hash;

-- 3. Phone lookup fast-ah irukka index (already iruntha skip aagum)
ALTER TABLE users
  ADD INDEX IF NOT EXISTS idx_users_phone (phone);

-- Done! Ippo users table-la ithu ready:
--   phone | password_hash | api_token
