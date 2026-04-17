# Cryptographic Security Dossier - 2026-04-16

This dossier records the current product cryptography theorem surface for
SuperNeo/NumiSeal. It is a checked, evidence-parametric record, not a
production-security claim.

Machine-readable scope:

- `TestVectors/product-crypto-security-dossier-v1.json`
- `TestVectors/product-selected-depth-loss-accounting-v1.json`
- `TestVectors/product-extractor-loss-accounting-v1.json`
- `TestVectors/product-qrom-fiat-shamir-accounting-v1.json`
- `TestVectors/product-qrom-transcript-schedule-v1.json`
- `TestVectors/product-qrom-sampler-encoding-evidence-v1.json`
- `TestVectors/product-qrom-collision-malleability-evidence-v1.json`
- `TestVectors/product-qrom-transform-preconditions-v1.json`
- `TestVectors/product-qrom-interactive-reduction-v1.json`
- `TestVectors/product-total-loss-budget-v1.json`
- `TestVectors/product-release-distribution-evidence-v1.json`
- `Formal/SuperNeoFormal/ProductSecurityTheorem.lean`
- `Scripts/validate-product-crypto-security-dossier.py`
- `Scripts/validate-product-selected-depth-loss-accounting.py`
- `Scripts/validate-product-extractor-loss-accounting.py`
- `Scripts/validate-product-qrom-fiat-shamir-accounting.py`
- `Scripts/validate-product-qrom-transcript-schedule.py`
- `Scripts/validate-product-qrom-sampler-encoding-evidence.py`
- `Scripts/validate-product-qrom-collision-malleability-evidence.py`
- `Scripts/validate-product-qrom-transform-preconditions.py`
- `Scripts/validate-product-qrom-interactive-reduction.py`
- `Scripts/validate-product-total-loss-budget.py`
- `Scripts/validate-product-release-distribution-evidence.py`

The current status is an evidence-parametric bounded-depth product security
theorem surface with local typed parent-child carry evidence. All production
claims remain disabled until the listed extractor, QROM, parameter, hosted
carry-depth, ZK, side-channel, release distribution, and benchmark obligations
are instantiated.

## Theorem Scope

`ProductSecurityTheorem` composes the actual product system surfaces:

- source fold relation,
- NumiSeal terminal relation,
- NumiSealZK masked residual relation,
- typed recursive carry relation,
- transcript binding,
- artifact/proof-envelope binding,
- verifier acceptance policy, and
- soundness/completeness/ZK composition.

The checked Lean theorem is intentionally evidence-parametric. It proves that
if the product bindings, bounded-depth loss accounting, lattice dossier,
Fiat-Shamir/QROM evidence, and existing NumiSeal product/carry/ZK relations are
accepted, then the product completeness, knowledge-soundness, zero-knowledge,
and composition claims hold. It does not fill in missing concrete extractor,
simulator-coupling, QROM, or side-channel evidence.

## Recursion And Knowledge Soundness

The current executable product path supports a local typed parent-child carry
handoff when a verified parent is supplied. Polynomial-depth knowledge
soundness and hosted selected-depth recursive carry are not claimed.

Depth promotion requires:

- concrete Swift extractor evidence for every accepted source fold and terminal
  NumiSeal layer,
- typed-required recursive child product carry extended from the local checked
  parent-child handoff to the selected hosted production depth with replay
  semantics,
- explicit per-layer loss accounting for folding, terminal sealing, carry, ZK,
  and Fiat-Shamir, and
- either a bounded-depth theorem for the chosen production depth or a
  polynomial-depth theorem for the actual folding/carry construction.

## Selected-Depth Loss Accounting

`TestVectors/product-selected-depth-loss-accounting-v1.json` is the checked
selected-depth loss accounting ledger for the product theorem boundary. It is a
contract for what must be instantiated before production claims can be made, not
a production loss proof.

The ledger pins these loss terms:

- source fold knowledge loss,
- terminal NumiSeal seal loss,
- typed recursive carry loss,
- ZK simulator composition loss,
- Fiat-Shamir/QROM loss,
- concrete extractor failure loss,
- transcript collision and proof-kind malleability loss,
- product-ops replay and revocation freshness loss,
- constant-time side-channel leakage loss, and
- release signing/notarization distribution loss.

For the current selected depth, the ledger records:

```text
epsilon_total(depth=1) =
  epsilon_fold
  + epsilon_terminal
  + epsilon_zk_sim
  + epsilon_qrom
  + epsilon_extract
  + epsilon_collision
  + epsilon_replay
  + epsilon_ct
  + epsilon_release
```

For future recursive promotion, the ledger records the additional carry-hop
term:

```text
epsilon_total(depth=d) =
  d * (epsilon_fold + epsilon_terminal + epsilon_zk_sim + epsilon_qrom + epsilon_extract)
  + max(d - 1, 0) * epsilon_carry
  + epsilon_collision
  + epsilon_replay
  + epsilon_ct
  + epsilon_release
```

The ledger deliberately keeps `selectedDepthLossClaimAllowed = false` until
all component losses are instantiated and the total loss is inside the selected
budget. `ProductSecurityTheorem` now exposes
`ProductSelectedDepthLossLedger`,
`ProductSelectedDepthLossLedgerAccepted`, and
`productSecurityTheorem_requires_selected_depth_loss_accounting` so the formal
surface cannot skip extractor, QROM, simulator, and total-loss gates.

## Extractor Loss Accounting

`TestVectors/product-extractor-loss-accounting-v1.json` is the checked
extractor loss accounting contract. It pins the selected depth, accepted input
bindings, transcript rewind model, and four extractor loss terms:

- source fold extractor loss,
- terminal NumiSeal seal extractor loss,
- product envelope composition extractor loss, and
- recursive carry extractor loss for future depth promotion.

At the current depth, the extractor contract records:

```text
epsilon_extract(depth=1) =
  epsilon_extract_source_fold
  + epsilon_extract_terminal
  + epsilon_extract_product
```

For future recursive promotion, it records:

```text
epsilon_extract(depth=d) =
  d * (epsilon_extract_source_fold + epsilon_extract_terminal + epsilon_extract_product)
  + max(d - 1, 0) * epsilon_extract_carry
```

This is not a completed extractor proof. It deliberately keeps
`concreteExtractorImplemented = false`, `extractorLossWithinBudget = false`,
and `productionExtractorClaimAllowed = false` until the Swift extractor is
implemented over the actual proof-envelope bytes and the numeric loss is inside
the selected total budget. `ProductSecurityTheorem` exposes
`ProductExtractorLossAccounting`,
`ProductExtractorLossAccountingAccepted`, and
`productSecurityTheorem_requires_extractor_loss_accounting`.

## Lattice Assumption Dossier

The pinned assumption is Module-SIS over Goldilocks/Phi81 Ajtai commitments:

| Parameter | Value |
| --- | ---: |
| `q` | `18446744069414584321` |
| Ring | `F_q[X]/(X^54 + X^27 + 1)` |
| Cyclotomic index | `81` |
| Ring degree | `54` |
| `kappa` | `18` |
| Decomposition length | `14` |
| Norm bound | `2` |
| Challenge coefficients | `[-2, -1, 0, 1, 2]` |
| Challenge expansion factor | `216` |
| Maximum fresh batch count | `61` |
| Maximum prior CE claim count | `14` |
| Coefficient-expanded SIS dimension | `972` |
| Estimator `m` | `1073741824` |
| L2 length bound | `927712935936` |
| Strong-sampling check | `16200 < 16384` |

