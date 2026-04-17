# Formal Lean Math Audit for SuperNeo / NumiSeal


# SuperNeo / NumiSeal formal audit addendum

Date: 2026-04-17

This addendum audits the newly provided Lean modules:

- `Serialization.lean`
- `Sumcheck.lean`
- `SumcheckSoundness.lean`
- `SumcheckPrefixSoundness.lean`
- `TerminalCE.lean`
- `TerminalCEConcreteSpecialSoundness.lean`
- `TerminalCEFiniteSoundness.lean`
- `Transcript.lean`
- `TranscriptChallenge.lean`
- `TranscriptProbability.lean`
- `TypedDigestSemantics.lean`
- `VectorChecks.lean`

## Executive decision

The transcript/sum-check core is mathematically strong and should be preserved. The CE stack is partially upgraded but still stops short of a concrete end theorem. The typed-digest layer is structurally useful but too small and too untyped for theorem-critical QROM binding under the pinned `Q_H = 2^64` policy.

The immediate mandatory changes are:

1. Add a well-formed transcript type or predicate and prove full transcript-byte injectivity on well-formed states.
2. Generalize theorem-critical digests from 256 bits to 384 bits and make typed digests parameterized by digest width and domain family.
3. Replace `TerminalCEFiniteSoundness` certificate budgets with a constructive bad-seed theorem tied to real parser/extractor semantics.
4. Use `SumcheckSoundness` + `SumcheckPrefixSoundness` as the source of constructive bad-set proofs for PiCCS, not as a separate disconnected layer.
5. Connect `TranscriptProbability` to a reusable finite-uniform probability theorem and then to the selected-depth loss ledger.

## File-by-file decisions

### `Serialization.lean`

Approved as core. It contains real injectivity results for framed bytes, fixed-width integers, digest wires, field wires, Ext2 wires, and proof-envelope transcript binding encodings.

Decision:
- Keep all current theorems.
- Add `Digest384Wire`, `digest384Encode`, `digest384Decode?`, and 384-bit variants of proof-envelope binding records.
- The theorem-critical path must stop using raw 256-bit digest wires as the final acceptance comparator.

### `Transcript.lean`

Strong deterministic transcript layer, but the theorem-critical object is not yet the correct one. The file proves injectivity for single frames and for `proofEnvelopeTranscriptInit` context decoding, but `TranscriptState` itself allows arbitrary `(count, payload)` pairs. That means the generic `transcriptBytes` function is not the correct canonical theorem object for full transcript injectivity.

Decision:
- Keep the current file.
- Add `WellFormedTranscriptFrame` and `WellFormedTranscriptState` or replace the public theorem-facing state type with a length-counted transcript type.
- Prove:
  - `transcriptFramesBytes_injective_of_wellFormed`
  - `transcriptBytes_injective_of_wellFormed`
  - domain separation and proof-kind separation for well-formed transcript families.
- All QROM/compiler theorems must quantify only over well-formed transcripts.

### `TranscriptChallenge.lean`

Approved as a deterministic schedule bridge. It is correctly modest: it gives equality and support-membership facts, not a random-oracle theorem.

Decision:
- Keep it.
- Extend it to the split-oracle architecture: `H_chal` seed derivation and deterministic challenge-tape expansion for CTCO.
- Add theorem families for the single-seed challenge tape rather than legacy many-round schedules.

### `TranscriptProbability.lean`

This file is better than a pure interface. It already defines a finite seed product domain, projection fibers, exact denominators, exact numerators, and a rational probability definition for the classical finite-seed model.

Decision:
- Promote it, but finish it.
- Add a reusable theorem saying the probability is exactly `badSeeds.card / support.card` under the uniform distribution.
- Add monotonicity and union lemmas usable by the selected-depth ledger.
- Add a bridge from `TranscriptProbability` to `ErrorLedger` so the latter is no longer an abstract probability shell on this path.
- This file remains classical ROM/counting only; it does not close QROM.

