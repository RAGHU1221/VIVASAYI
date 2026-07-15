<?php

namespace App\Routes;

use FastRoute\RouteCollector;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use function FastRoute\simpleDispatcher;

use App\Controllers\AuthController;
use App\Controllers\AuditLogController;
use App\Controllers\DiseaseScanController;
use App\Controllers\FarmerController;
use App\Controllers\FarmController;
use App\Controllers\FarmPlotController;
use App\Controllers\FamilyMemberController;
use App\Controllers\PinController;
use App\Controllers\SessionController;
use App\Controllers\UserController;
use App\Middleware\AuthMiddleware;

class Router
{
    public function dispatch(): Response
    {
        $request = Request::createFromGlobals();
        $httpMethod = $request->getMethod();
        $uri = rawurldecode($request->getPathInfo());

        $dispatcher = simpleDispatcher(function (RouteCollector $r) {
            $r->addRoute('GET', '/health', [self::class, 'health']);
            $r->addRoute('POST', '/auth/login', [self::class, 'login']);
            $r->addRoute('POST', '/auth/signup', [self::class, 'signup']);
            $r->addRoute('POST', '/auth/pin/login', [self::class, 'loginWithPin']);
            $r->addRoute('GET', '/auth/validate', [self::class, 'validateToken']);
            $r->addRoute('GET', '/debug/selftest', [self::class, 'debugSelftest']);
            $r->addRoute('GET', '/profile', [self::class, 'profile']);
            $r->addRoute('GET', '/profile/stats', [self::class, 'profileStats']);
            $r->addRoute('GET', '/profile/farms', [self::class, 'profileFarms']);
            $r->addRoute('POST', '/profile/pin', [self::class, 'setPin']);
            $r->addRoute('POST', '/profile/pin/verify', [self::class, 'verifyPin']);
            $r->addRoute('GET', '/profile/sessions', [self::class, 'listSessions']);
            $r->addRoute('DELETE', '/profile/sessions/{id:\d+}', [self::class, 'revokeSession']);
            $r->addRoute('GET', '/profile/security-logs', [self::class, 'securityLogs']);
            $r->addRoute('GET', '/audit-logs', [self::class, 'auditLogs']);
            $r->addRoute('GET', '/users', [self::class, 'listUsers']);

            $r->addRoute('GET', '/disease-scans', [self::class, 'listDiseaseScans']);
            $r->addRoute('POST', '/disease-scans', [self::class, 'createDiseaseScan']);

            $r->addRoute('GET', '/farmers', [self::class, 'listFarmers']);
            $r->addRoute('GET', '/farmers/{id:\d+}', [self::class, 'getFarmer']);
            $r->addRoute('POST', '/farmers', [self::class, 'createFarmer']);

            $r->addRoute('GET', '/farmers/{farmer_id:\d+}/farms', [self::class, 'listFarms']);
            $r->addRoute('POST', '/farms', [self::class, 'createFarm']);
            $r->addRoute('PUT', '/farms/{id:\d+}', [self::class, 'updateFarm']);
            $r->addRoute('DELETE', '/farms/{id:\d+}', [self::class, 'deleteFarm']);

            $r->addRoute('GET', '/farms/{id:\d+}', [self::class, 'getFarm']);
            $r->addRoute('GET', '/farms/{farm_id:\d+}/plots', [self::class, 'listFarmPlots']);
            $r->addRoute('POST', '/plots', [self::class, 'createFarmPlot']);

            $r->addRoute('GET', '/farmers/{farmer_id:\d+}/family-members', [self::class, 'listFamilyMembers']);
            $r->addRoute('POST', '/family-members', [self::class, 'createFamilyMember']);
        });

        $routeInfo = $dispatcher->dispatch($httpMethod, $uri);

        switch ($routeInfo[0]) {
            case \FastRoute\Dispatcher::NOT_FOUND:
                return new Response('Not Found', Response::HTTP_NOT_FOUND);
            case \FastRoute\Dispatcher::METHOD_NOT_ALLOWED:
                return new Response('Method Not Allowed', Response::HTTP_METHOD_NOT_ALLOWED);
            case \FastRoute\Dispatcher::FOUND:
                $handler = $routeInfo[1];
                $vars = $routeInfo[2];
                return call_user_func($handler, $request, $vars);
        }

        return new Response('Unexpected error', Response::HTTP_INTERNAL_SERVER_ERROR);
    }

    public static function health(Request $request): Response
    {
        return new Response(json_encode(['status' => 'ok']), Response::HTTP_OK, ['Content-Type' => 'application/json']);
    }

