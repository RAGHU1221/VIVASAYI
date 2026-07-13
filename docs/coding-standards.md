# Coding Standards

## General

- Follow clean, readable code with consistent indentation and naming.
- Prefer composition over inheritance.
- Keep methods small: one responsibility per method.
- Avoid hard-coded values; use constants and theme tokens.
- Write documentation comments for public APIs and services.
- Use feature-based folder structure for Flutter and modular folders for backend.

## Flutter

- Organize code by feature, not by type.
- Use `const` constructors whenever possible.
- Prefer `final` for immutable state.
- Keep widgets composable and stateful widgets minimal.
- Use `flutter_lints` or similar analysis rules.
- Use `json_serializable` for model conversion.
- Keep UI code declarative and avoid side effects in `build()`.

## PHP

- Follow PSR-12 coding standards.
- Use strict typing and type hints.
- Keep controllers thin and move business logic into services.
- Use dependency injection for reusable components.
- Sanitize and validate all input data.
- Use prepared statements via PDO.
- Avoid echoing raw content; use response objects.

## Admin Panel

- Keep markup semantic and accessible.
- Use Bootstrap classes for spacing and layout.
- Keep JavaScript unobtrusive and modular.
- Use CSS custom properties for theme values.
- Prefer progressive enhancement over complex scripts.
