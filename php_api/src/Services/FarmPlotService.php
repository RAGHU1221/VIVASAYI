<?php

namespace App\Services;

use App\Config\Database;
use App\Models\FarmPlot;
use PDO;
use RuntimeException;

class FarmPlotService
{
    public function getByFarmId(int $farmId): array
    {
        $stmt = Database::getConnection()->prepare('SELECT * FROM farm_plots WHERE farm_id = :farm_id ORDER BY created_at DESC');
        $stmt->execute(['farm_id' => $farmId]);
        return array_map(fn(array $row) => new FarmPlot($row), $stmt->fetchAll(PDO::FETCH_ASSOC));
    }

    public function create(array $payload): FarmPlot
    {
        $stmt = Database::getConnection()->prepare(
            'INSERT INTO farm_plots (farm_id, plot_name, area, crop_type, planted_on, expected_harvest_date)
            VALUES (:farm_id, :plot_name, :area, :crop_type, :planted_on, :expected_harvest_date)'
        );

        $stmt->execute([
            'farm_id' => $payload['farm_id'],
            'plot_name' => $payload['plot_name'],
            'area' => $payload['area'],
            'crop_type' => $payload['crop_type'] ?? null,
            'planted_on' => $payload['planted_on'] ?? null,
            'expected_harvest_date' => $payload['expected_harvest_date'] ?? null,
        ]);

        $id = (int) Database::getConnection()->lastInsertId();
        $farmPlot = $this->getById($id);

        if ($farmPlot === null) {
            throw new RuntimeException('Failed to create farm plot record.');
        }

        return $farmPlot;
    }

    public function getById(int $id): ?FarmPlot
    {
        $stmt = Database::getConnection()->prepare('SELECT * FROM farm_plots WHERE id = :id');
        $stmt->execute(['id' => $id]);
        $data = $stmt->fetch(PDO::FETCH_ASSOC);
        return $data ? new FarmPlot($data) : null;
    }
}
