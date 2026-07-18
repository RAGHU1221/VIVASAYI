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
        $this->seedAedSchemesIfMissing($db);
        $this->seedInsuranceAndAdvisoryIfMissing($db);
    }

    /**
     * District-specific PMFBY (Pradhan Mantri Fasal Bima Yojana) horticulture
     * crop insurance rates for Kharif 2026-27, plus two seasonal crop-care
     * advisories. Source: official Tamil Nadu Department of Horticulture
     * circulars (Dharmapuri and Thiruvannamalai districts) shared by the
     * user — premium/sum-insured figures and cutoff dates are reproduced
     * exactly; advisory steps are paraphrased/condensed into the app's own
     * words rather than copied verbatim.
     *
     * NOTE: these premium rates and cutoff dates are DISTRICT-SPECIFIC and
     * time-bound (Kharif 2026-27 season only) — they will need refreshing
     * each season and do not apply state-wide. Flagged clearly in each
     * entry's title/description so farmers from other districts don't
     * mistake them for their own rates.
     */
    private function seedInsuranceAndAdvisoryIfMissing(\PDO $db): void
    {
        $schemes = [
            // ---- Dharmapuri district PMFBY horticulture crops, Kharif 2026-27 ----
            [
                'title' => 'PMFBY பயிர் காப்பீடு — தக்காளி (தருமபுரி மாவட்டம், காரிப் 2026-27)',
                'category' => 'காப்பீடு',
                'description' => 'தருமபுரி மாவட்டத்தில் 2026-27 காரிப் பருவத்தில் அறிவிக்கப்பட்ட வருவாய் கிராமங்களில் தக்காளி சாகுபடி செய்யும் விவசாயிகளுக்கான பிரதமர் பயிர் காப்பீட்டுத் திட்டம்.',
                'eligibility' => 'தருமபுரி மாவட்டம் அறிவிக்கப்பட்ட கிராமங்களில் தக்காளி சாகுபடி செய்யும் விவசாயிகள் (நில உரிமையாளர்/குத்தகைதாரர்).',
                'benefits' => 'ஏக்கருக்கு பிரீமியம் ரூ.1,771/-. காப்பீடு செய்ய கடைசி நாள்: 31.08.2026.',
                'how_to_apply' => 'முன்மொழிவுப் படிவம், பதிவுப் படிவம், பயிர் சாகுபடி அடங்கல் அறிக்கை, ஆதார் அட்டை நகல், வங்கிக் கணக்குப் புத்தகத்தின் முதல் பக்க நகல், சிட்டா ஆகியவற்றுடன் தேசியமயமாக்கப்பட்ட வங்கிகள் / தொடக்க வேளாண்மை கூட்டுறவு கடன் சங்கங்கள் / CSC மையங்களில் விண்ணப்பிக்கவும்.',
                'link' => null,
            ],
            [
                'title' => 'PMFBY பயிர் காப்பீடு — மஞ்சள் (தருமபுரி மாவட்டம், காரிப் 2026-27)',
                'category' => 'காப்பீடு',
                'description' => 'தருமபுரி மாவட்டத்தில் 2026-27 காரிப் பருவத்தில் மஞ்சள் சாகுபடி செய்யும் விவசாயிகளுக்கான பிரதமர் பயிர் காப்பீட்டுத் திட்டம்.',
                'eligibility' => 'தருமபுரி மாவட்டம் அறிவிக்கப்பட்ட கிராமங்களில் மஞ்சள் சாகுபடி செய்யும் விவசாயிகள்.',
                'benefits' => 'ஏக்கருக்கு பிரீமியம் ரூ.4,200/-. காப்பீடு செய்ய கடைசி நாள்: 15.09.2026.',
                'how_to_apply' => 'முன்மொழிவுப் படிவம், பதிவுப் படிவம், பயிர் சாகுபடி அடங்கல் அறிக்கை, ஆதார் அட்டை நகல், வங்கிக் கணக்குப் புத்தகத்தின் முதல் பக்க நகல், சிட்டா ஆகியவற்றுடன் தேசியமயமாக்கப்பட்ட வங்கிகள் / தொடக்க வேளாண்மை கூட்டுறவு கடன் சங்கங்கள் / CSC மையங்களில் விண்ணப்பிக்கவும்.',
                'link' => null,
            ],
            [
                'title' => 'PMFBY பயிர் காப்பீடு — வாழை (தருமபுரி மாவட்டம், காரிப் 2026-27)',
                'category' => 'காப்பீடு',
                'description' => 'தருமபுரி மாவட்டத்தில் 2026-27 காரிப் பருவத்தில் வாழை சாகுபடி செய்யும் விவசாயிகளுக்கான பிரதமர் பயிர் காப்பீட்டுத் திட்டம்.',
                'eligibility' => 'தருமபுரி மாவட்டம் அறிவிக்கப்பட்ட கிராமங்களில் வாழை சாகுபடி செய்யும் விவசாயிகள்.',
                'benefits' => 'ஏக்கருக்கு பிரீமியம் ரூ.1,935/-. காப்பீடு செய்ய கடைசி நாள்: 15.09.2026.',
                'how_to_apply' => 'முன்மொழிவுப் படிவம், பதிவுப் படிவம், பயிர் சாகுபடி அடங்கல் அறிக்கை, ஆதார் அட்டை நகல், வங்கிக் கணக்குப் புத்தகத்தின் முதல் பக்க நகல், சிட்டா ஆகியவற்றுடன் தேசியமயமாக்கப்பட்ட வங்கிகள் / தொடக்க வேளாண்மை கூட்டுறவு கடன் சங்கங்கள் / CSC மையங்களில் விண்ணப்பிக்கவும்.',
                'link' => null,
            ],
            [
                'title' => 'PMFBY பயிர் காப்பீடு — வெங்காயம் (தருமபுரி மாவட்டம், காரிப் 2026-27)',
                'category' => 'காப்பீடு',
                'description' => 'தருமபுரி மாவட்டத்தில் 2026-27 காரிப் பருவத்தில் வெங்காயம் சாகுபடி செய்யும் விவசாயிகளுக்கான பிரதமர் பயிர் காப்பீட்டுத் திட்டம்.',
                'eligibility' => 'தருமபுரி மாவட்டம் அறிவிக்கப்பட்ட கிராமங்களில் வெங்காயம் சாகுபடி செய்யும் விவசாயிகள்.',
                'benefits' => 'ஏக்கருக்கு பிரீமியம் ரூ.2,122/-. காப்பீடு செய்ய கடைசி நாள்: 31.08.2026.',
                'how_to_apply' => 'முன்மொழிவுப் படிவம், பதிவுப் படிவம், பயிர் சாகுபடி அடங்கல் அறிக்கை, ஆதார் அட்டை நகல், வங்கிக் கணக்குப் புத்தகத்தின் முதல் பக்க நகல், சிட்டா ஆகியவற்றுடன் தேசியமயமாக்கப்பட்ட வங்கிகள் / தொடக்க வேளாண்மை கூட்டுறவு கடன் சங்கங்கள் / CSC மையங்களில் விண்ணப்பிக்கவும்.',
                'link' => null,
            ],
            [
                'title' => 'PMFBY பயிர் காப்பீடு — கத்திரி (தருமபுரி மாவட்டம், காரிப் 2026-27)',
                'category' => 'காப்பீடு',
                'description' => 'தருமபுரி மாவட்டத்தில் 2026-27 காரிப் பருவத்தில் கத்திரி சாகுபடி செய்யும் விவசாயிகளுக்கான பிரதமர் பயிர் காப்பீட்டுத் திட்டம்.',
                'eligibility' => 'தருமபுரி மாவட்டம் அறிவிக்கப்பட்ட கிராமங்களில் கத்திரி சாகுபடி செய்யும் விவசாயிகள்.',
                'benefits' => 'ஏக்கருக்கு பிரீமியம் ரூ.749/-. காப்பீடு செய்ய கடைசி நாள்: 31.08.2026.',
                'how_to_apply' => 'முன்மொழிவுப் படிவம், பதிவுப் படிவம், பயிர் சாகுபடி அடங்கல் அறிக்கை, ஆதார் அட்டை நகல், வங்கிக் கணக்குப் புத்தகத்தின் முதல் பக்க நகல், சிட்டா ஆகியவற்றுடன் தேசியமயமாக்கப்பட்ட வங்கிகள் / தொடக்க வேளாண்மை கூட்டுறவு கடன் சங்கங்கள் / CSC மையங்களில் விண்ணப்பிக்கவும்.',
                'link' => null,
            ],
            [
                'title' => 'PMFBY பயிர் காப்பீடு — வெண்டைக்காய் (தருமபுரி மாவட்டம், காரிப் 2026-27)',
                'category' => 'காப்பீடு',
                'description' => 'தருமபுரி மாவட்டத்தில் 2026-27 காரிப் பருவத்தில் வெண்டைக்காய் சாகுபடி செய்யும் விவசாயிகளுக்கான பிரதமர் பயிர் காப்பீட்டுத் திட்டம்.',
                'eligibility' => 'தருமபுரி மாவட்டம் அறிவிக்கப்பட்ட கிராமங்களில் வெண்டைக்காய் சாகுபடி செய்யும் விவசாயிகள்.',
                'benefits' => 'ஏக்கருக்கு பிரீமியம் ரூ.467/-. காப்பீடு செய்ய கடைசி நாள்: 31.08.2026.',
                'how_to_apply' => 'முன்மொழிவுப் படிவம், பதிவுப் படிவம், பயிர் சாகுபடி அடங்கல் அறிக்கை, ஆதார் அட்டை நகல், வங்கிக் கணக்குப் புத்தகத்தின் முதல் பக்க நகல், சிட்டா ஆகியவற்றுடன் தேசியமயமாக்கப்பட்ட வங்கிகள் / தொடக்க வேளாண்மை கூட்டுறவு கடன் சங்கங்கள் / CSC மையங்களில் விண்ணப்பிக்கவும்.',
                'link' => null,
            ],
            // ---- Thiruvannamalai district PMFBY, Kharif 2026-27 ----
            [
                'title' => 'PMFBY பயிர் காப்பீடு — வாழை (திருவண்ணாமலை மாவட்டம், 2026-27)',
                'category' => 'காப்பீடு',
                'description' => 'திருவண்ணாமலை மாவட்டத்தில் வாழை சாகுபடி செய்யும் விவசாயிகளுக்கு இயற்கை சீற்றங்கள் (கனமழை, புயல், வெள்ளம், வறட்சி, பலத்த காற்று), பூச்சி/நோய் தாக்குதலால் ஏற்படும் மகசூல் இழப்புக்கு நிதி பாதுகாப்பு அளிக்கும் PMFBY திட்டம். சேதம் ஏற்பட்டால் 72 மணி நேரத்திற்குள் அறிவிக்க வேண்டும்.',
                'eligibility' => 'திருவண்ணாமலை மாவட்டத்தில் வாழை சாகுபடி செய்யும் நில உரிமையாளர் மற்றும் தகுதி விதிகளுக்கு உட்பட்ட குத்தகை விவசாயிகள்.',
                'benefits' => 'காப்பீட்டுத் தொகை: ஏக்கருக்கு ரூ.61,947/-. பிரீமியம்: ஏக்கருக்கு ரூ.2,471.71/- (காப்பீட்டுத் தொகையில் 3.9% மட்டுமே விவசாயி செலுத்த வேண்டும்; மீதி மத்திய+மாநில அரசு மானியம்). பதிவு செய்யும் நாள்: 25.06.2026. கடைசி நாள்: 15.09.2026.',
                'how_to_apply' => 'ஆதார் அட்டை, சிட்டா/அடங்கல், நில உரிமை/குத்தகை ஆவணம், வங்கிக் கணக்குப் புத்தகம், பயிர் விவரங்கள், கைபேசி எண், பாஸ்போர்ட் அளவு புகைப்படத்துடன் தோட்டக்கலை உதவி இயக்குநர் அலுவலகம் / CSC / அங்கீகரிக்கப்பட்ட வங்கிகளில் விண்ணப்பிக்கவும்.',
                'link' => null,
            ],
            [
                'title' => 'PMFBY பயிர் காப்பீடு — மரவள்ளி/Tapioca (திருவண்ணாமலை மாவட்டம், 2026-27)',
                'category' => 'காப்பீடு',
                'description' => 'திருவண்ணாமலை மாவட்டத்தில் மரவள்ளி சாகுபடி செய்யும் விவசாயிகளுக்கு இயற்கை சீற்றங்கள் மற்றும் பூச்சி/நோய் தாக்குதலால் ஏற்படும் மகசூல் இழப்புக்கு நிதி பாதுகாப்பு அளிக்கும் PMFBY திட்டம். சேதம் ஏற்பட்டால் 72 மணி நேரத்திற்குள் அறிவிக்க வேண்டும்.',
                'eligibility' => 'திருவண்ணாமலை மாவட்டத்தில் மரவள்ளி சாகுபடி செய்யும் நில உரிமையாளர் மற்றும் தகுதி விதிகளுக்கு உட்பட்ட குத்தகை விவசாயிகள்.',
                'benefits' => 'காப்பீட்டுத் தொகை: ஏக்கருக்கு ரூ.23,316/-. பிரீமியம்: ஏக்கருக்கு ரூ.1,165.84/- (காப்பீட்டுத் தொகையில் 5% மட்டுமே விவசாயி செலுத்த வேண்டும்). பதிவு செய்யும் நாள்: 25.06.2026. கடைசி நாள்: 15.09.2026.',
                'how_to_apply' => 'ஆதார் அட்டை, சிட்டா/அடங்கல், நில உரிமை/குத்தகை ஆவணம், வங்கிக் கணக்குப் புத்தகம், பயிர் விவரங்கள், கைபேசி எண், பாஸ்போர்ட் அளவு புகைப்படத்துடன் தோட்டக்கலை உதவி இயக்குநர் அலுவலகம் / CSC / அங்கீகரிக்கப்பட்ட வங்கிகளில் விண்ணப்பிக்கவும்.',
                'link' => null,
            ],
            // ---- Seasonal crop-care advisories (not financial schemes, but
            // shown in the same list since there's no separate advisory
            // feature yet — condensed/paraphrased from department circulars) ----
            [
                'title' => 'தென்னை வெள்ளை ஈ ஒருங்கிணைந்த மேலாண்மை',
                'category' => 'பயிர் பராமரிப்பு ஆலோசனை',
                'description' => 'தமிழ்நாடு வேளாண்மைப் பல்கலைக்கழகம் பயிர் பாதுகாப்பு இயக்ககம் (கோயம்புத்தூர்) + தோட்டக்கலை துறை பரிந்துரைக்கும் தென்னையில் வெள்ளை ஈ கட்டுப்பாட்டிற்கான ஒருங்கிணைந்த மேலாண்மை வழிமுறைகள்.',
                'eligibility' => 'தென்னை சாகுபடி செய்யும் அனைத்து விவசாயிகளும்.',
                'benefits' => 'படிநிலைகள்: (1) அடிப்பரப்பை நோக்கி தண்ணீர் பீய்ச்சி வெள்ளை ஈக்களை அகற்றவும். (2) மஞ்சள் நிற பாலித்தீன் தாள்களில் விளக்கெண்ணெய் தடவி மரத்தில் 6 அடி உயரத்தில் தொங்கவிடவும் — ஏக்கருக்கு 20 வீதம். (3) அபெர்டோக்கிரசா நன்மை பூச்சியின் முட்டைகளை ஏக்கருக்கு 400 வீதம் இணைக்கவும். (4) என்காசியா ஓட்டுண்ணிகளை ஏக்கருக்கு 10 மரத்திற்கு ஒரு இலைத்துண்டு வீதம் இணைக்கவும். (5) தென்னை மரங்களுக்கிடையே வாழை/கல்வாழை/சீத்தா ஏக்கருக்கு 20-25 எண்ணிக்கையில் ஊடுபயிராக நடவும். (6) 1 லிட்டர் தண்ணீருக்கு வேப்பெண்ணெய் 5மி.லி + ஓட்டும் திரவம் 1மி.லி கலந்து அடி தண்டில் தெளிக்கவும். (7) கரும்பூசணத்திற்கு 25கிராம் மைதாமாவுப் பசையை 1லிட்டர் தண்ணீரில் கலந்து தெளிக்கவும். (8) இயற்கை எதிரிகளை பாதுகாக்க இரசாயன பூச்சிக்கொல்லிகளை முற்றிலும் தவிர்க்கவும்.',
                'how_to_apply' => 'அருகிலுள்ள தோட்டக்கலை உதவி இயக்குநர் அலுவலகம் அல்லது TNAU பயிர் பாதுகாப்பு இயக்ககம், கோயம்புத்தூரை தொடர்பு கொள்ளவும்.',
                'link' => null,
            ],
            [
                'title' => 'வடகிழக்கு பருவமழை — தோட்டக்கலை பயிர்கள் முன்னெச்சரிக்கை',
                'category' => 'பயிர் பராமரிப்பு ஆலோசனை',
                'description' => 'வடகிழக்கு பருவமழை காலத்தில் தோட்டக்கலை பயிர்களை கனமழை, புயல், வெள்ளத்தால் ஏற்படும் சேதத்திலிருந்து பாதுகாக்க தமிழ்நாடு தோட்டக்கலை துறையின் ஆயத்த நடவடிக்கைகள்.',
                'eligibility' => 'அனைத்து தோட்டக்கலை பயிர் விவசாயிகளும் (தேங்காய், மா, வாழை, திராட்சை, மிளகு, காய்கறிகள், பூக்கள், பசுமைக்குடில்/நிழல்வலைக்குடில் உட்பட).',
                'benefits' => 'பொது முன்னெச்சரிக்கைகள்: சாகுபடி பரப்பை அடங்கல்/இ-அடங்கலில் புதுப்பிக்கவும்; நீர்ப்பாசனம்/உரமிடுதலை தற்காலிகமாக நிறுத்தவும்; மரங்களை மண் அணைத்து/ஊன்றுகோல் கட்டி பாதுகாக்கவும்; அறுவடைக்கு தயாராக உள்ள பயிர்களை உடனே அறுவடை செய்யவும்; வடிகால் வசதி செய்யவும். எல்லா தோட்டக்கலை பயிர்களையும் உடனடியாக PMFBY-ல் காப்பீடு செய்யவும். சேதம் ஏற்பட்டால் 72 மணி நேரத்திற்குள் தோட்டக்கலை அலுவலகம்/காப்பீட்டு நிறுவனத்திற்கு தகவல் தெரிவிக்கவும்.',
                'how_to_apply' => 'விரிவான பயிர்வாரி (தேங்காய், மா, வாழை, திராட்சை, மிளகு, காய்கறிகள் etc.) நடவடிக்கைகளுக்கு அருகிலுள்ள தோட்டக்கலை உதவி இயக்குநர் அலுவலகத்தை தொடர்பு கொள்ளவும்.',
                'link' => null,
            ],
        ];

        $exists = $db->prepare('SELECT COUNT(*) FROM schemes WHERE title = :title');
        $insert = $db->prepare(
            'INSERT INTO schemes (title, category, description, eligibility, benefits, how_to_apply, link)
             VALUES (:title, :category, :description, :eligibility, :benefits, :how_to_apply, :link)'
        );

        foreach ($schemes as $s) {
            $exists->execute(['title' => $s['title']]);
            if ((int) $exists->fetchColumn() > 0) {
                continue; // already seeded — skip
            }
            $insert->execute($s);
        }
    }

    /**
     * Tamil Nadu Agricultural Engineering Department (aed.tn.gov.in) machinery
     * / irrigation subsidy schemes — added as a separate idempotent step
     * (checked by title) so it safely runs on databases that were already
     * seeded before this update, including the live production DB. Source:
     * aed.tn.gov.in scheme pages (Sub Mission on Agricultural Mechanisation,
     * Individual/Cluster based subsidy schemes) — subsidy % and machinery
     * names taken directly from the department's published scheme text, not
     * invented.
     */
    private function seedAedSchemesIfMissing(\PDO $db): void
    {
        $schemes = [
            [
                'title' => 'தேசிய வேளாண் இயந்திரமயமாக்கல் துணைத் திட்டம் (SMAM)',
                'category' => 'வேளாண் பொறியியல் துறை',
                'description' => 'விவசாயிகளுக்கு தனிநபர் அடிப்படையில் வேளாண் இயந்திரங்கள்/கருவிகள் (பவர் டில்லர், பவர் வீடர், சாஃப் கட்டர், பிரஷ் கட்டர், நெல் நடவு இயந்திரம், டிராக்டர் ரோட்டாவேட்டர், கல்டிவேட்டர், டிஸ்க் ப்ளவ், லேசர் லேண்ட் லெவலர், விதை-உர சொருகி, தென்னை மட்டை துண்டாக்கி, பல பயிர் தாள்படி இயந்திரம் போன்றவை) வாங்க மானிய உதவி.',
                'eligibility' => 'அனைத்து விவசாயிகளும் தனிநபர் இயந்திர மானியத்திற்கு விண்ணப்பிக்கலாம்.',
                'benefits' => 'சிறு/குறு விவசாயிகளில் SC/ST பிரிவினருக்கு கூடுதல் 20% மானியம்; பொது பிரிவு சிறு/குறு விவசாயிகளுக்கு பவர் வீடர் மற்றும் நெல் நடவு இயந்திரத்திற்கு கூடுதல் 10% மானியம்.',
                'how_to_apply' => 'அருகிலுள்ள உதவி வேளாண்மைப் பொறியியலாளர் (AAE) அலுவலகம் அல்லது aed.tn.gov.in மூலம் விண்ணப்பிக்கவும்.',
                'link' => 'https://aed.tn.gov.in/en/schemes/agricultural-mechanisation/sub-mission-on-agricultural-mechanisation/',
            ],
            [
                'title' => 'கிராம அளவிலான வாடகை அடிப்படை மைய திட்டம் (VLCHC)',
                'category' => 'வேளாண் பொறியியல் துறை',
                'description' => 'பதிவு செய்யப்பட்ட விவசாயிகள் சங்கம், கூட்டுறவு சங்கங்கள், சுய உதவிக் குழுக்கள் (SHG), விவசாயிகள் உற்பத்தியாளர் நிறுவனங்கள் (FPO) மூலம் கிராம அளவில் இயந்திர வாடகை மையம் அமைக்க மானியம்.',
                'eligibility' => 'பதிவு செய்யப்பட்ட விவசாயிகள் சங்கங்கள், கூட்டுறவு சங்கங்கள், SHG, FPO — சென்னை தவிர்த்து அனைத்து மாவட்டங்களும்.',
                'benefits' => 'இயந்திரங்கள் மொத்த செலவில் 80% மானியம் (அதிகபட்சம் ரூ.8 லட்சம்).',
                'how_to_apply' => 'அருகிலுள்ள வேளாண்மைப் பொறியியல் துறை மாவட்ட அலுவலகத்தில் சங்கம்/FPO மூலம் விண்ணப்பிக்கவும்.',
                'link' => 'https://aed.tn.gov.in/en/cluster-based-subsidy-schemes/',
            ],
            [
                'title' => 'தொகுதி அளவிலான வாடகை அடிப்படை மைய திட்டம் (BLCHC)',
                'category' => 'வேளாண் பொறியியல் துறை',
                'description' => 'கிராமப்புற தொழில் முனைவோர், கூட்டுறவு சங்கங்கள், SHG, FPO மூலம் தொகுதி (Block) அளவில் பெரிய இயந்திர வாடகை மையம் அமைக்க மானியம்.',
                'eligibility' => 'கிராமப்புற தொழில் முனைவோர், கூட்டுறவு சங்கங்கள், SHG, பதிவு செய்யப்பட்ட விவசாயிகள் சங்கங்கள், FPO.',
                'benefits' => 'இயந்திரங்கள் மொத்த செலவில் 40% மானியம் (ஒரு தொகுதிக்கு அதிகபட்சம் ரூ.10 லட்சம்).',
                'how_to_apply' => 'அருகிலுள்ள வேளாண்மைப் பொறியியல் துறை மாவட்ட அலுவலகத்தில் விண்ணப்பிக்கவும்.',
                'link' => 'https://aed.tn.gov.in/en/cluster-based-subsidy-schemes/',
            ],
            [
                'title' => 'கரும்பு அடிப்படையிலான வாடகை மைய திட்டம்',
                'category' => 'வேளாண் பொறியியல் துறை',
                'description' => 'கரும்பு பயிரிடும் பகுதிகளில் அறுவடை/பதப்படுத்தும் இயந்திரங்களுடன் கூடிய Custom Hiring Centre அமைக்க மானியம்.',
                'eligibility' => 'கரும்பு விவசாயிகள் குழுக்கள், கூட்டுறவு சங்கங்கள்.',
                'benefits' => 'மொத்த ரூ.150 லட்சம் திட்ட செலவில் 40% மானியம் (அதிகபட்சம் ரூ.60 லட்சம்).',
                'how_to_apply' => 'அருகிலுள்ள வேளாண்மைப் பொறியியல் துறை அலுவலகத்தில் விண்ணப்பிக்கவும்.',
                'link' => 'https://aed.tn.gov.in/en/individual-based-subsidy-schemes/',
            ],
            [
                'title' => 'மதிப்புக் கூட்டு இயந்திரங்கள் மானியம் (Value Addition Machinery)',
                'category' => 'வேளாண் பொறியியல் துறை',
                'description' => 'விவசாய விளைபொருட்களை மதிப்புக் கூட்டி பதப்படுத்த தனிநபர் விவசாயிகள் மற்றும் விவசாயிகள் குழுக்களுக்கு இயந்திர மானியம்.',
                'eligibility' => 'தனிநபர் விவசாயிகள் மற்றும் விவசாயிகள் குழுக்கள்.',
                'benefits' => 'இயந்திரச் செலவில் அதிகபட்சம் 40% மானியம் (அரசு நிர்ணயித்த வரம்புக்கு உட்பட்டு).',
                'how_to_apply' => 'அருகிலுள்ள வேளாண்மைப் பொறியியல் துறை அலுவலகத்தில் விண்ணப்பிக்கவும்.',
                'link' => 'https://aed.tn.gov.in/en/individual-based-subsidy-schemes/',
            ],
            [
                'title' => 'சூரிய சக்தி உலர்த்தி மானியம் (Solar Dryer)',
                'category' => 'வேளாண் பொறியியல் துறை',
                'description' => 'எண்ணெய் வித்துக்கள் (கொப்பரை, எள், நிலக்கடலை), பழங்கள் (வாழை, நெல்லி), மசாலா (கிராம்பு, இஞ்சி), மிளகாய், முருங்கை இலை போன்றவற்றை சுகாதாரமாக உலர்த்த 400-1,000 சதுர அடி பாலிகார்பனேட் கிரீன்ஹவுஸ் உலர்த்தி அமைக்க மானியம்.',
                'eligibility' => 'தனிநபர் விவசாயிகள் மற்றும் விவசாயிகள் குழுக்கள்.',
                'benefits' => 'உலர்த்தி மொத்த செலவில் 40% மானியம் — நேரடியாக விவசாயியின் வங்கிக் கணக்கில் பின்-இணைப்பு (back-ended) மானியமாக செலுத்தப்படும்.',
                'how_to_apply' => 'அருகிலுள்ள வேளாண்மைப் பொறியியல் துறை அலுவலகத்தில் விண்ணப்பிக்கவும்.',
                'link' => 'https://aed.tn.gov.in/',
            ],
            [
                'title' => 'ஆஃப்-கிரிட் சூரிய சக்தி நீர்ப்பாசன பம்பு மானியம்',
                'category' => 'வேளாண் பொறியியல் துறை',
                'description' => 'மின் இணைப்பு இல்லாத பகுதிகளில் நீர்ப்பாசனத்திற்காக சூரிய சக்தி இயங்கும் தனித்த (off-grid) பம்பு செட் அமைக்க மானியம்.',
                'eligibility' => 'மின் இணைப்பு இல்லாத / டீசல் பம்பு பயன்படுத்தும் விவசாயிகள்.',
                'benefits' => 'சூரிய பம்பு செட் செலவில் மானிய உதவி (சதவீதம் திட்ட வழிகாட்டுதலின்படி மாறுபடும்).',
                'how_to_apply' => 'அருகிலுள்ள வேளாண்மைப் பொறியியல் துறை அலுவலகத்தில் விண்ணப்பிக்கவும்.',
                'link' => 'https://aed.tn.gov.in/',
            ],
            [
                'title' => 'நுண் நீர்நிலை மேம்பாட்டு மற்றும் வயல்வரப்பு/குளம் திட்டம்',
                'category' => 'வேளாண் பொறியியல் துறை',
                'description' => 'மானாவாரி (dryland) தொகுதிகளில் தனிநபர் விவசாயிகளின் நிலத்தில் வயல் வரப்பு (field bund) மற்றும் பண்ணைக் குளம் (farm pond) அமைத்து மழைநீர் சேமிப்பை மேம்படுத்துதல்.',
                'eligibility' => 'மானாவாரி தொகுதிகளில் உள்ள தனிநபர் விவசாயிகள்.',
                'benefits' => 'சமூக நீர் ஆதார உருவாக்கத்திற்கு 100% மானியம்; தொடர்புடைய திட்ட வழிகாட்டுதலின்படி மற்ற மானியங்கள்.',
                'how_to_apply' => 'அருகிலுள்ள வேளாண்மைப் பொறியியல் துறை அலுவலகத்தில் விண்ணப்பிக்கவும்.',
                'link' => 'https://aed.tn.gov.in/en/cluster-based-subsidy-schemes/',
            ],
        ];

        $exists = $db->prepare('SELECT COUNT(*) FROM schemes WHERE title = :title');
        $insert = $db->prepare(
            'INSERT INTO schemes (title, category, description, eligibility, benefits, how_to_apply, link)
             VALUES (:title, :category, :description, :eligibility, :benefits, :how_to_apply, :link)'
        );

        foreach ($schemes as $s) {
            $exists->execute(['title' => $s['title']]);
            if ((int) $exists->fetchColumn() > 0) {
                continue; // already seeded — skip
            }
            $insert->execute($s);
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
