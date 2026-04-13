# Artifact Duplicate-Key Hardening, 2026-04-13

This pass closes a parser-ambiguity gap in the CLI artifact boundary. Proof
artifacts are JSON, and duplicate object member names can be interpreted
differently by different parsers or tooling layers. For cryptographic artifacts,
that ambiguity is unacceptable even when later digest and envelope checks would
usually catch semantic drift.

## Change

`superneo verify` and `superneo inspect` now scan the raw artifact bytes before
normal JSON decoding and reject duplicate object keys anywhere in the artifact,
including nested `workloadParameters`.

The scanner also rejects malformed JSON syntax before `JSONDecoder` or
`JSONSerialization` receives the object. This preserves the existing strict
checks for:

- known top-level artifact fields,
- exact workload-parameter key sets,
- canonical workload-parameter decimal strings,
- public-input agreement,
- proof-envelope header agreement, and
- trusted verifier context supplied with strict verification arguments.

## Gate Coverage

`Scripts/production-gate.sh` now mutates release CLI artifacts and requires
verification failure for:

- a duplicate top-level `profile` key, and
- a duplicate nested `workloadParameters.publicSum` key.

These checks sit next to the existing unknown-field, missing-parameter,
non-canonical-parameter, trusted-context mismatch, and terminal-proof-requirement
negative tests.

## Trust Boundary

This does not change cryptographic parameters, transcript domains, proof-envelope
serialization, verifier-key derivation, or statement construction. It only makes
the artifact ingestion grammar fail closed before cryptographic verification
starts.
