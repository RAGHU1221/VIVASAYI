<?php

namespace App\Controllers;

use App\Middleware\AuthMiddleware;
use App\Services\AuditLogService;
use App\Services\DiseaseScanService;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;

/**
 * Disease scanner — sends the farmer's leaf/plant photo to a vision-capable
 * AI model (NVIDIA Build, same account as AiChatController/CropController's
 * text models, different model id) and returns the disease name + a
 * treatment suggestion, both in Tamil.
 *
 * Env vars used:
 *   AI_API_KEY       — same NVIDIA Build key already used elsewhere
 *   AI_BASE_URL       — optional override; defaults to https://integrate.api.nvidia.com/v1
 *   AI_VISION_MODEL   — optional override; defaults to meta/llama-3.2-11b-vision-instruct
 */
class DiseaseScanController
{
    private const DEFAULT_BASE_URL = 'https://integrate.api.nvidia.com/v1';
    private const DEFAULT_VISION_MODEL = 'meta/llama-3.2-11b-vision-instruct';
    private const MAX_IMAGE_BYTES = 6 * 1024 * 1024; // ~6MB decoded, generous safety cap

    private const VISION_PROMPT = 'நீங்கள் ஒரு தாவர நோய் நிபுணர். இந்த தாவர இலை/பயிர் புகைப்படத்தை கவனமாக பரிசோதித்து பின்வரும் "exact" format-ல மட்டும் பதில் சொல்லுங்கள் — வேறு எந்த preamble/வாக்கியமும் சேர்க்க வேண்டாம்:'
        . "\n\nநோய்: <நோயின் பெயர் தமிழில் — இலை ஆரோக்கியமா இருந்தால் 'ஆரோக்கியமான தாவரம்' என்று எழுதுங்கள்>"
        . "\nதீர்வு: <3-4 எளிய தமிழ் வாக்கியங்களில் காரணம் + சிகிச்சை (இயற்கை/கரிம வழி + தேவைப்பட்டால் மருந்து பெயர்) விளக்கம்>"
        . "\n\nபடத்தில் தாவரம்/இலை இல்லை என்றால், 'நோய்: கண்டறிய முடியவில்லை' என்று மட்டும் எழுதி, தீர்வு-வில் தெளிவான புகைப்படம் மீண்டும் எடுக்கச் சொல்லுங்கள். கற்பனையான நோய்களையோ மருந்துகளையோ உருவாக்காதீர்கள் — உறுதியாக தெரியவில்லை என்றால் அதையே சொல்லுங்கள்.";

    private DiseaseScanService $service;
    private AuditLogService $auditLogService;

    public function __construct()
    {
        $this->service = new DiseaseScanService();
        $this->auditLogService = new AuditLogService();
    }

    public function index(Request $request): JsonResponse
    {
        $userId = AuthMiddleware::getUserId($request);
        if ($userId === null) {
            return new JsonResponse(['error' => 'Unauthorized'], 401);
        }

        $farmId = $request->query->get('farm_id');
        if ($farmId !== null && !is_numeric($farmId)) {
            return new JsonResponse(['error' => 'Invalid farm_id filter'], 400);
        }

        $scans = $this->service->getByUserId($userId, $farmId !== null ? (int) $farmId : null);
        return new JsonResponse(array_map(fn($scan) => $scan->toArray(), $scans));
    }

    public function create(Request $request): JsonResponse
    {
        $userId = AuthMiddleware::getUserId($request);
        if ($userId === null) {
            return new JsonResponse(['error' => 'Unauthorized'], 401);
        }

        $payload = json_decode($request->getContent(), true);
        if (!is_array($payload)) {
            return new JsonResponse(['error' => 'Invalid request body'], 400);
        }

        if (empty($payload['image_path']) || !is_string($payload['image_path'])) {
            return new JsonResponse(['error' => 'image_path is required'], 400);
        }

        $payload['user_id'] = $userId;
        $scan = $this->service->create($payload);
        $this->auditLogService->createLog($userId, 'disease_scan.create', ['scan_id' => $scan->id], $request->getClientIp());

        return new JsonResponse($scan->toArray(), 201);
    }

