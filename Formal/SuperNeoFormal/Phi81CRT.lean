import SuperNeoFormal.Phi81Split

/-!
Concrete CRT decomposition for the Phi81 quotient ring.

`Phi81Split.lean` proves the concrete factorization

`X^54 + X^27 + 1 = (X^27 - a) * (X^27 + b)`.

This file turns that factorization into the algebraic object needed by the
PiRLC collision program: the Chinese-remainder homomorphism from `Phi81` into
the product of the two degree-27 quotient rings, together with injectivity and
zero-reflection lemmas.  The two degree-27 factors are proved irreducible using
the Kummer prime-power criterion plus concrete non-cube witnesses in the
Goldilocks field, so both CRT components are available as fields for
componentwise collision arguments.
-/

noncomputable section

namespace SuperNeoFormal

open Polynomial

def phi81CRTLeftRadicand : Goldilocks :=
  phi81SplitLeftConstant

def phi81CRTRightRadicand : Goldilocks :=
  -phi81SplitRightConstant

def phi81CRTLeftPolynomial : Polynomial Goldilocks :=
  X ^ 27 - C phi81CRTLeftRadicand

def phi81CRTRightPolynomial : Polynomial Goldilocks :=
  X ^ 27 + C phi81SplitRightConstant

theorem phi81CRTRightPolynomial_eq_X_pow_sub_C :
    phi81CRTRightPolynomial = X ^ 27 - C phi81CRTRightRadicand := by
  simp [phi81CRTRightPolynomial, phi81CRTRightRadicand]

def phi81CRTLeftIdeal : Ideal (Polynomial Goldilocks) :=
  Ideal.span ({phi81CRTLeftPolynomial} : Set (Polynomial Goldilocks))

def phi81CRTRightIdeal : Ideal (Polynomial Goldilocks) :=
  Ideal.span ({phi81CRTRightPolynomial} : Set (Polynomial Goldilocks))

abbrev Phi81CRTLeft :=
  Polynomial Goldilocks ⧸ phi81CRTLeftIdeal

abbrev Phi81CRTRight :=
  Polynomial Goldilocks ⧸ phi81CRTRightIdeal

def phi81CRTLeftX : Phi81CRTLeft :=
  Ideal.Quotient.mk phi81CRTLeftIdeal X

def phi81CRTRightX : Phi81CRTRight :=
  Ideal.Quotient.mk phi81CRTRightIdeal X

theorem phi81CRT_factorization :
    phi81Polynomial = phi81CRTLeftPolynomial * phi81CRTRightPolynomial := by
  simpa [phi81CRTLeftPolynomial, phi81CRTRightPolynomial, phi81CRTLeftRadicand]
    using phi81Polynomial_factor_goldilocks

theorem phi81CRTLeftRadicand_pow_div_three_ne_one :
    phi81CRTLeftRadicand ^ ((goldilocksModulus - 1) / 3) ≠ 1 := by
  native_decide

theorem phi81CRTRightRadicand_pow_div_three_ne_one :
    phi81CRTRightRadicand ^ ((goldilocksModulus - 1) / 3) ≠ 1 := by
  native_decide

theorem phi81CRTLeftRadicand_ne_zero :
    phi81CRTLeftRadicand ≠ 0 := by
  native_decide

theorem phi81CRTRightRadicand_ne_zero :
    phi81CRTRightRadicand ≠ 0 := by
  native_decide

theorem phi81CRTLeftRadicand_not_cube
    (value : Goldilocks) :
    value ^ 3 ≠ phi81CRTLeftRadicand := by
  intro hCube
  have hValueNonzero : value ≠ 0 := by
    intro hValueZero
    exact phi81CRTLeftRadicand_ne_zero (by simpa [hValueZero] using hCube.symm)
  have hExponent :
      3 * ((goldilocksModulus - 1) / 3) = goldilocksModulus - 1 := by
    native_decide
  have hPow :
      phi81CRTLeftRadicand ^ ((goldilocksModulus - 1) / 3) = 1 := by
    calc
      phi81CRTLeftRadicand ^ ((goldilocksModulus - 1) / 3)
          = (value ^ 3) ^ ((goldilocksModulus - 1) / 3) := by
            rw [hCube]
      _ = value ^ (3 * ((goldilocksModulus - 1) / 3)) := by
            rw [pow_mul]
      _ = value ^ (goldilocksModulus - 1) := by
            rw [hExponent]
      _ = 1 := ZMod.pow_card_sub_one_eq_one hValueNonzero
  exact phi81CRTLeftRadicand_pow_div_three_ne_one hPow

