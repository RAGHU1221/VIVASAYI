<?php

namespace App\Controllers;

use App\Config\Database;
use App\Middleware\AuthMiddleware;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;

class FinanceController
{
    private const TYPES = ['expense', 'income'];

    private function ensureTable(): void
    {
        Database::getConnection()->exec(
            'CREATE TABLE IF NOT EXISTS transactions (
              id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
              user_id BIGINT UNSIGNED NOT NULL,
              farm_id BIGINT UNSIGNED DEFAULT NULL,
              type VARCHAR(10) NOT NULL,
              category VARCHAR(100) NOT NULL,
              amount DECIMAL(12,2) NOT NULL,
              note VARCHAR(500) DEFAULT NULL,
              entry_date DATE NOT NULL,
              created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
              updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
              INDEX idx_txn_user_date (user_id, entry_date),
              INDEX idx_txn_user_type (user_id, type)
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

        $type = $request->query->get('type');
        $month = $request->query->get('month'); // format: YYYY-MM

        $sql = 'SELECT id, farm_id, type, category, amount, note, entry_date
                FROM transactions WHERE user_id = :uid';
        $params = ['uid' => $userId];

        if ($type !== null && in_array($type, self::TYPES, true)) {
            $sql .= ' AND type = :type';
            $params['type'] = $type;
        }

        if ($month !== null && preg_match('/^\d{4}-\d{2}$/', $month)) {
            $sql .= ' AND DATE_FORMAT(entry_date, \'%Y-%m\') = :month';
            $params['month'] = $month;
        }

        $sql .= ' ORDER BY entry_date DESC, id DESC LIMIT 200';

        $stmt = Database::getConnection()->prepare($sql);
        $stmt->execute($params);

        return new JsonResponse(['transactions' => $stmt->fetchAll()]);
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
            'INSERT INTO transactions (user_id, farm_id, type, category, amount, note, entry_date)
             VALUES (:uid, :farm_id, :type, :category, :amount, :note, :entry_date)'
        );
        $stmt->execute([
            'uid' => $userId,
            'farm_id' => isset($payload['farm_id']) ? (int) $payload['farm_id'] : null,
            'type' => $payload['type'],
            'category' => trim($payload['category']),
            'amount' => (float) $payload['amount'],
            'note' => isset($payload['note']) ? mb_substr(trim($payload['note']), 0, 500) : null,
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
            'UPDATE transactions
             SET farm_id = :farm_id, type = :type, category = :category,
                 amount = :amount, note = :note, entry_date = :entry_date
             WHERE id = :id AND user_id = :uid'
        );
        $stmt->execute([
            'id' => (int) $vars['id'],
            'uid' => $userId,
            'farm_id' => isset($payload['farm_id']) ? (int) $payload['farm_id'] : null,
            'type' => $payload['type'],
            'category' => trim($payload['category']),
            'amount' => (float) $payload['amount'],
            'note' => isset($payload['note']) ? mb_substr(trim($payload['note']), 0, 500) : null,
            'entry_date' => $payload['entry_date'],
        ]);

        if ($stmt->rowCount() === 0) {
            return new JsonResponse(['error' => 'Transaction not found'], 404);
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
            'DELETE FROM transactions WHERE id = :id AND user_id = :uid'
        );
        $stmt->execute(['id' => (int) $vars['id'], 'uid' => $userId]);

        if ($stmt->rowCount() === 0) {
            return new JsonResponse(['error' => 'Transaction not found'], 404);
        }

        return new JsonResponse(['message' => 'Deleted']);
    }

    public function summary(Request $request): JsonResponse
    {
        $userId = AuthMiddleware::getUserId($request);
        if ($userId === null) {
            return new JsonResponse(['error' => 'Unauthorized'], 401);
        }

        $this->ensureTable();
        $db = Database::getConnection();

        $currentMonth = date('Y-m');

        // Indha maasam
        $stmt = $db->prepare(
            'SELECT type, COALESCE(SUM(amount), 0) AS total
             FROM transactions
             WHERE user_id = :uid AND DATE_FORMAT(entry_date, \'%Y-%m\') = :month
             GROUP BY type'
        );
        $stmt->execute(['uid' => $userId, 'month' => $currentMonth]);
        $monthTotals = ['expense' => 0.0, 'income' => 0.0];
        foreach ($stmt->fetchAll() as $row) {
            $monthTotals[$row['type']] = (float) $row['total'];
        }

        // Last 6 months trend (Phase 6 reports ku um useful)
        $stmt = $db->prepare(
            'SELECT DATE_FORMAT(entry_date, \'%Y-%m\') AS ym, type, COALESCE(SUM(amount), 0) AS total
             FROM transactions
             WHERE user_id = :uid AND entry_date >= DATE_SUB(CURDATE(), INTERVAL 6 MONTH)
             GROUP BY ym, type
             ORDER BY ym ASC'
        );
        $stmt->execute(['uid' => $userId]);
        $trend = [];
        foreach ($stmt->fetchAll() as $row) {
            $ym = $row['ym'];
            if (!isset($trend[$ym])) {
                $trend[$ym] = ['month' => $ym, 'expense' => 0.0, 'income' => 0.0];
            }
            $trend[$ym][$row['type']] = (float) $row['total'];
        }

        return new JsonResponse([
            'month' => $currentMonth,
            'income' => $monthTotals['income'],
            'expense' => $monthTotals['expense'],
            'profit' => $monthTotals['income'] - $monthTotals['expense'],
            'trend' => array_values($trend),
        ]);
    }

    private function validate(array $payload): ?string
    {
        $type = $payload['type'] ?? '';
        if (!in_array($type, self::TYPES, true)) {
            return 'Type must be expense or income';
        }

        $category = trim($payload['category'] ?? '');
        if ($category === '' || mb_strlen($category) > 100) {
            return 'Category is required (max 100 chars)';
        }

        $amount = $payload['amount'] ?? null;
        if (!is_numeric($amount) || (float) $amount <= 0 || (float) $amount > 99999999) {
            return 'Amount must be a positive number';
        }

        $date = $payload['entry_date'] ?? '';
        if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $date) || strtotime($date) === false) {
            return 'entry_date must be YYYY-MM-DD';
        }

        return null;
    }
}