    public static function validateToken(Request $request, array $vars): Response
    {
        $authResponse = AuthMiddleware::authenticate($request);
        if ($authResponse !== null) {
            return $authResponse; // 401 — token invalid/expired/revoked
        }

        return new Response(json_encode(['valid' => true]), Response::HTTP_OK, ['Content-Type' => 'application/json']);
    }
public static function debugSelftest(Request $request, array $vars): Response
    {
        $out = [];
        try {
            $db = \App\Config\Database::getConnection();

            $out['php_now'] = date('Y-m-d H:i:s');
            $out['db_now'] = $db->query('SELECT NOW() AS n')->fetch()['n'];

            $col = $db->query("SHOW COLUMNS FROM sessions LIKE 'jwt_token'")->fetch();
            $out['jwt_token_column_type'] = $col['Type'] ?? 'unknown';

            $user = $db->query('SELECT id, role, is_active FROM users ORDER BY id LIMIT 1')->fetch();
            $out['first_user'] = $user ?: 'NO USERS';

            if ($user) {
                $secret = $_ENV['JWT_SECRET'] ?? 'change_me_securely';
                $now = time();
                $jwt = \Firebase\JWT\JWT::encode([
                    'sub' => (int) $user['id'],
                    'phone' => 'selftest',
                    'role' => $user['role'],
                    'iat' => $now,
                    'exp' => $now + 3600,
                ], $secret, 'HS256');
                $out['jwt_length'] = strlen($jwt);

                $svc = new \App\Services\SessionService();
                $svc->createSession((int) $user['id'], $jwt, date('Y-m-d H:i:s', $now + 3600), 'selftest-debug', '127.0.0.1');

                $stmt = $db->prepare('SELECT CHAR_LENGTH(jwt_token) AS len, expires_at FROM sessions WHERE device_info = ? ORDER BY id DESC LIMIT 1');
                $stmt->execute(['selftest-debug']);
                $row = $stmt->fetch();
                $out['stored_token_length'] = $row['len'] ?? null;
                $out['stored_expires_at'] = $row['expires_at'] ?? null;

                $found = $svc->getSessionByToken($jwt);
                $out['lookup_after_insert'] = $found !== null ? 'FOUND' : 'NOT_FOUND';

                $db->prepare("DELETE FROM sessions WHERE device_info = 'selftest-debug'")->execute();
            }
        } catch (\Throwable $e) {
            $out['exception'] = $e->getMessage();
        }

        return new Response(json_encode($out, JSON_PRETTY_PRINT), 200, ['Content-Type' => 'application/json']);
    }
    public static function login(Request $request, array $vars): Response
    {
        $controller = new AuthController();
        return $controller->login($request);
    }

    public static function signup(Request $request, array $vars): Response
    {
        $controller = new AuthController();
        return $controller->signup($request);
    }

    public static function profile(Request $request, array $vars): Response
    {
        $authResponse = self::authorize($request, ['admin', 'user']);
        if ($authResponse !== null) {
            return $authResponse;
        }

        $controller = new AuthController();
        return $controller->profile($request);
    }

    public static function profileFarms(Request $request, array $vars): Response
    {
        $authResponse = self::authorize($request, ['admin', 'user']);
        if ($authResponse !== null) {
            return $authResponse;
        }

        $controller = new AuthController();
        return $controller->profileFarms($request);
    }

    public static function profileStats(Request $request, array $vars): Response
    {
        $authResponse = self::authorize($request, ['admin', 'user']);
        if ($authResponse !== null) {
            return $authResponse;
        }

        $controller = new AuthController();
        return $controller->profileStats($request);
    }

    public static function loginWithPin(Request $request, array $vars): Response
    {
        $controller = new PinController();
        return $controller->loginWithPin($request);
    }

    public static function setPin(Request $request, array $vars): Response
    {
        $authResponse = self::authorize($request, ['admin', 'user']);
        if ($authResponse !== null) {
            return $authResponse;
        }

        $controller = new PinController();
        return $controller->setPin($request);
    }

    public static function verifyPin(Request $request, array $vars): Response
    {
        $authResponse = self::authorize($request, ['admin', 'user']);
        if ($authResponse !== null) {
            return $authResponse;
        }

        $controller = new PinController();
        return $controller->verifyPin($request);
    }

    public static function listSessions(Request $request, array $vars): Response
    {
        $authResponse = self::authorize($request, ['admin', 'user']);
        if ($authResponse !== null) {
            return $authResponse;
        }

        $controller = new SessionController();
        return $controller->index($request);
    }

    public static function revokeSession(Request $request, array $vars): Response
    {
        $authResponse = self::authorize($request, ['admin', 'user']);
        if ($authResponse !== null) {
            return $authResponse;
        }

        $controller = new SessionController();
        return $controller->revoke($request, $vars);
    }

