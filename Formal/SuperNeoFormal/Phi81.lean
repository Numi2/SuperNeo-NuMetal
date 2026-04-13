import SuperNeoFormal.Goldilocks

/-!
Concrete Phi81 ring profile.

Swift's `CyclotomicRing54` stores degree-54 Goldilocks coefficients and reduces
with

`X^54 = -X^27 - 1`

for `Phi_81(X) = X^54 + X^27 + 1`.  This module exposes both the quotient ring
and the coefficient-level operation shape used by Swift/Metal.
-/

noncomputable section

namespace SuperNeoFormal

open Finset Polynomial

def phi81Polynomial : Polynomial Goldilocks :=
  X ^ phi81Degree + X ^ (phi81Degree / 2) + 1

def phi81Ideal : Ideal (Polynomial Goldilocks) :=
  Ideal.span ({phi81Polynomial} : Set (Polynomial Goldilocks))

abbrev Phi81 :=
  Polynomial Goldilocks ⧸ phi81Ideal

abbrev Phi81Coefficients :=
  Fin phi81Degree → Goldilocks

def phi81X : Phi81 :=
  Ideal.Quotient.mk phi81Ideal X

def phi81CoeffsToPolynomial (coefficients : Phi81Coefficients) : Polynomial Goldilocks :=
  ∑ index : Fin phi81Degree, C (coefficients index) * X ^ index.val

def phi81CoeffsToQuotient (coefficients : Phi81Coefficients) : Phi81 :=
  Ideal.Quotient.mk phi81Ideal (phi81CoeffsToPolynomial coefficients)

def phi81ZeroCoeffs : Phi81Coefficients :=
  fun _ => 0

def phi81OneCoeffs : Phi81Coefficients :=
  fun index => if index.val = 0 then 1 else 0

def phi81SwiftAddCoeffs (lhs rhs : Phi81Coefficients) : Phi81Coefficients :=
  fun index => lhs index + rhs index

def phi81SwiftNegCoeffs (value : Phi81Coefficients) : Phi81Coefficients :=
  fun index => -value index

def phi81SwiftSubCoeffs (lhs rhs : Phi81Coefficients) : Phi81Coefficients :=
  fun index => lhs index - rhs index

/--
Coefficient contribution of `X^exponent` to a target coefficient after the
single-pass product reduction used by Swift for exponents `0 ≤ exponent ≤ 106`.
The final branch is kept total; product code never reaches it for degree-54
inputs.
-/
def phi81ProductMonomialContribution (target : Fin phi81Degree) (exponent : Nat) : Goldilocks :=
  if exponent < phi81Degree then
    if target.val = exponent then 1 else 0
  else if exponent < phi81Degree + phi81Degree / 2 then
    (if target.val = exponent - phi81Degree then -1 else 0) +
      (if target.val = exponent - phi81Degree / 2 then -1 else 0)
  else if exponent < 2 * phi81Degree then
    if target.val = exponent - phi81Degree - phi81Degree / 2 then 1 else 0
  else
    0

def phi81SwiftMulCoeffs (lhs rhs : Phi81Coefficients) : Phi81Coefficients :=
  fun target =>
    ∑ left : Fin phi81Degree,
      ∑ right : Fin phi81Degree,
        phi81ProductMonomialContribution target (left.val + right.val) *
          lhs left * rhs right

theorem phi81_relation :
    phi81X ^ 54 + phi81X ^ 27 + 1 = 0 := by
  have hRel : (Ideal.Quotient.mk phi81Ideal phi81Polynomial : Phi81) = 0 := by
    rw [Ideal.Quotient.eq_zero_iff_mem]
    exact Ideal.subset_span (by simp)
  simpa [phi81Polynomial, phi81Degree, phi81X] using hRel

theorem phi81_X54_eq :
    phi81X ^ 54 = -phi81X ^ 27 - 1 := by
  have h := phi81_relation
  linear_combination h

theorem phi81_X81_eq_one :
    phi81X ^ 81 = 1 := by
  have h := phi81_relation
  have hm : (phi81X ^ 27 - 1) * (phi81X ^ 54 + phi81X ^ 27 + 1) = 0 := by
    rw [h, mul_zero]
  have hz : phi81X ^ 81 - 1 = 0 := by
    calc
      phi81X ^ 81 - 1 =
          (phi81X ^ 27 - 1) * (phi81X ^ 54 + phi81X ^ 27 + 1) := by
        ring
      _ = 0 := hm
  exact sub_eq_zero.mp hz

