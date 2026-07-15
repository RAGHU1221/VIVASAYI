<?php

require_once __DIR__ . '/../vendor/autoload.php';

use App\Config\Environment;
use App\Routes\Router;
use Symfony\Component\HttpFoundation\Response;

Environment::load(__DIR__ . '/../.env');

$allowedOrigins = array_map(
    'trim',
    explode(',', $_ENV['CORS_ALLOWED_ORIGINS'] ?? '*')
);
$requestOrigin = $_SERVER['HTTP_ORIGIN'] ?? '';
$allowOrigin = in_array('*', $allowedOrigins, true)
    ? '*'
    : (in_array($requestOrigin, $allowedOrigins, true) ? $requestOrigin : null);

$corsHeaders = [
    'Access-Control-Allow-Methods' => 'GET, POST, PUT, DELETE, OPTIONS',
    'Access-Control-Allow-Headers' => 'Content-Type, Authorization',
    'Access-Control-Max-Age' => '86400',
];

if ($allowOrigin !== null) {
    $corsHeaders['Access-Control-Allow-Origin'] = $allowOrigin;
}

if (($_SERVER['REQUEST_METHOD'] ?? '') === 'OPTIONS') {
    (new Response('', Response::HTTP_NO_CONTENT, $corsHeaders))->send();
    return;
}

$dispatcher = new Router();
$debug = filter_var($_ENV['APP_DEBUG'] ?? false, FILTER_VALIDATE_BOOLEAN);

try {
    $response = $dispatcher->dispatch();
} catch (Throwable $error) {
    $payload = ['error' => 'Internal Server Error'];
    if ($debug) {
        $payload['message'] = $error->getMessage();
    }

    $response = new Response(
        json_encode($payload),
        Response::HTTP_INTERNAL_SERVER_ERROR,
        ['Content-Type' => 'application/json']
    );
}

foreach ($corsHeaders as $name => $value) {
    $response->headers->set($name, $value);
}
$response->send();
