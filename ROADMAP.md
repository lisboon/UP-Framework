# UP roadmap

UP is a foundation under active development. This roadmap describes the shortest path to a testable server baseline; it does not claim production or commercial readiness. GitHub issues are the source of truth for implementation details.

## P3 — Entry Foundation Closure

[Milestone](https://github.com/lisboon/UP-Framework/milestone/1) · [tracking epic #43](https://github.com/lisboon/UP-Framework/issues/43)

Execute in this order:

1. Stabilize Entry state recovery ([#11](https://github.com/lisboon/UP-Framework/issues/11)), then isolate voice with two-client evidence ([#10](https://github.com/lisboon/UP-Framework/issues/10)).
2. Persist the appearance contract ([#25](https://github.com/lisboon/UP-Framework/issues/25)) and consume it in preview ([#18](https://github.com/lisboon/UP-Framework/issues/18)); persist authoritative last location ([#26](https://github.com/lisboon/UP-Framework/issues/26)).
3. Add FXServer boot smoke ([#27](https://github.com/lisboon/UP-Framework/issues/27)) and client-backed E2E evidence ([#28](https://github.com/lisboon/UP-Framework/issues/28)).
4. Finish operator tooling ([#29](https://github.com/lisboon/UP-Framework/issues/29), [#30](https://github.com/lisboon/UP-Framework/issues/30)) and publish the immutable foundation baseline last ([#32](https://github.com/lisboon/UP-Framework/issues/32)).

Exit gate: all P1 issues closed with green CI; real-client evidence attached; Entry authority, cleanup and voice isolation verified; recipe and dependency references immutable.

## P4 — Playable Inventory Slice

[Milestone](https://github.com/lisboon/UP-Framework/milestone/2) · [tracking epic #44](https://github.com/lisboon/UP-Framework/issues/44)

Start only after #11 closes. Decide the provider and license boundary first ([ADR-0001](docs/adr/0001-inventory-provider-boundary.md), [#33](https://github.com/lisboon/UP-Framework/issues/33)), then implement the provider-neutral UP contract ([#34](https://github.com/lisboon/UP-Framework/issues/34)), transactional persistence ([#35](https://github.com/lisboon/UP-Framework/issues/35)), the isolated Ox bridge ([#36](https://github.com/lisboon/UP-Framework/issues/36)) and lifecycle recovery ([#37](https://github.com/lisboon/UP-Framework/issues/37)). Add the bounded catalog/starter slice ([#38](https://github.com/lisboon/UP-Framework/issues/38)), secure use/transfer ([#39](https://github.com/lisboon/UP-Framework/issues/39)) and finish with restart, concurrency and two-client qualification ([#40](https://github.com/lisboon/UP-Framework/issues/40)). The security assumptions and required evidence are maintained in the [inventory threat model](docs/security/inventory-threat-model.md).

Exit gate: two spawned players retain inventory through reconnect and restart, starter grants are exactly-once, transfers cannot duplicate items, first-party resources do not call Ox directly, and money remains a separate future ledger.

## Later, non-blocking work

- Appearance editor provider: [#41](https://github.com/lisboon/UP-Framework/issues/41)
- Dynamic property spawn contract: [#42](https://github.com/lisboon/UP-Framework/issues/42)

## Verification before a release

```powershell
go test ./...
go build ./cmd/upctl
go run ./cmd/upctl doctor --path .
go run ./cmd/upctl doctor --path . --json
docker compose -f infra/compose.dev.yml config
```

The repository checks are necessary but not sufficient: the milestone also requires the FXServer and real-client evidence identified by `needs: fxserver` and `needs: two-clients` labels.
