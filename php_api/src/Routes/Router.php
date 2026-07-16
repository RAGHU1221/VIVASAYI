<?php

namespace App\Routes;

use FastRoute\RouteCollector;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use function FastRoute\simpleDispatcher;

use App\Controllers\AuthController;
use App\Controllers\AiChatController;
use App\Controllers\AuditLogController;
use App\Controllers\CommunityController;
use App\Controllers\DiaryController;
use App\Controllers\DiseaseScanController;
use App\Controllers\FarmerController;
use App\Controllers\FinanceController;
use App\Controllers\FarmController;
use App\Controllers\FarmPlotController;
use App\Controllers\FamilyMemberController;
use App\Controllers\ListingController;
use App\Controllers\MarketPriceController;
use App\Controllers\PinController;
use App\Controllers\CropController;
use App\Controllers\SchemeController;
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
            $r->addRoute('POST', '/ai/chat', [self::class, 'aiChat']);
            $r->addRoute('GET', '/ai/chat/history', [self::class, 'aiChatHistory']);
            $r->addRoute('DELETE', '/ai/chat/history', [self::class, 'aiChatClear']);
            $r->addRoute('GET', '/finance/transactions', [self::class, 'financeIndex']);
            $r->addRoute('POST', '/finance/transactions', [self::class, 'financeCreate']);
            $r->addRoute('PUT', '/finance/transactions/{id:\d+}', [self::class, 'financeUpdate']);
            $r->addRoute('DELETE', '/finance/transactions/{id:\d+}', [self::class, 'financeDelete']);
            $r->addRoute('GET', '/finance/summary', [self::class, 'financeSummary']);
            $r->addRoute('GET', '/diary', [self::class, 'diaryIndex']);
            $r->addRoute('POST', '/diary', [self::class, 'diaryCreate']);
            $r->addRoute('PUT', '/diary/{id:\d+}', [self::class, 'diaryUpdate']);
            $r->addRoute('DELETE', '/diary/{id:\d+}', [self::class, 'diaryDelete']);
            $r->addRoute('GET', '/market-prices', [self::class, 'marketPrices']);
            $r->addRoute('GET', '/market-prices/sync', [self::class, 'marketPricesSync']);
            $r->addRoute('GET', '/crops', [self::class, 'cropsIndex']);
            $r->addRoute('GET', '/crops/{id:\d+}/varieties', [self::class, 'cropVarieties']);
            $r->addRoute('POST', '/crops/advisor', [self::class, 'cropAdvisor']);
            $r->addRoute('GET', '/schemes', [self::class, 'schemesIndex']);
            $r->addRoute('POST', '/schemes', [self::class, 'schemesCreate']);
            $r->addRoute('PUT', '/schemes/{id:\d+}', [self::class, 'schemesUpdate']);
            $r->addRoute('DELETE', '/schemes/{id:\d+}', [self::class, 'schemesDelete']);
            $r->addRoute('GET', '/posts', [self::class, 'postsIndex']);
            $r->addRoute('POST', '/posts', [self::class, 'postsCreate']);
            $r->addRoute('DELETE', '/posts/{id:\d+}', [self::class, 'postsDelete']);
            $r->addRoute('POST', '/posts/{id:\d+}/like', [self::class, 'postsLike']);
            $r->addRoute('GET', '/posts/{id:\d+}/comments', [self::class, 'postsComments']);
            $r->addRoute('POST', '/posts/{id:\d+}/comments', [self::class, 'postsAddComment']);
            $r->addRoute('POST', '/posts/{id:\d+}/report', [self::class, 'postsReport']);
            $r->addRoute('GET', '/listings', [self::class, 'listingsIndex']);
            $r->addRoute('POST', '/listings', [self::class, 'listingsCreate']);
            $r->addRoute('PUT', '/listings/{id:\d+}', [self::class, 'listingsUpdate']);
            $r->addRoute('DELETE', '/listings/{id:\d+}', [self::class, 'listingsDelete']);
            $r->addRoute('GET', '/profile', [self::class, 'profile']);
            $r->addRoute('PUT', '/profile', [self::class, 'updateProfile']);
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

    public static function aiChat(Request $request, array $vars): Response
    {
        $authResponse = self::authorize($request, ['admin', 'user']);
        if ($authResponse !== null) {
            return $authResponse;
        }

        $controller = new AiChatController();
        return $controller->chat($request);
    }

    public static function aiChatHistory(Request $request, array $vars): Response
    {
        $authResponse = self::authorize($request, ['admin', 'user']);
        if ($authResponse !== null) {
            return $authResponse;
        }

        $controller = new AiChatController();
        return $controller->history($request);
    }

    public static function aiChatClear(Request $request, array $vars): Response
    {
        $authResponse = self::authorize($request, ['admin', 'user']);
        if ($authResponse !== null) {
            return $authResponse;
        }

        $controller = new AiChatController();
        return $controller->clear($request);
    }

    public static function financeIndex(Request $request, array $vars): Response
    {
        $authResponse = self::authorize($request, ['admin', 'user']);
        if ($authResponse !== null) {
            return $authResponse;
        }

        $controller = new FinanceController();
        return $controller->index($request);
    }

    public static function financeCreate(Request $request, array $vars): Response
    {
        $authResponse = self::authorize($request, ['admin', 'user']);
        if ($authResponse !== null) {
            return $authResponse;
        }

        $controller = new FinanceController();
        return $controller->create($request);
    }

    public static function financeUpdate(Request $request, array $vars): Response
    {
        $authResponse = self::authorize($request, ['admin', 'user']);
        if ($authResponse !== null) {
            return $authResponse;
        }

        $controller = new FinanceController();
        return $controller->update($request, $vars);
    }

    public static function financeDelete(Request $request, array $vars): Response
    {
        $authResponse = self::authorize($request, ['admin', 'user']);
        if ($authResponse !== null) {
            return $authResponse;
        }

        $controller = new FinanceController();
        return $controller->delete($request, $vars);
    }

    public static function financeSummary(Request $request, array $vars): Response
    {
        $authResponse = self::authorize($request, ['admin', 'user']);
        if ($authResponse !== null) {
            return $authResponse;
        }

        $controller = new FinanceController();
        return $controller->summary($request);
    }

    public static function diaryIndex(Request $request, array $vars): Response
    {
        $authResponse = self::authorize($request, ['admin', 'user']);
        if ($authResponse !== null) {
            return $authResponse;
        }

        $controller = new DiaryController();
        return $controller->index($request);
    }

    public static function diaryCreate(Request $request, array $vars): Response
    {
        $authResponse = self::authorize($request, ['admin', 'user']);
        if ($authResponse !== null) {
            return $authResponse;
        }

        $controller = new DiaryController();
        return $controller->create($request);
    }

    public static function diaryUpdate(Request $request, array $vars): Response
    {
        $authResponse = self::authorize($request, ['admin', 'user']);
        if ($authResponse !== null) {
            return $authResponse;
        }

        $controller = new DiaryController();
        return $controller->update($request, $vars);
    }

    public static function diaryDelete(Request $request, array $vars): Response
    {
        $authResponse = self::authorize($request, ['admin', 'user']);
        if ($authResponse !== null) {
            return $authResponse;
        }

        $controller = new DiaryController();
        return $controller->delete($request, $vars);
    }

    public static function marketPrices(Request $request, array $vars): Response
    {
        $authResponse = self::authorize($request, ['admin', 'user']);
        if ($authResponse !== null) {
            return $authResponse;
        }

        $controller = new MarketPriceController();
        return $controller->index($request);
    }

    public static function marketPricesSync(Request $request, array $vars): Response
    {
        // NOTE: intentionally NO self::authorize() here — this endpoint is
        // hit once a day by an external cron service (cron-job.org), not by
        // a logged-in farmer. It checks its own MARKET_SYNC_TOKEN secret
        // inside MarketPriceController::syncAll().
        $controller = new MarketPriceController();
        return $controller->syncAll($request);
    }

        public static function cropsIndex(Request $request, array $vars): Response
    {
        $authResponse = self::authorize($request, ['admin', 'user']);
        if ($authResponse !== null) {
            return $authResponse;
        }

        return (new CropController())->crops($request);
    }

    public static function cropVarieties(Request $request, array $vars): Response
    {
        $authResponse = self::authorize($request, ['admin', 'user']);
        if ($authResponse !== null) {
            return $authResponse;
        }

        return (new CropController())->varieties($request, $vars);
    }

    public static function cropAdvisor(Request $request, array $vars): Response
    {
        $authResponse = self::authorize($request, ['admin', 'user']);
        if ($authResponse !== null) {
            return $authResponse;
        }

        return (new CropController())->advisor($request);
    }

    public static function schemesIndex(Request $request, array $vars): Response
    {
        $authResponse = self::authorize($request, ['admin', 'user']);
        if ($authResponse !== null) {
            return $authResponse;
        }

        $controller = new SchemeController();
        return $controller->index($request);
    }

    public static function schemesCreate(Request $request, array $vars): Response
    {
        $authResponse = self::authorize($request, ['admin']);
        if ($authResponse !== null) {
            return $authResponse;
        }

        $controller = new SchemeController();
        return $controller->create($request);
    }

    public static function schemesUpdate(Request $request, array $vars): Response
    {
        $authResponse = self::authorize($request, ['admin']);
        if ($authResponse !== null) {
            return $authResponse;
        }

        $controller = new SchemeController();
        return $controller->update($request, $vars);
    }

    public static function schemesDelete(Request $request, array $vars): Response
    {
        $authResponse = self::authorize($request, ['admin']);
        if ($authResponse !== null) {
            return $authResponse;
        }

        $controller = new SchemeController();
        return $controller->delete($request, $vars);
    }

    public static function postsIndex(Request $request, array $vars): Response
    {
        $authResponse = self::authorize($request, ['admin', 'user']);
        if ($authResponse !== null) {
            return $authResponse;
        }

        $controller = new CommunityController();
        return $controller->index($request);
    }

    public static function postsCreate(Request $request, array $vars): Response
    {
        $authResponse = self::authorize($request, ['admin', 'user']);
        if ($authResponse !== null) {
            return $authResponse;
        }

        $controller = new CommunityController();
        return $controller->create($request);
    }

    public static function postsDelete(Request $request, array $vars): Response
    {
        $authResponse = self::authorize($request, ['admin', 'user']);
        if ($authResponse !== null) {
            return $authResponse;
        }

        $controller = new CommunityController();
        return $controller->delete($request, $vars);
    }

    public static function postsLike(Request $request, array $vars): Response
    {
        $authResponse = self::authorize($request, ['admin', 'user']);
        if ($authResponse !== null) {
            return $authResponse;
        }

        $controller = new CommunityController();
        return $controller->toggleLike($request, $vars);
    }

    public static function postsComments(Request $request, array $vars): Response
    {
        $authResponse = self::authorize($request, ['admin', 'user']);
        if ($authResponse !== null) {
            return $authResponse;
        }

        $controller = new CommunityController();
        return $controller->comments($request, $vars);
    }

    public static function postsAddComment(Request $request, array $vars): Response
    {
        $authResponse = self::authorize($request, ['admin', 'user']);
        if ($authResponse !== null) {
            return $authResponse;
        }

        $controller = new CommunityController();
        return $controller->addComment($request, $vars);
    }

    public static function postsReport(Request $request, array $vars): Response
    {
        $authResponse = self::authorize($request, ['admin', 'user']);
        if ($authResponse !== null) {
            return $authResponse;
        }

        $controller = new CommunityController();
        return $controller->report($request, $vars);
    }

    public static function listingsIndex(Request $request, array $vars): Response
    {
        $authResponse = self::authorize($request, ['admin', 'user']);
        if ($authResponse !== null) {
            return $authResponse;
        }

        $controller = new ListingController();
        return $controller->index($request);
    }

    public static function listingsCreate(Request $request, array $vars): Response
    {
        $authResponse = self::authorize($request, ['admin', 'user']);
        if ($authResponse !== null) {
            return $authResponse;
        }

        $controller = new ListingController();
        return $controller->create($request);
    }

    public static function listingsUpdate(Request $request, array $vars): Response
    {
        $authResponse = self::authorize($request, ['admin', 'user']);
        if ($authResponse !== null) {
            return $authResponse;
        }

        $controller = new ListingController();
        return $controller->update($request, $vars);
    }

    public static function listingsDelete(Request $request, array $vars): Response
    {
        $authResponse = self::authorize($request, ['admin', 'user']);
        if ($authResponse !== null) {
            return $authResponse;
        }

        $controller = new ListingController();
        return $controller->delete($request, $vars);
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

    public static function updateProfile(Request $request, array $vars): Response
    {
        $authResponse = self::authorize($request, ['admin', 'user']);
        if ($authResponse !== null) {
            return $authResponse;
        }

        $controller = new AuthController();
        return $controller->updateProfile($request);
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
