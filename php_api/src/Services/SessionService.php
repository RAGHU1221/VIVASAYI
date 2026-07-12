<?php

namespace App\Services;

use App\Config\Database;
use PDO;
use RuntimeException;

class SessionService
{
    public function createSession(int $userId, string $jwtToken, string $expiresAt, ?string $deviceInfo = null, ?string $ipAddress = null): int
    {
        $stmt = Database::getConnection()->prepare(
            'INSERT INTO sessions (user_id, jwt_token, device_info, ip_address, expires_at, is_revoked)
             VALUES (:user_id, :jwt_token, :device_info, :ip_address, :expires_at, 0)'
        );

        $stmt->execute([
            'user_id' => $userId,
            'jwt_token' => $jwtToken,
            'device_info' => $deviceInfo,
            'ip_address' => $ipAddress,
            'expires_at' => $expiresAt,
        ]);

        $id = (int) Database::getConnection()->lastInsertId();
        if ($id === 0) {
            throw new RuntimeException('Failed to create session record.');
        }

        return $id;
    }

    public function getSessionByToken(string $jwtToken): ?array
    {
        $stmt = Database::getConnection()->prepare(
            'SELECT * FROM sessions WHERE jwt_token = :jwt_token AND is_revoked = 0 AND expires_at > NOW() LIMIT 1'
        );
        $stmt->execute(['jwt_token' => $jwtToken]);
        $data = $stmt->fetch(PDO::FETCH_ASSOC);
        return $data ?: null;
    }

    public function getActiveSessionsForUser(int $userId): array
    {
        $stmt = Database::getConnection()->prepare(
            'SELECT * FROM sessions WHERE user_id = :user_id AND is_revoked = 0 AND expires_at > NOW() ORDER BY created_at DESC'
        );
        $stmt->execute(['user_id' => $userId]);
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }

    public function revokeSession(int $sessionId, int $userId): bool
    {
        $stmt = Database::getConnection()->prepare(
            'UPDATE sessions SET is_revoked = 1 WHERE id = :id AND user_id = :user_id'
        );
        $stmt->execute(['id' => $sessionId, 'user_id' => $userId]);
        return $stmt->rowCount() > 0;
    }
}
