<?php

namespace App\Models;

class Farm
{
    public int $id;
    public int $farmer_id;
    public string $uuid;
    public string $farm_name;
    public float $total_area;
    public ?string $crop_type;
    public ?string $soil_type;
    public ?string $irrigation_type;
    public string $status;
    public string $created_at;
    public string $updated_at;

    public function __construct(array $data)
    {
        $this->id = (int) $data['id'];
        $this->farmer_id = (int) $data['farmer_id'];
        $this->uuid = $data['uuid'];
        $this->farm_name = $data['farm_name'];
        $this->total_area = (float) $data['total_area'];
        $this->crop_type = $data['crop_type'] ?? null;
        $this->soil_type = $data['soil_type'] ?? null;
        $this->irrigation_type = $data['irrigation_type'] ?? null;
        $this->status = $data['status'];
        $this->created_at = $data['created_at'];
        $this->updated_at = $data['updated_at'];
    }

    public function toArray(): array
    {
        return [
            'id' => $this->id,
            'farmer_id' => $this->farmer_id,
            'uuid' => $this->uuid,
            'farm_name' => $this->farm_name,
            'total_area' => $this->total_area,
            'crop_type' => $this->crop_type,
            'soil_type' => $this->soil_type,
            'irrigation_type' => $this->irrigation_type,
            'status' => $this->status,
            'created_at' => $this->created_at,
            'updated_at' => $this->updated_at,
        ];
    }
}
