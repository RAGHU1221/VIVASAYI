<?php

namespace App\Controllers;

use App\Middleware\AuthMiddleware;
use App\Services\AuditLogService;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;

class AuditLogController
{
    private AuditLogService $service;

    public function __construct()
    {
        $this->service = new AuditLogService();
    }

    public function index(Request $request): JsonResponse
    {
        $limit = (int) max(1, min(100, (int) $request->query->get('limit', 50)));
        $offset = (int) max(0, (int) $request->query->get('offset', 0));
        $userId = $request->query->get('user_id');

        if ($userId !== null && !is_numeric($userId)) {
            return new JsonResponse(['error' => 'Invalid user_id filter'], 400);
        }

        $logs = $userId !== null
            ? $this->service->getByUserId((int) $userId, $limit, $offset)
            : $this->service->getAll($limit, $offset);

        return new JsonResponse($logs);
    }

    public function selfIndex(Request $request): JsonResponse
    {
        $userId = AuthMiddleware::getUserId($request);
        if ($userId === null) {
            return new JsonResponse(['error' => 'Unauthorized'], 401);
        }

        $limit = (int) max(1, min(100, (int) $request->query->get('limit', 50)));
        $offset = (int) max(0, (int) $request->query->get('offset', 0));

        return new JsonResponse($this->service->getByUserId($userId, $limit, $offset));
    }
}
