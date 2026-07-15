<?php

namespace App\Services;

use App\Config\Database;
use App\Models\FamilyMember;
use PDO;
use RuntimeException;

class FamilyMemberService
{
    public function getByFarmerId(int $farmerId): array
    {
        $stmt = Database::getConnection()->prepare('SELECT * FROM family_members WHERE farmer_id = :farmer_id ORDER BY created_at DESC');
        $stmt->execute(['farmer_id' => $farmerId]);
        return array_map(fn(array $row) => new FamilyMember($row), $stmt->fetchAll(PDO::FETCH_ASSOC));
    }

    public function create(array $payload): FamilyMember
    {
        $stmt = Database::getConnection()->prepare(
            'INSERT INTO family_members (farmer_id, name, relationship, dob, gender, mobile)
            VALUES (:farmer_id, :name, :relationship, :dob, :gender, :mobile)'
        );

        $stmt->execute([
            'farmer_id' => $payload['farmer_id'],
            'name' => $payload['name'],
            'relationship' => $payload['relationship'],
            'dob' => $payload['dob'] ?? null,
            'gender' => $payload['gender'] ?? 'male',
            'mobile' => $payload['mobile'] ?? null,
        ]);

        $id = (int) Database::getConnection()->lastInsertId();
        $familyMember = $this->getById($id);

        if ($familyMember === null) {
            throw new RuntimeException('Failed to create family member record.');
        }

        return $familyMember;
    }

    public function getById(int $id): ?FamilyMember
    {
        $stmt = Database::getConnection()->prepare('SELECT * FROM family_members WHERE id = :id');
        $stmt->execute(['id' => $id]);
        $data = $stmt->fetch(PDO::FETCH_ASSOC);
        return $data ? new FamilyMember($data) : null;
    }
}
