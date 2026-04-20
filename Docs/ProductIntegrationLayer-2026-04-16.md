# Product Integration Layer, 2026-04-16

Formal status: completed formal protocol theorem.

This note records the first executable product-integration boundary around the
checked NumiSeal verification surface. A later April 16 pass added local
CLI/offline product controls documented in
`Docs/LocalProductControls-2026-04-16.md`: signed context packs, signed
provenance manifests, signed NumiSealZK side-channel certificates, SQLite
replay storage, hash-chained JSONL audit logs, and a machine-readable local
product-ops readiness status. This pass also separates revocation distribution
into a required signed revocation feed.
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
- provenance digest,
- recursive carry replay-binding digest for typed-required product carry, or
  `none` otherwise.

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
NumiSealZK policy. Signed side-channel certificates are optional release
metadata; when present, they are checked for release, context, leakage, proof
policy, Metal workspace, reviewed kernel, benchmark-report, and evidence-digest
bindings.
`product-status --format json` emits the canonical readiness status, and
`product-export-audit` embeds it as `operationsStatus`. The signed revocation
feed is verified independently from the context pack and its digest is recorded
in audit decisions.

Depth-1 typed recursive carry is now wired into the local product-control path:
`verify --product` accepts `--recursive-carry-parent` plus
`--recursive-carry-parent-provenance` for child artifacts with
`carryMode = "typed-required"`, verifies the parent product artifact and signed
parent provenance under the same signed context, requires the parent product
identity to already be present in the local replay ledger, reconstructs the child
carry parent from the child metadata, and binds the recursive carry context root,
replay root, parent artifact digest, parent proof-envelope digest, parent
provenance digest, parent accepted replay digest, consumer-session digest, next
recursion level, and claim count into JSONL audit records. SQLite also enforces
single-use acceptance for each recursive carry replay-binding digest. Parent
chains beyond one edge remain disabled here until the multi-depth theorem,
replay semantics, and loss accounting are closed.

## Remaining Product Responsibilities

The repository now has an executable integration contract and local CLI product
controls, but production deployment still requires product-owned completion for:

- Apple code signing, notarization, and release artifact publication,
- trusted key ceremony and distribution,
- operator-profile provisioning and hosted revocation feed distribution,
- authentication, authorization, and tenant isolation beyond the local OS-user
  model,
- hosted audit-log retention beyond the local hash-chain export and local
  retention policy,
- user-facing error and retry policy beyond the local CLI retry policy,
- side-channel evidence collection for each production hardware/profile lane,
- self-owned release review completion.

The product integration status is therefore repository-local production-ready:
the local repository supplies the integration-layer contract, local CLI control
substrate, and checked product/QROM, operations, total-loss,
release-distribution, and side-channel evidence manifests. External deployment
language still depends on deployed, reviewed release operations outside this
repository-local promotion gate.
