# Formal Completion Research Plan, 2026-04-14

Formal status: conditional protocol formalization.

This note turns the three remaining completion-blocker groups into concrete
closure contracts. It is intentionally a research and implementation plan, not a
status upgrade. The manifest should keep these groups `planned` until the
mechanized theorem statements, Swift conformance harnesses, and validation gates
below are all present.

## Current Blockers

The remaining planned groups are:

- `swift-goldilocks-ext2-serialization-equivalence`
- `swift-ce-verifier-byte-equivalence`
- `superneo-full-probability-composition`

The recommended order is the order above. The Ext2 serialization proof is the
narrowest byte-level obligation and unlocks the CE parser proof. The CE byte
proof then gives probability composition a concrete verifier event to compose,
instead of only the current abstract terminal CE trace.

## 1. Swift GoldilocksExt2 Serialization Equivalence

### Current surface

Lean already has the canonical Ext2 wire model in
`Formal/SuperNeoFormal/Serialization.lean`:

- `goldilocksExt2ElementWire`
- `goldilocksExt2ElementEncode`
- `goldilocksExt2ElementEncode_length`
- `goldilocksExt2ElementEncode_injective`

Swift currently serializes `GoldilocksExt2` in
`SuperNeo-NuMetal/Fields/GoldilocksField.swift` as:

- `c0.littleEndianBytes + c1.littleEndianBytes`
- decode from exactly 16 bytes, with `prefix(8)` as `c0` and `suffix(8)` as
  `c1`

`SuperNeo-NuMetal/SuperNeoSerialization.swift` exposes that path through
`GoldilocksExt2: SuperNeoByteEncodable` and `ByteReader.readGoldilocksExt2()`.
Callers include sum-check claimed sums, round coefficients, final points and
values, CCS evaluation-claim points, and `CyclotomicExt2Ring54` coefficient
surfaces.

### Why it remains blocked

The Lean model proves canonical byte layout and injectivity, but it does not yet
prove that the executable Swift encoder and parser are byte-for-byte equivalent
for all call sites. The gap is not the field algebra anymore. The gap is the
connection between the Swift implementation, the Lean byte grammar, and the
higher proof-object callers that transitively depend on Ext2 bytes.

### Progress after the first implementation pass

Lean now includes canonical Goldilocks and GoldilocksExt2 decoders alongside the
existing encoders. The checked surface includes Goldilocks canonical rejection
for 64-bit little-endian values greater than or equal to the modulus, exact
wrong-length rejection, and encode/decode round trips for `Goldilocks`,
`GoldilocksExt2Wire`, and concrete `GoldilocksExt2` values.

Swift tests now pin the executable `GoldilocksExt2` byte order to independent
little-endian fixtures for both coordinates, check non-canonical rejection in
`c0` and `c1`, and verify that `CyclotomicExt2Ring54`, `SumcheckProof`,
`CCSEvaluationClaim`, and `CEInstance` callers preserve the same `c0 || c1`
order in their byte layouts.

Lean now also has `SuperNeoFormal.Ext2CallerSerialization`, a caller-surface
grammar for counted Ext2 vectors, counted `CyclotomicExt2Ring54` vectors,
sum-check Ext2 rounds/proofs, and CCS/CE point-evaluation surfaces after their
opaque non-Ext2 prefixes. The manifest tracks this as the closed supporting
group `swift-ext2-caller-byte-surfaces`.

The production gate now runs `Scripts/validate-formal-ext2-serialization.py`
and `Scripts/test-formal-ext2-serialization-validation.py`. These checks tie
the Lean grammar, Swift `GoldilocksExt2` implementation, direct proof/public
readers, Ext2 ring caller layout, proof-object caller surfaces, and runtime
fixture test together, with mutation tests for swapped order, parser-width
drift, and caller-offset drift.

This is real progress toward the blocker, but not enough to close it. A full
closure still needs a mechanized Swift-behavior specification, or generated
single-source bridge, that proves the executable Swift implementation agrees
with the Lean grammar rather than only being source-validated and fixture-pinned.

