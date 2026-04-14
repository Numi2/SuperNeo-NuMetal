# Formal Sum-Check Semantics Progress, 2026-04-13

Formal status: completed formal protocol theorem

This pass adds the concrete semantic base for the sum-check track. The April 14
completion adds the finite bad-challenge certificate surface used by the
completed formal status.

## Added Lean modules

- `SuperNeoFormal.Multilinear`
  - Defines Boolean hypercube points as `Fin n → Bool`.
  - Defines the multilinear basis factor used by Swift:
    `r` for bit `1`, and `1 - r` for bit `0`.
  - Defines multilinear extension as the sum over Boolean vertices.
  - Defines the equality-polynomial factor
    `1 - lhs - rhs + 2 * lhs * rhs`, matching Swift's
    `MultilinearEvaluation.eq`.
  - Proves that equality-polynomial factors with a Boolean left input are the
    multilinear basis factors.
  - Proves Boolean interpolation: evaluating the multilinear extension at a
    Boolean vertex returns that vertex's table value.
  - Proves equality-polynomial delta behavior on Boolean points.

- `SuperNeoFormal.SumcheckSoundness`
  - Defines a recursive Boolean-hypercube partial-sum semantics over verifier
    rounds.
  - Defines exact round polynomials as the partial sum after setting the next
    verifier variable.
  - Proves the exact round consistency equation
    `g_i(0) + g_i(1) = claim_i` for the concrete partial sums.
  - Proves challenge-prefix propagation across verifier rounds.
  - Proves `sumcheck_exact_oracle_final_claim`: if an accepted verifier trace
    uses the exact partial-sum oracle at every round, then the final claim is
    exactly the oracle evaluated at the verifier's challenge point.
  - Proves the corresponding final-check transfer theorem.
  - A later April 14 pass adds the finite-field low-degree root-count core:
    nonzero polynomials have at most `natDegree` roots in a finite challenge
    support, and supports larger than the degree bound contain a non-root.
  - The same April 14 narrowing adds polynomial agreement sets for prover/exact
    round-polynomial mismatches. If the prover and exact polynomials differ and
    both satisfy a degree bound, the support values where they evaluate equally
    are degree-bounded; a larger support contains a disagreeing challenge.

- `SuperNeoFormal.PiCCSSoundness`
  - Defines when a PiCCS public-Q state matches an exact public-Q oracle.
  - Proves that an accepted PiCCS trace whose sum-check rounds match the exact
    oracle has a final claim equal to the exact public-Q evaluation.
  - Proves `piccs_exact_q_reduction`, which packages claimed-sum agreement,
    final public-Q equality, and final-claim consistency.

## Completed Replacement

The verifier-side sum-check track now has the deterministic exact-oracle
theorem, finite-field root-count lemma, and degree-bounded agreement-set lemma,
plus `PiCCSFiniteBadChallengeCertificate`. The completed model states PiCCS
soundness outside an explicit finite bad-challenge set rather than as a
deterministic zero-error theorem for every accepted trace.
