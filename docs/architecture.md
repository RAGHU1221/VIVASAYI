# Architecture Overview

## Core Principles

- Clean Architecture
- SOLID principles
- Repository pattern
- Separation of concerns
- REST API standards
- Mobile-first responsive UI
- Localization support for Tamil + English
- Security-first design

## Mobile App

The Flutter application follows a layered structure:

- `lib/main.dart` — app entry point
- `lib/src/app.dart` — app widget and theme configuration
- `lib/src/routes/` — route definitions and navigation
- `lib/src/features/` — feature modules for authentication, onboarding, and future ERP modules
- `lib/src/services/` — API clients, local storage, and offline sync
- `lib/src/data/` — models, repositories, and data sources
- `lib/src/ui/` — reusable widgets, themes, and screens

## PHP REST API Backend

The PHP API uses modern structure with the following layers:

- `public/` — web-facing entry point
- `src/Config/` — environment and database configuration
- `src/Controllers/` — HTTP controllers for each feature
- `src/Services/` — business logic and reusable services
- `src/Models/` — data model mapping and entity encapsulation
- `src/Middleware/` — request validation, JWT authentication, and security filtering
- `src/Routes/` — route definitions

## Admin Panel

The Bootstrap 5 admin panel is a static frontend scaffold with:

- responsive dashboard layout
- navigation drawer
- reusable components for cards, tables, forms, and charts
- dark and light theme support

## Database

The MySQL schema is designed for authentication, roles, users, sessions, and audit logs. Future ERP modules will extend this foundation with farmer, farm, crop, weather, and AI dataset tables.

## Deployment

- Use environment-based configuration
- Keep secrets in `.env` files and deploy only example files
- Enable logging and exception handling in all layers
- Prepare Docker or managed infrastructure scripts in `infra/`
