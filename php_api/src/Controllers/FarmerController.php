<?php

namespace App\Controllers;

use App\Middleware\AuthMiddleware;
use App\Services\AuditLogService;
use App\Services\FarmerService;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;

class FarmerController
{
    private FarmerService $service;
    private AuditLogService $auditLogService;

    public function __construct()
    {
        $this->service = new FarmerService();
        $this->auditLogService = new AuditLogService();
    }

    public function index(Request $request): JsonResponse
    {
        $farmers = $this->service->getAll();
        return new JsonResponse(array_map(fn($farmer) => $farmer->toArray(), $farmers));
    }

    public function show(Request $request, array $args): JsonResponse
    {
        $id = (int) $args['id'];
        $farmer = $this->service->getById($id);

        if ($farmer === null) {
            return new JsonResponse(['error' => 'Farmer not found'], 404);
        }

        return new JsonResponse($farmer->toArray());
    }

    public function create(Request $request): JsonResponse
    {
        $payload = json_decode($request->getContent(), true);

        if (!is_array($payload)) {
            return new JsonResponse(['error' => 'Invalid request body'], 400);
        }

        if (empty($payload['uuid']) || !is_string($payload['uuid'])) {
            return new JsonResponse(['error' => 'Farmer UUID is required'], 400);
        }

        if (empty($payload['name']) || !is_string($payload['name'])) {
            return new JsonResponse(['error' => 'Farmer name is required'], 400);
        }

        if (empty($payload['phone']) || !is_string($payload['phone'])) {
            return new JsonResponse(['error' => 'Farmer phone is required'], 400);
        }

        $farmer = $this->service->create($payload);
        $userId = AuthMiddleware::getUserId($request) ?? 0;
        $this->auditLogService->createLog($userId, 'farmer.create', ['farmer_uuid' => $payload['uuid'], 'name' => $payload['name']], $request->getClientIp());
        return new JsonResponse($farmer->toArray(), 201);
    }
}
