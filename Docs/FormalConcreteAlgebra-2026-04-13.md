# Formal Concrete Algebra Progress, 2026-04-13

Formal status: completed formal protocol theorem.

This pass moves the Lean track from a purely abstract ring profile toward the
implemented Goldilocks/Phi81 profile without weakening the existing assumption
boundaries.

## Added Lean modules

- `SuperNeoFormal.Goldilocks`
  - Defines `Goldilocks := ZMod 18446744069414584321`.
  - Proves the Swift modulus equivalences:
    `0xFFFF_FFFF_0000_0001` and `2^64 - 2^32 + 1`.
  - Proves primality with a Lucas certificate using witness `7` and the checked
    prime-factor set `{2, 3, 5, 17, 257, 65537}` for `p - 1`.
  - Installs the `Fact (Nat.Prime goldilocksModulus)` needed for the Lean field
    instance.

- `SuperNeoFormal.Phi81`
  - Defines the quotient ring
    `Polynomial Goldilocks ⧸ Ideal.span {X^54 + X^27 + 1}`.
  - Defines the degree-54 coefficient representation used by
    `CyclotomicRing54`.
  - Proves the quotient identities `X^54 = -X^27 - 1`, `X^81 = 1`, and
    `X^108 = X^27`.
  - Proves additive, negation, and subtraction compatibility from the
    coefficient model into the quotient.
  - Defines the product monomial-contribution table matching Swift's direct
    product reduction branches for degree-54 inputs.
  - Proves each product-reduction monomial has the same quotient meaning as
    `X^e` for all product exponents `e < 108`.
  - Proves the full bilinear compatibility theorem
    `phi81SwiftMulCoeffs_toQuotient_mul`, connecting Swift-shaped
    coefficient multiplication to quotient-ring multiplication for all
    degree-54 coefficient vectors.

- `SuperNeoFormal.Embedding`
  - Formalizes exact field-vector packing into 54-coefficient ring columns.
  - Formalizes Swift-style padded packing by zero-extending the final block.
  - Proves exact pack/unpack inverses.
  - Proves coefficient-bound preservation for exact and padded packing.

- `SuperNeoFormal.ModuleSIS`
  - Packages the concrete Module-SIS profile and estimator tuple:
    modulus `p`, degree `54`, rank `18`, coefficient dimension `972`, estimator
    length `2^30`, and claimed threshold `129` bits.
  - Names the concrete no-short-kernel predicate over `AjtaiMatrix Phi81 kappa`.

- `SuperNeoFormal.ConcreteAjtai`
  - Specializes Ajtai messages, matrices, commitments, openings, binding
    predicate shape, and commitment linearity to the concrete Phi81 ring and
    `kappa = 18`.
  - Connects exact field-witness packing to concrete Ajtai commitment shape.
  - Tracks concrete Ajtai shape, quotient-ring multiplication wiring, packed
    field-witness wiring, and concrete commitment row equations as closed
    deterministic instantiation facts.
  - Tracks concrete opening and binding predicate equivalence to the generic
    Ajtai model as a closed `concrete-ajtai-opening-core`.
  - Keeps only theorems that consume the concrete Module-SIS no-short-kernel
    predicate under the MSIS assumption boundary.

## What remains open

This is not yet an unconditional protocol theorem. The top-level label remains
conditional because PiRLC probability, PiCCS/sum-check soundness, terminal CE
opening soundness, and Fiat-Shamir remain represented by explicit formal
assumption surfaces.

The full multiplication equivalence proof between the coefficient product model
and quotient multiplication for all degree-54 coefficient vectors is now closed
by `phi81SwiftMulCoeffs_toQuotient_mul`. Remaining concrete-algebra work is
still needed around byte/Swift conformance: generated constant synchronization,
serialization injectivity, and a proof that Swift's concrete memory layout
feeds exactly this coefficient model.
