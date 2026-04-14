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

def BindingSecure {rows columns : Nat}
    (A : AjtaiMatrix RF rows columns)
    (bounded : Message RF columns → Prop) : Prop :=
  ∀ lhs rhs : Message RF columns,
    ∀ c : Commitment RF rows,
      Opening A c bounded lhs →
      Opening A c bounded rhs →
      lhs = rhs

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

theorem distinct_openings_yield_short_kernel {rows columns : Nat}
    {A : AjtaiMatrix RF rows columns}
    {bounded : Message RF columns → Prop}
    {lhs rhs : Message RF columns}
    {c : Commitment RF rows}
    (hlhs : Opening A c bounded lhs)
    (hrhs : Opening A c bounded rhs)
    (hmsg : lhs ≠ rhs) :
    ∃ diff : Message RF columns,
      DifferenceOfBounded bounded diff ∧ commit A diff = 0 ∧ diff ≠ 0 := by
  refine ⟨lhs - rhs, ?_, ?_, ?_⟩
  · exact ⟨lhs, rhs, hlhs.1, hrhs.1, rfl⟩
  · rw [commit_sub, hlhs.2, hrhs.2]
    simp
  · intro hDiffZero
    apply hmsg
    funext col
    have hAtCol : lhs col - rhs col = (0 : RF) := by
      simpa using congrFun hDiffZero col
    exact sub_eq_zero.mp hAtCol

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

theorem opening_messages_equal_from_noShortKernel {rows columns : Nat}
    {A : AjtaiMatrix RF rows columns}
    {bounded : Message RF columns → Prop}
    {lhs rhs : Message RF columns}
    {c : Commitment RF rows}
    (hKernel : NoShortKernel A bounded)
    (hlhs : Opening A c bounded lhs)
    (hrhs : Opening A c bounded rhs) :
    lhs = rhs := by
  apply binding_from_noShortKernel hKernel hlhs.1 hrhs.1
  rw [hlhs.2, hrhs.2]

theorem bindingSecure_from_noShortKernel {rows columns : Nat}
    {A : AjtaiMatrix RF rows columns}
    {bounded : Message RF columns → Prop}
    (hKernel : NoShortKernel A bounded) :
    BindingSecure A bounded := by
  intro lhs rhs c hlhs hrhs
  exact opening_messages_equal_from_noShortKernel hKernel hlhs hrhs

theorem noShortKernel_from_bindingSecure {rows columns : Nat}
    {A : AjtaiMatrix RF rows columns}
    {bounded : Message RF columns → Prop}
    (hBinding : BindingSecure A bounded) :
    NoShortKernel A bounded := by
  intro diff hDiff hCommit
  rcases hDiff with ⟨lhs, rhs, hlhs, hrhs, hDiffEq⟩
  subst diff
  have hCommitEq : commit A lhs = commit A rhs := by
    have hSubZero : commit A lhs - commit A rhs = 0 := by
      simpa [commit_sub] using hCommit
    exact sub_eq_zero.mp hSubZero
  have hMsgEq : lhs = rhs := hBinding lhs rhs (commit A rhs) ⟨hlhs, hCommitEq⟩ ⟨hrhs, rfl⟩
  simp [hMsgEq]

theorem noShortKernel_iff_bindingSecure {rows columns : Nat}
    {A : AjtaiMatrix RF rows columns}
    {bounded : Message RF columns → Prop} :
    NoShortKernel A bounded ↔ BindingSecure A bounded := by
  constructor
  · exact bindingSecure_from_noShortKernel
  · exact noShortKernel_from_bindingSecure

theorem short_kernel_yields_binding_failure {rows columns : Nat}
    {A : AjtaiMatrix RF rows columns}
    {bounded : Message RF columns → Prop}
    {diff : Message RF columns}
    (hDiff : DifferenceOfBounded bounded diff)
    (hCommit : commit A diff = 0)
    (hNonzero : diff ≠ 0) :
    ¬ BindingSecure A bounded := by
  intro hBinding
  rcases hDiff with ⟨lhs, rhs, hlhs, hrhs, hDiffEq⟩
  subst diff
  have hCommitEq : commit A lhs = commit A rhs := by
    have hSubZero : commit A lhs - commit A rhs = 0 := by
      simpa [commit_sub] using hCommit
    exact sub_eq_zero.mp hSubZero
  have hMsgEq : lhs = rhs :=
    hBinding lhs rhs (commit A rhs) ⟨hlhs, hCommitEq⟩ ⟨hrhs, rfl⟩
  exact hNonzero (by simp [hMsgEq])

theorem binding_failure_yields_short_kernel {rows columns : Nat}
    {A : AjtaiMatrix RF rows columns}
    {bounded : Message RF columns → Prop}
    (hFailure : ¬ BindingSecure A bounded) :
    ∃ diff : Message RF columns,
      DifferenceOfBounded bounded diff ∧ commit A diff = 0 ∧ diff ≠ 0 := by
  classical
  by_contra hNoWitness
  apply hFailure
  intro lhs rhs c hlhs hrhs
  by_contra hDistinct
  exact hNoWitness (distinct_openings_yield_short_kernel hlhs hrhs hDistinct)

theorem not_bindingSecure_iff_exists_short_kernel {rows columns : Nat}
    {A : AjtaiMatrix RF rows columns}
    {bounded : Message RF columns → Prop} :
    (¬ BindingSecure A bounded) ↔
      ∃ diff : Message RF columns,
        DifferenceOfBounded bounded diff ∧ commit A diff = 0 ∧ diff ≠ 0 := by
  constructor
  · exact binding_failure_yields_short_kernel
  · intro hWitness
    rcases hWitness with ⟨diff, hDiff, hCommit, hNonzero⟩
    exact short_kernel_yields_binding_failure hDiff hCommit hNonzero

end SuperNeoFormal