theorem phi81CRTRightRadicand_not_cube
    (value : Goldilocks) :
    value ^ 3 ≠ phi81CRTRightRadicand := by
  intro hCube
  have hValueNonzero : value ≠ 0 := by
    intro hValueZero
    exact phi81CRTRightRadicand_ne_zero (by simpa [hValueZero] using hCube.symm)
  have hExponent :
      3 * ((goldilocksModulus - 1) / 3) = goldilocksModulus - 1 := by
    native_decide
  have hPow :
      phi81CRTRightRadicand ^ ((goldilocksModulus - 1) / 3) = 1 := by
    calc
      phi81CRTRightRadicand ^ ((goldilocksModulus - 1) / 3)
          = (value ^ 3) ^ ((goldilocksModulus - 1) / 3) := by
            rw [hCube]
      _ = value ^ (3 * ((goldilocksModulus - 1) / 3)) := by
            rw [pow_mul]
      _ = value ^ (goldilocksModulus - 1) := by
            rw [hExponent]
      _ = 1 := ZMod.pow_card_sub_one_eq_one hValueNonzero
  exact phi81CRTRightRadicand_pow_div_three_ne_one hPow

theorem phi81CRTLeftPolynomial_irreducible :
    Irreducible phi81CRTLeftPolynomial := by
  have hPrime : Nat.Prime 3 := by decide
  have hNotTwo : (3 : Nat) ≠ 2 := by decide
  have hPowerNonzero : (3 : Nat) ≠ 0 := by decide
  simpa [phi81CRTLeftPolynomial, phi81CRTLeftRadicand] using
    (X_pow_sub_C_irreducible_iff_of_prime_pow
      (K := Goldilocks)
      hPrime
      hNotTwo
      (n := 3)
      hPowerNonzero
      (a := phi81CRTLeftRadicand)).mpr
        phi81CRTLeftRadicand_not_cube

theorem phi81CRTRightPolynomial_irreducible :
    Irreducible phi81CRTRightPolynomial := by
  have hPrime : Nat.Prime 3 := by decide
  have hNotTwo : (3 : Nat) ≠ 2 := by decide
  have hPowerNonzero : (3 : Nat) ≠ 0 := by decide
  rw [phi81CRTRightPolynomial_eq_X_pow_sub_C]
  simpa using
    (X_pow_sub_C_irreducible_iff_of_prime_pow
      (K := Goldilocks)
      hPrime
      hNotTwo
      (n := 3)
      hPowerNonzero
      (a := phi81CRTRightRadicand)).mpr
        phi81CRTRightRadicand_not_cube

instance phi81CRTLeftPolynomial_irreducible_fact :
    Fact (Irreducible phi81CRTLeftPolynomial) :=
  ⟨phi81CRTLeftPolynomial_irreducible⟩

instance phi81CRTRightPolynomial_irreducible_fact :
    Fact (Irreducible phi81CRTRightPolynomial) :=
  ⟨phi81CRTRightPolynomial_irreducible⟩

noncomputable instance phi81CRTLeftField : Field Phi81CRTLeft := by
  change Field (AdjoinRoot phi81CRTLeftPolynomial)
  infer_instance

noncomputable instance phi81CRTRightField : Field Phi81CRTRight := by
  change Field (AdjoinRoot phi81CRTRightPolynomial)
  infer_instance

theorem phi81CRTLeft_isUnit_of_ne_zero
    {value : Phi81CRTLeft}
    (hValue : value ≠ 0) :
    IsUnit value :=
  isUnit_iff_ne_zero.mpr hValue

theorem phi81CRTRight_isUnit_of_ne_zero
    {value : Phi81CRTRight}
    (hValue : value ≠ 0) :
    IsUnit value :=
  isUnit_iff_ne_zero.mpr hValue

theorem phi81CRT_constants_sum_ne_zero :
    phi81SplitLeftConstant + phi81SplitRightConstant ≠ 0 := by
  native_decide

