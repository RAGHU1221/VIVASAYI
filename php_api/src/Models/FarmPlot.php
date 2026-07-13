<?php

namespace App\Models;

class FarmPlot
{
    public int $id;
    public int $farm_id;
    public string $plot_name;
    public float $area;
    public ?string $crop_type;
    public ?string $planted_on;
    public ?string $expected_harvest_date;
    public string $created_at;
    public string $updated_at;

    public function __construct(array $data)
    {
        $this->id = (int) $data['id'];
        $this->farm_id = (int) $data['farm_id'];
        $this->plot_name = $data['plot_name'];
        $this->area = (float) $data['area'];
        $this->crop_type = $data['crop_type'] ?? null;
        $this->planted_on = $data['planted_on'] ?? null;
        $this->expected_harvest_date = $data['expected_harvest_date'] ?? null;
        $this->created_at = $data['created_at'];
        $this->updated_at = $data['updated_at'];
    }

    public function toArray(): array
    {
        return [
            'id' => $this->id,
            'farm_id' => $this->farm_id,
            'plot_name' => $this->plot_name,
            'area' => $this->area,
            'crop_type' => $this->crop_type,
            'planted_on' => $this->planted_on,
            'expected_harvest_date' => $this->expected_harvest_date,
            'created_at' => $this->created_at,
            'updated_at' => $this->updated_at,
        ];
    }
}
