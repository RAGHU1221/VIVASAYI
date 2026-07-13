<?php

namespace App\Services;

use App\Config\Database;
use PDO;

class PinService
{
    public function setPin(int $userId, string $pin): void
    {
        $stmt = Database::getConnection()->prepare(
            'UPDATE users SET pin_hash = :pin_hash WHERE id = :id'
        );
        $stmt->execute([
            'pin_hash' => password_hash($pin, PASSWORD_DEFAULT),
            'id' => $userId,
        ]);
    }

    public function verifyPin(int $userId, string $pin): bool
    {
        $stmt = Database::getConnection()->prepare(
            'SELECT pin_hash FROM users WHERE id = :id LIMIT 1'
        );
        $stmt->execute(['id' => $userId]);
        $hash = $stmt->fetchColumn();

        if (!is_string($hash) || $hash === '') {
            return false;
        }

        return password_verify($pin, $hash);
    }

    public function hasPin(int $userId): bool
    {
        $stmt = Database::getConnection()->prepare(
            'SELECT pin_hash FROM users WHERE id = :id LIMIT 1'
        );
        $stmt->execute(['id' => $userId]);
        $hash = $stmt->fetchColumn();

        return is_string($hash) && $hash !== '';
    }
}
