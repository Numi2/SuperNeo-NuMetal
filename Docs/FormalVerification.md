# Formal Verification Track

Formal status: conditional protocol formalization.

The formal track lives under `Formal/` as a Lean 4 Lake workspace. It is
separate from the Sage/lattice-estimator workflow:

- Sage/lattice-estimator reproduces a heuristic Module-SIS security estimate for
  the translated SIS parameter object.
- Lean formalization records protocol-level algebraic statements and reductions
  under explicitly named assumptions.

The current Lean milestone covers an assumption-scoped protocol formalization:
profile constants, derived parameter equalities, the strong-sampling inequality,
the abstract Ajtai commitment map, opening relation, additive linearity, binding
equivalence with an explicit MSIS no-short-kernel assumption, abstract PiDEC
commitment recomposition, PiRLC weighted-claim recomposition, the PiCCS
sum-check/public-Q final-check boundary, terminal CE batch opening, and the
top-level verifier-acceptance composition.

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
groups, and closed groups without any declaration:

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

## Build

When Lean is installed through elan, run:

```sh
cd Formal
lake build
```

The CI workflow `Formal Status` runs `lake build`, validates the status
manifest, and runs the mutation-regression harness for changes touching
`Formal/`, the manifest, validator scripts, or status-bearing docs.
