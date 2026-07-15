<?php

namespace App\Middleware;

use App\Services\SessionService;
use Firebase\JWT\JWT;
use Firebase\JWT\Key;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;

class AuthMiddleware
{
    public static function authenticate(Request $request): ?JsonResponse
    {
        $header = $request->headers->get('Authorization');

        // Apache sila configs la Authorization header ah PHP ku pass pannadhu —
        // getallheaders() fallback (mod_php la idhu reliable ah kidaikkum)
        if (!$header && function_exists('getallheaders')) {
            foreach (getallheaders() as $name => $value) {
                if (strtolower($name) === 'authorization') {
                    $header = $value;
                    break;
                }
            }
        }
        if (!$header && isset($_SERVER['REDIRECT_HTTP_AUTHORIZATION'])) {
            $header = $_SERVER['REDIRECT_HTTP_AUTHORIZATION'];
        }

        if (!$header || !str_starts_with($header, 'Bearer ')) {
            return new JsonResponse(['error' => 'Unauthorized'], JsonResponse::HTTP_UNAUTHORIZED);
        }

        $token = substr($header, 7);

        try {
            $secret = $_ENV['JWT_SECRET'] ?? 'change_me_securely';
            $decoded = JWT::decode($token, new Key($secret, 'HS256'));
            $request->attributes->set('jwt_payload', (array) $decoded);

            $sessionService = new SessionService();
            $session = $sessionService->getSessionByToken($token);
            if ($session === null) {
                return new JsonResponse(['error' => 'Invalid or revoked session'], JsonResponse::HTTP_UNAUTHORIZED);
            }

            return null;
        } catch (\Throwable $error) {
            return new JsonResponse(['error' => 'Invalid or expired token'], JsonResponse::HTTP_UNAUTHORIZED);
        }
    }

    public static function authorize(Request $request, array $roles): ?JsonResponse
    {
        $authResponse = self::authenticate($request);
        if ($authResponse !== null) {
            return $authResponse;
        }

        $payload = $request->attributes->get('jwt_payload', []);
        $role = $payload['role'] ?? null;
        if (!is_string($role) || !in_array($role, $roles, true)) {
            return new JsonResponse(['error' => 'Forbidden'], JsonResponse::HTTP_FORBIDDEN);
        }

        return null;
    }

    public static function getPayload(Request $request): array
    {
        return $request->attributes->get('jwt_payload', []);
    }

    public static function getUserId(Request $request): ?int
    {
        $payload = self::getPayload($request);
        return isset($payload['sub']) ? (int) $payload['sub'] : null;
    }
}
