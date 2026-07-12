<?php

namespace App\Services;

use App\Config\Database;
use PDO;
use RuntimeException;

class AuthOtpService
{
    public function createOtpCode(int $userId, string $phone): array
    {
        $otpCode = str_pad((string) random_int(100000, 999999), 6, '0', STR_PAD_LEFT);
        $expiresAt = new \DateTimeImmutable('+5 minutes');

        $stmt = Database::getConnection()->prepare(
            'INSERT INTO auth_otps (user_id, phone, otp_code, expires_at, is_used)
             VALUES (:user_id, :phone, :otp_code, :expires_at, 0)'
        );

        $stmt->execute([
            'user_id' => $userId,
            'phone' => $phone,
            'otp_code' => $otpCode,
            'expires_at' => $expiresAt->format('Y-m-d H:i:s'),
        ]);

        $id = (int) Database::getConnection()->lastInsertId();
        if ($id === 0) {
            throw new RuntimeException('Failed to create OTP record.');
        }

        return [
            'id' => $id,
            'otp_code' => $otpCode,
            'expires_at' => $expiresAt->format('Y-m-d H:i:s'),
        ];
    }

    public function getLatestValidOtp(string $phone, string $otpCode): ?array
    {
        $stmt = Database::getConnection()->prepare(
            'SELECT * FROM auth_otps
             WHERE phone = :phone
               AND otp_code = :otp_code
               AND is_used = 0
               AND expires_at > NOW()
             ORDER BY created_at DESC
             LIMIT 1'
        );
        $stmt->execute([
            'phone' => $phone,
            'otp_code' => $otpCode,
        ]);

        $data = $stmt->fetch(PDO::FETCH_ASSOC);
        return $data ?: null;
    }

    public function markOtpUsed(int $otpId): void
    {
        $stmt = Database::getConnection()->prepare(
            'UPDATE auth_otps SET is_used = 1 WHERE id = :id'
        );
        $stmt->execute(['id' => $otpId]);
    }
}
