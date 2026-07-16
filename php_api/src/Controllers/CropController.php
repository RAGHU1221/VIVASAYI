<?php

namespace App\Controllers;

use App\Config\Database;
use App\Middleware\AuthMiddleware;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;

/**
 * விவசாயி AI — Smart Paddy Advisor (Crop Master architecture).
 *
 * Tables: crop_master, crop_varieties (auto-created + auto-seeded).
 * Seed data: well-documented TNAU-released paddy varieties only.
 * AI: reuses the same NVIDIA Build chat-completions endpoint as AiChatController.
 * The AI is instructed to rank ONLY the varieties returned from the database —
 * never to invent varieties, prices, or schedules (strict rule from spec v2.0).
 *
 * Endpoints:
 *   GET  /crops                    — active crops from crop_master
 *   GET  /crops/{id}/varieties     — varieties with optional filters
 *   POST /crops/advisor            — inputs → DB match → AI ranking (Tamil)
 */
class CropController
{
    private const DEFAULT_BASE_URL = 'https://integrate.api.nvidia.com/v1';
    private const MAX_ATTEMPTS = 2;

    private const NO_MATCH_MESSAGE = "உங்கள் பகுதியில் இந்த தகவலுக்கான பொருத்தமான நெல் ரகம் தற்போது தரவுத்தளத்தில் இல்லை.\n\nஅருகிலுள்ள வேளாண்மை விரிவாக்க மையம் அல்லது வேளாண்மை அலுவலகத்தை தொடர்பு கொள்ளவும்.";

    private const ADVISOR_SYSTEM_PROMPT = 'நீங்கள் "விவசாயி AI" — தமிழ்நாடு விவசாயிகளுக்கான நெல் ரக ஆலோசகர். '
        . 'TNAU, ICAR, தமிழ்நாடு வேளாண்மைத் துறை பரிந்துரைகளின் அடிப்படையில் செயல்படுபவர். '
        . 'கீழே தரப்படும் தரவுத்தள ரகங்களை மட்டுமே பயன்படுத்தி பதில் சொல்லுங்கள் — '
        . 'புதிய ரகங்களை உருவாக்கக்கூடாது, கற்பனை சந்தை விலை/உர அட்டவணை/மருந்து பரிந்துரை தரக்கூடாது. '
        . 'விவசாயியின் தேவைகளுடன் ஒப்பிட்டு ரகங்களை தரவரிசைப்படுத்துங்கள்: '
        . '🥇 சிறந்த தேர்வு, 🥈 அடுத்த தேர்வு, 🥉 நல்ல தேர்வு. '
        . 'ஒவ்வொரு ரகத்திற்கும் ஏன் பொருத்தம் என்பதை 2-3 எளிய தமிழ் வாக்கியங்களில் விளக்குங்கள் '
        . '(காலம், மகசூல், மண், தண்ணீர், பருவம் பொருத்தம் ஆகியவற்றின் அடிப்படையில்). '
        . 'இறுதியில் விதை கிடைக்குமிடம்/சரியான அளவு நிச்சயம் தெரிய அருகிலுள்ள வேளாண்மை அலுவலகத்தை '
        . 'தொடர்பு கொள்ள ஒரு வரியில் பரிந்துரைக்கவும். எளிய தமிழில் மட்டுமே பதில் சொல்லுங்கள்.';

    // ---------------------------------------------------------------
    // Schema + seed
    // ---------------------------------------------------------------

    private function ensureTables(): void
    {
        $db = Database::getConnection();

        $db->exec(
            'CREATE TABLE IF NOT EXISTS crop_master (
              crop_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
              crop_name_tamil VARCHAR(100) NOT NULL,
              crop_name_english VARCHAR(100) NOT NULL,
              crop_icon VARCHAR(50) DEFAULT NULL,
              status TINYINT(1) NOT NULL DEFAULT 1,
              UNIQUE KEY uq_crop_english (crop_name_english)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4'
        );

        $db->exec(
            'CREATE TABLE IF NOT EXISTS crop_varieties (
              variety_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
              crop_id INT UNSIGNED NOT NULL,
              variety_name_tamil VARCHAR(150) NOT NULL,
              variety_name_english VARCHAR(150) NOT NULL,
              company VARCHAR(150) DEFAULT NULL,
              category VARCHAR(50) DEFAULT NULL,
              duration VARCHAR(50) DEFAULT NULL,
              yield VARCHAR(80) DEFAULT NULL,
              season VARCHAR(150) DEFAULT NULL,
              soil_type VARCHAR(200) DEFAULT NULL,
              water_requirement VARCHAR(50) DEFAULT NULL,
              tnau_reference VARCHAR(255) DEFAULT NULL,
              status TINYINT(1) NOT NULL DEFAULT 1,
              INDEX idx_variety_crop (crop_id, status),
              CONSTRAINT fk_variety_crop FOREIGN KEY (crop_id)
                REFERENCES crop_master (crop_id) ON DELETE CASCADE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4'
        );

        $this->seedIfEmpty($db);
        $this->seedCompanyVarietiesIfMissing($db);
    }

