<?php

namespace App\Controllers;

use App\Middleware\AuthMiddleware;
use App\Services\AuditLogService;
use App\Services\SessionService;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;

class SessionController
{
    private SessionService $sessionService;
    private AuditLogService $auditLogService;

    public function __construct()
    {
        $this->sessionService = new SessionService();
        $this->auditLogService = new AuditLogService();
    }

    public function index(Request $request): JsonResponse
    {
        $userId = AuthMiddleware::getUserId($request);
        if ($userId === null) {
            return new JsonResponse(['error' => 'Unauthorized'], 401);
        }

        $header = $request->headers->get('Authorization', '');
        $currentToken = str_starts_with($header, 'Bearer ') ? substr($header, 7) : null;

        $sessions = $this->sessionService->getActiveSessionsForUser($userId);
        $sessions = array_map(static function (array $session) use ($currentToken) {
            $session['is_current'] = $currentToken !== null && ($session['jwt_token'] ?? null) === $currentToken;
            unset($session['jwt_token']);
            return $session;
        }, $sessions);

        return new JsonResponse($sessions);
    }

    public function revoke(Request $request, array $vars): Response
    {
        $userId = AuthMiddleware::getUserId($request);
        if ($userId === null) {
            return new JsonResponse(['error' => 'Unauthorized'], 401);
        }

        $sessionId = isset($vars['id']) ? (int) $vars['id'] : 0;
        if ($sessionId <= 0) {
            return new JsonResponse(['error' => 'Invalid session id'], 400);
        }

        $revoked = $this->sessionService->revokeSession($sessionId, $userId);
        if (!$revoked) {
            return new JsonResponse(['error' => 'Session not found'], 404);
        }

        $this->auditLogService->createLog($userId, 'session.revoke', ['session_id' => $sessionId], $request->getClientIp());

        return new Response('', Response::HTTP_NO_CONTENT);
    }
}
