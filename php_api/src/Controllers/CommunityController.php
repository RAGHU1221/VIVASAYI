<?php

namespace App\Controllers;

use App\Config\Database;
use App\Middleware\AuthMiddleware;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;

class CommunityController
{
    private function ensureTables(): void
    {
        $db = Database::getConnection();
        $db->exec(
            'CREATE TABLE IF NOT EXISTS posts (
              id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
              user_id BIGINT UNSIGNED NOT NULL,
              content TEXT NOT NULL,
              report_count INT UNSIGNED NOT NULL DEFAULT 0,
              created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
              INDEX idx_posts_created (created_at)
            ) ENGINE=InnoDB'
        );
        $db->exec(
            'CREATE TABLE IF NOT EXISTS post_likes (
              post_id BIGINT UNSIGNED NOT NULL,
              user_id BIGINT UNSIGNED NOT NULL,
              created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
              PRIMARY KEY (post_id, user_id)
            ) ENGINE=InnoDB'
        );
        $db->exec(
            'CREATE TABLE IF NOT EXISTS post_comments (
              id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
              post_id BIGINT UNSIGNED NOT NULL,
              user_id BIGINT UNSIGNED NOT NULL,
              content TEXT NOT NULL,
              created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
              INDEX idx_comments_post (post_id, id)
            ) ENGINE=InnoDB'
        );
    }

    public function index(Request $request): JsonResponse
    {
        $userId = AuthMiddleware::getUserId($request);
        if ($userId === null) {
            return new JsonResponse(['error' => 'Unauthorized'], 401);
        }

        $this->ensureTables();
        $stmt = Database::getConnection()->prepare(
            'SELECT p.id, p.user_id, p.content, p.created_at,
                    u.name AS author,
                    (SELECT COUNT(*) FROM post_likes pl WHERE pl.post_id = p.id) AS like_count,
                    (SELECT COUNT(*) FROM post_comments pc WHERE pc.post_id = p.id) AS comment_count,
                    EXISTS(SELECT 1 FROM post_likes pl2 WHERE pl2.post_id = p.id AND pl2.user_id = :uid) AS liked
             FROM posts p
             JOIN users u ON u.id = p.user_id
             ORDER BY p.id DESC
             LIMIT 100'
        );
        $stmt->execute(['uid' => $userId]);

        return new JsonResponse(['posts' => $stmt->fetchAll()]);
    }

    public function create(Request $request): JsonResponse
    {
        $userId = AuthMiddleware::getUserId($request);
        if ($userId === null) {
            return new JsonResponse(['error' => 'Unauthorized'], 401);
        }

        $payload = json_decode($request->getContent(), true);
        $content = is_array($payload) ? trim($payload['content'] ?? '') : '';
        if ($content === '' || mb_strlen($content) > 2000) {
            return new JsonResponse(['error' => 'Content is required (max 2000 chars)'], 400);
        }

        $this->ensureTables();
        $stmt = Database::getConnection()->prepare(
            'INSERT INTO posts (user_id, content) VALUES (:uid, :content)'
        );
        $stmt->execute(['uid' => $userId, 'content' => $content]);

        return new JsonResponse(
            ['message' => 'Created', 'id' => (int) Database::getConnection()->lastInsertId()],
            201
        );
    }

    public function delete(Request $request, array $vars): JsonResponse
    {
        $userId = AuthMiddleware::getUserId($request);
        if ($userId === null) {
            return new JsonResponse(['error' => 'Unauthorized'], 401);
        }

        $this->ensureTables();
        $db = Database::getConnection();
        $postId = (int) $vars['id'];
        $isAdmin = AuthMiddleware::getUserRole($request) === 'admin';

        // Owner illa admin dhan delete panna mudiyum
        $sql = $isAdmin
            ? 'DELETE FROM posts WHERE id = :id'
            : 'DELETE FROM posts WHERE id = :id AND user_id = :uid';
        $stmt = $db->prepare($sql);
        $params = $isAdmin ? ['id' => $postId] : ['id' => $postId, 'uid' => $userId];
        $stmt->execute($params);

        if ($stmt->rowCount() === 0) {
            return new JsonResponse(['error' => 'Post not found'], 404);
        }

        $db->prepare('DELETE FROM post_likes WHERE post_id = :id')->execute(['id' => $postId]);
        $db->prepare('DELETE FROM post_comments WHERE post_id = :id')->execute(['id' => $postId]);

        return new JsonResponse(['message' => 'Deleted']);
    }

    public function toggleLike(Request $request, array $vars): JsonResponse
    {
        $userId = AuthMiddleware::getUserId($request);
        if ($userId === null) {
            return new JsonResponse(['error' => 'Unauthorized'], 401);
        }

        $this->ensureTables();
        $db = Database::getConnection();
        $postId = (int) $vars['id'];

        $del = $db->prepare('DELETE FROM post_likes WHERE post_id = :pid AND user_id = :uid');
        $del->execute(['pid' => $postId, 'uid' => $userId]);

        $liked = false;
        if ($del->rowCount() === 0) {
            $db->prepare('INSERT IGNORE INTO post_likes (post_id, user_id) VALUES (:pid, :uid)')
                ->execute(['pid' => $postId, 'uid' => $userId]);
            $liked = true;
        }

        $count = (int) $db->query('SELECT COUNT(*) AS c FROM post_likes WHERE post_id = ' . $postId)
            ->fetch()['c'];

        return new JsonResponse(['liked' => $liked, 'like_count' => $count]);
    }

    public function comments(Request $request, array $vars): JsonResponse
    {
        $userId = AuthMiddleware::getUserId($request);
        if ($userId === null) {
            return new JsonResponse(['error' => 'Unauthorized'], 401);
        }

        $this->ensureTables();
        $stmt = Database::getConnection()->prepare(
            'SELECT c.id, c.user_id, c.content, c.created_at, u.name AS author
             FROM post_comments c
             JOIN users u ON u.id = c.user_id
             WHERE c.post_id = :pid
             ORDER BY c.id ASC
             LIMIT 100'
        );
        $stmt->execute(['pid' => (int) $vars['id']]);

        return new JsonResponse(['comments' => $stmt->fetchAll()]);
    }

    public function addComment(Request $request, array $vars): JsonResponse
    {
        $userId = AuthMiddleware::getUserId($request);
        if ($userId === null) {
            return new JsonResponse(['error' => 'Unauthorized'], 401);
        }

        $payload = json_decode($request->getContent(), true);
        $content = is_array($payload) ? trim($payload['content'] ?? '') : '';
        if ($content === '' || mb_strlen($content) > 1000) {
            return new JsonResponse(['error' => 'Content is required (max 1000 chars)'], 400);
        }

        $this->ensureTables();
        $stmt = Database::getConnection()->prepare(
            'INSERT INTO post_comments (post_id, user_id, content) VALUES (:pid, :uid, :content)'
        );
        $stmt->execute(['pid' => (int) $vars['id'], 'uid' => $userId, 'content' => $content]);

        return new JsonResponse(['message' => 'Created'], 201);
    }

    public function report(Request $request, array $vars): JsonResponse
    {
        $userId = AuthMiddleware::getUserId($request);
        if ($userId === null) {
            return new JsonResponse(['error' => 'Unauthorized'], 401);
        }

        $this->ensureTables();
        $stmt = Database::getConnection()->prepare(
            'UPDATE posts SET report_count = report_count + 1 WHERE id = :id'
        );
        $stmt->execute(['id' => (int) $vars['id']]);

        return new JsonResponse(['message' => 'Reported']);
    }
}