    private function seedIfEmpty(\PDO $db): void
    {
        $count = (int) $db->query('SELECT COUNT(*) FROM crop_master')->fetchColumn();
        if ($count > 0) {
            return;
        }

        $db->prepare(
            'INSERT INTO crop_master (crop_name_tamil, crop_name_english, crop_icon, status)
             VALUES (:ta, :en, :icon, 1)'
        )->execute(['ta' => 'நெல்', 'en' => 'Paddy', 'icon' => 'grass']);
        $paddyId = (int) $db->lastInsertId();

        // -------------------------------------------------------------
        // TNAU-released, widely documented varieties (Crop Production
        // Guide). Duration = days, yield = approx t/ha under recommended
        // practice. Values are indicative — exact agronomy (fertilizer
        // schedule, spacing, seed rate) should be filled from the
        // official TNAU Crop Production Guide before production use.
        // -------------------------------------------------------------
        $varieties = [
            ['ஏடிடி 43', 'ADT 43', 'TRRI ஆடுதுறை (TNAU)', 'HYV', '110', '~5.8 t/ha', 'குறுவை,சொர்ணவாரி', 'களிமண்,வண்டல்', 'நடுத்தரம்', 'TNAU Crop Production Guide - Rice'],
            ['ஏடிடி 45', 'ADT 45', 'TRRI ஆடுதுறை (TNAU)', 'HYV', '110', '~6.0 t/ha', 'குறுவை,சொர்ணவாரி', 'களிமண்,வண்டல்', 'நடுத்தரம்', 'TNAU Crop Production Guide - Rice'],
            ['ஏடிடி 37', 'ADT 37', 'TRRI ஆடுதுறை (TNAU)', 'HYV', '105-110', '~5.5 t/ha', 'குறுவை,நவரை', 'களிமண்,வண்டல்', 'நடுத்தரம்', 'TNAU Crop Production Guide - Rice'],
            ['ஏடிடி 39', 'ADT 39', 'TRRI ஆடுதுறை (TNAU)', 'HYV', '120-125', '~5.8 t/ha', 'தாளடி,சம்பா', 'களிமண்,வண்டல்', 'நடுத்தரம்', 'TNAU Crop Production Guide - Rice'],
            ['ஏடிடி 53', 'ADT 53', 'TRRI ஆடுதுறை (TNAU)', 'HYV', '110', '~6.2 t/ha', 'குறுவை,சொர்ணவாரி', 'களிமண்,வண்டல்', 'நடுத்தரம்', 'TNAU Crop Production Guide - Rice'],
            ['கோ 51', 'CO 51', 'TNAU கோயம்புத்தூர்', 'HYV', '105-110', '~6.5 t/ha', 'குறுவை,நவரை,சொர்ணவாரி', 'களிமண்,வண்டல்,செம்மண்', 'நடுத்தரம்', 'TNAU Crop Production Guide - Rice'],
            ['கோ 43', 'CO 43', 'TNAU கோயம்புத்தூர்', 'HYV', '130-135', '~6.0 t/ha', 'சம்பா,தாளடி', 'களிமண்,உவர் மண்', 'அதிகம்', 'TNAU Crop Production Guide - Rice'],
            ['ஏஎஸ்டி 16', 'ASD 16', 'RRS அம்பாசமுத்திரம் (TNAU)', 'HYV', '110-115', '~5.8 t/ha', 'குறுவை,சொர்ணவாரி', 'களிமண்,வண்டல்', 'நடுத்தரம்', 'TNAU Crop Production Guide - Rice'],
            ['எம்டியு 5', 'MDU 5', 'AC&RI மதுரை (TNAU)', 'HYV', '115-120', '~5.5 t/ha', 'குறுவை,தாளடி', 'களிமண்,செம்மண்', 'நடுத்தரம்', 'TNAU Crop Production Guide - Rice'],
            ['டிஆர்ஒய் 1', 'TRY 1', 'ADAC&RI திருச்சி (TNAU)', 'HYV', '130-135', '~4.5 t/ha', 'சம்பா', 'உவர் மண்,களிமண்', 'அதிகம்', 'TNAU Crop Production Guide - Rice (உவர் நில ரகம்)'],
            ['வெள்ளை பொன்னி', 'White Ponni', 'TNAU', 'Traditional/HYV', '130-135', '~4.5-5.0 t/ha', 'சம்பா', 'களிமண்,வண்டல்', 'அதிகம்', 'TNAU Crop Production Guide - Rice (பிரீமியம் அரிசி)'],
            ['சிஆர் 1009 (சாவித்திரி)', 'CR 1009 (Savithri)', 'CRRI கட்டாக் (ICAR)', 'HYV', '150-155', '~5.8 t/ha', 'சம்பா', 'கனமான களிமண்', 'அதிகம்', 'ICAR-NRRI / TNAU அங்கீகரிக்கப்பட்ட ரகம்'],
            ['பிபிடி 5204 (சாம்பா மசூரி)', 'BPT 5204 (Samba Mahsuri)', 'APAU பாபட்லா', 'HYV', '145-150', '~5.0 t/ha', 'சம்பா', 'களிமண்,வண்டல்', 'அதிகம்', 'ICAR அங்கீகரிக்கப்பட்ட ரகம் (நுண் அரிசி)'],
            ['ஐஆர் 64', 'IR 64', 'IRRI', 'HYV', '115-120', '~5.5 t/ha', 'குறுவை,தாளடி', 'களிமண்,வண்டல்', 'நடுத்தரம்', 'IRRI/ICAR அங்கீகரிக்கப்பட்ட ரகம்'],
        ];

        $stmt = $db->prepare(
            'INSERT INTO crop_varieties
               (crop_id, variety_name_tamil, variety_name_english, company, category,
                duration, yield, season, soil_type, water_requirement, tnau_reference, status)
             VALUES (:cid, :ta, :en, :co, :cat, :dur, :yld, :sea, :soil, :water, :ref, 1)'
        );
        foreach ($varieties as $v) {
            $stmt->execute([
                'cid' => $paddyId,
                'ta' => $v[0], 'en' => $v[1], 'co' => $v[2], 'cat' => $v[3],
                'dur' => $v[4], 'yld' => $v[5], 'sea' => $v[6], 'soil' => $v[7],
                'water' => $v[8], 'ref' => $v[9],
            ]);
        }
    }