### `Sumcheck.lean`

Approved as abstraction layer.

### `SumcheckSoundness.lean`

Approved as one of the strongest mathematical files in the repo. It constructs the exact round polynomial, exact partial hypercube sums, and finite bad challenge sets via root-counting.

Decision:
- Preserve and use as the backbone for PiCCS soundness.
- Export a theorem package tailored to the actual PiCCS degree bounds so downstream modules stop restating generic assumptions.

### `SumcheckPrefixSoundness.lean`

Approved. This is the right finite bad-set theorem shape for prefix soundness.

Decision:
- Use it to build `PiCCSConstructiveFiniteSoundness.lean`.
- Do not leave PiCCS finite soundness as a certificate interface once this file already gives the mathematics needed to derive the set.

### `TerminalCE.lean`

Not a proof. It is an assumption boundary only.

Decision:
- Keep as an API surface.
- No theorem or dossier row may cite this file as if it were concrete soundness.

### `TerminalCEConcreteSpecialSoundness.lean`

This is a meaningful upgrade over the older CE finite file. It defines explicit all-branches acceptance, round extractor semantics, a seed-indexed extraction predicate, and the exact bad-seed set induced by extraction failure.

Decision:
- Keep.
- This file should become the canonical CE special-soundness interface.
- The next step is to instantiate `proofSeed` from the real transcript/challenge derivation and prove a concrete cardinality bound for `TerminalCEConcreteBadSeeds`.

### `TerminalCEFiniteSoundness.lean`

Still not acceptable as the final theorem. It remains certificate-driven. The key profile theorem

`terminal_ce_badSeedBudget_profile`

is tautological: if a certificate already has bound `roundCount * 3`, then the cardinality is at most `roundCount * 3`. That does not derive the bound from protocol semantics.

Decision:
- Demote this file to legacy compatibility.
- Replace it with a constructive theorem file that derives the bad-seed set from concrete round semantics and proves the real cardinality bound.
- The constructive replacement must import:
  - `TerminalCEConcreteSpecialSoundness.lean`
  - `CEByteSerialization.lean`
  - `Transcript.lean`
  - `TranscriptChallenge.lean`
  - `TranscriptProbability.lean`

### `TypedDigestSemantics.lean`

Structurally useful, cryptographically insufficient. It currently gives only a byte-level typed digest wrapper over 256-bit digests.

Decision:
- Replace the theorem-critical use with a generic family:
  - `TypedDigestWire (λ : Nat)`
  - 384-bit theorem-critical instances
  - explicit digest-domain families for artifact, provenance, replay, component-root, randomness-session, leakage, and carry.
- Add theorem `typedDigestDomainSeparation` and pairwise distinctness lemmas for all theorem-critical digest kinds.

### `VectorChecks.lean`

Useful executable audit harness, not theorem-critical.

Decision:
- Keep in CI.
- Do not cite in formal security claims.

## Direct developer instructions

1. **Build `WellFormedTranscript.lean` immediately.**
   The theorem-critical transcript object must be canonical and injective.

2. **Build `Digest384Serialization.lean` and replace theorem-critical 256-bit bindings.**
   This is mandatory under `Q_H = 2^64`.

3. **Replace `TerminalCEFiniteSoundness.lean` with `TerminalCEConstructiveFiniteSoundness.lean`.**
   The new file must derive its bad-seed set, not receive it by certificate.

4. **Promote the sum-check proofs into PiCCS directly.**
   The certificate layer should disappear once the constructive finite bad-set theorem exists.

5. **Connect `TranscriptProbability` to the repo loss ledger.**
   Until that bridge exists, the selected-depth arithmetic is still partly disconnected from the finite proof objects.

## Updated status

- Transcript/sum-check core: **approved and promotable with targeted upgrades**.
- CE soundness stack: **improving, but not yet complete**.
- Typed digest layer: **must be upgraded before any theorem-critical QROM/binding claim**.
- Upper product theorem usage of these files: **allowed only as interfaces until constructive bindings are instantiated**.


