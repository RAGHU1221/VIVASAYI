<?php

namespace App\Services;

use App\Config\Database;
use App\Models\Farmer;
use PDO;
use RuntimeException;

class FarmerService
{
    public function getAll(): array
    {
        $stmt = Database::getConnection()->prepare('SELECT * FROM farmers ORDER BY created_at DESC');
        $stmt->execute();
        return array_map(fn(array $row) => new Farmer($row), $stmt->fetchAll(PDO::FETCH_ASSOC));
    }

    public function getById(int $id): ?Farmer
    {
        $stmt = Database::getConnection()->prepare('SELECT * FROM farmers WHERE id = :id');
        $stmt->execute(['id' => $id]);
        $data = $stmt->fetch(PDO::FETCH_ASSOC);
        return $data ? new Farmer($data) : null;
    }

    public function getByUserId(int $userId): ?Farmer
    {
        $stmt = Database::getConnection()->prepare('SELECT * FROM farmers WHERE user_id = :user_id LIMIT 1');
        $stmt->execute(['user_id' => $userId]);
        $data = $stmt->fetch(PDO::FETCH_ASSOC);
        return $data ? new Farmer($data) : null;
    }

    public function create(array $payload): Farmer
    {
        $stmt = Database::getConnection()->prepare(
            'INSERT INTO farmers (uuid, user_id, name, phone, email, dob, gender, address, district, state, postal_code)
            VALUES (:uuid, :user_id, :name, :phone, :email, :dob, :gender, :address, :district, :state, :postal_code)'
        );

        $stmt->execute([
            'uuid' => $payload['uuid'],
            'user_id' => $payload['user_id'] ?? null,
            'name' => $payload['name'],
            'phone' => $payload['phone'],
            'email' => $payload['email'] ?? null,
            'dob' => $payload['dob'] ?? null,
            'gender' => $payload['gender'] ?? 'male',
            'address' => $payload['address'] ?? null,
            'district' => $payload['district'] ?? null,
            'state' => $payload['state'] ?? null,
            'postal_code' => $payload['postal_code'] ?? null,
        ]);

        $id = (int) Database::getConnection()->lastInsertId();
        $farmer = $this->getById($id);

        if ($farmer === null) {
            throw new RuntimeException('Failed to create farmer record.');
        }

        return $farmer;
    }
}
