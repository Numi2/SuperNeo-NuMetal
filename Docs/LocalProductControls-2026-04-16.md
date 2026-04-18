# Local Product Controls - 2026-04-16

This note pins the local controls used by product-mode verification and
`product-status --format json`.

## Operations Readiness

The product-status command reports operations readiness from the signed context
pack, signed revocation feed, replay ledger, and audit log. The JSON payload
contains `operationsStatus`, `auditRetentionPolicy`, and `retryPolicy` so a
runbook can decide whether local state is ready or attention is required.
CLI product-control commands discover the operator profile from
`SUPERNEO_OPERATOR_PROFILE` or `.superneo/operator-profile.json` when
`--operator-profile` is omitted.

If the signed context accepts `numiseal-zk`, readiness does not require a
side-channel certificate. Certificates are optional release metadata; when
supplied, product verification checks their context, release, leakage, proof
policy, Metal workspace, and evidence bindings.

## Signed Revocation Feed

The signed revocation feed is checked against the trusted revocation issuer
digests in the operator profile. It can revoke contexts, artifacts,
proof-envelope digests, and provenance digests before product-mode acceptance.

## Replay and Audit Controls

Accepted product proofs are recorded in the replay database under an
H_bind-derived replay identity. Recursive carry metadata is bound into that
identity when present. The audit log records accepted and rejected decisions and
exports chain status through `operationsStatus`.
