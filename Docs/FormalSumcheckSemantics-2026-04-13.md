# Formal Sum-Check Semantics Progress, 2026-04-13

Formal status: conditional protocol formalization

This pass adds a concrete semantic base for the sum-check track without claiming
probabilistic soundness yet.

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

- `SuperNeoFormal.PiCCSSoundness`
  - Defines when a PiCCS public-Q state matches an exact public-Q oracle.
  - Proves that an accepted PiCCS trace whose sum-check rounds match the exact
    oracle has a final claim equal to the exact public-Q evaluation.
  - Proves `piccs_exact_q_reduction`, which packages claimed-sum agreement,
    final public-Q equality, and final-claim consistency.

## What remains open

The verifier-side sum-check track now has the deterministic exact-oracle
theorem, but it is still not a full probabilistic soundness theorem. The next
required steps are degree-bounded univariate round polynomials, interpolation
from serialized round-polynomial coefficients, construction of the actual PiCCS
public-Q oracle from CCS and prior CE claims, and a finite-field Schwartz-Zippel
or explicitly assumed probability bound.
