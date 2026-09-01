# Inventory threat model

- Status: Initial P4 model
- Updated: 2026-09-01
- Architecture: [ADR-0001](../adr/0001-inventory-provider-boundary.md)
- Qualification issue: [#40](https://github.com/lisboon/UP-Framework/issues/40)

## Scope and security objectives

This model covers the personal inventory slice: catalog, weight/slots, metadata, starter grants, item use and player-to-player transfer. Stashes, drops, vehicles, weapons, shops, crafting, offline mutation and money are deferred and require threat-model extensions before implementation.

Security objectives:

- only the authoritative active character owns and mutates its inventory;
- retries, concurrency, reconnects and resource restarts do not duplicate or lose items;
- clients cannot choose trusted identifiers, quantities, metadata, capacity outcomes or provider slots;
- provider failure is visible and closed to mutation;
- every externally meaningful mutation has an attributable resource, reason and correlation trail;
- a provider can be replaced without silent semantic data loss.

## Trust boundaries

| Boundary | Trust level | Rules |
|---|---|---|
| FiveM client/NUI | Untrusted | Sends intent only; rate-limited and fully revalidated server-side |
| Server resource caller | Trusted by operator installation, not automatically allowed every operation | Attributed with `GetInvokingResource`; exact resource/operation policy and reason are validated |
| `up_inventory` | Authoritative policy boundary | Resolves source to the current character and owns public validation/audit intent |
| Provider adapter | Privileged implementation | Receives only validated internal requests; must enforce version and ownership again |
| Ox runtime/UI | Temporary GPL provider | Never becomes a public UP contract or source of character authority |
| MySQL | Trusted persistence with failure modes | Constraints, transactions, idempotency keys, backups and reconciliation are mandatory |
| Dependency/release channel | Untrusted until verified | Tags, commits, digests, licenses and corresponding source must match the release record |

## Threats and required controls

### Ownership spoofing and source reuse

Threat: a client supplies another passport/UUID, or a cached source becomes associated with a different player after reconnect.

Controls:

- public APIs accept a live source, never a caller-provided owner;
- resolve character UUID from `up_core` for every mutation boundary;
- require the authoritative `spawned` phase;
- unload on `playerUnloaded` and invalidate all source-bound state;
- provider records use immutable character UUIDs, not sources or passports.

The facade copies identity fields from `up_core` rather than retaining its live player-state table. After any provider yield it re-resolves the source and rejects the result with `session_mismatch` if the character UUID or spawned phase changed.

### Caller confusion and over-privileged resources

Threat: a server resource accidentally invokes an inventory mutation it should not own, omits attribution, or uses another resource's intended reason. A malicious resource installed by the operator already executes privileged server code and is outside the isolation guarantees of this contract.

Controls:

- capture `GetInvokingResource` at the public export boundary;
- maintain an exact resource-to-operation policy and fail closed for a missing or unauthorized caller;
- treat the resource name as attribution and policy input, not client authentication or a sandbox;
- require a bounded reason for every mutation and retain both fields in server-side audit intent;
- provider registration verifies that the invoking resource matches the declared provider name;
- do not expose mutation exports through client network events.

### Forged quantities, slots and metadata

Threat: negative/overflow amounts, arbitrary slots, nested payload bombs or privileged metadata create items or bypass capacity.

Controls:

- positive bounded integers only;
- no provider slot in the public API;
- #34 enforces a generic scalar-only envelope with key/value and serialized-size limits;
- #38 defines item stack, weight, use and explicit public-metadata policy;
- provider recalculates capacity and totals server-side;
- malformed requests fail without partial mutation.

### Duplicate grants and replay

Threat: retry, reconnect or concurrent reward delivery grants the same items multiple times.

Controls:

- globally unique idempotency key per grant;
- transactional pending/applied state in first-party tables;
- provider metadata may carry a temporary grant marker for reconciliation;
- retry converges to the intended total instead of repeating the full add;
- append-only audit records the correlation key and result.

Implementation and crash-point tests belong to #35.

### Transfer races and partial mutation

Threat: simultaneous transfers, disconnects or provider errors remove without adding, add without removing, or duplicate a stack.

Controls:

- server resolves both currently active characters;
- deterministic lock order and one atomic provider operation where supported;
- preconditions are rechecked under the mutation lock;
- failure returns a stable error and leaves both totals unchanged;
- post-operation audit and reconciliation compare before/after totals.

Qualification belongs to #39 and #40.

### Direct provider bypass

Threat: first-party code calls Ox exports/events or tables and bypasses UP validation, audit and migration boundaries.

Controls:

- CI rejects `ox_inventory` references in first-party executable sources;
- only `up_inventory_ox` in the separate GPL repository calls Ox;
- code review checks manifests, generated UI and server SQL;
- the facade exposes provider health and fails closed rather than offering a fallback bypass.

### Lifecycle and restart divergence

Threat: inventory remains associated with Entry, a previous character or stale source after resource restart.

Controls:

- loading may begin at `characterActivated`, but UI/mutations require `spawned`;
- public reads also require `spawned`;
- `playerUnloaded` closes UI, saves and invalidates the session;
- core health is checked actively because an `up_core` restart intentionally disconnects players and may not emit a per-player unload event;
- adapter restart enumerates connected players and re-resolves authoritative state;
- `up_core` restart retains its reconnect policy; inventory never reconstructs core authority;
- save timeout and rehydration failures emit structured diagnostics and block mutation.

Qualification belongs to #37.

### Item-use escalation

Threat: a client selects an arbitrary callback, replays use or injects metadata to invoke privileged gameplay.

Controls:

- usable handlers are registered server-side by identified and operation-authorized resources;
- item and handler come from the trusted catalog;
- the server checks possession and consumes according to declared semantics;
- one use token cannot complete twice;
- events expose sanitized results, never function references or private metadata.

### Information disclosure

Threat: snapshots/events reveal private metadata or inventories belonging to other characters.

Controls:

- public snapshots are scoped to the resolved source;
- transfer targets receive only data required for the interaction;
- client events carry no item metadata until #38 supplies explicit per-item public-key allowlists;
- logs avoid full inventory/PII payloads and use correlation IDs;
- administrative inspection requires explicit permission and separate future design.

### Provider outage and data corruption

Threat: provider/database failure accepts mutations that cannot be saved or loads malformed inventory data.

Controls:

- health/version handshake and fail-closed mutation path;
- schema/version validation on load;
- bounded save timeout with structured failure logs;
- immutable backup before migrations and provider cutover;
- count/hash reconciliation and quarantine instead of silently discarding malformed rows.

### Supply-chain or license failure

Threat: a mutable tag, modified archive, removed notice or closed-source fork introduces malicious code or makes distribution non-compliant.

Controls:

- pin tag, commit and official archive SHA-256;
- review upstream diffs before updates;
- preserve history, GPL license, notice and corresponding source;
- publish modification logs and fork artifact digests;
- keep the GPL implementation outside the Apache repository;
- block commercial distribution until qualified legal review is complete.

### Money represented as items

Threat: item operations bypass financial invariants and make balances duplicable through inventory flows.

Control: money and accounts are prohibited from the inventory catalog and belong to a future double-entry ledger.

## Required security evidence

Before the P4 gate closes:

- malformed and unauthorized contract tests from #34;
- concurrent/crash-recovery grant tests from #35;
- provider contract and license/notice checks from #36;
- reconnect/source-reuse/restart matrix from #37;
- use and atomic transfer tests from #39;
- two-client duplication, disconnect, restart and fuzz matrix from #40;
- provider-neutral export/import reconciliation with zero unexplained differences.

Any newly added inventory type or capability must update this model before implementation.
