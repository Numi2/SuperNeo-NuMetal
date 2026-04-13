import SuperNeoFormal.PiRLC

/-!
Concrete CCS relation semantics.

The Swift CCS layer evaluates sparse field matrices against the full witness
vector and then evaluates a serialized relation polynomial on the per-row matrix
outputs.  This module formalizes that surface over an arbitrary commutative
ring.  It intentionally stays algebraic: byte serialization and Fiat-Shamir
binding are handled by separate trust boundaries.
-/

noncomputable section

namespace SuperNeoFormal

open Finset

variable {RF : Type} [CommRing RF]

abbrev CCSMatrix (RF : Type) (rows columns : Nat) :=
  Fin rows → Fin columns → RF

structure SparseMatrixEntry (RF : Type) (rows columns : Nat) where
  row : Fin rows
  column : Fin columns
  value : RF

abbrev SparseMatrix (RF : Type) (rows columns nnz : Nat) :=
  Fin nnz → SparseMatrixEntry RF rows columns

def sparseMatrixToDense {rows columns nnz : Nat}
    (entries : SparseMatrix RF rows columns nnz) : CCSMatrix RF rows columns :=
  fun row column =>
    ∑ entryIndex : Fin nnz,
      if (entries entryIndex).row = row ∧ (entries entryIndex).column = column then
        (entries entryIndex).value
      else
        0

def denseMatrixEval {rows columns : Nat}
    (matrix : CCSMatrix RF rows columns)
    (vector : ProtocolVector RF columns) : ProtocolVector RF rows :=
  fun row => ∑ column : Fin columns, matrix row column * vector column

def sparseMatrixEval {rows columns nnz : Nat}
    (entries : SparseMatrix RF rows columns nnz)
    (vector : ProtocolVector RF columns) : ProtocolVector RF rows :=
  fun row =>
    ∑ entryIndex : Fin nnz,
      if (entries entryIndex).row = row then
        (entries entryIndex).value * vector (entries entryIndex).column
      else
        0

theorem sparseMatrixEval_eq_denseMatrixEval {rows columns nnz : Nat}
    (entries : SparseMatrix RF rows columns nnz)
    (vector : ProtocolVector RF columns) :
    sparseMatrixEval entries vector =
      denseMatrixEval (sparseMatrixToDense entries) vector := by
  funext row
  unfold sparseMatrixEval denseMatrixEval sparseMatrixToDense
  calc
    (∑ entryIndex : Fin nnz,
      if (entries entryIndex).row = row then
        (entries entryIndex).value * vector (entries entryIndex).column
      else
        0)
        = ∑ entryIndex : Fin nnz,
            ∑ column : Fin columns,
              (if (entries entryIndex).row = row ∧
                  (entries entryIndex).column = column then
                (entries entryIndex).value
              else
                0) * vector column := by
          apply Finset.sum_congr rfl
          intro entryIndex _
          by_cases hRow : (entries entryIndex).row = row
          · rw [if_pos hRow]
            rw [Finset.sum_eq_single (entries entryIndex).column]
            · simp [hRow]
            · intro column _ hColumn
              have hNe :
                  ¬((entries entryIndex).row = row ∧
                    (entries entryIndex).column = column) := by
                intro h
                exact hColumn h.2.symm
              simp [hNe]
            · simp
          · rw [if_neg hRow]
            simp [hRow]
    _ = ∑ column : Fin columns,
          ∑ entryIndex : Fin nnz,
            (if (entries entryIndex).row = row ∧
                (entries entryIndex).column = column then
              (entries entryIndex).value
            else
              0) * vector column := by
          rw [Finset.sum_comm]
    _ = ∑ column : Fin columns,
          (∑ entryIndex : Fin nnz,
            if (entries entryIndex).row = row ∧
                (entries entryIndex).column = column then
              (entries entryIndex).value
            else
              0) * vector column := by
          apply Finset.sum_congr rfl
          intro column _
          rw [Finset.sum_mul]

theorem denseMatrixEval_weightedVector {rows columns count : Nat}
    (matrix : CCSMatrix RF rows columns)
    (challenges : Fin count → RF)
    (vectors : Fin count → ProtocolVector RF columns) :
    denseMatrixEval matrix (rlcWeightedVector challenges vectors) =
      rlcWeightedVector challenges (fun index => denseMatrixEval matrix (vectors index)) := by
  funext row
  calc
    denseMatrixEval matrix (rlcWeightedVector challenges vectors) row
        = ∑ column : Fin columns,
            ∑ index : Fin count,
              matrix row column * (challenges index * vectors index column) := by
          simp [denseMatrixEval, rlcWeightedVector, rlcWeightedSum, Finset.mul_sum]
    _ = ∑ index : Fin count,
          ∑ column : Fin columns,
            matrix row column * (challenges index * vectors index column) := by
          rw [Finset.sum_comm]
    _ = ∑ index : Fin count,
          challenges index * ∑ column : Fin columns,
            matrix row column * vectors index column := by
          apply Finset.sum_congr rfl
          intro index _
          calc
            (∑ column : Fin columns,
              matrix row column * (challenges index * vectors index column))
                = ∑ column : Fin columns,
                    challenges index * (matrix row column * vectors index column) := by
                  apply Finset.sum_congr rfl
                  intro column _
                  ring
            _ = challenges index * ∑ column : Fin columns,
                  matrix row column * vectors index column := by
                  rw [Finset.mul_sum]
    _ = rlcWeightedVector challenges (fun index => denseMatrixEval matrix (vectors index)) row := by
          rfl

