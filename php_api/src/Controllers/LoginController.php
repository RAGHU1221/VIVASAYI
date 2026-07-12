<?php

namespace App\Controllers;

use App\Services\AuditLogService;
use App\Services\AuthOtpService;
use App\Services\SessionService;
use App\Services\SmsService;
use App\Services\UserService;
use Firebase\JWT\JWT;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;

class LoginController
{
    private UserService $userService;
    private AuthOtpService $otpService;
    private SessionService $sessionService;
    private AuditLogService $auditLogService;
    private SmsService $smsService;

    public function __construct()
    {
        $this->userService = new UserService();
        $this->otpService = new AuthOtpService();
        $this->sessionService = new SessionService();
        $this->auditLogService = new AuditLogService();
        $this->smsService = new SmsService();
    }

    public function requestOtp(Request $request): JsonResponse
    {
        $payload = json_decode($request->getContent(), true);
        if (!is_array($payload)) {
            return new JsonResponse(['error' => 'Invalid request body'], 400);
        }

        $phone = trim($payload['phone'] ?? '');
        if ($phone === '') {
            return new JsonResponse(['error' => 'Phone number is required'], 400);
        }

        $user = $this->userService->getByPhone($phone);
        if ($user === null || $user->is_active !== 1) {
            return new JsonResponse(['error' => 'User not found or inactive'], 404);
        }

        $otp = $this->otpService->createOtpCode($user->id, $phone);
        $sent = $this->smsService->sendOtp($phone, $otp['otp_code']);
        $this->auditLogService->createLog($user->id, 'login.request_otp', ['phone' => $phone, 'sms_sent' => $sent], $request->getClientIp());

        if (!$sent) {
            return new JsonResponse(['error' => 'Unable to send OTP SMS. Please try again shortly.'], 502);
        }

        return new JsonResponse([
            'phone' => $phone,
            'otp_id' => $otp['id'],
            'expires_at' => $otp['expires_at'],
            'message' => 'OTP sent successfully. Use this OTP to verify login.',
        ]);
    }

    public function verifyOtp(Request $request): JsonResponse
    {
        $payload = json_decode($request->getContent(), true);
        if (!is_array($payload)) {
            return new JsonResponse(['error' => 'Invalid request body'], 400);
        }

        $phone = trim($payload['phone'] ?? '');
        $otpCode = trim($payload['otp_code'] ?? '');
        if ($phone === '' || $otpCode === '') {
            return new JsonResponse(['error' => 'Phone and OTP code are required'], 400);
        }

        $otp = $this->otpService->getLatestValidOtp($phone, $otpCode);
        if ($otp === null) {
            return new JsonResponse(['error' => 'Invalid or expired OTP'], 401);
        }

        $user = $this->userService->getByPhone($phone);
        if ($user === null || $user->is_active !== 1) {
            return new JsonResponse(['error' => 'User not found or inactive'], 404);
        }

        $this->otpService->markOtpUsed((int) $otp['id']);

        $secret = $_ENV['JWT_SECRET'] ?? 'change_me_securely';
        $issuedAt = time();
        $expiresAt = $issuedAt + 3600;
        $tokenPayload = [
            'sub' => $user->id,
            'phone' => $user->phone,
            'role' => $user->role,
            'iat' => $issuedAt,
            'exp' => $expiresAt,
        ];

        $jwt = JWT::encode($tokenPayload, $secret, 'HS256');
        $expiresAtDate = date('Y-m-d H:i:s', $expiresAt);
        $this->sessionService->createSession($user->id, $jwt, $expiresAtDate, $request->headers->get('User-Agent'), $request->getClientIp());
        $this->auditLogService->createLog($user->id, 'login.verify_otp', ['phone' => $phone], $request->getClientIp());

        return new JsonResponse([
            'token' => $jwt,
            'expires_at' => $expiresAt,
            'user' => $user->toArray(),
        ]);
    }
}
