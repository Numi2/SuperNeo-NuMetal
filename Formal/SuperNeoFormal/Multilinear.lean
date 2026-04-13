import Mathlib

/-!
Multilinear-extension and equality-polynomial semantics for sum-check.

This module is field-agnostic and works over any commutative ring. It captures
the Boolean-hypercube basis used by the Swift `MultilinearEvaluation` helper and
proves the core interpolation property on Boolean vertices.
-/

namespace SuperNeoFormal

open Finset

variable {F : Type} [CommRing F]

abbrev BooleanPoint (n : Nat) :=
  Fin n → Bool

def boolToRing (bit : Bool) : F :=
  if bit then 1 else 0

def multilinearBasisFactor (challenge : F) (bit : Bool) : F :=
  if bit then challenge else 1 - challenge

def multilinearBasis {n : Nat}
    (point : Fin n → F)
    (vertex : BooleanPoint n) : F :=
  ∏ index : Fin n, multilinearBasisFactor (point index) (vertex index)

def multilinearExtension {n : Nat}
    (table : BooleanPoint n → F)
    (point : Fin n → F) : F :=
  ∑ vertex : BooleanPoint n, table vertex * multilinearBasis point vertex

def equalityFactor (lhs rhs : F) : F :=
  1 - lhs - rhs + (2 : F) * lhs * rhs

def equalityPolynomial {n : Nat}
    (lhs rhs : Fin n → F) : F :=
  ∏ index : Fin n, equalityFactor (lhs index) (rhs index)

theorem equalityFactor_bool_left (bit : Bool) (challenge : F) :
    equalityFactor (boolToRing bit) challenge =
      multilinearBasisFactor challenge bit := by
  cases bit
  · simp [equalityFactor, boolToRing, multilinearBasisFactor]
  · simp [equalityFactor, boolToRing, multilinearBasisFactor]
    ring

theorem equalityPolynomial_bool_left {n : Nat}
    (vertex : BooleanPoint n)
    (point : Fin n → F) :
    equalityPolynomial (fun index => boolToRing (vertex index)) point =
      multilinearBasis point vertex := by
  rw [equalityPolynomial, multilinearBasis]
  apply Finset.prod_congr rfl
  intro index _
  exact equalityFactor_bool_left (vertex index) (point index)

theorem multilinearBasis_boolean_self {n : Nat}
    (vertex : BooleanPoint n) :
    multilinearBasis (fun index => boolToRing (vertex index)) vertex = (1 : F) := by
  rw [multilinearBasis]
  apply Finset.prod_eq_one
  intro index _
  cases vertex index <;> simp [multilinearBasisFactor, boolToRing]

theorem multilinearBasis_boolean_ne {n : Nat}
    {point vertex : BooleanPoint n}
    (hneq : point ≠ vertex) :
    multilinearBasis (fun index => boolToRing (point index)) vertex = (0 : F) := by
  have hExists : ∃ index, point index ≠ vertex index := by
    by_contra hnone
    apply hneq
    funext index
    by_cases hEq : point index = vertex index
    · exact hEq
    · exfalso
      exact hnone ⟨index, hEq⟩
  rcases hExists with ⟨index, hDifferent⟩
  rw [multilinearBasis]
  apply Finset.prod_eq_zero (Finset.mem_univ index)
  cases hPoint : point index <;>
    cases hVertex : vertex index <;>
      simp [multilinearBasisFactor, boolToRing, hPoint, hVertex] at hDifferent ⊢

theorem multilinearExtension_interpolates {n : Nat}
    (table : BooleanPoint n → F)
    (vertex : BooleanPoint n) :
    multilinearExtension table (fun index => boolToRing (vertex index)) =
      table vertex := by
  rw [multilinearExtension]
  rw [Finset.sum_eq_single vertex]
  · simp [multilinearBasis_boolean_self]
  · intro other _ hOther
    have hbasis :
        multilinearBasis (fun index => boolToRing (vertex index)) other = (0 : F) :=
      multilinearBasis_boolean_ne hOther.symm
    simp [hbasis]
  · intro hnot
    simp at hnot

theorem equalityPolynomial_boolean_self {n : Nat}
    (vertex : BooleanPoint n) :
    equalityPolynomial
      (fun index => boolToRing (vertex index))
      (fun index => boolToRing (vertex index)) = (1 : F) := by
  rw [equalityPolynomial_bool_left]
  exact multilinearBasis_boolean_self vertex

theorem equalityPolynomial_boolean_ne {n : Nat}
    {lhs rhs : BooleanPoint n}
    (hneq : lhs ≠ rhs) :
    equalityPolynomial
      (fun index => boolToRing (lhs index))
      (fun index => boolToRing (rhs index)) = (0 : F) := by
  rw [equalityPolynomial_bool_left]
  exact multilinearBasis_boolean_ne hneq.symm

end SuperNeoFormal
