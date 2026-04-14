# Formal Verification Track

Formal status: conditional protocol formalization.

The formal track lives under `Formal/` as a Lean 4 Lake workspace. It is
separate from the Sage/lattice-estimator workflow:

- Sage/lattice-estimator reproduces a heuristic Module-SIS security estimate for
  the translated SIS parameter object.
- Lean formalization records protocol-level algebraic statements and reductions
  under explicitly named assumptions.

The current Lean milestone is narrowed conditional formalization: closed
deterministic theorem groups are separated from explicit cryptographic,
probabilistic, and CE-proof boundaries. It covers profile constants,
derived parameter equalities, the strong-sampling inequality, concrete
Goldilocks/Phi81 algebra, field-to-ring packing, concrete Ajtai instantiation,
PiDEC recomposition, PiRLC weighted-claim recomposition, finite-support counting
and scalar collision facts, transcript-bound finite challenge scheduling, PiCCS
acceptance projections, the PiCCS exact public-Q bridge, finite-field
low-degree root counting, terminal CE statement and local batch algebra, and
deterministic verifier-acceptance composition. Binding, Phi81 collision
probability, low-degree sum-check soundness, public CE proof soundness, and the
CE-soundness-dependent end-to-end terminal theorem remain named assumption
boundaries. The status
validator rejects declaration reuse across theorem groups so closed cores and
assumption boundaries cannot double-count the same Lean declaration. It also
prevents boundary/assumption declarations from being marked closed and keeps the
completed label tied to every conditional theorem-group dependency.

## Status Manifest

`Docs/FormalStatus.json` is the source of truth for documentation labels. The
validator checks that docs do not claim a stronger status than the manifest
supports, resolves each declared Lean module to its source file, and requires
closed theorem groups to reference declarations that are present in that module:

```sh
Scripts/validate-formal-status.py
```

The regression harness mutates temporary manifest copies and confirms the
validator fails closed for missing declarations, declarations attached to planned
groups, closed groups without any declaration, boundary groups marked closed,
and completed-label dependency drift:

```sh
Scripts/test-formal-status-validation.py
```

Allowed labels are:

- `bounded formalization`
- `partial formalization`
- `conditional protocol formalization`
- `completed formal protocol theorem`

Documentation must not use `completed formal protocol theorem` until every
required theorem group is unconditionally `closed`. Groups marked
`closed_under_*` are formal assumption boundaries and support the current
conditional label only.

Recent formal pass:

- [Formal Ajtai Binding, 2026-04-13](FormalAjtaiBinding-2026-04-13.md)
- [Formal PiDEC Recomposition, 2026-04-13](FormalPiDECRecomposition-2026-04-13.md)
- [Formal Protocol Composition, 2026-04-13](FormalProtocolComposition-2026-04-13.md)
- [Formal Assumption Ledger Split, 2026-04-14](FormalAssumptionLedger-2026-04-14.md)
- [Formal Remaining Boundaries, 2026-04-14](FormalRemainingBoundaries-2026-04-14.md)

## Build

When Lean is installed through elan, run:

```sh
cd Formal
lake build
```

The CI workflow `Formal Status` runs `lake build`, validates the status
manifest, and runs the mutation-regression harness for changes touching
`Formal/`, the manifest, validator scripts, or status-bearing docs.
