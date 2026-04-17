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
- `TestVectors/product-qrom-transform-preconditions-v1.json`
- `TestVectors/product-qrom-interactive-reduction-v1.json`
- `TestVectors/product-total-loss-budget-v1.json`
- `Formal/SuperNeoFormal/ProductSecurityTheorem.lean`
- `Scripts/validate-product-crypto-security-dossier.py`
- `Scripts/validate-product-selected-depth-loss-accounting.py`
- `Scripts/validate-product-extractor-loss-accounting.py`
- `Scripts/validate-product-qrom-fiat-shamir-accounting.py`
- `Scripts/validate-product-qrom-transcript-schedule.py`
- `Scripts/validate-product-qrom-transform-preconditions.py`
- `Scripts/validate-product-qrom-interactive-reduction.py`
- `Scripts/validate-product-total-loss-budget.py`

The current status is a bounded-depth product security theorem at depth 1.
All production claims remain disabled until the listed extractor, QROM,
parameter, carry, ZK, side-channel, and benchmark obligations are instantiated.

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

The current supported product depth is exactly 1. Polynomial-depth knowledge
soundness is not claimed.

Depth promotion requires:

- concrete Swift extractor evidence for every accepted source fold and terminal
  NumiSeal layer,
- typed-required recursive child product carry extended from the checked
  parent-child handoff to the selected production depth with replay semantics,
- explicit per-layer loss accounting for folding, terminal sealing, carry, ZK,
  and Fiat-Shamir, and
- either a bounded-depth theorem for the chosen production depth or a
  polynomial-depth theorem for the actual folding/carry construction.

## Selected-Depth Loss Accounting

`TestVectors/product-selected-depth-loss-accounting-v1.json` is the checked
selected-depth loss accounting ledger for the current depth-1 product boundary.
It is a contract for what must be instantiated before production claims can be
made, not a production loss proof.

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

The Fiat-Shamir/QROM target is recorded, and
`TestVectors/product-qrom-fiat-shamir-accounting-v1.json` now pins the QROM
Fiat-Shamir accounting contract. The accounting manifest links to
`TestVectors/product-qrom-transcript-schedule-v1.json` and
`TestVectors/product-qrom-transform-preconditions-v1.json`, and
`TestVectors/product-qrom-interactive-reduction-v1.json`, which pin the QROM
transcript schedule, transform-precondition obligations, and selected DFM20
interactive-reduction loss interface separately from the
numeric loss formula. The manifest records the selected depth, proof-kind
transcript interfaces, challenge families, and the selected-depth loss
expression:

```text
epsilon_qrom(depth=1) =
  max_kind(((2*Q_H+n_kind+1)^(2*n_kind) / n_kind!)
    * epsilon_interactive_kind
    + n_kind! / 2^256
    + epsilon_precondition_kind)
  + epsilon_qro_queries
  + epsilon_proof_kind_malleability
```

`epsilon_transcript_collision` is exported separately into the selected-depth
ledger as `epsilon_collision`; it is not counted inside `epsilon_qrom`. This
prevents a later budget evaluator from silently double-counting or dropping the
collision term. The manifest covers the current envelope kinds for fold,
terminal, compressed-terminal, NumiSeal terminal, and NumiSealZK product
proofs. The production QROM claim is still disabled.

Remaining work:

- close `TestVectors/product-qrom-interactive-reduction-v1.json` by
  instantiating numeric NumiSeal challenge-count maxima, sampler uniformity,
  and per-kind interactive security bounds,
- instantiate the pinned QROM transcript schedule with per-kind `Q_H` query
  bounds,
- close `TestVectors/product-qrom-transform-preconditions-v1.json` by proving
  the selected transform preconditions or explicitly narrow the theorem to ROM,
- account quantum random-oracle query bounds in the soundness loss,
- bind every domain separator and transcript label in the theorem, and
- prove no transcript collision or malleability across fold, terminal,
  compressed-terminal, NumiSeal terminal, and NumiSealZK envelopes.

