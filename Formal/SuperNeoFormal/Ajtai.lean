import Mathlib
import SuperNeoFormal.Profile

/-!
Milestone-1 model for the concrete Ajtai commitment layer.

The quotient-ring multiplication used by Swift/Metal is represented here by an
abstract commutative ring `RF`. The concrete Phi81 constants and estimator
dimensions are fixed in `Profile.lean`; later milestones refine `RF` to the
explicit quotient `F[X] / (X^54 + X^27 + 1)`.
-/

namespace SuperNeoFormal

open Finset

variable {RF : Type} [CommRing RF]

abbrev Message (RF : Type) (columns : Nat) := Fin columns → RF
abbrev AjtaiMatrix (RF : Type) (rows columns : Nat) := Fin rows → Fin columns → RF
abbrev Commitment (RF : Type) (rows : Nat) := Fin rows → RF

def commit {rows columns : Nat} (A : AjtaiMatrix RF rows columns) (z : Message RF columns) :
    Commitment RF rows :=
  fun row => ∑ col : Fin columns, A row col * z col

def Opening {rows columns : Nat}
    (A : AjtaiMatrix RF rows columns)
    (c : Commitment RF rows)
    (bounded : Message RF columns → Prop)
    (z : Message RF columns) : Prop :=
  bounded z ∧ commit A z = c

def DifferenceOfBounded {columns : Nat}
    (bounded : Message RF columns → Prop)
    (diff : Message RF columns) : Prop :=
  ∃ lhs rhs : Message RF columns, bounded lhs ∧ bounded rhs ∧ diff = lhs - rhs

def NoShortKernel {rows columns : Nat}
    (A : AjtaiMatrix RF rows columns)
    (bounded : Message RF columns → Prop) : Prop :=
  ∀ diff : Message RF columns,
    DifferenceOfBounded bounded diff →
    commit A diff = 0 →
    diff = 0

theorem commit_zero {rows columns : Nat} (A : AjtaiMatrix RF rows columns) :
    commit A (0 : Message RF columns) = 0 := by
  funext row
  simp [commit]

theorem commit_add {rows columns : Nat}
    (A : AjtaiMatrix RF rows columns)
    (lhs rhs : Message RF columns) :
    commit A (lhs + rhs) = commit A lhs + commit A rhs := by
  funext row
  simp [commit, mul_add, Finset.sum_add_distrib]

theorem commit_neg {rows columns : Nat}
    (A : AjtaiMatrix RF rows columns)
    (z : Message RF columns) :
    commit A (-z) = -commit A z := by
  funext row
  simp [commit]

theorem commit_sub {rows columns : Nat}
    (A : AjtaiMatrix RF rows columns)
    (lhs rhs : Message RF columns) :
    commit A (lhs - rhs) = commit A lhs - commit A rhs := by
  funext row
  simp [commit, sub_eq_add_neg, mul_add, Finset.sum_add_distrib]

theorem opening_commitment_unique_under_message_eq {rows columns : Nat}
    {A : AjtaiMatrix RF rows columns}
    {bounded : Message RF columns → Prop}
    {lhs rhs : Message RF columns}
    {c : Commitment RF rows}
    (_hlhs : Opening A c bounded lhs)
    (_hrhs : Opening A c bounded rhs)
    (hmsg : lhs = rhs) :
    commit A lhs = commit A rhs := by
  subst hmsg
  rfl

theorem binding_from_noShortKernel {rows columns : Nat}
    {A : AjtaiMatrix RF rows columns}
    {bounded : Message RF columns → Prop}
    {lhs rhs : Message RF columns}
    (hKernel : NoShortKernel A bounded)
    (hlhs : bounded lhs)
    (hrhs : bounded rhs)
    (hCommit : commit A lhs = commit A rhs) :
    lhs = rhs := by
  have hDiffBounded : DifferenceOfBounded bounded (lhs - rhs) := by
    exact ⟨lhs, rhs, hlhs, hrhs, rfl⟩
  have hDiffCommit : commit A (lhs - rhs) = 0 := by
    rw [commit_sub, hCommit]
    simp
  have hDiffZero : lhs - rhs = 0 := hKernel (lhs - rhs) hDiffBounded hDiffCommit
  funext col
  have hAtCol : lhs col - rhs col = (0 : RF) := by
    simpa using congrFun hDiffZero col
  exact sub_eq_zero.mp hAtCol

end SuperNeoFormal
