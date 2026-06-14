import Mathlib.Analysis.CStarAlgebra.Matrix
import Mathlib.Analysis.Normed.Operator.Basic
import Mathlib.Data.ZMod.Basic
import Mathlib.Tactic
import SuperNeoFormal.QuantumRandomOracle

/-!
DFMS/Zhandry online extraction theorem surface.

This module restricts the online-extraction theorem to the setting where it
applies: an ideal QROM for a finite hash-defined classical commitment
`t = f x (H x)`.  The analytic commutator theorem remains an explicit theorem
record, but its inputs and outputs are typed by the finite commitment function,
the compressed-oracle relation, and the DFMS `Γ`/`Γ'` tightness parameters.
-/

noncomputable section

namespace SuperNeoFormal

open Finset
open scoped Matrix.Norms.L2Operator

abbrev DFMSBitVector (n : Nat) :=
  Fin n → ZMod 2

theorem dfmsBitVector_card (n : Nat) :
    Fintype.card (DFMSBitVector n) = 2 ^ n := by
  rw [Fintype.card_fun]
  rw [ZMod.card 2, Fintype.card_fin]

def DFMSBitVector.zero (n : Nat) : DFMSBitVector n :=
  fun _ => 0

abbrev DFMSRegisterHilbertSpace (A : Type) [Fintype A] :=
  EuclideanSpace ℂ A

abbrev DFMSContinuousOperator (A : Type) [Fintype A] :=
  DFMSRegisterHilbertSpace A →L[ℂ] DFMSRegisterHilbertSpace A

noncomputable def DFMSOperatorNorm
    {A : Type} [Fintype A]
    (operator : DFMSContinuousOperator A) : ℝ :=
  ContinuousLinearMap.opNorm operator

noncomputable def DFMSOperatorCommutator
    {A : Type} [Fintype A]
    (left right : DFMSContinuousOperator A) :
    DFMSContinuousOperator A :=
  left.comp right - right.comp left

abbrev DFMSMatrixOperator (A : Type) :=
  Matrix A A ℂ

noncomputable def DFMSMatrixOperator.toContinuous
    {A : Type} [Fintype A] [DecidableEq A]
    (operator : DFMSMatrixOperator A) :
    DFMSContinuousOperator A :=
  (Matrix.toEuclideanCLM (n := A) (𝕜 := ℂ)) operator

abbrev DFMSTh31Database (n : Nat) (X : Type) :=
  X → Option (DFMSBitVector n)

abbrev DFMSTh31Basis (n : Nat) (X : Type) :=
  ((X × DFMSBitVector n) × DFMSTh31Database n X) × Option X

abbrev DFMSTh31CellBasis (n : Nat) :=
  Option (DFMSBitVector n)

abbrev DFMSTh31LocalQueryBasis (n : Nat) :=
  DFMSBitVector n × DFMSTh31CellBasis n

noncomputable def DFMSTh31HashCardinalityReal (n : Nat) : ℝ :=
  (2 : ℝ) ^ n

noncomputable def DFMSTh31InvSqrtHashCardinality (n : Nat) : ℂ :=
  ((Real.sqrt (DFMSTh31HashCardinalityReal n)) : ℂ)⁻¹

noncomputable def DFMSTh31InvHashCardinality (n : Nat) : ℂ :=
  ((DFMSTh31HashCardinalityReal n : ℝ) : ℂ)⁻¹

noncomputable def DFMSTh31CellFourierMatrix
    (n : Nat) :
    DFMSMatrixOperator (DFMSTh31CellBasis n) :=
  fun output input =>
    match output, input with
    | none, none => 0
    | some _, none => DFMSTh31InvSqrtHashCardinality n
    | none, some _ => DFMSTh31InvSqrtHashCardinality n
    | some outputY, some inputY =>
        if outputY = inputY then
          1 - DFMSTh31InvHashCardinality n
        else
          -DFMSTh31InvHashCardinality n

def DFMSTh31CellValue
    {n : Nat}
    (cell : DFMSTh31CellBasis n) : DFMSBitVector n :=
  match cell with
  | none => DFMSBitVector.zero n
  | some y => y

noncomputable def DFMSTh31CellMatchProjectorMatrix
    {n : Nat}
    {X : Type}
    (R : X → DFMSBitVector n → Prop)
    [DecidableRel R]
    (x : X) :
    DFMSMatrixOperator (DFMSTh31CellBasis n) :=
  fun output input =>
    if output = input then
      match input with
      | none => 0
      | some y => if R x y then 1 else 0
    else
      0

noncomputable def DFMSTh31CellNoMatchProjectorMatrix
    {n : Nat}
    {X : Type}
    (R : X → DFMSBitVector n → Prop)
    [DecidableRel R]
    (x : X) :
    DFMSMatrixOperator (DFMSTh31CellBasis n) :=
  fun output input =>
    if output = input then
      match input with
      | none => 1
      | some y => if R x y then 0 else 1
    else
      0

noncomputable def DFMSTh31LiftCellMatrix
    {n : Nat}
    (cellOperator : DFMSMatrixOperator (DFMSTh31CellBasis n)) :
    DFMSMatrixOperator (DFMSTh31LocalQueryBasis n) :=
  fun output input =>
    if output.1 = input.1 then cellOperator output.2 input.2 else 0

noncomputable def DFMSTh31LocalFourierMatrix
    (n : Nat) :
    DFMSMatrixOperator (DFMSTh31LocalQueryBasis n) :=
  DFMSTh31LiftCellMatrix (DFMSTh31CellFourierMatrix n)

noncomputable def DFMSTh31LocalMatchProjectorMatrix
    {n : Nat}
    {X : Type}
    (R : X → DFMSBitVector n → Prop)
    [DecidableRel R]
    (x : X) :
    DFMSMatrixOperator (DFMSTh31LocalQueryBasis n) :=
  DFMSTh31LiftCellMatrix (DFMSTh31CellMatchProjectorMatrix R x)

noncomputable def DFMSTh31LocalNoMatchProjectorMatrix
    {n : Nat}
    {X : Type}
    (R : X → DFMSBitVector n → Prop)
    [DecidableRel R]
    (x : X) :
    DFMSMatrixOperator (DFMSTh31LocalQueryBasis n) :=
  DFMSTh31LiftCellMatrix (DFMSTh31CellNoMatchProjectorMatrix R x)

noncomputable def DFMSTh31LocalEvaluationMatrix
    (n : Nat) :
    DFMSMatrixOperator (DFMSTh31LocalQueryBasis n) :=
  fun output input =>
    if output = (input.1 + DFMSTh31CellValue input.2, input.2) then 1 else 0

noncomputable def DFMSTh31LocalOracleMatrix
    (n : Nat) :
    DFMSMatrixOperator (DFMSTh31LocalQueryBasis n) :=
  DFMSTh31LocalFourierMatrix n *
    DFMSTh31LocalEvaluationMatrix n *
    DFMSTh31LocalFourierMatrix n

noncomputable def DFMSTh31CellFourierOperator
    (n : Nat) :
    DFMSContinuousOperator (DFMSTh31CellBasis n) :=
  (DFMSTh31CellFourierMatrix n).toContinuous

noncomputable def DFMSTh31LocalFourierOperator
    (n : Nat) :
    DFMSContinuousOperator (DFMSTh31LocalQueryBasis n) :=
  (DFMSTh31LocalFourierMatrix n).toContinuous

noncomputable def DFMSTh31LocalEvaluationOperator
    (n : Nat) :
    DFMSContinuousOperator (DFMSTh31LocalQueryBasis n) :=
  (DFMSTh31LocalEvaluationMatrix n).toContinuous

noncomputable def DFMSTh31LocalOracleOperator
    (n : Nat) :
    DFMSContinuousOperator (DFMSTh31LocalQueryBasis n) :=
  (DFMSTh31LocalOracleMatrix n).toContinuous

noncomputable def DFMSTh31LocalMatchProjectorOperator
    {n : Nat}
    {X : Type}
    (R : X → DFMSBitVector n → Prop)
    [DecidableRel R]
    (x : X) :
    DFMSContinuousOperator (DFMSTh31LocalQueryBasis n) :=
  (DFMSTh31LocalMatchProjectorMatrix R x).toContinuous

