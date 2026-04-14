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

1. Add a Lean decoder for `GoldilocksExt2` next to the existing encoder.
   Reuse the fixed-width little-endian parser primitives already in
   `Serialization.lean`.
2. Prove encode/decode round trips, exact accepted length, and exact rejection
   for non-16-byte inputs.
3. Add a Swift fixture generator or validator that emits canonical and negative
   vectors for:
   - `GoldilocksField`
   - `GoldilocksExt2`
   - arrays of `GoldilocksExt2`
   - `CyclotomicExt2Ring54`
   - sum-check and CCS evaluation-claim fragments that contain Ext2 values
4. Add a repository script that compares the Swift vectors against the Lean
   specification outputs. This is not a theorem by itself, but it gives CI a
   drift detector while the theorem group is being completed.
5. Record caller coverage in the manifest by adding declarations for each
   parser or object grammar that depends on Ext2 bytes.

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

1. Define Lean CE byte grammar types in or near
   `TerminalCEFiniteSoundness.lean`, or split a new
   `SuperNeoFormal.CEByteSerialization` module if the parser grows too large.
2. Reuse the closed serialization primitives for UInt counts, digests,
   Goldilocks, Ext2, and ring coefficients.
3. Add Lean decoders for:
   - CE opening commitments
   - CE opening response tags and payloads
   - CE opening rounds
   - complete CE opening proofs
4. Prove encode/decode round trips and exact failure behavior for each grammar
   layer.
5. Add a Swift CE fixture generator with:
   - one valid proof per response branch
   - malformed tag vectors
   - wrong round count
   - truncated digest, ring, and response payload vectors
   - extra trailing-byte vectors
6. Add a validator that compares Swift parser outcomes against the Lean grammar
   fixtures.
7. Prove that decoded Swift responses map to the same Lean branch predicates
   consumed by `TerminalCEVerifierTraceAccepts`.
8. Prove that Swift terminal CE verifier acceptance implies the existing Lean
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

- PiRLC: `PiRLCBadSeedCertificate` and
  `pirlc_allInputsSound_of_seed_not_bad` in
  `Formal/SuperNeoFormal/PiRLCFiniteSoundness.lean`
- PiCCS/sum-check: `PiCCSBadChallengeCertificate` and
  `piccs_traceSound_of_seed_not_bad` in
  `Formal/SuperNeoFormal/PiCCSFiniteSoundness.lean`
- Terminal CE: `TerminalCEFiniteBadSeedCertificate` and
  `terminal_ce_relation_from_verified_proof_outside_badSeeds` in
  `Formal/SuperNeoFormal/TerminalCEFiniteSoundness.lean`
- Composition: `superneo_end_to_end_outside_ce_badSeeds` in
  `Formal/SuperNeoFormal/Composition.lean`

### Why it remains blocked

The current composition theorem consumes the terminal CE bad-seed certificate
but does not yet aggregate all PiRLC, PiCCS, transcript, and terminal CE finite
bad events into one end-to-end probability statement. Also, the bad-event sets
do not all currently live in the same seed space. Some are challenge seeds, some
are trace seeds, and some are proof seeds. Collapsing them into one denominator
without modeling the Fiat-Shamir derivation maps and their fibers would
overclaim.

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

def SuperNeoBadEvents.aggregate
    (pirlc : Finset (PiRLCChallengeSeed count))
    (piccs : Finset Seed)
    (terminalCE : Finset Seed) :
    Finset SuperNeoBadEvent := ...

theorem superneo_aggregateBadEvents_card_le :
    aggregate.card <= pirlc.card + piccs.card + terminalCE.card
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

1. Add a `SuperNeoFormal.ProbabilityComposition` module or extend
   `Composition.lean` if the declarations remain small.
2. Define tagged aggregate bad-event sets for PiRLC, PiCCS, terminal CE, and
   transcript-domain failure events.
3. Prove union/cardinality lemmas using only `Finset` cardinality and the union
   bound. Do not require independence.
4. Prove an end-to-end "outside all tagged bad events" theorem that combines:
   - `pirlc_allInputsSound_of_seed_not_bad`
   - `piccs_traceSound_of_seed_not_bad`
   - `terminal_ce_relation_from_verified_proof_outside_badSeeds`
   - the deterministic composition theorem
5. Define the common transcript seed domain and projection maps used by the
   implemented Fiat-Shamir schedule.
6. Prove support membership and preimage/fiber bounds for each projection.
   If a projection is not injective, carry its exact fiber multiplier into the
   final bound.
7. Convert the finite bad-event count into a rational probability bound over
   the uniform transcript seed distribution.
8. Add manifest declarations only when the final theorem states the actual
   denominator, numerator, and all transcript/projection side conditions.

### Acceptance criteria

- Lean proves a single aggregate bad-event count from the stage certificates.
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
