import Mathlib.Data.Complex.Basic
import Mathlib.Data.Rat.Lemmas
import Mathlib.Tactic
import SuperNeoFormal.Serialization

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

abbrev FiniteHilbertSpace (A : Type) :=
  A → ℂ

abbrev FiniteLinearOperator (A B : Type) :=
  FiniteHilbertSpace A → FiniteHilbertSpace B

abbrev FiniteMatrixOperator (A B : Type) :=
  B → A → ℂ

def finiteKet {A : Type} [DecidableEq A] (a : A) :
    FiniteHilbertSpace A :=
  fun basis => if basis = a then 1 else 0

def finiteInnerProduct {A : Type} [Fintype A]
    (phi psi : FiniteHilbertSpace A) : ℂ :=
  (Finset.univ : Finset A).sum fun basis =>
    star (phi basis) * psi basis

def finiteMatrixApply {A B : Type} [Fintype A]
    (matrix : FiniteMatrixOperator A B) :
    FiniteLinearOperator A B :=
  fun psi output =>
    (Finset.univ : Finset A).sum fun input =>
      matrix output input * psi input

def finiteMatrixAdjoint {A B : Type}
    (matrix : FiniteMatrixOperator A B) :
    FiniteMatrixOperator B A :=
  fun input output => star (matrix output input)

def finiteTrace {A : Type} [Fintype A]
    (matrix : FiniteMatrixOperator A A) : ℂ :=
  (Finset.univ : Finset A).sum fun basis => matrix basis basis

def complexNonnegative (value : ℂ) : Prop :=
  value.im = 0 ∧ 0 ≤ value.re

def FinitePositiveSemidefinite {A : Type} [Fintype A]
    (matrix : FiniteMatrixOperator A A) : Prop :=
  ∀ psi : FiniteHilbertSpace A,
    complexNonnegative
      (finiteInnerProduct psi (finiteMatrixApply matrix psi))

structure FiniteDensityMatrix (A : Type) [Fintype A] where
  matrix : FiniteMatrixOperator A A
  positiveSemidefinite : FinitePositiveSemidefinite matrix
  traceOne : finiteTrace matrix = 1

structure FiniteSubnormalizedDensityMatrix (A : Type) [Fintype A] where
  matrix : FiniteMatrixOperator A A
  positiveSemidefinite : FinitePositiveSemidefinite matrix
  traceNonnegative : complexNonnegative (finiteTrace matrix)
  traceAtMostOne : (finiteTrace matrix).re ≤ 1

def finiteIdentityOperator (A : Type) : FiniteLinearOperator A A :=
  fun psi => psi

def finiteOperatorComp {A B C : Type}
    (T : FiniteLinearOperator B C)
    (S : FiniteLinearOperator A B) :
    FiniteLinearOperator A C :=
  fun psi => T (S psi)

def finiteBasisPermutationOperator {A B : Type}
    (equiv : A ≃ B) : FiniteLinearOperator A B :=
  fun psi basis => psi (equiv.symm basis)

def finiteBasisPermutationAdjoint {A B : Type}
    (equiv : A ≃ B) : FiniteLinearOperator B A :=
  finiteBasisPermutationOperator equiv.symm

def FiniteIsometry {A B : Type}
    (operator : FiniteLinearOperator A B)
    (adjoint : FiniteLinearOperator B A) : Prop :=
  ∀ psi, adjoint (operator psi) = psi

def FiniteUnitary {A : Type}
    (operator adjoint : FiniteLinearOperator A A) : Prop :=
  (∀ psi, adjoint (operator psi) = psi)
    ∧ (∀ psi, operator (adjoint psi) = psi)

theorem finiteBasisPermutationOperator_leftInverse
    {A B : Type} (equiv : A ≃ B) :
    ∀ psi,
      finiteBasisPermutationAdjoint equiv
          (finiteBasisPermutationOperator equiv psi) = psi := by
  intro psi
  funext basis
  simp [finiteBasisPermutationAdjoint, finiteBasisPermutationOperator]

