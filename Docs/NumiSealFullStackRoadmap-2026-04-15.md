# NumiSeal Full Stack Roadmap - 2026-04-15

This roadmap is the execution plan for turning the current folding engine into
a complete NumiSeal terminal-seal stack and then into a stronger SNARK product
track.

It is intentionally ambitious, but every claim must be evidence-gated. "Better
than state of the art" is a research target, not a release label. The repository
earns that label only when it has reproducible proofs, adversarial vectors,
formal hooks, benchmark evidence, and a clear security story.

## Current Baseline

Already present:

- CCS is the internal arithmetization IR.
- Hand-authored R1CS can generate witnesses and terminal/compressed proof
  envelopes through `SuperNeoR1CSProgram`.
- Ajtai commitments have a backend boundary with seeded/system-random keygen,
  shape-bound verification, key serialization, and verifier-key digesting.
- SuperNeo fold reduction, terminal local envelopes, compressed public terminal
  envelopes, and terminal acceptance policy exist.
- NumiSeal Phase 0 has lane IDs, lane keys, obligations, canonical ordering,
  lane summary roots, a versioned public statement, bounded wire readers, and
  initial lane-local public aggregation.
- NumiSeal has a versioned proof-body grammar, kind `4` envelope, dedicated
  terminal preflight policy, typed component digest leaves, typed absent carry
  binding, deterministic decomposition-key derivation, a bounded ternary
  digit-tensor grammar, CPU reference decomposition commitment checks, and a
  public scalarization residual oracle bound into lane-proof digests.
- NumiSeal has an initial aggregate evaluation oracle that rebuilds witnessed
  lane aggregates and checks sparse CCS transformed evaluations against the
  existing Ajtai/CCS machinery.
- NumiSeal has an optimized dense folded sum-check handoff that binds proof-body
  sum-check bytes to the scalar residual and digit-tensor language while
  supporting large bounded digit tensors.
- NumiSeal has a typed immediate residual-opening handoff that binds lane scope,
  scalarization digest, sum-check proof digest, a stable residual CE
  shape/statement digest, derived decomposition key, decomposition commitment,
  digit-tensor digest, synthetic digit-opening terminal statement bytes, and
  canonical CE opening proof bytes. Preflight reruns the public final sum-check
  equation against the claimed digit evaluation, and full verification derives
  the digit-opening key and calls the existing CE opening verifier for the direct
  digit-commitment opening.
- NumiSeal has a first `NumiSealProvingPlan`/`NumiSealProver`/`NumiSealVerifier`
  assembly API for the current immediate-residual aggregate-sequence path. The
  plan exposes deterministic public statement and aggregate order before the
  caller supplies per-aggregate digit-tensor inputs. The prover builds
  multi-lane/multi-aggregate envelopes from witnessed obligations, and the
  verifier recomputes public statement and aggregates before CE verification.
- NumiSeal has a checked terminal vector matrix and release-gate validation
  path: `superneo-numiseal-vectors` regenerates deterministic immediate
  residual vectors byte-for-byte using SPI-only deterministic CE randomness,
  validates `numiseal-manifest.json`, parses kind `4` envelopes, and verifies
  through `NumiSealVerifier`.
- NumiSeal now has adversarial audit coverage for malformed 13-round
  large-tensor sum-check proof-body frames, per-shape vector manifest negatives,
  per-shape vector artifact proof-kind negatives, and a Lean dense sum-check
  transcript hook.

Now present:

- Production `superneo inspect` and opt-in `superneo verify --require-numiseal`
  exposure for checked immediate-residual artifacts over the current direct
  digit-commitment residual verifier.

Not yet present:

- General NumiSeal proving/product exposure.
- Formal completion and security audit artifacts.
- Zero-knowledge layer.
- Recursive/aggregate sealing product.
- General program frontend.

## Non-Negotiable Boundaries

- A fold reduction is never application acceptance.
- NumiSeal verifier exposure is limited to checked immediate-residual artifacts
  and must not be advertised as a complete production NumiSeal product until
  general proving, formal completion, and security-audit gates pass.
