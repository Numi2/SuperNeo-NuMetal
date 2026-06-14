# Local Product Context Binding - 2026-04-16

This note records the local context, replay, and audit bindings used by
product-mode verification and `product-status --format json`.

## Local Context State

The product-status command reports local context state from the signed context
pack, signed revocation feed, replay ledger, and audit log. The JSON payload
contains `operationsStatus`, `auditRetentionPolicy`, and `retryPolicy`; treat it
as local verifier state, not a release-readiness signal.
CLI product-control commands discover the operator profile from
`SUPERNEO_OPERATOR_PROFILE` or `.superneo/operator-profile.json` when
`--operator-profile` is omitted.

If the signed context accepts `numiseal-zk`, certificates remain optional local
context metadata for default `correctness-only` contexts.
Stricter trusted contexts can require a certificate; when supplied, product
verification checks certificate context, leakage, proof policy, Metal workspace,
and binding digests before acceptance.

## Signed Revocation Feed

The signed revocation feed is checked against the trusted revocation issuer
digests in the operator profile. It can revoke contexts, artifacts,
proof-envelope digests, and provenance digests before product-mode acceptance.

## Replay and Audit Controls

Accepted product proofs are recorded in the replay database under an
H_bind-derived replay identity. Recursive carry metadata is bound into that
identity when present. For NumiSealZK product-control verification, the verifier
public coin must be issued through a signed
`SuperNeoSignedQROChallengePack`; raw QRO CLI fields are not a product-control
input. The signed pack binds context ID, frontend-context digest, verifier key,
shape, statement, public inputs, transcript domain, validity window, and
single-use policy. Its payload digest is bound into the replay identity, and the
SQLite ledger enforces `accepted_issued_qro_challenges` single-use acceptance
even if a different artifact/provenance pair attempts to replay the same issued
public coin.

The audit log records accepted and rejected decisions, including issued-QRO and
QRO challenge digests when present, and exports chain status through
`operationsStatus`.
