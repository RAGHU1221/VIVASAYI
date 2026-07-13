<?php

namespace App\Controllers;

use App\Services\UserService;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;

class UserController
{
    private UserService $service;

    public function __construct()
    {
        $this->service = new UserService();
    }

    public function index(Request $request): JsonResponse
    {
        $users = $this->service->getAll();
        return new JsonResponse(array_map(fn($user) => $user->toArray(), $users));
    }
}