Date: 2026-04-17

## 2026-04-17 implementation status

Verified with:

```text
cd Formal
lake build SuperNeoFormal
```

Result: build completed successfully for the full `SuperNeoFormal` import wall.

### Finished in this pass

- `Phi81CRT.lean` is present and imported. It defines the two degree-27 factor quotient rings, the CRT equivalence/homomorphism `Phi81 ->+* Phi81CRTLeft × Phi81CRTRight`, injectivity, component zero-reflection, nonzero-component transfer, the `X^27` relations in both components, irreducibility facts, and field instances for both CRT components.
- `PiRLCConcreteCollision.lean` is present and imported. It projects PiRLC random-linear-combination challenges/deltas through the CRT components, proves projection compatibility for `rlcWeightedSum`, proves nonzero pivot transfer to a nonzero CRT component, and reuses the scalar one-bad-pivot theorem in each component.
- `Phi81.lean` now proves `phi81Polynomial_monic`, `phi81Polynomial_natDegree`, degree-`<54` representative bounds, coefficient recovery for `phi81CoeffsToPolynomial`, `phi81CoeffsToPolynomial_injective`, and `phi81CoeffsToQuotient_injective`.
- `ChallengeSampling.lean` now proves `challengeCoefficientGoldilocks_injective`, `phi81ChallengeCoefficients_injective`, and `phi81ChallengeElement_injective`.
- `PiCCSConstructiveFiniteSoundness.lean` is present and imported. It constructs `PiCCSBadChallengeSetConstructed` directly from `sumcheckPrefixBadChallenges` and proves the requested `card <= numVars * maxDegreePerRound` bound.
- `TerminalCEConcreteSpecialSoundness.lean` is present and imported. It defines explicit three-branch CE round acceptance, concrete round extractor semantics, batch extraction from selected rounds, and a constructed finite bad-seed set from the seed-indexed extraction predicate.
- `FiniteUniformProbability.lean` is present and imported. It defines exact finite-uniform probability over finite supports, proves `Pr[event] = |event ∩ support| / |support|`, proves generic rational bounds from finite bad-set cardinality, and connects `superNeoFiatShamirProbability` to the finite-uniform model.
- `ProductBadEventLedger.lean` is present and imported. It defines a shared-tag product bad-event ledger across fold / terminal / product / carry / ZK / transcript sources and proves the aggregate charged tag set is bounded by the flat component charge while de-duplicating shared tags by construction.
- `TypedDigestSemantics.lean` is present and imported. It defines typed digest kinds, `TypedDigestWire`, injective typed digest byte encoding, framed typed digest encoding, and binding lemmas from encoded equality.

### Still compatibility surfaces, not completed cryptographic proofs

- `PiRLCFiniteSoundness.lean` still contains the older `Phi81SplitCertificate` compatibility interface. The concrete CRT collision lemmas now live below it in `Phi81CRT.lean` and `PiRLCConcreteCollision.lean`, but a full finite bad-seed count over the actual coefficient challenge support remains future work.
- `TerminalCEFiniteSoundness.lean` remains a certificate-oriented surface. `TerminalCEConcreteSpecialSoundness.lean` adds constructed semantics and an exact finite bad-set definition, but the production Stern extractor for the concrete Swift proof schedule is not yet instantiated.
- `ErrorLedger.lean` still exposes `AbstractProbabilityModel`. The finite-uniform model now exists separately in `FiniteUniformProbability.lean`; replacing or parameter-specializing `ErrorLedger.lean` is still open.
- The upper theorem files remain evidence-parametric theorem surfaces: `RecursiveFoldingKnowledge.lean`, `NumiSealEndToEnd.lean`, `NumiSealTypedCarryTheorem.lean`, `NumiSealZKPrivacy.lean`, `NumiSealProductTheorem.lean`, `ProductSecurityTheorem.lean`, and `ConstantTime.lean`.

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
