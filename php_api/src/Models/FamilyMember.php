<?php

namespace App\Models;

class FamilyMember
{
    public int $id;
    public int $farmer_id;
    public string $name;
    public string $relationship;
    public ?string $dob;
    public ?string $gender;
    public ?string $mobile;
    public string $created_at;
    public string $updated_at;

    public function __construct(array $data)
    {
        $this->id = (int) $data['id'];
        $this->farmer_id = (int) $data['farmer_id'];
        $this->name = $data['name'];
        $this->relationship = $data['relationship'];
        $this->dob = $data['dob'] ?? null;
        $this->gender = $data['gender'] ?? 'male';
        $this->mobile = $data['mobile'] ?? null;
        $this->created_at = $data['created_at'];
        $this->updated_at = $data['updated_at'];
    }

    public function toArray(): array
    {
        return [
            'id' => $this->id,
            'farmer_id' => $this->farmer_id,
            'name' => $this->name,
            'relationship' => $this->relationship,
            'dob' => $this->dob,
            'gender' => $this->gender,
            'mobile' => $this->mobile,
            'created_at' => $this->created_at,
            'updated_at' => $this->updated_at,
        ];
    }
}