    /**
     * Private-company hybrid varieties popular in Tamil Nadu + Andhra Pradesh
     * (RNR, Kaveri, Mahendra). Added as a separate idempotent step (checked
     * by variety_name_english) so it safely runs on databases that were
     * already seeded before this update — including the live production DB.
     *
     * Sources (per strict rule: no imaginary varieties/prices):
     *  - RNR 15048 (Telangana Sona): released by PJTSAU, Rajendranagar —
     *    Gazette Notification S.O. 2238(E), 29.06.2016. 120-125 days,
     *    6500-7000 kg/ha, blast resistant. Widely grown beyond Telangana
     *    incl. Andhra Pradesh, Tamil Nadu, Karnataka.
     *  - Kaveri 468 / KPH 468: Kaveri Seeds Company Ltd (est. 1986,
     *    Secunderabad, AP) — hybrid, ~115-130 days depending on region,
     *    sold and grown across AP/Telangana/TN.
     *  - Mahendra MPR 606 / Sowbhagya Gold: Mahendra Agrigenetics Pvt Ltd
     *    (est. 1991, Warangal, AP) — improved/hybrid paddy seeds marketed
     *    in Tamil Nadu.
     *
     * NOTE: these are commercial/private hybrids, not TNAU-bred varieties —
     * category is marked "Hybrid (தனியார்)" to distinguish from the
     * TNAU/ICAR public varieties above. Exact fertilizer/spacing schedules
     * should be confirmed with the company's seed packet / local dealer
     * before advising a farmer, same as noted for the TNAU list.
     */
    private function seedCompanyVarietiesIfMissing(\PDO $db): void
    {
        $cropId = (int) $db->query(
            "SELECT crop_id FROM crop_master WHERE crop_name_english = 'Paddy' LIMIT 1"
        )->fetchColumn();
        if ($cropId === 0) {
            return;
        }

        $varieties = [
            // ta, en, company, category, duration, yield, season, soil, water, reference
            ['ஆர்என்ஆர் 15048 (தெலங்கானா சோனா)', 'RNR 15048 (Telangana Sona)', 'PJTSAU ராஜேந்திரநகர் (Telangana)', 'Hybrid (தனியார்)', '120-125', '~6.5-7.0 t/ha', 'கார்/கோடை (kharif,rabi)', 'களிமண்,வண்டல்', 'நடுத்தரம்', 'PJTSAU Gazette Notification S.O.2238(E) 29.06.2016 — தமிழ்நாடு,ஆந்திரா,கர்நாடகாவிலும் பயிரிடப்படுகிறது'],
            ['காவேரி 468', 'Kaveri 468', 'Kaveri Seeds Company Ltd (Secunderabad, AP)', 'Hybrid (தனியார்)', '115-130', 'தனியார் விதை தர அறிக்கை படி', 'கார்/கோடை', 'களிமண்,வண்டல்', 'நடுத்தரம்', 'நிறுவன விதை தொகுப்பு விவரம் — ஆந்திரா/தெலங்கானா/தமிழ்நாடு'],
            ['காவேரி கேபிஎச் 468', 'Kaveri KPH 468', 'Kaveri Seeds Company Ltd (Secunderabad, AP)', 'Hybrid (தனியார்)', '115-120', 'விவசாயி அனுபவப்படி அதிக மகசூல்', 'கார்/கோடை', 'களிமண்,வண்டல்', 'நடுத்தரம்', 'நிறுவன விதை தொகுப்பு விவரம்'],
            ['மகேந்திரா எம்பிஆர் 606', 'Mahendra MPR 606', 'Mahendra Agrigenetics Pvt Ltd (Warangal, AP)', 'Hybrid (தனியார்)', '100-110', 'நிறுவன விதை தர அறிக்கை படி', 'கார்/கோடை', 'களிமண்,வண்டல்', 'நடுத்தரம்', 'நிறுவன விதை தொகுப்பு விவரம் — குறுகிய கால, நுண் அரிசி ரகம்'],
            ['மகேந்திரா சௌபாக்யா கோல்டு', 'Mahendra Sowbhagya Gold', 'Mahendra Agrigenetics Pvt Ltd (Warangal, AP)', 'Hybrid (தனியார்)', '130-135', 'நிறுவன விதை தர அறிக்கை படி', 'சம்பா,தாளடி', 'களிமண்,வண்டல்', 'அதிகம்', 'நிறுவன விதை தொகுப்பு விவரம் — நீண்ட கால ரகம்'],
        ];

        $exists = $db->prepare(
            'SELECT COUNT(*) FROM crop_varieties WHERE crop_id = :cid AND variety_name_english = :en'
        );
        $insert = $db->prepare(
            'INSERT INTO crop_varieties
               (crop_id, variety_name_tamil, variety_name_english, company, category,
                duration, yield, season, soil_type, water_requirement, tnau_reference, status)
             VALUES (:cid, :ta, :en, :co, :cat, :dur, :yld, :sea, :soil, :water, :ref, 1)'
        );

        foreach ($varieties as $v) {
            $exists->execute(['cid' => $cropId, 'en' => $v[1]]);
            if ((int) $exists->fetchColumn() > 0) {
                continue; // already seeded — skip
            }
            $insert->execute([
                'cid' => $cropId,
                'ta' => $v[0], 'en' => $v[1], 'co' => $v[2], 'cat' => $v[3],
                'dur' => $v[4], 'yld' => $v[5], 'sea' => $v[6], 'soil' => $v[7],
                'water' => $v[8], 'ref' => $v[9],
            ]);
        }
    }