theorem phi81_X108_eq_X27 :
    phi81X ^ 108 = phi81X ^ 27 := by
  calc
    phi81X ^ 108 = (phi81X ^ 81) * (phi81X ^ 27) := by ring
    _ = phi81X ^ 27 := by rw [phi81_X81_eq_one, one_mul]

theorem phi81CoeffsToPolynomial_zero :
    phi81CoeffsToPolynomial phi81ZeroCoeffs = 0 := by
  simp [phi81CoeffsToPolynomial, phi81ZeroCoeffs]

theorem phi81CoeffsToPolynomial_one :
    phi81CoeffsToPolynomial phi81OneCoeffs = 1 := by
  rw [phi81CoeffsToPolynomial]
  trans ∑ index : Fin phi81Degree, if index.val = 0 then (1 : Polynomial Goldilocks) else 0
  · apply Finset.sum_congr rfl
    intro index _
    by_cases h : index.val = 0
    · simp [phi81OneCoeffs, h]
    · simp [phi81OneCoeffs, h]
  · rw [Finset.sum_eq_single ⟨0, by native_decide⟩]
    · simp
    · intro index _ hne
      have hval : index.val ≠ 0 := by
        intro hzero
        apply hne
        exact Fin.ext hzero
      simp [hval]
    · simp

theorem phi81CoeffsToPolynomial_add (lhs rhs : Phi81Coefficients) :
    phi81CoeffsToPolynomial (phi81SwiftAddCoeffs lhs rhs) =
      phi81CoeffsToPolynomial lhs + phi81CoeffsToPolynomial rhs := by
  simp [phi81CoeffsToPolynomial, phi81SwiftAddCoeffs, Finset.sum_add_distrib, add_mul]

theorem phi81CoeffsToPolynomial_neg (value : Phi81Coefficients) :
    phi81CoeffsToPolynomial (phi81SwiftNegCoeffs value) =
      -phi81CoeffsToPolynomial value := by
  rw [phi81CoeffsToPolynomial, phi81CoeffsToPolynomial]
  simp [phi81SwiftNegCoeffs, Finset.sum_neg_distrib]

theorem phi81CoeffsToPolynomial_sub (lhs rhs : Phi81Coefficients) :
    phi81CoeffsToPolynomial (phi81SwiftSubCoeffs lhs rhs) =
      phi81CoeffsToPolynomial lhs - phi81CoeffsToPolynomial rhs := by
  rw [phi81CoeffsToPolynomial, phi81CoeffsToPolynomial, phi81CoeffsToPolynomial]
  simp [phi81SwiftSubCoeffs, sub_eq_add_neg, Finset.sum_add_distrib,
    Finset.sum_neg_distrib, add_mul]

theorem phi81CoeffsToQuotient_zero :
    phi81CoeffsToQuotient phi81ZeroCoeffs = 0 := by
  simp [phi81CoeffsToQuotient, phi81CoeffsToPolynomial_zero]

theorem phi81CoeffsToQuotient_one :
    phi81CoeffsToQuotient phi81OneCoeffs = 1 := by
  simp [phi81CoeffsToQuotient, phi81CoeffsToPolynomial_one]

theorem phi81CoeffsToQuotient_add (lhs rhs : Phi81Coefficients) :
    phi81CoeffsToQuotient (phi81SwiftAddCoeffs lhs rhs) =
      phi81CoeffsToQuotient lhs + phi81CoeffsToQuotient rhs := by
  simp [phi81CoeffsToQuotient, phi81CoeffsToPolynomial_add]

theorem phi81CoeffsToQuotient_neg (value : Phi81Coefficients) :
    phi81CoeffsToQuotient (phi81SwiftNegCoeffs value) =
      -phi81CoeffsToQuotient value := by
  simp [phi81CoeffsToQuotient, phi81CoeffsToPolynomial_neg]

