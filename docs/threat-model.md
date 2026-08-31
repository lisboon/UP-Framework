# Threat model

## Trust boundaries

The client and NUI are hostile inputs. They may request an action but never decide its price, reward, permission, ownership, or final state. Cross-resource calls are accepted only through registered, versioned contracts.

## Minimum controls

- Validate type, length, range, ownership, proximity, and current state on the server.
- Rate-limit callback routes independently per player.
- Use parameterized SQL and transactions for multi-step mutations.
- Keep economy operations idempotent with immutable ledger identifiers.
- Record privileged actions and value transfers in an append-only audit trail.
- Never log database passwords, license keys, tokens, or raw identifiers.
- Default-deny administrative permissions and use ACE as an emergency override.

## Release gates

A premium release requires abuse tests for replay, duplicate requests, negative values, unauthorized identifiers, disconnect during transaction, and resource restart. High-value operations require a rollback/reconciliation procedure.