The pinned default estimator lane records `129.1` rop bits, matching the paper
threshold lane. The sensitivity rows in
`Docs/LatticeEstimatorReproduction.md` include lower conservative quantum and
enumeration models, so the product dossier does not permit a broad production
post-quantum claim. NIST FIPS 203/204/205 set the reference bar for precise
parameter sets and category claims; this repo keeps the current claim
assumption-scoped until the reduction-loss and parameter story survives that
style of scrutiny.

## QROM Fiat-Shamir Accounting

The Fiat-Shamir/QROM target is no longer the old DFM20 multi-round production
route. The current theorem path is the split-oracle product surface in
`ProductSecurityTheorem.lean`: 256-bit challenge seeds, 384-bit
theorem-critical binding digests, well-formed framed transcripts, CTCO as the
preferred compiler family, and Merkle-straightline as the fallback compiler
family. Interactive soundness is charged outside the QROM transform term, and
shared bad events are carried through the selected-depth ledger instead of being
duplicated under flat rows.

`TestVectors/product-qrom-fiat-shamir-accounting-v1.json`,
`TestVectors/product-qrom-transcript-schedule-v1.json`,
`TestVectors/product-qrom-transform-preconditions-v1.json`, and
`TestVectors/product-qrom-interactive-reduction-v1.json` remain useful
fail-closed manifests. They record the older DFM20 diagnostic accounting, the
historical schedule pressure, and the executable reason production QROM claims
stay disabled. They are not the target theorem package.

The current Lean surface exposes the theorem-critical replacement objects:

- `ProductQROMTransformFamily.ctco`
- `ProductQROMTransformFamily.merkleStraightline`
- `ProductHashOracleInstantiationAccepted`, requiring split oracles and
  `bindingOracleBits = 384`
- `ProductCTCOCompilerEvidenceAccepted`, requiring 384-bit binding and Merkle
  node digests
- `ProductQROMCollisionBoundAccepted`
- `ProductQROMMalleabilityBoundAccepted`
- `ProductQROMTotalLossInstantiatedAccepted`
- `ProductFiatShamirQROMAccepted`
- `ProductQROMTightTransform`

Remaining QROM work is therefore:

- instantiate the selected CTCO or Merkle-straightline compiler evidence;
- prove or otherwise pin the release-grade trace/extractor equivalences consumed
  by the product theorem surface;
- instantiate concrete hash/QRO assumptions, 384-bit binding collision bounds,
  proof-kind malleability bounds, and total-loss integration; and
- keep production QROM claims disabled until those evidence objects are present.

## QROM Transform Preconditions

`TestVectors/product-qrom-transform-preconditions-v1.json` is the checked QROM
Transform Preconditions manifest. It is not a production QROM theorem; it is a
fail-closed checklist and historical diagnostic for the older
measure-and-reprogram route. The active theorem target is the split-oracle
CTCO/Merkle-straightline surface in `ProductSecurityTheorem.lean`, not promotion
of the DFM20 loss formula.

The manifest follows the QROM Fiat-Shamir literature most relevant to this
stack:

- Don, Fehr, Majenz, and Schaffner, `Security of the Fiat-Shamir
  Transformation in the Quantum Random-Oracle Model`,
  https://eprint.iacr.org/2019/190, for the three-round Sigma-protocol target.
- Don, Fehr, and Majenz, `The Measure-and-Reprogram Technique 2.0:
  Multi-Round Fiat-Shamir and More`, https://eprint.iacr.org/2020/282, for
  constant-round public-coin multi-round Fiat-Shamir and the `O(q^(2n))` loss
  shape.
- Unruh, `Post-Quantum Security of Fiat-Shamir`,
  https://eprint.iacr.org/2017/398, for the stronger post-quantum caveats
  around zero knowledge, soundness, and extractability.
- Don, Fehr, Majenz, and Schaffner, `Efficient NIZKs and Signatures from
  Commit-and-Open Protocols in the QROM`, https://arxiv.org/abs/2202.13730,
  for the future tighter commit-and-open extractor track if product proofs are
  refactored to fit that family.

