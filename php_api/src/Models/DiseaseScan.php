<?php

namespace App\Models;

class DiseaseScan
{
    public int $id;
    public int $user_id;
    public ?int $farm_id;
    public string $image_path;
    public ?string $predicted_label;
    public ?float $confidence;
    public ?string $model_version;
    public ?string $solution_text;
    public string $status;
    public string $created_at;

    public function __construct(array $data)
    {
        $this->id = (int) $data['id'];
        $this->user_id = (int) $data['user_id'];
        $this->farm_id = isset($data['farm_id']) ? (int) $data['farm_id'] : null;
        $this->image_path = $data['image_path'];
        $this->predicted_label = $data['predicted_label'] ?? null;
        $this->confidence = isset($data['confidence']) ? (float) $data['confidence'] : null;
        $this->model_version = $data['model_version'] ?? null;
        $this->solution_text = $data['solution_text'] ?? null;
        $this->status = $data['status'];
        $this->created_at = $data['created_at'];
    }

    public function toArray(): array
    {
        return [
            'id' => $this->id,
            'user_id' => $this->user_id,
            'farm_id' => $this->farm_id,
            'image_path' => $this->image_path,
            'predicted_label' => $this->predicted_label,
            'confidence' => $this->confidence,
            'model_version' => $this->model_version,
            'solution_text' => $this->solution_text,
            'status' => $this->status,
            'created_at' => $this->created_at,
        ];
    }
}