theorem phi81CRT_ideals_coprime :
    IsCoprime phi81CRTLeftIdeal phi81CRTRightIdeal := by
  rw [Ideal.isCoprime_iff_exists]
  let scale : Goldilocks :=
    (phi81SplitLeftConstant + phi81SplitRightConstant)⁻¹
  refine
    ⟨-C scale * phi81CRTLeftPolynomial, ?_,
      C scale * phi81CRTRightPolynomial, ?_, ?_⟩
  · exact Ideal.mul_mem_left _ _ (Ideal.subset_span (by simp [phi81CRTLeftPolynomial]))
  · exact Ideal.mul_mem_left _ _ (Ideal.subset_span (by simp [phi81CRTRightPolynomial]))
  · have hScale :
        scale * (phi81SplitLeftConstant + phi81SplitRightConstant) = 1 := by
      exact inv_mul_cancel₀ phi81CRT_constants_sum_ne_zero
    calc
      -C scale * phi81CRTLeftPolynomial + C scale * phi81CRTRightPolynomial
          = C scale * C (phi81SplitLeftConstant + phi81SplitRightConstant) := by
            simp [phi81CRTLeftPolynomial, phi81CRTLeftRadicand,
              phi81CRTRightPolynomial]
            ring
      _ = 1 := by
            rw [← map_mul, hScale]
            simp

theorem phi81CRT_ideal_product_eq_phi81Ideal :
    phi81CRTLeftIdeal * phi81CRTRightIdeal = phi81Ideal := by
  rw [phi81CRTLeftIdeal, phi81CRTRightIdeal, phi81Ideal]
  rw [Ideal.span_singleton_mul_span_singleton]
  rw [← phi81CRT_factorization]

theorem phi81Ideal_eq_phi81CRT_ideal_product :
    phi81Ideal = phi81CRTLeftIdeal * phi81CRTRightIdeal :=
  phi81CRT_ideal_product_eq_phi81Ideal.symm

def phi81CRTQuotientEquiv :
    Phi81 ≃+* Phi81CRTLeft × Phi81CRTRight :=
  (Ideal.quotEquivOfEq phi81Ideal_eq_phi81CRT_ideal_product).trans
    (Ideal.quotientMulEquivQuotientProd
      phi81CRTLeftIdeal
      phi81CRTRightIdeal
      phi81CRT_ideals_coprime)

def phi81CRTHom : Phi81 →+* Phi81CRTLeft × Phi81CRTRight :=
  phi81CRTQuotientEquiv.toRingHom

def phi81CRTLeftProjection : Phi81 →+* Phi81CRTLeft :=
  (RingHom.fst Phi81CRTLeft Phi81CRTRight).comp phi81CRTHom

def phi81CRTRightProjection : Phi81 →+* Phi81CRTRight :=
  (RingHom.snd Phi81CRTLeft Phi81CRTRight).comp phi81CRTHom

theorem phi81CRTQuotientEquiv_mk (p : Polynomial Goldilocks) :
    phi81CRTQuotientEquiv (Ideal.Quotient.mk phi81Ideal p) =
      (Ideal.Quotient.mk phi81CRTLeftIdeal p,
        Ideal.Quotient.mk phi81CRTRightIdeal p) := by
  rfl

@[simp]
theorem phi81CRTLeftProjection_mk (p : Polynomial Goldilocks) :
    phi81CRTLeftProjection (Ideal.Quotient.mk phi81Ideal p) =
      Ideal.Quotient.mk phi81CRTLeftIdeal p := by
  rfl

@[simp]
theorem phi81CRTRightProjection_mk (p : Polynomial Goldilocks) :
    phi81CRTRightProjection (Ideal.Quotient.mk phi81Ideal p) =
      Ideal.Quotient.mk phi81CRTRightIdeal p := by
  rfl

theorem phi81CRTHom_injective :
    Function.Injective phi81CRTHom :=
  phi81CRTQuotientEquiv.injective

theorem phi81CRT_zero_of_components_zero
    {value : Phi81}
    (hLeft : phi81CRTLeftProjection value = 0)
    (hRight : phi81CRTRightProjection value = 0) :
    value = 0 := by
  apply phi81CRTHom_injective
  ext <;> assumption

theorem phi81CRT_nonzero_has_nonzero_component
    {value : Phi81}
    (hNonzero : value ≠ 0) :
    phi81CRTLeftProjection value ≠ 0 ∨
      phi81CRTRightProjection value ≠ 0 := by
  by_contra hNoComponent
  push_neg at hNoComponent
  exact hNonzero
    (phi81CRT_zero_of_components_zero
      hNoComponent.1
      hNoComponent.2)

