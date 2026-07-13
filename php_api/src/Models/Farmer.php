<?php

namespace App\Models;

class Farmer
{
    public int $id;
    public string $uuid;
    public ?int $user_id;
    public string $name;
    public string $phone;
    public ?string $email;
    public ?string $dob;
    public ?string $gender;
    public ?string $address;
    public ?string $district;
    public ?string $state;
    public ?string $postal_code;
    public string $created_at;
    public string $updated_at;

    public function __construct(array $data)
    {
        $this->id = (int) $data['id'];
        $this->uuid = $data['uuid'];
        $this->user_id = isset($data['user_id']) ? (int) $data['user_id'] : null;
        $this->name = $data['name'];
        $this->phone = $data['phone'];
        $this->email = $data['email'] ?? null;
        $this->dob = $data['dob'] ?? null;
        $this->gender = $data['gender'] ?? 'male';
        $this->address = $data['address'] ?? null;
        $this->district = $data['district'] ?? null;
        $this->state = $data['state'] ?? null;
        $this->postal_code = $data['postal_code'] ?? null;
        $this->created_at = $data['created_at'];
        $this->updated_at = $data['updated_at'];
    }

    public function toArray(): array
    {
        return [
            'id' => $this->id,
            'uuid' => $this->uuid,
            'user_id' => $this->user_id,
            'name' => $this->name,
            'phone' => $this->phone,
            'email' => $this->email,
            'dob' => $this->dob,
            'gender' => $this->gender,
            'address' => $this->address,
            'district' => $this->district,
            'state' => $this->state,
            'postal_code' => $this->postal_code,
            'created_at' => $this->created_at,
            'updated_at' => $this->updated_at,
        ];
    }
}
