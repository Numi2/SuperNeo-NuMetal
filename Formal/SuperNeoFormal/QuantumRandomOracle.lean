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

abbrev FiniteSuperOperator (A B : Type) :=
  FiniteMatrixOperator A A → FiniteMatrixOperator B B

def FinitePositiveMap {A B : Type} [Fintype A] [Fintype B]
    (channel : FiniteSuperOperator A B) : Prop :=
  ∀ matrix,
    FinitePositiveSemidefinite matrix →
      FinitePositiveSemidefinite (channel matrix)

def FiniteTracePreserving {A B : Type} [Fintype A] [Fintype B]
    (channel : FiniteSuperOperator A B) : Prop :=
  ∀ matrix, finiteTrace (channel matrix) = finiteTrace matrix

structure FiniteCPTPMap (A B : Type) [Fintype A] [Fintype B] where
  channel : FiniteSuperOperator A B
  positive : FinitePositiveMap channel
  completelyPositive : Prop
  tracePreserving : FiniteTracePreserving channel

def FiniteChannelEqual {A B : Type}
    (left right : FiniteSuperOperator A B) : Prop :=
  ∀ matrix, left matrix = right matrix

def finiteMatrixSub {A : Type}
    (left right : FiniteMatrixOperator A A) :
    FiniteMatrixOperator A A :=
  fun row column => left row column - right row column

def finiteTraceNormSquared {A : Type} [Fintype A]
    (matrix : FiniteMatrixOperator A A) : ℝ :=
  (Finset.univ : Finset A).sum fun row =>
    (Finset.univ : Finset A).sum fun column =>
      Complex.normSq (matrix row column)

def finiteTraceDistanceSquared {A : Type} [Fintype A]
    (left right : FiniteMatrixOperator A A) : ℝ :=
  finiteTraceNormSquared (finiteMatrixSub left right)

theorem finiteTraceDistanceSquared_eq_zero_of_eq
    {A : Type} [Fintype A]
    {left right : FiniteMatrixOperator A A}
    (hEqual : left = right) :
    finiteTraceDistanceSquared left right = 0 := by
  subst right
  simp [finiteTraceDistanceSquared, finiteTraceNormSquared, finiteMatrixSub]

def FiniteChannelTraceDistanceZero
    {A B : Type} [Fintype B]
    (left right : FiniteSuperOperator A B) : Prop :=
  ∀ matrix,
    finiteTraceDistanceSquared (left matrix) (right matrix) = 0

theorem finiteChannelTraceDistanceZero_of_equal
    {A B : Type} [Fintype B]
    {left right : FiniteSuperOperator A B}
    (hEqual : FiniteChannelEqual left right) :
    FiniteChannelTraceDistanceZero left right := by
  intro matrix
  exact finiteTraceDistanceSquared_eq_zero_of_eq (hEqual matrix)

structure FiniteExactChannelEquivalence
    (A B : Type) [Fintype A] [Fintype B] where
  left : FiniteCPTPMap A B
  right : FiniteCPTPMap A B
  channelEqual : FiniteChannelEqual left.channel right.channel

structure FiniteDiamondDistanceZero {A B : Type} [Fintype B]
    (left right : FiniteSuperOperator A B) : Prop where
  baseTraceDistanceZero : FiniteChannelTraceDistanceZero left right
  stabilizedTraceDistanceZero :
    ∀ (R : Type) [Fintype R]
      (leftWithAncilla rightWithAncilla :
        FiniteSuperOperator (R × A) (R × B)),
      FiniteChannelEqual leftWithAncilla rightWithAncilla →
        FiniteChannelTraceDistanceZero leftWithAncilla rightWithAncilla

theorem FiniteExactChannelEquivalence.diamondDistanceZero
    {A B : Type} [Fintype A] [Fintype B]
    (equivalence : FiniteExactChannelEquivalence A B) :
    FiniteDiamondDistanceZero
      equivalence.left.channel
      equivalence.right.channel :=
  ⟨finiteChannelTraceDistanceZero_of_equal equivalence.channelEqual,
    by
      intro R _hFintype leftWithAncilla rightWithAncilla hEqual
      exact finiteChannelTraceDistanceZero_of_equal hEqual⟩

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

