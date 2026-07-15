<?php

namespace App\Controllers;

use App\Config\Database;
use App\Middleware\AuthMiddleware;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;

class AiChatController
{
    private const SYSTEM_PROMPT = 'நீங்கள் "விவசாயி AI உதவியாளர்" - தமிழ்நாடு விவசாயிகளுக்கான நட்பான AI உதவியாளர். '
        . 'பயிர் சாகுபடி, நோய் கட்டுப்பாடு, உரம், நீர் மேலாண்மை, மண் வளம், அரசு திட்டங்கள், '
        . 'சந்தை விலை போன்ற விவசாய கேள்விகளுக்கு எளிய தமிழில் நடைமுறை பதில்கள் கொடுங்கள். '
        . 'பதில்கள் சுருக்கமாகவும் (3-6 வாக்கியங்கள்), செயல்படுத்தக்கூடியதாகவும் இருக்க வேண்டும். '
        . 'மருந்து/பூச்சிக்கொல்லி பரிந்துரைக்கும்போது அளவு மற்றும் பாதுகாப்பு குறிப்புகளையும் சேர்க்கவும். '
        . 'உறுதியாக தெரியாத விஷயங்களில் அருகிலுள்ள வேளாண் அலுவலரை அணுக பரிந்துரைக்கவும். '
        . 'விவசாயம் தொடர்பில்லாத கேள்விகளுக்கு பணிவாக மறுத்து விவசாய கேள்விகளுக்கு திருப்பவும்.';

    private const MAX_MESSAGE_LENGTH = 2000;
    private const HISTORY_CONTEXT_LIMIT = 10;

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

        // Last N messages context ku (reverse chronological fetch, then flip)
        $stmt = $db->prepare(
            'SELECT role, message FROM ai_chats WHERE user_id = :uid ORDER BY id DESC LIMIT ' . self::HISTORY_CONTEXT_LIMIT
        );
        $stmt->execute(['uid' => $userId]);
        $history = array_reverse($stmt->fetchAll());

        $messages = [];
        foreach ($history as $row) {
            $messages[] = ['role' => $row['role'], 'content' => $row['message']];
        }
        $messages[] = ['role' => 'user', 'content' => $message];

        $reply = $this->callAnthropic($apiKey, $messages);
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

    private function callAnthropic(string $apiKey, array $messages): ?string
    {
        $model = $_ENV['AI_MODEL'] ?? 'claude-haiku-4-5-20251001';

        $body = json_encode([
            'model' => $model,
            'max_tokens' => 1024,
            'system' => self::SYSTEM_PROMPT,
            'messages' => $messages,
        ], JSON_UNESCAPED_UNICODE);

        $ch = curl_init('https://api.anthropic.com/v1/messages');
        curl_setopt_array($ch, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_POST => true,
            CURLOPT_POSTFIELDS => $body,
            CURLOPT_TIMEOUT => 50,
            CURLOPT_CONNECTTIMEOUT => 10,
            CURLOPT_HTTPHEADER => [
                'Content-Type: application/json',
                'x-api-key: ' . $apiKey,
                'anthropic-version: 2023-06-01',
            ],
        ]);

        $response = curl_exec($ch);
        $status = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);

        if ($response === false || $status !== 200) {
            error_log('AI API error: HTTP ' . $status . ' — ' . substr((string) $response, 0, 500));
            return null;
        }

        $data = json_decode($response, true);
        if (!is_array($data) || !isset($data['content'][0]['text'])) {
            return null;
        }

        return $data['content'][0]['text'];
    }
}
