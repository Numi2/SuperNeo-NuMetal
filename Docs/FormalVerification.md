# Formal Verification Track

Formal status: conditional protocol formalization.

The formal track lives under `Formal/` as a Lean 4 Lake workspace. It is
separate from the Sage/lattice-estimator workflow:

- Sage/lattice-estimator reproduces a heuristic Module-SIS security estimate for
  the translated SIS parameter object.
- Lean formalization records protocol-level algebraic statements, certified-key
  reductions, and finite bad-challenge/bad-seed exclusions.

The current Lean milestone is a conditional protocol formalization for the
corrected model: Ajtai binding is consumed through certified verifier keys, and
probabilistic PiRLC, PiCCS/sum-check, and terminal CE proof soundness are stated
outside explicitly finite bad challenge/seed sets. It covers profile constants,
derived parameter equalities, the strong-sampling inequality, concrete
Goldilocks/Phi81 algebra, GoldilocksExt2 wire operations, Phi81 factorization,
field-to-ring packing, the complete Lean `GoldilocksExt2` field instance,
concrete and certified Ajtai instantiation, PiDEC
recomposition, PiRLC weighted-claim recomposition, finite-support counting,
scalar and quotient-ring-safe collision facts, transcript-bound finite challenge
scheduling, PiCCS acceptance projections, the PiCCS exact public-Q bridge,
finite-field low-degree root counting, finite bad-challenge PiCCS soundness,
terminal CE statement and local batch algebra, finite bad-seed terminal CE proof
soundness, distinct-witness-to-short-kernel reductions, and end-to-end verifier
composition outside the CE bad-seed set.

The full theorem label is intentionally blocked by planned theorem groups for
full cryptographic probability composition, complete Swift serialization
equivalence for `GoldilocksExt2`, and a byte-for-byte Swift CE verifier
equivalence proof. The closure contracts for those remaining groups are tracked
in [Formal Completion Research Plan, 2026-04-14](FormalCompletionResearchPlan-2026-04-14.md).

The historical `closed_under_*` groups remain documented for auditability, but
the manifest now uses closed replacement group IDs for the mechanized
conditional path. The status validator rejects declaration reuse across theorem
groups, prevents boundary/assumption declarations from being marked closed, and
keeps the full theorem label tied to every conditional theorem-group dependency
plus the explicit planned blocker groups.

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
- full formal protocol theorem

Documentation may use the full theorem label only when every group on that path
is `closed`. Historical `closed_under_*` boundary IDs are replaced by closed
certified-key and finite-bad-seed groups on the conditional path.

Recent formal pass:

- [Formal Ajtai Binding, 2026-04-13](FormalAjtaiBinding-2026-04-13.md)
- [Formal PiDEC Recomposition, 2026-04-13](FormalPiDECRecomposition-2026-04-13.md)
- [Formal Protocol Composition, 2026-04-13](FormalProtocolComposition-2026-04-13.md)
- [Formal Assumption Ledger Split, 2026-04-14](FormalAssumptionLedger-2026-04-14.md)
- [Formal Remaining Boundaries, 2026-04-14](FormalRemainingBoundaries-2026-04-14.md)
- [Formal Completion Research Plan, 2026-04-14](FormalCompletionResearchPlan-2026-04-14.md)

## Build

When Lean is installed through elan, run:

```sh
cd Formal
lake build
```

The CI workflow `Formal Status` runs `lake build`, validates the status
manifest, and runs the mutation-regression harness for changes touching
`Formal/`, the manifest, validator scripts, or status-bearing docs.
