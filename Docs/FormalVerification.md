# Formal Verification Track

Formal status: completed formal protocol theorem.

The formal track lives under `Formal/` as a Lean 4 Lake workspace. It is
separate from the Sage/lattice-estimator workflow:

- Sage/lattice-estimator reproduces a heuristic Module-SIS security estimate for
  the translated SIS parameter object.
- Lean formalization records protocol-level algebraic statements, certified-key
  reductions, and finite bad-challenge/bad-seed exclusions.

The current Lean milestone is a completed formal protocol theorem for the
finite model. Ajtai binding is consumed through certified
verifier keys, transcript byte injectivity is theorem-facing only for
well-formed length-counted transcript states, theorem-critical bindings have a
384-bit typed digest layer, and finite PiRLC/PiCCS/terminal-CE/transcript
probability accounting exists over explicit bad challenge/seed sets. The active
status keeps the two former integration IDs in `Docs/FormalStatus.json` as
closed promotion gates: constructive terminal CE localization instantiation for
the concrete Swift/Fiat-Shamir tape and CRT-based PiRLC finite-soundness
completion. PiRLC now has concrete folded-claim linear observations, finite
observation-family bad-seed accounting with an explicit family-cardinality
multiplier, and a direct certificate for the selected public-fields-zero
relation.

The historical `closed_under_*` groups remain documented for auditability, but
the manifest now uses corrected-core group IDs plus closed integration gates.
The status validator rejects declaration reuse across theorem groups, prevents
boundary/assumption declarations from being promoted into completed-theorem
groups, and rejects documentation that claims the completed label unless the
promotion gates are closed.

## Status Manifest

`Docs/FormalStatus.json` is the source of truth for documentation labels. The
validator checks that docs do not claim a stronger status than the manifest
supports, resolves each declared Lean module to its source file, and requires
closed theorem groups to reference declarations that are present in that module:

```sh
Scripts/legacy-gates/validate-formal-status.py
```

The regression harness mutates temporary manifest copies and confirms the
validator fails closed for missing integration gates, non-closed integration
gates at promotion, missing declarations, closed groups without any declaration,
assumption/boundary declarations in stronger-label groups, documentation
overclaims, and completed-label dependency drift:

```sh
Scripts/legacy-gates/test-formal-status-validation.py
```

Allowed labels are:

- `bounded formalization`
- `partial formalization`
- `conditional protocol formalization`
- `corrected finite-model core with open theorem-critical integrations`
- `completed formal protocol theorem`

The completed formal protocol theorem label is active only when every group on
that path is `closed`. Historical `closed_under_*` boundary IDs are retained
only as audit history, not as active manifest groups.

Recent formal pass:

- [Formal PiDEC Recomposition, 2026-04-13](FormalPiDECRecomposition-2026-04-13.md)
- [Formal Protocol Composition, 2026-04-13](FormalProtocolComposition-2026-04-13.md)
- [Formal Assumption Ledger Split, 2026-04-14](FormalAssumptionLedger-2026-04-14.md)
- [Formal Remaining Boundaries, 2026-04-14](FormalRemainingBoundaries-2026-04-14.md)
- [Formal Completion Research Plan, 2026-04-14](FormalCompletionResearchPlan-2026-04-14.md)
- `Formal/SuperNeoFormal/NumiSealSumcheckTranscript.lean` now names the dense
  NumiSeal sum-check transcript domain and absorb-frame order used by the Swift
  prover/verifier.
- `Formal/SuperNeoFormal/WellFormedTranscript.lean` now provides the
  theorem-facing transcript object and byte-injectivity theorem for
  length-counted transcript states.
- `Formal/SuperNeoFormal/Digest384Serialization.lean` and
  `Formal/SuperNeoFormal/TypedDigestSemantics.lean` now provide 384-bit
  theorem-critical binding encodings and typed digest-domain separation.
- `Formal/SuperNeoFormal/PiCCSConstructiveFiniteSoundness.lean` and
  `Formal/SuperNeoFormal/TerminalCEConstructiveFiniteSoundness.lean` are the
  constructive finite bad-set theorem surfaces for PiCCS and terminal CE.
- `Formal/SuperNeoFormal/ConstantTime.lean` now defines the conditional
  constant-trace model used by `TestVectors/constant-time-scope-v1.json` and
  proves trace independence for the checked fixed schedules.

## Build

When Lean is installed through elan, run:

```sh
cd Formal
lake build
```

The CI workflow `Formal Status` runs `lake build`, validates the status
manifest, and runs the mutation-regression harness for changes touching
`Formal/`, the manifest, validator scripts, or status-bearing docs.
