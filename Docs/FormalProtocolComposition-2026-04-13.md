# Formal Protocol Composition Pass, 2026-04-13

Formal status: conditional protocol formalization.

This pass replaces the remaining planned Lean roadmap markers with explicit
assumption-scoped theorem surfaces for PiRLC, PiCCS/sum-check, terminal CE, and
the top-level SuperNeo verifier composition.

## Work Completed

- `Formal/SuperNeoFormal/Sumcheck.lean` models the verifier's sum-check round
  skeleton: initial claim binding, each `g_i(0) + g_i(1)` consistency check, the
  challenge-updated running claim, and final oracle check.
- `Formal/SuperNeoFormal/PiCCS.lean` models the public Q final-check boundary
  used by PiCCS and proves the accepted trace exposes the expected final Q value
  and final-claim consistency predicate.
- `Formal/SuperNeoFormal/PiRLC.lean` models weighted random-linear-combination
  claims and proves the Ajtai commitment opening recomposes under the same
  weighted sum used by the Swift verifier.
- `Formal/SuperNeoFormal/TerminalCE.lean` models terminal CE batch openings and
  the explicit soundness boundary for the public CE opening proof verifier.
- `Formal/SuperNeoFormal/Composition.lean` models the verifier's terminal
  acceptance shape: accepted fold reduction, terminal statement/output match,
  and accepted terminal CE opening verification.

## Status Model

`Docs/FormalStatus.json` now tracks these theorem groups as closed under explicit
assumptions instead of `planned`:

- `pirlc-soundness-assumptions`: random-linear-combination soundness assumption.
- `piccs-sumcheck-model`: sum-check/public-Q soundness assumption.
- `terminal-ce-relation`: CE opening proof soundness assumption.
- `superneo-composition-theorem`: composition from the stage assumptions.

The manifest current label is `conditional protocol formalization`.
Documentation still must not claim `completed formal protocol theorem` because
that stricter label now requires every required theorem group to have status
`closed`, not merely `closed_under_*`.

## Trust Boundary

This is a real Lean formalization layer, not a roadmap marker. It is still
not an unconditional concrete cryptographic proof of the deployed system. The
Fiat-Shamir/random-linear-combination analysis, concrete sum-check soundness
probability, concrete CE opening proof soundness, and quotient-ring
instantiation remain represented as explicit assumptions rather than fully
mechanized probability and algebra proofs.