### Closure target

The closure theorem group should establish all of the following:

- Swift `GoldilocksField.littleEndianBytes` equals Lean `goldilocksElementEncode`
  for canonical values.
- Swift `GoldilocksField(littleEndianBytes:)` accepts exactly canonical
  8-byte encodings and rejects wrong-length or non-canonical encodings.
- Swift `GoldilocksExt2.littleEndianBytes` equals Lean
  `goldilocksExt2ElementEncode`, including the `c0 || c1` order.
- Swift `GoldilocksExt2(littleEndianBytes:)` agrees with the Lean decoder on
  success and failure, including exact length behavior.
- Every Swift parser path using `readGoldilocksExt2()` is covered by a Lean
  grammar node or an explicitly documented non-formal caller.

A precise Lean theorem shape should be:

```lean
theorem swift_goldilocksExt2_encode_eq_lean
    (x : GoldilocksExt2) :
    SwiftGoldilocksExt2.encode x = goldilocksExt2ElementEncode x

theorem swift_goldilocksExt2_decode?_eq_lean
    (bytes : List Byte) :
    SwiftGoldilocksExt2.decode? bytes = goldilocksExt2ElementDecode? bytes

theorem swift_goldilocksExt2_roundTrip
    (x : GoldilocksExt2) :
    goldilocksExt2ElementDecode? (goldilocksExt2ElementEncode x) = some x
```

The `SwiftGoldilocksExt2.*` names above should be implemented as Lean
specifications of the Swift source behavior, not as imported trust assertions.

### Implementation sequence

Completed supporting steps:

1. Added Lean decoders for `Goldilocks` and `GoldilocksExt2` next to the
   existing encoders, reusing the fixed-width little-endian parser primitives in
   `Serialization.lean`.
2. Proved encode/decode round trips, exact accepted length, and exact rejection
   for non-16-byte Ext2 inputs and non-canonical base-field limbs.
3. Added Swift runtime fixtures for canonical and negative vectors covering:
   `GoldilocksField`, `GoldilocksExt2`, arrays of `GoldilocksExt2`,
   `CyclotomicExt2Ring54`, `SumcheckProof`, `CCSEvaluationClaim`, and
   `CEInstance` fragments that contain Ext2 values.
4. Recorded caller grammar coverage in the manifest as the closed supporting
   group `swift-ext2-caller-byte-surfaces`.
5. Added `superneo-formal-vectors ext2`, a Lean Ext2 vector emitter, an exact
   Swift/Lean vector comparator, comparator mutation tests, and production-gate
   integration.

Remaining closure steps:

1. Mechanize the executable Swift behavior model, or generate the Swift and Lean
   parser/encoder from a single source, so the theorem is about the actual
   implementation rather than source-shape validation plus fixtures.
2. Record declarations under `swift-goldilocks-ext2-serialization-equivalence`
   only after the executable Swift-behavior equivalence is mechanized.

### Acceptance criteria

- `lake build` checks the Ext2 encode/decode equivalence declarations.
- Swift tests include positive and negative Ext2 parser vectors.
- The production gate runs the Swift/Lean serialization-vector comparison.
- `Docs/FormalStatus.json` moves
  `swift-goldilocks-ext2-serialization-equivalence` from `planned` to `closed`
  only after the theorem declarations and validator are both present.

### Do not claim yet

Do not claim full proof serialization equivalence from this group alone. This
group closes the Ext2 field-element byte substrate and its direct callers. CE
proof parser equivalence is a separate larger obligation.

## 2. Swift CE Verifier Byte Equivalence

### Current surface

Swift proof bytes are defined in `SuperNeo-NuMetal/SuperNeoSerialization.swift`:

