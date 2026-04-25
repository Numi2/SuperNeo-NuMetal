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
- `TestVectors/product-finite-protocol-loss-obstruction-v1.json`
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

The current status is a repository-local bounded-depth product theorem surface
with local typed parent-child carry evidence. The selected finite-protocol loss
budget is instantiated for the checked depth-1 profile, but production-security
claims remain disabled until hosted operations replay, side-channel,
release-distribution, and promoted-depth recursive-carry evidence are
instantiated and accepted. These production gates do not block repository-local
development, testing, or selected-depth theorem use.

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
hosted operations, concrete hash/QRO, side-channel, or release evidence.

## Recursion And Knowledge Soundness

The current executable product path supports a local typed parent-child carry
handoff when a verified parent is supplied. Polynomial-depth knowledge
soundness and hosted selected-depth recursive carry are not claimed.

Depth promotion requires:

- recursive typed carry extractor evidence for promoted depths beyond the
  selected depth-1 zero-hop profile,
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
- proof-level ZK simulator composition loss, now instantiated as zero under the
  declared leakage model,
- Fiat-Shamir/QROM loss,
- concrete extractor failure loss,
- transcript collision and proof-kind malleability loss,
- product-ops replay and revocation freshness loss,
- constant-time side-channel leakage loss, and
- repository-local release distribution evidence.

For the current repository-local selected-depth theorem claim, the finite loss
ledger records:

```text
epsilon_total(depth=1) =
  epsilon_core_shared
  + epsilon_fold
  + epsilon_terminal
  + epsilon_zk_sim
  + epsilon_qrom
  + epsilon_extract
  + epsilon_collision
```

For future recursive promotion, the finite selected-depth expression records
the additional carry-hop term:

```text
epsilon_total(depth=d) =
  epsilon_core_shared
  + d * (epsilon_fold + epsilon_terminal + epsilon_zk_sim + epsilon_qrom + epsilon_extract)
  + max(d - 1, 0) * epsilon_carry
  + epsilon_collision
```

Hosted operations replay, side-channel, release-distribution, and promoted-depth
recursive-carry evidence are production-security gates outside the
repository-local selected-depth finite loss sum. The ledger allows the selected
finite theorem claim only when its required finite terms are instantiated and
inside budget, while production-security claim flags remain false until those
gates close. `ProductSecurityTheorem` now exposes
`ProductSelectedDepthLossLedger`,
`ProductSelectedDepthLossLedgerAccepted`, and
`productSecurityTheorem_requires_selected_depth_loss_accounting` so the formal
surface cannot skip extractor, QROM, selected finite loss, and production-gate
accounting.

The finite-model protocol certificates are now separated from selected numeric
loss instantiation. `TestVectors/product-finite-protocol-loss-obstruction-v1.json`
records the exact obstruction: under the current `Goldilocks/Phi81(d=54)`
profile, `5^54 < 2^128`, so even a hypothetical full-ring PiRLC
`1/5^54` single-observation bound is larger than the selected 128-bit budget,
while the available CRT-component certificate is only `1/5^27`. The PiCCS
Ext2 support also satisfies `q^2 < 2^128`, and the selected `72/q^2` certificate
is about `2^-121.83`. The current one-shot route is therefore frozen as
non-128-bit. The selected route is fixed-kind CTCO repeated-tape accounting:
PiCCS uses two internal tapes, PiRLC uses three internal CRT-component tapes
unless a separate semantic unit-pivot theorem is proved, and terminal CE is
pinned at 226 rounds. The terminal repeated-challenge tape theorem gives
`(2/3)^226`, about `2^-132.20`, and Lean pins the exact comparison with
shared-core slack. The selected product ledger now wires the fixed-kind route as
`epsilon_fold <= 16/q^4 + 1/5^81` and `epsilon_terminal_ce <= (2/3)^226`; the
one-shot PiRLC/PiCCS facts remain as permanent non-128-bit blockers so they
cannot be used to promote a one-shot selected-depth claim.

## Extractor Loss Accounting

`TestVectors/product-extractor-loss-accounting-v1.json` is the checked
extractor loss accounting contract. It pins the selected depth, accepted input
bindings, deterministic post-acceptance replay model, and four extractor loss
terms:

- source fold extractor loss,
- terminal NumiSeal seal extractor loss,
- product envelope composition extractor loss, and
- recursive carry extractor loss for future depth promotion.

At the current depth, the extractor contract records the selected replay loss
as exact zero:

```text
epsilon_extract(depth=1) = 0
```

For future recursive promotion, it records:

```text
epsilon_extract(depth=d) =
  d * 0 + max(d - 1, 0) * epsilon_extract_carry
```

This is not a production product-security claim. The selected-depth Swift
surface `NumiSealProductConcreteExtractor.extract` replays accepted source fold,
terminal seal, product envelope, trusted-context, trace-evidence, and QROM
bindings and records `swiftConcreteExtractorEvidenceDigest` in product metadata.
Recursive carry extraction remains required before promoted-depth production
claims. `ProductSecurityTheorem` exposes
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
threshold lane. `Scripts/reproduce-lattice-estimator.sh` and
`Scripts/validate-lattice-estimator-artifact.py` preserve the pinned estimator
lane and sensitivity-row validation, including lower conservative quantum and
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

