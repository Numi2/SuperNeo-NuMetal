# Product Integration Layer, 2026-04-16

Formal status: completed formal protocol theorem.

This note records the first executable product-integration boundary around the
checked NumiSeal verification surface. A later April 16 pass added local
CLI/offline product controls documented in
`Docs/LocalProductControls-2026-04-16.md`: signed context packs, signed
provenance manifests, signed NumiSealZK side-channel certificates, SQLite
replay storage, and hash-chained JSONL audit logs.
Neither pass is a hosted verifier service or a complete production
certification.

## Implemented Boundary

`SuperNeoNumiSealProductVerifier` wraps `NumiSealArtifactVerifier.verify` with
product-owned hooks that run before accepted verification is reported:

- `SuperNeoNumiSealExpectedContextStore` loads trusted
  `NumiSealArtifactExpectedContext` from product storage instead of trusting the
  artifact.
- `SuperNeoProductAuthorizer` authorizes the caller against the expected
  context identifier before provenance and algebraic verification.
- `SuperNeoArtifactProvenanceVerifier` verifies product provenance over the raw
  artifact digest and returns a provenance digest to bind into replay identity.
- `SuperNeoReplayLedger` rejects identities that were already accepted and
  records the identity only after successful NumiSeal verification.
- `SuperNeoVerificationAuditSink` receives accepted and rejected decisions with
  caller, expected-context identifier, artifact digest, optional proof-envelope
  digest, optional provenance digest, and rejection reason.

The replay identity binds:

- expected context identifier,
- statement digest,
- proof-envelope digest,
- raw artifact digest, and
- provenance digest.

The facade also enforces product-level artifact byte limits before proof body
parsing.

## Validation

Focused XCTest coverage verifies that the facade:

- accepts a checked NumiSeal vector through all integration hooks,
- records accepted replay identity and audit output,
- fails closed on authorization rejection before provenance is accepted,
- rejects a previously accepted identity before repeated algebraic verification,
  and
- fails closed on product artifact byte-limit violations before proof-envelope
  parsing.

Command:

```sh
swift test --filter NumiSealCanonicalizationTests/testNumiSealProductVerifier
```

Result: passed locally.

## Local CLI Product Controls

The CLI now has a product-control mode:

```sh
superneo verify --product --operator-profile profile.json proof.json
```

This path verifies the signed trusted context before artifact parsing, verifies
signed provenance before algebraic acceptance, rejects replay through a durable
SQLite ledger, and appends accepted/rejected decisions to a hash-chained JSONL
audit log. It covers terminal, compressed-terminal, NumiSeal terminal, and
NumiSealZK product surfaces. For `numiseal-zk`, the trusted context must include
NumiSealZK policy. Optional signed side-channel certificates can be supplied as
release metadata and are checked for release, context, leakage, proof policy,
Metal workspace, reviewed kernel, and evidence-digest bindings when present.

## Remaining Product Responsibilities

The repository now has an executable integration contract and local CLI product
controls, but production deployment still requires product-owned completion for:

- Apple code signing, notarization, and release artifact publication,
- trusted key ceremony and distribution,
- operator-profile provisioning and revocation distribution,
- authentication, authorization, and tenant isolation beyond the local OS-user
  model,
- hosted audit-log retention beyond the local hash-chain export,
- user-facing error and retry policy,
- side-channel evidence collection for each production hardware/profile lane,
- self-owned release review completion.

The product integration blocker is therefore narrowed: the local repository no
longer lacks an integration-layer contract or local CLI control substrate, but
production-security language still requires deployed, reviewed release
operations and the remaining formal and side-channel blockers.