- NumiSeal is not zero knowledge by default.
- CE opening masking is not a blanket zero-knowledge layer.
- No external PCS is imported for v10.
- No cross-lane batching is allowed. Equal lane key is the batching boundary.
- Every absent optional component must have a typed absent-component leaf, never
  a zero digest.
- Every proof byte must be parsed through bounded readers before algebraic
  verification starts.
- Any parameter change that affects security gets a new profile ID.

## Design Thesis

The strongest path for this repository is not to imitate pairing-era SNARK
stacks. The opportunity is a native post-quantum terminal seal:

```text
CCS terminal CE obligations
-> canonical lane-local aggregation
-> one Ajtai digit-tensor commitment per aggregate
-> public scalar residual
-> degree-4 sum-check
-> residual CE opening
-> terminal envelope policy
```

The invention target is a verifier whose expensive work is narrow, whose public
bytes are typed and digest-bound, whose recursive carry format is native, and
whose security story is explicit about every conditional assumption.

## Phase 1: Proof Body Grammar

Goal: define the public binary object before implementing expensive proving
logic.

Artifacts:

- `NumiSealProof`
- `NumiSealLaneProof`
- `NumiSealComponentDigest`
- `NumiSealComponentDigestTree`
- bounded parsers and serializers

Proof body:

```text
NumiSealProof {
  bodyVersion = 11
  publicStatement
  aggregateCount
  laneProofs
  componentDigestRoot
  transcriptDigest
}

NumiSealLaneProof {
  laneKey
  aggregateIndex
  aggregateDigest
  decompositionKeyDigest
  decompositionCommitment
  scalarizationDigest
  sumcheckProof
  residualOpening
  optionalCarryClaim
}
```

Acceptance gates:

- malformed body version is rejected;
- aggregate count must match lane proof count;
- lane proofs are lane-major and aggregate-index sorted;
- every public-statement lane summary must have lane proof coverage, with
  lane-scoped aggregate indices starting at zero and without gaps;
- component root recomputes exactly;
- transcript digest recomputes exactly;
- absent optional carry uses a typed absent-component digest;
- trailing bytes and oversized counts fail before algebraic verification.

World-class bar:

- include a proof-body corpus with one valid body and mutations for every
  public field;
- publish a byte-layout table like `Docs/ProofEnvelope.md`;
- include parser-only tests that never instantiate private witnesses.

## Phase 2: Envelope Kind And Terminal Policy

Goal: make NumiSeal terminal acceptance impossible to confuse with fold
reduction.

Artifacts:

- `ProofEnvelopeKind.numiSealTerminal = 4`
- `NumiSealProofEnvelope`
- `NumiSealTerminalProofAcceptancePolicy`
- verifier preflight helper mirroring `SuperNeoTerminalProofAcceptancePolicy`

Policy fields:

```text
profileID
shapeDigest
statementDigest
verifierKeyDigest
transcriptDomain
acceptedLaneIDs
maximumProofByteCount
maximumLaneCount
maximumAggregatesPerLane
acceptedResidualMode
acceptedCarryMode
```

Acceptance gates:

- fold, terminal-local, and compressed-public envelopes are rejected by
  NumiSeal policy;
- NumiSeal envelopes are rejected by existing terminal policy unless explicitly
  supported later;
- wrong profile, shape, statement, verifier key, transcript domain, lane ID,
  proof byte limit, residual mode, or carry mode fails before expensive checks;
- old parsers fail closed on unknown kind;
- `Docs/ProofEnvelope.md` records the new kind and body grammar.

World-class bar:

- the policy must be usable by services without loading private witness data;
- the policy must expose structured rejection reasons without leaking witness
  details.

## Phase 3: Decomposition Key And Digit Tensor

Goal: turn each lane aggregate witness into a bounded digit language with one
Ajtai commitment.

Artifacts:

- `NumiSealDecompositionKeyDerivation`
- `NumiSealDigitTensor`
- `NumiSealDecompositionCommitment`
- CPU reference implementation
- optional Metal path behind CPU-redundant policy only

Initial implementation status: deterministic key derivation, bounded
`NumiSealDigitTensor` parsing, ternary reconstruction, zero-padding checks, and
CPU reference decomposition commitment/opening checks are present. The actual
aggregate witness decomposition pipeline and algebraic verifier handoff remain
future work.

Rules:

- derive `A_dec` from public data:

  ```text
  H(
    "numiseal.decomposition-key.v1" ||
    verifierKeyDigest ||
    laneKey ||
    aggregateIndex ||
    requiredColumnCount
  )
  ```

- decompose into ternary digits `{-1, 0, 1}`;
- use one digit-tensor commitment per aggregate, not 14 limb commitments;
- padding digits must be zero and explicitly checked.

Acceptance gates:

- deterministic key derivation round trips;
- decomposition reconstructs aggregate witness exactly;
- invalid digit is rejected;
- nonzero padding is rejected;
- CPU and CPU-redundant Metal commitments match;
- decomposition key digest changes when any derivation input changes.

World-class bar:

- provide a standalone fixture that lets an external verifier reproduce
  `A_dec`, the digit commitment, and the reconstruction.

## Phase 4: Public Scalarization

Goal: collapse all public linear terminal equalities for an aggregate into one
extension-field residual.

Equalities:

- original Ajtai commitment consistency;
- CCS matrix evaluation consistency;
- public-slot consistency.

Artifacts:

- `NumiSealScalarizationStatement`
- `NumiSealScalarizationWeights`
- `NumiSealLinearResidual`
- direct recomputation oracle

Initial implementation status: scalarization statements, transcript-derived
weights, and parse-checked linear residuals are present. The proof-body fixture
now binds `scalarizationDigest` to the recomputed residual digest. An aggregate
evaluation oracle rebuilds witnessed lane aggregates in canonical order and
checks sparse transformed CCS evaluations against the existing commitment/key
machinery. Full transformed-matrix fixture coverage across multi-lane,
prior-claim, and sum-check handoff cases remains future work.

Acceptance gates:

- tampering commitment, public input, matrix evaluation, lane key, or aggregate
  digest changes the scalar residual;
- sparse CCS evaluation agrees with the existing transformed matrix oracle;
- scalarization coefficients are transcript-bound to public statement,
  aggregate digest, decomposition commitment, and policy context;
- fixtures cover one-obligation, multi-obligation, multi-lane, and prior-claim
  cases.

World-class bar:

- scalarization has a small independent reference checker that can run without
  the prover.

## Phase 5: Degree-4 Sum-Check

Goal: prove linear residual, ternary language, and padding checks with one
degree-4 sum-check per aggregate.

Artifacts:

- `NumiSealSumcheckOracle`
- `NumiSealSumcheckProof`
- verifier integration with existing `SumcheckVerifier`

Initial implementation status: `NumiSealSumcheckOracle` is present as an
optimized dense folded handoff. It uses the existing
`SumcheckProver`/`SumcheckVerifier`, binds the transcript to scalarization and
digit-tensor digests, proves
`claimedSum == residualValue` for valid ternary/zero-padded tensors, and
replaces the toy proof in the NumiSeal proof-body fixture. The typed immediate
residual-opening handoff now binds this sum-check proof digest into the residual
payload. A large-tensor regression covers proof generation and verification
beyond the old reference variable cap.

Polynomial components:

```text
G_lin  = lambda(X) * pow2(K)  * D(X,K)
G_lang = eta_lang(X,K) * active(K)  * D(X,K)(D(X,K)-1)(D(X,K)+1)
G_pad  = eta_pad(X,K)  * padding(K) * D(X,K)
```

Acceptance gates:

- valid digit tensor passes;
- wrong scalar residual fails;
- non-ternary digit fails;
- nonzero padding fails;
- wrong sum-check degree fails;
- final evaluation mismatch fails;
- transcript replay is deterministic.

