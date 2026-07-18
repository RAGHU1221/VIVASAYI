<?php

namespace App\Controllers;

use App\Middleware\AuthMiddleware;
use App\Services\AuditLogService;
use App\Services\FarmService;
use App\Services\FarmerService;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;

class FarmController
{
    private FarmService $service;
    private AuditLogService $auditLogService;
    private FarmerService $farmerService;

    public function __construct()
    {
        $this->service = new FarmService();
        $this->auditLogService = new AuditLogService();
        $this->farmerService = new FarmerService();
    }

    public function index(Request $request, array $vars): JsonResponse
    {
        $farmerId = (int) ($vars['farmer_id'] ?? 0);
        $farms = $this->service->getByFarmerId($farmerId);
        return new JsonResponse(array_map(fn($farm) => $farm->toArray(), $farms));
    }

    public function show(Request $request, array $vars): JsonResponse
    {
        $id = isset($vars['id']) ? (int) $vars['id'] : 0;
        if ($id <= 0) {
            return new JsonResponse(['error' => 'Invalid farm id'], 400);
        }

        $farm = $this->service->getById($id);
        if ($farm === null) {
            return new JsonResponse(['error' => 'Farm not found'], 404);
        }

        return new JsonResponse($farm->toArray());
    }

    public function create(Request $request): JsonResponse
    {
        $payload = json_decode($request->getContent(), true);

        if (!is_array($payload)) {
            return new JsonResponse(['error' => 'Invalid request body'], 400);
        }

        // Determine farmer_id: prefer explicit payload, otherwise infer from authenticated user
        $userId = AuthMiddleware::getUserId($request);
        $farmerId = null;
        if (!empty($payload['farmer_id']) && is_numeric($payload['farmer_id'])) {
            $farmerId = (int) $payload['farmer_id'];
        } elseif ($userId !== null) {
            $farmer = $this->farmerService->getByUserId((int) $userId);
            if ($farmer === null) {
                // Self-heal: accounts created before farmer auto-creation was
                // added to signup() won't have a farmers row yet. Create one
                // on the fly instead of blocking farm creation.
                $userService = new \App\Services\UserService();
                $user = $userService->getById((int) $userId);
                if ($user !== null) {
                    try {
                        $farmer = $this->farmerService->create([
                            'uuid' => self::uuidV4(),
                            'user_id' => $user->id,
                            'name' => $user->name,
                            'phone' => $user->phone,
                        ]);
                    } catch (\Throwable $e) {
                        error_log('farm.create: farmer self-heal failed for user ' . $userId . ': ' . $e->getMessage());
                    }
                }
            }
            if ($farmer !== null) {
                $farmerId = $farmer->id;
            }
        }

        if ($farmerId === null) {
            return new JsonResponse(['error' => 'Farmer ID could not be determined for the farm record'], 400);
        }

        // Ensure UUID exists; generate server-side if missing (RFC4122 v4)
        if (empty($payload['uuid']) || !is_string($payload['uuid'])) {
            $payload['uuid'] = self::uuidV4();
        }

        if (empty($payload['farm_name']) || !is_string($payload['farm_name'])) {
            return new JsonResponse(['error' => 'Farm name is required'], 400);
        }

        if (!isset($payload['total_area']) || !is_numeric($payload['total_area'])) {
            return new JsonResponse(['error' => 'Farm total area is required and must be numeric'], 400);
        }

        // fill inferred farmer_id into payload for persistence
        $payload['farmer_id'] = $farmerId;

        $farm = $this->service->create($payload);
        $userIdInt = $userId ?? 0;
        $this->auditLogService->createLog($userIdInt, 'farm.create', ['farm_uuid' => $payload['uuid'], 'farmer_id' => $payload['farmer_id']], $request->getClientIp());
        return new JsonResponse($farm->toArray(), 201);
    }

    private static function uuidV4(): string
    {
        $data = random_bytes(16);
        $data[6] = chr(ord($data[6]) & 0x0f | 0x40); // set version to 0100
        $data[8] = chr(ord($data[8]) & 0x3f | 0x80); // set bits 6-7 to 10
        return vsprintf('%s%s-%s-%s-%s-%s%s%s', str_split(bin2hex($data), 4));
    }

    public function update(Request $request, array $vars): JsonResponse
    {
        $id = isset($vars['id']) ? (int) $vars['id'] : 0;
        if ($id <= 0) {
            return new JsonResponse(['error' => 'Invalid farm id'], 400);
        }

        $payload = json_decode($request->getContent(), true);
        if (!is_array($payload)) {
            return new JsonResponse(['error' => 'Invalid request body'], 400);
        }

        $farm = $this->service->update($id, $payload);
        if ($farm === null) {
            return new JsonResponse(['error' => 'Farm not found'], 404);
        }

        $userId = AuthMiddleware::getUserId($request) ?? 0;
        $this->auditLogService->createLog($userId, 'farm.update', ['farm_id' => $id], $request->getClientIp());

        return new JsonResponse($farm->toArray());
    }

    public function delete(Request $request, array $vars): Response
    {
        $id = isset($vars['id']) ? (int) $vars['id'] : 0;
        if ($id <= 0) {
            return new JsonResponse(['error' => 'Invalid farm id'], 400);
        }

        $existing = $this->service->getById($id);
        if ($existing === null) {
            return new JsonResponse(['error' => 'Farm not found'], 404);
        }

        $deleted = $this->service->delete($id);
        if (!$deleted) {
            return new JsonResponse(['error' => 'Failed to delete farm'], 500);
        }

        $userId = AuthMiddleware::getUserId($request) ?? 0;
        $this->auditLogService->createLog($userId, 'farm.delete', ['farm_id' => $id], $request->getClientIp());

        return new Response('', Response::HTTP_NO_CONTENT);
    }
}
