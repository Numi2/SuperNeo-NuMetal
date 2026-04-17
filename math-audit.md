# Formal Lean Math Audit for SuperNeo / NumiSeal

Date: 2026-04-17

This audit classifies the current Lean files into four buckets:

1. **Substantive mechanized mathematics**: real algebra / arithmetic / encoding / finite-cardinality results.
2. **Substantive but incomplete proof pipelines**: real lower-level mathematics plus missing construction theorems.
3. **Finite deterministic bookkeeping**: finite bad-set and seed-space accounting without full probability/QROM semantics.
4. **Theorem surfaces / evidence shells**: acceptance-gate / evidence-parametric wrappers, not cryptographic proofs.

## Bucket A — substantive mechanized mathematics

These files contain real mathematics that should be preserved and extended, not rewritten:

- `Profile.lean`
- `Goldilocks.lean`
- `GoldilocksExt2.lean`
- `Phi81.lean`
- `Embedding.lean`
- `Multilinear.lean`
- `Ajtai.lean`
- `ConcreteAjtai.lean`
- `Serialization.lean`
- `Transcript.lean`
- `CEByteSerialization.lean`
- `Ext2CallerSerialization.lean`
- `ChallengeSampling.lean`
- `CCSSemantics.lean`
- `PiDEC.lean`
- `PiDECSoundness.lean`
- `Sumcheck.lean`
- `SumcheckSoundness.lean`
- `SumcheckPrefixSoundness.lean`
- `CEOpeningRelation.lean`
- `NumiSealSumcheckTranscript.lean`

### Audit verdict

These are the strongest part of the current formal layer. They already give:

- concrete field/ring instantiation,
- concrete quotient-ring multiplication shape,
- exact pack/unpack and coefficient-bound preservation,
- framed encoding injectivity and transcript ordering facts,
- exact-oracle sum-check semantics,
- low-degree root-counting over finite supports,
- deterministic recomposition facts for PiDEC,
- witness uniqueness under no-short-kernel,
- and concrete challenge-space / support accounting.

### Required upgrades

1. Add `phi81CoeffsToQuotient_injective` and `phi81ChallengeElement_injective`.
2. Replace all theorem-surface digest placeholders of type `Nat` with typed digest wires.
3. Add explicit canonical-representative lemmas for degree-`< 54` quotient representatives.
4. Add a theorem that framed transcript schedules used by product / carry / ZK are injective as full structured encodings, not just frame-local.

## Bucket B — substantive but incomplete proof pipelines

These files contain real mathematical ingredients, but the critical constructive step is still missing:

- `Phi81Split.lean`
- `PiRLCSoundness.lean`
- `PiRLCFiniteSoundness.lean`
- `PiCCSSoundness.lean`
- `PiCCSFiniteSoundness.lean`
- `TerminalCEFiniteSoundness.lean`
- `CertifiedAjtai.lean`
- `ModuleSIS.lean`

### Audit verdict

The mathematics here is not fake, but it stops one layer too early.

#### `Phi81Split.lean`

The factorization theorem is real and useful. The current `Phi81SplitCertificate` is not enough for the theorem program because it only packages two zero-separating maps `Phi81 -> Goldilocks`. That is not the right algebraic object for the state-of-the-art PiRLC collision argument.

**Direction**: replace the certificate by a concrete CRT decomposition:

- define `R_left := F_q[X] / (X^27 - a)`,
- define `R_right := F_q[X] / (X^27 + b)`,
- define a ring homomorphism `Phi81 ->+* R_left × R_right`,
- prove injectivity via coprimality / CRT,
- then do the collision argument componentwise in the factor fields.

If the factors are irreducible, prove `Field R_left` and `Field R_right`. If not, prove enough unit / integral-domain structure for the root-counting step actually used.

#### `PiRLCFiniteSoundness.lean`

This file currently names a bad-seed certificate but does not construct one from the split algebra. The current theorem chain does not yet prove a concrete collision-set bound from the actual `Phi81` challenge distribution.

**Direction**: add a new file `PiRLCConcreteCollision.lean` that:

- instantiates the CRT split,
- proves that a nonzero folded-difference has a nonzero component in one factor,
- fixes one pivot challenge,
- shows at most one bad pivot value per fixed remaining challenges in the active factor,
- lifts this to an exact finite bad-seed count over the actual challenge support.

#### `PiCCSFiniteSoundness.lean`

This file packages the right bad-challenge interface, but it still asks for a certificate instead of constructing the bad set from the low-degree mismatch theorem already available in `SumcheckPrefixSoundness.lean`.

**Direction**: replace the certificate-first interface by a constructive theorem:

`PiCCSBadChallengeSetConstructed` proving
`badSeeds.card <= numVars * maxDegreePerRound`.

#### `TerminalCEFiniteSoundness.lean`

This is still an extraction-certificate shell. It does not build the three-branch Stern extractor or the per-round bad-seed set.

**Direction**: define the exact round grammar and extractor semantics, then prove:

- 3-accepting-branch extraction for one round,
- product extraction for the selected round subset,
- exact bad-seed bound for the concrete CE proof schedule.

#### `CertifiedAjtai.lean` and `ModuleSIS.lean`

These are certificate / parameter wrappers, not hardness proofs.

**Direction**:

- keep them,
- but do not let them stand in for an instantiated lattice reduction theorem,
- and add an explicit distinction between a checked verifier-key certificate and an actual reduction-backed security theorem.

## Bucket C — finite deterministic bookkeeping, not probability/QROM theorems

These files are honest but still below real cryptographic probability theorems:

- `ProbabilityComposition.lean`
- `TranscriptProbability.lean`
- `ErrorLedger.lean`
- parts of `Composition.lean`

### Audit verdict

The finite set/cardinality work is useful, but the layer still stops before actual probability and before any QROM semantics. These files should never be cited as if they already prove negligible failure probabilities.

### Required upgrades

1. Add a concrete finite-uniform probability model and prove `Pr[event] = |event| / |support|`.
2. Connect `TranscriptProbability.lean` to that model.
3. Replace `AbstractProbabilityModel` in `ErrorLedger.lean` with either:
   - a concrete finite-uniform model for ROM-level theorems, or
   - a genuine oracle-game model for QROM-level theorems.
4. Add a tagged-bad-event union ledger, so the same underlying cryptographic event is not flat-summed multiple times.

## Bucket D — theorem surfaces / evidence shells

These files are not cryptographic proofs. They are theorem interfaces.

- `NumiSealEndToEnd.lean`
- `RecursiveFoldingKnowledge.lean`
- `NumiSealTypedCarryTheorem.lean`
- `NumiSealZKPrivacy.lean`
- `NumiSealProductTheorem.lean`
- `ProductSecurityTheorem.lean`
- `ConstantTime.lean`

### Audit verdict

These files are structurally honest: they say they depend on evidence. That is good. But mathematically they are mostly `Prop`-gated composition shells. They should not be described as completed cryptographic proofs.

### Required upgrades

1. Keep them as top-level interfaces.
2. Rename any claim path that could be misread as a completed theorem.
3. Move the real mathematics below them into new concrete modules.
4. Add explicit “assumption instantiated / not instantiated” fields for every imported theorem obligation.

## Mandatory new modules

### 1. `Phi81CRT.lean`

Must provide the actual algebraic split used by the PiRLC soundness theorem:

- factor quotient rings,
- CRT homomorphism,
- injectivity,
- unit/nonzero transfer,
- factor-field or domain structure.

### 2. `PiRLCConcreteCollision.lean`

Must replace certificate-style PiRLC finite soundness by a concrete bad-seed construction and bound.

### 3. `PiCCSConstructiveFiniteSoundness.lean`

Must construct the global bad-challenge set from the per-round low-degree mismatch theorem.

### 4. `TerminalCEConcreteSpecialSoundness.lean`

Must define the actual CE opening round grammar and prove the concrete extractor / bad-seed theorem.

### 5. `FiniteUniformProbability.lean`

Must turn all current bad-set cardinality results into real probabilities.

### 6. `ProductBadEventLedger.lean`

Must tag shared bad events and prevent double charging across fold / terminal / product / carry / ZK layers.

