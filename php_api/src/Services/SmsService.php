<?php

namespace App\Services;

class SmsService
{
    private const ENDPOINT = 'https://www.fast2sms.com/dev/bulkV2';

    public function sendOtp(string $phone, string $otpCode): bool
    {
        $apiKey = $_ENV['FAST2SMS_API_KEY'] ?? '';
        if ($apiKey === '') {
            error_log('SmsService: FAST2SMS_API_KEY is not configured; skipping SMS send.');
            return false;
        }

        $query = http_build_query([
            'authorization' => $apiKey,
            'route' => 'otp',
            'variables_values' => $otpCode,
            'flash' => 0,
            'numbers' => $phone,
        ]);

        $ch = curl_init(self::ENDPOINT . '?' . $query);
        curl_setopt_array($ch, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT => 10,
        ]);

        $response = curl_exec($ch);
        $error = curl_error($ch);
        curl_close($ch);

        if ($response === false) {
            error_log('SmsService: Fast2SMS request failed: ' . $error);
            return false;
        }

        $data = json_decode($response, true);
        if (!is_array($data) || ($data['return'] ?? false) !== true) {
            error_log('SmsService: Fast2SMS did not confirm delivery: ' . $response);
            return false;
        }

        return true;
    }
}
