# Serialization Framing Formal Slice

Formal status: conditional protocol formalization.

This note records the April 14, 2026 framed-byte serialization work in
`Formal/SuperNeoFormal/Serialization.lean`.

## What closed

- Added a concrete formal byte type, `Byte = Fin 256`.
- Added an eight-byte little-endian count-field type, `Count64LE = Fin 8 ->
  Byte`, matching the fixed-width count surface used by Swift framing helpers.
- Proved the count-field byte encoding has length 8 and is injective.
- Defined a framed byte object with one tag byte, one count field, and a payload.
- Proved the frame header length is 9 bytes.
- Proved `frameEncode` is injective: equal encoded frames imply equal tag,
  count field, and payload.
- Added domain, payload, and proof-envelope header tag constants with explicit
  disjointness theorems.
- Proved domain-tagged first-frame transcripts cannot equal payload-tagged
  first-frame transcripts.

## Boundary kept explicit

This is a byte-framing theorem, not a random-oracle or Fiat-Shamir theorem.  It
does not claim SHA-256 collision resistance, transcript challenge uniformity, or
byte-for-byte compatibility for every Swift serialization type.  Those remain
future work under the transcript and Fiat-Shamir boundary.

## Verification

The module builds as part of `lake build`, and the declaration group is tracked
by `Docs/FormalStatus.json`.
