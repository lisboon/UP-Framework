# up_core

Minimal server-authoritative runtime for UP — Universo Paralelo.

Start `oxmysql` before `up_core` and apply the migrations in `database/migrations`. Public integrations must use the versioned events and exports declared by this resource; direct access to another module's tables is not supported.

The directory `[up]` groups first-party UP resources only. It is not part of the resource name or public API.

## Character lifecycle

Client resources use `TriggerCallback` with `characters.list`, `characters.create`, `characters.delete`, and `characters.select`. Creation accepts `firstName`, `lastName`, and an ISO `birthDate`. A character session is immutable after selection and ends when the player disconnects.

Character names intentionally accept Latin-script letters, spaces, apostrophes, and hyphens for the Brazilian product scope. The database slot ceiling of 32 is a storage invariant; the lower configurable account limit is enforced transactionally by the application.

After character selection, clients use `spawns.list` and `spawns.select` with a configured `locationId`. The server authorizes one expiring spawn attempt and marks the session as loaded only after `spawnmanager` completes it.

Server resources use the character exports and `ListSpawnLocations` or `SelectSpawnLocation`. Ownership, limits, dates, names, configured spawn locations, and current session state are validated by `up_core`.
