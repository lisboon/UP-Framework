# up_entry

First-party runtime for the UP entry experience. It isolates pre-spawn players in population-free routing buckets and restores the public world after the authoritative `playerSpawned` event.

Presentation layers may add cameras, preview peds, audio, and NUI state inside this resource. They must not own account, character, or spawn authority, and they must preserve the cleanup behavior in `client/session.lua`.

The replicated `up:entry` player state is the integration boundary for voice and other resources that must suppress gameplay behavior during entry. `up_entry` does not take ownership of a server's voice implementation.

Server integrations use the stable `IsInEntry(source)` boolean export. The internal session table and bucket representation are not public contracts.

Entry buckets reserve identifiers from `bucketBase + 1` through the configured server source range. The default base `100000` keeps this namespace separate from ordinary gameplay buckets. A disconnected player is removed from the in-memory registry without native resets because FiveM destroys its player routing and state-bag context; connected players are explicitly restored during completion or resource shutdown.

Client synchronization is event-driven. Resource restart triggers a new `clientReady` handshake, but a client that retains replicated `up:entry = true` while missing the corresponding `entered` event has no watchdog yet. Add state-divergence recovery before public release if runtime evidence shows this window can occur; use a state-bag change handler with bounded `SetTimeout` backoff rather than continuous polling. The recovery must remain idempotent and must never create a server session.
