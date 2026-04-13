# Swift Wire Serialization Formal Slice

Formal status: conditional protocol formalization

This note records the April 14, 2026 concrete wire-format additions in
`Formal/SuperNeoFormal/Serialization.lean`.

## What closed

- Added fixed-width little-endian unsigned integer encoders for the Swift
  `UInt16`, `UInt32`, and `UInt64` surfaces used by proof serialization.
- Proved those encoders have the expected byte lengths and are injective.
- Added a 32-byte digest wire type and proved digest byte encoding is injective.
- Added canonical Goldilocks wire encoding through the existing Lean
  `Goldilocks = ZMod p` representation, with an injectivity theorem tied to
  canonical values below the Goldilocks modulus.
- Added Goldilocks extension-pair wire encoding matching Swift's
  `GoldilocksExt2` byte order.
- Added a fixed-width vector encoder and used it to formalize the Swift
  `CyclotomicRing54` coefficient byte order for degree-54 Phi81 coefficients.
- Added a proof-envelope transcript-binding context matching Swift's
  `transcriptBindingBytes` order:
  magic, version, profile id, proof kind, shape digest, statement digest,
  verifier-key digest, and transcript-domain digest.
- Proved the transcript-binding byte string has length 137 and is injective in
  its public context fields.

## Boundary kept explicit

This slice proves canonical byte layout and injectivity for concrete public wire
objects.  It does not prove SHA-256 collision resistance, Fiat-Shamir
random-oracle soundness, or parser totality for every Swift proof object.

## Verification

The declarations are tracked by `Docs/FormalStatus.json`, and the full formal
target builds with `lake build`.
