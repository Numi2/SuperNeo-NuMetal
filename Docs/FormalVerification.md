# Formal Verification Track

Formal status: completed formal protocol theorem.

The formal track lives under `Formal/` as a Lean 4 Lake workspace. It is
separate from the Sage/lattice-estimator workflow:

- Sage/lattice-estimator reproduces a heuristic Module-SIS security estimate for
  the translated SIS parameter object.
- Lean formalization records protocol-level algebraic statements, certified-key
  reductions, and finite bad-challenge/bad-seed exclusions.

The current Lean milestone is the completed formal protocol theorem label for
the corrected model. Ajtai binding is consumed through certified verifier keys,
and probabilistic PiRLC, PiCCS/sum-check, transcript-stage, and terminal CE proof
soundness are composed outside explicitly finite bad challenge/seed sets. The
checked declaration set covers profile constants, derived parameter equalities,
the strong-sampling inequality, concrete Goldilocks/Phi81 algebra,
GoldilocksExt2 wire operations, Ext2 caller byte surfaces, CE opening proof byte
grammar, Phi81 factorization, field-to-ring packing, the complete Lean
`GoldilocksExt2` field instance, concrete and certified Ajtai instantiation,
PiDEC recomposition, PiRLC weighted-claim recomposition, finite-support
counting, scalar and quotient-ring-safe collision facts, transcript-bound
finite challenge scheduling, PiCCS acceptance projections, the PiCCS exact
public-Q bridge, finite-field low-degree root counting, sum-check prefix
bad-challenge aggregation, finite bad-challenge PiCCS soundness, terminal CE
statement and local batch algebra, finite bad-seed terminal CE proof soundness,
Swift/Lean GoldilocksExt2 serialization equivalence, Swift/Lean CE verifier-byte
equivalence, distinct-witness-to-short-kernel reductions, and the full rational
probability composition theorem over the finite Fiat-Shamir seed product.

The historical `closed_under_*` groups remain documented for auditability, but
the manifest now uses closed replacement group IDs and closed promotion blocker
groups. The status validator rejects declaration reuse across theorem groups,
prevents boundary/assumption declarations from appearing in completed theorem
groups, and requires the three promotion blockers to be closed when the
completed label is active.

## Status Manifest

`Docs/FormalStatus.json` is the source of truth for documentation labels. The
validator checks that docs do not claim a stronger status than the manifest
supports, resolves each declared Lean module to its source file, and requires
closed theorem groups to reference declarations that are present in that module:

```sh
Scripts/validate-formal-status.py
```

The regression harness mutates temporary manifest copies and confirms the
validator fails closed for missing blockers, non-closed promotion blockers,
missing declarations, closed groups without any declaration, assumption/boundary
declarations in completion groups, documentation overclaims, and completed-label
dependency drift:

```sh
Scripts/test-formal-status-validation.py
```

Allowed labels are:

- `bounded formalization`
- `partial formalization`
- `conditional protocol formalization`
- `completed formal protocol theorem`

Documentation may use the full theorem label only when every group on that path
is `closed`. Historical `closed_under_*` boundary IDs are replaced by closed
certified-key, finite-bad-seed, byte-equivalence, and probability-composition
groups on the completed path.

Recent formal pass:

- [Formal Ajtai Binding, 2026-04-13](FormalAjtaiBinding-2026-04-13.md)
- [Formal PiDEC Recomposition, 2026-04-13](FormalPiDECRecomposition-2026-04-13.md)
- [Formal Protocol Composition, 2026-04-13](FormalProtocolComposition-2026-04-13.md)
- [Formal Assumption Ledger Split, 2026-04-14](FormalAssumptionLedger-2026-04-14.md)
- [Formal Remaining Boundaries, 2026-04-14](FormalRemainingBoundaries-2026-04-14.md)
- [Formal Completion Research Plan, 2026-04-14](FormalCompletionResearchPlan-2026-04-14.md)
- `Formal/SuperNeoFormal/NumiSealSumcheckTranscript.lean` now names the dense
  NumiSeal sum-check transcript domain and absorb-frame order used by the Swift
  prover/verifier.

## Build

When Lean is installed through elan, run:

```sh
cd Formal
lake build
```

The CI workflow `Formal Status` runs `lake build`, validates the status
manifest, and runs the mutation-regression harness for changes touching
`Formal/`, the manifest, validator scripts, or status-bearing docs.
