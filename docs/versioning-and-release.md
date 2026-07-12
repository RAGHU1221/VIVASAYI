# Versioning and Release Strategy

## Semantic Versioning

- Use `MAJOR.MINOR.PATCH`.
- `MAJOR` for breaking changes.
- `MINOR` for new features without breaking compatibility.
- `PATCH` for bug fixes and small improvements.

## Branching

- `main` for production-ready code.
- `develop` for integration and feature readiness.
- `feature/*` for new modules and UI work.
- `hotfix/*` for urgent fixes.

## Release Workflow

- Create a release branch from `develop`.
- Run tests and validate linting.
- Merge into `main` with a release tag.
- Tag releases in Git with `v<major>.<minor>.<patch>`.

## Deployment Notes

- Keep configuration separate by environment.
- Use `infra/docker-compose.yml` for local development.
- Avoid committing generated packages and credentials.
