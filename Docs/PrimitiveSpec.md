# SuperNeo Primitive Spec

This file is the working cryptographic spec for core development. It should stay
short enough that an external cryptographer can read it before looking at code.

## Goal

SuperNeo proves that a committed witness satisfies a CCS/R1CS-derived relation
over the Goldilocks field and the Phi81 cyclotomic ring profile used by this
repository. The daily implementation target is:

- deterministic encoding of the public statement,
- domain-separated transcripts,
- canonical proof-envelope serialization,
- verifier rejection of malformed or mismatched artifacts,
- stable test vectors for accepted proof kinds.

This is not a production-security claim.

## Parameters

- Base field: Goldilocks, modulus `2^64 - 2^32 + 1`.
- Ring profile: `Phi81(d=54)`.
- Default source decomposition/opening profile: `pay-per-bit-v1`.
- Default development workload examples: one-hot vector and binary addition.

Parameter changes must be reviewed as cryptographic changes. A parameter check is
useful only if it catches an invalid field/ring profile, an unsupported proof
shape, or a verifier acceptance bug.

## Statement Binding

A proof binds:

- proof kind,
- parameter profile,
- shape digest,
- public statement digest,
- verifier key digest,
- transcript domain,
- public inputs,
- exact proof-envelope body length.

The verifier must reject any artifact where JSON metadata and envelope contents
disagree.

## Transcript Design

Transcripts are append-only byte strings with domain-separated frames. Challenge
derivation must never depend on ambiguous string concatenation or host JSON
ordering. Every challenge family needs a stable label that identifies the
protocol stage and proof kind.

Transcript changes require negative tests that show swapped labels, swapped
statements, or mismatched public inputs are rejected.

## Canonical Serialization

Serialization is part of the primitive. Integers, field elements, ring elements,
digests, lengths, and proof-envelope headers must have one accepted encoding.

The verifier must reject:

- unknown proof-envelope versions or kinds,
- non-canonical field encodings,
- malformed length prefixes,
- trailing bytes,
- truncated envelopes,
- JSON metadata that contradicts envelope context.

## Attack Workflow

Development should ask:

- Can a malformed proof verify?
- Can JSON metadata steer verification away from the envelope context?
- Can a transcript label collision or statement swap preserve acceptance?
- Can a non-canonical encoding round-trip into an accepted object?
- Can a public input, shape, or verifier-key digest be swapped?

Run:

```sh
Scripts/check-smoke.sh
Scripts/check-crypto-dev.sh
Scripts/fuzz-malformed-artifacts.sh
Scripts/test-slice.sh protocol
Scripts/test-slice.sh attack
```

These checks are useful because they exercise proof construction, verifier
acceptance, serialization, and adversarial mutations.

## Non-Goals During Core Development

Do not block development on:

- wording validation,
- release-readiness packets,
- benchmark coverage manifests,
- QROM accounting manifests,
- conformance-scope manifests,
- production promotion flags.

Those artifacts are quarantined under `Scripts/legacy-gates/` and can be
revived later if they serve a concrete review or release need.