World-class bar:

- include mutation tests for every polynomial component, not just the final
  proof bytes.

## Phase 6: Residual Opening

Goal: close the sum-check final digit-witness evaluation using the existing CE
opening relation.

Artifacts:

- `NumiSealResidualCEShape`
- `NumiSealResidualCEStatement`
- `NumiSealResidualOpening`
- `NumiSealCarryClaim`
- residual CE witness builder

Implementation status: `NumiSealResidualOpening` is now the typed immediate
residual object for the current prover track. It parses canonical decomposition
key derivation bytes, residual CE statement bytes, synthetic digit-opening
terminal statement bytes, and CE opening proof bytes, binding them to
lane/aggregate scope, `residualShapeDigest`, `decompositionKeyDigest`,
`decompositionCommitmentDigest`, `digitTensorDigest`,
`scalarizationStatementDigest`, `linearResidualDigest`, `sumcheckProofDigest`,
`residualStatementDigest`, `digitOpeningStatementDigest`,
`ceOpeningProofDigest`, and an `openingDigest`. `NumiSealResidualCEShape` and
`NumiSealResidualCEStatement` bind digit dimensions, the sum-check final-point
digest, the synthetic digit-opening shape digest, decomposition digests, the
claimed digit evaluation, and the digit-opening statement digest. Preflight
reruns the public final sum-check equation, and full verification derives the
digit-opening key from public data before calling `CEOpeningRelation.verify`.
`NumiSealResidualCEBuilder` constructs that direct digit-commitment opening from
typed public statement, aggregate, decomposition, digit tensor, scalar residual,
sum-check proof, and aggregate-witness inputs.

Current residual object:

```text
NumiSealResidualOpening {
  laneKey
  aggregateIndex
  residualShapeDigest
  decompositionKeyDerivation
  decompositionKeyDigest
  decompositionCommitmentDigest
  digitTensorDigest
  scalarizationStatementDigest
  linearResidualDigest
  sumcheckProofDigest
  residualStatement
  digitOpeningStatement
  ceOpeningProof
}
```

Rules:

- residual shape is stable and versioned;
- residual opening verifies the digit commitment at the sum-check final point;
- immediate verification is the default;
- carry mode is opt-in and policy-controlled.

Acceptance gates:

- wrong residual shape digest fails;
- wrong decomposition key digest fails;
- wrong decomposition commitment digest fails;
- wrong final point fails;
- wrong claimed digit evaluation fails;
- CE opening proof mutation fails;
- carry claims are rejected unless policy accepts carry mode.

World-class bar:

- residual opening can be verified independently from the rest of the prover
  with only public statement, aggregate metadata, and proof bytes.

## Phase 7: NumiSeal Prover And Verifier

Goal: assemble the complete terminal seal.

Initial implementation status: `NumiSealWitnessedObligation`, `NumiSealProver`,
`NumiSealVerifier`, `NumiSealVerificationResult`, and
`NumiSealAggregateDigitTensorInput` are present, with `NumiSealProvingPlan`
exposing the deterministic public statement, aggregate sequence, aggregate
count, and aggregate digests before proving. The prover supports the current
multi-lane/multi-aggregate immediate-residual path: it canonicalizes witnessed
obligations, builds the public statement, aggregates deterministic lane chunks,
consumes one digit-tensor input per aggregate, derives each decomposition
commitment, proves the dense folded sum-check, constructs immediate
residual CE openings, and wraps a kind `4` envelope. The verifier parses bytes,
applies NumiSeal terminal policy preflight, recomputes the public statement and
aggregates from caller-supplied public obligations, checks lane and residual CE
bindings, and only then calls the existing full residual-opening verification
path. An SPI-only deterministic proving path exists for reproducible checked
vectors and benchmark-style tooling; production proving remains on randomized
CE opening generation. CLI exposure and the final algebraic digit-commitment
residual verifier remain future work.

Prover pipeline:

```text
obligations + witnesses + shape + key + policy
-> canonicalization
-> public statement
-> lane aggregation
-> decomposition commitment
-> scalarization
-> degree-4 sum-check
-> residual opening
-> proof body
-> envelope
```

Verifier pipeline:

```text
proof bytes + obligations + shape + key + policy
-> parse envelope
-> policy preflight
-> parse proof body
-> recompute canonicalization
-> recompute public statement
-> recompute aggregates/challenges
-> verify decomposition metadata
-> verify scalarization
-> verify sum-check
-> verify residual opening or accepted carry
-> recompute component root and transcript digest
-> VerificationResult
```

APIs:

```swift
public struct NumiSealProvingPlan { ... }
public struct NumiSealAggregateDigitTensorInput { ... }
public final class NumiSealProver { ... }
public final class NumiSealVerifier { ... }
public struct NumiSealVerificationResult { ... }
```

Acceptance gates:

- complete valid proof verifies;
- every single public component has a mutation test;
- fold-only proof bytes are rejected;
- terminal-local and compressed-public proof bytes are rejected by NumiSeal
  policy;
- proof generated for one shape/key/statement/domain never verifies under
  another;
- multi-lane and multi-aggregate proofs verify;
- empty lane, empty obligation, and inconsistent lane summary fail closed.

World-class bar:

- verifier has a cheap preflight path that rejects bad public bytes before
  touching sum-check or CE opening verification.

## Phase 8: Vectors, CLI, And Production Gate

Goal: make NumiSeal reproducible without presenting the CLI as a production
verifier service.

Artifacts:

- checked-in NumiSeal terminal vectors;
- vector manifest entries with byte count, hash, shape digest, statement digest,
  verifier-key digest, transcript-domain digest, public-statement digest,
  aggregate digest, proof kind, lane IDs, and strict command;
- `superneo inspect` support for NumiSeal headers and public statement;
- opt-in `superneo verify --require-numiseal`;
- future opt-in `superneo prove --seal numiseal`;
- production-gate coverage.

Initial implementation status: `superneo-numiseal-vectors` now generates and
validates `TestVectors/numiseal-terminal-single-aggregate-v1.json`,
`TestVectors/numiseal-terminal-two-aggregate-v1.json`, and
`TestVectors/numiseal-terminal-two-lane-v1.json` under
`TestVectors/numiseal-manifest.json` and
`TestVectors/numiseal-artifact.schema.json`. Validation rejects duplicate and
unknown JSON keys, checks byte count and SHA-256, regenerates deterministic
envelopes from checked fixtures, and uses the shared `NumiSealArtifactVerifier`
core to compare public statement, obligation-root, lane-summary-root,
aggregate, component-root, and proof-transcript digests before verifying through
`NumiSealVerifier`. `Scripts/production-gate.sh` runs this validator and runs
`Scripts/test-numiseal-vector-validation.py`, which mutates the manifest
workload metadata and artifact proof-kind metadata for every checked NumiSeal
vector shape. The production `superneo` CLI now inspects NumiSeal vector
artifacts and verifies them only behind `--require-numiseal`, with optional
external pins for transcript-domain, public-statement, obligation-root,
lane-summary-root, aggregate, component-root, proof-transcript, and ordinary
verifier-context digests.

Acceptance gates:

- vector validator rejects unknown fields and duplicate keys;
- release gate verifies the single-aggregate, same-lane two-aggregate, and
  two-lane checked NumiSeal vectors through `superneo verify --require-numiseal`;
- negative fixtures cover wrong digest, wrong lane, wrong proof kind, wrong
  byte count, wrong manifest hash, per-shape NumiSeal manifest and artifact
  metadata, missing `--require-numiseal`, legacy terminal policy, wrong
  production pins, wrong public input, and proof-kind/header mismatch;
- production gate runs parser-only tests before expensive algebraic tests.

World-class bar:

- vectors are small enough to inspect, but include at least one multi-lane
  aggregate to exercise real canonicalization.
