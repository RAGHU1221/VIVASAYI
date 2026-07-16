<?php

namespace App\Controllers;

use App\Config\Database;
use App\Middleware\AuthMiddleware;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;

class MarketPriceController
{
    private const RESOURCE_URL = 'https://api.data.gov.in/resource/9ef84268-d588-465a-a308-a864a43d0070';
    private const STATE_NAME = 'Tamil Nadu';
    private const PAGE_LIMIT = 500;
    private const MAX_PAGES = 20;

    private const DISTRICTS = [
        'அரியலூர்' => ['Ariyalur'],
        'சென்னை' => ['Chennai'],
        'கோயம்புத்தூர்' => ['Coimbatore'],
        'கடலூர்' => ['Cuddalore'],
        'தர்மபுரி' => ['Dharmapuri'],
        'திண்டுக்கல்' => ['Dindigul'],
        'ஈரோடு' => ['Erode'],
        'காஞ்சிபுரம்' => ['Kancheepuram', 'Kanchipuram'],
        'கன்னியாகுமரி' => ['Kanyakumari', 'Kanniyakumari'],
        'கரூர்' => ['Karur'],
        'கிருஷ்ணகிரி' => ['Krishnagiri'],
        'மதுரை' => ['Madurai'],
        'நாகப்பட்டினம்' => ['Nagapattinam'],
        'நாமக்கல்' => ['Namakkal'],
        'நீலகிரி' => ['Nilgiris', 'The Nilgiris', 'Udhagamandalam'],
        'பெரம்பலூர்' => ['Perambalur'],
        'புதுக்கோட்டை' => ['Pudukkottai'],
        'இராமநாதபுரம்' => ['Ramanathapuram'],
        'சேலம்' => ['Salem'],
        'சிவகங்கை' => ['Sivaganga', 'Sivagangai'],
        'தஞ்சாவூர்' => ['Thanjavur'],
        'தேனி' => ['Theni'],
        'தூத்துக்குடி' => ['Thoothukudi', 'Tuticorin'],
        'திருச்சிராப்பள்ளி' => ['Tiruchirappalli', 'Trichy', 'Tiruchirapalli'],
        'திருநெல்வேலி' => ['Tirunelveli'],
        'திருப்பூர்' => ['Tiruppur', 'Tirupur'],
        'திருவள்ளூர்' => ['Tiruvallur', 'Thiruvallur'],
        'திருவண்ணாமலை' => ['Tiruvannamalai'],
        'திருவாரூர்' => ['Tiruvarur', 'Thiruvarur'],
        'வேலூர்' => ['Vellore'],
        'விழுப்புரம்' => ['Villupuram', 'Viluppuram'],
        'விருதுநகர்' => ['Virudhunagar'],
        'செங்கல்பட்டு' => ['Chengalpattu', 'Chengalpet'],
        'கள்ளக்குறிச்சி' => ['Kallakurichi', 'Villupuram', 'Viluppuram'],
        'மயிலாடுதுறை' => ['Mayiladuthurai', 'Nagapattinam'],
        'ராணிப்பேட்டை' => ['Ranipet', 'Vellore'],
        'தென்காசி' => ['Tenkasi', 'Tirunelveli'],
        'திருப்பத்தூர்' => ['Tirupattur', 'Vellore'],
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

        $districtTamil = $request->query->get('district', 'செங்கல்பட்டு');
        if (!array_key_exists($districtTamil, self::DISTRICTS)) {
            return new JsonResponse(['error' => 'Invalid district'], 400);
        }

        $this->ensureTable();
        $db = Database::getConnection();
        $today = date('Y-m-d');
        $aliases = self::DISTRICTS[$districtTamil];

        $rows = $this->getCached($db, $aliases, $today);
        $dataDate = $today;
        $stale = false;

        if (empty($rows)) {
            $placeholders = implode(',', array_fill(0, count($aliases), '?'));
            $stmt = $db->prepare("SELECT MAX(price_date) AS d FROM market_prices WHERE district IN ($placeholders)");
            $stmt->execute($aliases);
            $latest = $stmt->fetch()['d'] ?? null;
            if ($latest !== null) {
                $rows = $this->getCached($db, $aliases, $latest);
                $dataDate = $latest;
                $stale = ($latest !== $today);
            }
        }

        if (empty($rows)) {
            $fetched = $this->fetchDistrict($aliases[0]);
            if (!empty($fetched)) {
                $this->storeRecords($db, $today, $aliases[0], $fetched);
                $rows = $this->getCached($db, $aliases, $today);
                $dataDate = $today;
                $stale = false;
            }
        }

        if (empty($rows)) {
            return new JsonResponse([
                'error' => 'இந்த மாவட்டத்திற்கு இன்று விலை தகவல் கிடைக்கவில்லை. பிறகு முயற்சிக்கவும்.',
            ], 404);
        }

        return new JsonResponse([
            'district' => $districtTamil,
            'date' => $dataDate,
            'stale' => $stale,
            'prices' => $rows,
        ]);
    }

