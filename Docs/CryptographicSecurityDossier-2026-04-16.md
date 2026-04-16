# Cryptographic Security Dossier - 2026-04-16

This dossier records the current product cryptography theorem surface for
SuperNeo/NumiSeal. It is a checked, evidence-parametric record, not a
production-security claim.

Machine-readable scope:

- `TestVectors/product-crypto-security-dossier-v1.json`
- `Formal/SuperNeoFormal/ProductSecurityTheorem.lean`
- `Scripts/validate-product-crypto-security-dossier.py`

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
- recursive typed carry product vectors and replay semantics beyond
  `carryMode = none`,
- explicit per-layer loss accounting for folding, terminal sealing, carry, ZK,
  and Fiat-Shamir, and
- either a bounded-depth theorem for the chosen production depth or a
  polynomial-depth theorem for the actual folding/carry construction.

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

## Fiat-Shamir/QROM

The Fiat-Shamir/QROM target is recorded, but the production QROM claim is
disabled.

Remaining work:

- define the exact public-coin interactive protocol before Fiat-Shamir for
  every accepted product proof kind,
- prove the selected transform preconditions or explicitly narrow the theorem
  to ROM,
- account quantum random-oracle query bounds in the soundness loss,
- bind every domain separator and transcript label in the theorem, and
- prove no transcript collision or malleability across fold, terminal,
  compressed-terminal, NumiSeal terminal, and NumiSealZK envelopes.

Relevant QROM literature includes Don, Fehr, Majenz, and Schaffner,
`Security of the Fiat-Shamir Transformation in the Quantum Random-Oracle
Model`, https://arxiv.org/abs/1902.07556. The current dossier does not claim
that SuperNeo/NumiSeal already satisfies that theorem's hypotheses.

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
parent acceptance evidence, context, and lane state. The product default still
uses `carryMode = none`.

Production recursive carry promotion requires product-level carry vectors,
malformed negative vectors for the recursive product path, replay semantics for
accepted product sessions, and a theorem showing carry cannot be swapped across
contexts, lanes, proofs, or product sessions.

## Proof Size And Latency

`TestVectors/e2e-proof-metrics-v1.json` pins deterministic proof-envelope and
artifact byte budgets for checked vectors and product smokes. That is not a
competitive performance claim.

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
