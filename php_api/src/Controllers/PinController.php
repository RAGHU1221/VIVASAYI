<?php

namespace App\Controllers;

use App\Middleware\AuthMiddleware;
use App\Services\AuditLogService;
use App\Services\PinService;
use App\Services\SessionService;
use App\Services\UserService;
use Firebase\JWT\JWT;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;

class PinController
{
    private UserService $userService;
    private PinService $pinService;
    private SessionService $sessionService;
    private AuditLogService $auditLogService;

    public function __construct()
    {
        $this->userService = new UserService();
        $this->pinService = new PinService();
        $this->sessionService = new SessionService();
        $this->auditLogService = new AuditLogService();
    }

    private function isValidPin(mixed $pin): bool
    {
        return is_string($pin) && preg_match('/^\d{4,6}$/', $pin) === 1;
    }

    public function loginWithPin(Request $request): JsonResponse
    {
        $payload = json_decode($request->getContent(), true);
        if (!is_array($payload)) {
            return new JsonResponse(['error' => 'Invalid request body'], 400);
        }

        $phone = trim($payload['phone'] ?? '');
        $pin = $payload['pin'] ?? '';

        if ($phone === '' || !$this->isValidPin($pin)) {
            return new JsonResponse(['error' => 'Phone and a 4-6 digit PIN are required'], 400);
        }

        $user = $this->userService->getByPhone($phone);
        if ($user === null || $user->is_active !== 1) {
            return new JsonResponse(['error' => 'Invalid credentials or inactive account'], 401);
        }

        if (!$this->pinService->verifyPin($user->id, $pin)) {
            return new JsonResponse(['error' => 'Invalid credentials'], 401);
        }

        $secret = $_ENV['JWT_SECRET'] ?? 'change_me_securely';
        $issuedAt = time();
        $expiresAt = $issuedAt + (int) ($_ENV['JWT_TTL'] ?? 2592000); // default 30 days
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
        $this->auditLogService->createLog($user->id, 'login.pin', ['phone' => $user->phone], $request->getClientIp());

        return new JsonResponse([
            'token' => $jwt,
            'expires_at' => $expiresAt,
            'user' => $user->toArray(),
        ]);
    }

    public function setPin(Request $request): JsonResponse
    {
        $userId = AuthMiddleware::getUserId($request);
        if ($userId === null) {
            return new JsonResponse(['error' => 'Unauthorized'], 401);
        }

        $payload = json_decode($request->getContent(), true);
        if (!is_array($payload)) {
            return new JsonResponse(['error' => 'Invalid request body'], 400);
        }

        $pin = $payload['pin'] ?? '';
        if (!$this->isValidPin($pin)) {
            return new JsonResponse(['error' => 'PIN must be 4-6 digits'], 400);
        }

        $this->pinService->setPin($userId, $pin);
        $this->auditLogService->createLog($userId, 'pin.set', null, $request->getClientIp());

        return new JsonResponse(['message' => 'PIN updated successfully']);
    }

    public function verifyPin(Request $request): JsonResponse
    {
        $userId = AuthMiddleware::getUserId($request);
        if ($userId === null) {
            return new JsonResponse(['error' => 'Unauthorized'], 401);
        }

        $payload = json_decode($request->getContent(), true);
        if (!is_array($payload)) {
            return new JsonResponse(['error' => 'Invalid request body'], 400);
        }

        $pin = $payload['pin'] ?? '';
        if (!$this->isValidPin($pin)) {
            return new JsonResponse(['error' => 'PIN must be 4-6 digits'], 400);
        }

        if (!$this->pinService->verifyPin($userId, $pin)) {
            return new JsonResponse(['error' => 'Incorrect PIN'], 401);
        }

        return new JsonResponse(['message' => 'PIN verified']);
    }
}