theorem finiteBasisPermutationOperator_rightInverse
    {A B : Type} (equiv : A ≃ B) :
    ∀ psi,
      finiteBasisPermutationOperator equiv
          (finiteBasisPermutationAdjoint equiv psi) = psi := by
  intro psi
  funext basis
  simp [finiteBasisPermutationAdjoint, finiteBasisPermutationOperator]

theorem finiteBasisPermutationOperator_isometry
    {A B : Type} (equiv : A ≃ B) :
    FiniteIsometry
      (finiteBasisPermutationOperator equiv)
      (finiteBasisPermutationAdjoint equiv) :=
  finiteBasisPermutationOperator_leftInverse equiv

theorem finiteBasisPermutationOperator_unitary
    {A : Type} (equiv : A ≃ A) :
    FiniteUnitary
      (finiteBasisPermutationOperator equiv)
      (finiteBasisPermutationAdjoint equiv) :=
  ⟨finiteBasisPermutationOperator_leftInverse equiv,
    finiteBasisPermutationOperator_rightInverse equiv⟩

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

def quantumRandomOracleQueryEquiv
    {X Y : Type} [AddGroup Y]
    (h : X → Y) : X × Y ≃ X × Y where
  toFun := quantumRandomOracleQuery h
  invFun := quantumRandomOracleQueryInverse h
  left_inv := by
    intro query
    cases query with
    | mk x y =>
        simp [quantumRandomOracleQuery, quantumRandomOracleQueryInverse]
  right_inv := by
    intro query
    cases query with
    | mk x y =>
        simp [quantumRandomOracleQuery, quantumRandomOracleQueryInverse]

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

def quantumRandomOracleOperator
    {X Y : Type} [AddGroup Y]
    (h : X → Y) : FiniteLinearOperator (X × Y) (X × Y) :=
  finiteBasisPermutationOperator (quantumRandomOracleQueryEquiv h)

def quantumRandomOracleOperatorAdjoint
    {X Y : Type} [AddGroup Y]
    (h : X → Y) : FiniteLinearOperator (X × Y) (X × Y) :=
  finiteBasisPermutationAdjoint (quantumRandomOracleQueryEquiv h)

theorem quantumRandomOracleOperator_unitary
    {X Y : Type} [AddGroup Y]
    (h : X → Y) :
    FiniteUnitary
      (quantumRandomOracleOperator h)
      (quantumRandomOracleOperatorAdjoint h) :=
  finiteBasisPermutationOperator_unitary (quantumRandomOracleQueryEquiv h)

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

structure SplitQROSignature where
  L : Type
  X : L → Type
  Y : L → Type
  [lFintype : Fintype L]
  [lDecidableEq : DecidableEq L]
  [xFintype : ∀ label, Fintype (X label)]
  [xDecidableEq : ∀ label, DecidableEq (X label)]
  [yFintype : ∀ label, Fintype (Y label)]
  [yDecidableEq : ∀ label, DecidableEq (Y label)]
  [yAddCommGroup : ∀ label, AddCommGroup (Y label)]

attribute [instance]
  SplitQROSignature.lFintype
  SplitQROSignature.lDecidableEq
  SplitQROSignature.xFintype
  SplitQROSignature.xDecidableEq
  SplitQROSignature.yFintype
  SplitQROSignature.yDecidableEq
  SplitQROSignature.yAddCommGroup

abbrev SplitQROFunction (signature : SplitQROSignature) :=
  ∀ label : signature.L, signature.X label → signature.Y label

abbrev SplitQROQuery (signature : SplitQROSignature) :=
  Sigma fun label : signature.L =>
    signature.X label × signature.Y label

def splitQROQuery
    {signature : SplitQROSignature}
    (H : SplitQROFunction signature) :
    SplitQROQuery signature → SplitQROQuery signature
  | ⟨label, x, y⟩ => ⟨label, x, y + H label x⟩

