# ADR-0002: Runtime and language boundaries

Status: accepted — 2026-08-30

## Decision

- CfxLua 5.4 owns latency-sensitive FiveM runtime and gameplay resources.
- React/TypeScript will own browser NUI packages.
- Go owns installation, diagnostics, release verification, backups, and other control-plane tooling.
- MySQL 8 with oxmysql is the persistence contract.
- Docker Compose is a reproducible Linux reference, not a requirement for Windows customers.

The `up_core` resource stays small: identity, character lifecycle, permissions, callbacks, contracts, migrations, and observability. Economy, inventory, professions, housing, vehicles, and integrations are modules behind versioned contracts.

## Consequences

Business modules cannot read another module's tables directly. Public events and exports carry a version suffix. Server code is authoritative for money, inventory, permissions, and state mutations.