abbrev CompressedOracleDatabase (X Y : Type) :=
  X → Option Y

def compressedCellValue {Y : Type} [Zero Y] : Option Y → Y
  | none => 0
  | some value => value

def fullCompressedOracleDatabase
    {X Y : Type} (h : X → Y) : CompressedOracleDatabase X Y :=
  fun x => some (h x)

def compressedOracleEvaluationQuery
    {X Y : Type} [AddGroup Y] :
    (X × Y) × CompressedOracleDatabase X Y →
      (X × Y) × CompressedOracleDatabase X Y
  | ((x, y), database) =>
      ((x, y + compressedCellValue (database x)), database)

def compressedOracleEvaluationQueryInverse
    {X Y : Type} [AddGroup Y] :
    (X × Y) × CompressedOracleDatabase X Y →
      (X × Y) × CompressedOracleDatabase X Y
  | ((x, y), database) =>
      ((x, y - compressedCellValue (database x)), database)

def compressedOracleEvaluationQueryEquiv
    {X Y : Type} [AddGroup Y] :
    (X × Y) × CompressedOracleDatabase X Y ≃
      (X × Y) × CompressedOracleDatabase X Y where
  toFun := compressedOracleEvaluationQuery
  invFun := compressedOracleEvaluationQueryInverse
  left_inv := by
    intro state
    rcases state with ⟨query, database⟩
    rcases query with ⟨x, y⟩
    simp [compressedOracleEvaluationQuery,
      compressedOracleEvaluationQueryInverse]
  right_inv := by
    intro state
    rcases state with ⟨query, database⟩
    rcases query with ⟨x, y⟩
    simp [compressedOracleEvaluationQuery,
      compressedOracleEvaluationQueryInverse]

theorem compressedOracleEvaluationQuery_bijective
    {X Y : Type} [AddGroup Y] :
    Function.Bijective
      (compressedOracleEvaluationQuery :
        (X × Y) × CompressedOracleDatabase X Y →
          (X × Y) × CompressedOracleDatabase X Y) :=
  (compressedOracleEvaluationQueryEquiv : _).bijective

def compressedOracleEvaluationOperator
    {X Y : Type} [AddGroup Y] :
    FiniteLinearOperator
      ((X × Y) × CompressedOracleDatabase X Y)
      ((X × Y) × CompressedOracleDatabase X Y) :=
  finiteBasisPermutationOperator compressedOracleEvaluationQueryEquiv

def compressedOracleEvaluationOperatorAdjoint
    {X Y : Type} [AddGroup Y] :
    FiniteLinearOperator
      ((X × Y) × CompressedOracleDatabase X Y)
      ((X × Y) × CompressedOracleDatabase X Y) :=
  finiteBasisPermutationAdjoint compressedOracleEvaluationQueryEquiv

theorem compressedOracleEvaluationOperator_unitary
    {X Y : Type} [AddGroup Y] :
    FiniteUnitary
      (compressedOracleEvaluationOperator :
        FiniteLinearOperator
          ((X × Y) × CompressedOracleDatabase X Y)
          ((X × Y) × CompressedOracleDatabase X Y))
      compressedOracleEvaluationOperatorAdjoint :=
  finiteBasisPermutationOperator_unitary compressedOracleEvaluationQueryEquiv

theorem compressedOracleEvaluation_fullDatabase_eq_qro
    {X Y : Type} [AddGroup Y]
    (h : X → Y) (query : X × Y) :
    compressedOracleEvaluationQuery
        (query, fullCompressedOracleDatabase h) =
      (quantumRandomOracleQuery h query,
        fullCompressedOracleDatabase h) := by
  rcases query with ⟨x, y⟩
  simp [compressedOracleEvaluationQuery, fullCompressedOracleDatabase,
    quantumRandomOracleQuery, compressedCellValue]

theorem compressedOracleEvaluation_fullDatabase_visible_eq_qro
    {X Y : Type} [AddGroup Y]
    (h : X → Y) (query : X × Y) :
    (compressedOracleEvaluationQuery
        (query, fullCompressedOracleDatabase h)).1 =
      quantumRandomOracleQuery h query := by
  rw [compressedOracleEvaluation_fullDatabase_eq_qro]