def splitQROQueryInverse
    {signature : SplitQROSignature}
    (H : SplitQROFunction signature) :
    SplitQROQuery signature → SplitQROQuery signature
  | ⟨label, x, y⟩ => ⟨label, x, y - H label x⟩

def splitQROQueryEquiv
    {signature : SplitQROSignature}
    (H : SplitQROFunction signature) :
    SplitQROQuery signature ≃ SplitQROQuery signature where
  toFun := splitQROQuery H
  invFun := splitQROQueryInverse H
  left_inv := by
    intro query
    rcases query with ⟨label, x, y⟩
    simp [splitQROQuery, splitQROQueryInverse]
  right_inv := by
    intro query
    rcases query with ⟨label, x, y⟩
    simp [splitQROQuery, splitQROQueryInverse]

theorem splitQROQuery_bijective
    {signature : SplitQROSignature}
    (H : SplitQROFunction signature) :
    Function.Bijective (splitQROQuery H) :=
  (splitQROQueryEquiv H).bijective

def splitQROOperator
    {signature : SplitQROSignature}
    (H : SplitQROFunction signature) :
    FiniteLinearOperator
      (SplitQROQuery signature)
      (SplitQROQuery signature) :=
  finiteBasisPermutationOperator (splitQROQueryEquiv H)

def splitQROOperatorAdjoint
    {signature : SplitQROSignature}
    (H : SplitQROFunction signature) :
    FiniteLinearOperator
      (SplitQROQuery signature)
      (SplitQROQuery signature) :=
  finiteBasisPermutationAdjoint (splitQROQueryEquiv H)

theorem splitQROOperator_unitary
    {signature : SplitQROSignature}
    (H : SplitQROFunction signature) :
    FiniteUnitary
      (splitQROOperator H)
      (splitQROOperatorAdjoint H) :=
  finiteBasisPermutationOperator_unitary (splitQROQueryEquiv H)

abbrev SplitQROHiddenState (signature : SplitQROSignature) :=
  SplitQROFunction signature

def splitQROHiddenQuery
    {signature : SplitQROSignature} :
    SplitQROQuery signature × SplitQROHiddenState signature →
      SplitQROQuery signature × SplitQROHiddenState signature
  | (query, H) => (splitQROQuery H query, H)

def splitQROHiddenQueryInverse
    {signature : SplitQROSignature} :
    SplitQROQuery signature × SplitQROHiddenState signature →
      SplitQROQuery signature × SplitQROHiddenState signature
  | (query, H) => (splitQROQueryInverse H query, H)

theorem splitQROHiddenQuery_preservesFunction
    {signature : SplitQROSignature}
    (state :
      SplitQROQuery signature × SplitQROHiddenState signature) :
    (splitQROHiddenQuery state).2 = state.2 := by
  cases state
  rfl

def splitQROHiddenQueryEquiv
    {signature : SplitQROSignature} :
    SplitQROQuery signature × SplitQROHiddenState signature ≃
      SplitQROQuery signature × SplitQROHiddenState signature where
  toFun := splitQROHiddenQuery
  invFun := splitQROHiddenQueryInverse
  left_inv := by
    intro state
    rcases state with ⟨query, H⟩
    rcases query with ⟨label, x, y⟩
    simp [splitQROHiddenQuery, splitQROHiddenQueryInverse,
      splitQROQuery, splitQROQueryInverse]
  right_inv := by
    intro state
    rcases state with ⟨query, H⟩
    rcases query with ⟨label, x, y⟩
    simp [splitQROHiddenQuery, splitQROHiddenQueryInverse,
      splitQROQuery, splitQROQueryInverse]

theorem splitQROHiddenQuery_bijective
    {signature : SplitQROSignature} :
    Function.Bijective
      (splitQROHiddenQuery :
        SplitQROQuery signature × SplitQROHiddenState signature →
          SplitQROQuery signature × SplitQROHiddenState signature) :=
  (splitQROHiddenQueryEquiv : _).bijective

