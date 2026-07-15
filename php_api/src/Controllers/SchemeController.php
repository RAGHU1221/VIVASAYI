<?php

namespace App\Controllers;

use App\Config\Database;
use App\Middleware\AuthMiddleware;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;

class SchemeController
{
    private function ensureTable(): void
    {
        $db = Database::getConnection();
        $db->exec(
            'CREATE TABLE IF NOT EXISTS schemes (
              id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
              title VARCHAR(200) NOT NULL,
              category VARCHAR(50) NOT NULL,
              description TEXT NOT NULL,
              eligibility TEXT DEFAULT NULL,
              benefits TEXT DEFAULT NULL,
              how_to_apply TEXT DEFAULT NULL,
              link VARCHAR(300) DEFAULT NULL,
              is_active TINYINT(1) NOT NULL DEFAULT 1,
              created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
              updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
            ) ENGINE=InnoDB'
        );

        $count = (int) $db->query('SELECT COUNT(*) AS c FROM schemes')->fetch()['c'];
        if ($count === 0) {
            $this->seed($db);
        }
    }

    private function seed(\PDO $db): void
    {
        $schemes = [
            [
                'title' => 'PM-KISAN (பிரதமர் கிசான் சம்மான் நிதி)',
                'category' => 'மத்திய அரசு',
                'description' => 'சிறு மற்றும் குறு விவசாயிகளுக்கு ஆண்டுக்கு ₹6,000 நேரடி வங்கி கணக்கு பரிமாற்றம் (3 தவணைகளாக ₹2,000 வீதம்).',
                'eligibility' => 'விவசாய நிலம் வைத்திருக்கும் விவசாய குடும்பங்கள். அரசு ஊழியர்கள், வருமான வரி செலுத்துவோர் தகுதியற்றவர்கள்.',
                'benefits' => 'ஆண்டுக்கு ₹6,000 — 4 மாதங்களுக்கு ஒருமுறை ₹2,000 நேரடியாக வங்கி கணக்கில்.',
                'how_to_apply' => 'pmkisan.gov.in இணையதளத்தில் அல்லது அருகிலுள்ள CSC மையத்தில் ஆதார், வங்கி கணக்கு, நில ஆவணங்களுடன் பதிவு செய்யவும்.',
                'link' => 'https://pmkisan.gov.in',
            ],
            [
                'title' => 'பிரதமர் பயிர் காப்பீட்டு திட்டம் (PMFBY)',
                'category' => 'காப்பீடு',
                'description' => 'இயற்கை பேரிடர், பூச்சி தாக்குதல், நோய்களால் பயிர் சேதம் ஏற்பட்டால் காப்பீட்டு இழப்பீடு.',
                'eligibility' => 'அனைத்து விவசாயிகளும் — நில உரிமையாளர்கள் மற்றும் குத்தகை விவசாயிகள்.',
                'benefits' => 'குறைந்த பிரீமியத்தில் (உணவு பயிர்கள் 2%, பருவகால பயிர்கள் 1.5%) முழு காப்பீட்டு தொகை.',
                'how_to_apply' => 'pmfby.gov.in அல்லது அருகிலுள்ள வங்கி / CSC மையம் / வேளாண்மை அலுவலகம் மூலம் விண்ணப்பிக்கவும்.',
                'link' => 'https://pmfby.gov.in',
            ],
            [
                'title' => 'கிசான் கடன் அட்டை (KCC)',
                'category' => 'கடன்',
                'description' => 'விவசாய செலவுகளுக்கு குறைந்த வட்டியில் (4% வரை) கடன் வசதி.',
                'eligibility' => 'விவசாயிகள், கால்நடை வளர்ப்போர், மீனவர்கள்.',
                'benefits' => '₹3 லட்சம் வரை 7% வட்டி; சரியான நேரத்தில் திருப்பிச் செலுத்தினால் 3% வட்டி மானியம் (நிகர 4%).',
                'how_to_apply' => 'அருகிலுள்ள வங்கி கிளையில் நில ஆவணங்கள், ஆதார், புகைப்படத்துடன் விண்ணப்பிக்கவும்.',
                'link' => 'https://www.myscheme.gov.in/schemes/kcc',
            ],
            [
                'title' => 'உழவர் பாதுகாப்பு திட்டம்',
                'category' => 'மாநில அரசு',
                'description' => 'தமிழ்நாடு முதலமைச்சரின் உழவர் பாதுகாப்புத் திட்டம் — விவசாயிகளுக்கு விபத்து காப்பீடு மற்றும் நல உதவிகள்.',
                'eligibility' => 'தமிழ்நாட்டில் உள்ள விவசாயிகள் மற்றும் விவசாய தொழிலாளர்கள்.',
                'benefits' => 'விபத்து மரணம்/ஊனத்திற்கு இழப்பீடு, மகப்பேறு உதவி, இயற்கை மரண உதவி.',
                'how_to_apply' => 'அருகிலுள்ள வேளாண்மை அலுவலகம் அல்லது வருவாய் அலுவலகத்தில் விண்ணப்பிக்கவும்.',
                'link' => 'https://www.tn.gov.in',
            ],
            [
                'title' => 'இலவச மின்சாரம் (விவசாய பம்புசெட்)',
                'category' => 'மாநில அரசு',
                'description' => 'தமிழ்நாடு அரசு விவசாய பம்புசெட்டுகளுக்கு இலவச மின்சாரம் வழங்குகிறது.',
                'eligibility' => 'விவசாய மின் இணைப்பு உள்ள தமிழ்நாடு விவசாயிகள்.',
                'benefits' => 'விவசாய பம்புசெட் மின் கட்டணம் முழுவதும் அரசு ஏற்கும்.',
                'how_to_apply' => 'TNEB / TANGEDCO அலுவலகத்தில் விவசாய மின் இணைப்புக்கு விண்ணப்பிக்கவும்.',
                'link' => 'https://www.tangedco.org',
            ],
            [
                'title' => 'மண் வள அட்டை (Soil Health Card)',
                'category' => 'மத்திய அரசு',
                'description' => 'உங்கள் நிலத்தின் மண் பரிசோதனை செய்து உர பரிந்துரைகளுடன் இலவச அட்டை.',
                'eligibility' => 'அனைத்து விவசாயிகளும்.',
                'benefits' => 'மண்ணின் ஊட்டச்சத்து நிலை அறிக்கை + பயிர்வாரியாக உர பரிந்துரை — உர செலவு குறையும்.',
                'how_to_apply' => 'அருகிலுள்ள வேளாண்மை உதவி இயக்குநர் அலுவலகத்தில் மண் மாதிரி கொடுத்து பதிவு செய்யவும்.',
                'link' => 'https://soilhealth.dac.gov.in',
            ],
            [
                'title' => 'PM-KUSUM (சூரிய பம்பு மானியம்)',
                'category' => 'மானியம்',
                'description' => 'சூரிய சக்தி விவசாய பம்புகள் நிறுவ மத்திய + மாநில அரசு மானியம்.',
                'eligibility' => 'மின் இணைப்பு இல்லாத / டீசல் பம்பு பயன்படுத்தும் விவசாயிகள்.',
                'benefits' => 'சூரிய பம்பு விலையில் 60% வரை மானியம்; 30% வங்கி கடன் வசதி.',
                'how_to_apply' => 'TEDA / வேளாண்மை பொறியியல் துறை மூலம் விண்ணப்பிக்கவும்.',
                'link' => 'https://pmkusum.mnre.gov.in',
            ],
        ];

        $stmt = $db->prepare(
            'INSERT INTO schemes (title, category, description, eligibility, benefits, how_to_apply, link)
             VALUES (:title, :category, :description, :eligibility, :benefits, :how_to_apply, :link)'
        );
        foreach ($schemes as $s) {
            $stmt->execute($s);
        }
    }

    public function index(Request $request): JsonResponse
    {
        $userId = AuthMiddleware::getUserId($request);
        if ($userId === null) {
            return new JsonResponse(['error' => 'Unauthorized'], 401);
        }

        $this->ensureTable();
        $stmt = Database::getConnection()->query(
            'SELECT id, title, category, description, eligibility, benefits, how_to_apply, link
             FROM schemes WHERE is_active = 1 ORDER BY id ASC'
        );

        return new JsonResponse(['schemes' => $stmt->fetchAll()]);
    }

    public function create(Request $request): JsonResponse
    {
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
            'INSERT INTO schemes (title, category, description, eligibility, benefits, how_to_apply, link)
             VALUES (:title, :category, :description, :eligibility, :benefits, :how_to_apply, :link)'
        );
        $stmt->execute($this->bind($payload));

        return new JsonResponse(
            ['message' => 'Created', 'id' => (int) Database::getConnection()->lastInsertId()],
            201
        );
    }

    public function update(Request $request, array $vars): JsonResponse
    {
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
        $params['is_active'] = isset($payload['is_active']) ? (int) (bool) $payload['is_active'] : 1;

        $stmt = Database::getConnection()->prepare(
            'UPDATE schemes
             SET title = :title, category = :category, description = :description,
                 eligibility = :eligibility, benefits = :benefits,
                 how_to_apply = :how_to_apply, link = :link, is_active = :is_active
             WHERE id = :id'
        );
        $stmt->execute($params);

        if ($stmt->rowCount() === 0) {
            return new JsonResponse(['error' => 'Scheme not found'], 404);
        }

        return new JsonResponse(['message' => 'Updated']);
    }

    public function delete(Request $request, array $vars): JsonResponse
    {
        $this->ensureTable();
        $stmt = Database::getConnection()->prepare('DELETE FROM schemes WHERE id = :id');
        $stmt->execute(['id' => (int) $vars['id']]);

        if ($stmt->rowCount() === 0) {
            return new JsonResponse(['error' => 'Scheme not found'], 404);
        }

        return new JsonResponse(['message' => 'Deleted']);
    }

    private function validate(array $payload): ?string
    {
        $title = trim($payload['title'] ?? '');
        if ($title === '' || mb_strlen($title) > 200) {
            return 'Title is required (max 200 chars)';
        }

        $category = trim($payload['category'] ?? '');
        if ($category === '' || mb_strlen($category) > 50) {
            return 'Category is required (max 50 chars)';
        }

        $description = trim($payload['description'] ?? '');
        if ($description === '') {
            return 'Description is required';
        }

        return null;
    }

    private function bind(array $payload): array
    {
        return [
            'title' => trim($payload['title']),
            'category' => trim($payload['category']),
            'description' => trim($payload['description']),
            'eligibility' => isset($payload['eligibility']) ? trim($payload['eligibility']) : null,
            'benefits' => isset($payload['benefits']) ? trim($payload['benefits']) : null,
            'how_to_apply' => isset($payload['how_to_apply']) ? trim($payload['how_to_apply']) : null,
            'link' => isset($payload['link']) ? mb_substr(trim($payload['link']), 0, 300) : null,
        ];
    }
}
