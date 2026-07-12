FROM php:8.3-apache

WORKDIR /var/www/html

RUN apt-get update \
    && apt-get install -y --no-install-recommends git unzip \
    && docker-php-ext-install pdo_mysql \
    && a2enmod rewrite \
    && rm -rf /var/lib/apt/lists/*

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
COPY php_api/composer.json ./
COPY php_api/src ./src
RUN composer install --no-dev --prefer-dist --no-interaction --no-progress --optimize-autoloader

COPY php_api/ ./
