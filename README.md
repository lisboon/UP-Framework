# UP — Universo Paralelo

Clean-room, server-authoritative FiveM roleplay platform. UP is the permanent product name; `up` is the technical prefix used across resources, events, SQL, tooling, and documentation. This project does not incorporate source code, assets, schemas, or UI from the Creation Network snapshot.

## Status

Foundation / walking skeleton. Not ready for production or sale.

## Components

- `resources/[up]/up_core`: open FiveM core written in CfxLua.
- `database/migrations`: forward-compatible MySQL 8 migrations.
- `cmd/upctl`: cross-platform release and diagnostics CLI written in Go.
- `infra`: reproducible Linux/MySQL reference environment.
- `sbom`: allowlisted third-party dependencies and their provenance.

## Quick checks

```powershell
go test ./...
go build ./cmd/upctl
go run ./cmd/upctl version
go run ./cmd/upctl doctor --path .
docker compose -f infra/compose.dev.yml config
```

## Runtime deployment

For an actual FiveM deployment, launch a current FXServer artifact and deploy `recipe.yaml` through txAdmin. FXServer artifacts are runtime binaries and stay outside Git.

For manual Windows development, copy `server.local.cfg.example` to `server.local.cfg`, replace the license key, extract FXServer into the ignored `artifacts/` directory, and run:

```powershell
.\artifacts\FXServer.exe +exec server.local.cfg
```

`server.cfg` is rendered by txAdmin, while `common.cfg` contains configuration shared by both installation modes. Never commit resolved secrets. Before a public release, the recipe must reference an immutable UP tag or commit.

## Naming contract

The product is **UP — Universo Paralelo**. First-party resources live under `resources/[up]`, use names such as `up_core`, publish versioned events in the form `up:<domain>:<action>:vN`, store data in `up_<domain>_*` tables, and expose operator tooling through `upctl`.

Start the disposable development database with:

```powershell
docker compose -f infra/compose.dev.yml up -d --wait mysql
```

It publishes MySQL on `127.0.0.1:3307` by default to avoid colliding with a local installation. Copy `.env.example` to `.env` and replace every development password before any shared or internet-facing deployment.

Lua syntax is checked in CI with Lua 5.4. Runtime integration tests require an FXServer artifact, a Cfx license key, and MySQL 8.

## Licensing

The open core and CLI are Apache-2.0. Premium gameplay resources will live in separate repositories and are not part of this initial scaffold. Third-party components retain their own licenses; see `sbom/dependencies.json`.
