import Mathlib.Algebra.Field.TransferInstance
import Mathlib.Algebra.QuadraticAlgebra.Basic
import SuperNeoFormal.Goldilocks

/-!
Goldilocks quadratic-extension field and wire model.

Swift represents an extension element as `c0 + c1 u` with `u^2 = 7`.  This file
records the concrete operations and transfers a field instance from mathlib's
quadratic algebra after proving that `7` has no square root in the base
Goldilocks field.
-/

namespace SuperNeoFormal

structure GoldilocksExt2 where
  c0 : Goldilocks
  c1 : Goldilocks
  deriving DecidableEq

def goldilocksExt2NonResidue : Goldilocks :=
  7

def goldilocksExt2Zero : GoldilocksExt2 where
  c0 := 0
  c1 := 0

def goldilocksExt2One : GoldilocksExt2 where
  c0 := 1
  c1 := 0

def goldilocksExt2Add (lhs rhs : GoldilocksExt2) : GoldilocksExt2 where
  c0 := lhs.c0 + rhs.c0
  c1 := lhs.c1 + rhs.c1

def goldilocksExt2Neg (value : GoldilocksExt2) : GoldilocksExt2 where
  c0 := -value.c0
  c1 := -value.c1

def goldilocksExt2Sub (lhs rhs : GoldilocksExt2) : GoldilocksExt2 :=
  goldilocksExt2Add lhs (goldilocksExt2Neg rhs)

def goldilocksExt2Mul (lhs rhs : GoldilocksExt2) : GoldilocksExt2 where
  c0 := lhs.c0 * rhs.c0 + lhs.c1 * rhs.c1 * goldilocksExt2NonResidue
  c1 := (lhs.c0 + lhs.c1) * (rhs.c0 + rhs.c1) -
    lhs.c0 * rhs.c0 - lhs.c1 * rhs.c1

def goldilocksExt2Denominator (value : GoldilocksExt2) : Goldilocks :=
  value.c0 * value.c0 - value.c1 * value.c1 * goldilocksExt2NonResidue

def goldilocksExt2InvData (value : GoldilocksExt2) (denominatorInv : Goldilocks) :
    GoldilocksExt2 where
  c0 := value.c0 * denominatorInv
  c1 := -value.c1 * denominatorInv

theorem goldilocksExt2NonResidue_ne_zero :
    goldilocksExt2NonResidue ≠ 0 := by
  native_decide

theorem goldilocksExt2NonResidue_pow_half_ne_one :
    goldilocksExt2NonResidue ^ (Fintype.card Goldilocks / 2) ≠ 1 := by
  rw [ZMod.card goldilocksModulus]
  have hHalf :
      goldilocksModulus / 2 = (goldilocksModulus - 1) / 2 := by
    native_decide
  rw [hHalf]
  exact goldilocksLucasWitness_pow_div_two

theorem goldilocksExt2_ringChar_ne_two :
    ringChar Goldilocks ≠ 2 := by
  rw [goldilocks_char]
  native_decide

theorem goldilocksExt2NonResidue_not_isSquare :
    ¬ IsSquare goldilocksExt2NonResidue := by
  intro hSquare
  have hPow :=
    (FiniteField.isSquare_iff goldilocksExt2_ringChar_ne_two
      goldilocksExt2NonResidue_ne_zero).mp hSquare
  exact goldilocksExt2NonResidue_pow_half_ne_one hPow

theorem goldilocksExt2NonResidue_no_square_root (r : Goldilocks) :
    r ^ 2 ≠ goldilocksExt2NonResidue := by
  intro hRoot
  exact goldilocksExt2NonResidue_not_isSquare ⟨r, by simpa [pow_two] using hRoot.symm⟩

instance goldilocksExt2NoRootFact :
    Fact (∀ r : Goldilocks,
      r ^ 2 ≠ goldilocksExt2NonResidue + (0 : Goldilocks) * r) :=
  ⟨fun r => by simpa using goldilocksExt2NonResidue_no_square_root r⟩

def goldilocksExt2QuadraticEquiv :
    GoldilocksExt2 ≃ QuadraticAlgebra Goldilocks goldilocksExt2NonResidue 0 where
  toFun value := ⟨value.c0, value.c1⟩
  invFun value := ⟨value.re, value.im⟩
  left_inv value := by
    cases value
    rfl
  right_inv value := by
    cases value
    rfl

noncomputable instance : Field GoldilocksExt2 :=
  goldilocksExt2QuadraticEquiv.field

noncomputable def goldilocksExt2Field :
    Field GoldilocksExt2 :=
  inferInstance

theorem goldilocksExt2_zero_matches_model :
    (0 : GoldilocksExt2) = goldilocksExt2Zero := by
  rfl

theorem goldilocksExt2_one_matches_model :
    (1 : GoldilocksExt2) = goldilocksExt2One := by
  rfl

theorem goldilocksExt2_add_matches_model
    (lhs rhs : GoldilocksExt2) :
    lhs + rhs = goldilocksExt2Add lhs rhs := by
  rfl

theorem goldilocksExt2_neg_matches_model
    (value : GoldilocksExt2) :
    -value = goldilocksExt2Neg value := by
  rfl

theorem goldilocksExt2_sub_matches_model
    (lhs rhs : GoldilocksExt2) :
    lhs - rhs = goldilocksExt2Sub lhs rhs := by
  rw [sub_eq_add_neg, goldilocksExt2_add_matches_model, goldilocksExt2_neg_matches_model]
  rfl

