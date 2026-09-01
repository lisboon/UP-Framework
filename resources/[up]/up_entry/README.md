# up_entry

First-party runtime for the UP entry experience. It isolates pre-spawn players in population-free routing buckets and restores the public world after the authoritative `playerSpawned` event.

Presentation layers may add cameras, preview peds, audio, and NUI state inside this resource. They must not own account, character, or spawn authority, and they must preserve the cleanup behavior in `client/session.lua`.

The first-party presentation creates a local preview ped and scripted camera while the player remains isolated. After character selection, Lua retains the trusted spawn catalog and exposes only location identifiers and labels to the NUI. Location previews move the camera with trusted coordinates; the final identifier is revalidated by `up_core` before `spawnmanager` runs. Expired attempts restore the arrival interface instead of leaving the client behind a black screen.

The replicated `up:entry` player state is the integration boundary for voice and other resources that must suppress gameplay behavior during entry. `up_entry` does not take ownership of a server's voice implementation.

Server integrations use the stable `IsInEntry(source)` boolean export. The internal session table and bucket representation are not public contracts.

Entry buckets reserve identifiers from `bucketBase + 1` through the configured server source range. The default base `100000` keeps this namespace separate from ordinary gameplay buckets. A disconnected player is removed from the in-memory registry without native resets because FiveM destroys its player routing and state-bag context; connected players are explicitly restored during completion or resource shutdown.

Client synchronization is event-driven. Resource restart triggers a `clientReady` handshake, and the local `up:entry` state-bag handler recovers a missed `entered` event with one bounded sequence at 0, 250, 750, and 1750 ms. Receiving `entered` or `left`, completing spawn, losing the local player, or stopping the resource invalidates pending callbacks. There is no frame or permanent polling, and `clientReady` only asks the server to replay an existing authoritative session.

For development-only failure injection, set `up_entry_test_drop_entered` to the number of initial `entered` events that the server should discard, then restart `up_entry`. Reset it to `0` immediately after the smoke test. The default is disabled, and dropping the notification does not change the authoritative session or replicated state.

The NUI uses a separate versioned protocol. Lua owns entry lifecycle and sends presentation commands; the web layer renders them and cannot authorize character or spawn operations. Install dependencies and build from `web/`; the generated `web/dist` is tracked because a deployed FiveM resource cannot assume a Node.js toolchain.

Character presentation is organized by domain under `web/src/features/entry`. Its provider coordinates loading and mutations, services own NUI transport, the model owns protocol state, and components remain presentation-focused. Character constraints come from `up_core`; the browser never owns slot, identity, deletion, or selection authority.

```text
npm --prefix resources/[up]/up_entry/web ci
npm --prefix resources/[up]/up_entry/web test
npm --prefix resources/[up]/up_entry/web run build
```