theorem phi81CoeffsToQuotient_sub (lhs rhs : Phi81Coefficients) :
    phi81CoeffsToQuotient (phi81SwiftSubCoeffs lhs rhs) =
      phi81CoeffsToQuotient lhs - phi81CoeffsToQuotient rhs := by
  simp [phi81CoeffsToQuotient, phi81CoeffsToPolynomial_sub]

theorem phi81CoeffsToQuotient_eq_sum (coefficients : Phi81Coefficients) :
    phi81CoeffsToQuotient coefficients =
      ∑ index : Fin phi81Degree,
        algebraMap Goldilocks Phi81 (coefficients index) * phi81X ^ index.val := by
  simp [phi81CoeffsToQuotient, phi81CoeffsToPolynomial, phi81X, map_sum, map_mul,
    map_pow, Polynomial.C_eq_algebraMap,
    Ideal.Quotient.mk_algebraMap (R₁ := Goldilocks)]

def phi81BasisCoeffs (exponent : Nat) : Phi81Coefficients :=
  fun target => if target.val = exponent then 1 else 0

def phi81ProductMonomialCoeffs (exponent : Nat) : Phi81Coefficients :=
  fun target => phi81ProductMonomialContribution target exponent

theorem phi81BasisCoeffs_toQuotient
    (exponent : Nat)
    (hExponent : exponent < phi81Degree) :
    phi81CoeffsToQuotient (phi81BasisCoeffs exponent) = phi81X ^ exponent := by
  rw [phi81CoeffsToQuotient_eq_sum]
  rw [Finset.sum_eq_single ⟨exponent, hExponent⟩]
  · simp [phi81BasisCoeffs]
  · intro target _ hTarget
    have hValue : target.val ≠ exponent := by
      intro hEq
      apply hTarget
      exact Fin.ext hEq
    simp [phi81BasisCoeffs, hValue]
  · simp

theorem phi81ProductMonomialCoeffs_low
    (exponent : Nat)
    (hExponent : exponent < phi81Degree) :
    phi81ProductMonomialCoeffs exponent = phi81BasisCoeffs exponent := by
  funext target
  simp [phi81ProductMonomialCoeffs, phi81ProductMonomialContribution, phi81BasisCoeffs,
    hExponent]

theorem phi81ProductMonomialCoeffs_mid
    (exponent : Nat)
    (hLower : phi81Degree ≤ exponent)
    (hUpper : exponent < phi81Degree + phi81Degree / 2) :
    phi81ProductMonomialCoeffs exponent =
      phi81SwiftAddCoeffs
        (phi81SwiftNegCoeffs (phi81BasisCoeffs (exponent - phi81Degree)))
        (phi81SwiftNegCoeffs (phi81BasisCoeffs (exponent - phi81Degree / 2))) := by
  funext target
  have hNotLow : ¬ exponent < phi81Degree := not_lt.mpr hLower
  have hDifferentA : exponent - phi81Degree ≠ exponent - phi81Degree / 2 := by
    simp [phi81Degree] at hLower hUpper ⊢
    omega
  have hDifferentB : exponent - phi81Degree / 2 ≠ exponent - phi81Degree :=
    Ne.symm hDifferentA
  simp [phi81ProductMonomialCoeffs, phi81ProductMonomialContribution, hNotLow, hUpper,
    phi81SwiftAddCoeffs, phi81SwiftNegCoeffs, phi81BasisCoeffs]
  by_cases hA : target.val = exponent - phi81Degree <;>
    by_cases hB : target.val = exponent - phi81Degree / 2 <;>
      simp [hA, hB, hDifferentA, hDifferentB]

theorem phi81ProductMonomialCoeffs_high
    (exponent : Nat)
    (hLower : phi81Degree + phi81Degree / 2 ≤ exponent)
    (hUpper : exponent < 2 * phi81Degree) :
    phi81ProductMonomialCoeffs exponent =
      phi81BasisCoeffs (exponent - phi81Degree - phi81Degree / 2) := by
  funext target
  have hNotLow : ¬ exponent < phi81Degree := by omega
  have hNotMid : ¬ exponent < phi81Degree + phi81Degree / 2 := not_lt.mpr hLower
  simp [phi81ProductMonomialCoeffs, phi81ProductMonomialContribution, hNotLow, hNotMid,
    hUpper, phi81BasisCoeffs]