Promotion now requires CTCO or Merkle-straightline compiler evidence, underlying
interactive security against quantum dishonest provers, a split-challenge/binding
oracle instantiation, 384-bit binding collision accounting, proof-kind
malleability accounting, and integration into the selected total-loss budget.
Uniform challenge-space and well-formed structured transcript-oracle input
encoding are pinned by the sampler/encoding evidence plus the Lean
`WellFormedTranscript` and `Digest384Serialization` layers, while concrete
hash/QRO instantiation remains outside the Lean finite model.

## QROM Sampler And Encoding Evidence

`TestVectors/product-qrom-sampler-encoding-evidence-v1.json` is the checked
QROM sampler and transcript-encoding evidence manifest. It pins the current
Goldilocks rejection sampler, Ext2 product sampler, Phi81 coefficient and ring
sampler, terminal CE ternary sampler, and NumiSealZK masked-residual field
challenge sampler. The arithmetic is exact under the QRO abstraction:
Goldilocks accepts `2^64 - 2^32 + 1` values and rejects `2^32 - 1`,
Phi81 coefficient sampling accepts `2^64 - 1` values divisible by `5`, and CE
ternary sampling rejects the single Goldilocks field value needed for a
multiple-of-3 support.

The same manifest pins the structured transcript-oracle encoding. The Lean
theorem path now strengthens this with `WellFormedTranscript.lean`: byte
injectivity is theorem-facing only for length-counted transcript states whose
frame counters agree with payload lengths. `Digest384Serialization.lean` and
`TypedDigestSemantics.lean` add the 384-bit theorem-critical binding layer used
by the product theorem surface. This closes the old canonical-transcript and
binding-width documentation gap. It does not prove a concrete hash
instantiation as a QRO, instantiate the product compiler evidence, or close the
final total-loss budget.

## QROM Collision/Malleability Structural Evidence

`TestVectors/product-qrom-collision-malleability-evidence-v1.json` is the
checked QROM Collision/Malleability Structural Evidence manifest. It pins the
accepted five proof kinds, Swift proof-envelope raw values, the Lean
proof-envelope kind and transcript-binding injectivity surface, transcript
domain enforcement, proof-kind acceptance policy, artifact/provenance digest
binding, product replay identity, NumiSeal component-root binding, and typed
carry replay binding.

This evidence closes structural cross-kind, cross-domain, cross-product-session,
and cross-carry swap paths outside digest collision events. The theorem-critical
digest taxonomy is now parameterized and includes explicit 384-bit binding
domains for artifact, provenance, replay, component root, randomness session,
leakage, and carry. It intentionally does not instantiate a concrete hash/QRO
proof, numeric 384-bit binding collision bounds, numeric proof-kind
malleability bounds, product compiler evidence, or total-loss budget
integration. Those residual events remain mapped into
`epsilon_transcript_collision`, `epsilon_proof_kind_malleability`, and the
selected-depth `epsilon_collision`/`epsilon_qrom` ledger terms.

## QROM Interactive Reduction

`TestVectors/product-qrom-interactive-reduction-v1.json` is the checked QROM
Interactive Reduction ledger for the legacy DFM20 diagnostic route. It records
the historical constant-round public-coin theorem family, `Q_H = 2^64`
candidate query policy, 256-bit challenge-range accounting, exact
challenge-count formulas for fold, terminal, compressed-terminal, NumiSeal
terminal, and NumiSealZK product proofs, and the exact DFM20 multiplier
`((2*Q_H+n+1)^(2n)/n!)` plus the additive `n! / 2^256` ordering term.

