# ADR-0001: Provider-neutral inventory with an isolated Ox provider

- Status: Proposed
- Date: 2026-09-01
- Decision owners: UP maintainers
- Tracking issue: [#33](https://github.com/lisboon/UP-Framework/issues/33)
- Acceptance event: merge of the pull request that resolves #33

## Context

UP needs a playable inventory before investing in a native backend and NUI. `ox_inventory` provides that acceleration, but it is an opinionated GPL-3.0-or-later system with its own framework bridge, persistence assumptions, exports, slots, UI, and lifecycle. Allowing gameplay resources to call it directly would make Ox behavior part of UP's permanent public API and would obstruct a later native provider.

The UP repository and its first-party resources are Apache-2.0. This decision establishes a conservative technical and distribution boundary; it is not legal advice. Distribution of a combined commercial product remains blocked on qualified license review.

## Decision

UP will use a provider-neutral first-party facade and an isolated Ox implementation:

```text
first-party gameplay resources
            |
            v
  up_inventory contract v1          Apache-2.0 / UP-Framework
            |
            v
  versioned provider port
            |
            v
  up_inventory_ox adapter           GPL repository and release
            |
            v
  ox_inventory fork v2.47.9         GPL-3.0-or-later
       |                 |
       v                 v
  ox_lib v3.39.0      oxmysql v2.14.1
```

`up_inventory` owns the stable UP contract, authorization, input validation, audit intent, provider health, and lifecycle policy. It contains no Ox imports, exports, events, types, slot semantics, SQL, or UI assumptions.

The future `UP-Inventory-Ox` repository will contain the maintained Ox fork, `modules/bridge/up`, and the `up_inventory_ox` adapter. Treating the adapter conservatively as GPL avoids mixing provider-derived code into the Apache repository. It must preserve upstream history, `LICENSE`, `NOTICE.md`, authorship, modification notices, and corresponding source.

## Repository and resource responsibilities

| Component | Repository/license | Responsibility | Must not do |
|---|---|---|---|
| `up_core` | UP-Framework / Apache-2.0 | Authoritative account, character UUID, passport, phase and lifecycle events | Store inventory JSON, slots, item balances or provider state |
| `up_inventory` | UP-Framework / Apache-2.0 | Public v1 facade, server authorization, validation, provider registration/capabilities, audit/grant orchestration | Import or call Ox; expose provider slots or accept client ownership |
| First-party gameplay | UP repositories / declared first-party license | Call only the public `up_inventory` contract | Call Ox exports/events, query provider tables or depend on its UI |
| `up_inventory_ox` | Separate GPL repository | Implement the provider port, translate UP operations and lifecycle to Ox | Redefine the public UP contract or trust client identity |
| `ox_inventory` fork | Separate GPL repository | Temporary storage engine, item runtime and UI | Modify UP core tables or represent money as items |

After `up_core`, the normal start order is `oxmysql`, `ox_lib`, `up_inventory`, `ox_inventory`, then `up_inventory_ox`. This lets the facade start safely without a provider and makes the UP contract available before the Ox bridge initializes. Provider registration is server-only and versioned. `up_inventory` fails closed while no single compatible provider is healthy; duplicate or incompatible providers are rejected. Restart/re-registration behavior belongs to #37.

## Contract boundary

Issue #34 will define the exact v1 types and names. This ADR fixes the boundary it must preserve:

- Callers identify the connected `source`; `up_inventory` resolves the active character UUID and passport from `up_core`.
- A client never supplies an owner, character UUID, passport, amount authority, target inventory or provider slot.
- Public mutations require a positive integer amount, a bounded scalar-only metadata envelope, an invoking resource, and a non-empty reason.
- Public capability covers inventory snapshot/count, capacity check, add, remove, usable registration, use and transfer. Unsupported capabilities fail explicitly.
- Public results and events use UP item names and sanitized metadata. Provider-specific slot IDs, internal item identities and callbacks remain private.
- Money, bank balances and account transfers are excluded. They belong to a future double-entry ledger.
- Offline mutation, stashes, drops, vehicle storage, weapons, shops and crafting are outside the first playable slice.

No first-party executable source may contain `ox_inventory`, `@ox_inventory`, or `ox_inventory:*` references. CI enforces this rule. Only the separate GPL provider repository may know the Ox API.

## Authority and lifecycle

The active character UUID is the storage identity. Passport is a public gameplay identifier and must not be the provider's primary key. Transient FiveM source IDs are never persisted.

The provider may load after `characterActivated`, but public UI and mutations remain blocked until the authoritative phase is `spawned`. It unloads on `playerUnloaded`. Source reuse, reconnect and independent resource restarts must re-resolve the current UUID rather than reuse cached ownership. These transitions are implemented and qualified in #37.

Every mutation is initiated server-side. Client messages express intent only; the server resolves ownership, item definition, allowed metadata, quantity, capacity and target. Grants and externally meaningful mutations use the idempotency and audit model in #35.

## Data ownership and schema boundary

UP owns the semantic data: character ownership, item names, counts, approved metadata, grants, audit reasons and the provider-neutral migration format. During the Ox phase, the GPL provider owns the physical inventory representation and transaction mechanics.

The provider must use dedicated provider tables keyed by `up_core_characters.id`. It must not add an `inventory` column to `up_core_characters`, write inventory data into `metadata`, or store a transient source/passport as ownership. Exact DDL belongs to #36 and must preserve soft-deleted character data for audit and migration.

Slots and Ox internal identifiers are implementation details. Audit/grant tables created in #35 remain first-party and must not contain provider slots.

## Migration to a native provider

The provider port must support a maintenance-mode export before the first release that stores player data. The provider-neutral snapshot will be finalized in #34 and must include at least:

- schema version and source provider/version;
- character UUID;
- normalized item name, count and sanitized metadata per stack/instance;
- deterministic totals and a content hash;
- export timestamp and correlation ID.

Cutover procedure:

1. Block new inventory mutations and wait for in-flight operations.
2. Force provider saves and retain an immutable database backup.
3. Export all character snapshots and validate counts, metadata and hashes.
4. Import into the native provider in a disposable environment and run reconciliation.
5. Switch the configured provider only after zero unexplained differences.
6. Keep the Ox data read-only for the rollback window; never dual-write providers.
7. Record the cutover and per-character result in the audit trail.

Rollback restores the original provider configuration and database snapshot before mutations resume. A provider cannot be declared replaceable until this export/import rehearsal passes.

## Supply-chain and distribution policy

The evaluated baseline is:

| Dependency | Version | Immutable commit | Official release SHA-256 |
|---|---|---|---|
| `ox_inventory` | `v2.47.9` | `952c128fdff056fd7506d924faa6c07fb80892e9` | `c072acd028cd8f75f3fab1a594e85c620a4c77cfb5db77a4ea64bcdefd362ae1` |
| `ox_lib` | `v3.39.0` | `08bac37f3b56d4c3c56d6a0b3749ec3d527de9d6` | `1df6724dfc1d2d287299ff023a29c9e999eb77832cb918a4f1761d5c18a54501` |

The baseline records evaluated inputs; it does not install or bundle them. #36 must pin the actual fork commit and release archive in the release lock before deployment.

Updates are deliberate, never automatic:

1. Fetch the upstream tag into the GPL fork without rewriting history.
2. Review the complete upstream diff, database changes, licenses and notices.
3. Rebase or replay UP patches with a modification log.
4. Run the provider contract suite, migration rehearsal, restart matrix and two-client anti-duplication tests.
5. Publish a GPL source release and record its commit and artifact digest.
6. Update SBOM/lock only in the consuming UP release.

No Ox-derived code, built UI or release archive enters this Apache repository. Operators install the GPL provider separately until legal review approves a distribution model. Encryption, escrow-only source, entitlement bypasses and removal of notices are prohibited.

## Security model

The inventory-specific threat model is maintained in [inventory-threat-model.md](../security/inventory-threat-model.md). Its blocking properties are server-resolved ownership, bounded inputs, idempotent grants, atomic transfers, fail-closed provider health, lifecycle revalidation and auditable supply-chain inputs.

## Alternatives considered

### Vendor or fork Ox inside UP-Framework

Rejected. It mixes a GPL-derived provider and UI into the Apache release surface, encourages direct calls and makes the temporary implementation look permanent.

### Pretend to be Qbox or ESX

Rejected. Compatibility shims would leak foreign identity, money and schema assumptions into `up_core` and hide the actual contract.

### Build the complete native inventory first

Deferred. It offers maximum control but postpones a playable server and recreates backend, interaction and NUI work before UP has validated gameplay requirements.

### Let each gameplay script choose a provider

Rejected. It prevents centralized authorization, audit, migration and provider replacement.

### Dual-write Ox and a native schema

Rejected. Cross-provider atomicity is unavailable and creates an additional duplication/loss path. Export, reconcile and cut over under maintenance mode instead.

## Consequences

Positive:

- A playable provider can arrive without making Ox the UP domain.
- First-party gameplay and future premium resources retain one stable contract.
- License obligations, update risk and provider data are visible and isolated.
- A native provider can replace Ox through a rehearsed migration rather than a rewrite of every consumer.

Costs and risks:

- Two repositories and resources require coordinated releases and compatibility tests.
- The temporary provider schema needs an explicit migration path.
- GPL boundary conclusions still require qualified legal review before commercial distribution.
- Some Ox features remain deliberately unavailable through v1.

## Acceptance gates

Before #36 starts:

- [ ] This ADR is accepted through review.
- [ ] The first-party boundary test is green.
- [ ] SBOM pins and upstream links are independently verified.
- [ ] The GPL fork repository and public corresponding-source policy are agreed.
- [ ] Qualified legal review is tracked as an unresolved commercial-release gate.

Before any provider release:

- [ ] Fork commit, archives, checksums, licenses, notices and modification log are present.
- [ ] No first-party source calls Ox directly.
- [ ] Provider contract, lifecycle, migration and anti-duplication suites pass.
- [ ] Known limitations and rollback instructions are published.

## References

- [`ox_inventory` v2.47.9 release](https://github.com/overextended/ox_inventory/releases/tag/v2.47.9)
- [`ox_inventory` v2.47.9 commit](https://github.com/overextended/ox_inventory/commit/952c128fdff056fd7506d924faa6c07fb80892e9)
- [`ox_inventory` license and distribution notice](https://github.com/overextended/ox_inventory/blob/v2.47.9/NOTICE.md)
- [`ox_inventory` unsupported-framework integration guidance](https://github.com/overextended/overextended.github.io/blob/main/content/docs/ox_inventory/index.mdx#using-an-unsupported-framework)
- [`ox_lib` v3.39.0 release](https://github.com/overextended/ox_lib/releases/tag/v3.39.0)
- [Inventory contract #34](https://github.com/lisboon/UP-Framework/issues/34)
- [Grants and audit #35](https://github.com/lisboon/UP-Framework/issues/35)
- [Ox provider #36](https://github.com/lisboon/UP-Framework/issues/36)
- [Inventory lifecycle #37](https://github.com/lisboon/UP-Framework/issues/37)
