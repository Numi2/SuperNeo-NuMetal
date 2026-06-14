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
probability accounting exists over explicit bad challenge/seed sets. PiRLC now
has concrete folded-claim linear observations, finite observation-family
bad-seed accounting with an explicit family-cardinality multiplier, and a direct
certificate for the selected public-fields-zero relation.

## Status Manifest

`Docs/FormalStatus.json` records the theorem groups and the Lean declarations
they are meant to track. For active development, build the formal workspace and
run the executable formal vector checks:

```sh
cd Formal
lake build
lake build SuperNeoFormal.VectorChecks
lake env lean --run ProofImportWall.lean
lake env lean --run SuperNeoFormalVectorCheck.lean
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
  constant-trace model used by
  `TestVectors/Archive/compliance/constant-time-scope-v1.json` and proves trace
  independence for the checked fixed schedules.

## Build

When Lean is installed through elan, run:

```sh
cd Formal
lake build
```

The manual CI workflow `Formal Status` runs `lake build` and the executable
formal vector checks. Treat it as proof-work verification, not a documentation
promotion gate.