- `superneo` verifier exposure is explicit about being a checked
  immediate-residual terminal verifier, not a general NumiSeal proving or
  zero-knowledge product surface.

## Phase 9: Security Story

Goal: make claims precise enough that future auditors can attack them.

Artifacts:

- `Docs/ThreatModel.md` NumiSeal update;
- `Docs/WhatThisProves.md` NumiSeal section;
- `Docs/FormalAssumptionLedger` update;
- NumiSeal-specific adversarial test matrix;
- implementation security checklist.

Claims to prove or explicitly condition:

- binding to policy context and proof kind;
- lane-local RLC soundness;
- digit-language soundness;
- scalarization soundness;
- residual CE opening soundness;
- composition with existing terminal CE assumptions;
- carry-claim semantics under recursion;
- non-ZK default behavior.

Acceptance gates:

- every security claim has a code artifact, test artifact, or formal assumption
  entry;
- every non-claim is documented in the public docs;
- no README or CLI text calls NumiSeal zero knowledge by default;
- no benchmark or demo text calls the CLI a production verifier.

World-class bar:

- maintain a living attack ledger with accepted, mitigated, and out-of-scope
  attacks.

## Phase 10: Formalization Hooks

Goal: make the implementation easy to connect to Lean and external review.

Artifacts:

- typed byte grammar for NumiSeal public statement and proof body;
- Lean declarations for lane keys, dense sum-check transcript frame order,
  roots, aggregate challenge schedule, scalarization, digit language, and
  residual opening;
- conformance script comparing Swift encodings to formal grammar fixtures.

Acceptance gates:

- Swift fixtures are imported by formal conformance tooling;
- `Formal/SuperNeoFormal/NumiSealSumcheckTranscript.lean` is imported by the
  top-level formal target and listed in the formal-status manifest;
- byte-level grammar rejects malformed lengths and wrong domains;
- formal status manifest distinguishes closed deterministic cores from
  assumptions;
- no formal document claims end-to-end proof until verifier composition is
  represented.

World-class bar:

- every public digest label appears in one place in Swift and one place in the
  formal model, with a conformance check.

## Phase 11: Performance And Metal

Goal: accelerate only after the CPU reference is unambiguous.

Order:

1. CPU reference.
2. Constant-work CPU mode for secret-bearing witness transformations.
3. CPU-redundant Metal for public or array-heavy deterministic work.
4. Benchmarks and regression thresholds.
5. Optional Metal-only fast path for non-secret verifier work after CPU oracle
   coverage exists.

Acceptance gates:

- CPU and CPU-redundant Metal outputs match for decomposition commitment and
  scalarization helpers;
- benchmark rows separate prover decomposition, scalarization, sum-check,
  residual CE opening, and full envelope verification;
- no Metal path is used for witness-bearing work under `.highAssurance`;
- performance claims are tied to hardware class and benchmark metadata.

World-class bar:

- verifier can report a cost breakdown by phase for engineering and audit use.

## Phase 12: Recursive And Aggregate Sealing

Goal: use NumiSeal carry claims without weakening terminal acceptance.

Artifacts:

- `NumiSealCarryPolicy`
- recursive carry statement encoding;
- aggregate proof planner;
- recursion-level transcript labels;
- carry consumption verifier.

Rules:

- base verifier defaults to immediate residual verification;
- carry mode is policy opt-in;
- carry claims bind parent statement digest and recursion level;
- no randomness reuse across recursive levels;
- carry claims cannot silently replace terminal proof acceptance.

Acceptance gates:

- immediate-residual and carry modes have separate vectors;
- a carry accepted at level `n` must be consumed by level `n+1`;
- replaying carry under another parent statement fails;
- aggregate proof verifies the same public obligations as the unaggregated
  proof.

World-class bar:

- recursive carry format is stable enough to survive frontend changes.

## Phase 13: Zero-Knowledge Product Track

Goal: add ZK as a separate layer with its own proof story.

Artifacts:

