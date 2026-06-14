import Mathlib.Data.Rat.Lemmas
import Mathlib.Tactic

/-!
Finite quantum-random-oracle core semantics.

This module records the model-theoretic part of a QROM that is independent of
any product protocol: a finite random function `h : X → Y` is sampled once, and
the adversary's query interface is the reversible basis action
`(x, y) ↦ (x, y + h x)`.  The linear/unitary extension to finite-dimensional
Hilbert spaces is not developed here; the Lean proof below verifies the
necessary computational-basis permutation that such an extension acts on.
-/

noncomputable section

namespace SuperNeoFormal

open Finset

structure QROFunctionDistribution
    (X Y : Type)
    [Fintype X] [DecidableEq X]
    [Fintype Y] [DecidableEq Y] where
  weight : (X → Y) → ℚ
  nonnegative : ∀ h, 0 ≤ weight h
  totalMass : (Finset.univ : Finset (X → Y)).sum weight = 1

def QROFunctionDistributionAccepted
    {X Y : Type}
    [Fintype X] [DecidableEq X]
    [Fintype Y] [DecidableEq Y]
    (distribution : QROFunctionDistribution X Y) : Prop :=
  (∀ h, 0 ≤ distribution.weight h)
    ∧ (Finset.univ : Finset (X → Y)).sum distribution.weight = 1

theorem QROFunctionDistribution.accepted
    {X Y : Type}
    [Fintype X] [DecidableEq X]
    [Fintype Y] [DecidableEq Y]
    (distribution : QROFunctionDistribution X Y) :
    QROFunctionDistributionAccepted distribution :=
  ⟨distribution.nonnegative, distribution.totalMass⟩

def quantumRandomOracleQuery
    {X Y : Type} [AddGroup Y]
    (h : X → Y) : X × Y → X × Y
  | (x, y) => (x, y + h x)

def quantumRandomOracleQueryInverse
    {X Y : Type} [AddGroup Y]
    (h : X → Y) : X × Y → X × Y
  | (x, y) => (x, y - h x)

theorem quantumRandomOracleQuery_leftInverse
    {X Y : Type} [AddGroup Y]
    (h : X → Y) :
    Function.LeftInverse
      (quantumRandomOracleQueryInverse h)
      (quantumRandomOracleQuery h) := by
  intro query
  cases query with
  | mk x y =>
      simp [quantumRandomOracleQuery, quantumRandomOracleQueryInverse]

theorem quantumRandomOracleQuery_rightInverse
    {X Y : Type} [AddGroup Y]
    (h : X → Y) :
    Function.RightInverse
      (quantumRandomOracleQueryInverse h)
      (quantumRandomOracleQuery h) := by
  intro query
  cases query with
  | mk x y =>
      simp [quantumRandomOracleQuery, quantumRandomOracleQueryInverse]

theorem quantumRandomOracleQuery_bijective
    {X Y : Type} [AddGroup Y]
    (h : X → Y) :
    Function.Bijective (quantumRandomOracleQuery h) := by
  refine ⟨?injective, ?surjective⟩
  · exact
      (quantumRandomOracleQuery_leftInverse h).injective
  · intro query
    exact
      ⟨quantumRandomOracleQueryInverse h query,
        quantumRandomOracleQuery_rightInverse h query⟩

def quantumRandomOracleBasisTrace
    {X Y : Type} [AddGroup Y]
    (h : X → Y) (queries : List (X × Y)) : List (X × Y) :=
  queries.map (quantumRandomOracleQuery h)

theorem quantumRandomOracleBasisTrace_sameSample
    {X Y : Type} [AddGroup Y]
    (h : X → Y) (queries : List (X × Y)) :
    quantumRandomOracleBasisTrace h queries =
      queries.map (quantumRandomOracleQuery h) :=
  rfl

def quantumRandomOracleHiddenQuery
    {X Y : Type} [AddGroup Y] :
    (X × Y) × (X → Y) → (X × Y) × (X → Y)
  | ((x, y), h) => ((x, y + h x), h)

