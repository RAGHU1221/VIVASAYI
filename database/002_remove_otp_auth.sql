-- Vivasayi: remove OTP authentication
-- Run this against an existing database that still has the auth_otps table.
-- Password login (users.password_hash) and PIN login (users.pin_hash) remain.

DROP TABLE IF EXISTS auth_otps;
