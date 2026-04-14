# Vector Manifest Duplicate-Key Hardening, 2026-04-14

## Finding

`superneo verify` and `superneo inspect` already rejected duplicate JSON object
member names before decoding proof artifacts, but `Scripts/validate-test-vectors.swift`
still decoded the vector manifest and checked-in artifacts through standard JSON
parsers first. That left the public vector corpus with a parser-ambiguity gap:
two tools could disagree on which duplicate trust-metadata member was effective.

## Work

- Added the duplicate-key JSON scanner to `Scripts/validate-test-vectors.swift`.
- Scanned `TestVectors/manifest.json` before manifest decoding.
- Added exact manifest top-level and per-vector key allowlists before manifest
  decoding so `JSONDecoder` cannot silently ignore unexpected trust metadata.
- Scanned each manifest-listed artifact before `JSONSerialization` top-level
  key checks or `JSONDecoder` artifact decoding.
- Kept byte count and SHA-256 checks as the first artifact-integrity gate, then
  applied the duplicate-key grammar gate before semantic artifact parsing.
- Extended `Scripts/test-vector-manifest-validation.py` to mutation-test:
  - duplicate manifest entries,
  - duplicate raw manifest JSON keys,
  - unknown raw manifest top-level and per-vector keys,
  - duplicate strict verification commands,
  - missing required proof-kind coverage,
  - unmanifested checked vector files, and
  - duplicate nested artifact JSON keys after updating the temporary manifest
    hash and byte count so the duplicate-key scanner is the failing check.

## Boundary

This does not change proof artifacts, transcript domains, cryptographic
parameters, verifier-key derivation, statement construction, or proof-envelope
serialization. It only makes vector-corpus ingestion fail closed before parser
ambiguity can affect trusted metadata.

## Validation

- `swift Scripts/validate-test-vectors.swift`
- `Scripts/test-vector-manifest-validation.py`
