<?php

namespace App\Controllers;

use App\Config\Database;
use App\Middleware\AuthMiddleware;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;

/**
 * AI Chat controller — NVIDIA Build (integrate.api.nvidia.com), OpenAI-compatible.
 *
 * Configuration (Render env variables):
 *   AI_API_KEY  — NVIDIA API key from build.nvidia.com (starts with "nvapi-")
 *   AI_BASE_URL — optional override; defaults to https://integrate.api.nvidia.com/v1
 *   AI_MODEL    — model id from the NVIDIA catalog
 *                 (default: sarvamai/sarvam-m — trained on Tamil + 10 other Indic
 *                 languages, +20% better than its base model on Indic-language
 *                 benchmarks. Best default for a Tamil farming assistant.)
 *                 Other options on build.nvidia.com: "meta/llama-3.1-70b-instruct",
 *                 "qwen/qwen3.5-397b-a17b", "z-ai/glm-5.2" (general multilingual,
 *                 not Tamil-tuned specifically).
 *
 * Endpoint called: POST {AI_BASE_URL}/chat/completions
 * Auth: Authorization: Bearer {AI_API_KEY}   (standard OpenAI Bearer format)
 * Response parsed: choices[0].message.content
 * Automatically retries once on network/server failure.
 */
class AiChatController
{
    private const DEFAULT_BASE_URL = 'https://integrate.api.nvidia.com/v1';

    private const SYSTEM_PROMPT = 'நீங்கள் "விவசாயி AI உதவியாளர்" - தமிழ்நாடு விவசாயிகளுக்கான நட்பான AI உதவியாளர். '
        . 'பயிர் சாகுபடி, நோய் கட்டுப்பாடு, உரம், நீர் மேலாண்மை, மண் வளம், அரசு திட்டங்கள், '
        . 'சந்தை விலை போன்ற விவசாய கேள்விகளுக்கு எளிய தமிழில் நடைமுறை பதில்கள் கொடுங்கள். '
        . 'பதில்கள் சுருக்கமாகவும் (3-6 வாக்கியங்கள்), செயல்படுத்தக்கூடியதாகவும் இருக்க வேண்டும். '
        . 'மருந்து/பூச்சிக்கொல்லி பரிந்துரைக்கும்போது அளவு மற்றும் பாதுகாப்பு குறிப்புகளையும் சேர்க்கவும். '
        . 'உறுதியாக தெரியாத விஷயங்களில் அருகிலுள்ள வேளாண் அலுவலரை அணுக பரிந்துரைக்கவும். '
        . 'விவசாயம் தொடர்பில்லாத கேள்விகளுக்கு பணிவாக மறுத்து விவசாய கேள்விகளுக்கு திருப்பவும்.';

    private const MAX_MESSAGE_LENGTH = 2000;
    private const HISTORY_CONTEXT_LIMIT = 10;
    private const MAX_ATTEMPTS = 2; // 1 request + 1 automatic retry

