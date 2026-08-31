# UP — Universo Paralelo

Clean-room, server-authoritative FiveM roleplay platform. UP is the permanent product name; `up` is the technical prefix used across resources, events, SQL, tooling, and documentation. This project does not incorporate source code, assets, schemas, or UI from the Creation Network snapshot.

## Status

Foundation / walking skeleton. Not ready for production or sale.

## Components

- `resources/[system]/up_core`: open FiveM core written in CfxLua.
- `database/migrations`: forward-compatible MySQL 8 migrations.
- `cmd/upctl`: cross-platform release and diagnostics CLI written in Go.
- `infra`: reproducible Linux/MySQL reference environment.
- `docs`: architecture, clean-room, security, support, and licensing decisions.
- `sbom`: allowlisted third-party dependencies and their provenance.

## Quick checks

```powershell
go test ./...
go build ./cmd/upctl
go run ./cmd/upctl version
go run ./cmd/upctl doctor --path .
docker compose -f infra/compose.dev.yml config
```

Start the disposable development database with:

```powershell
docker compose -f infra/compose.dev.yml up -d --wait mysql
```

It publishes MySQL on `127.0.0.1:3307` by default to avoid colliding with a local installation. Copy `.env.example` to `.env` and replace every development password before any shared or internet-facing deployment.

Lua syntax is checked in CI with Lua 5.4. Runtime integration tests require an FXServer artifact, a Cfx license key, and MySQL 8.

## Licensing

The open core and CLI are Apache-2.0. Premium gameplay resources will live in separate repositories and are not part of this initial scaffold. Third-party components retain their own licenses; see `sbom/dependencies.json`.
