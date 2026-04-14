import SuperNeoFormal.PiRLCSoundness

/-!
Phi81 split semantics.

Goldilocks satisfies `p ≡ 4 (mod 81)`, and the concrete cyclotomic polynomial
factors over the base field into two degree-27 factors.  The formal PiRLC
collision replacement uses an explicit split certificate instead of treating the
quotient ring as a field.
-/

noncomputable section

namespace SuperNeoFormal

open Polynomial

def phi81SplitLeftConstant : Goldilocks :=
  4294967295

def phi81SplitRightConstant : Goldilocks :=
  4294967296

theorem phi81Split_constants_sub :
    phi81SplitRightConstant - phi81SplitLeftConstant = 1 := by
  native_decide

theorem phi81Split_constants_mul :
    phi81SplitLeftConstant * phi81SplitRightConstant = -1 := by
  native_decide

theorem phi81Polynomial_factor_goldilocks :
    phi81Polynomial =
      (X ^ 27 - C phi81SplitLeftConstant) *
        (X ^ 27 + C phi81SplitRightConstant) := by
  have hCdiff :
      C phi81SplitRightConstant - C phi81SplitLeftConstant =
        (1 : Polynomial Goldilocks) := by
    simpa [map_sub] using
      congrArg (C : Goldilocks → Polynomial Goldilocks)
        phi81Split_constants_sub
  have hCprod :
      C phi81SplitLeftConstant * C phi81SplitRightConstant =
        -(1 : Polynomial Goldilocks) := by
    simpa [map_mul] using
      congrArg (C : Goldilocks → Polynomial Goldilocks)
        phi81Split_constants_mul
  calc
    phi81Polynomial = X ^ 54 + X ^ 27 + 1 := by
      rw [phi81Polynomial]
      simp [phi81Degree]
    _ = X ^ 54 + (C phi81SplitRightConstant - C phi81SplitLeftConstant) *
        X ^ 27 - C phi81SplitLeftConstant * C phi81SplitRightConstant := by
      rw [hCdiff, hCprod]
      ring
    _ = (X ^ 27 - C phi81SplitLeftConstant) *
        (X ^ 27 + C phi81SplitRightConstant) := by
      ring

structure Phi81SplitCertificate where
  leftProjection : Phi81 → Goldilocks
  rightProjection : Phi81 → Goldilocks
  left_zero : leftProjection 0 = 0
  right_zero : rightProjection 0 = 0
  separates_zero :
    ∀ value,
      leftProjection value = 0 →
        rightProjection value = 0 →
          value = 0

theorem phi81Split_nonzero_has_nonzero_component
    (certificate : Phi81SplitCertificate)
    {value : Phi81}
    (hNonzero : value ≠ 0) :
    certificate.leftProjection value ≠ 0 ∨
      certificate.rightProjection value ≠ 0 := by
  by_contra hNoComponent
  push_neg at hNoComponent
  exact hNonzero
    (certificate.separates_zero
      value
      hNoComponent.1
      hNoComponent.2)

def phi81SplitComponentCollisionValues
    {count : Nat}
    [DecidableEq Goldilocks]
    (support : Finset Goldilocks)
    (fixedChallenges : Fin count → Goldilocks)
    (pivot : Fin count)
    (deltas : Fin count → Goldilocks) :
    Finset Goldilocks :=
  scalarRLCBadPivotValues support fixedChallenges pivot deltas

theorem phi81SplitComponentCollisionValues_card_le_one
    {count : Nat}
    [DecidableEq Goldilocks]
    (support : Finset Goldilocks)
    (fixedChallenges : Fin count → Goldilocks)
    (pivot : Fin count)
    (deltas : Fin count → Goldilocks)
    (hPivot : deltas pivot ≠ 0) :
    (phi81SplitComponentCollisionValues
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
