# Infrastructure

This folder contains example deployment and local environment configuration.

## Docker Compose

Start the PHP API and MySQL database locally using:

```
cd infra
docker compose up -d
```

## Notes

- The PHP API container builds from `infra/php-api.Dockerfile`, installs `pdo_mysql` and Composer dependencies, maps `../php_api/` into `/var/www/html`, and serves `/var/www/html/public`.
- The database loads scripts from `../database/` on first initialization.
- `docker-compose.yml` provides local database and JWT environment values. A `php_api/.env` file is optional for local overrides.
- Use MySQL credentials from `docker-compose.yml`.