`ProductSecurityTheorem` exposes `ProductFiatShamirTranscriptSchedule`,
`ProductFiatShamirTranscriptScheduleAccepted`,
`productSecurityTheorem_requires_qrom_transcript_schedule`,
`ProductFiatShamirTransformPreconditions`,
`ProductFiatShamirTransformPreconditionsAccepted`,
`productSecurityTheorem_requires_qrom_transform_preconditions`,
`ProductQROMInteractiveReduction`, `ProductQROMInteractiveReductionAccepted`,
`productSecurityTheorem_requires_qrom_interactive_reduction`,
`ProductFiatShamirLossAccounting`, `ProductFiatShamirLossAccountingAccepted`,
and `productSecurityTheorem_requires_qrom_loss_accounting` so future theorem
promotion cannot bypass interactive-protocol, challenge-schedule,
precondition, quantum-query, collision, malleability, or budget evidence.

## QROM Transform Preconditions

`TestVectors/product-qrom-transform-preconditions-v1.json` is the checked QROM
Transform Preconditions manifest. It is not a production QROM theorem; it is a
fail-closed checklist that makes the missing Fiat-Shamir transform proof
obligations executable. It pins primary sources, the selected
measure-and-reprogram profile, the proof-kind fit table, the symbolic
`((2*Q_H+n+1)^(2n)/n!)` DFM20 loss interface, and the blockers that keep the
production claim disabled.

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

Promotion requires the exact interactive public-coin protocol for every
accepted proof kind, the exact `(2n + 1)` schedule, uniform challenge-space
proofs, injective transcript-oracle input encoding, underlying interactive
security against quantum dishonest provers, numeric `Q_H`, numeric `n_kind`,
sampler-uniformity, and per-kind `epsilon_interactive` bounds, and integration
of `epsilon_fs_transform` and `epsilon_precondition` into the selected
total-loss budget.

## QROM Interactive Reduction

`TestVectors/product-qrom-interactive-reduction-v1.json` is the checked QROM
Interactive Reduction ledger. It records the selected DFM20 constant-round
public-coin theorem family, `Q_H = 2^64` candidate query policy, 256-bit
challenge-range accounting, exact challenge-count formulas for fold, terminal,
compressed-terminal, NumiSeal terminal, and NumiSealZK product proofs, and the
exact DFM20 multiplier `((2*Q_H+n+1)^(2n)/n!)` plus the additive
`n! / 2^256` ordering term.

The ledger instantiates conservative numeric `n` upper bounds for fold,
terminal, and compressed-terminal using the checked profile limits
`log2(shape.m) <= 64`, `maxFreshBatchCount = 61`, `maxPriorClaimCount = 14`,
and `CEOpeningProof.roundCount = 219`. It deliberately does not instantiate
numeric `n` for NumiSeal terminal or NumiSealZK product because those require
hosted product-policy maxima for lane count, aggregate count, obligation count,
lane proof count, and proof byte count. It also keeps every per-kind
`epsilon_interactive` bound, sampler-uniformity proof, and final total-loss
budget term open, so it is not a production QROM theorem.

## QROM Transcript Schedule

`TestVectors/product-qrom-transcript-schedule-v1.json` is the checked QROM
Transcript Schedule contract. It pins the accepted proof-kind order, envelope
kinds, public challenge labels, transcript bindings, symbolic quantum
random-oracle query families, and schedule-to-ledger binding for fold,
terminal, compressed-terminal, NumiSeal terminal, and NumiSealZK product proof
kinds. It is intentionally not a production QROM proof: interactive protocol
closure, transform preconditions, numeric quantum random-oracle query bounds,
and integration into the total-loss budget remain open.

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
depth-1 parent edge, verifies the parent artifact under the signed context, and
binds the recursive carry context root and replay root into durable SQLite
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
- no production performance claim, and
- no production constant-time claim.

Those claims become eligible only after the remaining obligations are closed in
the repository and the production gate validates the new evidence.