theorem phi81ProductMonomialCoeffs_toQuotient_mid
    (exponent : Nat)
    (hLower : phi81Degree ≤ exponent)
    (hUpper : exponent < phi81Degree + phi81Degree / 2) :
    phi81CoeffsToQuotient (phi81ProductMonomialCoeffs exponent) = phi81X ^ exponent := by
  rw [phi81ProductMonomialCoeffs_mid exponent hLower hUpper]
  rw [phi81CoeffsToQuotient_add, phi81CoeffsToQuotient_neg, phi81CoeffsToQuotient_neg]
  rw [phi81BasisCoeffs_toQuotient]
  rw [phi81BasisCoeffs_toQuotient]
  · have hExp : exponent = 54 + (exponent - 54) := by
      simp [phi81Degree] at hLower hUpper
      omega
    have hExp27 : exponent - 27 = 27 + (exponent - 54) := by
      simp [phi81Degree] at hLower hUpper
      omega
    calc
      -(phi81X ^ (exponent - phi81Degree)) + -(phi81X ^ (exponent - phi81Degree / 2))
          = -(phi81X ^ (exponent - 54)) + -(phi81X ^ (exponent - 27)) := by
            simp [phi81Degree]
      _ = -(phi81X ^ (exponent - 54)) + -(phi81X ^ (27 + (exponent - 54))) := by
            rw [hExp27]
      _ = (-phi81X ^ 27 - 1) * phi81X ^ (exponent - 54) := by
            rw [pow_add]
            ring
      _ = phi81X ^ 54 * phi81X ^ (exponent - 54) := by rw [← phi81_X54_eq]
      _ = phi81X ^ (54 + (exponent - 54)) := by rw [pow_add]
      _ = phi81X ^ exponent := by rw [← hExp]
  · simp [phi81Degree] at hLower hUpper ⊢
    omega
  · simp [phi81Degree] at hLower hUpper ⊢
    omega

theorem phi81ProductMonomialCoeffs_toQuotient_high
    (exponent : Nat)
    (hLower : phi81Degree + phi81Degree / 2 ≤ exponent)
    (hUpper : exponent < 2 * phi81Degree) :
    phi81CoeffsToQuotient (phi81ProductMonomialCoeffs exponent) = phi81X ^ exponent := by
  rw [phi81ProductMonomialCoeffs_high exponent hLower hUpper]
  rw [phi81BasisCoeffs_toQuotient]
  · have hIndex : exponent - phi81Degree - phi81Degree / 2 = exponent - 81 := by
      simp [phi81Degree] at hLower hUpper ⊢
      omega
    have hExp : exponent = 81 + (exponent - 81) := by
      simp [phi81Degree] at hLower hUpper
      omega
    calc
      phi81X ^ (exponent - phi81Degree - phi81Degree / 2)
          = phi81X ^ (exponent - 81) := by rw [hIndex]
      _ = 1 * phi81X ^ (exponent - 81) := by rw [one_mul]
      _ = phi81X ^ 81 * phi81X ^ (exponent - 81) := by rw [phi81_X81_eq_one]
      _ = phi81X ^ (81 + (exponent - 81)) := by rw [pow_add]
      _ = phi81X ^ exponent := by rw [← hExp]
  · simp [phi81Degree] at hLower hUpper ⊢
    omega

theorem phi81ProductMonomialCoeffs_toQuotient
    (exponent : Nat)
    (hExponent : exponent < 2 * phi81Degree) :
    phi81CoeffsToQuotient (phi81ProductMonomialCoeffs exponent) = phi81X ^ exponent := by
  by_cases hLow : exponent < phi81Degree
  · rw [phi81ProductMonomialCoeffs_low exponent hLow]
    exact phi81BasisCoeffs_toQuotient exponent hLow
  · by_cases hMid : exponent < phi81Degree + phi81Degree / 2
    · exact phi81ProductMonomialCoeffs_toQuotient_mid exponent (not_lt.mp hLow) hMid
    · exact phi81ProductMonomialCoeffs_toQuotient_high exponent (not_lt.mp hMid) hExponent