Current QROM guardrails are therefore:

- keep the per-kind interactive security bounds consumed by the product theorem
  surface charged outside `epsilon_qrom`; these are now pinned by
  `TestVectors/product-qrom-interactive-reduction-v1.json`;
- consume the NumiSealZK proof-level simulator coupling evidence outside the
  QROM transform term with `epsilon_zk_sim = 0`;
- keep concrete SHAKE256-to-QRO promotion separate from the ideal split-QRO
  theorem model; and
- keep production QROM claims enabled through those evidence objects.

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

Repository-local promotion is scoped to the ideal split-QRO model and checked
selected total-loss budget. Concrete hash/QRO promotion is a separate
deployment-model extension outside this repository-local claim. The CTCO
delayed-message/unique-response data, ideal split-QRO compiler-overhead term,
384-bit H_bind collision accounting, proof-kind malleability accounting, and
exact partial total-loss wiring are pinned by the checked manifests. Per-kind
interactive security and proof-level NumiSealZK simulator coupling are exported
outside `epsilon_qrom` by checked evidence.
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
instantiation as a QRO; that is outside the repository-local split-QRO claim.

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
leakage, and carry. It instantiates the 384-bit H_bind collision target count
and zero proof-kind malleability outside the collision ledger. It intentionally
does not prove a concrete hash/QRO instantiation. The residual collision events
are mapped into the selected-depth `epsilon_collision` ledger term, while the
ideal split-QRO `epsilon_qrom` compiler-overhead term is zero in the checked
CTCO model.

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
`maxPriorClaimCount = 14`, and `CEOpeningProof.roundCount = 226`.
NumiSeal terminal and NumiSealZK product now use the code-enforced
`NumiSealProductTheoremLimits` surface: one product lane, at most 75 source
fold output claims, at most 75 obligations per aggregate, at most 75 aggregates
per lane, at most 1024 public inputs, at most 1024 matrix evaluations, and at
most 18 sum-check variables. This yields `n_numiseal_terminal <= 4,376,925`
and `n_numiseal_zk_product <= 4,377,150`.

The ledger also records the decisive fail-closed budget result. Under the legacy
DFM20/256-bit challenge accounting, `log2(204!)` is already greater than 1276,
so the additive `204! / 2^256` ordering term is greater than 1 for the smallest
accepted proof kind. That route is not being promoted. The active route is the
CTCO split-QRO product compiler with 384-bit binding digests and interactive
soundness charged outside the QROM transform loss.

## QROM Transcript Schedule

`TestVectors/product-qrom-transcript-schedule-v1.json` is the checked QROM
Transcript Schedule contract. It pins the accepted proof-kind order, envelope
kinds, public challenge labels, transcript bindings, symbolic quantum
random-oracle query families, and schedule-to-ledger binding for fold,
terminal, compressed-terminal, NumiSeal terminal, and NumiSealZK product proof
kinds. It also pins the conditional `Q_H = 2^64` adversary-query cap and
`8755125` selected-depth protocol challenge derivations. It is intentionally
not a concrete-hash QROM proof. The transcript-canonicality gap is now closed
by the well-formed Lean transcript object, the binding-width gap is closed by
the 384-bit digest layer, and the ideal split-QRO compiler-overhead term is
wired as zero into the selected total-loss budget.

## Total Loss Budget

`TestVectors/product-total-loss-budget-v1.json` is the checked total-loss
budget contract. It is an executable accounting layer over the selected-depth
ledger, extractor accounting, QROM accounting, ZK evidence, product-ops
readiness, release evidence, and constant-time evidence.

The budget uses exact rational arithmetic over terms of the form:

```text
exact rational upper-bound terms, with dyadic terms as numerator / 2^k
```

For this contract, the selected threshold is `2^-128`. The current manifest
records eleven component bounds, seven of which are required for the
repository-local selected depth-1 theorem claim. The typed recursive carry,
hosted operations replay, side-channel, and release-distribution rows have zero
selected-depth multiplicity and are kept outside the selected finite-protocol
sum. They are production-security gates, not blockers for repository-local use.
The shared cryptographic core is charged once as
`epsilon_core_shared = 1/2^129`; source-fold, terminal, and extractor rows are
residual terms after that shared charge rather than a flat duplicate sum of the
same core event.

The current manifest intentionally records:

- `requiredTermCount = 7`,
- `instantiatedRequiredTermCount = 7`,
- `exactInstantiatedRequiredTermUpperBound` is the exact rational sum of the
  shared core term, repeated-tape source-fold term, terminal CE 226 term,
  zero-valued QROM compiler-overhead, zero-valued ZK simulator term,
  zero-valued extractor term, and H_bind collision term,
- `exactSelectedDepthLossUpperBound` is that same exact rational sum,
- `selectedDepthLossWithinBudget = true`,
- `repositoryLocalSelectedDepthLossClaimAllowed = true`, and
- `productionTotalLossClaimAllowed = false`.

