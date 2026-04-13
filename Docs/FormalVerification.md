# Formal Verification Track

Formal status: partial formalization.

The formal track lives under `Formal/` as a Lean 4 Lake workspace. It is
separate from the Sage/lattice-estimator workflow:

- Sage/lattice-estimator reproduces a heuristic Module-SIS security estimate for
  the translated SIS parameter object.
- Lean formalization records protocol-level algebraic statements and reductions
  under explicitly named assumptions.

The current Lean milestone covers the first partial formalization layer:
profile constants, the abstract Ajtai commitment map, opening relation,
additive linearity, and binding from an explicit MSIS no-short-kernel
assumption. It does not close the PiDEC, PiRLC, PiCCS, terminal CE, or full
SuperNeo composition theorem groups.

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

Documentation must not use `completed formal protocol theorem` until the PiDEC,
PiRLC, PiCCS, terminal CE, and final SuperNeo verifier-acceptance composition
theorem groups are closed.

## Build

When Lean is installed through elan, run:

```sh
cd Formal
lake build
```

The CI workflow `Formal Status` runs `lake build`, validates the status
manifest, and runs the mutation-regression harness for changes touching
`Formal/`, the manifest, validator scripts, or status-bearing docs.
