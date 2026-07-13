<?php

namespace App\Services;

use App\Config\Database;
use App\Models\User;
use PDO;
use RuntimeException;

class UserService
{
    public function getAll(): array
    {
        $stmt = Database::getConnection()->prepare('SELECT * FROM users ORDER BY created_at DESC');
        $stmt->execute();
        return array_map(fn(array $row) => new User($row), $stmt->fetchAll(PDO::FETCH_ASSOC));
    }

    public function getByPhone(string $phone): ?User
    {
        $stmt = Database::getConnection()->prepare('SELECT * FROM users WHERE phone = :phone LIMIT 1');
        $stmt->execute(['phone' => $phone]);
        $data = $stmt->fetch(PDO::FETCH_ASSOC);
        return $data ? new User($data) : null;
    }

    public function create(array $payload): User
    {
        $stmt = Database::getConnection()->prepare(
            'INSERT INTO users (uuid, name, email, phone, password_hash, role, language, is_active)
            VALUES (:uuid, :name, :email, :phone, :password_hash, :role, :language, :is_active)'
        );

        $stmt->execute([
            'uuid' => $payload['uuid'],
            'name' => $payload['name'],
            'email' => $payload['email'] ?? null,
            'phone' => $payload['phone'],
            'password_hash' => $payload['password_hash'] ?? null,
            'role' => $payload['role'] ?? 'user',
            'language' => $payload['language'] ?? 'en',
            'is_active' => $payload['is_active'] ?? 1,
        ]);

        $id = (int) Database::getConnection()->lastInsertId();
        $user = $this->getById($id);

        if ($user === null) {
            throw new RuntimeException('Failed to create user.');
        }

        return $user;
    }

    public function getById(int $id): ?User
    {
        $stmt = Database::getConnection()->prepare('SELECT * FROM users WHERE id = :id LIMIT 1');
        $stmt->execute(['id' => $id]);
        $data = $stmt->fetch(PDO::FETCH_ASSOC);
        return $data ? new User($data) : null;
    }
}
