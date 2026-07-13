<?php

namespace App\Controllers;

use App\Middleware\AuthMiddleware;
use App\Services\AuditLogService;
use App\Services\FarmPlotService;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;

class FarmPlotController
{
    private FarmPlotService $service;
    private AuditLogService $auditLogService;

    public function __construct()
    {
        $this->service = new FarmPlotService();
        $this->auditLogService = new AuditLogService();
    }

    public function index(Request $request, array $vars): JsonResponse
    {
        $farmId = (int) ($vars['farm_id'] ?? 0);
        $plots = $this->service->getByFarmId($farmId);
        return new JsonResponse(array_map(fn($plot) => $plot->toArray(), $plots));
    }

    public function create(Request $request): JsonResponse
    {
        $payload = json_decode($request->getContent(), true);

        if (!is_array($payload)) {
            return new JsonResponse(['error' => 'Invalid request body'], 400);
        }

        if (empty($payload['farm_id']) || !is_numeric($payload['farm_id'])) {
            return new JsonResponse(['error' => 'Farm ID is required for the plot record'], 400);
        }

        if (empty($payload['plot_name']) || !is_string($payload['plot_name'])) {
            return new JsonResponse(['error' => 'Plot name is required'], 400);
        }

        if (!isset($payload['area']) || !is_numeric($payload['area'])) {
            return new JsonResponse(['error' => 'Plot area is required and must be numeric'], 400);
        }

        $plot = $this->service->create($payload);
        $userId = AuthMiddleware::getUserId($request) ?? 0;
        $this->auditLogService->createLog($userId, 'farm_plot.create', ['farm_id' => $payload['farm_id'], 'plot_name' => $payload['plot_name']], $request->getClientIp());
        return new JsonResponse($plot->toArray(), 201);
    }
}