The ledger instantiates conservative numeric `n` upper bounds for every
accepted proof kind. Fold, terminal, and compressed-terminal use the checked
profile limits `log2(shape.m) <= 64`, `maxFreshBatchCount = 61`,
`maxPriorClaimCount = 14`, and `CEOpeningProof.roundCount = 219`.
NumiSeal terminal and NumiSealZK product now use the code-enforced
`NumiSealProductTheoremLimits` surface: one product lane, at most 75 source
fold output claims, at most 75 obligations per aggregate, at most 75 aggregates
per lane, at most 1024 public inputs, at most 1024 matrix evaluations, and at
most 18 sum-check variables. This yields `n_numiseal_terminal <= 4,376,925`
and `n_numiseal_zk_product <= 4,377,150`.

The ledger also records the decisive fail-closed budget result. Under the legacy
DFM20/256-bit challenge accounting, `log2(204!)` is already greater than 1276,
so the additive `204! / 2^256` ordering term is greater than 1 for the smallest
accepted proof kind. That route is not being promoted. The active route is to
instantiate CTCO or Merkle-straightline product compiler evidence with 384-bit
binding digests and separate interactive soundness from QROM transform loss.

## QROM Transcript Schedule

`TestVectors/product-qrom-transcript-schedule-v1.json` is the checked QROM
Transcript Schedule contract. It pins the accepted proof-kind order, envelope
kinds, public challenge labels, transcript bindings, symbolic quantum
random-oracle query families, and schedule-to-ledger binding for fold,
terminal, compressed-terminal, NumiSeal terminal, and NumiSealZK product proof
kinds. It also pins the conditional `Q_H = 2^64` adversary-query cap and
`8755125` selected-depth protocol challenge derivations. It is intentionally
not a production QROM proof. The transcript-canonicality gap is now closed by
the well-formed Lean transcript object, and the binding-width gap is closed by
the 384-bit digest layer. Remaining QROM work is product compiler evidence,
concrete hash/QRO assumptions, numeric collision/malleability bounds, and
integration into the total-loss budget.

## Total Loss Budget

`TestVectors/product-total-loss-budget-v1.json` is the checked total-loss
budget contract. It is an executable accounting layer over the selected-depth
ledger, extractor accounting, QROM accounting, ZK evidence, product-ops
readiness, release evidence, and constant-time evidence.

The budget uses exact rational arithmetic over terms of the form:

```text
multiplicity * 2^-boundLog2
```

For this contract, the selected threshold is `2^-128`. The current manifest
records ten component bounds, nine of which are required at selected depth 1.
The typed recursive carry term has zero selected-depth multiplicity and remains
closed only for the current base depth, not for recursive depth promotion.

The current manifest intentionally records:

- `requiredTermCount = 9`,
- `instantiatedRequiredTermCount = 0`,
- `exactSelectedDepthLossUpperBound = null`,
- `selectedDepthLossWithinBudget = false`, and
- `productionTotalLossClaimAllowed = false`.

This does not prove product security. It prevents a future product-security
claim from bypassing numeric extractor, QROM, ZK, operations, constant-time,
and release-distribution loss terms or from double-counting
`epsilon_transcript_collision` inside `epsilon_qrom`.

## Release Distribution Evidence

`TestVectors/product-release-distribution-evidence-v1.json` is the checked
release distribution evidence contract. It binds the `epsilon_release` loss
term to required source archives, Swift CLI binaries, test-vector bundles,
release-candidate evidence, benchmark/estimator artifacts, provenance fields,
unsigned research-artifact status, release evidence digests, and fail-closed
signing/notarization/branch-protection flags.

The manifest intentionally records that no release signing key, signed
provenance format, notarization/publication path, hosted branch-protection
evidence, archived release evidence, or numeric `epsilon_release` bound has
been instantiated. Production release distribution remains outside the theorem
claim until those fields are supplied and folded into the total-loss budget.

## NumiSealZK Privacy

The masked residual language and leakage surface are recorded in the NumiSealZK
theorem scope. The exact rejection-sampled field mask distribution is checked
by `TestVectors/numiseal-zk-mask-distribution-evidence-v1.json`, including
zero statistical distance from uniform accepted field elements after rejection.