def quantumRandomOracleHiddenQueryInverse
    {X Y : Type} [AddGroup Y] :
    (X × Y) × (X → Y) → (X × Y) × (X → Y)
  | ((x, y), h) => ((x, y - h x), h)

theorem quantumRandomOracleHiddenQuery_preservesFunction
    {X Y : Type} [AddGroup Y]
    (state : (X × Y) × (X → Y)) :
    (quantumRandomOracleHiddenQuery state).2 = state.2 := by
  cases state with
  | mk query h =>
      cases query
      rfl

theorem quantumRandomOracleHiddenQuery_leftInverse
    {X Y : Type} [AddGroup Y] :
    Function.LeftInverse
      (quantumRandomOracleHiddenQueryInverse :
        (X × Y) × (X → Y) → (X × Y) × (X → Y))
      quantumRandomOracleHiddenQuery := by
  intro state
  cases state with
  | mk query h =>
      cases query with
      | mk x y =>
          simp [quantumRandomOracleHiddenQuery,
            quantumRandomOracleHiddenQueryInverse]

theorem quantumRandomOracleHiddenQuery_rightInverse
    {X Y : Type} [AddGroup Y] :
    Function.RightInverse
      (quantumRandomOracleHiddenQueryInverse :
        (X × Y) × (X → Y) → (X × Y) × (X → Y))
      quantumRandomOracleHiddenQuery := by
  intro state
  cases state with
  | mk query h =>
      cases query with
      | mk x y =>
          simp [quantumRandomOracleHiddenQuery,
            quantumRandomOracleHiddenQueryInverse]

theorem quantumRandomOracleHiddenQuery_bijective
    {X Y : Type} [AddGroup Y] :
    Function.Bijective
      (quantumRandomOracleHiddenQuery :
        (X × Y) × (X → Y) → (X × Y) × (X → Y)) := by
  refine ⟨?injective, ?surjective⟩
  · exact quantumRandomOracleHiddenQuery_leftInverse.injective
  · intro state
    exact
      ⟨quantumRandomOracleHiddenQueryInverse state,
        quantumRandomOracleHiddenQuery_rightInverse state⟩

structure ProductQROSemanticBundle where
  X : Type
  Y : Type
  [xFintype : Fintype X]
  [xDecidableEq : DecidableEq X]
  [yFintype : Fintype Y]
  [yDecidableEq : DecidableEq Y]
  [yAddCommGroup : AddCommGroup Y]
  distribution : QROFunctionDistribution X Y

attribute [instance]
  ProductQROSemanticBundle.xFintype
  ProductQROSemanticBundle.xDecidableEq
  ProductQROSemanticBundle.yFintype
  ProductQROSemanticBundle.yDecidableEq
  ProductQROSemanticBundle.yAddCommGroup

def ProductQROSemanticBundleAccepted
    (bundle : ProductQROSemanticBundle) : Prop :=
  QROFunctionDistributionAccepted bundle.distribution
    ∧ (∀ h : bundle.X → bundle.Y,
      Function.Bijective (quantumRandomOracleQuery h))
    ∧ Function.Bijective
      (quantumRandomOracleHiddenQuery :
        (bundle.X × bundle.Y) × (bundle.X → bundle.Y) →
          (bundle.X × bundle.Y) × (bundle.X → bundle.Y))
    ∧ (∀ state : (bundle.X × bundle.Y) × (bundle.X → bundle.Y),
      (quantumRandomOracleHiddenQuery state).2 = state.2)

theorem ProductQROSemanticBundle.accepted
    (bundle : ProductQROSemanticBundle) :
    ProductQROSemanticBundleAccepted bundle :=
  ⟨bundle.distribution.accepted,
    fun h => quantumRandomOracleQuery_bijective h,
    quantumRandomOracleHiddenQuery_bijective,
    fun state => quantumRandomOracleHiddenQuery_preservesFunction state⟩

end SuperNeoFormal
