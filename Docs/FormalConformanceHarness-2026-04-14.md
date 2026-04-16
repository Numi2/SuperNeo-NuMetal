# Formal Conformance Harness Progress, 2026-04-14

Formal status: completed formal protocol theorem.

This pass adds a drift check between the implemented Swift profile and the Lean
formal constants.

## Added scripts

- `Scripts/validate-formal-profile-constants.py`
  - Compares the Lean Goldilocks modulus against `GoldilocksField.modulus`.
  - Compares Lean `phi81Degree` against `CyclotomicRing54.degree` and Swift
    `ringDegree`.
  - Compares Lean `phi81Index`, `kappa`, `normBound`,
    `decompositionLength`, `challengeExpansionFactor`, `freshBatchCount`, and
    `paperClaimThresholdBits` against the Swift profile.
  - Checks Swift `maxPriorClaimCount` stays tied to Lean
    `decompositionLength`.
  - Compares the Lean challenge coefficient set against Swift
    `challengeCoefficients`.
  - Compares Lean proof-envelope magic, version, proof-kind tags, and
    transcript-binding byte length against `ProofEnvelopeHeader` and
    `ProofEnvelopeKind`.

- `Scripts/test-formal-profile-constants-validation.py`
  - Runs the validator against the repository.
  - Mutates a temporary Lean `kappa` constant and requires validation failure.
  - Mutates a temporary Lean challenge coefficient set and requires validation
    failure.
  - Mutates temporary Lean proof-envelope magic, transcript-binding length, and
    proof-kind tags and requires validation failure.

- `Scripts/validate-formal-ext2-serialization.py`
  - Checks the Lean Goldilocks/GoldilocksExt2 decoder declarations are present.
  - Checks Lean Ext2 wire encoding and decoding stay in `c0 || c1` order.
  - Checks the Lean `SuperNeoFormal.Ext2CallerSerialization` caller-surface
    grammar is present and imported by the top-level formal target.
  - Checks Swift `GoldilocksExt2` encoding, decoding, `SuperNeoByteEncodable`,
    proof-body `ByteReader`, public CCS reader, and `CyclotomicExt2Ring54`
    caller layouts stay tied to exact 16-byte Ext2 chunks.
  - Checks the Swift runtime fixture test pins independent `c0` and `c1`
    little-endian bytes, non-canonical rejection in both coordinates,
    `CyclotomicExt2Ring54`, `SumcheckProof`, `CCSEvaluationClaim`, and
    `CEInstance` caller offsets.

- `Scripts/test-formal-ext2-serialization-validation.py`
  - Runs the Ext2 serialization validator against the repository.
  - Mutates temporary Lean and Swift Ext2 byte order, parser chunk width,
    caller-surface imports, caller grammar, and fixture offset surfaces and
    requires validation failure.

- `Scripts/compare-formal-ext2-vectors.py`
  - Runs the executable Swift vector tool and the Lean Ext2 vector emitter.
  - Compares canonical Goldilocks, GoldilocksExt2, caller-surface, and negative
    parser vectors exactly by label.

- `Scripts/test-formal-ext2-vector-bridge.py`
  - Mutation-tests missing labels, duplicate labels, unexpected labels, and
    byte drift in the Ext2 vector comparator.

- `Scripts/validate-formal-ce-byte-serialization.py`
  - Checks the Lean `SuperNeoFormal.CEByteSerialization` declarations are
    present and imported by the top-level formal target.
  - Checks Lean CE response tags stay mapped to `0`, `1`, and `2` and to the
    modeled terminal CE challenge branches.
  - Checks Lean CE proof grammar fixes the 219-round count, three-digest
    commitments, Swift-accepted `Int` wire bounds, response count framing, and
    proof-level counted round vector.
  - Checks Swift `CEOpeningProof` serialization and `ByteReader` parsing keep
    the same round count, tag mapping, digest ordering, positive commitment
    count, response count equality, and unsupported-tag rejection.
  - Checks the Swift runtime fixture pins all three response tags and malformed
    proof classes.

- `Scripts/test-formal-ce-byte-serialization-validation.py`
  - Runs the CE byte serialization validator against the repository.
  - Mutates temporary Lean and Swift CE round-count, response-tag, parser-tag,
    and fixture surfaces and requires validation failure.

- `Scripts/compare-formal-ce-vectors.py`
  - Runs the executable Swift vector tool and the Lean CE vector emitter.
  - Compares all three response branches, round widths, complete 219-round
    proof bytes, and parser rejection statuses exactly by label.

- `Scripts/test-formal-ce-vector-bridge.py`
  - Mutation-tests missing labels, duplicate labels, unexpected labels, and
    byte drift in the CE vector comparator.

- `Formal/ProofImportWall.lean`
  - Scans theorem-facing Lean modules and fails if they import generated,
    golden, regression, or executable vector-check evidence modules.

- `Formal/SuperNeoFormalVectorCheck.lean`
  - Runs executable Lean predicates over representative GoldilocksExt2,
    sum-check caller-surface, CE response, CE round, and parser-rejection
    fixtures.

- `Formal/lakefile.lean`
  - Exposes `proof_import_wall` and `vector_check` build targets. The
    `vector_check` target runs the Lean predicate runner through the
    interpreter to avoid a native-link dependency on the full transitive theorem
    graph.

- `Scripts/validate-formal-status.py`
  - Declaration scanning now includes Lean names ending in `?`, so parser
    declarations such as `proofEnvelopeTranscriptBindingDecode?` are checked
    by the manifest instead of silently falling outside the harness.

## Gate integration

`Scripts/production-gate.sh` now runs both the profile-constant validator and
its mutation tests after the Lean build and formal-status validation. It also
runs the proof import wall, executable Lean vector predicates, Ext2
serialization conformance validator, the CE opening byte serialization
validator, the Swift/Lean Ext2 and CE vector comparators, and all associated
mutation tests, so byte-order, parser-width, proof-module dependency,
round-count, response-tag, or executable/vector drift fails the release gate
before public claims can move forward.

## What remains open

The validator catches profile constant drift, but it is still a comparison
harness rather than a single-source generator. A later pass can move both Swift
and Lean constants to a generated source derived from one checked JSON profile.