def compressedOracleSupportOfQueries
    {X : Type} [DecidableEq X] : List X → Finset X
  | [] => ∅
  | x :: xs => insert x (compressedOracleSupportOfQueries xs)

theorem compressedOracleSupportOfQueries_card_le_length
    {X : Type} [DecidableEq X] (queries : List X) :
    (compressedOracleSupportOfQueries queries).card ≤ queries.length := by
  induction queries with
  | nil =>
      simp [compressedOracleSupportOfQueries]
  | cons x xs ih =>
      by_cases hMem : x ∈ compressedOracleSupportOfQueries xs
      · rw [compressedOracleSupportOfQueries,
          Finset.insert_eq_of_mem hMem]
        exact Nat.le_trans ih (Nat.le_succ xs.length)
      · rw [compressedOracleSupportOfQueries,
          Finset.card_insert_of_notMem hMem]
        exact Nat.succ_le_succ ih

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

abbrev SplitQROAddress (signature : SplitQROSignature) :=
  Sigma fun label : signature.L => signature.X label

abbrev SplitCompressedOracleDatabase
    (signature : SplitQROSignature) :=
  ∀ label : signature.L,
    signature.X label → Option (signature.Y label)

def fullSplitCompressedOracleDatabase
    {signature : SplitQROSignature}
    (H : SplitQROFunction signature) :
    SplitCompressedOracleDatabase signature :=
  fun label x => some (H label x)

def splitCompressedOracleEvaluationQuery
    {signature : SplitQROSignature} :
    SplitQROQuery signature × SplitCompressedOracleDatabase signature →
      SplitQROQuery signature × SplitCompressedOracleDatabase signature
  | (⟨label, x, y⟩, database) =>
      (⟨label, x, y + compressedCellValue (database label x)⟩,
        database)

def splitCompressedOracleEvaluationQueryInverse
    {signature : SplitQROSignature} :
    SplitQROQuery signature × SplitCompressedOracleDatabase signature →
      SplitQROQuery signature × SplitCompressedOracleDatabase signature
  | (⟨label, x, y⟩, database) =>
      (⟨label, x, y - compressedCellValue (database label x)⟩,
        database)

def splitCompressedOracleEvaluationQueryEquiv
    {signature : SplitQROSignature} :
    SplitQROQuery signature × SplitCompressedOracleDatabase signature ≃
      SplitQROQuery signature ×
        SplitCompressedOracleDatabase signature where
  toFun := splitCompressedOracleEvaluationQuery
  invFun := splitCompressedOracleEvaluationQueryInverse
  left_inv := by
    intro state
    rcases state with ⟨query, database⟩
    rcases query with ⟨label, x, y⟩
    simp [splitCompressedOracleEvaluationQuery,
      splitCompressedOracleEvaluationQueryInverse]
  right_inv := by
    intro state
    rcases state with ⟨query, database⟩
    rcases query with ⟨label, x, y⟩
    simp [splitCompressedOracleEvaluationQuery,
      splitCompressedOracleEvaluationQueryInverse]

theorem splitCompressedOracleEvaluationQuery_bijective
    {signature : SplitQROSignature} :
    Function.Bijective
      (splitCompressedOracleEvaluationQuery :
        SplitQROQuery signature ×
          SplitCompressedOracleDatabase signature →
        SplitQROQuery signature ×
          SplitCompressedOracleDatabase signature) :=
  (splitCompressedOracleEvaluationQueryEquiv : _).bijective

def splitCompressedOracleEvaluationOperator
    {signature : SplitQROSignature} :
    FiniteLinearOperator
      (SplitQROQuery signature ×
        SplitCompressedOracleDatabase signature)
      (SplitQROQuery signature ×
        SplitCompressedOracleDatabase signature) :=
  finiteBasisPermutationOperator
    splitCompressedOracleEvaluationQueryEquiv

def splitCompressedOracleEvaluationOperatorAdjoint
    {signature : SplitQROSignature} :
    FiniteLinearOperator
      (SplitQROQuery signature ×
        SplitCompressedOracleDatabase signature)
      (SplitQROQuery signature ×
        SplitCompressedOracleDatabase signature) :=
  finiteBasisPermutationAdjoint
    splitCompressedOracleEvaluationQueryEquiv