    public static function securityLogs(Request $request, array $vars): Response
    {
        $authResponse = self::authorize($request, ['admin', 'user']);
        if ($authResponse !== null) {
            return $authResponse;
        }

        $controller = new AuditLogController();
        return $controller->selfIndex($request);
    }

    public static function listDiseaseScans(Request $request, array $vars): Response
    {
        $authResponse = self::authorize($request, ['admin', 'user']);
        if ($authResponse !== null) {
            return $authResponse;
        }

        $controller = new DiseaseScanController();
        return $controller->index($request);
    }

    public static function createDiseaseScan(Request $request, array $vars): Response
    {
        $authResponse = self::authorize($request, ['admin', 'user']);
        if ($authResponse !== null) {
            return $authResponse;
        }

        $controller = new DiseaseScanController();
        return $controller->create($request);
    }

    public static function auditLogs(Request $request, array $vars): Response
    {
        $authResponse = self::authorize($request, ['admin']);
        if ($authResponse !== null) {
            return $authResponse;
        }

        $controller = new AuditLogController();
        return $controller->index($request);
    }

    public static function listUsers(Request $request, array $vars): Response
    {
        $authResponse = self::authorize($request, ['admin']);
        if ($authResponse !== null) {
            return $authResponse;
        }

        $controller = new UserController();
        return $controller->index($request);
    }

    private static function authenticate(Request $request): ?Response
    {
        return AuthMiddleware::authenticate($request);
    }

    private static function authorize(Request $request, array $roles): ?Response
    {
        return AuthMiddleware::authorize($request, $roles);
    }

    public static function listFarmers(Request $request, array $vars): Response
    {
        $authResponse = self::authorize($request, ['admin']);
        if ($authResponse !== null) {
            return $authResponse;
        }

        $controller = new FarmerController();
        return $controller->index($request);
    }

    public static function getFarmer(Request $request, array $vars): Response
    {
        $authResponse = self::authorize($request, ['admin']);
        if ($authResponse !== null) {
            return $authResponse;
        }

        $controller = new FarmerController();
        return $controller->show($request, $vars);
    }

    public static function createFarmer(Request $request, array $vars): Response
    {
        $authResponse = self::authorize($request, ['admin']);
        if ($authResponse !== null) {
            return $authResponse;
        }

        $controller = new FarmerController();
        return $controller->create($request);
    }

    public static function listFarms(Request $request, array $vars): Response
    {
        $authResponse = self::authorize($request, ['admin', 'user']);
        if ($authResponse !== null) {
            return $authResponse;
        }

        $controller = new FarmController();
        return $controller->index($request, $vars);
    }

    public static function createFarm(Request $request, array $vars): Response
    {
        $authResponse = self::authorize($request, ['admin', 'user']);
        if ($authResponse !== null) {
            return $authResponse;
        }

        $controller = new FarmController();
        return $controller->create($request);
    }

    public static function getFarm(Request $request, array $vars): Response
    {
        $authResponse = self::authorize($request, ['admin', 'user']);
        if ($authResponse !== null) {
            return $authResponse;
        }

        $controller = new FarmController();
        return $controller->show($request, $vars);
    }

    public static function updateFarm(Request $request, array $vars): Response
    {
        $authResponse = self::authorize($request, ['admin', 'user']);
        if ($authResponse !== null) {
            return $authResponse;
        }

        $controller = new FarmController();
        return $controller->update($request, $vars);
    }

    public static function deleteFarm(Request $request, array $vars): Response
    {
        $authResponse = self::authorize($request, ['admin', 'user']);
        if ($authResponse !== null) {
            return $authResponse;
        }

        $controller = new FarmController();
        return $controller->delete($request, $vars);
    }

    public static function listFarmPlots(Request $request, array $vars): Response
    {
        $authResponse = self::authorize($request, ['admin', 'user']);
        if ($authResponse !== null) {
            return $authResponse;
        }

        $controller = new FarmPlotController();
        return $controller->index($request, $vars);
    }

    public static function createFarmPlot(Request $request, array $vars): Response
    {
        $authResponse = self::authorize($request, ['admin', 'user']);
        if ($authResponse !== null) {
            return $authResponse;
        }

        $controller = new FarmPlotController();
        return $controller->create($request);
    }

    public static function listFamilyMembers(Request $request, array $vars): Response
    {
        $authResponse = self::authorize($request, ['admin', 'user']);
        if ($authResponse !== null) {
            return $authResponse;
        }

        $controller = new FamilyMemberController();
        return $controller->index($request, $vars);
    }

    public static function createFamilyMember(Request $request, array $vars): Response
    {
        $authResponse = self::authorize($request, ['admin', 'user']);
        if ($authResponse !== null) {
            return $authResponse;
        }

        $controller = new FamilyMemberController();
        return $controller->create($request);
    }
}