    /**
     * POST /disease-scans/analyze
     * body: { image_base64: "<raw base64, no data: prefix>", mime?: "image/jpeg", farm_id?: int }
     */
    public function analyze(Request $request): JsonResponse
    {
        $userId = AuthMiddleware::getUserId($request);
        if ($userId === null) {
            return new JsonResponse(['error' => 'Unauthorized'], 401);
        }

        $payload = json_decode($request->getContent(), true);
        if (!is_array($payload) || empty($payload['image_base64']) || !is_string($payload['image_base64'])) {
            return new JsonResponse(['error' => 'image_base64 is required'], 400);
        }

        $imageB64 = $payload['image_base64'];
        // rough size check before we even touch the network — 4/3 ratio for base64
        if (strlen($imageB64) > (self::MAX_IMAGE_BYTES * 4 / 3)) {
            return new JsonResponse(['error' => 'படம் மிகப் பெரியது. குறைந்த தரத்தில் மீண்டும் முயற்சிக்கவும்.'], 413);
        }

        $mime = is_string($payload['mime'] ?? null) ? $payload['mime'] : 'image/jpeg';
        $farmId = isset($payload['farm_id']) && is_numeric($payload['farm_id']) ? (int) $payload['farm_id'] : null;

        $aiText = $this->callVisionModel($imageB64, $mime);
        if ($aiText === null) {
            return new JsonResponse([
                'error' => 'படத்தை பகுப்பாய்வு செய்ய முடியவில்லை. இணைய இணைப்பை சரிபார்த்து மீண்டும் முயற்சிக்கவும்.',
            ], 502);
        }

        [$label, $solution] = $this->parseVisionReply($aiText);

        // NOTE: image itself is NOT stored (no object storage wired up yet) —
        // only the AI's text verdict is persisted. image_path records that.
        $scan = $this->service->create([
            'user_id' => $userId,
            'farm_id' => $farmId,
            'image_path' => 'on-device (not stored)',
            'predicted_label' => $label,
            'confidence' => null,
            'model_version' => $_ENV['AI_VISION_MODEL'] ?? self::DEFAULT_VISION_MODEL,
            'solution_text' => $solution,
            'status' => 'completed',
        ]);

        $this->auditLogService->createLog($userId, 'disease_scan.analyze', ['scan_id' => $scan->id], $request->getClientIp());

        return new JsonResponse($scan->toArray(), 201);
    }

    private function callVisionModel(string $imageB64, string $mime): ?string
    {
        $apiKey = $_ENV['AI_API_KEY'] ?? '';
        if ($apiKey === '') {
            error_log('Disease scan: AI_API_KEY not set in environment');
            return null;
        }

        $baseUrl = rtrim($_ENV['AI_BASE_URL'] ?? self::DEFAULT_BASE_URL, '/');
        $model = $_ENV['AI_VISION_MODEL'] ?? self::DEFAULT_VISION_MODEL;

        $body = json_encode([
            'model' => $model,
            'messages' => [
                [
                    'role' => 'user',
                    'content' => [
                        ['type' => 'text', 'text' => self::VISION_PROMPT],
                        ['type' => 'image_url', 'image_url' => [
                            'url' => 'data:' . $mime . ';base64,' . $imageB64,
                        ]],
                    ],
                ],
            ],
            'max_tokens' => 500,
            'temperature' => 0.2,
        ], JSON_UNESCAPED_UNICODE);

        $ch = curl_init($baseUrl . '/chat/completions');
        curl_setopt_array($ch, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_POST => true,
            CURLOPT_POSTFIELDS => $body,
            CURLOPT_HTTPHEADER => [
                'Content-Type: application/json',
                'Authorization: Bearer ' . $apiKey,
            ],
            CURLOPT_TIMEOUT => 60,
            CURLOPT_CONNECTTIMEOUT => 10,
        ]);
        $response = curl_exec($ch);
        $status = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);

        if ($response === false || $status < 200 || $status >= 300) {
            error_log('Disease scan vision call failed: HTTP ' . $status . ' ' . substr((string) $response, 0, 300));
            return null;
        }

        $data = json_decode($response, true);
        $content = $data['choices'][0]['message']['content'] ?? null;

        return is_string($content) && $content !== '' ? trim($content) : null;
    }

    /** @return array{0: string, 1: string} [label, solution] */
    private function parseVisionReply(string $text): array
    {
        $label = 'கண்டறிய முடியவில்லை';
        $solution = $text; // fallback: show the raw reply if format parsing fails

        if (preg_match('/நோய்\s*[:：]\s*(.+?)(?:\n|$)/u', $text, $m)) {
            $label = trim($m[1]);
        }
        if (preg_match('/தீர்வு\s*[:：]\s*(.+)/us', $text, $m)) {
            $solution = trim($m[1]);
        }

        return [$label, $solution];
    }
}
