<?php

namespace App\Controllers;

use App\Config\Database;
use App\Middleware\AuthMiddleware;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;

class DiaryController
{
    private function ensureTable(): void
    {
        Database::getConnection()->exec(
            'CREATE TABLE IF NOT EXISTS diary_entries (
              id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
              user_id BIGINT UNSIGNED NOT NULL,
              farm_id BIGINT UNSIGNED DEFAULT NULL,
              activity VARCHAR(100) NOT NULL,
              note TEXT NOT NULL,
              entry_date DATE NOT NULL,
              created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
              updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
              INDEX idx_diary_user_date (user_id, entry_date)
            ) ENGINE=InnoDB'
        );
    }

    public function index(Request $request): JsonResponse
    {
        $userId = AuthMiddleware::getUserId($request);
        if ($userId === null) {
            return new JsonResponse(['error' => 'Unauthorized'], 401);
        }

        $this->ensureTable();

        $month = $request->query->get('month'); // YYYY-MM

        $sql = 'SELECT id, farm_id, activity, note, entry_date
                FROM diary_entries WHERE user_id = :uid';
        $params = ['uid' => $userId];

        if ($month !== null && preg_match('/^\d{4}-\d{2}$/', $month)) {
            $sql .= ' AND DATE_FORMAT(entry_date, "%Y-%m") = :month';
            $params['month'] = $month;
        }

        $sql .= ' ORDER BY entry_date DESC, id DESC LIMIT 200';

        $stmt = Database::getConnection()->prepare($sql);
        $stmt->execute($params);

        return new JsonResponse(['entries' => $stmt->fetchAll()]);
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

        $error = $this->validate($payload);
        if ($error !== null) {
            return new JsonResponse(['error' => $error], 400);
        }

        $this->ensureTable();
        $stmt = Database::getConnection()->prepare(
            'INSERT INTO diary_entries (user_id, farm_id, activity, note, entry_date)
             VALUES (:uid, :farm_id, :activity, :note, :entry_date)'
        );
        $stmt->execute([
            'uid' => $userId,
            'farm_id' => isset($payload['farm_id']) ? (int) $payload['farm_id'] : null,
            'activity' => trim($payload['activity']),
            'note' => trim($payload['note']),
            'entry_date' => $payload['entry_date'],
        ]);

        $id = (int) Database::getConnection()->lastInsertId();

        return new JsonResponse(['message' => 'Created', 'id' => $id], 201);
    }

    public function update(Request $request, array $vars): JsonResponse
    {
        $userId = AuthMiddleware::getUserId($request);
        if ($userId === null) {
            return new JsonResponse(['error' => 'Unauthorized'], 401);
        }

        $payload = json_decode($request->getContent(), true);
        if (!is_array($payload)) {
            return new JsonResponse(['error' => 'Invalid request body'], 400);
        }

        $error = $this->validate($payload);
        if ($error !== null) {
            return new JsonResponse(['error' => $error], 400);
        }

        $this->ensureTable();
        $stmt = Database::getConnection()->prepare(
            'UPDATE diary_entries
             SET farm_id = :farm_id, activity = :activity, note = :note, entry_date = :entry_date
             WHERE id = :id AND user_id = :uid'
        );
        $stmt->execute([
            'id' => (int) $vars['id'],
            'uid' => $userId,
            'farm_id' => isset($payload['farm_id']) ? (int) $payload['farm_id'] : null,
            'activity' => trim($payload['activity']),
            'note' => trim($payload['note']),
            'entry_date' => $payload['entry_date'],
        ]);

        if ($stmt->rowCount() === 0) {
            return new JsonResponse(['error' => 'Entry not found'], 404);
        }

        return new JsonResponse(['message' => 'Updated']);
    }

    public function delete(Request $request, array $vars): JsonResponse
    {
        $userId = AuthMiddleware::getUserId($request);
        if ($userId === null) {
            return new JsonResponse(['error' => 'Unauthorized'], 401);
        }

        $this->ensureTable();
        $stmt = Database::getConnection()->prepare(
            'DELETE FROM diary_entries WHERE id = :id AND user_id = :uid'
        );
        $stmt->execute(['id' => (int) $vars['id'], 'uid' => $userId]);

        if ($stmt->rowCount() === 0) {
            return new JsonResponse(['error' => 'Entry not found'], 404);
        }

        return new JsonResponse(['message' => 'Deleted']);
    }

    private function validate(array $payload): ?string
    {
        $activity = trim($payload['activity'] ?? '');
        if ($activity === '' || mb_strlen($activity) > 100) {
            return 'Activity is required (max 100 chars)';
        }

        $note = trim($payload['note'] ?? '');
        if ($note === '' || mb_strlen($note) > 5000) {
            return 'Note is required (max 5000 chars)';
        }

        $date = $payload['entry_date'] ?? '';
        if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $date) || strtotime($date) === false) {
            return 'entry_date must be YYYY-MM-DD';
        }

        return null;
    }
}