    private function ensureTable(): void
    {
        Database::getConnection()->exec(
            'CREATE TABLE IF NOT EXISTS ai_chats (
              id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
              user_id BIGINT UNSIGNED NOT NULL,
              role VARCHAR(20) NOT NULL,
              message TEXT NOT NULL,
              created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
              INDEX idx_ai_chats_user (user_id, id)
            ) ENGINE=InnoDB'
        );
    }

    public function chat(Request $request): JsonResponse
    {
        $userId = AuthMiddleware::getUserId($request);
        if ($userId === null) {
            return new JsonResponse(['error' => 'Unauthorized'], 401);
        }

        $apiKey = $_ENV['AI_API_KEY'] ?? '';
        $baseUrl = rtrim($_ENV['AI_BASE_URL'] ?? self::DEFAULT_BASE_URL, '/');
        if ($apiKey === '') {
            return new JsonResponse(['error' => 'AI சேவை இன்னும் அமைக்கப்படவில்லை'], 503);
        }

        $payload = json_decode($request->getContent(), true);
        if (!is_array($payload)) {
            return new JsonResponse(['error' => 'Invalid request body'], 400);
        }

        $message = trim($payload['message'] ?? '');
        if ($message === '') {
            return new JsonResponse(['error' => 'Message is required'], 400);
        }
        if (mb_strlen($message) > self::MAX_MESSAGE_LENGTH) {
            return new JsonResponse(['error' => 'செய்தி மிக நீளமாக உள்ளது'], 400);
        }

        $this->ensureTable();
        $db = Database::getConnection();

        // Previous chat history — last N messages as conversation context
        $stmt = $db->prepare(
            'SELECT role, message FROM ai_chats WHERE user_id = :uid ORDER BY id DESC LIMIT ' . self::HISTORY_CONTEXT_LIMIT
        );
        $stmt->execute(['uid' => $userId]);
        $history = array_reverse($stmt->fetchAll());

        // OpenAI-compatible format: system prompt is the first message in the array
        $messages = [['role' => 'system', 'content' => self::SYSTEM_PROMPT]];
        foreach ($history as $row) {
            $messages[] = ['role' => $row['role'], 'content' => $row['message']];
        }
        $messages[] = ['role' => 'user', 'content' => $message];

        $reply = $this->callChatCompletions($baseUrl, $apiKey, $messages);
        if ($reply === null) {
            return new JsonResponse(['error' => 'AI பதில் பெற முடியவில்லை. சிறிது நேரம் கழித்து முயற்சிக்கவும்.'], 502);
        }

        $insert = $db->prepare('INSERT INTO ai_chats (user_id, role, message) VALUES (:uid, :role, :msg)');
        $insert->execute(['uid' => $userId, 'role' => 'user', 'msg' => $message]);
        $insert->execute(['uid' => $userId, 'role' => 'assistant', 'msg' => $reply]);

        return new JsonResponse(['reply' => $reply]);
    }

    public function history(Request $request): JsonResponse
    {
        $userId = AuthMiddleware::getUserId($request);
        if ($userId === null) {
            return new JsonResponse(['error' => 'Unauthorized'], 401);
        }

        $this->ensureTable();
        $stmt = Database::getConnection()->prepare(
            'SELECT role, message, created_at FROM ai_chats WHERE user_id = :uid ORDER BY id ASC LIMIT 100'
        );
        $stmt->execute(['uid' => $userId]);

        return new JsonResponse(['messages' => $stmt->fetchAll()]);
    }

    public function clear(Request $request): JsonResponse
    {
        $userId = AuthMiddleware::getUserId($request);
        if ($userId === null) {
            return new JsonResponse(['error' => 'Unauthorized'], 401);
        }

        $this->ensureTable();
        $stmt = Database::getConnection()->prepare('DELETE FROM ai_chats WHERE user_id = :uid');
        $stmt->execute(['uid' => $userId]);

        return new JsonResponse(['message' => 'Chat history cleared']);
    }

    /**
     * Calls NVIDIA Build's OpenAI-compatible Chat Completions endpoint.
     * Retries once automatically on failure (network error, 5xx, bad response).
     */
    private function callChatCompletions(string $baseUrl, string $apiKey, array $messages): ?string
    {
        $model = $_ENV['AI_MODEL'] ?? 'sarvamai/sarvam-m';

        $body = json_encode([
            'model' => $model,
            'messages' => $messages,
            'max_tokens' => 1024,
            'temperature' => 0.5,
        ], JSON_UNESCAPED_UNICODE);

        for ($attempt = 1; $attempt <= self::MAX_ATTEMPTS; $attempt++) {
            $reply = $this->requestOnce($baseUrl . '/chat/completions', $apiKey, $body);
            if ($reply !== null) {
                return $reply;
            }
            if ($attempt < self::MAX_ATTEMPTS) {
                usleep(800000); // 0.8s wait before the single retry
            }
        }

        return null;
    }

    private function requestOnce(string $url, string $apiKey, string $body): ?string
    {
        $ch = curl_init($url);
        curl_setopt_array($ch, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_POST => true,
            CURLOPT_POSTFIELDS => $body,
            CURLOPT_TIMEOUT => 50,
            CURLOPT_CONNECTTIMEOUT => 10,
            CURLOPT_HTTPHEADER => [
                'Content-Type: application/json',
                // NVIDIA Build uses the standard OpenAI Bearer format
                // (nvapi-... key), not a custom header.
                'Authorization: Bearer ' . $apiKey,
            ],
        ]);

        $response = curl_exec($ch);
        $status = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $curlError = curl_error($ch);
        curl_close($ch);

        if ($response === false || $status !== 200) {
            error_log('AI API error: HTTP ' . $status . ' curl=' . $curlError
                . ' body=' . substr((string) $response, 0, 500));
            return null;
        }

        $data = json_decode($response, true);

        // OpenAI-compatible response: choices[0].message.content
        if (!is_array($data) || !isset($data['choices'][0]['message']['content'])) {
            error_log('AI API unexpected response: ' . substr($response, 0, 500));
            return null;
        }

        $content = trim((string) $data['choices'][0]['message']['content']);

        return $content !== '' ? $content : null;
    }
}
