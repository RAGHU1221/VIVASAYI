<?php

namespace App\Controllers;

use App\Services\AuditLogService;
use App\Services\FarmService;
use App\Services\FarmerService;
use App\Services\SessionService;
use App\Services\UserService;
use Firebase\JWT\JWT;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;

class AuthController
{
    private UserService $userService;
    private SessionService $sessionService;
    private AuditLogService $auditLogService;
    private FarmService $farmService;
    private FarmerService $farmerService;

    public function __construct()
    {
        $this->userService = new UserService();
        $this->sessionService = new SessionService();
        $this->auditLogService = new AuditLogService();
        $this->farmService = new FarmService();
        $this->farmerService = new FarmerService();
    }

    public function login(Request $request): JsonResponse
    {
        $payload = json_decode($request->getContent(), true);

        if (!is_array($payload)) {
            return new JsonResponse(['error' => 'Invalid request body'], 400);
        }

        $phone = trim($payload['phone'] ?? '');
        $password = $payload['password'] ?? null;

        if ($phone === '') {
            return new JsonResponse(['error' => 'Phone number is required'], 400);
        }

        $user = $this->userService->getByPhone($phone);
        if ($user === null || $user->is_active !== 1) {
            return new JsonResponse(['error' => 'Invalid credentials or inactive account'], 401);
        }

        if (!is_string($password) || $password === '') {
            return new JsonResponse(['error' => 'Password is required'], 400);
        }

        if ($user->password_hash === null || $user->password_hash === '') {
            return new JsonResponse(['error' => 'Password login is not available for this account'], 401);
        }

        if (!password_verify($password, $user->password_hash)) {
            return new JsonResponse(['error' => 'Invalid credentials'], 401);
        }

        $secret = $_ENV['JWT_SECRET'] ?? 'change_me_securely';
        $issuedAt = time();
        $expiresAt = $issuedAt + 3600;
        $tokenPayload = [
            'sub' => $user->id,
            'phone' => $user->phone,
            'role' => $user->role,
            'iat' => $issuedAt,
            'exp' => $expiresAt,
        ];

        $jwt = JWT::encode($tokenPayload, $secret, 'HS256');
        $expiresAtDate = date('Y-m-d H:i:s', $expiresAt);
        $this->sessionService->createSession($user->id, $jwt, $expiresAtDate, $request->headers->get('User-Agent'), $request->getClientIp());
        $this->auditLogService->createLog($user->id, 'login.password', ['phone' => $user->phone], $request->getClientIp());

        return new JsonResponse([
            'token' => $jwt,
            'expires_at' => $expiresAt,
            'user' => $user->toArray(),
        ]);
    }

    public function signup(Request $request): JsonResponse
    {
        $payload = json_decode($request->getContent(), true);

        if (!is_array($payload)) {
            return new JsonResponse(['error' => 'Invalid request body'], 400);
        }

        $name = trim($payload['name'] ?? '');
        $phone = trim($payload['phone'] ?? '');
        $password = $payload['password'] ?? null;

        if ($name === '') {
            return new JsonResponse(['error' => 'Name is required'], 400);
        }

        if ($phone === '' || !preg_match('/^\d{10}$/', $phone)) {
            return new JsonResponse(['error' => 'Valid 10-digit phone number is required'], 400);
        }

        if (!is_string($password) || strlen($password) < 6) {
            return new JsonResponse(['error' => 'Password must be at least 6 characters'], 400);
        }

        $existing = $this->userService->getByPhone($phone);
        if ($existing !== null) {
            return new JsonResponse(['error' => 'This phone number is already registered'], 409);
        }

        $user = $this->userService->create([
            'uuid' => self::generateUuid(),
            'name' => $name,
            'phone' => $phone,
            'password_hash' => password_hash($password, PASSWORD_BCRYPT),
            'role' => 'user',
            'language' => 'ta',
            'is_active' => 1,
        ]);

        $secret = $_ENV['JWT_SECRET'] ?? 'change_me_securely';
        $issuedAt = time();
        $expiresAt = $issuedAt + 3600;
        $tokenPayload = [
            'sub' => $user->id,
            'phone' => $user->phone,
            'role' => $user->role,
            'iat' => $issuedAt,
            'exp' => $expiresAt,
        ];

        $jwt = JWT::encode($tokenPayload, $secret, 'HS256');
        $expiresAtDate = date('Y-m-d H:i:s', $expiresAt);
        $this->sessionService->createSession($user->id, $jwt, $expiresAtDate, $request->headers->get('User-Agent'), $request->getClientIp());
        $this->auditLogService->createLog($user->id, 'signup.password', ['phone' => $user->phone], $request->getClientIp());

        return new JsonResponse([
            'token' => $jwt,
            'expires_at' => $expiresAt,
            'user' => $user->toArray(),
        ], 201);
    }

    private static function generateUuid(): string
    {
        $data = random_bytes(16);
        $data[6] = chr((ord($data[6]) & 0x0f) | 0x40);
        $data[8] = chr((ord($data[8]) & 0x3f) | 0x80);
        return vsprintf('%s%s-%s-%s-%s-%s%s%s', str_split(bin2hex($data), 4));
    }

    public function profile(Request $request): JsonResponse
    {
        $payload = $request->attributes->get('jwt_payload', []);
        $userId = isset($payload['sub']) ? (int) $payload['sub'] : null;

        if ($userId === null) {
            return new JsonResponse(['error' => 'Unauthorized'], 401);
        }

        $user = $this->userService->getById($userId);
        if ($user === null) {
            return new JsonResponse(['error' => 'User not found'], 404);
        }

        return new JsonResponse(['profile' => $user->toArray()]);
    }

    public function profileFarms(Request $request): JsonResponse
    {
        $payload = $request->attributes->get('jwt_payload', []);
        $userId = isset($payload['sub']) ? (int) $payload['sub'] : null;

        if ($userId === null) {
            return new JsonResponse(['error' => 'Unauthorized'], 401);
        }

        $farmer = $this->farmerService->getByUserId($userId);
        if ($farmer === null) {
            return new JsonResponse(['farms' => []]);
        }

        $farms = $this->farmService->getByFarmerId($farmer->id);

        return new JsonResponse([
            'farms' => array_map(fn($farm) => $farm->toArray(), $farms),
        ]);
    }

    public function profileStats(Request $request): JsonResponse
    {
        $payload = $request->attributes->get('jwt_payload', []);
        $userId = isset($payload['sub']) ? (int) $payload['sub'] : null;

        if ($userId === null) {
            return new JsonResponse(['error' => 'Unauthorized'], 401);
        }

        $farmer = $this->farmerService->getByUserId($userId);
        $farms = $farmer !== null ? $this->farmService->getByFarmerId($farmer->id) : [];

        $farmCount = count($farms);
        $totalArea = array_reduce($farms, fn($carry, $farm) => $carry + $farm->total_area, 0.0);

        return new JsonResponse([
            'stats' => [
                'farm_count' => $farmCount,
                'total_area' => $totalArea,
                'weather' => ['summary' => '-'],
                'alerts' => 0,
            ],
        ]);
    }
}