- `NumiSealZKDesign.md`
- randomness derivation policy;
- digit-tensor masking design;
- simulator argument;
- witness-hiding tests;
- side-channel review.

Hard requirements:

- masking composes with scalarization and residual CE opening;
- randomness is domain-separated by proof, lane, aggregate, and recursion level;
- no deterministic witness-dependent branches in ZK witness transformations
  unless protected by constant-work mode;
- ZK proofs have distinct proof kind or policy flag.

Acceptance gates:

- non-ZK NumiSeal remains available and explicitly labeled;
- ZK vectors fail under non-ZK policy unless policy explicitly accepts them;
- randomness reuse tests fail closed;
- docs state exactly what is hidden and what remains public.

World-class bar:

- produce a simulator-oriented design before optimizing proof size.

## Phase 14: Frontend Expansion

Goal: move beyond hand-authored R1CS without pretending the builder is a full
compiler.

Tracks:

- richer R1CS builder ergonomics;
- AIR-like frontend exploration;
- small DSL for arithmetic circuits;
- witness trace validation;
- frontend-to-CCS shape cache;
- source-map style debugging from constraints back to frontend code.

Acceptance gates:

- every frontend emits CCS as canonical IR;
- every frontend has deterministic witness generation;
- public/private input ordering is explicit;
- frontend-generated statements round-trip through terminal and NumiSeal
  verification;
- frontend errors identify violated constraints without leaking private witness
  values in default logs.

World-class bar:

- build a constraint debugger good enough that failed proofs are actionable.

## Phase 15: Verifier/API Product Surface

Goal: expose verification as a library and service boundary without
over-trusting the CLI.

Artifacts:

- Swift library verifier API;
- stable JSON metadata schema for public context;
- optional local service wrapper;
- structured `VerificationResult`;
- policy templates for common modes.

Acceptance gates:

- API rejects missing policy;
- API rejects unknown proof kind by default;
- API exposes public rejection reasons and internal diagnostics separately;
- API supports byte limits, lane allowlists, profile allowlists, and statement
  digest pinning;
- service mode never fetches keys or statements from untrusted proof metadata
  without caller policy.

World-class bar:

- API makes unsafe integration harder than safe integration.

## Phase 16: Research Evidence And Governance

Goal: make improvements reproducible and maintainable.

Artifacts:

- benchmark dashboards by phase;
- parameter-profile registry;
- lattice-estimator reproduction updates;
- formal-status promotion rules;
- release checklist;
- proof-size and verifier-time reports.

Acceptance gates:

- every profile has a pinned estimator artifact;
- every proof format has versioned byte docs;
- every release vector has manifest hash and strict verification command;
- every benchmark has hardware, toolchain, source-cleanliness, and policy
  metadata;
- no "state of the art" comparison is published without reproducible commands.

World-class bar:

- a third party can rebuild the vectors, rerun the estimator, rerun the
  benchmarks, and inspect the formal assumption ledger without private context.

## Execution Order

Shortest path to a complete NumiSeal terminal proof:

1. Proof body grammar.
2. Envelope kind and NumiSeal acceptance policy.
3. Decomposition key and digit tensor.
4. Scalarization.
5. Degree-4 sum-check.
6. Residual opening.
7. Prover/verifier assembly.
8. Vectors, CLI exposure, and production gate.
9. Threat model, formal hooks, and benchmark report.

Then:

1. Recursive carry.
2. Zero-knowledge layer.
3. General frontend expansion.
4. Verifier/API product surface.
5. Parameter governance and external reproducibility.

## Stop Conditions

Do not advance to the next phase when:

- a parser accepts malformed bytes;
- a policy can accidentally accept fold reduction as terminal proof;
- a digest root can be recomputed with missing components;
- a proof verifies after mutation of a public binding field;
- a witness-bearing path uses Metal under `.highAssurance`;
- docs claim zero knowledge before the ZK layer exists;
- benchmark output lacks reproduction metadata;
- formal docs imply closed soundness while assumptions remain open.
