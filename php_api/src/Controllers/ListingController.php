<?php

namespace App\Controllers;

use App\Config\Database;
use App\Middleware\AuthMiddleware;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;

class ListingController
{
    private const CATEGORIES = [
        'விளைபொருள்', 'விதை / நாற்று', 'உரம்', 'கருவிகள்', 'கால்நடை', 'மற்றவை',
    ];

    private function ensureTable(): void
    {
        Database::getConnection()->exec(
            'CREATE TABLE IF NOT EXISTS listings (
              id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
              user_id BIGINT UNSIGNED NOT NULL,
              title VARCHAR(150) NOT NULL,
              category VARCHAR(50) NOT NULL,
              price DECIMAL(12,2) NOT NULL,
              unit VARCHAR(50) DEFAULT NULL,
              description TEXT DEFAULT NULL,
              district VARCHAR(100) DEFAULT NULL,
              phone VARCHAR(30) NOT NULL,
              is_active TINYINT(1) NOT NULL DEFAULT 1,
              created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
              updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
              INDEX idx_listings_active (is_active, id),
              INDEX idx_listings_category (category, is_active)
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

        $category = $request->query->get('category');
        $mine = $request->query->get('mine') === '1';

        $sql = 'SELECT l.id, l.user_id, l.title, l.category, l.price, l.unit,
                       l.description, l.district, l.phone, l.is_active, l.created_at,
                       u.name AS seller
                FROM listings l
                JOIN users u ON u.id = l.user_id
                WHERE 1=1';
        $params = [];

        if ($mine) {
            $sql .= ' AND l.user_id = :uid';
            $params['uid'] = $userId;
        } else {
            $sql .= ' AND l.is_active = 1';
        }

        if ($category !== null && in_array($category, self::CATEGORIES, true)) {
            $sql .= ' AND l.category = :category';
            $params['category'] = $category;
        }

        $sql .= ' ORDER BY l.id DESC LIMIT 100';

        $stmt = Database::getConnection()->prepare($sql);
        $stmt->execute($params);

        return new JsonResponse(['listings' => $stmt->fetchAll()]);
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
            'INSERT INTO listings (user_id, title, category, price, unit, description, district, phone)
             VALUES (:uid, :title, :category, :price, :unit, :description, :district, :phone)'
        );
        $params = $this->bind($payload);
        $params['uid'] = $userId;
        $stmt->execute($params);

        return new JsonResponse(
            ['message' => 'Created', 'id' => (int) Database::getConnection()->lastInsertId()],
            201
        );
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
        $params = $this->bind($payload);
        $params['id'] = (int) $vars['id'];
        $params['uid'] = $userId;
        $params['is_active'] = isset($payload['is_active']) ? (int) (bool) $payload['is_active'] : 1;

        $stmt = Database::getConnection()->prepare(
            'UPDATE listings
             SET title = :title, category = :category, price = :price, unit = :unit,
                 description = :description, district = :district, phone = :phone,
                 is_active = :is_active
             WHERE id = :id AND user_id = :uid'
        );
        $stmt->execute($params);

        if ($stmt->rowCount() === 0) {
            return new JsonResponse(['error' => 'Listing not found'], 404);
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
        $isAdmin = AuthMiddleware::getUserRole($request) === 'admin';

        $sql = $isAdmin
            ? 'DELETE FROM listings WHERE id = :id'
            : 'DELETE FROM listings WHERE id = :id AND user_id = :uid';
        $stmt = Database::getConnection()->prepare($sql);
        $params = $isAdmin ? ['id' => (int) $vars['id']] : ['id' => (int) $vars['id'], 'uid' => $userId];
        $stmt->execute($params);

        if ($stmt->rowCount() === 0) {
            return new JsonResponse(['error' => 'Listing not found'], 404);
        }

        return new JsonResponse(['message' => 'Deleted']);
    }

    private function validate(array $payload): ?string
    {
        $title = trim($payload['title'] ?? '');
        if ($title === '' || mb_strlen($title) > 150) {
            return 'Title is required (max 150 chars)';
        }

        $category = trim($payload['category'] ?? '');
        if (!in_array($category, self::CATEGORIES, true)) {
            return 'Invalid category';
        }

        $price = $payload['price'] ?? null;
        if (!is_numeric($price) || (float) $price <= 0 || (float) $price > 99999999) {
            return 'Price must be a positive number';
        }

        $phone = trim($payload['phone'] ?? '');
        if (!preg_match('/^[0-9+\-\s]{8,15}$/', $phone)) {
            return 'Valid phone number is required';
        }

        return null;
    }

    private function bind(array $payload): array
    {
        return [
            'title' => trim($payload['title']),
            'category' => trim($payload['category']),
            'price' => (float) $payload['price'],
            'unit' => isset($payload['unit']) ? mb_substr(trim($payload['unit']), 0, 50) : null,
            'description' => isset($payload['description']) ? mb_substr(trim($payload['description']), 0, 2000) : null,
            'district' => isset($payload['district']) ? mb_substr(trim($payload['district']), 0, 100) : null,
            'phone' => trim($payload['phone']),
        ];
    }
}