structure RelationMonomialFormal (RF : Type) (vars : Nat) where
  coefficient : RF
  exponent : Fin vars → Nat

abbrev RelationPolynomialFormal (RF : Type) (vars terms : Nat) :=
  Fin terms → RelationMonomialFormal RF vars

def relationMonomialTotalDegree {vars : Nat}
    (monomial : RelationMonomialFormal RF vars) : Nat :=
  ∑ varIndex : Fin vars, monomial.exponent varIndex

def relationPolynomialDegreeBound {vars terms : Nat}
    (polynomial : RelationPolynomialFormal RF vars terms)
    (bound : Nat) : Prop :=
  ∀ term, relationMonomialTotalDegree (polynomial term) ≤ bound

def relationMonomialEval {vars : Nat}
    (monomial : RelationMonomialFormal RF vars)
    (values : ProtocolVector RF vars) : RF :=
  monomial.coefficient *
    ∏ varIndex : Fin vars, values varIndex ^ monomial.exponent varIndex

def relationPolynomialEval {vars terms : Nat}
    (polynomial : RelationPolynomialFormal RF vars terms)
    (values : ProtocolVector RF vars) : RF :=
  ∑ term : Fin terms, relationMonomialEval (polynomial term) values

def hadamardRelationMonomial (vars : Nat) : RelationMonomialFormal RF vars where
  coefficient := 1
  exponent := fun _ => 1

def hadamardRelationPolynomial (vars : Nat) : RelationPolynomialFormal RF vars 1 :=
  fun _ => hadamardRelationMonomial vars

theorem relationMonomialTotalDegree_hadamard (vars : Nat) :
    relationMonomialTotalDegree (hadamardRelationMonomial (RF := RF) vars) = vars := by
  simp [relationMonomialTotalDegree, hadamardRelationMonomial]

theorem relationPolynomialDegreeBound_hadamard (vars : Nat) :
    relationPolynomialDegreeBound (hadamardRelationPolynomial (RF := RF) vars) vars := by
  intro term
  simp [hadamardRelationPolynomial, relationMonomialTotalDegree_hadamard]

theorem relationPolynomialEval_hadamard {vars : Nat}
    (values : ProtocolVector RF vars) :
    relationPolynomialEval (hadamardRelationPolynomial (RF := RF) vars) values =
      ∏ varIndex : Fin vars, values varIndex := by
  simp [relationPolynomialEval, hadamardRelationPolynomial, relationMonomialEval,
    hadamardRelationMonomial]

def ccsMatrixRowValues {rows columns matrixCount : Nat}
    (matrices : Fin matrixCount → CCSMatrix RF rows columns)
    (witness : ProtocolVector RF columns)
    (row : Fin rows) : ProtocolVector RF matrixCount :=
  fun matrixIndex => denseMatrixEval (matrices matrixIndex) witness row

def ccsRelationRowValue {rows columns matrixCount terms : Nat}
    (polynomial : RelationPolynomialFormal RF matrixCount terms)
    (matrices : Fin matrixCount → CCSMatrix RF rows columns)
    (witness : ProtocolVector RF columns)
    (row : Fin rows) : RF :=
  relationPolynomialEval polynomial (ccsMatrixRowValues matrices witness row)

def CCSSatisfied {rows columns matrixCount terms : Nat}
    (polynomial : RelationPolynomialFormal RF matrixCount terms)
    (matrices : Fin matrixCount → CCSMatrix RF rows columns)
    (witness : ProtocolVector RF columns) : Prop :=
  ∀ row, ccsRelationRowValue polynomial matrices witness row = 0

theorem ccsRelationRowValue_hadamard {rows columns matrixCount : Nat}
    (matrices : Fin matrixCount → CCSMatrix RF rows columns)
    (witness : ProtocolVector RF columns)
    (row : Fin rows) :
    ccsRelationRowValue
        (hadamardRelationPolynomial (RF := RF) matrixCount)
        matrices
        witness
        row =
      ∏ matrixIndex : Fin matrixCount,
        denseMatrixEval (matrices matrixIndex) witness row := by
  rw [ccsRelationRowValue, relationPolynomialEval_hadamard]
  rfl

theorem ccsSatisfied_hadamard_iff {rows columns matrixCount : Nat}
    (matrices : Fin matrixCount → CCSMatrix RF rows columns)
    (witness : ProtocolVector RF columns) :
    CCSSatisfied
        (hadamardRelationPolynomial (RF := RF) matrixCount)
        matrices
        witness ↔
      ∀ row,
        (∏ matrixIndex : Fin matrixCount,
          denseMatrixEval (matrices matrixIndex) witness row) = 0 := by
  constructor
  · intro h row
    rw [← ccsRelationRowValue_hadamard]
    exact h row
  · intro h row
    rw [ccsRelationRowValue_hadamard]
    exact h row

end SuperNeoFormal
