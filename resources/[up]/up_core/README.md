# up_core

Minimal server-authoritative runtime for UP — Universo Paralelo.

Start `oxmysql` before `up_core` and apply the migrations in `database/migrations`. Public integrations must use the versioned events and exports declared by this resource; direct access to another module's tables is not supported.

The directory `[up]` groups first-party UP resources only. It is not part of the resource name or public API.

## Character lifecycle

Client resources use `TriggerCallback` with `characters.list`, `characters.create`, `characters.delete`, and `characters.select`. Creation accepts `firstName`, `lastName`, and an ISO `birthDate`. A character session is immutable after selection and ends when the player disconnects.

Character names intentionally accept Latin-script letters, spaces, apostrophes, and hyphens for the Brazilian product scope. The database slot ceiling of 32 is a storage invariant; the lower configurable account limit is enforced transactionally by the application.

After character selection, clients use `spawns.list` and `spawns.select` with a configured `locationId`. The server authorizes one expiring spawn attempt and marks the session as loaded only after `spawnmanager` completes it.

Server resources use the character exports and `ListSpawnLocations` or `SelectSpawnLocation`. Ownership, limits, dates, names, configured spawn locations, and current session state are validated by `up_core`.

## Core restart policy

`up_core` deliberately does not rehydrate connected sessions after a resource restart. Authorization grants, active character ownership, mutation locks, and spawn attempts include transient state that cannot be reconstructed safely from persistence alone. After the database and schema checks complete, every client that remained connected is disconnected with a reconnect instruction, regardless of whether it was in `account_ready`, `character_selected`, `spawning`, or `spawned`. A clean reconnect creates a new authorization and authoritative session.

Operators must treat a core restart as a controlled reconnect event. Other first-party resources must clean up their local routing, camera, NUI, and gameplay state during their own stop handlers; they must not attempt to recreate a core session.

## Spawn attestation

Spawn completion is not accepted solely from a client event. Each location selects a configured provider policy. Position policies retain trusted coordinates server-side, wait for the configured OneSync stabilization interval, and compare the server-observed entity position with a provider-specific tolerance. A mismatch returns the player to character selection and emits a structured diagnostic; it never bans automatically. Interior or cinematic handoffs require an explicit, documented exemption on the location.
