import SuperNeoFormal.PiDEC
import SuperNeoFormal.Profile

/-!
Additional PiDEC recomposition and signed-decomposition facts.

`PiDEC.lean` proves commitment recomposition.  This module extends the same
weighted-recomposition surface to public inputs and matrix-evaluation vectors,
and proves the concrete signed base-2 limb bound for the implemented
`decompositionLength = 14` profile.
-/

noncomputable section

namespace SuperNeoFormal

open Finset

variable {RF : Type} [CommRing RF]

def pidecWeightedVector {count width : Nat}
    (base : RF)
    (parts : Fin count → Fin width → RF) : Fin width → RF :=
  fun coordinate => pidecWeightedSum base (fun index => parts index coordinate)

def pidecWeightedPublicInput {count publicCount : Nat}
    (base : RF)
    (parts : Fin count → Fin publicCount → RF) : Fin publicCount → RF :=
  pidecWeightedVector base parts

def pidecWeightedMatrixEvaluations {count evalCount : Nat}
    (base : RF)
    (parts : Fin count → Fin evalCount → RF) : Fin evalCount → RF :=
  pidecWeightedVector base parts

theorem pidecWeightedVector_eq_sum {count width : Nat}
    (base : RF)
    (parts : Fin count → Fin width → RF)
    (coordinate : Fin width) :
    pidecWeightedVector base parts coordinate =
      ∑ index : Fin count, base ^ index.val * parts index coordinate := by
  rfl

theorem pidec_public_input_recomposition {count publicCount : Nat}
    {base : RF}
    {limbs : Fin count → Fin publicCount → RF}
    {folded : Fin publicCount → RF}
    (hFolded : folded = pidecWeightedPublicInput base limbs) :
    ∀ coordinate,
      folded coordinate =
        ∑ index : Fin count, base ^ index.val * limbs index coordinate := by
  intro coordinate
  rw [hFolded]
  rfl

theorem pidec_matrix_evaluation_recomposition {count evalCount : Nat}
    {base : RF}
    {limbs : Fin count → Fin evalCount → RF}
    {folded : Fin evalCount → RF}
    (hFolded : folded = pidecWeightedMatrixEvaluations base limbs) :
    ∀ coordinate,
      folded coordinate =
        ∑ index : Fin count, base ^ index.val * limbs index coordinate := by
  intro coordinate
  rw [hFolded]
  rfl

def signedBaseTwoRecompose {length : Nat} (limbs : Fin length → Int) : Int :=
  ∑ index : Fin length, limbs index * (2 : Int) ^ index.val

def SignedBaseTwoLimbBound {length : Nat} (limbs : Fin length → Int) : Prop :=
  ∀ index, |limbs index| ≤ 1

def signedBaseTwoVectorRecompose {length width : Nat}
    (limbs : Fin length → Fin width → Int) : Fin width → Int :=
  fun coordinate => signedBaseTwoRecompose (fun index => limbs index coordinate)

def SignedBaseTwoVectorLimbBound {length width : Nat}
    (limbs : Fin length → Fin width → Int) : Prop :=
  ∀ index coordinate, |limbs index coordinate| ≤ 1

theorem signedBaseTwoRecompose_abs_bound_14
    (limbs : Fin decompositionLength → Int)
    (hBound : SignedBaseTwoLimbBound limbs) :
    |signedBaseTwoRecompose limbs| ≤ (decompositionRadixBound : Int) - 1 := by
  calc
    |signedBaseTwoRecompose limbs|
        ≤ ∑ index : Fin decompositionLength,
            |limbs index * (2 : Int) ^ index.val| := by
          exact Finset.abs_sum_le_sum_abs (fun index : Fin decompositionLength =>
            limbs index * (2 : Int) ^ index.val) Finset.univ
    _ ≤ ∑ index : Fin decompositionLength, (2 : Int) ^ index.val := by
          apply Finset.sum_le_sum
          intro index _
          rw [abs_mul]
          have hPowNonneg : 0 ≤ (2 : Int) ^ index.val := by positivity
          rw [abs_of_nonneg hPowNonneg]
          calc
            |limbs index| * (2 : Int) ^ index.val
                ≤ 1 * (2 : Int) ^ index.val := by
                  exact mul_le_mul_of_nonneg_right (hBound index) hPowNonneg
            _ = (2 : Int) ^ index.val := by simp
    _ = 16383 := by native_decide
    _ ≤ (decompositionRadixBound : Int) - 1 := by native_decide

theorem signedBaseTwoRecompose_abs_lt_radix_14
    (limbs : Fin decompositionLength → Int)
    (hBound : SignedBaseTwoLimbBound limbs) :
    |signedBaseTwoRecompose limbs| < (decompositionRadixBound : Int) := by
  have hLe := signedBaseTwoRecompose_abs_bound_14 limbs hBound
  simp [decompositionRadixBound, normBound, decompositionLength] at hLe ⊢
  omega

theorem signedBaseTwoVectorRecompose_abs_bound_14 {width : Nat}
    (limbs : Fin decompositionLength → Fin width → Int)
    (hBound : SignedBaseTwoVectorLimbBound limbs)
    (coordinate : Fin width) :
    |signedBaseTwoVectorRecompose limbs coordinate| ≤
      (decompositionRadixBound : Int) - 1 := by
  exact signedBaseTwoRecompose_abs_bound_14
    (fun index => limbs index coordinate)
    (fun index => hBound index coordinate)

theorem signedBaseTwoVectorRecompose_abs_lt_radix_14 {width : Nat}
    (limbs : Fin decompositionLength → Fin width → Int)
    (hBound : SignedBaseTwoVectorLimbBound limbs)
    (coordinate : Fin width) :
    |signedBaseTwoVectorRecompose limbs coordinate| <
      (decompositionRadixBound : Int) := by
  exact signedBaseTwoRecompose_abs_lt_radix_14
    (fun index => limbs index coordinate)
    (fun index => hBound index coordinate)

end SuperNeoFormal
