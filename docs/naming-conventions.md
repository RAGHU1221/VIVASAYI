# Naming Conventions

## Flutter

- Files and folders: `snake_case`
- Classes: `PascalCase`
- Constants: `kUpperCamelCase` or `camelCase` with `const`
- Widget names: descriptive and end with `Widget` only when helpful.
- Provider or state classes: end with `Provider`, `Controller`, or `Store`.
- API clients: end with `ApiClient` or `ApiService`.

## PHP

- Files: `snake_case.php` for entrypoints and `PascalCase.php` for classes.
- Namespaces: `App\Feature\Subfeature`
- Classes: `PascalCase`
- Methods: `camelCase`
- Variables: `snake_case`
- Constants: `UPPER_SNAKE_CASE`

## Database

- Tables: `snake_case` plural nouns, e.g. `farmers`, `user_sessions`.
- Columns: `snake_case`.
- Indexes: `idx_<table>_<column>`.
- Foreign keys: `fk_<table>_<reference>`.
- Pivot tables: alphabetical, e.g. `farm_user`.

## Admin Panel

- CSS classes: `kebab-case`
- IDs: `camelCase`
- JavaScript vars: `camelCase`
- HTML data attributes: `data-<purpose>`
