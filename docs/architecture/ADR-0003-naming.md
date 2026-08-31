# ADR-0003: Permanent naming convention

Status: accepted — 2026-08-30

## Decision

The product and public brand are **UP — Universo Paralelo**. Technical identifiers use the ASCII lowercase prefix `up`; prose may use “UP”. We do not use the generic word `system` as a product or namespace.

| Surface | Convention | Example |
|---|---|---|
| Resource category | `[system]` | `resources/[system]/up_core` |
| FiveM resource | `up_<domain>` | `up_core`, `up_economy` |
| Lua global | `UP` plus PascalCase members | `UP.Players` |
| Network event | `up:<domain>:<action>:vN` | `up:character:activated:v1` |
| State bag | `up:<name>` | `up:passport` |
| Export | PascalCase verb | `GetPlayerState` |
| SQL object | `up_<domain>_<noun>` | `up_core_accounts` |
| Permission | `up.<scope>` | `up.admin` |
| CLI | `upctl` | `upctl doctor` |
| Configuration | `up.*` | `up.toml`, `up.lock.json` |
| Go module | repository identity | `github.com/lisboon/up` |

Names are English in source code and contracts; user-facing copy may be Portuguese. Version suffixes are mandatory on network events and public contracts. The brand name is never embedded into generic domain concepts when the `up` prefix already supplies ownership.

## Consequences

New modules can be discovered and supported consistently without renaming the core. `[system]` is only an organizational directory and has no API meaning.
