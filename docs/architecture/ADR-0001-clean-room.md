# ADR-0001: Clean-room product boundary

Status: accepted — 2026-08-30

## Decision

UP is implemented from public Cfx.re contracts and original specifications. Code, database schemas, UI, names, artwork, maps, configuration, and other assets from the Creation Network snapshot are not copied or adapted.

Every third-party dependency must be declared in `sbom/dependencies.json`, include provenance and license metadata, and pass the release allowlist. Unknown, leaked, or server-derived assets block a release.

## Consequences

- Compatibility is achieved through documented adapters, never copied internals.
- Contributors must attest that their contribution is original or properly licensed.
- A dependency audit is part of every release candidate.