The remaining privacy proof obligations are:

- simulator coupling from witness-free transcripts to real product transcripts,
- randomness-session composition across repeated product proofs,
- proof that mask reuse is impossible or detected in every accepted mode,
- proof that artifact metadata, sizes, errors, retry behavior, and carry state
  leak only declared public information, and
- composition of the simulator with transcript, envelope, and product-policy
  binding.

## Carry And Recursion Closure

Typed carry producer/consumer theorem surfaces exist, and the carry digest
binds producer evidence, transcript evidence, residual opening material,
parent acceptance evidence, context, and lane state. Product artifacts now bind
`carryMode` to `terminalCarryPolicy` metadata and the terminal verifier carry
acceptance mode, so a typed-required artifact cannot be accepted as a no-carry
proof. Product recursive carry context vectors now bind parent artifact, source
fold, product proof envelope, producer proof envelope, lane, aggregate, child
session, and next recursion level. Base artifacts still use `carryMode = none`;
recursive child artifacts with a verified parent use `carryMode =
typed-required`. The local product-control path now reconstructs the same
typed parent-child edge, verifies the parent artifact under the signed context,
and binds the recursive carry context root and replay root into durable SQLite
replay identity and JSONL audit evidence. The child path also requires signed
parent provenance and prior parent replay-ledger acceptance, and SQLite enforces
single-use local acceptance for each recursive carry replay-binding digest.

Production recursive carry promotion still requires extending that parent-child
handoff to the selected production depth, hosted replay/loss accounting for
accepted product sessions, and a theorem showing carry cannot be swapped across
contexts, lanes, proofs, or product sessions at the promoted depth.

## Proof Size And Latency

`TestVectors/e2e-proof-metrics-v1.json` pins deterministic proof-envelope and
artifact byte budgets for checked vectors and product smokes. That is not a
competitive performance claim.
`TestVectors/benchmark-coverage-v1.json` pins the benchmark row families that
must remain present for source fold, verifier, stage, CPU kernel, Metal kernel,
NumiSeal product, recursive carry, and product-control timing. That is coverage
evidence for the local benchmarking stack, not a substitute for fresh hardware
latency measurements.

State-of-art comparison requires same-hardware tables for:

- proof bytes,
- prover time,
- verifier time,
- peak memory,
- recursion/carry overhead,
- Metal vs CPU cost,
- ZK overhead, and
- parameter-security level.

The relevant comparison class includes LatticeFold/LatticeFold+ style lattice
folding systems and STARK-style transparent systems. LatticeFold is tracked as
a nearby comparison target because it is a lattice-based folding construction
with recursive-SNARK/PCD applications: https://eprint.iacr.org/2024/257.

## Implementation Hardening

The constant-time evidence track already pins source/formal scope,
Swift/LLVM/Metal lowering evidence, local Swift SIL/LLVM/assembly artifacts,
Metal AIR/metallib artifacts, runtime allocation review, and CPU/GPU
observation corpora. The production constant-time claim remains disabled.

Remaining hardening work:

- Swift optimized SIL review,
- LLVM IR review,
- target assembly review,
- Metal AIR/object/disassembly review per GPU family,
- dudect-style CPU timing corpus,
- hardware counters,
- GPU timing/counter corpus,
- allocator/ARC/COW proof or exclusion,
- failure-path constant behavior, and
- proof that artifact size, error, and retry behavior do not depend on secrets.

## Promotion Rule

The machine-readable dossier fails closed:

- no production product-security claim,
- no production post-quantum claim,
- no production QROM claim,
- no production ZK privacy claim,
- no production recursive carry claim,
- no production performance claim,
- no production release distribution claim, and
- no production constant-time claim.

Those claims become eligible only after the remaining obligations are closed in
the repository and the production gate validates the new evidence.
