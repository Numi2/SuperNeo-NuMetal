# Formal Verification Track

Formal status: bounded formalization.

The formal track lives under `Formal/` as a Lean 4 Lake workspace. It is
separate from the Sage/lattice-estimator workflow:

- Sage/lattice-estimator reproduces a heuristic Module-SIS security estimate for
  the translated SIS parameter object.
- Lean formalization records protocol-level algebraic statements and reductions
  under explicitly named assumptions.

The current Lean milestone covers the Ajtai commitment layer at a bounded level:
profile constants, the abstract commitment map, opening relation, additive
linearity, and binding from an explicit MSIS no-short-kernel assumption.

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
- `completed formal protocol theorem`

Documentation must not use `completed formal protocol theorem` until the final
SuperNeo verifier-acceptance composition theorem group is closed.

## Build

When Lean is installed through elan, run:

```sh
cd Formal
lake build
```

The CI workflow `Formal Status` runs `lake build` and then validates the status
manifest for changes touching `Formal/`, the manifest, or status-bearing docs.
