# Formal Assumption Ledger Split, 2026-04-14

Formal status: conditional protocol formalization.

This pass narrows the formal-status manifest by separating deterministic Lean
cores from theorem groups that still depend on cryptographic, probabilistic, or
stage-level assumptions.

## What Changed

- Module-SIS profile constants and estimator tuple facts are now tracked as the
  closed `module-sis-parameters` group. The no-short-kernel predicate remains
  `closed_under_msis_assumption`.
- Concrete Ajtai shape, Phi81 quotient-ring wiring, packed-witness wiring, and
  concrete commitment linearity are tracked as `concrete-ajtai-instantiation`.
  Concrete opening and binding predicate shape is tracked separately as the
  closed `concrete-ajtai-opening-core`; only binding from no-short-kernel
  remains an MSIS assumption boundary.
- Generic Ajtai binding is split between the closed
  `ajtai-binding-reduction-core` group and the
  `closed_under_msis_assumption` `ajtai-binding-boundary` group.
- Transcript-derived challenge scheduling is tracked by
  `transcript-challenge-binding`: equal structured transcripts, equal
  proof-envelope context/seed inputs, equal absorbed payloads, and equal ordered
  absorb sequences derive equal finite challenge seeds and elements.
- PiRLC weighted-claim recomposition, finite challenge support/counting, and
  the scalar Goldilocks one-root collision lemma are tracked as closed cores.
  Concrete acceptance predicate shape is tracked as the closed
  `pirlc-concrete-acceptance-core`.
  The concrete Phi81 quotient-ring folded-claim collision-set bound remains the
  random-linear-combination boundary.
- PiCCS exact public-Q reduction is tracked as a closed deterministic bridge.
  PiCCS acceptance projections are tracked separately as a closed core.
  The finite-field low-degree root-count lemma is tracked as
  `sumcheck-low-degree-root-count-core`; the remaining trace/oracle
  low-degree/probabilistic sum-check soundness statement remains
  assumption-scoped.
- Terminal CE statement and batch-projection facts are tracked as a closed core.
  Terminal CE local batch relations are tracked as closed local algebra.
  Public proof-acceptance predicate shape is tracked as the closed
  `terminal-ce-proof-acceptance-core`.
  Witness uniqueness from no-short-kernel is tracked separately as
  `ce-opening-binding-boundary`, and public CE proof-verifier soundness remains
  an explicit CE-opening assumption.
- SuperNeo acceptance decomposition is tracked as closed deterministic
  composition. The proof-carrying end-to-end theorem now depends directly on
  `TerminalCEProofSoundnessAssumption`, so the top-level composition boundary
  is CE-opening scoped rather than a separate stage-assumption bucket.
- The formal-status validator now rejects duplicate declaration entries across
  theorem groups, preventing deterministic cores and assumption boundaries from
  double-counting the same Lean declaration.
- The validator also checks every label's theorem-group references and accepted
  status vocabulary, even when that label is not the active `current_label`, and
  rejects duplicate documentation claim paths.
- The validator rejects boundary groups or declarations named as assumptions or
  boundaries if they are marked `closed`. It also enforces that the completed
  label includes every conditional theorem group and accepts only `closed`.

## Boundary Kept Explicit

The manifest still keeps the public label at conditional protocol
formalization. A theorem group is not marked `closed` only because a theorem
takes a cryptographic or probabilistic assumption as an argument. The completed
formal protocol label remains blocked until every required boundary group is
unconditionally closed.

## Verification

Validation commands:

```sh
cd Formal && lake build
cd ..
Scripts/validate-formal-status.py
Scripts/test-formal-status-validation.py
```