noncomputable def DFMSTh31LocalNoMatchProjectorOperator
    {n : Nat}
    {X : Type}
    (R : X → DFMSBitVector n → Prop)
    [DecidableRel R]
    (x : X) :
    DFMSContinuousOperator (DFMSTh31LocalQueryBasis n) :=
  (DFMSTh31LocalNoMatchProjectorMatrix R x).toContinuous

theorem DFMSTh31LocalOracleMatrix_eq_FEF
    (n : Nat) :
    DFMSTh31LocalOracleMatrix n =
      DFMSTh31LocalFourierMatrix n *
        DFMSTh31LocalEvaluationMatrix n *
        DFMSTh31LocalFourierMatrix n :=
  rfl

theorem DFMSTh31LocalOracleOperator_eq_FEF
    (n : Nat) :
    DFMSTh31LocalOracleOperator n =
      (DFMSTh31LocalFourierOperator n).comp
        ((DFMSTh31LocalEvaluationOperator n).comp
          (DFMSTh31LocalFourierOperator n)) := by
  ext vector
  simp [DFMSTh31LocalOracleOperator, DFMSTh31LocalFourierOperator,
    DFMSTh31LocalEvaluationOperator, DFMSMatrixOperator.toContinuous,
    DFMSTh31LocalOracleMatrix, mul_assoc]

def DFMSTh31DatabaseAgreesExcept
    {n : Nat}
    {X : Type}
    (x : X)
    (left right : DFMSTh31Database n X) : Prop :=
  ∀ z : X, z ≠ x → left z = right z

noncomputable def DFMSTh31GlobalOracleMatrix
    (n : Nat)
    (X : Type) [Fintype X] [DecidableEq X] :
    DFMSMatrixOperator (DFMSTh31Basis n X) :=
  by
    classical
    exact
      fun output input =>
        let queriedAddress := input.1.1.1
        if output.1.1.1 = queriedAddress
            ∧ output.2 = input.2
            ∧ DFMSTh31DatabaseAgreesExcept
              queriedAddress output.1.2 input.1.2 then
          DFMSTh31LocalOracleMatrix n
            (output.1.1.2, output.1.2 queriedAddress)
            (input.1.1.2, input.1.2 queriedAddress)
        else
          0

theorem DFMSTh31GlobalOracleMatrix_eq_zero_of_query_address_ne
    (n : Nat)
    {X : Type} [Fintype X] [DecidableEq X]
    {output input : DFMSTh31Basis n X}
    (hAddress : output.1.1.1 ≠ input.1.1.1) :
    DFMSTh31GlobalOracleMatrix n X output input = 0 := by
  classical
  simp [DFMSTh31GlobalOracleMatrix, hAddress]

theorem DFMSTh31GlobalOracleMatrix_eq_zero_of_purifier_ne
    (n : Nat)
    {X : Type} [Fintype X] [DecidableEq X]
    {output input : DFMSTh31Basis n X}
    (hPurifier : output.2 ≠ input.2) :
    DFMSTh31GlobalOracleMatrix n X output input = 0 := by
  classical
  simp [DFMSTh31GlobalOracleMatrix, hPurifier]

noncomputable def DFMSTh31GlobalOracleOperator
    (n : Nat)
    (X : Type) [Fintype X] [DecidableEq X] :
    DFMSContinuousOperator (DFMSTh31Basis n X) :=
  (DFMSTh31GlobalOracleMatrix n X).toContinuous

def DFMSTh31DatabaseCellMatches
    {n : Nat}
    {X : Type}
    (R : X → DFMSBitVector n → Prop)
    (database : DFMSTh31Database n X)
    (x : X) : Prop :=
  ∃ y : DFMSBitVector n, database x = some y ∧ R x y

def DFMSTh31FirstMatchingAddress
    {n : Nat}
    {X : Type} [LT X]
    (R : X → DFMSBitVector n → Prop)
    (database : DFMSTh31Database n X)
    (x : X) : Prop :=
  DFMSTh31DatabaseCellMatches R database x
    ∧ ∀ x' : X,
      x' < x → ¬ DFMSTh31DatabaseCellMatches R database x'

def DFMSTh31NoMatchingAddress
    {n : Nat}
    {X : Type}
    (R : X → DFMSBitVector n → Prop)
    (database : DFMSTh31Database n X) : Prop :=
  ∀ x : X, ¬ DFMSTh31DatabaseCellMatches R database x

theorem DFMSTh31FirstMatchingAddress.matches
    {n : Nat}
    {X : Type} [LT X]
    {R : X → DFMSBitVector n → Prop}
    {database : DFMSTh31Database n X}
    {x : X}
    (hFirst : DFMSTh31FirstMatchingAddress R database x) :
    DFMSTh31DatabaseCellMatches R database x :=
  hFirst.1

