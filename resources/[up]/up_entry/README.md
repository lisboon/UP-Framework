# up_entry

First-party runtime for the UP entry experience. It isolates pre-spawn players in population-free routing buckets and restores the public world after the authoritative `playerSpawned` event.

Presentation layers may add cameras, preview peds, audio, and NUI state inside this resource. They must not own account, character, or spawn authority, and they must preserve the cleanup behavior in `client/session.lua`.

The first-party presentation creates a local preview ped and scripted camera while the player remains isolated. After character selection, Lua retains the trusted spawn catalog and exposes only location identifiers and labels to the NUI. Location previews move the camera with trusted coordinates; the final identifier is revalidated by `up_core` before `spawnmanager` runs. Expired attempts restore the arrival interface instead of leaving the client behind a black screen.

The replicated `up:entry` player state is the integration boundary for voice and other resources that must suppress gameplay behavior during entry. `up_entry` does not take ownership of a server's voice implementation.

Server integrations use the stable `IsInEntry(source)` boolean export. The internal session table and bucket representation are not public contracts.

Entry buckets reserve identifiers from `bucketBase + 1` through the configured server source range. The default base `100000` keeps this namespace separate from ordinary gameplay buckets. A disconnected player is removed from the in-memory registry without native resets because FiveM destroys its player routing and state-bag context; connected players are explicitly restored during completion or resource shutdown.

Client synchronization is event-driven. Resource restart triggers a new `clientReady` handshake, but a client that retains replicated `up:entry = true` while missing the corresponding `entered` event has no watchdog yet. Add state-divergence recovery before public release if runtime evidence shows this window can occur; use a state-bag change handler with bounded `SetTimeout` backoff rather than continuous polling. The recovery must remain idempotent and must never create a server session.

The NUI uses a separate versioned protocol. Lua owns entry lifecycle and sends presentation commands; the web layer renders them and cannot authorize character or spawn operations. Install dependencies and build from `web/`; the generated `web/dist` is tracked because a deployed FiveM resource cannot assume a Node.js toolchain.

Character presentation follows a layered layout under `web/src`:

```text
web/src/
├── app/                  # composition root: App, view switcher and flow tests
├── components/
│   ├── arrival/          # arrival screen (location selection)
│   ├── character/        # character screen, list and dialogs
│   ├── layout/           # transient shell (loading, spawning, error)
│   └── ui/               # reusable primitives (dialog frame)
├── hooks/                # React hooks (NUI message bridge)
├── providers/            # context, provider and entry reducer
├── services/             # NUI transport and character/spawn services
├── types/                # versioned NUI protocol and state contracts
└── styles/               # global stylesheet
```

Files use kebab-case; exported components use PascalCase with named exports. `app/` and screens stay composition-only: the provider coordinates loading and mutations, the reducer owns protocol state, services own NUI transport, and components remain presentation-focused. There is no `lib/` layer because no shared utility emerged; single-consumer helpers stay co-located with their consumer. Character constraints come from `up_core`; the browser never owns slot, identity, deletion, or selection authority.

```text
npm --prefix resources/[up]/up_entry/web ci
npm --prefix resources/[up]/up_entry/web test
npm --prefix resources/[up]/up_entry/web run build
```