This proves only the repository-local selected-depth finite loss claim. It
prevents a future production-security claim from bypassing operations,
constant-time, release-distribution, or promoted-depth recursive-carry gates, or
from double-counting `epsilon_core_shared` or `epsilon_collision` inside another
ledger term.

## Release Distribution Evidence

`TestVectors/product-release-distribution-evidence-v1.json` is the checked
release distribution evidence contract. It binds the `epsilon_release` loss
term to required source archives, Swift CLI binaries, test-vector bundles,
release-candidate evidence, benchmark/estimator artifacts, provenance fields,
unsigned artifact status, release evidence digests, and repository-local
artifact digest provenance requirements.

The manifest intentionally removes release signing, notarization, public
distribution, publication-protection evidence, and archived-evidence fields
from the repository-local production gate. Production release distribution is
claimed through artifact digests, release evidence digests, the full production
gate result, and the selected total-loss budget surface.

## NumiSealZK Privacy

The masked residual language and leakage surface are recorded in the NumiSealZK
theorem scope. The exact rejection-sampled field mask distribution is checked
by `TestVectors/numiseal-zk-mask-distribution-evidence-v1.json`, including
zero statistical distance from uniform accepted field elements after rejection.

The proof-level privacy simulator is now recorded in
`TestVectors/numiseal-zk-simulator-coupling-evidence-v1.json`: under exact
field-mask sampling, fresh randomness-session binding, mask-reuse rejection,
and the declared proof-byte leakage model, the simulator loss is
`epsilon_zk_sim = 0`. Product proving now emits NumiSealZK by default. Signed
side-channel certificates are optional only when the trusted context minimum is
`correctness-only`; stricter contexts must attach a certificate at or above the
minimum. The remaining privacy production obligations are side-channel evidence
plus hosted behavior evidence for artifact metadata, sizes, errors, retry
behavior, allocator/GPU behavior, and carry-state exposure outside declared
proof bytes.

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

Repository-local recursive carry promotion is enabled for the checked selected
depth and parent-child edge. Extending that handoff to deeper hosted recursion
bounds requires corresponding multi-depth vectors, hosted replay/loss
accounting for accepted product sessions, and theorem coverage showing carry
cannot be swapped across contexts, lanes, proofs, or product sessions at the
new promoted depth.

## Proof Size And Latency

`TestVectors/e2e-proof-metrics-v1.json` pins deterministic proof-envelope and
artifact byte budgets for checked vectors and product smokes. That is not a
competitive performance claim.
`TestVectors/benchmark-coverage-v1.json` pins the benchmark row families that
must remain present for source fold, verifier, stage, CPU kernel, Metal kernel,
NumiSeal product, recursive carry, and product-control timing. That is coverage
evidence for the local benchmarking stack, not a substitute for fresh hardware
latency measurements.

State-of-art comparison claims require fresh same-hardware tables for:

- proof bytes,
- prover time,
- verifier time,
- peak memory,
- recursion/carry overhead,
- Metal vs CPU cost,
- ZK overhead, and
- parameter-security level.

That evidence is now pinned separately in
`Docs/CompetitivePerformance-2026-04-21.md` and
`TestVectors/competitive-performance-comparison-v1.json`. It remains separate
from the repository-local production gate surfaced by this dossier.

The relevant comparison class includes LatticeFold/LatticeFold+ style lattice
folding systems and STARK-style transparent systems. LatticeFold is tracked as
a nearby comparison target because it is a lattice-based folding construction
with recursive-SNARK/PCD applications: https://eprint.iacr.org/2024/257.

## Implementation Hardening

The constant-time evidence track already pins source/formal scope,
Swift/LLVM/Metal lowering evidence, local Swift SIL/LLVM/assembly artifacts,
Metal AIR/metallib artifacts, metallib objdump output, the scoped
compiler/lowering audit, runtime allocation review, and CPU/GPU observation
corpora. These are non-certifying evidence artifacts. Full side-channel
certification still requires hardware observation coverage before claiming
whole-stack constant-time behavior.

Remaining hardening work:

- dudect-style CPU timing corpus,
- hardware counters,
- GPU timing/counter corpus,
- allocator/ARC/COW proof or exclusion,
- failure-path constant behavior, and
- proof that artifact size, error, and retry behavior do not depend on secrets.

## Promotion Rule

The machine-readable dossier enables repository-local production claims for:

- product security,
- post-quantum parameter position,
- Fiat-Shamir/QROM accounting,
- ZK privacy and default masked-residual behavior,
- recursive carry,
- local performance/proof-size budgets,
- release distribution evidence.

The machine-readable dossier deliberately does not enable the production
constant-time claim. Constant-time evidence is pinned as non-certifying release
evidence until hardware observation coverage is complete.

External signing, notarization, public distribution, and competitor-performance
claims are not promotion gates for this repository-local status. When external
materials quote competitor numbers, cite
`Docs/CompetitivePerformance-2026-04-21.md` and
`TestVectors/competitive-performance-comparison-v1.json`.