    public function syncAll(Request $request): JsonResponse
    {
        $expected = $_ENV['MARKET_SYNC_TOKEN'] ?? '';
        $given = (string) $request->query->get('token', '');
        if ($expected === '' || !hash_equals($expected, $given)) {
            return new JsonResponse(['error' => 'Unauthorized'], 403);
        }

        $this->ensureTable();
        $db = Database::getConnection();
        $today = date('Y-m-d');

        $allRecords = $this->fetchAllTamilNaduRecords();
        if (empty($allRecords)) {
            return new JsonResponse([
                'synced' => false,
                'message' => 'Upstream fetch returned 0 records - check DATA_GOV_API_KEY / upstream availability.',
            ], 502);
        }

        $aliasToTamil = [];
        foreach (self::DISTRICTS as $tamil => $aliases) {
            foreach ($aliases as $alias) {
                $aliasToTamil[$this->normalize($alias)] = $tamil;
            }
        }

        $grouped = [];
        $unmatched = [];
        foreach ($allRecords as $rec) {
            $key = $this->normalize($rec['district']);
            $tamil = $aliasToTamil[$key] ?? null;
            if ($tamil === null) {
                $unmatched[$rec['district']] = true;
                continue;
            }
            $grouped[$tamil][] = $rec;
        }

        $db->beginTransaction();
        try {
            $del = $db->prepare('DELETE FROM market_prices WHERE district = :tamil AND price_date = :d');
            foreach ($grouped as $tamil => $records) {
                $del->execute(['tamil' => $tamil, 'd' => $today]);
                $this->storeRecords($db, $today, $tamil, $records);
            }
            $db->commit();
        } catch (\Throwable $e) {
            $db->rollBack();
            error_log('Market sync store failed: ' . $e->getMessage());
            return new JsonResponse(['error' => 'Failed to store synced data'], 500);
        }

        return new JsonResponse([
            'synced' => true,
            'date' => $today,
            'districts_updated' => count($grouped),
            'total_records' => array_sum(array_map('count', $grouped)),
            'unmatched_district_names' => array_slice(array_keys($unmatched), 0, 20),
        ]);
    }

    private function normalize(string $s): string
    {
        return strtolower(trim(preg_replace('/\s+/', ' ', $s)));
    }

    private function getCached(\PDO $db, array $aliases, string $date): array
    {
        $placeholders = implode(',', array_fill(0, count($aliases), '?'));
        $stmt = $db->prepare(
            "SELECT market, commodity, variety, min_price, max_price, modal_price
             FROM market_prices
             WHERE district IN ($placeholders) AND price_date = ?
             ORDER BY commodity ASC, market ASC"
        );
        $stmt->execute([...$aliases, $date]);
        return $stmt->fetchAll();
    }

    private function storeRecords(\PDO $db, string $date, string $districtLabel, array $records): void
    {
        $insert = $db->prepare(
            'INSERT INTO market_prices
             (price_date, district, market, commodity, variety, min_price, max_price, modal_price)
             VALUES (:price_date, :district, :market, :commodity, :variety, :min_price, :max_price, :modal_price)'
        );
        foreach ($records as $r) {
            $insert->execute([
                'price_date' => $date,
                'district' => $districtLabel,
                'market' => $r['market'],
                'commodity' => $r['commodity'],
                'variety' => $r['variety'],
                'min_price' => $r['min'],
                'max_price' => $r['max'],
                'modal_price' => $r['modal'],
            ]);
        }
    }

    private function fetchDistrict(string $districtAlias): array
    {
        return $this->fetchFromDataGov(['filters[district]' => $districtAlias]);
    }

    private function fetchAllTamilNaduRecords(): array
    {
        $all = [];
        for ($page = 0; $page < self::MAX_PAGES; $page++) {
            $batch = $this->fetchFromDataGov([], $page * self::PAGE_LIMIT);
            if (empty($batch)) {
                break;
            }
            $all = array_merge($all, $batch);
            if (count($batch) < self::PAGE_LIMIT) {
                break;
            }
        }
        return $all;
    }

    private function fetchFromDataGov(array $extraFilters, int $offset = 0): array
    {
        $apiKey = $_ENV['DATA_GOV_API_KEY'] ?? '';
        if ($apiKey === '') {
            error_log('Market prices: DATA_GOV_API_KEY not set in environment');
            return [];
        }

        $params = array_merge([
            'api-key' => $apiKey,
            'format' => 'json',
            'limit' => self::PAGE_LIMIT,
            'offset' => $offset,
            'filters[state]' => self::STATE_NAME,
        ], $extraFilters);

        $url = self::RESOURCE_URL . '?' . http_build_query($params);

        $ch = curl_init($url);
        curl_setopt_array($ch, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT => 30,
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
            $district = trim($rec['district'] ?? '');
            if ($commodity === '' || $district === '') {
                continue;
            }
            $out[] = [
                'district' => $district,
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