theorem DFMSTh31FirstMatchingAddress.unique
    {n : Nat}
    {X : Type} [LinearOrder X]
    {R : X → DFMSBitVector n → Prop}
    {database : DFMSTh31Database n X}
    {x x' : X}
    (hFirst : DFMSTh31FirstMatchingAddress R database x)
    (hFirst' : DFMSTh31FirstMatchingAddress R database x') :
    x = x' := by
  by_contra hDistinct
  rcases lt_or_gt_of_ne hDistinct with hlt | hgt
  · exact (hFirst'.2 x hlt) hFirst.1
  · exact (hFirst.2 x' hgt) hFirst'.1

noncomputable def DFMSTh31FirstMatchOutcome
    {n : Nat}
    {X : Type} [LinearOrder X]
    (R : X → DFMSBitVector n → Prop)
    (database : DFMSTh31Database n X) : Option X :=
  by
    classical
    exact
      if h : ∃ x : X, DFMSTh31FirstMatchingAddress R database x then
        some (Classical.choose h)
      else
        none

noncomputable def DFMSTh31FirstMatchProjectorMatrix
    {n : Nat}
    {X : Type} [Fintype X] [DecidableEq X] [LinearOrder X]
    (R : X → DFMSBitVector n → Prop)
    (outcome : Option X) :
    DFMSMatrixOperator (DFMSTh31Basis n X) :=
  fun output input =>
    if output = input ∧
        DFMSTh31FirstMatchOutcome R input.1.2 = outcome then
      1
    else
      0

noncomputable def DFMSTh31NoMatchProjectorMatrix
    {n : Nat}
    {X : Type} [Fintype X] [DecidableEq X] [LinearOrder X]
    (R : X → DFMSBitVector n → Prop) :
    DFMSMatrixOperator (DFMSTh31Basis n X) :=
  DFMSTh31FirstMatchProjectorMatrix R none

abbrev DFMSTh31PurifierShift (X : Type) :=
  Option X → Option X ≃ Option X

noncomputable def DFMSTh31PurifiedMeasurementMatrix
    {n : Nat}
    {X : Type} [Fintype X] [DecidableEq X] [LinearOrder X]
    (R : X → DFMSBitVector n → Prop)
    (shift : DFMSTh31PurifierShift X) :
    DFMSMatrixOperator (DFMSTh31Basis n X) :=
  fun output input =>
    let outcome := DFMSTh31FirstMatchOutcome R input.1.2
    if output.1 = input.1 ∧ output.2 = shift outcome input.2 then
      1
    else
      0

noncomputable def DFMSTh31FirstMatchProjectorOperator
    {n : Nat}
    {X : Type} [Fintype X] [DecidableEq X] [LinearOrder X]
    (R : X → DFMSBitVector n → Prop)
    (outcome : Option X) :
    DFMSContinuousOperator (DFMSTh31Basis n X) :=
  (DFMSTh31FirstMatchProjectorMatrix R outcome).toContinuous

noncomputable def DFMSTh31NoMatchProjectorOperator
    {n : Nat}
    {X : Type} [Fintype X] [DecidableEq X] [LinearOrder X]
    (R : X → DFMSBitVector n → Prop) :
    DFMSContinuousOperator (DFMSTh31Basis n X) :=
  (DFMSTh31NoMatchProjectorMatrix R).toContinuous

noncomputable def DFMSTh31PurifiedMeasurementOperator
    {n : Nat}
    {X : Type} [Fintype X] [DecidableEq X] [LinearOrder X]
    (R : X → DFMSBitVector n → Prop)
    (shift : DFMSTh31PurifierShift X) :
    DFMSContinuousOperator (DFMSTh31Basis n X) :=
  (DFMSTh31PurifiedMeasurementMatrix R shift).toContinuous

def DFMSTh31GammaX
    {n : Nat}
    {X : Type} [Fintype X] [DecidableEq X]
    (R : X → DFMSBitVector n → Prop)
    [DecidableRel R]
    (x : X) : Nat :=
  ((Finset.univ : Finset (DFMSBitVector n)).filter
    (fun y => R x y)).card

def DFMSTh31GammaR
    {n : Nat}
    {X : Type} [Fintype X] [DecidableEq X]
    (R : X → DFMSBitVector n → Prop)
    [DecidableRel R] : Nat :=
  (Finset.univ : Finset X).sup fun x => DFMSTh31GammaX R x

theorem dfmsTh31_gammaX_le_gammaR
    {n : Nat}
    {X : Type} [Fintype X] [DecidableEq X]
    (R : X → DFMSBitVector n → Prop)
    [DecidableRel R]
    (x : X) :
    DFMSTh31GammaX R x ≤ DFMSTh31GammaR R :=
  Finset.le_sup (Finset.mem_univ x)

def DFMSTh31CommutatorBound
    {n : Nat}
    {X : Type} [Fintype X] [DecidableEq X]
    (R : X → DFMSBitVector n → Prop)
    [DecidableRel R]
    (oracleQuery purifiedMeasurement :
      DFMSContinuousOperator (DFMSTh31Basis n X)) : Prop :=
  DFMSOperatorNorm
      (DFMSOperatorCommutator oracleQuery purifiedMeasurement)
    ≤ 8 *
      Real.sqrt
        (((2 : ℝ) * (DFMSTh31GammaR R : ℝ)) / ((2 : ℝ) ^ n))

def DFMSTh31LocalSqrtTerm (n gammaX : Nat) : ℝ :=
  Real.sqrt (((2 : ℝ) * (gammaX : ℝ)) / ((2 : ℝ) ^ n))

def DFMSTh31ExactFourierProjectorTerm
    (n gammaX : Nat) : ℝ :=
  Real.sqrt
    ((((2 : ℝ) * (gammaX : ℝ)) / ((2 : ℝ) ^ n)) -
      (((gammaX : ℝ) ^ 2) / (((2 : ℝ) ^ n) ^ 2)))

def DFMSTh31FourierProjectorExactNorm
    (n gammaX : Nat)
    (fourier matchProjector :
      DFMSContinuousOperator (DFMSTh31LocalQueryBasis n)) : Prop :=
  DFMSOperatorNorm
      (DFMSOperatorCommutator fourier matchProjector)
    = DFMSTh31ExactFourierProjectorTerm n gammaX

def DFMSTh31FourierProjectorBound
    (n gammaX : Nat)
    (fourier matchProjector :
      DFMSContinuousOperator (DFMSTh31LocalQueryBasis n)) : Prop :=
  DFMSOperatorNorm
      (DFMSOperatorCommutator fourier matchProjector)
    ≤ DFMSTh31LocalSqrtTerm n gammaX

def DFMSTh31LocalOracleProjectorFactorTwo
    (n : Nat)
    (fourier localOracle matchProjector :
      DFMSContinuousOperator (DFMSTh31LocalQueryBasis n)) : Prop :=
  DFMSOperatorNorm
      (DFMSOperatorCommutator localOracle matchProjector)
    ≤ 2 *
      DFMSOperatorNorm
        (DFMSOperatorCommutator fourier matchProjector)

def DFMSTh31LocalOracleProjectorBound
    (n gammaX : Nat)
    (localOracle matchProjector :
      DFMSContinuousOperator (DFMSTh31LocalQueryBasis n)) : Prop :=
  DFMSOperatorNorm
      (DFMSOperatorCommutator localOracle matchProjector)
    ≤ 2 * DFMSTh31LocalSqrtTerm n gammaX

def DFMSTh31NoMatchProjectorBound
    (n gammaX : Nat)
    (localOracle noMatchProjector :
      DFMSContinuousOperator (DFMSTh31LocalQueryBasis n)) : Prop :=
  DFMSOperatorNorm
      (DFMSOperatorCommutator localOracle noMatchProjector)
    ≤ 2 * DFMSTh31LocalSqrtTerm n gammaX

def DFMSTh31PurifiedMeasurementReduction
    (n : Nat)
    (localOracle localMeasurement matchProjector noMatchProjector :
      DFMSContinuousOperator (DFMSTh31LocalQueryBasis n)) : Prop :=
  DFMSOperatorNorm
      (DFMSOperatorCommutator localOracle localMeasurement)
    ≤ 3 *
        DFMSOperatorNorm
          (DFMSOperatorCommutator localOracle matchProjector)
      + DFMSOperatorNorm
          (DFMSOperatorCommutator localOracle noMatchProjector)

def DFMSTh31LocalPurifiedMeasurementBound
    (n gammaX : Nat)
    (localOracle localMeasurement :
      DFMSContinuousOperator (DFMSTh31LocalQueryBasis n)) : Prop :=
  DFMSOperatorNorm
      (DFMSOperatorCommutator localOracle localMeasurement)
    ≤ 8 * DFMSTh31LocalSqrtTerm n gammaX

theorem dfmsTh31_exactFourierProjectorTerm_le_localSqrtTerm
    (n gammaX : Nat) :
    DFMSTh31ExactFourierProjectorTerm n gammaX ≤
      DFMSTh31LocalSqrtTerm n gammaX := by
  unfold DFMSTh31ExactFourierProjectorTerm DFMSTh31LocalSqrtTerm
  apply Real.sqrt_le_sqrt
  have hNonneg :
      0 ≤
        ((gammaX : ℝ) ^ 2) / (((2 : ℝ) ^ n) ^ 2) :=
    div_nonneg (sq_nonneg _) (sq_nonneg _)
  linarith

theorem DFMSTh31FourierProjectorBound.of_exactNorm
    (n gammaX : Nat)
    (fourier matchProjector :
      DFMSContinuousOperator (DFMSTh31LocalQueryBasis n))
    (hExact :
      DFMSTh31FourierProjectorExactNorm
        n gammaX fourier matchProjector) :
    DFMSTh31FourierProjectorBound
      n gammaX fourier matchProjector := by
  unfold DFMSTh31FourierProjectorExactNorm at hExact
  unfold DFMSTh31FourierProjectorBound
  rw [hExact]
  exact dfmsTh31_exactFourierProjectorTerm_le_localSqrtTerm n gammaX

theorem DFMSTh31LocalOracleProjectorBound.of_factorTwo
    (n gammaX : Nat)
    (fourier localOracle matchProjector :
      DFMSContinuousOperator (DFMSTh31LocalQueryBasis n))
    (hFactorTwo :
      DFMSTh31LocalOracleProjectorFactorTwo
        n fourier localOracle matchProjector)
    (hFourier :
      DFMSTh31FourierProjectorBound
        n gammaX fourier matchProjector) :
    DFMSTh31LocalOracleProjectorBound
      n gammaX localOracle matchProjector := by
  unfold DFMSTh31LocalOracleProjectorFactorTwo at hFactorTwo
  unfold DFMSTh31FourierProjectorBound at hFourier
  unfold DFMSTh31LocalOracleProjectorBound
  linarith

def DFMSTh31NoMatchProjectorReduction
    (n : Nat)
    (localOracle matchProjector noMatchProjector :
      DFMSContinuousOperator (DFMSTh31LocalQueryBasis n)) : Prop :=
  DFMSOperatorNorm
      (DFMSOperatorCommutator localOracle noMatchProjector)
    ≤ DFMSOperatorNorm
        (DFMSOperatorCommutator localOracle matchProjector)

theorem DFMSTh31NoMatchProjectorBound.of_reduction
    (n gammaX : Nat)
    (localOracle matchProjector noMatchProjector :
      DFMSContinuousOperator (DFMSTh31LocalQueryBasis n))
    (hReduction :
      DFMSTh31NoMatchProjectorReduction
        n localOracle matchProjector noMatchProjector)
    (hMatchBound :
      DFMSTh31LocalOracleProjectorBound
        n gammaX localOracle matchProjector) :
    DFMSTh31NoMatchProjectorBound
      n gammaX localOracle noMatchProjector := by
  unfold DFMSTh31NoMatchProjectorReduction at hReduction
  unfold DFMSTh31LocalOracleProjectorBound at hMatchBound
  unfold DFMSTh31NoMatchProjectorBound
  linarith

theorem DFMSTh31LocalPurifiedMeasurementBound.of_reduction
    (n gammaX : Nat)
    (localOracle localMeasurement matchProjector noMatchProjector :
      DFMSContinuousOperator (DFMSTh31LocalQueryBasis n))
    (hReduction :
      DFMSTh31PurifiedMeasurementReduction
        n localOracle localMeasurement matchProjector noMatchProjector)
    (hMatchBound :
      DFMSTh31LocalOracleProjectorBound
        n gammaX localOracle matchProjector)
    (hNoMatchBound :
      DFMSTh31NoMatchProjectorBound
        n gammaX localOracle noMatchProjector) :
    DFMSTh31LocalPurifiedMeasurementBound
      n gammaX localOracle localMeasurement := by
  unfold DFMSTh31PurifiedMeasurementReduction at hReduction
  unfold DFMSTh31LocalOracleProjectorBound at hMatchBound
  unfold DFMSTh31NoMatchProjectorBound at hNoMatchBound
  unfold DFMSTh31LocalPurifiedMeasurementBound
  linarith

structure DFMSTh31OperatorModel
    (n : Nat)
    (X : Type) [Fintype X] [DecidableEq X] where
  oracleQuery : DFMSContinuousOperator (DFMSTh31Basis n X)
  purifiedMeasurement : DFMSContinuousOperator (DFMSTh31Basis n X)
  oracleQueryImplementsCompressedOracle : Prop
  oracleQueryImplementsCompressedOracleHolds :
    oracleQueryImplementsCompressedOracle
  purifiedMeasurementImplementsFirstMatchProjectors : Prop
  purifiedMeasurementImplementsFirstMatchProjectorsHolds :
    purifiedMeasurementImplementsFirstMatchProjectors

def DFMSTh31GlobalBlockDiagonalReduction
    {n : Nat}
    {X : Type} [Fintype X] [DecidableEq X]
    (R : X → DFMSBitVector n → Prop) [DecidableRel R]
    (operatorModel : DFMSTh31OperatorModel n X)
    (localOracle localPurifiedMeasurement :
      X → DFMSContinuousOperator (DFMSTh31LocalQueryBasis n)) : Prop :=
  (∀ x,
      DFMSTh31LocalPurifiedMeasurementBound
        n
        (DFMSTh31GammaX R x)
        (localOracle x)
        (localPurifiedMeasurement x)) →
    DFMSTh31CommutatorBound
      R
      operatorModel.oracleQuery
      operatorModel.purifiedMeasurement

structure DFMSTh31AnalyticProof
    (n : Nat)
    (X : Type) [Fintype X] [DecidableEq X]
    (R : X → DFMSBitVector n → Prop) [DecidableRel R]
    (operatorModel : DFMSTh31OperatorModel n X) where
  localFourier : X →
    DFMSContinuousOperator (DFMSTh31LocalQueryBasis n)
  localEvaluation : X →
    DFMSContinuousOperator (DFMSTh31LocalQueryBasis n)
  localOracle : X →
    DFMSContinuousOperator (DFMSTh31LocalQueryBasis n)
  localMatchProjector : X →
    DFMSContinuousOperator (DFMSTh31LocalQueryBasis n)
  localNoMatchProjector : X →
    DFMSContinuousOperator (DFMSTh31LocalQueryBasis n)
  localPurifiedMeasurement : X →
    DFMSContinuousOperator (DFMSTh31LocalQueryBasis n)
  localOracleFactorization :
    ∀ x,
      localOracle x =
        (localFourier x).comp
          ((localEvaluation x).comp (localFourier x))
  evaluationCommutesWithMatchProjector :
    ∀ x,
      DFMSOperatorCommutator
          (localEvaluation x)
          (localMatchProjector x) = 0
  fourierProjectorExactNorm :
    ∀ x,
      DFMSTh31FourierProjectorExactNorm
        n
        (DFMSTh31GammaX R x)
        (localFourier x)
        (localMatchProjector x)
  localOracleProjectorFactorTwo :
    ∀ x,
      DFMSTh31LocalOracleProjectorFactorTwo
        n
        (localFourier x)
        (localOracle x)
        (localMatchProjector x)
  noMatchProjectorReduction :
    ∀ x,
      DFMSTh31NoMatchProjectorReduction
        n
        (localOracle x)
        (localMatchProjector x)
        (localNoMatchProjector x)
  purifiedMeasurementReduction :
    ∀ x,
      DFMSTh31PurifiedMeasurementReduction
        n
        (localOracle x)
        (localPurifiedMeasurement x)
        (localMatchProjector x)
        (localNoMatchProjector x)
  globalBlockDiagonalReduction :
    DFMSTh31GlobalBlockDiagonalReduction
      R
      operatorModel
      localOracle
      localPurifiedMeasurement

def DFMSTh31OperatorModelAccepted
    {n : Nat}
    {X : Type} [Fintype X] [DecidableEq X]
    (model : DFMSTh31OperatorModel n X) : Prop :=
  model.oracleQueryImplementsCompressedOracle
    ∧ model.purifiedMeasurementImplementsFirstMatchProjectors

theorem DFMSTh31OperatorModel.accepted
    {n : Nat}
    {X : Type} [Fintype X] [DecidableEq X]
    (model : DFMSTh31OperatorModel n X) :
    DFMSTh31OperatorModelAccepted model :=
  ⟨model.oracleQueryImplementsCompressedOracleHolds,
    model.purifiedMeasurementImplementsFirstMatchProjectorsHolds⟩

def DFMSTh31AnalyticProofAccepted
    {n : Nat}
    {X : Type} [Fintype X] [DecidableEq X]
    {R : X → DFMSBitVector n → Prop} [DecidableRel R]
    {operatorModel : DFMSTh31OperatorModel n X}
    (analytic : DFMSTh31AnalyticProof n X R operatorModel) : Prop :=
  (∀ x,
      analytic.localOracle x =
        (analytic.localFourier x).comp
          ((analytic.localEvaluation x).comp
            (analytic.localFourier x)))
    ∧ (∀ x,
      DFMSOperatorCommutator
          (analytic.localEvaluation x)
          (analytic.localMatchProjector x) = 0)
    ∧ (∀ x,
      DFMSTh31FourierProjectorExactNorm
        n
        (DFMSTh31GammaX R x)
        (analytic.localFourier x)
        (analytic.localMatchProjector x))
    ∧ (∀ x,
      DFMSTh31FourierProjectorBound
        n
        (DFMSTh31GammaX R x)
        (analytic.localFourier x)
        (analytic.localMatchProjector x))
    ∧ (∀ x,
      DFMSTh31LocalOracleProjectorFactorTwo
        n
        (analytic.localFourier x)
        (analytic.localOracle x)
        (analytic.localMatchProjector x))
    ∧ (∀ x,
      DFMSTh31LocalOracleProjectorBound
        n
        (DFMSTh31GammaX R x)
        (analytic.localOracle x)
        (analytic.localMatchProjector x))
    ∧ (∀ x,
      DFMSTh31NoMatchProjectorReduction
        n
        (analytic.localOracle x)
        (analytic.localMatchProjector x)
        (analytic.localNoMatchProjector x))
    ∧ (∀ x,
      DFMSTh31NoMatchProjectorBound
        n
        (DFMSTh31GammaX R x)
        (analytic.localOracle x)
        (analytic.localNoMatchProjector x))
    ∧ (∀ x,
      DFMSTh31PurifiedMeasurementReduction
        n
        (analytic.localOracle x)
        (analytic.localPurifiedMeasurement x)
        (analytic.localMatchProjector x)
        (analytic.localNoMatchProjector x))
    ∧ (∀ x,
      DFMSTh31LocalPurifiedMeasurementBound
        n
        (DFMSTh31GammaX R x)
        (analytic.localOracle x)
        (analytic.localPurifiedMeasurement x))
    ∧ DFMSTh31GlobalBlockDiagonalReduction
      R
      operatorModel
      analytic.localOracle
      analytic.localPurifiedMeasurement
    ∧ DFMSTh31CommutatorBound
      R
      operatorModel.oracleQuery
      operatorModel.purifiedMeasurement

theorem DFMSTh31AnalyticProof.fourierProjectorBound
    {n : Nat}
    {X : Type} [Fintype X] [DecidableEq X]
    {R : X → DFMSBitVector n → Prop} [DecidableRel R]
    {operatorModel : DFMSTh31OperatorModel n X}
    (analytic : DFMSTh31AnalyticProof n X R operatorModel)
    (x : X) :
    DFMSTh31FourierProjectorBound
      n
      (DFMSTh31GammaX R x)
      (analytic.localFourier x)
      (analytic.localMatchProjector x) :=
  DFMSTh31FourierProjectorBound.of_exactNorm
    n
    (DFMSTh31GammaX R x)
    (analytic.localFourier x)
    (analytic.localMatchProjector x)
    (analytic.fourierProjectorExactNorm x)

theorem DFMSTh31AnalyticProof.localOracleProjectorBound
    {n : Nat}
    {X : Type} [Fintype X] [DecidableEq X]
    {R : X → DFMSBitVector n → Prop} [DecidableRel R]
    {operatorModel : DFMSTh31OperatorModel n X}
    (analytic : DFMSTh31AnalyticProof n X R operatorModel)
    (x : X) :
    DFMSTh31LocalOracleProjectorBound
      n
      (DFMSTh31GammaX R x)
      (analytic.localOracle x)
      (analytic.localMatchProjector x) :=
  DFMSTh31LocalOracleProjectorBound.of_factorTwo
    n
    (DFMSTh31GammaX R x)
    (analytic.localFourier x)
    (analytic.localOracle x)
    (analytic.localMatchProjector x)
    (analytic.localOracleProjectorFactorTwo x)
    (analytic.fourierProjectorBound x)

theorem DFMSTh31AnalyticProof.noMatchProjectorBound
    {n : Nat}
    {X : Type} [Fintype X] [DecidableEq X]
    {R : X → DFMSBitVector n → Prop} [DecidableRel R]
    {operatorModel : DFMSTh31OperatorModel n X}
    (analytic : DFMSTh31AnalyticProof n X R operatorModel)
    (x : X) :
    DFMSTh31NoMatchProjectorBound
      n
      (DFMSTh31GammaX R x)
      (analytic.localOracle x)
      (analytic.localNoMatchProjector x) :=
  DFMSTh31NoMatchProjectorBound.of_reduction
    n
    (DFMSTh31GammaX R x)
    (analytic.localOracle x)
    (analytic.localMatchProjector x)
    (analytic.localNoMatchProjector x)
    (analytic.noMatchProjectorReduction x)
    (analytic.localOracleProjectorBound x)

theorem DFMSTh31AnalyticProof.localPurifiedMeasurementBound
    {n : Nat}
    {X : Type} [Fintype X] [DecidableEq X]
    {R : X → DFMSBitVector n → Prop} [DecidableRel R]
    {operatorModel : DFMSTh31OperatorModel n X}
    (analytic : DFMSTh31AnalyticProof n X R operatorModel)
    (x : X) :
    DFMSTh31LocalPurifiedMeasurementBound
      n
      (DFMSTh31GammaX R x)
      (analytic.localOracle x)
      (analytic.localPurifiedMeasurement x) :=
  DFMSTh31LocalPurifiedMeasurementBound.of_reduction
    n
    (DFMSTh31GammaX R x)
    (analytic.localOracle x)
    (analytic.localPurifiedMeasurement x)
    (analytic.localMatchProjector x)
    (analytic.localNoMatchProjector x)
    (analytic.purifiedMeasurementReduction x)
    (analytic.localOracleProjectorBound x)
    (analytic.noMatchProjectorBound x)

theorem DFMSTh31AnalyticProof.globalCommutatorBound
    {n : Nat}
    {X : Type} [Fintype X] [DecidableEq X]
    {R : X → DFMSBitVector n → Prop} [DecidableRel R]
    {operatorModel : DFMSTh31OperatorModel n X}
    (analytic : DFMSTh31AnalyticProof n X R operatorModel) :
    DFMSTh31CommutatorBound
      R
      operatorModel.oracleQuery
      operatorModel.purifiedMeasurement :=
  analytic.globalBlockDiagonalReduction
    (fun x => analytic.localPurifiedMeasurementBound x)

theorem DFMSTh31AnalyticProof.accepted
    {n : Nat}
    {X : Type} [Fintype X] [DecidableEq X]
    {R : X → DFMSBitVector n → Prop} [DecidableRel R]
    {operatorModel : DFMSTh31OperatorModel n X}
    (analytic : DFMSTh31AnalyticProof n X R operatorModel) :
    DFMSTh31AnalyticProofAccepted analytic :=
  ⟨analytic.localOracleFactorization,
    analytic.evaluationCommutesWithMatchProjector,
    analytic.fourierProjectorExactNorm,
    analytic.fourierProjectorBound,
    analytic.localOracleProjectorFactorTwo,
    analytic.localOracleProjectorBound,
    analytic.noMatchProjectorReduction,
    analytic.noMatchProjectorBound,
    analytic.purifiedMeasurementReduction,
    analytic.localPurifiedMeasurementBound,
    analytic.globalBlockDiagonalReduction,
    analytic.globalCommutatorBound⟩

structure DFMSTh31CommutatorTheorem
    (n : Nat)
    (X : Type) [Fintype X] [DecidableEq X] [LinearOrder X] where
  R : X → DFMSBitVector n → Prop
  [rDecidable : DecidableRel R]
  operatorModel : DFMSTh31OperatorModel n X
  analyticProof : DFMSTh31AnalyticProof n X R operatorModel

attribute [instance] DFMSTh31CommutatorTheorem.rDecidable

def DFMSTh31CommutatorTheoremAccepted
    {n : Nat}
    {X : Type} [Fintype X] [DecidableEq X] [LinearOrder X]
    (theoremRecord : DFMSTh31CommutatorTheorem n X) : Prop :=
  DFMSTh31OperatorModelAccepted theoremRecord.operatorModel
    ∧ DFMSTh31AnalyticProofAccepted theoremRecord.analyticProof
    ∧ DFMSTh31CommutatorBound
      theoremRecord.R
      theoremRecord.operatorModel.oracleQuery
      theoremRecord.operatorModel.purifiedMeasurement

theorem DFMSTh31CommutatorTheorem.accepted
    {n : Nat}
    {X : Type} [Fintype X] [DecidableEq X] [LinearOrder X]
    (theoremRecord : DFMSTh31CommutatorTheorem n X) :
    DFMSTh31CommutatorTheoremAccepted theoremRecord :=
  ⟨theoremRecord.operatorModel.accepted,
    theoremRecord.analyticProof.accepted,
    theoremRecord.analyticProof.globalCommutatorBound⟩

structure DFMSTh31ExactEvidence where
  n : Nat
  X : Type
  [xFintype : Fintype X]
  [xDecidableEq : DecidableEq X]
  [xLinearOrder : LinearOrder X]
  theorem31 : DFMSTh31CommutatorTheorem n X

attribute [instance]
  DFMSTh31ExactEvidence.xFintype
  DFMSTh31ExactEvidence.xDecidableEq
  DFMSTh31ExactEvidence.xLinearOrder

def DFMSTh31ExactEvidenceAccepted
    (evidence : DFMSTh31ExactEvidence) : Prop :=
  DFMSTh31CommutatorTheoremAccepted evidence.theorem31

theorem DFMSTh31ExactEvidence.accepted
    (evidence : DFMSTh31ExactEvidence) :
    DFMSTh31ExactEvidenceAccepted evidence :=
  evidence.theorem31.accepted

structure DFMSHashCommitmentFunction where
  X : Type
  Y : Type
  T : Type
  [xFintype : Fintype X]
  [xDecidableEq : DecidableEq X]
  [xLinearOrder : LinearOrder X]
  [yFintype : Fintype Y]
  [yDecidableEq : DecidableEq Y]
  [yAddCommGroup : AddCommGroup Y]
  [tFintype : Fintype T]
  [tDecidableEq : DecidableEq T]
  hashOutputBits : Nat
  hashOutputCardinality : Fintype.card Y = 2 ^ hashOutputBits
  f : X → Y → T

attribute [instance]
  DFMSHashCommitmentFunction.xFintype
  DFMSHashCommitmentFunction.xDecidableEq
  DFMSHashCommitmentFunction.xLinearOrder
  DFMSHashCommitmentFunction.yFintype
  DFMSHashCommitmentFunction.yDecidableEq
  DFMSHashCommitmentFunction.yAddCommGroup
  DFMSHashCommitmentFunction.tFintype
  DFMSHashCommitmentFunction.tDecidableEq

def DFMSCommitmentFiber
    (commitment : DFMSHashCommitmentFunction)
    (x : commitment.X)
    (t : commitment.T) : Finset commitment.Y :=
  (Finset.univ : Finset commitment.Y).filter
    (fun y => commitment.f x y = t)

def DFMSCrossCommitmentFiber
    (commitment : DFMSHashCommitmentFunction)
    (x x' : commitment.X)
    (y' : commitment.Y) : Finset commitment.Y :=
  (Finset.univ : Finset commitment.Y).filter
    (fun y => commitment.f x y = commitment.f x' y')

def DFMSGammaBound
    (commitment : DFMSHashCommitmentFunction)
    (gamma : Nat) : Prop :=
  ∀ (x : commitment.X) (t : commitment.T),
    (DFMSCommitmentFiber commitment x t).card ≤ gamma

def DFMSGammaPrimeBound
    (commitment : DFMSHashCommitmentFunction)
    (gammaPrime : Nat) : Prop :=
  ∀ (x x' : commitment.X) (y' : commitment.Y),
    x ≠ x' →
      (DFMSCrossCommitmentFiber commitment x x' y').card ≤ gammaPrime

def DFMSRelationForOutput
    (commitment : DFMSHashCommitmentFunction)
    (t : commitment.T)
    (x : commitment.X)
    (y : commitment.Y) : Prop :=
  commitment.f x y = t

theorem dfms_relation_gamma_bound
    {commitment : DFMSHashCommitmentFunction}
    {gamma : Nat}
    (hGamma : DFMSGammaBound commitment gamma) :
    ∀ (t : commitment.T) (x : commitment.X),
      (DFMSCommitmentFiber commitment x t).card ≤ gamma := by
  intro t x
  exact hGamma x t

abbrev DFMSCompressedDatabase
    (commitment : DFMSHashCommitmentFunction) :=
  CompressedOracleDatabase commitment.X commitment.Y

def DFMSDatabaseCellMatches
    (commitment : DFMSHashCommitmentFunction)
    (t : commitment.T)
    (database : DFMSCompressedDatabase commitment)
    (x : commitment.X) : Prop :=
  ∃ y : commitment.Y, database x = some y ∧ commitment.f x y = t

def DFMSFirstMatchingAddress
    (commitment : DFMSHashCommitmentFunction)
    (t : commitment.T)
    (database : DFMSCompressedDatabase commitment)
    (x : commitment.X) : Prop :=
  DFMSDatabaseCellMatches commitment t database x
    ∧ ∀ x' : commitment.X,
      x' < x → ¬ DFMSDatabaseCellMatches commitment t database x'

def DFMSNoMatchingAddress
    (commitment : DFMSHashCommitmentFunction)
    (t : commitment.T)
    (database : DFMSCompressedDatabase commitment) : Prop :=
  ∀ x : commitment.X,
    ¬ DFMSDatabaseCellMatches commitment t database x

theorem dfms_firstMatchingAddress_matches
    {commitment : DFMSHashCommitmentFunction}
    {t : commitment.T}
    {database : DFMSCompressedDatabase commitment}
    {x : commitment.X}
    (hFirst : DFMSFirstMatchingAddress commitment t database x) :
    DFMSDatabaseCellMatches commitment t database x :=
  hFirst.1

theorem dfms_firstMatchingAddress_unique
    {commitment : DFMSHashCommitmentFunction}
    {t : commitment.T}
    {database : DFMSCompressedDatabase commitment}
    {x x' : commitment.X}
    (hFirst : DFMSFirstMatchingAddress commitment t database x)
    (hFirst' : DFMSFirstMatchingAddress commitment t database x') :
    x = x' := by
  by_contra hDistinct
  rcases lt_or_gt_of_ne hDistinct with hlt | hgt
  · exact (hFirst'.2 x hlt) hFirst.1
  · exact (hFirst.2 x' hgt) hFirst'.1

inductive DFMSExtractionOutcome (X : Type) where
  | value : X → DFMSExtractionOutcome X
  | none : DFMSExtractionOutcome X
  deriving DecidableEq

def DFMSExtractionOutcomeAccepted
    (commitment : DFMSHashCommitmentFunction)
    (t : commitment.T)
    (database : DFMSCompressedDatabase commitment) :
    DFMSExtractionOutcome commitment.X → Prop
  | .value x => DFMSFirstMatchingAddress commitment t database x
  | .none => DFMSNoMatchingAddress commitment t database

def DFMSIdentityHashCommitmentFunction
    (X Y : Type)
    [Fintype X] [DecidableEq X] [LinearOrder X]
    [Fintype Y] [DecidableEq Y] [AddCommGroup Y]
    (hashOutputBits : Nat)
    (hashOutputCardinality : Fintype.card Y = 2 ^ hashOutputBits) :
    DFMSHashCommitmentFunction where
  X := X
  Y := Y
  T := Y
  hashOutputBits := hashOutputBits
  hashOutputCardinality := hashOutputCardinality
  f := fun _ y => y

def DFMSBitvectorHashCommitmentFunction
    (n : Nat)
    (X T : Type)
    [Fintype X] [DecidableEq X] [LinearOrder X]
    [Fintype T] [DecidableEq T]
    (f : X → DFMSBitVector n → T) :
    DFMSHashCommitmentFunction where
  X := X
  Y := DFMSBitVector n
  T := T
  hashOutputBits := n
  hashOutputCardinality := dfmsBitVector_card n
  f := f

def DFMSBitvectorIdentityHashCommitmentFunction
    (n : Nat)
    (X : Type)
    [Fintype X] [DecidableEq X] [LinearOrder X] :
    DFMSHashCommitmentFunction :=
  DFMSIdentityHashCommitmentFunction
    X
    (DFMSBitVector n)
    n
    (dfmsBitVector_card n)

theorem finset_card_filter_eq_le_one
    {Y : Type} [Fintype Y] [DecidableEq Y] (target : Y) :
    ((Finset.univ : Finset Y).filter (fun y => y = target)).card ≤ 1 := by
  have hSubset :
      ((Finset.univ : Finset Y).filter (fun y => y = target)) ⊆
        ({target} : Finset Y) := by
    intro y hy
    rw [Finset.mem_filter] at hy
    simp [hy.2]
  calc
    ((Finset.univ : Finset Y).filter (fun y => y = target)).card ≤
        ({target} : Finset Y).card :=
      Finset.card_le_card hSubset
    _ = 1 := by simp

theorem dfmsIdentityHashCommitment_gammaBound_one
    (X Y : Type)
    [Fintype X] [DecidableEq X] [LinearOrder X]
    [Fintype Y] [DecidableEq Y] [AddCommGroup Y]
    (hashOutputBits : Nat)
    (hashOutputCardinality : Fintype.card Y = 2 ^ hashOutputBits) :
    DFMSGammaBound
      (DFMSIdentityHashCommitmentFunction
        X Y hashOutputBits hashOutputCardinality)
      1 := by
  intro _x t
  simpa [DFMSCommitmentFiber, DFMSIdentityHashCommitmentFunction] using
    finset_card_filter_eq_le_one t

theorem dfmsIdentityHashCommitment_gammaPrimeBound_one
    (X Y : Type)
    [Fintype X] [DecidableEq X] [LinearOrder X]
    [Fintype Y] [DecidableEq Y] [AddCommGroup Y]
    (hashOutputBits : Nat)
    (hashOutputCardinality : Fintype.card Y = 2 ^ hashOutputBits) :
    DFMSGammaPrimeBound
      (DFMSIdentityHashCommitmentFunction
        X Y hashOutputBits hashOutputCardinality)
      1 := by
  intro _x _x' y' _hDistinct
  simpa [DFMSCrossCommitmentFiber, DFMSIdentityHashCommitmentFunction] using
    finset_card_filter_eq_le_one y'

theorem dfmsBitvectorIdentityHashCommitment_gammaBound_one
    (n : Nat)
    (X : Type)
    [Fintype X] [DecidableEq X] [LinearOrder X] :
    DFMSGammaBound
      (DFMSBitvectorIdentityHashCommitmentFunction n X)
      1 :=
  dfmsIdentityHashCommitment_gammaBound_one
    X
    (DFMSBitVector n)
    n
    (dfmsBitVector_card n)

theorem dfmsBitvectorIdentityHashCommitment_gammaPrimeBound_one
    (n : Nat)
    (X : Type)
    [Fintype X] [DecidableEq X] [LinearOrder X] :
    DFMSGammaPrimeBound
      (DFMSBitvectorIdentityHashCommitmentFunction n X)
      1 :=
  dfmsIdentityHashCommitment_gammaPrimeBound_one
    X
    (DFMSBitVector n)
    n
    (dfmsBitVector_card n)

def DFMSHashOutputDenominator
    (commitment : DFMSHashCommitmentFunction) : ℝ :=
  (2 : ℝ) ^ commitment.hashOutputBits

def DFMSSqrtTightnessTerm
    (commitment : DFMSHashCommitmentFunction)
    (gamma : Nat) : ℝ :=
  Real.sqrt
    (((2 : ℝ) * (gamma : ℝ)) /
      DFMSHashOutputDenominator commitment)

def DFMSAdjacentSwapBound
    (commitment : DFMSHashCommitmentFunction)
    (gamma : Nat) : ℝ :=
  8 * DFMSSqrtTightnessTerm commitment gamma

def DFMSMultiOutputViewBound
    (commitment : DFMSHashCommitmentFunction)
    (ell q gamma : Nat) : ℝ :=
  8 * (ell : ℝ) * ((q + ell : Nat) : ℝ) *
    DFMSSqrtTightnessTerm commitment gamma

def DFMSMultiOutputExtractionFailureBound
    (commitment : DFMSHashCommitmentFunction)
    (ell q gamma gammaPrime : Nat) : ℝ :=
  8 * (ell : ℝ) * ((q + 1 : Nat) : ℝ) *
      DFMSSqrtTightnessTerm commitment gamma
    + (((40 : ℝ) * (Real.exp 1) ^ 2 *
          ((q + ell + 1 : Nat) : ℝ) ^ 3 *
          (gammaPrime : ℝ)) + 2) /
        DFMSHashOutputDenominator commitment

def DFMSProtocolOnlineExtractionBound
    (commitment : DFMSHashCommitmentFunction)
    (ell q gamma gammaPrime : Nat)
    (linkLoss : ℝ) : ℝ :=
  linkLoss
    + DFMSMultiOutputViewBound commitment ell q gamma
    + DFMSMultiOutputExtractionFailureBound
      commitment ell q gamma gammaPrime

structure DFMSProtocolApplicability
    (commitment : DFMSHashCommitmentFunction)
    (ell q gamma gammaPrime : Nat)
    (linkLoss : ℝ) where
  commitmentsClassicalAtExtractionTime : Prop
  commitmentsClassicalAtExtractionTimeHolds :
    commitmentsClassicalAtExtractionTime
  oracleAccessOnlyThroughSpecifiedQROInterface : Prop
  oracleAccessOnlyThroughSpecifiedQROInterfaceHolds :
    oracleAccessOnlyThroughSpecifiedQROInterface
  extractorMayQueryImmediatelyAfterCommitment : Prop
  extractorMayQueryImmediatelyAfterCommitmentHolds :
    extractorMayQueryImmediatelyAfterCommitment
  acceptingTranscriptOpensHashCommitmentsExceptLinkLoss : Prop
  acceptingTranscriptOpensHashCommitmentsExceptLinkLossHolds :
    acceptingTranscriptOpensHashCommitmentsExceptLinkLoss
  gammaBound : DFMSGammaBound commitment gamma
  gammaPrimeBound : DFMSGammaPrimeBound commitment gammaPrime

def DFMSProtocolApplicabilityAccepted
    {commitment : DFMSHashCommitmentFunction}
    {ell q gamma gammaPrime : Nat}
    {linkLoss : ℝ}
    (applicability :
      DFMSProtocolApplicability
        commitment ell q gamma gammaPrime linkLoss) : Prop :=
  applicability.commitmentsClassicalAtExtractionTime
    ∧ applicability.oracleAccessOnlyThroughSpecifiedQROInterface
    ∧ applicability.extractorMayQueryImmediatelyAfterCommitment
    ∧ applicability.acceptingTranscriptOpensHashCommitmentsExceptLinkLoss
    ∧ DFMSGammaBound commitment gamma
    ∧ DFMSGammaPrimeBound commitment gammaPrime

theorem DFMSProtocolApplicability.accepted
    {commitment : DFMSHashCommitmentFunction}
    {ell q gamma gammaPrime : Nat}
    {linkLoss : ℝ}
    (applicability :
      DFMSProtocolApplicability
        commitment ell q gamma gammaPrime linkLoss) :
    DFMSProtocolApplicabilityAccepted applicability :=
  ⟨applicability.commitmentsClassicalAtExtractionTimeHolds,
    applicability.oracleAccessOnlyThroughSpecifiedQROInterfaceHolds,
    applicability.extractorMayQueryImmediatelyAfterCommitmentHolds,
    applicability.acceptingTranscriptOpensHashCommitmentsExceptLinkLossHolds,
    applicability.gammaBound,
    applicability.gammaPrimeBound⟩

structure DFMSCompressedOracleCommutatorTheorem
    (commitment : DFMSHashCommitmentFunction)
    (gamma : Nat) where
  relationGammaBound :
    ∀ (t : commitment.T) (x : commitment.X),
      (DFMSCommitmentFiber commitment x t).card ≤ gamma
  exactTheorem31 : DFMSTh31ExactEvidence
  exactTheorem31GammaWithinSimulatorGamma :
    DFMSTh31GammaR exactTheorem31.theorem31.R ≤ gamma
  compressedOracleExternallyEquivalentWhenUnmeasured : Prop
  compressedOracleExternallyEquivalentWhenUnmeasuredHolds :
    compressedOracleExternallyEquivalentWhenUnmeasured
  randomOracleQueriesCommute : Prop
  randomOracleQueriesCommuteHolds : randomOracleQueriesCommute
  extractionQueriesCommute : Prop
  extractionQueriesCommuteHolds : extractionQueriesCommute
  adjacentROExtractionSwapTraceDistanceBound : Prop
  adjacentROExtractionSwapTraceDistanceBoundHolds :
    adjacentROExtractionSwapTraceDistanceBound
  classicalROQueriesIdempotent : Prop
  classicalROQueriesIdempotentHolds : classicalROQueriesIdempotent
  classicalExtractionQueriesIdempotent : Prop
  classicalExtractionQueriesIdempotentHolds :
    classicalExtractionQueriesIdempotent
  extractionThenROConsistencyBound : Prop
  extractionThenROConsistencyBoundHolds :
    extractionThenROConsistencyBound
  roThenExtractionFindsFreshCommitmentBound : Prop
  roThenExtractionFindsFreshCommitmentBoundHolds :
    roThenExtractionFindsFreshCommitmentBound

def DFMSCompressedOracleCommutatorTheoremAccepted
    {commitment : DFMSHashCommitmentFunction}
    {gamma : Nat}
    (theoremRecord :
      DFMSCompressedOracleCommutatorTheorem commitment gamma) : Prop :=
  (∀ (t : commitment.T) (x : commitment.X),
      (DFMSCommitmentFiber commitment x t).card ≤ gamma)
    ∧ DFMSTh31ExactEvidenceAccepted theoremRecord.exactTheorem31
    ∧ DFMSTh31GammaR theoremRecord.exactTheorem31.theorem31.R ≤ gamma
    ∧ theoremRecord.compressedOracleExternallyEquivalentWhenUnmeasured
    ∧ theoremRecord.randomOracleQueriesCommute
    ∧ theoremRecord.extractionQueriesCommute
    ∧ theoremRecord.adjacentROExtractionSwapTraceDistanceBound
    ∧ theoremRecord.classicalROQueriesIdempotent
    ∧ theoremRecord.classicalExtractionQueriesIdempotent
    ∧ theoremRecord.extractionThenROConsistencyBound
    ∧ theoremRecord.roThenExtractionFindsFreshCommitmentBound

theorem DFMSCompressedOracleCommutatorTheorem.accepted
    {commitment : DFMSHashCommitmentFunction}
    {gamma : Nat}
    (theoremRecord :
      DFMSCompressedOracleCommutatorTheorem commitment gamma) :
    DFMSCompressedOracleCommutatorTheoremAccepted theoremRecord :=
  ⟨theoremRecord.relationGammaBound,
    theoremRecord.exactTheorem31.accepted,
    theoremRecord.exactTheorem31GammaWithinSimulatorGamma,
    theoremRecord.compressedOracleExternallyEquivalentWhenUnmeasuredHolds,
    theoremRecord.randomOracleQueriesCommuteHolds,
    theoremRecord.extractionQueriesCommuteHolds,
    theoremRecord.adjacentROExtractionSwapTraceDistanceBoundHolds,
    theoremRecord.classicalROQueriesIdempotentHolds,
    theoremRecord.classicalExtractionQueriesIdempotentHolds,
    theoremRecord.extractionThenROConsistencyBoundHolds,
    theoremRecord.roThenExtractionFindsFreshCommitmentBoundHolds⟩

structure DFMSOnlineExtractionParameters where
  outputCount : Nat
  queryBound : Nat
  gamma : Nat
  gammaPrime : Nat
  linkLoss : ℝ
  viewLoss : ℝ
  extractionLoss : ℝ
  onlineExtractionLoss : ℝ

structure DFMSOnlineExtractionTheorem where
  commitment : DFMSHashCommitmentFunction
  parameters : DFMSOnlineExtractionParameters
  applicability :
    DFMSProtocolApplicability
      commitment
      parameters.outputCount
      parameters.queryBound
      parameters.gamma
      parameters.gammaPrime
      parameters.linkLoss
  commutatorTheorem :
    DFMSCompressedOracleCommutatorTheorem
      commitment
      parameters.gamma
  viewLossBound :
    DFMSMultiOutputViewBound
      commitment
      parameters.outputCount
      parameters.queryBound
      parameters.gamma ≤ parameters.viewLoss
  extractionLossBound :
    DFMSMultiOutputExtractionFailureBound
      commitment
      parameters.outputCount
      parameters.queryBound
      parameters.gamma
      parameters.gammaPrime ≤ parameters.extractionLoss
  onlineExtractionLossBound :
    DFMSProtocolOnlineExtractionBound
      commitment
      parameters.outputCount
      parameters.queryBound
      parameters.gamma
      parameters.gammaPrime
      parameters.linkLoss ≤ parameters.onlineExtractionLoss

def DFMSOnlineExtractionTheoremAccepted
    (theoremRecord : DFMSOnlineExtractionTheorem) : Prop :=
  DFMSProtocolApplicabilityAccepted theoremRecord.applicability
    ∧ DFMSCompressedOracleCommutatorTheoremAccepted
      theoremRecord.commutatorTheorem
    ∧ DFMSMultiOutputViewBound
      theoremRecord.commitment
      theoremRecord.parameters.outputCount
      theoremRecord.parameters.queryBound
      theoremRecord.parameters.gamma ≤
      theoremRecord.parameters.viewLoss
    ∧ DFMSMultiOutputExtractionFailureBound
      theoremRecord.commitment
      theoremRecord.parameters.outputCount
      theoremRecord.parameters.queryBound
      theoremRecord.parameters.gamma
      theoremRecord.parameters.gammaPrime ≤
      theoremRecord.parameters.extractionLoss
    ∧ DFMSProtocolOnlineExtractionBound
      theoremRecord.commitment
      theoremRecord.parameters.outputCount
      theoremRecord.parameters.queryBound
      theoremRecord.parameters.gamma
      theoremRecord.parameters.gammaPrime
      theoremRecord.parameters.linkLoss ≤
      theoremRecord.parameters.onlineExtractionLoss

theorem DFMSOnlineExtractionTheorem.accepted
    (theoremRecord : DFMSOnlineExtractionTheorem) :
    DFMSOnlineExtractionTheoremAccepted theoremRecord :=
  ⟨theoremRecord.applicability.accepted,
    theoremRecord.commutatorTheorem.accepted,
    theoremRecord.viewLossBound,
    theoremRecord.extractionLossBound,
    theoremRecord.onlineExtractionLossBound⟩

structure DFMSSplitQROOnlineExtractionTheorem where
  splitOracle : SplitQROSemanticBundle
  minHashOutputBits : Nat
  gammaMax : Nat
  gammaPrimeMax : Nat
  outputCount : Nat
  queryBound : Nat
  linkLoss : ℝ
  viewLoss : ℝ
  extractionLoss : ℝ
  splitOracleAccepted : SplitQROSemanticBundleAccepted splitOracle
  typedAddressRelationLabelsIncluded : Prop
  typedAddressRelationLabelsIncludedHolds :
    typedAddressRelationLabelsIncluded
  perLabelDFMSApplicability : Prop
  perLabelDFMSApplicabilityHolds : perLabelDFMSApplicability
  viewLossBound :
    8 * (outputCount : ℝ) * ((queryBound + outputCount : Nat) : ℝ) *
        Real.sqrt
          (((2 : ℝ) * (gammaMax : ℝ)) /
            ((2 : ℝ) ^ minHashOutputBits)) ≤ viewLoss
  extractionLossBound :
    8 * (outputCount : ℝ) * ((queryBound + 1 : Nat) : ℝ) *
        Real.sqrt
          (((2 : ℝ) * (gammaMax : ℝ)) /
            ((2 : ℝ) ^ minHashOutputBits))
      + (((40 : ℝ) * (Real.exp 1) ^ 2 *
            ((queryBound + outputCount + 1 : Nat) : ℝ) ^ 3 *
            (gammaPrimeMax : ℝ)) + 2) /
          ((2 : ℝ) ^ minHashOutputBits) ≤ extractionLoss

def DFMSSplitQROOnlineExtractionTheoremAccepted
    (theoremRecord : DFMSSplitQROOnlineExtractionTheorem) : Prop :=
  SplitQROSemanticBundleAccepted theoremRecord.splitOracle
    ∧ theoremRecord.typedAddressRelationLabelsIncluded
    ∧ theoremRecord.perLabelDFMSApplicability
    ∧
      8 * (theoremRecord.outputCount : ℝ) *
          ((theoremRecord.queryBound + theoremRecord.outputCount : Nat) : ℝ) *
          Real.sqrt
            (((2 : ℝ) * (theoremRecord.gammaMax : ℝ)) /
              ((2 : ℝ) ^ theoremRecord.minHashOutputBits)) ≤
        theoremRecord.viewLoss
    ∧
      8 * (theoremRecord.outputCount : ℝ) *
          ((theoremRecord.queryBound + 1 : Nat) : ℝ) *
          Real.sqrt
            (((2 : ℝ) * (theoremRecord.gammaMax : ℝ)) /
              ((2 : ℝ) ^ theoremRecord.minHashOutputBits))
        + (((40 : ℝ) * (Real.exp 1) ^ 2 *
              ((theoremRecord.queryBound +
                    theoremRecord.outputCount + 1 : Nat) : ℝ) ^ 3 *
              (theoremRecord.gammaPrimeMax : ℝ)) + 2) /
            ((2 : ℝ) ^ theoremRecord.minHashOutputBits) ≤
          theoremRecord.extractionLoss

theorem DFMSSplitQROOnlineExtractionTheorem.accepted
    (theoremRecord : DFMSSplitQROOnlineExtractionTheorem) :
    DFMSSplitQROOnlineExtractionTheoremAccepted theoremRecord :=
  ⟨theoremRecord.splitOracleAccepted,
    theoremRecord.typedAddressRelationLabelsIncludedHolds,
    theoremRecord.perLabelDFMSApplicabilityHolds,
    theoremRecord.viewLossBound,
    theoremRecord.extractionLossBound⟩

end SuperNeoFormal
