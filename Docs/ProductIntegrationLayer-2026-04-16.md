# Product Integration Layer, 2026-04-16

Formal status: conditional protocol formalization.

This note records the first executable product-integration boundary around the
checked NumiSeal verification surface. It is a library contract for product
services; it is not durable storage, a hosted verifier, a signing system, or a
production deployment.

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

## Remaining Product Responsibilities

The repository now has an executable integration contract, but production
deployment still requires product-owned implementations for:

- durable expected-context storage,
- trusted key distribution and rotation,
- artifact signing and provenance roots,
- race-safe replay ledger semantics,
- authentication, authorization, and tenant isolation,
- persistent verification records,
- structured audit-log transport and retention,
- user-facing error and retry policy, and
- incident response, revocation, and provenance rollback hooks.

The product integration blocker is therefore narrowed: the local repository no
longer lacks an integration-layer contract, but production-security language
still requires deployed, reviewed implementations of those protocols.