    public function crops(Request $request): JsonResponse
    {
        if (AuthMiddleware::getUserId($request) === null) {
            return new JsonResponse(['error' => 'Unauthorized'], 401);
        }
        $this->ensureTables();
        $rows = Database::getConnection()
            ->query('SELECT crop_id, crop_name_tamil, crop_name_english, crop_icon FROM crop_master WHERE status = 1 ORDER BY crop_id')
            ->fetchAll();

        return new JsonResponse(['crops' => $rows]);
    }

    // ---------------------------------------------------------------
    // GET /crops/{id}/varieties?season=&soil=&water=&max_duration=
    // ---------------------------------------------------------------

    public function varieties(Request $request, array $vars): JsonResponse
    {
        if (AuthMiddleware::getUserId($request) === null) {
            return new JsonResponse(['error' => 'Unauthorized'], 401);
        }
        $this->ensureTables();

        $cropId = (int) ($vars['id'] ?? 0);
        [$rows] = $this->matchVarieties(
            $cropId,
            trim($request->query->get('season', '')),
            trim($request->query->get('soil', '')),
            trim($request->query->get('water', '')),
            trim($request->query->get('max_duration', ''))
        );

        return new JsonResponse(['varieties' => $rows]);
    }

    // ---------------------------------------------------------------
    // POST /crops/advisor
    // body: { crop_id, district, taluk, village, season, month, soil_type,
    //         water, duration_preference, purpose, budget, organic }
    // ---------------------------------------------------------------

