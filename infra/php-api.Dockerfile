FROM php:8.3-apache

WORKDIR /var/www/html

RUN apt-get update \
    && apt-get install -y --no-install-recommends git unzip \
    && docker-php-ext-install pdo_mysql \
    && a2enmod rewrite \
    && rm -rf /var/lib/apt/lists/*

# Serve from public/ and allow .htaccess overrides
RUN sed -ri 's!/var/www/html!/var/www/html/public!g' /etc/apache2/sites-available/*.conf /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf \
    && sed -ri 's!AllowOverride None!AllowOverride All!g' /etc/apache2/apache2.conf

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
COPY php_api/composer.json ./
COPY php_api/src ./src
RUN composer install --no-dev --prefer-dist --no-interaction --no-progress --optimize-autoloader

COPY php_api/ ./

# Render assigns a dynamic $PORT; Apache must bind to it at container start
RUN printf '#!/bin/bash\nsed -ri "s/Listen 80/Listen \\${PORT:-80}/" /etc/apache2/ports.conf\nsed -ri "s/:80/:\\${PORT:-80}/" /etc/apache2/sites-available/*.conf\nexec apache2-foreground\n' > /usr/local/bin/start-apache.sh \
    && chmod +x /usr/local/bin/start-apache.sh

EXPOSE 80

CMD ["/usr/local/bin/start-apache.sh"]
