-- Seed data for Vivasayi AI Super App
-- Run against whichever database is already selected (see schema.sql note).

INSERT INTO users (uuid, name, email, phone, password_hash, role, language, is_active)
VALUES
('00000000-0000-0000-0000-000000000001', 'Admin User', 'admin@example.com', '9999999999', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'admin', 'en', 1)
ON DUPLICATE KEY UPDATE
name = VALUES(name),
email = VALUES(email),
password_hash = VALUES(password_hash),
role = VALUES(role),
language = VALUES(language),
is_active = VALUES(is_active);

INSERT INTO farmers (uuid, user_id, name, phone, email, district, state, postal_code)
VALUES
('10000000-0000-0000-0000-000000000001', 1, 'Ravi Kumar', '9888888888', 'ravi@example.com', 'Tiruvannamalai', 'Tamil Nadu', '606601')
ON DUPLICATE KEY UPDATE
user_id = VALUES(user_id),
name = VALUES(name),
phone = VALUES(phone),
email = VALUES(email),
district = VALUES(district),
state = VALUES(state),
postal_code = VALUES(postal_code);

INSERT INTO farms (farmer_id, uuid, farm_name, total_area, crop_type, soil_type, irrigation_type)
VALUES
(1, '20000000-0000-0000-0000-000000000001', 'Ravi Farm', 12.50, 'Paddy', 'Loamy', 'Drip Irrigation')
ON DUPLICATE KEY UPDATE
farmer_id = VALUES(farmer_id),
farm_name = VALUES(farm_name),
total_area = VALUES(total_area),
crop_type = VALUES(crop_type),
soil_type = VALUES(soil_type),
irrigation_type = VALUES(irrigation_type);