- `CEOpeningProof.superNeoBytes`
- `CEOpeningProofRound.superNeoBytes`
- `encodeCEOpeningResponse(tag:openings:)`
- `ByteReader.readCEOpeningProof(parameters:)`
- `ByteReader.readCEOpeningProofRound(parameters:)`
- `ByteReader.readCEOpeningProofResponse(expectedCount:)`

The response tag mapping is:

- `0`: mask opening
- `1`: masked-witness opening
- `2`: permuted-witness opening

The verifier path is in `SuperNeo-NuMetal/Protocols/SuperNeoProtocols.swift`,
through `CEOpeningRelation.verify` and the terminal local-batch verifier calls.

Lean currently models terminal CE proof soundness in
`Formal/SuperNeoFormal/TerminalCEFiniteSoundness.lean` using abstract verifier
traces:

- `TerminalCEVerifierTrace`
- `TerminalCEVerifierTraceAccepts`
- `TerminalCEFiniteBadSeedCertificate`
- `terminal_ce_relation_from_verified_proof_outside_badSeeds`

### Why it remains blocked

The Lean terminal CE theorem is sound for the modeled trace, but it does not
yet prove that Swift proof bytes parse into exactly that trace, or that the
Swift verifier branches match the Lean branch predicates. This is the largest
remaining trust boundary between implementation and formal statement.

### Progress after the CE byte-grammar pass

Lean now has `SuperNeoFormal.CEByteSerialization`, a byte grammar for the
Swift CE opening proof format. It fixes the 219-round proof count, three-digest
commitment order, response tags `0`, `1`, and `2`, Swift-accepted `Int` wire
bounds, linear and norm response payload vectors, response count framing, proof
rounds, and complete CE opening proofs. The tag layer is linked back to the
existing terminal CE challenge branch domain, and the grammar has checked
encode/decode round trips through the complete proof layer.

Swift now has a deterministic CE proof serialization fixture that constructs a
canonical 219-round proof cycling through all three response tags. The fixture
checks the raw tag bytes and parser round trip, then requires rejection for
wrong round count, unsupported tag, response count mismatch, truncated
commitment bytes, and trailing bytes.

The production gate now runs
`Scripts/validate-formal-ce-byte-serialization.py` and
`Scripts/test-formal-ce-byte-serialization-validation.py`. These checks pin the
Lean grammar to the Swift encoder/parser shape and include mutation tests for
round-count and response-tag drift.

This narrows the CE blocker, but does not close it. The missing theorem is
still the executable verifier-path connection: Swift acceptance of decoded CE
proof bytes must be related to the existing `TerminalCEVerifierTraceAccepts`
predicate and to the terminal CE finite bad-seed theorem.

### Closure target

This blocker should close only when the following equivalences are mechanized:

- Byte grammar equivalence for CE proof framing, round counts, commitment
  arrays, digest sizes, response tags, and response payload counts.
- Parser equivalence between Swift `ByteReader` behavior and Lean CE proof
  decoders, including failure cases for malformed length, invalid tag, truncated
  payload, excess trailing bytes, and wrong round count.
- Branch equivalence for the three challenge responses: mask,
  masked-witness, and permuted-witness.
- Transcript branch equivalence: the challenge byte or symbol absorbed by Swift
  selects the same Lean challenge branch for each round.
- Verifier equivalence: Swift acceptance of a byte string is equivalent to Lean
  acceptance of the decoded `TerminalCEVerifierTrace`, for all public statement
  fields covered by the grammar.

The proof should distinguish two layers:

```lean
theorem swift_ceProof_decode?_eq_lean
    (params : CEParserParameters) (bytes : List Byte) :
    SwiftCEProof.decode? params bytes = ceProofDecode? params bytes

theorem swift_ceVerifier_accepts_iff_traceAccepts
    (ctx : CEVerifierContext) (bytes : List Byte) (proof : CEProof) :
    ceProofDecode? ctx.params bytes = some proof ->
    SwiftCEVerifier.accepts ctx bytes =
      TerminalCEVerifierTraceAccepts (ceProofTrace ctx proof)
```

