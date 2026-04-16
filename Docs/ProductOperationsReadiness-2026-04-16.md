# Product Operations Readiness, 2026-04-16

Formal status: local product-ops surface for operator lifecycle and release
evidence. It is not a hosted service and it does not claim production hardware
side-channel clearance.

## Surface

`SuperNeoProductOperationsStatus` format version `2` is the canonical status
document for the local product-control layer. `product-status --format json`
selects the machine-readable mode. `superneo product-status` still prints a
concise human-readable report by default, and:

```sh
superneo product-status --operator-profile profile.json --format json
```

emits the same status as sorted JSON. `product-export-audit` embeds that status
as `operationsStatus`, so audit exports carry the active operator lifecycle
state alongside the hash-chained records.

## Readiness States

The top-level `readiness` field is one of:

- `ready`: all local checks are currently green.
- `attention-required`: verification may still be possible, but an operator
  action is needed before a production-security release.
- `blocked`: local acceptance must stop until the listed remediation is handled.

Each status document includes typed checks with an ID, check status, detail, and
optional remediation. The current checks cover:

- audit log hash-chain validity,
- trusted-context expiry,
- issuer key rotation staging,
- signed revocation feed freshness, digest, sequence, and active-context
  revocation,
- NumiSealZK side-channel certificate attachment,
- default artifact provenance path availability, and
- audit export pressure for large local JSONL logs.

## Retention And Retry Policy

`auditRetentionPolicy` is deliberately explicit: local JSONL audit state must be
exported as a hash-chained JSON snapshot before local log rotation. Hosted
retention remains operator-owned until a deployed product-control layer exists.

`retryPolicy` is also explicit. Operators should retry only after refreshing
signed context, provenance, revocation feed, storage, or certificate material.
Replay rejections require a new proof identity; rerunning the same accepted
proof is expected to fail.

## Revocation Distribution

`SuperNeoSignedRevocationFeed` is required local product-control input. Its
payload binds the context ID, release build digest, sequence, issue and expiry
timestamps, and revoked context/artifact/proof/provenance digests. Product
verification uses the union of embedded context revocation metadata and the
signed revocation feed. `revocationFeedDigestHex` is emitted in
`SuperNeoProductOperationsStatus` and in audit decisions, so operators can prove
which feed was active for an accepted or rejected proof.

## Gate

`Scripts/validate-product-ops-surface.py` checks that the Swift surface, CLI
JSON mode, audit export binding, docs, release policy, and production gate stay
in sync. `Scripts/test-product-ops-surface-validation.py` mutation-tests the
validator so missing CLI text, missing gate wiring, implicit trust-root
fallbacks, and outsourced-review language are rejected.

This closes another local E2E operations gap: operators can now inspect and
export a machine-readable lifecycle state and a signed revocation feed binding
instead of inferring readiness from scattered CLI lines.
