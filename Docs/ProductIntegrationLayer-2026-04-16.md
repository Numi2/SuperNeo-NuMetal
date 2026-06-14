# Product Context Integration, 2026-04-16

Formal status: completed formal protocol theorem.

This is the concise product-context binding note. The selected architecture is
the QRO path in `Docs/QROProductArchitecture-2026-04-25.md`.

## Product Context Inputs

Product-context verification uses:

- signed trusted context pack,
- signed provenance manifest,
- signed issued-QRO challenge pack,
- signed revocation feed,
- replay ledger,
- hash-chained audit log,
- optional signed NumiSealZK side-channel certificate.

Raw QRO flags are accepted only by local/dev non-product verification.

## Accepted Product Proof

Product-context NumiSeal acceptance is `proofKind = "numiseal-zk"` with
`artifactVersion = 2`. Non-ZK terminal artifacts are local/dev diagnostics and
are rejected by product-context verification.

The verifier checks:

- trusted context and public inputs,
- signed issued-QRO pack against context, statement, verifier key, transcript
  domain, validity window, and single-use policy,
- source fold envelope under the QRO-derived source-fold challenge,
- `sourceDecompositionProfile = "pay-per-bit-v1"`,
- recomposed source output-claim digests,
- NumiSealZK terminal envelope under the QRO-derived transcript domain,
- public statement roots, aggregate digests, component roots, CTCO/QROM metadata,
- optional side-channel certificate binding when supplied or required by policy,
- recursive carry parent/provenance when `carryMode = "typed-required"`.

## Replay And Audit Surface

`product-status --format json` emits `operationsStatus`. `product-export-audit`
embeds that status and validates the local hash-chained audit log. The replay
identity binds context, statement, proof envelope, artifact, provenance,
issued-QRO digest, and recursive carry replay binding when present.
