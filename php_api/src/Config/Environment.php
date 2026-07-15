<?php

namespace App\Config;

use Dotenv\Dotenv;

class Environment
{
    public static function load(string $path): void
    {
        if (!file_exists($path)) {
            return;
        }

        $dotenv = Dotenv::createImmutable(dirname($path));
        $dotenv->load();
    }
}
