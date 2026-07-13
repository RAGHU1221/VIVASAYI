<?php

namespace App\Models;

class User
{
    public int $id;
    public string $uuid;
    public string $name;
    public ?string $email;
    public string $phone;
    public ?string $password_hash;
    public string $role;
    public string $language;
    public int $is_active;
    public string $created_at;
    public string $updated_at;

    public function __construct(array $data)
    {
        $this->id = (int) $data['id'];
        $this->uuid = $data['uuid'];
        $this->name = $data['name'];
        $this->email = $data['email'] ?? null;
        $this->phone = $data['phone'];
        $this->password_hash = $data['password_hash'] ?? null;
        $this->role = $data['role'];
        $this->language = $data['language'];
        $this->is_active = (int) $data['is_active'];
        $this->created_at = $data['created_at'];
        $this->updated_at = $data['updated_at'];
    }

    public function toArray(): array
    {
        return [
            'id' => $this->id,
            'uuid' => $this->uuid,
            'name' => $this->name,
            'email' => $this->email,
            'phone' => $this->phone,
            'role' => $this->role,
            'language' => $this->language,
            'is_active' => $this->is_active,
            'created_at' => $this->created_at,
            'updated_at' => $this->updated_at,
        ];
    }
}
