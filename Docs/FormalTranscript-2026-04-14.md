# Transcript Absorption Formal Slice

Formal status: conditional protocol formalization.

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
- Added `transcriptAbsorbFrames` for a whole ordered frame sequence, with
  singleton, append, frame-list, and byte-append laws.
- Proved transcript initialization is injective at the structured level, so
  changing the domain or seed changes the initialized transcript state.
- Added length-counted transcript frames: for payloads whose length fits in
  `UInt64`, Lean proves the frame count bytes are exactly Swift's little-endian
  payload length and the transcript bytes are `len(domain) || domain ||
  len(seed) || seed`.
- Connected proof-envelope transcript-binding bytes to transcript
  initialization: Lean now exposes the first payload, proves it decodes back to
  the public envelope context, and proves context changes are injective through
  transcript initialization when counts and seed are fixed.
- Added `proofEnvelopeTranscriptWithAbsorbs`, so proof-envelope context, seed,
  and a full ordered absorb sequence are modeled together before challenge
  derivation.
- Added the proof-envelope length-counted initialization theorem, so the
  checked 137-byte binding payload is recovered even when transcript counts are
  generated from concrete payload lengths.
- Added an abstract `ChallengeDeriver` and proved challenge consistency when
  prover and verifier have equal structured transcripts or equal absorbed
  payloads.
- A follow-up `SuperNeoFormal.TranscriptChallenge` module now connects that
  deriver to Phi81 and PiRLC challenge seeds, proving deterministic transcript
  equality, proof-envelope context/seed/ordered-absorbs equality,
  finite-support membership, coefficient bounds, and strong-sampling-capacity
  reuse.

## Boundary kept explicit

This is not a Fiat-Shamir proof and does not model SHA-256 as a random oracle.
It proves deterministic transcript-state consistency for the ordered absorption
surface, including the proof-envelope binding payload.  Challenge uniformity,
random-oracle programming, and full byte-level Swift compatibility for every
serialized proof object remain separate formal work.

## Verification

The module builds as part of `lake build`, and the declaration group is tracked
by `Docs/FormalStatus.json`.
