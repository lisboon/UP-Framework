# up_core

Minimal server-authoritative runtime for UP — Universo Paralelo.

Start `oxmysql` before `up_core` and apply the migrations in `database/migrations`. Public integrations must use the versioned events and exports declared by this resource; direct access to another module's tables is not supported.

The directory `[system]` groups infrastructure resources only. It is not part of the resource name or public API.
