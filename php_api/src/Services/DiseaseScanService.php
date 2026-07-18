<?php

namespace App\Services;

use App\Config\Database;
use App\Models\DiseaseScan;
use PDO;
use RuntimeException;

class DiseaseScanService
{
    private static bool $columnsEnsured = false;

    /**
     * AI vision analysis-la irundhu varra Tamil solution text (paragraph
     * length) store panna, predicted_label VARCHAR(150) podhaathu. Existing
     * live DB-layum automatic-ah run aagum (idempotent, matches CropController
     * pattern elsewhere in this codebase).
     */
    private function ensureColumns(): void
    {
        if (self::$columnsEnsured) {
            return;
        }
        try {
            Database::getConnection()->exec(
                'ALTER TABLE disease_scans ADD COLUMN IF NOT EXISTS solution_text TEXT DEFAULT NULL AFTER model_version'
            );
        } catch (\Throwable $e) {
            error_log('disease_scans.solution_text migration warning: ' . $e->getMessage());
        }
        self::$columnsEnsured = true;
    }

    public function create(array $payload): DiseaseScan
    {
        $this->ensureColumns();

        $stmt = Database::getConnection()->prepare(
            'INSERT INTO disease_scans (user_id, farm_id, image_path, predicted_label, confidence, model_version, solution_text, status)
            VALUES (:user_id, :farm_id, :image_path, :predicted_label, :confidence, :model_version, :solution_text, :status)'
        );

        $stmt->execute([
            'user_id' => $payload['user_id'],
            'farm_id' => $payload['farm_id'] ?? null,
            'image_path' => $payload['image_path'],
            'predicted_label' => $payload['predicted_label'] ?? null,
            'confidence' => $payload['confidence'] ?? null,
            'model_version' => $payload['model_version'] ?? null,
            'solution_text' => $payload['solution_text'] ?? null,
            'status' => $payload['status'] ?? 'completed',
        ]);

        $id = (int) Database::getConnection()->lastInsertId();
        $scan = $this->getById($id);

        if ($scan === null) {
            throw new RuntimeException('Failed to create disease scan record.');
        }

        return $scan;
    }

    public function getById(int $id): ?DiseaseScan
    {
        $this->ensureColumns();
        $stmt = Database::getConnection()->prepare('SELECT * FROM disease_scans WHERE id = :id LIMIT 1');
        $stmt->execute(['id' => $id]);
        $data = $stmt->fetch(PDO::FETCH_ASSOC);
        return $data ? new DiseaseScan($data) : null;
    }

    public function getByUserId(int $userId, ?int $farmId = null): array
    {
        $this->ensureColumns();
        if ($farmId !== null) {
            $stmt = Database::getConnection()->prepare(
                'SELECT * FROM disease_scans WHERE user_id = :user_id AND farm_id = :farm_id ORDER BY created_at DESC'
            );
            $stmt->execute(['user_id' => $userId, 'farm_id' => $farmId]);
        } else {
            $stmt = Database::getConnection()->prepare(
                'SELECT * FROM disease_scans WHERE user_id = :user_id ORDER BY created_at DESC'
            );
            $stmt->execute(['user_id' => $userId]);
        }

        return array_map(fn(array $row) => new DiseaseScan($row), $stmt->fetchAll(PDO::FETCH_ASSOC));
    }
}