For soundness, the forward direction is the critical theorem. For public
trustworthiness, parser behavior should be proved both ways because malformed
bytes are where implementation drift most often hides.

### Implementation sequence

Completed supporting steps:

1. Added `SuperNeoFormal.CEByteSerialization` for the CE byte grammar.
2. Reused the closed serialization primitives for UInt counts, digests,
   Goldilocks, Ext2, and ring coefficients.
3. Added Lean decoders for CE opening commitments, response tags and payloads,
   proof rounds, and complete CE opening proofs.
4. Proved encode/decode round trips through the complete proof grammar.
5. Added a deterministic Swift CE fixture that exercises all three response
   branches and malformed proof classes.
6. Added a production-gate validator and mutation harness for CE proof byte
   grammar drift.
7. Added `superneo-formal-vectors ce`, a Lean CE vector emitter, an exact
   Swift/Lean complete-proof vector comparator, comparator mutation tests, and
   production-gate integration.

Remaining closure steps:

1. Prove that decoded Swift responses map to the same Lean branch predicates
   consumed by `TerminalCEVerifierTraceAccepts`.
2. Prove that Swift terminal CE verifier acceptance implies the existing Lean
   terminal CE acceptance predicate, then connect that theorem to
   `terminal_ce_relation_from_verified_proof_outside_badSeeds`.

### Acceptance criteria

- Lean has explicit parser and verifier-equivalence declarations tracked in the
  `swift-ce-verifier-byte-equivalence` theorem group.
- Swift test vectors cover all three response tags and malformed proof classes.
- The production gate fails on any drift in CE proof bytes, response tags,
  parser acceptance, or verifier branch selection.
- The group remains `planned` until byte parser equivalence and verifier-path
  equivalence are both mechanized.

### Do not claim yet

Do not treat the existing abstract `TerminalCEVerifierTrace` theorem as a
byte-for-byte Swift CE verifier proof. It is the semantic target for the future
proof, not the proof that the Swift parser and verifier already match it.

## 3. Full Cryptographic Probability Composition

### Current surface

The repo now has finite bad-event surfaces for each protocol layer:

- PiRLC: `PiRLCFiniteBadSeedCertificate` and
  `pirlc_allInputsSound_of_seed_not_bad` in
  `Formal/SuperNeoFormal/PiRLCFiniteSoundness.lean`
- PiCCS/sum-check: `PiCCSFiniteBadChallengeCertificate` and
  `piccs_traceSound_of_seed_not_bad` in
  `Formal/SuperNeoFormal/PiCCSFiniteSoundness.lean`
- Sum-check prefix events: `sumcheckPrefixBadChallenges` and
  `sumcheckPrefixBadChallengeBudget_card_le` in
  `Formal/SuperNeoFormal/SumcheckPrefixSoundness.lean`
- Terminal CE: `TerminalCEFiniteBadSeedCertificate` and
  `terminal_ce_relation_from_verified_proof_outside_badSeeds` in
  `Formal/SuperNeoFormal/TerminalCEFiniteSoundness.lean`
- Composition: `superneo_end_to_end_outside_ce_badSeeds` in
  `Formal/SuperNeoFormal/Composition.lean`
- Tagged event composition:
  `SuperNeoBadEvent`, `superNeoBadEventsAggregate`,
  `superneo_aggregateBadEvents_card_le`, and
  `superneo_outsideAggregate_stage_not_bad` in
  `Formal/SuperNeoFormal/ProbabilityComposition.lean`
- Abstract error ledger:
  `SuperNeoErrorBudget`, `SuperNeoComponentErrorBounds`, and
  `superneo_errorBudget_union_bound` in
  `Formal/SuperNeoFormal/ErrorLedger.lean`

### Progress after the tagged bad-event pass

Lean now has `SuperNeoFormal.ProbabilityComposition`, a deliberately finite
and distribution-free aggregation layer. It tags the PiRLC, PiCCS/sum-check,
terminal CE, and transcript bad-event sets into one disjoint event type, proves
the aggregate cardinality is bounded by the sum of the four stage cardinalities,
and proves that being outside the aggregate tagged set implies being outside
each contributing stage set.

