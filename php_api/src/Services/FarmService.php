<?php

namespace App\Services;

use App\Config\Database;
use App\Models\Farm;
use PDO;
use RuntimeException;

class FarmService
{
    public function getByFarmerId(int $farmerId): array
    {
        $stmt = Database::getConnection()->prepare('SELECT * FROM farms WHERE farmer_id = :farmer_id ORDER BY created_at DESC');
        $stmt->execute(['farmer_id' => $farmerId]);
        return array_map(fn(array $row) => new Farm($row), $stmt->fetchAll(PDO::FETCH_ASSOC));
    }

    public function create(array $payload): Farm
    {
        $stmt = Database::getConnection()->prepare(
            'INSERT INTO farms (farmer_id, uuid, farm_name, total_area, crop_type, soil_type, irrigation_type, status)
            VALUES (:farmer_id, :uuid, :farm_name, :total_area, :crop_type, :soil_type, :irrigation_type, :status)'
        );

        $stmt->execute([
            'farmer_id' => $payload['farmer_id'],
            'uuid' => $payload['uuid'],
            'farm_name' => $payload['farm_name'],
            'total_area' => $payload['total_area'],
            'crop_type' => $payload['crop_type'] ?? null,
            'soil_type' => $payload['soil_type'] ?? null,
            'irrigation_type' => $payload['irrigation_type'] ?? null,
            'status' => $payload['status'] ?? 'active',
        ]);

        $id = (int) Database::getConnection()->lastInsertId();
        $farm = $this->getById($id);

        if ($farm === null) {
            throw new RuntimeException('Failed to create farm record.');
        }

        return $farm;
    }

    public function getById(int $id): ?Farm
    {
        $stmt = Database::getConnection()->prepare('SELECT * FROM farms WHERE id = :id');
        $stmt->execute(['id' => $id]);
        $data = $stmt->fetch(PDO::FETCH_ASSOC);
        return $data ? new Farm($data) : null;
    }

    public function update(int $id, array $payload): ?Farm
    {
        $fields = [];
        $params = ['id' => $id];

        if (isset($payload['farm_name'])) {
            $fields[] = 'farm_name = :farm_name';
            $params['farm_name'] = $payload['farm_name'];
        }

        if (isset($payload['total_area'])) {
            $fields[] = 'total_area = :total_area';
            $params['total_area'] = $payload['total_area'];
        }

        if (array_key_exists('crop_type', $payload)) {
            $fields[] = 'crop_type = :crop_type';
            $params['crop_type'] = $payload['crop_type'];
        }

        if (array_key_exists('soil_type', $payload)) {
            $fields[] = 'soil_type = :soil_type';
            $params['soil_type'] = $payload['soil_type'];
        }

        if (array_key_exists('irrigation_type', $payload)) {
            $fields[] = 'irrigation_type = :irrigation_type';
            $params['irrigation_type'] = $payload['irrigation_type'];
        }

        if (empty($fields)) {
            return $this->getById($id);
        }

        $sql = 'UPDATE farms SET ' . implode(', ', $fields) . ', updated_at = CURRENT_TIMESTAMP WHERE id = :id';
        $stmt = Database::getConnection()->prepare($sql);
        $stmt->execute($params);

        return $this->getById($id);
    }

    public function delete(int $id): bool
    {
        $stmt = Database::getConnection()->prepare('DELETE FROM farms WHERE id = :id');
        return $stmt->execute(['id' => $id]);
    }
}