structure SplitQRODomainSeparation
    (signature : SplitQROSignature) where
  encodedAddress :
    (Sigma fun label : signature.L => signature.X label) → List Byte
  perLabelInjective :
    ∀ label,
      Function.Injective
        (fun x : signature.X label =>
          encodedAddress ⟨label, x⟩)
  crossLabelDisjoint :
    ∀ {left right : signature.L}
      (_hDistinct : left ≠ right)
      (x : signature.X left)
      (y : signature.X right),
      encodedAddress ⟨left, x⟩ ≠ encodedAddress ⟨right, y⟩

def SplitQRODomainSeparationAccepted
    {signature : SplitQROSignature}
    (separation : SplitQRODomainSeparation signature) : Prop :=
  (∀ label,
    Function.Injective
      (fun x : signature.X label =>
        separation.encodedAddress ⟨label, x⟩))
    ∧ (∀ {left right : signature.L}
      (_hDistinct : left ≠ right)
      (x : signature.X left)
      (y : signature.X right),
      separation.encodedAddress ⟨left, x⟩ ≠
        separation.encodedAddress ⟨right, y⟩)

theorem SplitQRODomainSeparation.accepted
    {signature : SplitQROSignature}
    (separation : SplitQRODomainSeparation signature) :
    SplitQRODomainSeparationAccepted separation :=
  ⟨separation.perLabelInjective, separation.crossLabelDisjoint⟩

structure SplitQROFunctionDistribution
    (signature : SplitQROSignature) where
  weight : SplitQROHiddenState signature → ℚ
  nonnegative : ∀ H, 0 ≤ weight H
  totalMass :
    (Finset.univ : Finset (SplitQROHiddenState signature)).sum
      weight = 1

def SplitQROFunctionDistributionAccepted
    {signature : SplitQROSignature}
    (distribution : SplitQROFunctionDistribution signature) : Prop :=
  (∀ H, 0 ≤ distribution.weight H)
    ∧ (Finset.univ : Finset (SplitQROHiddenState signature)).sum
      distribution.weight = 1

theorem SplitQROFunctionDistribution.accepted
    {signature : SplitQROSignature}
    (distribution : SplitQROFunctionDistribution signature) :
    SplitQROFunctionDistributionAccepted distribution :=
  ⟨distribution.nonnegative, distribution.totalMass⟩

structure SplitQROSemanticBundle where
  signature : SplitQROSignature
  distribution : SplitQROFunctionDistribution signature
  domainSeparation : SplitQRODomainSeparation signature

def SplitQROSemanticBundleAccepted
    (bundle : SplitQROSemanticBundle) : Prop :=
  SplitQROFunctionDistributionAccepted bundle.distribution
    ∧ (∀ H : SplitQROFunction bundle.signature,
      Function.Bijective (splitQROQuery H))
    ∧ Function.Bijective
      (splitQROHiddenQuery :
        SplitQROQuery bundle.signature ×
          SplitQROHiddenState bundle.signature →
        SplitQROQuery bundle.signature ×
          SplitQROHiddenState bundle.signature)
    ∧ (∀ state :
      SplitQROQuery bundle.signature ×
        SplitQROHiddenState bundle.signature,
      (splitQROHiddenQuery state).2 = state.2)
    ∧ SplitQRODomainSeparationAccepted bundle.domainSeparation

theorem SplitQROSemanticBundle.accepted
    (bundle : SplitQROSemanticBundle) :
    SplitQROSemanticBundleAccepted bundle :=
  ⟨bundle.distribution.accepted,
    fun H => splitQROQuery_bijective H,
    splitQROHiddenQuery_bijective,
    fun state => splitQROHiddenQuery_preservesFunction state,
    bundle.domainSeparation.accepted⟩

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
