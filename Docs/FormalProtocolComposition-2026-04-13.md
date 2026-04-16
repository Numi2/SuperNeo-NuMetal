# Formal Protocol Composition Pass, 2026-04-13

Formal status: completed formal protocol theorem.

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
assumptions instead of `planned`. A later 2026-04-14 assumption-ledger split
separates their deterministic cores from the remaining boundaries:

- `pirlc-recomposition-core`, `pirlc-finite-support-core`, and
  `pirlc-scalar-collision-core` are closed; the quotient-ring folded-claim
  collision certificate remains in `pirlc-collision-bound-boundary`.
- `piccs-acceptance-core` and `piccs-deterministic-sumcheck-bridge` are closed;
  `sumcheck-low-degree-root-count-core` closes the finite-field root-count
  lemma; `piccs-sumcheck-boundary` remains scoped to the remaining
  trace/oracle low-degree and probabilistic sum-check argument.
- `ce-opening-local-relation`, `terminal-ce-statement-core`, and
  `terminal-ce-local-batch` are closed local algebra. Witness uniqueness from a
  no-short-kernel premise is tracked separately in
  `ce-opening-binding-boundary`, and `terminal-ce-proof-soundness-boundary`
  remains CE-opening scoped.
- Terminal proof acceptance itself is tracked as the closed
  `terminal-ce-proof-acceptance-core`; only proof-verifier soundness remains in
  `terminal-ce-proof-soundness-boundary`.
- `superneo-deterministic-composition` is closed. The proof-carrying
  end-to-end theorem is now tracked in
  `superneo-ce-opening-composition-boundary`, which depends directly on the CE
  opening soundness boundary rather than a separate aggregate stage assumption.

The manifest current label is `conditional protocol formalization`.
Documentation still must not claim the full formal protocol theorem because
that stricter label now requires every required theorem group to have status
`closed`, not merely `closed_under_*`.

## Trust Boundary

This is a real Lean formalization layer, not a roadmap marker. It is still
not an unconditional concrete cryptographic proof of the deployed system. The
Fiat-Shamir/random-linear-combination analysis, concrete sum-check soundness
probability, concrete CE opening proof soundness, and quotient-ring
instantiation remain represented as explicit assumptions rather than fully
mechanized probability and algebra proofs.