theorem goldilocksExt2_mul_matches_model
    (lhs rhs : GoldilocksExt2) :
    lhs * rhs = goldilocksExt2Mul lhs rhs := by
  change goldilocksExt2QuadraticEquiv.symm
      (goldilocksExt2QuadraticEquiv lhs * goldilocksExt2QuadraticEquiv rhs) =
    goldilocksExt2Mul lhs rhs
  cases lhs with
  | mk lhs0 lhs1 =>
      cases rhs with
      | mk rhs0 rhs1 =>
          rw [GoldilocksExt2.mk.injEq]
          constructor
          · simp [goldilocksExt2QuadraticEquiv, goldilocksExt2Mul]
            ring
          · simp [goldilocksExt2QuadraticEquiv, goldilocksExt2Mul]
            ring

theorem goldilocksExt2_denominator_eq_norm
    (value : GoldilocksExt2) :
    goldilocksExt2Denominator value =
      QuadraticAlgebra.norm (goldilocksExt2QuadraticEquiv value) := by
  cases value with
  | mk c0 c1 =>
      simp [goldilocksExt2Denominator, QuadraticAlgebra.norm_def, goldilocksExt2QuadraticEquiv]
      ring

theorem goldilocksExt2_denominator_nonzero
    (value : GoldilocksExt2)
    (hValue : value ≠ goldilocksExt2Zero) :
    goldilocksExt2Denominator value ≠ 0 := by
  intro hDenominator
  have hNorm :
      QuadraticAlgebra.norm (goldilocksExt2QuadraticEquiv value) = 0 := by
    rw [← goldilocksExt2_denominator_eq_norm value]
    exact hDenominator
  have hQuadraticZero :
      goldilocksExt2QuadraticEquiv value = 0 :=
    (QuadraticAlgebra.norm_eq_zero_iff_eq_zero).mp hNorm
  have hZero : value = goldilocksExt2Zero := by
    cases value with
    | mk c0 c1 =>
        rw [QuadraticAlgebra.ext_iff] at hQuadraticZero
        simp [goldilocksExt2QuadraticEquiv, goldilocksExt2Zero] at hQuadraticZero ⊢
        exact hQuadraticZero
  exact hValue hZero

structure GoldilocksExt2FieldCertificate where
  denominator_nonzero :
    ∀ value : GoldilocksExt2,
      value ≠ goldilocksExt2Zero →
        goldilocksExt2Denominator value ≠ 0
  denominator_inverse :
    ∀ value : GoldilocksExt2,
      value ≠ goldilocksExt2Zero →
        ∃ denominatorInv,
          goldilocksExt2Denominator value * denominatorInv = 1

def GoldilocksExt2FieldModel : Prop :=
  ∃ _certificate : GoldilocksExt2FieldCertificate, True

def goldilocksExt2FieldCertificateFromField :
    GoldilocksExt2FieldCertificate where
  denominator_nonzero := goldilocksExt2_denominator_nonzero
  denominator_inverse := by
    intro value hValue
    exact ⟨(goldilocksExt2Denominator value)⁻¹,
      mul_inv_cancel₀ (goldilocksExt2_denominator_nonzero value hValue)⟩

theorem goldilocksExt2_operations_match_swift_mul
    (lhs rhs : GoldilocksExt2) :
    goldilocksExt2Mul lhs rhs =
      { c0 := lhs.c0 * rhs.c0 + lhs.c1 * rhs.c1 * goldilocksExt2NonResidue
        c1 := (lhs.c0 + lhs.c1) * (rhs.c0 + rhs.c1) -
          lhs.c0 * rhs.c0 - lhs.c1 * rhs.c1 } := by
  rfl

theorem goldilocksExt2_inverse_data_denominator
    (value : GoldilocksExt2)
    {denominatorInv : Goldilocks}
    (hInv : goldilocksExt2Denominator value * denominatorInv = 1) :
    goldilocksExt2Denominator value * (goldilocksExt2InvData value denominatorInv).c0 =
      value.c0 := by
  simp [goldilocksExt2InvData]
  calc
    goldilocksExt2Denominator value * (value.c0 * denominatorInv) =
        value.c0 * (goldilocksExt2Denominator value * denominatorInv) := by
      ring
    _ = value.c0 := by
      rw [hInv]
      ring

theorem goldilocksExt2_mul_invData
    (value : GoldilocksExt2)
    {denominatorInv : Goldilocks}
    (hInv : goldilocksExt2Denominator value * denominatorInv = 1) :
    goldilocksExt2Mul value (goldilocksExt2InvData value denominatorInv) =
      goldilocksExt2One := by
  cases value with
  | mk c0 c1 =>
      rw [GoldilocksExt2.mk.injEq]
      constructor
      · simp [goldilocksExt2Mul, goldilocksExt2InvData, goldilocksExt2One,
          goldilocksExt2Denominator] at hInv ⊢
        calc
          c0 * (c0 * denominatorInv) +
              -(c1 * (c1 * denominatorInv) * goldilocksExt2NonResidue) =
            (c0 * c0 - c1 * c1 * goldilocksExt2NonResidue) * denominatorInv := by
              ring
          _ = 1 := hInv
      · simp [goldilocksExt2Mul, goldilocksExt2InvData, goldilocksExt2One,
          goldilocksExt2NonResidue]
        ring

theorem goldilocksExt2_field_model_from_certificate
    (certificate : GoldilocksExt2FieldCertificate) :
    GoldilocksExt2FieldModel :=
  ⟨certificate, trivial⟩

theorem goldilocksExt2_field_model :
    GoldilocksExt2FieldModel :=
  goldilocksExt2_field_model_from_certificate goldilocksExt2FieldCertificateFromField

end SuperNeoFormal
