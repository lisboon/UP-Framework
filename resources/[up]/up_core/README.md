# up_core

Minimal server-authoritative runtime for UP — Universo Paralelo.

Start `oxmysql` before `up_core` and apply the migrations in `database/migrations`. Public integrations must use the versioned events and exports declared by this resource; direct access to another module's tables is not supported.

The directory `[up]` groups first-party UP resources only. It is not part of the resource name or public API.

## Character lifecycle

Client resources use `TriggerCallback` with `characters.list`, `characters.create`, `characters.delete`, and `characters.select`. Creation accepts `firstName`, `lastName`, and an ISO `birthDate`. A character session is immutable after selection and ends when the player disconnects.

Server resources use the `ListCharacters`, `CreateCharacter`, `DeleteCharacter`, and `SelectCharacter` exports. Ownership, limits, dates, names, and current session state are validated by `up_core`.