The manifest tracks this as the closed supporting group
`superneo-tagged-bad-event-composition`. The supporting
`sumcheck-prefix-bad-challenge-composition` and
`superneo-error-ledger-composition` groups are also closed: they provide the
finite per-round sum-check bad-challenge aggregate and the abstract union-bound
ledger.

Lean now also has `SuperNeoFormal.TranscriptProbability`, tracked as the closed
supporting group `superneo-fiat-shamir-finite-seed-accounting`. This defines a
finite transcript-seed product for the PiRLC, PiCCS, terminal-CE, and
transcript-byte components, exposes the stage projection maps, proves
projection-support membership, proves generic fiber-preimage cardinality
bounds, and records rational probability numerator/denominator definitions,
including a profile-factor denominator formula.

The same module also closes the supporting group
`superneo-fiat-shamir-stage-event-bridge`: outside the finite
Fiat-Shamir-preimage bad-seed union, every projected stage seed is outside its
stage bad set, and the existing `superneoOutsideAggregate` predicate follows for
the projected stage-seed tuple.

The true blocker `superneo-full-probability-composition` remains planned because
this is still finite accounting below the executable transcript schedule. It
does not mechanize SHA-256 as a random oracle, prove Swift transcript bytes
project to these stage seeds, or connect the rational budget into the abstract
error ledger.

### Why it remains blocked

The current composition theorem consumes the terminal CE bad-seed certificate
but does not yet aggregate all PiRLC, PiCCS, transcript, and terminal CE finite
bad events into one end-to-end soundness theorem. The tagged aggregate and
finite seed product close only the finite-union and projection bookkeeping. The
checked seed product is not yet proved to be the implemented sampled transcript
schedule. Collapsing it into an end-to-end denominator without modeling the
Swift Fiat-Shamir derivation behavior and exact fibers would overclaim.

### Closure target

The probability proof should have two explicit layers:

1. A finite bad-event composition theorem over tagged stage events.
2. A probability theorem over the actual transcript seed distribution, after
   proving the maps from transcript material to stage challenges have the
   required support and preimage bounds.

The first layer can be closed conservatively with a tagged event type:

```lean
inductive SuperNeoBadEvent
| pirlc : PiRLCChallengeSeed count -> SuperNeoBadEvent
| piccs : Seed -> SuperNeoBadEvent
| terminalCE : Seed -> SuperNeoBadEvent
| transcript : TranscriptSeed -> SuperNeoBadEvent

def SuperNeoBadEvents.aggregate
    (pirlc : Finset (PiRLCChallengeSeed count))
    (piccs : Finset Seed)
    (terminalCE : Finset Seed)
    (transcript : Finset TranscriptSeed) :
    Finset SuperNeoBadEvent := ...

theorem superneo_aggregateBadEvents_card_le :
    aggregate.card <=
      pirlc.card + piccs.card + terminalCE.card + transcript.card
```

The second layer should be proved only after common transcript-domain maps are
formalized:

```lean
structure TranscriptStageProjection where
  transcriptSeed : Type
  pirlcSeed : transcriptSeed -> PiRLCChallengeSeed count
  piccsSeed : transcriptSeed -> Seed
  terminalCESeed : transcriptSeed -> Seed
  pirlcFiberBound : ...
  piccsFiberBound : ...
  terminalCEFiberBound : ...

theorem superneo_full_probability_bound :
    Pr[accepts bad statement] <=
      pirlcBudget / pirlcSupport
      + piccsBudget / piccsSupport
      + terminalCEBudget / terminalCESupport
      + transcriptCollisionBudget / transcriptSupport
```

The exact rational expression should be derived from the mechanized support
sizes and fiber bounds, not inserted as a paper claim.

### Implementation sequence

