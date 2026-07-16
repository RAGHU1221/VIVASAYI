<?php

namespace App\Config;

use PDO;

class Database
{
    private static ?PDO $connection = null;

    public static function getConnection(): PDO
    {
        if (self::$connection === null) {
            $host = $_ENV['DB_HOST'] ?? '127.0.0.1';
            $port = $_ENV['DB_PORT'] ?? '3306';
            $database = $_ENV['DB_DATABASE'] ?? 'if0_42389804_vivasayi';
            $username = $_ENV['DB_USERNAME'] ?? 'root';
            $password = $_ENV['DB_PASSWORD'] ?? '';
            $dsn = sprintf('mysql:host=%s;port=%s;dbname=%s;charset=utf8mb4', $host, $port, $database);

            $options = [
                PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            ];

            // Cloud MySQL (Aiven etc.) ku SSL mandatory —
            // DB_SSL_CA env la path kudukalam, illa na repo root la
            // irukka ca.pem auto-detect aagum.
            $sslCa = $_ENV['DB_SSL_CA'] ?? '';
            if ($sslCa === '') {
                $defaultCa = dirname(__DIR__, 2) . '/ca.pem';
                if (is_file($defaultCa)) {
                    $sslCa = $defaultCa;
                }
            }
            if ($sslCa !== '' && is_file($sslCa)) {
                $options[PDO::MYSQL_ATTR_SSL_CA] = $sslCa;
                $options[PDO::MYSQL_ATTR_SSL_VERIFY_SERVER_CERT] = true;
            }

            self::$connection = new PDO($dsn, $username, $password, $options);
        }

        return self::$connection;
    }
}