    public function advisor(Request $request): JsonResponse
    {
        if (AuthMiddleware::getUserId($request) === null) {
            return new JsonResponse(['error' => 'Unauthorized'], 401);
        }
        $this->ensureTables();

        $p = json_decode($request->getContent(), true);
        if (!is_array($p)) {
            return new JsonResponse(['error' => 'Invalid request body'], 400);
        }

        $cropId = (int) ($p['crop_id'] ?? 1);
        $season = trim((string) ($p['season'] ?? ''));
        $soil = trim((string) ($p['soil_type'] ?? ''));
        $water = trim((string) ($p['water'] ?? ''));
        $durationPref = trim((string) ($p['duration_preference'] ?? ''));

        $maxDuration = '';
        if ($durationPref === 'குறுகிய') {
            $maxDuration = '115';
        } elseif ($durationPref === 'நடுத்தர') {
            $maxDuration = '135';
        }

        [$rows, $relaxed] = $this->matchVarieties($cropId, $season, $soil, $water, $maxDuration);

        if (count($rows) === 0) {
            return new JsonResponse([
                'matched' => 0,
                'varieties' => [],
                'analysis' => self::NO_MATCH_MESSAGE,
            ]);
        }

        $rows = array_slice($rows, 0, 5); // Top 5 per spec

        // AI ranking — DB rows are the ONLY data given to the model
        $analysis = $this->aiRank($rows, $p, $relaxed);

        return new JsonResponse([
            'matched' => count($rows),
            'relaxed_filters' => $relaxed,
            'varieties' => $rows,
            'analysis' => $analysis,
        ]);
    }

    /**
     * Filters varieties. If strict filters give 0 rows, relaxes one filter
     * at a time (water → soil → duration) so the farmer still gets nearby
     * options, and reports which filters were relaxed. Season is never
     * relaxed — wrong-season advice is worse than none.
     *
     * @return array{0: array, 1: array} [rows, relaxedFilterNames]
     */
    private function matchVarieties(int $cropId, string $season, string $soil, string $water, string $maxDuration): array
    {
        $attempts = [
            ['season' => $season, 'soil' => $soil, 'water' => $water, 'dur' => $maxDuration],
            ['season' => $season, 'soil' => $soil, 'water' => '',     'dur' => $maxDuration],
            ['season' => $season, 'soil' => '',    'water' => '',     'dur' => $maxDuration],
            ['season' => $season, 'soil' => '',    'water' => '',     'dur' => ''],
        ];

        $db = Database::getConnection();
        foreach ($attempts as $i => $f) {
            $sql = 'SELECT variety_id, variety_name_tamil, variety_name_english, company, category,
                           duration, yield, season, soil_type, water_requirement, tnau_reference
                    FROM crop_varieties WHERE crop_id = :cid AND status = 1';
            $args = ['cid' => $cropId];

            if ($f['season'] !== '') {
                $sql .= ' AND season LIKE :season';
                $args['season'] = '%' . $f['season'] . '%';
            }
            if ($f['soil'] !== '') {
                $sql .= ' AND soil_type LIKE :soil';
                $args['soil'] = '%' . $f['soil'] . '%';
            }
            if ($f['water'] !== '') {
                $sql .= ' AND water_requirement = :water';
                $args['water'] = $f['water'];
            }
            if ($f['dur'] !== '') {
                // duration stored as "110" or "130-135" — compare leading number.
                // NOTE: must use single-quoted '-' — Aiven MySQL runs with
                // ANSI_QUOTES in sql_mode, where double-quoted "-" is parsed
                // as a column identifier (caused "Unknown column '-'" error).
                $sql .= " AND CAST(SUBSTRING_INDEX(duration, '-', 1) AS UNSIGNED) <= :dur";
                $args['dur'] = (int) $f['dur'];
            }

            $stmt = $db->prepare($sql . ' ORDER BY variety_id');
            $stmt->execute($args);
            $rows = $stmt->fetchAll();

            if (count($rows) > 0) {
                $relaxed = [];
                if ($i >= 1 && $water !== '') { $relaxed[] = 'தண்ணீர்'; }
                if ($i >= 2 && $soil !== '') { $relaxed[] = 'மண் வகை'; }
                if ($i >= 3 && $maxDuration !== '') { $relaxed[] = 'காலம்'; }
                return [$rows, $relaxed];
            }
        }

        return [[], []];
    }

