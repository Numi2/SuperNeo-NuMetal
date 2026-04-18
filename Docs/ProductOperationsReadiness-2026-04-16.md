# Product Operations Readiness - 2026-04-16

This note records the local product-ops surface consumed by the release and
total-loss evidence manifests. It documents the shipped operator controls, not
a production security promotion.

## Local product-ops surface

The local product-ops surface is centered on `SuperNeoProductOperationsStatus`.
The status snapshot is produced from a verified signed trusted context, the
effective signed revocation feed, the replay ledger, and the JSONL audit log.

Operators inspect the surface with:

```sh
superneo product-status --operator-profile profile.json --format json
```

The short form `product-status --format json` names the same JSON status view
when the operator profile is supplied by the surrounding runbook. Local CLI
commands also discover a default operator profile from `SUPERNEO_OPERATOR_PROFILE`
or `.superneo/operator-profile.json`.

The JSON response includes `operationsStatus`, `readiness`, `checks`,
`revocationFeedDigestHex`, `auditRetentionPolicy`, and `retryPolicy`.

## Signed revocation feed

Revocation updates are represented by `SuperNeoSignedRevocationFeed`. The feed
is verified against the trusted revocation issuer set in the local operator
profile, merged with the trusted-context revocation block, and then applied to
context IDs, artifact digests, proof-envelope digests, and provenance digests.

The feed digest is exposed as `revocationFeedDigestHex` so product runs can bind
the status snapshot to the exact revocation state used for acceptance.

## Replay and Audit State

The replay ledger records accepted proof identities under the H_bind-derived
local replay digest. Recursive carry consumption also records the carry replay
binding digest so duplicate carry consumption fails closed.

The audit log is append-only JSONL with a chained record digest. The status
surface exports the current chain state, record count, `operationsStatus`,
`auditRetentionPolicy`, and `retryPolicy` so release tooling can detect missing
or stale operational state before a product claim is considered.

## Readiness Meaning

`readiness` is `ready` only when the local context pack, provenance roots,
revocation feed, replay database, and audit log are all internally consistent
for the current operator profile. `attention-required` means the operator must
repair or refresh local state before relying on product-mode acceptance.

For trusted contexts that accept `numiseal-zk`, readiness does not require a
side-channel certificate. The `sideChannelCertificateStatus` field records
whether optional release metadata is attached, and supplied certificates are
checked by product verification for context, release, leakage, proof-policy,
Metal workspace, benchmark-report, and evidence bindings.

This document closes the product operations readiness evidence artifact
referenced by the total-loss budget. It does not instantiate the hosted replay
freshness loss, and it does not close the remaining side-channel,
release-distribution, or total-loss numeric terms.
