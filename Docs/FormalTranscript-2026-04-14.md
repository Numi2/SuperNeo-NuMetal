# Transcript Absorption Formal Slice

Formal status: conditional protocol formalization

This note records the April 14, 2026 transcript absorption work in
`Formal/SuperNeoFormal/Transcript.lean`.

## What closed

- Added a formal `TranscriptFrame` matching Swift's absorb shape: an eight-byte
  count prefix followed by a payload.
- Proved single-frame transcript encoding length and injectivity.
- Added `TranscriptState` as an ordered list of absorbed frames.
- Modeled Swift transcript initialization as two ordered absorbs: domain
  separator, then seed.
- Modeled later absorption as appending one frame to the ordered transcript.
- Proved frame-count and byte-append laws for absorption.
- Proved two consecutive absorbs preserve order.
- Proved transcript initialization is injective at the structured level, so
  changing the domain or seed changes the initialized transcript state.
- Added an abstract `ChallengeDeriver` and proved challenge consistency when
  prover and verifier have equal structured transcripts or equal absorbed
  payloads.

## Boundary kept explicit

This is not a Fiat-Shamir proof and does not model SHA-256 as a random oracle.
It proves deterministic transcript-state consistency for the ordered absorption
surface.  Challenge uniformity, random-oracle programming, and full byte-level
Swift compatibility for every serialized object remain separate formal work.

## Verification

The module builds as part of `lake build`, and the declaration group is tracked
by `Docs/FormalStatus.json`.