    private function aiRank(array $rows, array $inputs, array $relaxed): string
    {
        $apiKey = $_ENV['AI_API_KEY'] ?? '';
        $baseUrl = rtrim($_ENV['AI_BASE_URL'] ?? self::DEFAULT_BASE_URL, '/');

        // AI illa na DB match mattum return — app varieties list kaatum
        if ($apiKey === '') {
            return 'தரவுத்தளத்தில் பொருந்திய ரகங்கள் கீழே உள்ளன. (AI பகுப்பாய்வு சேவை அமைக்கப்படவில்லை)';
        }

        $farmerProfile = [
            'மாவட்டம்' => $inputs['district'] ?? '',
            'வட்டம்' => $inputs['taluk'] ?? '',
            'பருவம்' => $inputs['season'] ?? '',
            'மாதம்' => $inputs['month'] ?? '',
            'மண் வகை' => $inputs['soil_type'] ?? '',
            'தண்ணீர் வசதி' => $inputs['water'] ?? '',
            'விரும்பும் காலம்' => $inputs['duration_preference'] ?? '',
            'நோக்கம்' => $inputs['purpose'] ?? '',
            'இயற்கை விவசாயம்' => !empty($inputs['organic']) ? 'ஆம்' : 'இல்லை',
        ];

        $user = "விவசாயி விவரம்:\n" . json_encode(array_filter($farmerProfile), JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT)
            . "\n\nதரவுத்தளத்தில் பொருந்திய ரகங்கள் (இவற்றை மட்டும் பயன்படுத்தவும்):\n"
            . json_encode($rows, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);

        if (count($relaxed) > 0) {
            $user .= "\n\nகுறிப்பு: " . implode(', ', $relaxed)
                . " வடிகட்டிக்கு நேரடி பொருத்தம் கிடைக்காததால் அவை தளர்த்தப்பட்டுள்ளன. இதை பதிலில் விவசாயிக்கு தெரிவிக்கவும்.";
        }

        $messages = [
            ['role' => 'system', 'content' => self::ADVISOR_SYSTEM_PROMPT],
            ['role' => 'user', 'content' => $user],
        ];

        $reply = $this->callChatCompletions($baseUrl, $apiKey, $messages);
        return $reply ?? 'AI பகுப்பாய்வு தற்போது கிடைக்கவில்லை. கீழே உள்ள ரகங்களை நேரடியாக ஒப்பிட்டு பார்க்கவும்.';
    }

    // Same call pattern as AiChatController (NVIDIA Build, OpenAI-compatible)
    private function callChatCompletions(string $baseUrl, string $apiKey, array $messages): ?string
    {
        $model = $_ENV['AI_MODEL'] ?? 'sarvamai/sarvam-m';
        $body = json_encode([
            'model' => $model,
            'messages' => $messages,
            'max_tokens' => 1500,
            'temperature' => 0.3,
        ], JSON_UNESCAPED_UNICODE);

        for ($attempt = 1; $attempt <= self::MAX_ATTEMPTS; $attempt++) {
            $reply = $this->requestOnce($baseUrl . '/chat/completions', $apiKey, $body);
            if ($reply !== null) {
                return $reply;
            }
            if ($attempt < self::MAX_ATTEMPTS) {
                usleep(800000);
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
            return null;
        }
        $data = json_decode($response, true);
        $content = $data['choices'][0]['message']['content'] ?? null;

        return is_string($content) && $content !== '' ? trim($content) : null;
    }
}