theorem phi81CRTLeft_X27_eq_constant :
    phi81CRTLeftX ^ 27 =
      algebraMap Goldilocks Phi81CRTLeft phi81SplitLeftConstant := by
  have hRel :
      (Ideal.Quotient.mk phi81CRTLeftIdeal phi81CRTLeftPolynomial :
          Phi81CRTLeft) = 0 := by
    rw [Ideal.Quotient.eq_zero_iff_mem]
    exact Ideal.subset_span (by simp [phi81CRTLeftPolynomial])
  have hSub :
      phi81CRTLeftX ^ 27 -
        algebraMap Goldilocks Phi81CRTLeft phi81SplitLeftConstant = 0 := by
    simpa [phi81CRTLeftPolynomial, phi81CRTLeftRadicand, phi81CRTLeftX, map_sub, map_pow,
      Polynomial.C_eq_algebraMap,
      Ideal.Quotient.mk_algebraMap (R₁ := Goldilocks)] using hRel
  exact sub_eq_zero.mp hSub

theorem phi81CRTRight_X27_eq_neg_constant :
    phi81CRTRightX ^ 27 =
      -algebraMap Goldilocks Phi81CRTRight phi81SplitRightConstant := by
  have hRel :
      (Ideal.Quotient.mk phi81CRTRightIdeal phi81CRTRightPolynomial :
          Phi81CRTRight) = 0 := by
    rw [Ideal.Quotient.eq_zero_iff_mem]
    exact Ideal.subset_span (by simp [phi81CRTRightPolynomial])
  have hAdd :
      phi81CRTRightX ^ 27 +
        algebraMap Goldilocks Phi81CRTRight phi81SplitRightConstant = 0 := by
    simpa [phi81CRTRightPolynomial, phi81CRTRightX, map_add, map_pow,
      Polynomial.C_eq_algebraMap,
      Ideal.Quotient.mk_algebraMap (R₁ := Goldilocks)] using hRel
  exact eq_neg_of_add_eq_zero_left hAdd

def phi81CRTLeftComponentBadValues
    {count : Nat}
    [DecidableEq Phi81CRTLeft]
    (support : Finset Phi81CRTLeft)
    (fixedChallenges : Fin count → Phi81CRTLeft)
    (pivot : Fin count)
    (deltas : Fin count → Phi81CRTLeft) :
    Finset Phi81CRTLeft :=
  scalarRLCBadPivotValues support fixedChallenges pivot deltas

def phi81CRTRightComponentBadValues
    {count : Nat}
    [DecidableEq Phi81CRTRight]
    (support : Finset Phi81CRTRight)
    (fixedChallenges : Fin count → Phi81CRTRight)
    (pivot : Fin count)
    (deltas : Fin count → Phi81CRTRight) :
    Finset Phi81CRTRight :=
  scalarRLCBadPivotValues support fixedChallenges pivot deltas

theorem phi81CRTLeftComponentBadValues_card_le_one
    {count : Nat}
    [DecidableEq Phi81CRTLeft]
    (support : Finset Phi81CRTLeft)
    (fixedChallenges : Fin count → Phi81CRTLeft)
    (pivot : Fin count)
    (deltas : Fin count → Phi81CRTLeft)
    (hPivot : deltas pivot ≠ 0) :
    (phi81CRTLeftComponentBadValues
      support
      fixedChallenges
      pivot
      deltas).card ≤ 1 :=
  scalarRLCBadPivotValues_card_le_one
    support
    fixedChallenges
    pivot
    deltas
    hPivot

theorem phi81CRTRightComponentBadValues_card_le_one
    {count : Nat}
    [DecidableEq Phi81CRTRight]
    (support : Finset Phi81CRTRight)
    (fixedChallenges : Fin count → Phi81CRTRight)
    (pivot : Fin count)
    (deltas : Fin count → Phi81CRTRight)
    (hPivot : deltas pivot ≠ 0) :
    (phi81CRTRightComponentBadValues
      support
      fixedChallenges
      pivot
      deltas).card ≤ 1 :=
  scalarRLCBadPivotValues_card_le_one
    support
    fixedChallenges
    pivot
    deltas
    hPivot

end SuperNeoFormal