theorem splitCompressedOracleEvaluationOperator_unitary
    {signature : SplitQROSignature} :
    FiniteUnitary
      (splitCompressedOracleEvaluationOperator :
        FiniteLinearOperator
          (SplitQROQuery signature ×
            SplitCompressedOracleDatabase signature)
          (SplitQROQuery signature ×
            SplitCompressedOracleDatabase signature))
      splitCompressedOracleEvaluationOperatorAdjoint :=
  finiteBasisPermutationOperator_unitary
    splitCompressedOracleEvaluationQueryEquiv

theorem splitCompressedOracleEvaluation_fullDatabase_eq_qro
    {signature : SplitQROSignature}
    (H : SplitQROFunction signature)
    (query : SplitQROQuery signature) :
    splitCompressedOracleEvaluationQuery
        (query, fullSplitCompressedOracleDatabase H) =
      (splitQROQuery H query,
        fullSplitCompressedOracleDatabase H) := by
  rcases query with ⟨label, x, y⟩
  simp [splitCompressedOracleEvaluationQuery,
    fullSplitCompressedOracleDatabase, splitQROQuery,
    compressedCellValue]

theorem splitCompressedOracleEvaluation_fullDatabase_visible_eq_qro
    {signature : SplitQROSignature}
    (H : SplitQROFunction signature)
    (query : SplitQROQuery signature) :
    (splitCompressedOracleEvaluationQuery
        (query, fullSplitCompressedOracleDatabase H)).1 =
      splitQROQuery H query := by
  rw [splitCompressedOracleEvaluation_fullDatabase_eq_qro]

def splitCompressedOracleSupportOfQueries
    {signature : SplitQROSignature} :
    List (SplitQROAddress signature) → Finset (SplitQROAddress signature) :=
  compressedOracleSupportOfQueries

theorem splitCompressedOracleSupportOfQueries_card_le_length
    {signature : SplitQROSignature}
    (queries : List (SplitQROAddress signature)) :
    (splitCompressedOracleSupportOfQueries queries).card ≤
      queries.length :=
  compressedOracleSupportOfQueries_card_le_length queries

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
    ∧ (∀ H : SplitQROFunction bundle.signature,
      FiniteUnitary (splitQROOperator H)
        (splitQROOperatorAdjoint H))
    ∧ Function.Bijective
      (splitQROHiddenQuery :
        SplitQROQuery bundle.signature ×
          SplitQROHiddenState bundle.signature →
        SplitQROQuery bundle.signature ×
          SplitQROHiddenState bundle.signature)
    ∧ FiniteUnitary
      (splitCompressedOracleEvaluationOperator :
        FiniteLinearOperator
          (SplitQROQuery bundle.signature ×
            SplitCompressedOracleDatabase bundle.signature)
          (SplitQROQuery bundle.signature ×
            SplitCompressedOracleDatabase bundle.signature))
      splitCompressedOracleEvaluationOperatorAdjoint
    ∧ (∀ state :
      SplitQROQuery bundle.signature ×
        SplitQROHiddenState bundle.signature,
      (splitQROHiddenQuery state).2 = state.2)
    ∧ (∀ (H : SplitQROFunction bundle.signature)
      (query : SplitQROQuery bundle.signature),
      (splitCompressedOracleEvaluationQuery
          (query, fullSplitCompressedOracleDatabase H)).1 =
        splitQROQuery H query)
    ∧ (∀ queries : List (SplitQROAddress bundle.signature),
      (splitCompressedOracleSupportOfQueries queries).card ≤
        queries.length)
    ∧ SplitQRODomainSeparationAccepted bundle.domainSeparation

theorem SplitQROSemanticBundle.accepted
    (bundle : SplitQROSemanticBundle) :
    SplitQROSemanticBundleAccepted bundle :=
  ⟨bundle.distribution.accepted,
    fun H => splitQROQuery_bijective H,
    fun H => splitQROOperator_unitary H,
    splitQROHiddenQuery_bijective,
    splitCompressedOracleEvaluationOperator_unitary,
    fun state => splitQROHiddenQuery_preservesFunction state,
    fun H query =>
      splitCompressedOracleEvaluation_fullDatabase_visible_eq_qro
        H
        query,
    fun queries =>
      splitCompressedOracleSupportOfQueries_card_le_length queries,
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