theorem phi81CoeffsToQuotient_fintype_sum {α : Type} [Fintype α]
    (coefficients : α → Phi81Coefficients) :
    phi81CoeffsToQuotient (fun target => ∑ value : α, coefficients value target) =
      ∑ value : α, phi81CoeffsToQuotient (coefficients value) := by
  rw [phi81CoeffsToQuotient_eq_sum]
  simp_rw [map_sum]
  simp_rw [Finset.sum_mul]
  rw [Finset.sum_comm]
  simp [phi81CoeffsToQuotient_eq_sum]

theorem phi81CoeffsToQuotient_const_mul
    (scale : Goldilocks)
    (coefficients : Phi81Coefficients) :
    phi81CoeffsToQuotient (fun target => scale * coefficients target) =
      algebraMap Goldilocks Phi81 scale * phi81CoeffsToQuotient coefficients := by
  rw [phi81CoeffsToQuotient_eq_sum, phi81CoeffsToQuotient_eq_sum]
  simp [map_mul, Finset.mul_sum, mul_assoc]

theorem phi81ProductMonomialContribution_X54_const :
    phi81ProductMonomialContribution ⟨0, by native_decide⟩ 54 = -1 := by
  simp [phi81ProductMonomialContribution, phi81Degree]

theorem phi81ProductMonomialContribution_X54_mid :
    phi81ProductMonomialContribution ⟨27, by native_decide⟩ 54 = -1 := by
  simp [phi81ProductMonomialContribution, phi81Degree]

theorem phi81ProductMonomialContribution_X54_other
    (target : Fin phi81Degree)
    (h0 : target.val ≠ 0)
    (h27 : target.val ≠ 27) :
    phi81ProductMonomialContribution target 54 = 0 := by
  simp [phi81ProductMonomialContribution, phi81Degree, h0, h27]

theorem phi81ProductMonomialContribution_X81_const :
    phi81ProductMonomialContribution ⟨0, by native_decide⟩ 81 = 1 := by
  simp [phi81ProductMonomialContribution, phi81Degree]

theorem phi81ProductMonomialContribution_X81_other
    (target : Fin phi81Degree)
    (h0 : target.val ≠ 0) :
    phi81ProductMonomialContribution target 81 = 0 := by
  simp [phi81ProductMonomialContribution, phi81Degree, h0]

theorem phi81SwiftMulCoeffs_eq_sum (lhs rhs : Phi81Coefficients) :
    phi81SwiftMulCoeffs lhs rhs =
      fun target =>
        ∑ left : Fin phi81Degree,
          ∑ right : Fin phi81Degree,
            phi81ProductMonomialContribution target (left.val + right.val) *
              lhs left * rhs right := by
  rfl

theorem phi81SwiftMulCoeffs_toQuotient_mul (lhs rhs : Phi81Coefficients) :
    phi81CoeffsToQuotient (phi81SwiftMulCoeffs lhs rhs) =
      phi81CoeffsToQuotient lhs * phi81CoeffsToQuotient rhs := by
  have hCoeffDecomposition :
      phi81SwiftMulCoeffs lhs rhs =
        fun target =>
          ∑ left : Fin phi81Degree,
            ∑ right : Fin phi81Degree,
              (lhs left * rhs right) *
                phi81ProductMonomialCoeffs (left.val + right.val) target := by
    funext target
    apply Finset.sum_congr rfl
    intro left _
    apply Finset.sum_congr rfl
    intro right _
    simp [phi81ProductMonomialCoeffs]
    ring
  rw [hCoeffDecomposition]
  rw [phi81CoeffsToQuotient_fintype_sum]
  simp_rw [phi81CoeffsToQuotient_fintype_sum]
  simp_rw [phi81CoeffsToQuotient_const_mul]
  have hReduced (left right : Fin phi81Degree) :
      phi81CoeffsToQuotient (phi81ProductMonomialCoeffs (left.val + right.val)) =
        phi81X ^ (left.val + right.val) := by
    apply phi81ProductMonomialCoeffs_toQuotient
    have hLeft := left.isLt
    have hRight := right.isLt
    omega
  simp_rw [hReduced]
  rw [phi81CoeffsToQuotient_eq_sum lhs, phi81CoeffsToQuotient_eq_sum rhs]
  rw [Finset.sum_mul]
  simp_rw [Finset.mul_sum]
  apply Finset.sum_congr rfl
  intro left _
  apply Finset.sum_congr rfl
  intro right _
  simp [map_mul, pow_add]
  ring

end SuperNeoFormal
