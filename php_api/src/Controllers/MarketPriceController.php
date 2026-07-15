<?php

namespace App\Controllers;

use App\Config\Database;
use App\Middleware\AuthMiddleware;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;

class MarketPriceController
{
    /** data.gov.in — Current Daily Price of Various Commodities (Agmarknet) */
    private const RESOURCE_URL = 'https://api.data.gov.in/resource/9ef84268-d588-465a-a308-a864a43d0070';

    private const ALLOWED_DISTRICTS = [
        'Chengalpattu', 'Chennai', 'Coimbatore', 'Cuddalore', 'Dindigul',
        'Erode', 'Kancheepuram', 'Karur', 'Madurai', 'Nagapattinam',
        'Namakkal', 'Salem', 'Thanjavur', 'Theni', 'Tirunelveli',
        'Tiruppur', 'Trichy', 'Vellore', 'Villupuram', 'Virudhunagar',
    ];

    private function ensureTable(): void
    {
        Database::getConnection()->exec(
            'CREATE TABLE IF NOT EXISTS market_prices (
              id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
              price_date DATE NOT NULL,
              district VARCHAR(100) NOT NULL,
              market VARCHAR(150) NOT NULL,
              commodity VARCHAR(150) NOT NULL,
              variety VARCHAR(150) DEFAULT NULL,
              min_price DECIMAL(12,2) DEFAULT NULL,
              max_price DECIMAL(12,2) DEFAULT NULL,
              modal_price DECIMAL(12,2) DEFAULT NULL,
              created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
              INDEX idx_mp_district_date (district, price_date)
            ) ENGINE=InnoDB'
        );
    }

    public function index(Request $request): JsonResponse
    {
        $userId = AuthMiddleware::getUserId($request);
        if ($userId === null) {
            return new JsonResponse(['error' => 'Unauthorized'], 401);
        }

        $district = $request->query->get('district', 'Chengalpattu');
        if (!in_array($district, self::ALLOWED_DISTRICTS, true)) {
            return new JsonResponse(['error' => 'Invalid district'], 400);
        }

        $this->ensureTable();
        $db = Database::getConnection();
        $today = date('Y-m-d');

        // 1. Indha naal cache check
        $rows = $this->getCached($district, $today);

        // 2. Cache illa na upstream fetch + store
        if (empty($rows)) {
            $fetched = $this->fetchFromDataGov($district);
            if (!empty($fetched)) {
                $insert = $db->prepare(
                    'INSERT INTO market_prices
                     (price_date, district, market, commodity, variety, min_price, max_price, modal_price)
                     VALUES (:price_date, :district, :market, :commodity, :variety, :min_price, :max_price, :modal_price)'
                );
                foreach ($fetched as $r) {
                    $insert->execute([
                        'price_date' => $today,
                        'district' => $district,
                        'market' => $r['market'],
                        'commodity' => $r['commodity'],
                        'variety' => $r['variety'],
                        'min_price' => $r['min'],
                        'max_price' => $r['max'],
                        'modal_price' => $r['modal'],
                    ]);
                }
                $rows = $this->getCached($district, $today);
            }
        }

        // 3. Upstream fail — latest stale cache fallback
        $dataDate = $today;
        $stale = false;
        if (empty($rows)) {
            $stmt = $db->prepare(
                'SELECT MAX(price_date) AS d FROM market_prices WHERE district = :district'
            );
            $stmt->execute(['district' => $district]);
            $latest = $stmt->fetch()['d'] ?? null;
            if ($latest !== null) {
                $rows = $this->getCached($district, $latest);
                $dataDate = $latest;
                $stale = true;
            }
        }

        if (empty($rows)) {
            return new JsonResponse([
                'error' => 'இந்த மாவட்டத்திற்கு இன்று விலை தகவல் கிடைக்கவில்லை. பிறகு முயற்சிக்கவும்.',
            ], 404);
        }

        return new JsonResponse([
            'district' => $district,
            'date' => $dataDate,
            'stale' => $stale,
            'prices' => $rows,
        ]);
    }

    private function getCached(string $district, string $date): array
    {
        $stmt = Database::getConnection()->prepare(
            'SELECT market, commodity, variety, min_price, max_price, modal_price
             FROM market_prices
             WHERE district = :district AND price_date = :d
             ORDER BY commodity ASC, market ASC'
        );
        $stmt->execute(['district' => $district, 'd' => $date]);
        return $stmt->fetchAll();
    }

    private function fetchFromDataGov(string $district): array
    {
        $apiKey = $_ENV['DATA_GOV_API_KEY'] ?? '';
        if ($apiKey === '') {
            error_log('Market prices: DATA_GOV_API_KEY not set');
            return [];
        }

        $url = self::RESOURCE_URL . '?' . http_build_query([
            'api-key' => $apiKey,
            'format' => 'json',
            'limit' => 200,
            'filters[state]' => 'Tamil Nadu',
            'filters[district]' => $district,
        ]);

        $ch = curl_init($url);
        curl_setopt_array($ch, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT => 25,
            CURLOPT_CONNECTTIMEOUT => 10,
        ]);
        $response = curl_exec($ch);
        $status = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);

        if ($response === false || $status !== 200) {
            error_log('Market prices upstream error: HTTP ' . $status);
            return [];
        }

        $data = json_decode($response, true);
        if (!is_array($data) || empty($data['records'])) {
            return [];
        }

        $out = [];
        foreach ($data['records'] as $rec) {
            $commodity = trim($rec['commodity'] ?? '');
            if ($commodity === '') {
                continue;
            }
            $out[] = [
                'market' => mb_substr(trim($rec['market'] ?? ''), 0, 150),
                'commodity' => mb_substr($commodity, 0, 150),
                'variety' => mb_substr(trim($rec['variety'] ?? ''), 0, 150),
                'min' => is_numeric($rec['min_price'] ?? null) ? (float) $rec['min_price'] : null,
                'max' => is_numeric($rec['max_price'] ?? null) ? (float) $rec['max_price'] : null,
                'modal' => is_numeric($rec['modal_price'] ?? null) ? (float) $rec['modal_price'] : null,
            ];
        }

        return $out;
    }
}