1. Closed supporting layer: `SuperNeoFormal.ProbabilityComposition` defines
   tagged aggregate bad-event sets for PiRLC, PiCCS, terminal CE, and transcript
   failure events.
2. Closed supporting layer: `SuperNeoFormal.SumcheckPrefixSoundness` composes
   per-round low-degree agreement sets into a finite prefix bad-challenge set.
3. Closed supporting layer: Lean proves the aggregate `Finset` cardinality bound
   using only finite union/cardinality facts. It does not require independence.
4. Closed supporting layer: `SuperNeoFormal.ErrorLedger` proves that component
   probability bounds imply a summed aggregate budget under an abstract
   probability model with union bounds.
5. Next: prove an end-to-end "outside all tagged bad events" theorem that
   combines:
   - `pirlc_allInputsSound_of_seed_not_bad`
   - `piccs_traceSound_of_seed_not_bad`
   - `terminal_ce_relation_from_verified_proof_outside_badSeeds`
   - the deterministic composition theorem
6. Closed supporting layer: `SuperNeoFormal.TranscriptProbability` defines a
   finite transcript-seed product, projection maps, projection supports, generic
   preimage/fiber bounds, and rational numerator/denominator accounting.
7. Closed supporting layer: the finite bad transcript-seed preimage union now
   implies the existing tagged outside-aggregate predicate for projected stage
   seeds.
8. Next: connect the finite seed product to the implemented Fiat-Shamir
   transcript schedule, including the exact Swift transcript bytes and the
   transcript-to-stage projection behavior.
9. Next: prove support membership and exact preimage/fiber bounds for those
   implemented projections. If a projection is not injective, carry its exact
   fiber multiplier into the final bound.
10. Next: convert the finite bad-event count into a rational probability bound
   over the checked transcript seed distribution and feed that into the error
   ledger.
11. Add manifest declarations only when the final theorem states the actual
   denominator, numerator, and all transcript/projection side conditions.

### Acceptance criteria

- Lean proves a single aggregate bad-event count from the stage certificates.
  This is now partially satisfied by the closed supporting group
  `superneo-tagged-bad-event-composition`, but not by an end-to-end probability
  theorem.
- Lean proves that verifier acceptance outside the aggregate bad set implies the
  composed soundness target.
- Lean proves the final probability bound from a formal transcript seed
  distribution and checked support/fiber bounds.
- No independence assumption is introduced unless it is explicitly formalized
  and used by name.
- The manifest moves `superneo-full-probability-composition` to `closed` only
  after the theorem states the end-to-end probability numerator and denominator
  in terms of mechanized profile constants.

### Do not claim yet

Do not claim a full cryptographic probability theorem from the current finite
bad-seed composition alone. The current theorem is valuable, but it is a
conditional outside-bad-set statement. The final probability theorem must also
mechanize how the implemented transcript schedule samples, maps, and bounds the
bad events.

## Cross-Cutting Validation Gates

The completion pass should extend `Scripts/production-gate.sh` with these
checks as they become available:

- Swift/Lean Ext2 serialization-vector comparison.
- Swift/Lean CE proof parser-vector comparison.
- CE verifier branch-selection vector comparison.
- CE verifier branch-selection vector comparison. The CE proof parser-vector
  comparison is already in the production gate; verifier transcript branch
  selection remains separate.
- Formal status validation that rejects any completion-label upgrade until all
  three groups are `closed`.
- Regression mutations that change an Ext2 byte order, CE response tag, CE
  round count, or probability budget constant and require validation failure.

## Manifest Discipline

Until these closure contracts are satisfied, the correct public status remains
`conditional protocol formalization`. The completed theorem label should remain
blocked by:

- `swift-goldilocks-ext2-serialization-equivalence`
- `swift-ce-verifier-byte-equivalence`
- `superneo-full-probability-composition`

The next highest-leverage engineering pass is the Ext2 serialization
equivalence pass, because it is narrow, testable, and needed by the CE byte
grammar.
