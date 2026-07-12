<?php

namespace App\Controllers;

use App\Middleware\AuthMiddleware;
use App\Services\AuditLogService;
use App\Services\FamilyMemberService;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;

class FamilyMemberController
{
    private FamilyMemberService $service;
    private AuditLogService $auditLogService;

    public function __construct()
    {
        $this->service = new FamilyMemberService();
        $this->auditLogService = new AuditLogService();
    }

    public function index(Request $request, array $vars): JsonResponse
    {
        $farmerId = (int) ($vars['farmer_id'] ?? 0);
        $members = $this->service->getByFarmerId($farmerId);
        return new JsonResponse(array_map(fn($member) => $member->toArray(), $members));
    }

    public function create(Request $request): JsonResponse
    {
        $payload = json_decode($request->getContent(), true);

        if (!is_array($payload)) {
            return new JsonResponse(['error' => 'Invalid request body'], 400);
        }

        if (empty($payload['farmer_id']) || !is_numeric($payload['farmer_id'])) {
            return new JsonResponse(['error' => 'Farmer ID is required for the family member record'], 400);
        }

        if (empty($payload['name']) || !is_string($payload['name'])) {
            return new JsonResponse(['error' => 'Family member name is required'], 400);
        }

        if (empty($payload['relationship']) || !is_string($payload['relationship'])) {
            return new JsonResponse(['error' => 'Relationship is required'], 400);
        }

        $member = $this->service->create($payload);
        $userId = AuthMiddleware::getUserId($request) ?? 0;
        $this->auditLogService->createLog($userId, 'family_member.create', ['farmer_id' => $payload['farmer_id'], 'name' => $payload['name']], $request->getClientIp());
        return new JsonResponse($member->toArray(), 201);
    }
}
