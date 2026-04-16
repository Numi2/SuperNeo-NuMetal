# Formal GoldilocksExt2 Field Instance

Formal status: completed formal protocol theorem.

This pass closes the Lean-side `GoldilocksExt2` field-instance blocker without
changing the public status label. The implementation keeps the existing Swift
shape, `c0 + c1 u` with `u^2 = 7`, and transfers mathlib's
`QuadraticAlgebra Goldilocks 7 0` field instance onto the existing `c0/c1`
structure.

The proof obligation is now explicit:

- `7` is nonzero in the Goldilocks base field.
- The Lucas witness already used for primality also proves
  `7 ^ (#Goldilocks / 2) != 1`.
- Mathlib's finite-field square criterion turns that exponent check into
  `not IsSquare 7`.
- The no-square-root fact satisfies the root-free hypothesis required by
  mathlib's quadratic-algebra field instance.

The transferred field operations are then tied back to the repository's
concrete model:

- `0`, `1`, addition, negation, subtraction, and multiplication match the
  existing `goldilocksExt2*` definitions.
- Multiplication still matches the Swift Karatsuba expression:
  `(a0 + a1) * (b0 + b1) - a0*b0 - a1*b1` for the extension coefficient.
- The denominator `c0^2 - c1^2 * 7` is identified with the quadratic norm, so
  every nonzero `GoldilocksExt2` value has a nonzero denominator and therefore
  the explicit inverse-certificate surface is populated from the real field
  proof.

This does not close Swift serialization equivalence. Lean now proves that the
field exists and that its operations match the modeled formulas, but the
byte-for-byte Swift caller graph and CE verifier parser equivalence remain
separate planned blockers.
