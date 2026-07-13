<?php

namespace App\Services;

use App\Config\Database;
use PDO;
use RuntimeException;

class AuditLogService
{
    public function createLog(?int $userId, string $action, ?array $context = null, ?string $ipAddress = null): int
    {
        $stmt = Database::getConnection()->prepare(
            'INSERT INTO audit_logs (user_id, action, context, ip_address)
             VALUES (:user_id, :action, :context, :ip_address)'
        );

        $stmt->execute([
            'user_id' => ($userId !== null && $userId > 0) ? $userId : null,
            'action' => $action,
            'context' => $context !== null ? json_encode($context, JSON_UNESCAPED_UNICODE) : null,
            'ip_address' => $ipAddress,
        ]);

        $id = (int) Database::getConnection()->lastInsertId();
        if ($id === 0) {
            throw new RuntimeException('Failed to create audit log entry.');
        }

        return $id;
    }

    public function getAll(int $limit = 50, int $offset = 0): array
    {
        $stmt = Database::getConnection()->prepare(
            'SELECT * FROM audit_logs ORDER BY created_at DESC LIMIT :limit OFFSET :offset'
        );
        $stmt->bindValue('limit', $limit, PDO::PARAM_INT);
        $stmt->bindValue('offset', $offset, PDO::PARAM_INT);
        $stmt->execute();

        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }

    public function getByUserId(int $userId, int $limit = 50, int $offset = 0): array
    {
        $stmt = Database::getConnection()->prepare(
            'SELECT * FROM audit_logs WHERE user_id = :user_id ORDER BY created_at DESC LIMIT :limit OFFSET :offset'
        );
        $stmt->bindValue('user_id', $userId, PDO::PARAM_INT);
        $stmt->bindValue('limit', $limit, PDO::PARAM_INT);
        $stmt->bindValue('offset', $offset, PDO::PARAM_INT);
        $stmt->execute();

        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }
}
