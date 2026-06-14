# Swift Wire Serialization Formal Slice

Formal status: completed formal protocol theorem.

This note records the April 14, 2026 concrete wire-format additions in
`Formal/SuperNeoFormal/Serialization.lean`.

## What closed

- Added fixed-width little-endian unsigned integer encoders for the Swift
  `UInt16`, `UInt32`, and `UInt64` surfaces used by proof serialization.
- Proved those encoders have the expected byte lengths and are injective.
- Added finite parsers for fixed-width little-endian integers and byte vectors,
  with checked encode/decode round-trip theorems.
- Bridged the abstract transcript `Count64LE` bytes to the concrete Swift
  `UInt64` little-endian encoding, with a checked decode round trip for
  count values produced from `UInt64`.
- Added a 32-byte digest wire type and proved digest byte encoding is injective.
- Added canonical Goldilocks wire encoding through the existing Lean
  `Goldilocks = ZMod p` representation, with an injectivity theorem tied to
  canonical values below the Goldilocks modulus.
- Added Goldilocks canonical wire decoding, including encode/decode round trip,
  wrong-length rejection, and rejection for 64-bit little-endian values greater
  than or equal to the Goldilocks modulus.
- Added Goldilocks extension-pair wire encoding and decoding, with a Lean bridge
  from the concrete `GoldilocksExt2` structure to `c0 || c1` byte order and an
  exact 16-byte decode round trip.
- Added a fixed-width vector encoder and used it to formalize the Swift
  `CyclotomicRing54` coefficient byte order for degree-54 Phi81 coefficients.
- Added a fixed-width vector decoder with encode/decode round-trip and
  wrong-length rejection theorems.
- Added a `Phi81Ext2Coefficients` wire grammar for `CyclotomicExt2Ring54`:
  degree-54 contiguous `GoldilocksExt2` coefficients, exact
  `phi81Degree * 16` byte length, injective encoding, exact decode round trip,
  and wrong-length rejection.
- Added a proof-envelope transcript-binding context matching Swift's
  `transcriptBindingBytes` order:
  magic, version, profile id, proof kind, shape digest, statement digest,
  verifier-key digest, and transcript-domain digest.
- Proved the transcript-binding byte string has length 137 and is injective in
  its public context fields.
- Added a checked parser for that 137-byte transcript binding.  Lean now proves
  that encoding then decoding recovers the full context, and that any successful
  parse has the exact binding length, magic value, and version bytes.
- Added `SuperNeoFormal.CEByteSerialization`, a dedicated CE opening proof byte
  grammar. It models Swift's 226-round CE proof count, digest-triple
  commitments, response tags `0`, `1`, and `2`, Swift-accepted `Int` wire
  values, linear and norm response payload vectors, response count framing,
  proof rounds, and complete CE opening proof byte strings.
- Proved CE byte-grammar encode/decode round trips for commitments, linear
  responses, norm responses, tagged proof responses, proof rounds, and complete
  CE opening proofs. The response tag layer is also linked to the existing
  terminal CE challenge-branch domain.
- Added `SuperNeoFormal.Ext2CallerSerialization`, a caller-surface grammar for
  the Swift proof objects that carry Ext2 values: counted Ext2 vectors, counted
  `CyclotomicExt2Ring54` vectors, sum-check Ext2 rounds/proofs, and CCS/CE
  point-evaluation surfaces after opaque non-Ext2 prefixes.
- Proved round-trip parser facts for counted Ext2 vectors, counted
  `CyclotomicExt2Ring54` vectors, and sum-check Ext2 rounds. The larger
  variable-length proof-object parsers are present as grammar nodes. The later
  formal cleanup connects the theorem-facing Swift/Lean byte and CE branch
  equivalence surfaces through the closed formal-status groups.

## Boundary kept explicit

This slice proves canonical byte layout and injectivity for concrete public wire
objects, exact Goldilocks/GoldilocksExt2 decode round trips, round-trip parsing
for the proof-envelope transcript-binding prefix, a Lean CE opening proof byte
grammar, and Lean Ext2 caller-surface grammar nodes for higher proof objects.
The current theorem path extends this with well-formed transcript injectivity,
384-bit proof-envelope binding, typed digest-domain separation, and the
closed Swift/Lean CE verifier-byte equivalence surface. It does not prove
SHA-256 collision resistance, Fiat-Shamir random-oracle soundness, or a
production QROM theorem.

## Verification

The declarations are tracked by `Docs/FormalStatus.json`, and the full formal
target builds with `lake build`. `Scripts/legacy-gates/validate-formal-ext2-serialization.py`
checks the Lean Ext2 and Phi81/Ext2 coefficient grammars against the Swift
encoder/parser shape, direct 16-byte reader call sites, Ext2 ring caller layout,
Ext2 caller-surface grammar, and the independent Swift runtime fixture test.
`Scripts/legacy-gates/validate-formal-ce-byte-serialization.py`
checks the CE byte grammar against Swift CE proof encoding/parsing and the
all-tags parser fixture. Both mutation harnesses are part of the production
gate.
