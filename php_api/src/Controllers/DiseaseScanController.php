<?php

namespace App\Controllers;

use App\Middleware\AuthMiddleware;
use App\Services\AuditLogService;
use App\Services\DiseaseScanService;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;

class DiseaseScanController
{
    private DiseaseScanService $service;
    private AuditLogService $auditLogService;

    public function __construct()
    {
        $this->service = new DiseaseScanService();
        $this->auditLogService = new AuditLogService();
    }

    public function index(Request $request): JsonResponse
    {
        $userId = AuthMiddleware::getUserId($request);
        if ($userId === null) {
            return new JsonResponse(['error' => 'Unauthorized'], 401);
        }

        $farmId = $request->query->get('farm_id');
        if ($farmId !== null && !is_numeric($farmId)) {
            return new JsonResponse(['error' => 'Invalid farm_id filter'], 400);
        }

        $scans = $this->service->getByUserId($userId, $farmId !== null ? (int) $farmId : null);
        return new JsonResponse(array_map(fn($scan) => $scan->toArray(), $scans));
    }

    public function create(Request $request): JsonResponse
    {
        $userId = AuthMiddleware::getUserId($request);
        if ($userId === null) {
            return new JsonResponse(['error' => 'Unauthorized'], 401);
        }

        $payload = json_decode($request->getContent(), true);
        if (!is_array($payload)) {
            return new JsonResponse(['error' => 'Invalid request body'], 400);
        }

        if (empty($payload['image_path']) || !is_string($payload['image_path'])) {
            return new JsonResponse(['error' => 'image_path is required'], 400);
        }

        $payload['user_id'] = $userId;
        $scan = $this->service->create($payload);
        $this->auditLogService->createLog($userId, 'disease_scan.create', ['scan_id' => $scan->id], $request->getClientIp());

        return new JsonResponse($scan->toArray(), 201);
    }
}