### 7. `TypedDigestSemantics.lean`

Must replace theorem-surface `Nat` digests by byte-typed digests with explicit framed encodings.

## Immediate decisions for developers

1. Do **not** promote `NumiSeal*Theorem.lean` or `ProductSecurityTheorem.lean` as completed cryptographic proofs.
2. Do **not** keep `Phi81SplitCertificate` as the end state. Replace it by actual CRT decomposition.
3. Do **not** keep `PiRLCFiniteSoundness`, `PiCCSFiniteSoundness`, or `TerminalCEFiniteSoundness` in certificate-only form.
4. Do **not** keep `ErrorLedger.lean` abstract if the goal is an actual budget theorem.
5. Keep and extend the arithmetic / quotient-ring / serialization / sum-check core. That part is real and should become the foundation of the stronger theorem program.

## File-by-file high-level verdict

- `Profile.lean` — solid constants / inequalities.
- `Goldilocks.lean` — solid primality / field instantiation.
- `GoldilocksExt2.lean` — solid quadratic extension instantiation.
- `Phi81.lean` — solid quotient-ring / coefficient multiplication model.
- `Embedding.lean` — solid exact packing / unpacking.
- `Multilinear.lean` — solid multilinear basis / interpolation.
- `Ajtai.lean` — solid abstract commitment linear algebra.
- `ConcreteAjtai.lean` — solid specialization to Phi81.
- `Serialization.lean` — solid injective wire encoding core.
- `Transcript.lean` — solid framed transcript append model, but no hash theorem.
- `CEByteSerialization.lean` — solid wire grammar work.
- `Ext2CallerSerialization.lean` — solid caller-side wire grammar work.
- `ChallengeSampling.lean` — solid finite support / bound work.
- `CCSSemantics.lean` — solid algebraic CCS semantics.
- `PiDEC.lean` — solid recomposition skeleton.
- `PiDECSoundness.lean` — solid additional recomposition / signed limb bounds.
- `Sumcheck.lean` — solid verifier skeleton.
- `SumcheckSoundness.lean` — solid exact-oracle theorem + low-degree root counting.
- `SumcheckPrefixSoundness.lean` — solid finite bad-prefix aggregation.
- `CEOpeningRelation.lean` — solid local relation / uniqueness under no-short-kernel.
- `TerminalCE.lean` — relation / assumption shell.
- `TerminalCEFiniteSoundness.lean` — incomplete certificate shell; must be constructive.
- `PiRLC.lean` — mixed: algebraic recomposition is real, soundness remains abstract.
- `PiRLCSoundness.lean` — mixed: finite bad-seed framework is real, concrete collision theorem missing.
- `PiRLCFiniteSoundness.lean` — incomplete certificate shell; must be constructive.
- `Phi81Split.lean` — factorization theorem is real; split object is not yet the right theorem object.
- `PiCCS.lean` — verifier skeleton / assumption shell.
- `PiCCSSoundness.lean` — real exact-oracle bridge.
- `PiCCSFiniteSoundness.lean` — incomplete certificate shell; must be constructive.
- `ProbabilityComposition.lean` — finite union-cardinality bookkeeping only.
- `TranscriptProbability.lean` — finite seed-space bookkeeping only.
- `ErrorLedger.lean` — abstract probability shell only.
- `Composition.lean` — mostly deterministic composition plus imported assumptions.
- `CertifiedAjtai.lean` — certificate wrapper, not hardness proof.
- `ModuleSIS.lean` — parameter wrapper, not reduction proof.
- `NumiSealSumcheckTranscript.lean` — good transcript schedule scaffold.
- `RecursiveFoldingKnowledge.lean` — theorem surface only.
- `NumiSealEndToEnd.lean` — theorem surface only.
- `NumiSealTypedCarryTheorem.lean` — theorem surface only.
- `NumiSealZKPrivacy.lean` — theorem surface only.
- `NumiSealProductTheorem.lean` — composition surface only.
- `ProductSecurityTheorem.lean` — top-level evidence-parametric shell only.
- `ConstantTime.lean` — constant-trace schedule model only, not a whole-stack CT proof.

