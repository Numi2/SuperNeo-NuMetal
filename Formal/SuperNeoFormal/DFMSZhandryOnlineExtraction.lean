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

noncomputable def DFMSTh31CellMatchProjectorOperator
    {n : Nat}
    {X : Type}
    (R : X → DFMSBitVector n → Prop)
    [DecidableRel R]
    (x : X) :
    DFMSContinuousOperator (DFMSTh31CellBasis n) :=
  (DFMSTh31CellMatchProjectorMatrix R x).toContinuous

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

def DFMSTh31LocalEvaluationEquiv
    (n : Nat) :
    DFMSTh31LocalQueryBasis n ≃ DFMSTh31LocalQueryBasis n where
  toFun input := (input.1 + DFMSTh31CellValue input.2, input.2)
  invFun output := (output.1 - DFMSTh31CellValue output.2, output.2)
  left_inv := by
    intro input
    ext <;> simp
  right_inv := by
    intro output
    ext <;> simp

lemma DFMSTh31LocalEvaluationMatrix_eq_permMatrix
    (n : Nat) :
    DFMSTh31LocalEvaluationMatrix n =
      Equiv.Perm.permMatrix ℂ
        (DFMSTh31LocalEvaluationEquiv n).symm := by
  ext output input
  simp [DFMSTh31LocalEvaluationMatrix, Equiv.Perm.permMatrix,
    PEquiv.toMatrix, DFMSTh31LocalEvaluationEquiv]
  have hiff :
      (output.1 - DFMSTh31CellValue output.2, output.2) = input ↔
        output =
          (input.1 + DFMSTh31CellValue input.2, input.2) := by
    constructor
    · intro h
      rw [← h]
      ext <;> simp
    · intro h
      rw [h]
      ext <;> simp
  by_cases h :
      output =
        (input.1 + DFMSTh31CellValue input.2, input.2)
  · simp [h]
  · have hinv :
        (output.1 - DFMSTh31CellValue output.2, output.2) ≠
          input :=
      mt hiff.mp h
    simp [h, hinv]

theorem DFMSTh31LocalEvaluationOperator_norm_le_one
    (n : Nat) :
    ‖DFMSTh31LocalEvaluationOperator n‖ ≤ 1 := by
  unfold DFMSTh31LocalEvaluationOperator DFMSMatrixOperator.toContinuous
  rw [DFMSTh31LocalEvaluationMatrix_eq_permMatrix n]
  rw [Matrix.l2_opNorm_toEuclideanCLM]
  exact Matrix.permMatrix_l2_opNorm_le _

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

noncomputable def DFMSRankOneOperator
    {E : Type} [NormedAddCommGroup E] [InnerProductSpace ℂ E]
    (u v : E) : E →L[ℂ] E :=
  ContinuousLinearMap.smulRight ((innerSL ℂ) u) v

noncomputable def DFMSSkewRankTwoOperator
    {E : Type} [NormedAddCommGroup E] [InnerProductSpace ℂ E]
    (u v : E) : E →L[ℂ] E :=
  DFMSRankOneOperator u v - DFMSRankOneOperator v u

noncomputable def DFMSSkewPairOperator
    {E : Type} [NormedAddCommGroup E] [InnerProductSpace ℂ E]
    (e : Fin 2 → E) : E →L[ℂ] E :=
  DFMSRankOneOperator (e 0) (e 1) -
    DFMSRankOneOperator (e 1) (e 0)

noncomputable def DFMSSkewPairCoeff
    {E : Type} [NormedAddCommGroup E] [InnerProductSpace ℂ E]
    (e : Fin 2 → E) (x : E) : Fin 2 → ℂ :=
  fun i => if i = 0 then -inner ℂ (e 1) x else inner ℂ (e 0) x

lemma DFMSSkewPairOperator_apply_eq_sum
    {E : Type} [NormedAddCommGroup E] [InnerProductSpace ℂ E]
    (e : Fin 2 → E) (x : E) :
    DFMSSkewPairOperator e x =
      ∑ i, DFMSSkewPairCoeff e x i • e i := by
  rw [Fin.sum_univ_two]
  simp [DFMSSkewPairOperator, DFMSRankOneOperator,
    DFMSSkewPairCoeff, sub_eq_add_neg]
  abel

lemma DFMSComplex_re_conj_mul_self (z : ℂ) :
    ((starRingEnd ℂ) z * z).re = ‖z‖ ^ 2 := by
  rw [Complex.conj_mul']
  rw [← Complex.ofReal_pow]
  exact Complex.ofReal_re _

lemma DFMSComplex_re_sum_conj_mul_self_fin_two (a : Fin 2 → ℂ) :
    (∑ i, (starRingEnd ℂ) (a i) * a i).re =
      ∑ i, ‖a i‖ ^ 2 := by
  rw [Fin.sum_univ_two, Fin.sum_univ_two]
  rw [Complex.add_re]
  rw [DFMSComplex_re_conj_mul_self, DFMSComplex_re_conj_mul_self]

lemma DFMSSkewPairOperator_apply_norm_sq
    {E : Type} [NormedAddCommGroup E] [InnerProductSpace ℂ E]
    (e : Fin 2 → E) (he : Orthonormal ℂ e) (x : E) :
    ‖DFMSSkewPairOperator e x‖ ^ 2 =
      ∑ i, ‖DFMSSkewPairCoeff e x i‖ ^ 2 := by
  rw [DFMSSkewPairOperator_apply_eq_sum]
  rw [@InnerProductSpace.norm_sq_eq_re_inner ℂ E _ _ _]
  rw [he.inner_sum (DFMSSkewPairCoeff e x)
    (DFMSSkewPairCoeff e x) Finset.univ]
  exact DFMSComplex_re_sum_conj_mul_self_fin_two _

lemma DFMSSkewPairCoeff_sum_le
    {E : Type} [NormedAddCommGroup E] [InnerProductSpace ℂ E]
    (e : Fin 2 → E) (he : Orthonormal ℂ e) (x : E) :
    (∑ i, ‖DFMSSkewPairCoeff e x i‖ ^ 2) ≤ ‖x‖ ^ 2 := by
  rw [Fin.sum_univ_two]
  have hb := he.sum_inner_products_le x (s := Finset.univ)
  rw [Fin.sum_univ_two] at hb
  simpa [DFMSSkewPairCoeff, norm_neg, add_comm] using hb

lemma DFMSSkewPairOperator_norm_le_one
    {E : Type} [NormedAddCommGroup E] [InnerProductSpace ℂ E]
    (e : Fin 2 → E) (he : Orthonormal ℂ e) :
    ‖DFMSSkewPairOperator e‖ ≤ 1 := by
  refine ContinuousLinearMap.opNorm_le_bound _ zero_le_one fun x => ?_
  apply (sq_le_sq₀ (norm_nonneg _) (by positivity)).mp
  rw [one_mul]
  rw [DFMSSkewPairOperator_apply_norm_sq e he x]
  exact DFMSSkewPairCoeff_sum_le e he x

lemma DFMSSkewPairOperator_norm_eq_one
    {E : Type} [NormedAddCommGroup E] [InnerProductSpace ℂ E]
    (e : Fin 2 → E) (he : Orthonormal ℂ e) :
    ‖DFMSSkewPairOperator e‖ = 1 := by
  apply le_antisymm
  · exact DFMSSkewPairOperator_norm_le_one e he
  · have htest := ContinuousLinearMap.le_opNorm
      (DFMSSkewPairOperator e) (e 0)
    have hnorm0 : ‖e 0‖ = 1 := he.norm_eq_one 0
    have himage : DFMSSkewPairOperator e (e 0) = e 1 := by
      simp [DFMSSkewPairOperator, DFMSRankOneOperator,
        he.inner_eq_zero (by decide : (1 : Fin 2) ≠ 0),
        inner_self_eq_norm_sq_to_K, hnorm0]
    rw [himage, he.norm_eq_one 1, hnorm0, mul_one] at htest
    exact htest

lemma DFMSNormalizedPair_orthonormal
    {E : Type} [NormedAddCommGroup E] [InnerProductSpace ℂ E]
    (u v : E) (horth : inner ℂ u v = 0)
    (hu : u ≠ 0) (hv : v ≠ 0) :
    Orthonormal ℂ
      (fun i : Fin 2 =>
        if i = 0 then ((‖u‖ : ℂ)⁻¹) • u
        else ((‖v‖ : ℂ)⁻¹) • v) := by
  constructor
  · intro i
    fin_cases i
    · simp only [Fin.isValue, Fin.zero_eta, ↓reduceIte]
      rw [norm_smul]
      simp [norm_ne_zero_iff.mpr hu]
    · simp only [Fin.isValue, Fin.mk_one, one_ne_zero, ↓reduceIte]
      rw [norm_smul]
      simp [norm_ne_zero_iff.mpr hv]
  · intro i j hij
    fin_cases i <;> fin_cases j
    · exact False.elim (hij rfl)
    · simp only [Fin.isValue, Fin.zero_eta, Fin.mk_one,
        ↓reduceIte, one_ne_zero]
      rw [inner_smul_left, inner_smul_right, horth, mul_zero, mul_zero]
    · simp only [Fin.isValue, Fin.zero_eta, Fin.mk_one,
        ↓reduceIte, one_ne_zero]
      rw [inner_smul_left, inner_smul_right]
      have hvu : inner ℂ v u = 0 := inner_eq_zero_symm.mp horth
      rw [hvu, mul_zero, mul_zero]
    · exact False.elim (hij rfl)

lemma DFMSSkewRankTwoOperator_eq_scaled_skewPair
    {E : Type} [NormedAddCommGroup E] [InnerProductSpace ℂ E]
    (u v : E) (hu : u ≠ 0) (hv : v ≠ 0) :
    DFMSSkewRankTwoOperator u v =
      ((↑(‖u‖ * ‖v‖) : ℂ)) •
        DFMSSkewPairOperator
          (fun i : Fin 2 =>
            if i = 0 then ((‖u‖ : ℂ)⁻¹) • u
            else ((‖v‖ : ℂ)⁻¹) • v) := by
  ext x
  simp only [DFMSSkewRankTwoOperator, DFMSSkewPairOperator,
    DFMSRankOneOperator, ContinuousLinearMap.sub_apply,
    ContinuousLinearMap.smul_apply, ContinuousLinearMap.smulRight_apply,
    innerSL_apply_apply]
  simp only [Fin.isValue, one_ne_zero, ↓reduceIte]
  rw [inner_smul_left, inner_smul_left]
  simp only [map_inv₀, Complex.conj_ofReal, smul_sub, smul_smul]
  have hscaleU :
      ↑(‖u‖ * ‖v‖) *
          ((↑‖u‖)⁻¹ * inner ℂ u x * (↑‖v‖)⁻¹) =
        inner ℂ u x := by
    rw [Complex.ofReal_mul]
    field_simp [Complex.ofReal_ne_zero.mpr (norm_ne_zero_iff.mpr hu),
      Complex.ofReal_ne_zero.mpr (norm_ne_zero_iff.mpr hv)]
  have hscaleV :
      ↑(‖u‖ * ‖v‖) *
          ((↑‖v‖)⁻¹ * inner ℂ v x * (↑‖u‖)⁻¹) =
        inner ℂ v x := by
    rw [Complex.ofReal_mul]
    field_simp [Complex.ofReal_ne_zero.mpr (norm_ne_zero_iff.mpr hu),
      Complex.ofReal_ne_zero.mpr (norm_ne_zero_iff.mpr hv)]
  rw [hscaleU, hscaleV]

lemma DFMSSkewRankTwoOperator_norm_eq
    {E : Type} [NormedAddCommGroup E] [InnerProductSpace ℂ E]
    (u v : E) (horth : inner ℂ u v = 0) :
    ‖DFMSSkewRankTwoOperator u v‖ = ‖u‖ * ‖v‖ := by
  by_cases hu : u = 0
  · subst hu
    have hzero : DFMSSkewRankTwoOperator (0 : E) v = 0 := by
      ext x
      simp [DFMSSkewRankTwoOperator, DFMSRankOneOperator]
    rw [hzero]
    simp
  by_cases hv : v = 0
  · subst hv
    have hzero : DFMSSkewRankTwoOperator u (0 : E) = 0 := by
      ext x
      simp [DFMSSkewRankTwoOperator, DFMSRankOneOperator]
    rw [hzero]
    simp
  rw [DFMSSkewRankTwoOperator_eq_scaled_skewPair u v hu hv]
  rw [norm_smul]
  rw [DFMSSkewPairOperator_norm_eq_one _
    (DFMSNormalizedPair_orthonormal u v horth hu hv)]
  simp

theorem DFMSTh31LocalEvaluationMatrix_commutes_matchProjector
    {n : Nat}
    {X : Type}
    (R : X → DFMSBitVector n → Prop)
    [DecidableRel R]
    (x : X) :
    DFMSTh31LocalEvaluationMatrix n *
        DFMSTh31LocalMatchProjectorMatrix R x =
      DFMSTh31LocalMatchProjectorMatrix R x *
        DFMSTh31LocalEvaluationMatrix n := by
  classical
  ext output input
  rw [Matrix.mul_apply, Matrix.mul_apply]
  let target : DFMSTh31LocalQueryBasis n :=
    (input.1 + DFMSTh31CellValue input.2, input.2)
  have hLeft :
      (∑ mid,
          DFMSTh31LocalEvaluationMatrix n output mid *
            DFMSTh31LocalMatchProjectorMatrix R x mid input) =
        DFMSTh31LocalEvaluationMatrix n output input *
          DFMSTh31LocalMatchProjectorMatrix R x input input := by
    refine Finset.sum_eq_single input ?_ ?_
    · intro mid _hmem hne
      by_cases hQuery : mid.1 = input.1
      · have hCell : mid.2 ≠ input.2 := by
          intro hEq
          apply hne
          exact Prod.ext hQuery hEq
        have hPzero :
            DFMSTh31CellMatchProjectorMatrix R x mid.2 input.2 = 0 := by
          simp [DFMSTh31CellMatchProjectorMatrix, hCell]
        simp [DFMSTh31LocalMatchProjectorMatrix,
          DFMSTh31LiftCellMatrix, hQuery, hPzero]
      · simp [DFMSTh31LocalMatchProjectorMatrix,
          DFMSTh31LiftCellMatrix, hQuery]
    · intro hnot
      exact False.elim (hnot (Finset.mem_univ input))
  have hRight :
      (∑ mid,
          DFMSTh31LocalMatchProjectorMatrix R x output mid *
            DFMSTh31LocalEvaluationMatrix n mid input) =
        DFMSTh31LocalMatchProjectorMatrix R x output target *
          DFMSTh31LocalEvaluationMatrix n target input := by
    refine Finset.sum_eq_single target ?_ ?_
    · intro mid _hmem hne
      simp [DFMSTh31LocalEvaluationMatrix, target, hne]
    · intro hnot
      exact False.elim (hnot (Finset.mem_univ target))
  rw [hLeft, hRight]
  by_cases hTarget : output = target
  · simp [DFMSTh31LocalEvaluationMatrix, DFMSTh31LocalMatchProjectorMatrix,
      DFMSTh31LiftCellMatrix, target, hTarget]
  · by_cases hQuery : output.1 = target.1
    · have hCell : output.2 ≠ input.2 := by
        intro hEq
        apply hTarget
        exact Prod.ext hQuery (by simpa [target] using hEq)
      have hPzero :
          DFMSTh31CellMatchProjectorMatrix R x output.2 input.2 = 0 := by
        simp [DFMSTh31CellMatchProjectorMatrix, hCell]
      simp [DFMSTh31LocalEvaluationMatrix, DFMSTh31LocalMatchProjectorMatrix,
        DFMSTh31LiftCellMatrix, target, hTarget, hQuery, hPzero]
    · simp [DFMSTh31LocalEvaluationMatrix, DFMSTh31LocalMatchProjectorMatrix,
        DFMSTh31LiftCellMatrix, target, hTarget, hQuery]

theorem DFMSTh31LocalEvaluationOperator_commutes_matchProjector
    {n : Nat}
    {X : Type}
    (R : X → DFMSBitVector n → Prop)
    [DecidableRel R]
    (x : X) :
    DFMSOperatorCommutator
        (DFMSTh31LocalEvaluationOperator n)
        (DFMSTh31LocalMatchProjectorOperator R x) = 0 := by
  ext vector basis
  simp [DFMSOperatorCommutator, DFMSTh31LocalEvaluationOperator,
    DFMSTh31LocalMatchProjectorOperator, DFMSMatrixOperator.toContinuous]
  exact sub_eq_zero.mpr
    (congrArg
      (fun operator :
          DFMSMatrixOperator (DFMSTh31LocalQueryBasis n) =>
        operator.mulVec vector.ofLp basis)
      (DFMSTh31LocalEvaluationMatrix_commutes_matchProjector R x))

noncomputable def DFMSTh31LocalSlice
    {n : Nat}
    (vector : EuclideanSpace ℂ (DFMSTh31LocalQueryBasis n))
    (query : DFMSBitVector n) :
    EuclideanSpace ℂ (DFMSTh31CellBasis n) :=
  WithLp.toLp 2 (fun cell => vector.ofLp (query, cell))

noncomputable def DFMSTh31LocalCellEmbed
    {n : Nat}
    (query : DFMSBitVector n)
    (vector : EuclideanSpace ℂ (DFMSTh31CellBasis n)) :
    EuclideanSpace ℂ (DFMSTh31LocalQueryBasis n) :=
  WithLp.toLp 2
    (fun basis => if basis.1 = query then vector.ofLp basis.2 else 0)

lemma DFMSTh31LiftCellOperator_apply_slice
    {n : Nat}
    (M : DFMSMatrixOperator (DFMSTh31CellBasis n))
    (vector : EuclideanSpace ℂ (DFMSTh31LocalQueryBasis n))
    (query : DFMSBitVector n)
    (cell : DFMSTh31CellBasis n) :
    (((DFMSTh31LiftCellMatrix M).toContinuous vector).ofLp
        (query, cell)) =
      (((M.toContinuous) (DFMSTh31LocalSlice vector query)).ofLp
        cell) := by
  simp [DFMSMatrixOperator.toContinuous, DFMSTh31LiftCellMatrix,
    DFMSTh31LocalSlice, Matrix.ofLp_toEuclideanCLM, Matrix.mulVec,
    dotProduct]
  rw [Fintype.sum_prod_type]
  simp

lemma DFMSTh31LiftCellOperator_apply_norm_sq
    {n : Nat}
    (M : DFMSMatrixOperator (DFMSTh31CellBasis n))
    (vector : EuclideanSpace ℂ (DFMSTh31LocalQueryBasis n)) :
    ‖(DFMSTh31LiftCellMatrix M).toContinuous vector‖ ^ 2 =
      ∑ query : DFMSBitVector n,
        ‖M.toContinuous (DFMSTh31LocalSlice vector query)‖ ^ 2 := by
  rw [EuclideanSpace.norm_sq_eq]
  rw [Fintype.sum_prod_type]
  apply Finset.sum_congr rfl
  intro query _hquery
  rw [EuclideanSpace.norm_sq_eq]
  apply Finset.sum_congr rfl
  intro cell _hcell
  rw [DFMSTh31LiftCellOperator_apply_slice M vector query cell]

lemma DFMSTh31LocalSlice_norm_sq
    {n : Nat}
    (vector : EuclideanSpace ℂ (DFMSTh31LocalQueryBasis n)) :
    ‖vector‖ ^ 2 =
      ∑ query : DFMSBitVector n,
        ‖DFMSTh31LocalSlice vector query‖ ^ 2 := by
  rw [EuclideanSpace.norm_sq_eq]
  simp [DFMSTh31LocalSlice]
  rw [Fintype.sum_prod_type]
  simp [EuclideanSpace.norm_sq_eq]

lemma DFMSTh31LocalCellEmbed_norm
    {n : Nat}
    (query : DFMSBitVector n)
    (vector : EuclideanSpace ℂ (DFMSTh31CellBasis n)) :
    ‖DFMSTh31LocalCellEmbed query vector‖ = ‖vector‖ := by
  apply (sq_eq_sq₀ (norm_nonneg _) (norm_nonneg _)).mp
  rw [EuclideanSpace.norm_sq_eq, EuclideanSpace.norm_sq_eq]
  rw [Fintype.sum_prod_type]
  simp only [DFMSTh31LocalCellEmbed]
  change
    (∑ q : DFMSBitVector n,
      ∑ cell : DFMSTh31CellBasis n,
        ‖if q = query then vector.ofLp cell else 0‖ ^ 2) =
      ∑ cell : DFMSTh31CellBasis n, ‖vector.ofLp cell‖ ^ 2
  simpa using
    (Finset.sum_eq_single
      (s := (Finset.univ : Finset (DFMSBitVector n)))
      (a := query)
      (f := fun q : DFMSBitVector n =>
        ∑ cell : DFMSTh31CellBasis n,
          ‖if q = query then vector.ofLp cell else 0‖ ^ 2)
      (by
        intro q _hq hqne
        simp [hqne])
      (by
        intro hnot
        exact False.elim (hnot (Finset.mem_univ query))))

lemma DFMSTh31LiftCellOperator_apply_embed
    {n : Nat}
    (M : DFMSMatrixOperator (DFMSTh31CellBasis n))
    (query : DFMSBitVector n)
    (vector : EuclideanSpace ℂ (DFMSTh31CellBasis n)) :
    (DFMSTh31LiftCellMatrix M).toContinuous
        (DFMSTh31LocalCellEmbed query vector) =
      DFMSTh31LocalCellEmbed query (M.toContinuous vector) := by
  ext basis
  simp [DFMSMatrixOperator.toContinuous, DFMSTh31LiftCellMatrix,
    DFMSTh31LocalCellEmbed, Matrix.ofLp_toEuclideanCLM, Matrix.mulVec,
    dotProduct]
  rw [Fintype.sum_prod_type]
  by_cases h : basis.1 = query
  · subst h
    simp
  · simp [h]

lemma DFMSTh31LiftCellOperator_norm_le
    {n : Nat}
    (M : DFMSMatrixOperator (DFMSTh31CellBasis n)) :
    ‖(DFMSTh31LiftCellMatrix M).toContinuous‖ ≤ ‖M.toContinuous‖ := by
  refine ContinuousLinearMap.opNorm_le_bound _
    (ContinuousLinearMap.opNorm_nonneg _) fun vector => ?_
  apply (sq_le_sq₀ (norm_nonneg _)
    (mul_nonneg (ContinuousLinearMap.opNorm_nonneg _) (norm_nonneg _))).mp
  rw [DFMSTh31LiftCellOperator_apply_norm_sq M vector]
  calc
    (∑ query : DFMSBitVector n,
        ‖M.toContinuous (DFMSTh31LocalSlice vector query)‖ ^ 2) ≤
      ∑ query : DFMSBitVector n,
        (‖M.toContinuous‖ *
          ‖DFMSTh31LocalSlice vector query‖) ^ 2 := by
        apply Finset.sum_le_sum
        intro query _hquery
        exact
          (sq_le_sq₀ (norm_nonneg _)
            (mul_nonneg
              (ContinuousLinearMap.opNorm_nonneg _)
              (norm_nonneg _))).mpr
            (ContinuousLinearMap.le_opNorm _ _)
    _ =
      ‖M.toContinuous‖ ^ 2 *
        ∑ query : DFMSBitVector n,
          ‖DFMSTh31LocalSlice vector query‖ ^ 2 := by
        rw [Finset.mul_sum]
        apply Finset.sum_congr rfl
        intro query _hquery
        ring
    _ = (‖M.toContinuous‖ * ‖vector‖) ^ 2 := by
        rw [← DFMSTh31LocalSlice_norm_sq vector]
        ring

lemma DFMSTh31LiftCellOperator_norm_ge
    {n : Nat}
    (M : DFMSMatrixOperator (DFMSTh31CellBasis n)) :
    ‖M.toContinuous‖ ≤ ‖(DFMSTh31LiftCellMatrix M).toContinuous‖ := by
  refine ContinuousLinearMap.opNorm_le_bound _
    (ContinuousLinearMap.opNorm_nonneg _) fun vector => ?_
  let query : DFMSBitVector n := DFMSBitVector.zero n
  have h := ContinuousLinearMap.le_opNorm
    ((DFMSTh31LiftCellMatrix M).toContinuous)
    (DFMSTh31LocalCellEmbed query vector)
  rw [DFMSTh31LiftCellOperator_apply_embed M query vector,
    DFMSTh31LocalCellEmbed_norm query (M.toContinuous vector),
    DFMSTh31LocalCellEmbed_norm query vector] at h
  exact h

theorem DFMSTh31LiftCellOperator_norm_eq
    {n : Nat}
    (M : DFMSMatrixOperator (DFMSTh31CellBasis n)) :
    DFMSOperatorNorm ((DFMSTh31LiftCellMatrix M).toContinuous) =
      DFMSOperatorNorm M.toContinuous := by
  unfold DFMSOperatorNorm
  exact le_antisymm
    (DFMSTh31LiftCellOperator_norm_le M)
    (DFMSTh31LiftCellOperator_norm_ge M)

lemma DFMSTh31LiftCellMatrix_mul
    {n : Nat}
    (A B : DFMSMatrixOperator (DFMSTh31CellBasis n)) :
    DFMSTh31LiftCellMatrix (A * B) =
      DFMSTh31LiftCellMatrix A * DFMSTh31LiftCellMatrix B := by
  ext output input
  simp [DFMSTh31LiftCellMatrix, Matrix.mul_apply]
  rw [Fintype.sum_prod_type]
  by_cases h : output.1 = input.1 <;> simp [h]

lemma DFMSTh31LiftCellMatrix_sub
    {n : Nat}
    (A B : DFMSMatrixOperator (DFMSTh31CellBasis n)) :
    DFMSTh31LiftCellMatrix (A - B) =
      DFMSTh31LiftCellMatrix A - DFMSTh31LiftCellMatrix B := by
  ext output input
  by_cases h : output.1 = input.1 <;>
    simp [DFMSTh31LiftCellMatrix, h]

lemma DFMSTh31LiftCellMatrix_commutator
    {n : Nat}
    (A B : DFMSMatrixOperator (DFMSTh31CellBasis n)) :
    DFMSTh31LiftCellMatrix (A * B - B * A) =
      DFMSTh31LiftCellMatrix A * DFMSTh31LiftCellMatrix B -
        DFMSTh31LiftCellMatrix B * DFMSTh31LiftCellMatrix A := by
  rw [DFMSTh31LiftCellMatrix_sub,
    DFMSTh31LiftCellMatrix_mul,
    DFMSTh31LiftCellMatrix_mul]

theorem DFMSMatrixOperator.toContinuous_commutator
    {A : Type} [Fintype A] [DecidableEq A]
    (M N : DFMSMatrixOperator A) :
    DFMSOperatorCommutator M.toContinuous N.toContinuous =
      DFMSMatrixOperator.toContinuous (A := A) (M * N - N * M) := by
  ext vector basis
  simp [DFMSOperatorCommutator, DFMSMatrixOperator.toContinuous,
    Matrix.ofLp_toEuclideanCLM, Matrix.mulVec_mulVec]

theorem DFMSTh31LocalFourierMatchCommutator_lift
    {n : Nat}
    {X : Type}
    (R : X → DFMSBitVector n → Prop)
    [DecidableRel R]
    (x : X) :
    DFMSOperatorCommutator
        (DFMSTh31LocalFourierOperator n)
        (DFMSTh31LocalMatchProjectorOperator R x) =
      (DFMSTh31LiftCellMatrix
        (DFMSTh31CellFourierMatrix n *
            DFMSTh31CellMatchProjectorMatrix R x -
          DFMSTh31CellMatchProjectorMatrix R x *
            DFMSTh31CellFourierMatrix n)).toContinuous := by
  simp only [DFMSTh31LocalFourierOperator,
    DFMSTh31LocalMatchProjectorOperator, DFMSTh31LocalFourierMatrix,
    DFMSTh31LocalMatchProjectorMatrix]
  rw [DFMSMatrixOperator.toContinuous_commutator]
  rw [← DFMSTh31LiftCellMatrix_commutator]

theorem DFMSTh31LocalFourierOperator_norm_eq_cell
    (n : Nat) :
    ‖DFMSTh31LocalFourierOperator n‖ =
      ‖DFMSTh31CellFourierOperator n‖ := by
  simpa [DFMSOperatorNorm, DFMSTh31LocalFourierOperator,
    DFMSTh31CellFourierOperator, DFMSTh31LocalFourierMatrix] using
    DFMSTh31LiftCellOperator_norm_eq (DFMSTh31CellFourierMatrix n)

theorem DFMSTh31CellNoMatchProjectorMatrix_eq_one_sub_match
    {n : Nat}
    {X : Type}
    (R : X → DFMSBitVector n → Prop)
    [DecidableRel R]
    (x : X) :
    DFMSTh31CellNoMatchProjectorMatrix R x =
      1 - DFMSTh31CellMatchProjectorMatrix R x := by
  ext output input
  cases output with
  | none =>
      cases input <;>
        simp [DFMSTh31CellNoMatchProjectorMatrix,
          DFMSTh31CellMatchProjectorMatrix]
  | some outputY =>
      cases input with
      | none =>
          simp [DFMSTh31CellNoMatchProjectorMatrix,
            DFMSTh31CellMatchProjectorMatrix]
      | some inputY =>
          by_cases hEq : outputY = inputY
          · by_cases hMatch : R x inputY
            · simp [DFMSTh31CellNoMatchProjectorMatrix,
                DFMSTh31CellMatchProjectorMatrix, hEq, hMatch]
            · simp [DFMSTh31CellNoMatchProjectorMatrix,
                DFMSTh31CellMatchProjectorMatrix, hEq, hMatch]
          · simp [DFMSTh31CellNoMatchProjectorMatrix,
              DFMSTh31CellMatchProjectorMatrix, hEq]

theorem DFMSTh31LocalNoMatchProjectorMatrix_eq_one_sub_match
    {n : Nat}
    {X : Type}
    (R : X → DFMSBitVector n → Prop)
    [DecidableRel R]
    (x : X) :
    DFMSTh31LocalNoMatchProjectorMatrix R x =
      1 - DFMSTh31LocalMatchProjectorMatrix R x := by
  ext output input
  have hCell :=
    congrFun
      (congrFun
        (DFMSTh31CellNoMatchProjectorMatrix_eq_one_sub_match R x)
        output.2)
      input.2
  by_cases hQuery : output.1 = input.1
  · by_cases hCellEq : output.2 = input.2
    · have hInput : output = input := Prod.ext hQuery hCellEq
      simpa [DFMSTh31LocalNoMatchProjectorMatrix,
        DFMSTh31LocalMatchProjectorMatrix, DFMSTh31LiftCellMatrix,
        Matrix.one_apply, hQuery, hCellEq, hInput] using hCell
    · have hInput : output ≠ input := by
        intro hEq
        exact hCellEq (congrArg Prod.snd hEq)
      simpa [DFMSTh31LocalNoMatchProjectorMatrix,
        DFMSTh31LocalMatchProjectorMatrix, DFMSTh31LiftCellMatrix,
        Matrix.one_apply, hQuery, hCellEq, hInput] using hCell
  · have hInput : output ≠ input := by
      intro hEq
      exact hQuery (congrArg Prod.fst hEq)
    simp [DFMSTh31LocalNoMatchProjectorMatrix,
      DFMSTh31LocalMatchProjectorMatrix, DFMSTh31LiftCellMatrix,
      hQuery, hInput]

theorem DFMSTh31LocalNoMatchProjectorOperator_eq_one_sub_match
    {n : Nat}
    {X : Type}
    (R : X → DFMSBitVector n → Prop)
    [DecidableRel R]
    (x : X) :
    DFMSTh31LocalNoMatchProjectorOperator R x =
      1 - DFMSTh31LocalMatchProjectorOperator R x := by
  ext vector basis
  rw [DFMSTh31LocalNoMatchProjectorOperator,
    DFMSTh31LocalMatchProjectorOperator]
  simp [DFMSMatrixOperator.toContinuous,
    DFMSTh31LocalNoMatchProjectorMatrix_eq_one_sub_match R x,
    Matrix.ofLp_toEuclideanCLM, Matrix.mulVec]

noncomputable def DFMSTh31CellMatchIndicator
    {n : Nat}
    {X : Type}
    (R : X → DFMSBitVector n → Prop)
    [DecidableRel R]
    (x : X) :
    DFMSTh31CellBasis n → ℂ
  | none => 0
  | some y => if R x y then 1 else 0

noncomputable def DFMSTh31CellFourierBoundaryVector
    {n : Nat}
    {X : Type}
    (R : X → DFMSBitVector n → Prop)
    [DecidableRel R]
    (x : X) :
    DFMSTh31CellBasis n → ℂ
  | none => DFMSTh31InvSqrtHashCardinality n
  | some y => if R x y then 0 else -DFMSTh31InvHashCardinality n

noncomputable def DFMSTh31CellMatchVector
    {n : Nat}
    {X : Type}
    (R : X → DFMSBitVector n → Prop)
    [DecidableRel R]
    (x : X) :
    EuclideanSpace ℂ (DFMSTh31CellBasis n) :=
  WithLp.toLp 2 (DFMSTh31CellMatchIndicator R x)

noncomputable def DFMSTh31CellFourierBoundaryEuclideanVector
    {n : Nat}
    {X : Type}
    (R : X → DFMSBitVector n → Prop)
    [DecidableRel R]
    (x : X) :
    EuclideanSpace ℂ (DFMSTh31CellBasis n) :=
  WithLp.toLp 2 (DFMSTh31CellFourierBoundaryVector R x)

lemma DFMSTh31CellFourierMatchCommutator_entry
    {n : Nat}
    {X : Type}
    (R : X → DFMSBitVector n → Prop)
    [DecidableRel R]
    (x : X)
    (out input : DFMSTh31CellBasis n) :
    (DFMSTh31CellFourierMatrix n *
          DFMSTh31CellMatchProjectorMatrix R x -
        DFMSTh31CellMatchProjectorMatrix R x *
          DFMSTh31CellFourierMatrix n) out input =
      DFMSTh31CellFourierBoundaryVector R x out *
          DFMSTh31CellMatchIndicator R x input -
        DFMSTh31CellMatchIndicator R x out *
          DFMSTh31CellFourierBoundaryVector R x input := by
  classical
  simp only [Matrix.sub_apply, Matrix.mul_apply]
  cases out <;> cases input <;>
    simp [DFMSTh31CellFourierMatrix,
      DFMSTh31CellMatchProjectorMatrix,
      DFMSTh31CellMatchIndicator,
      DFMSTh31CellFourierBoundaryVector]
  all_goals split_ifs <;> simp_all

lemma DFMSTh31CellMatchIndicator_star
    {n : Nat}
    {X : Type}
    (R : X → DFMSBitVector n → Prop)
    [DecidableRel R]
    (x : X)
    (cell : DFMSTh31CellBasis n) :
    star (DFMSTh31CellMatchIndicator R x cell) =
      DFMSTh31CellMatchIndicator R x cell := by
  cases cell <;> simp [DFMSTh31CellMatchIndicator]

lemma DFMSTh31CellFourierBoundaryVector_star
    {n : Nat}
    {X : Type}
    (R : X → DFMSBitVector n → Prop)
    [DecidableRel R]
    (x : X)
    (cell : DFMSTh31CellBasis n) :
    star (DFMSTh31CellFourierBoundaryVector R x cell) =
      DFMSTh31CellFourierBoundaryVector R x cell := by
  cases cell with
  | none =>
      simp [DFMSTh31CellFourierBoundaryVector,
        DFMSTh31InvSqrtHashCardinality, Complex.conj_ofReal]
  | some y =>
      by_cases h : R x y
      · simp [DFMSTh31CellFourierBoundaryVector, h]
      · simp [DFMSTh31CellFourierBoundaryVector, h,
          DFMSTh31InvHashCardinality, Complex.conj_ofReal]

lemma DFMSTh31CellMatchBoundary_inner_zero
    {n : Nat}
    {X : Type}
    (R : X → DFMSBitVector n → Prop)
    [DecidableRel R]
    (x : X) :
    inner ℂ
        (DFMSTh31CellMatchVector R x)
        (DFMSTh31CellFourierBoundaryEuclideanVector R x) = 0 := by
  classical
  rw [DFMSTh31CellMatchVector,
    DFMSTh31CellFourierBoundaryEuclideanVector]
  rw [EuclideanSpace.inner_toLp_toLp]
  simp [dotProduct, DFMSTh31CellMatchIndicator,
    DFMSTh31CellFourierBoundaryVector]
  apply Finset.sum_eq_zero
  intro y _hy
  by_cases h : R x y <;> simp [h]

theorem DFMSTh31CellFourierMatchCommutator_eq_skewRankTwo
    {n : Nat}
    {X : Type}
    (R : X → DFMSBitVector n → Prop)
    [DecidableRel R]
    (x : X) :
    DFMSOperatorCommutator
        (DFMSTh31CellFourierOperator n)
        (DFMSTh31CellMatchProjectorOperator R x) =
      DFMSSkewRankTwoOperator
        (DFMSTh31CellMatchVector R x)
        (DFMSTh31CellFourierBoundaryEuclideanVector R x) := by
  classical
  ext vector basis
  simp only [DFMSOperatorCommutator, DFMSTh31CellFourierOperator,
    DFMSTh31CellMatchProjectorOperator, DFMSMatrixOperator.toContinuous,
    ContinuousLinearMap.sub_apply, ContinuousLinearMap.comp_apply]
  change
      (((Matrix.toEuclideanCLM (n := DFMSTh31CellBasis n) (𝕜 := ℂ)
              (DFMSTh31CellFourierMatrix n))
            ((Matrix.toEuclideanCLM (n := DFMSTh31CellBasis n) (𝕜 := ℂ)
              (DFMSTh31CellMatchProjectorMatrix R x)) vector)).ofLp basis -
        ((Matrix.toEuclideanCLM (n := DFMSTh31CellBasis n) (𝕜 := ℂ)
              (DFMSTh31CellMatchProjectorMatrix R x))
            ((Matrix.toEuclideanCLM (n := DFMSTh31CellBasis n) (𝕜 := ℂ)
              (DFMSTh31CellFourierMatrix n)) vector)).ofLp basis) =
        ((DFMSSkewRankTwoOperator
          (DFMSTh31CellMatchVector R x)
          (DFMSTh31CellFourierBoundaryEuclideanVector R x)) vector).ofLp
          basis
  rw [Matrix.ofLp_toEuclideanCLM, Matrix.ofLp_toEuclideanCLM]
  rw [Matrix.ofLp_toEuclideanCLM, Matrix.ofLp_toEuclideanCLM]
  simp only [Matrix.mulVec_mulVec]
  rw [← Pi.sub_apply]
  rw [← Matrix.sub_mulVec]
  rw [Matrix.mulVec, dotProduct]
  simp_rw [DFMSTh31CellFourierMatchCommutator_entry R x]
  simp only [DFMSSkewRankTwoOperator, DFMSRankOneOperator,
    ContinuousLinearMap.sub_apply, ContinuousLinearMap.smulRight_apply,
    innerSL_apply_apply, DFMSTh31CellMatchVector,
    DFMSTh31CellFourierBoundaryEuclideanVector]
  rw [EuclideanSpace.inner_toLp_toLp,
    EuclideanSpace.inner_toLp_toLp]
  simp only [dotProduct]
  change
      (∑ input,
          (DFMSTh31CellFourierBoundaryVector R x basis *
              DFMSTh31CellMatchIndicator R x input -
            DFMSTh31CellMatchIndicator R x basis *
              DFMSTh31CellFourierBoundaryVector R x input) *
            vector.ofLp input) =
        (∑ input,
            vector.ofLp input *
              star (DFMSTh31CellMatchIndicator R x input)) *
            DFMSTh31CellFourierBoundaryVector R x basis -
          (∑ input,
            vector.ofLp input *
              star (DFMSTh31CellFourierBoundaryVector R x input)) *
            DFMSTh31CellMatchIndicator R x basis
  simp_rw [DFMSTh31CellMatchIndicator_star R x,
    DFMSTh31CellFourierBoundaryVector_star R x]
  simp_rw [sub_mul]
  rw [Finset.sum_sub_distrib]
  simp_rw [mul_assoc]
  rw [← Finset.mul_sum, ← Finset.mul_sum]
  have hsumMatch :
      (∑ input,
        DFMSTh31CellMatchIndicator R x input * vector.ofLp input) =
        ∑ input,
          vector.ofLp input * DFMSTh31CellMatchIndicator R x input := by
    apply Finset.sum_congr rfl
    intro input _hmem
    ring
  have hsumBoundary :
      (∑ input,
        DFMSTh31CellFourierBoundaryVector R x input *
          vector.ofLp input) =
        ∑ input,
          vector.ofLp input *
            DFMSTh31CellFourierBoundaryVector R x input := by
    apply Finset.sum_congr rfl
    intro input _hmem
    ring
  rw [hsumMatch, hsumBoundary]
  ring

theorem DFMSTh31CellFourierMatchCommutator_rankTwoExactNorm
    {n : Nat}
    {X : Type}
    (R : X → DFMSBitVector n → Prop)
    [DecidableRel R]
    (x : X) :
    DFMSOperatorNorm
      (DFMSOperatorCommutator
        (DFMSTh31CellFourierOperator n)
        (DFMSTh31CellMatchProjectorOperator R x)) =
      ‖DFMSTh31CellMatchVector R x‖ *
        ‖DFMSTh31CellFourierBoundaryEuclideanVector R x‖ := by
  unfold DFMSOperatorNorm
  rw [DFMSTh31CellFourierMatchCommutator_eq_skewRankTwo R x]
  exact DFMSSkewRankTwoOperator_norm_eq
    (DFMSTh31CellMatchVector R x)
    (DFMSTh31CellFourierBoundaryEuclideanVector R x)
    (DFMSTh31CellMatchBoundary_inner_zero R x)

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

lemma dfmsTh31_invHashCardinality_norm_sq
    (n : Nat) :
    ‖DFMSTh31InvHashCardinality n‖ ^ 2 =
      (1 : ℝ) / (((2 : ℝ) ^ n) ^ 2) := by
  rw [← Complex.normSq_eq_norm_sq]
  simp [DFMSTh31InvHashCardinality, DFMSTh31HashCardinalityReal,
    div_eq_mul_inv]
  symm
  calc
    ((2 : ℝ) ^ n) ^ 2 = (2 : ℝ) ^ (n * 2) := by rw [pow_mul]
    _ = (2 : ℝ) ^ (2 * n) := by rw [Nat.mul_comm]
    _ = ((2 : ℝ) ^ 2) ^ n := by rw [pow_mul]
    _ = ((2 : ℝ) * 2) ^ n := by rw [pow_two]

lemma dfmsTh31_invSqrtHashCardinality_norm_sq
    (n : Nat) :
    ‖DFMSTh31InvSqrtHashCardinality n‖ ^ 2 =
      (1 : ℝ) / ((2 : ℝ) ^ n) := by
  rw [← Complex.normSq_eq_norm_sq]
  simp [DFMSTh31InvSqrtHashCardinality,
    DFMSTh31HashCardinalityReal, Complex.normSq_ofReal, div_eq_mul_inv]

theorem dfmsTh31_gammaX_le_hashCardinality
    {n : Nat}
    {X : Type} [Fintype X] [DecidableEq X]
    (R : X → DFMSBitVector n → Prop)
    [DecidableRel R]
    (x : X) :
    DFMSTh31GammaX R x ≤ 2 ^ n := by
  calc
    DFMSTh31GammaX R x ≤ Fintype.card (DFMSBitVector n) := by
      unfold DFMSTh31GammaX
      simpa using
        Finset.card_filter_le
          (Finset.univ : Finset (DFMSBitVector n))
          (fun y => R x y)
    _ = 2 ^ n := dfmsBitVector_card n

lemma DFMSTh31CellMatchVector_norm_sq
    {n : Nat}
    {X : Type} [Fintype X] [DecidableEq X]
    (R : X → DFMSBitVector n → Prop)
    [DecidableRel R]
    (x : X) :
    ‖(DFMSTh31CellMatchVector R x :
        EuclideanSpace ℂ (DFMSTh31CellBasis n))‖ ^ 2 =
      (DFMSTh31GammaX R x : ℝ) := by
  rw [DFMSTh31CellMatchVector]
  rw [EuclideanSpace.norm_sq_eq]
  simp [DFMSTh31CellMatchIndicator]
  rw [DFMSTh31GammaX, Finset.card_filter]
  rw [Nat.cast_sum]
  apply Finset.sum_congr rfl
  intro y _hy
  by_cases h : R x y <;> simp [h]

lemma DFMSTh31CellFourierBoundary_nonmatch_norm_sum
    {n : Nat}
    {X : Type} [Fintype X] [DecidableEq X]
    (R : X → DFMSBitVector n → Prop)
    [DecidableRel R]
    (x : X) :
    (∑ y : DFMSBitVector n,
        ‖(if R x y then (0 : ℂ)
          else -DFMSTh31InvHashCardinality n)‖ ^ 2) =
      ((Fintype.card (DFMSBitVector n) - DFMSTh31GammaX R x : Nat) : ℝ) /
        (((2 : ℝ) ^ n) ^ 2) := by
  have hfilter :
      ((Finset.univ : Finset (DFMSBitVector n)).filter
          (fun y => ¬ R x y)).card =
        Fintype.card (DFMSBitVector n) - DFMSTh31GammaX R x := by
    rw [DFMSTh31GammaX]
    rw [← Finset.card_compl
      ((Finset.univ : Finset (DFMSBitVector n)).filter
        (fun y => R x y))]
    congr 1
    ext y
    simp
  calc
    (∑ y : DFMSBitVector n,
        ‖(if R x y then (0 : ℂ)
          else -DFMSTh31InvHashCardinality n)‖ ^ 2) =
        ∑ y ∈ (Finset.univ : Finset (DFMSBitVector n)) with ¬ R x y,
          ((1 : ℝ) / (((2 : ℝ) ^ n) ^ 2)) := by
      rw [Finset.sum_filter]
      apply Finset.sum_congr rfl
      intro y _hy
      by_cases h : R x y <;>
        simp [h, dfmsTh31_invHashCardinality_norm_sq n]
    _ =
        (((Finset.univ : Finset (DFMSBitVector n)).filter
          (fun y => ¬ R x y)).card : ℝ) *
          ((1 : ℝ) / (((2 : ℝ) ^ n) ^ 2)) := by
      rw [Finset.sum_const, nsmul_eq_mul]
    _ =
        ((Fintype.card (DFMSBitVector n) -
            DFMSTh31GammaX R x : Nat) : ℝ) /
          (((2 : ℝ) ^ n) ^ 2) := by
      rw [hfilter]
      ring

lemma DFMSTh31CellFourierBoundary_norm_sq_count
    {n : Nat}
    {X : Type} [Fintype X] [DecidableEq X]
    (R : X → DFMSBitVector n → Prop)
    [DecidableRel R]
    (x : X) :
    ‖(DFMSTh31CellFourierBoundaryEuclideanVector R x :
        EuclideanSpace ℂ (DFMSTh31CellBasis n))‖ ^ 2 =
      (1 : ℝ) / ((2 : ℝ) ^ n) +
        ((2 ^ n - DFMSTh31GammaX R x : Nat) : ℝ) /
          (((2 : ℝ) ^ n) ^ 2) := by
  rw [DFMSTh31CellFourierBoundaryEuclideanVector]
  rw [EuclideanSpace.norm_sq_eq]
  simp [DFMSTh31CellFourierBoundaryVector,
    dfmsTh31_invSqrtHashCardinality_norm_sq n]
  simpa [dfmsBitVector_card n] using
    DFMSTh31CellFourierBoundary_nonmatch_norm_sum R x

lemma DFMSTh31CellFourierBoundary_norm_sq
    {n : Nat}
    {X : Type} [Fintype X] [DecidableEq X]
    (R : X → DFMSBitVector n → Prop)
    [DecidableRel R]
    (x : X) :
    ‖(DFMSTh31CellFourierBoundaryEuclideanVector R x :
        EuclideanSpace ℂ (DFMSTh31CellBasis n))‖ ^ 2 =
      (2 : ℝ) / ((2 : ℝ) ^ n) -
        (DFMSTh31GammaX R x : ℝ) / (((2 : ℝ) ^ n) ^ 2) := by
  rw [DFMSTh31CellFourierBoundary_norm_sq_count R x]
  have hpowpos : (0 : ℝ) < (2 : ℝ) ^ n := by positivity
  rw [Nat.cast_sub (dfmsTh31_gammaX_le_hashCardinality R x)]
  rw [Nat.cast_pow]
  field_simp [ne_of_gt hpowpos]
  ring

theorem DFMSTh31CellFourierMatchCommutator_exactNorm
    {n : Nat}
    {X : Type} [Fintype X] [DecidableEq X]
    (R : X → DFMSBitVector n → Prop)
    [DecidableRel R]
    (x : X) :
    DFMSOperatorNorm
      (DFMSOperatorCommutator
        (DFMSTh31CellFourierOperator n)
        (DFMSTh31CellMatchProjectorOperator R x)) =
      DFMSTh31ExactFourierProjectorTerm
        n
        (DFMSTh31GammaX R x) := by
  rw [DFMSTh31CellFourierMatchCommutator_rankTwoExactNorm R x]
  unfold DFMSTh31ExactFourierProjectorTerm
  let u : EuclideanSpace ℂ (DFMSTh31CellBasis n) :=
    DFMSTh31CellMatchVector R x
  let v : EuclideanSpace ℂ (DFMSTh31CellBasis n) :=
    DFMSTh31CellFourierBoundaryEuclideanVector R x
  have hprodSq :
      (‖u‖ * ‖v‖) ^ 2 =
        (((2 : ℝ) * (DFMSTh31GammaX R x : ℝ)) / ((2 : ℝ) ^ n)) -
          (((DFMSTh31GammaX R x : ℝ) ^ 2) /
            (((2 : ℝ) ^ n) ^ 2)) := by
    rw [mul_pow]
    rw [show ‖u‖ ^ 2 =
        (DFMSTh31GammaX R x : ℝ) by
      simpa [u] using DFMSTh31CellMatchVector_norm_sq R x]
    rw [show ‖v‖ ^ 2 =
        (2 : ℝ) / ((2 : ℝ) ^ n) -
          (DFMSTh31GammaX R x : ℝ) /
            (((2 : ℝ) ^ n) ^ 2) by
      simpa [v] using DFMSTh31CellFourierBoundary_norm_sq R x]
    ring
  have hRadNonneg :
      0 ≤
        (((2 : ℝ) * (DFMSTh31GammaX R x : ℝ)) / ((2 : ℝ) ^ n)) -
          (((DFMSTh31GammaX R x : ℝ) ^ 2) /
            (((2 : ℝ) ^ n) ^ 2)) := by
    rw [← hprodSq]
    exact sq_nonneg _
  rw [← (sq_eq_sq₀
    (mul_nonneg (norm_nonneg u) (norm_nonneg v))
    (Real.sqrt_nonneg _))]
  rw [hprodSq, Real.sq_sqrt hRadNonneg]

def DFMSTh31FourierProjectorExactNorm
    (n gammaX : Nat)
    (fourier matchProjector :
      DFMSContinuousOperator (DFMSTh31LocalQueryBasis n)) : Prop :=
  DFMSOperatorNorm
      (DFMSOperatorCommutator fourier matchProjector)
    = DFMSTh31ExactFourierProjectorTerm n gammaX

theorem DFMSTh31LocalFourierMatchCommutator_exactNorm
    {n : Nat}
    {X : Type} [Fintype X] [DecidableEq X]
    (R : X → DFMSBitVector n → Prop)
    [DecidableRel R]
    (x : X) :
    DFMSTh31FourierProjectorExactNorm
      n
      (DFMSTh31GammaX R x)
      (DFMSTh31LocalFourierOperator n)
      (DFMSTh31LocalMatchProjectorOperator R x) := by
  unfold DFMSTh31FourierProjectorExactNorm
  rw [DFMSTh31LocalFourierMatchCommutator_lift R x]
  rw [DFMSTh31LiftCellOperator_norm_eq]
  rw [← DFMSMatrixOperator.toContinuous_commutator]
  exact DFMSTh31CellFourierMatchCommutator_exactNorm R x

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

theorem DFMSOperatorCommutator.factorTwo_of_FEF
    {A : Type} [Fintype A]
    (fourier evaluation projector :
      DFMSContinuousOperator A)
    (hEvaluationCommutes :
      DFMSOperatorCommutator evaluation projector = 0)
    (hFourierContractive : ‖fourier‖ ≤ 1)
    (hEvaluationContractive : ‖evaluation‖ ≤ 1) :
    DFMSOperatorNorm
        (DFMSOperatorCommutator
          (fourier.comp (evaluation.comp fourier))
          projector) ≤
      2 *
        DFMSOperatorNorm
          (DFMSOperatorCommutator fourier projector) := by
  let commutator : DFMSContinuousOperator A :=
    DFMSOperatorCommutator fourier projector
  have hIdentity :
      DFMSOperatorCommutator
          (fourier.comp (evaluation.comp fourier))
          projector =
        fourier.comp (evaluation.comp commutator) +
          commutator.comp (evaluation.comp fourier) := by
    have hEvaluationProjector :
        evaluation.comp projector = projector.comp evaluation :=
      sub_eq_zero.mp hEvaluationCommutes
    ext vector basis
    have hEvaluationProjector_apply :
        evaluation (projector (fourier vector)) =
          projector (evaluation (fourier vector)) := by
      simpa [ContinuousLinearMap.comp_apply] using
        congrFun
          (congrArg DFunLike.coe hEvaluationProjector)
          (fourier vector)
    simp only [DFMSOperatorCommutator, commutator,
      ContinuousLinearMap.sub_apply, ContinuousLinearMap.comp_apply,
      ContinuousLinearMap.add_apply]
    simp [map_sub]
    rw [hEvaluationProjector_apply]
    abel
  unfold DFMSOperatorNorm
  rw [hIdentity]
  have hCommutatorNonneg : 0 ≤ ‖commutator‖ := norm_nonneg _
  have hFourierNonneg : 0 ≤ ‖fourier‖ := norm_nonneg _
  have hEvaluationNonneg : 0 ≤ ‖evaluation‖ := norm_nonneg _
  have hEvaluationCommutator :
      ‖evaluation.comp commutator‖ ≤
        ‖evaluation‖ * ‖commutator‖ :=
    ContinuousLinearMap.opNorm_comp_le evaluation commutator
  have hEvaluationFourier :
      ‖evaluation.comp fourier‖ ≤
        ‖evaluation‖ * ‖fourier‖ :=
    ContinuousLinearMap.opNorm_comp_le evaluation fourier
  have hLeft :
      ‖fourier.comp (evaluation.comp commutator)‖ ≤
        ‖fourier‖ * (‖evaluation‖ * ‖commutator‖) := by
    exact
      (ContinuousLinearMap.opNorm_comp_le
          fourier
          (evaluation.comp commutator)).trans
        (mul_le_mul_of_nonneg_left
          hEvaluationCommutator
          hFourierNonneg)
  have hRight :
      ‖commutator.comp (evaluation.comp fourier)‖ ≤
        ‖commutator‖ * (‖evaluation‖ * ‖fourier‖) := by
    exact
      (ContinuousLinearMap.opNorm_comp_le
          commutator
          (evaluation.comp fourier)).trans
        (mul_le_mul_of_nonneg_left
          hEvaluationFourier
          hCommutatorNonneg)
  calc
    ‖fourier.comp (evaluation.comp commutator) +
        commutator.comp (evaluation.comp fourier)‖ ≤
        ‖fourier.comp (evaluation.comp commutator)‖ +
          ‖commutator.comp (evaluation.comp fourier)‖ :=
      norm_add_le _ _
    _ ≤
        ‖fourier‖ * (‖evaluation‖ * ‖commutator‖) +
          ‖commutator‖ * (‖evaluation‖ * ‖fourier‖) := by
      exact add_le_add hLeft hRight
    _ ≤ 2 * ‖commutator‖ := by
      have hFourierEvaluation :
          ‖fourier‖ * ‖evaluation‖ ≤ 1 := by
        simpa using
          mul_le_mul
            hFourierContractive
            hEvaluationContractive
            hEvaluationNonneg
            zero_le_one
      have hScaled :
          ‖fourier‖ * ‖evaluation‖ * ‖commutator‖ ≤
            1 * ‖commutator‖ :=
        mul_le_mul_of_nonneg_right
          hFourierEvaluation
          hCommutatorNonneg
      nlinarith

theorem DFMSTh31LocalOracleProjectorFactorTwo.of_FEF
    (n : Nat)
    (fourier evaluation localOracle matchProjector :
      DFMSContinuousOperator (DFMSTh31LocalQueryBasis n))
    (hOracle :
      localOracle = fourier.comp (evaluation.comp fourier))
    (hEvaluationCommutes :
      DFMSOperatorCommutator evaluation matchProjector = 0)
    (hFourierContractive : ‖fourier‖ ≤ 1)
    (hEvaluationContractive : ‖evaluation‖ ≤ 1) :
    DFMSTh31LocalOracleProjectorFactorTwo
      n fourier localOracle matchProjector := by
  unfold DFMSTh31LocalOracleProjectorFactorTwo
  rw [hOracle]
  exact
    DFMSOperatorCommutator.factorTwo_of_FEF
      fourier
      evaluation
      matchProjector
      hEvaluationCommutes
      hFourierContractive
      hEvaluationContractive

theorem DFMSTh31LocalOracleProjectorFactorTwo.concrete_of_fourierContractive
    {n : Nat}
    {X : Type}
    (R : X → DFMSBitVector n → Prop)
    [DecidableRel R]
    (x : X)
    (hFourierContractive :
      ‖DFMSTh31LocalFourierOperator n‖ ≤ 1) :
    DFMSTh31LocalOracleProjectorFactorTwo
      n
      (DFMSTh31LocalFourierOperator n)
      (DFMSTh31LocalOracleOperator n)
      (DFMSTh31LocalMatchProjectorOperator R x) :=
  DFMSTh31LocalOracleProjectorFactorTwo.of_FEF
    n
    (DFMSTh31LocalFourierOperator n)
    (DFMSTh31LocalEvaluationOperator n)
    (DFMSTh31LocalOracleOperator n)
    (DFMSTh31LocalMatchProjectorOperator R x)
    (DFMSTh31LocalOracleOperator_eq_FEF n)
    (DFMSTh31LocalEvaluationOperator_commutes_matchProjector R x)
    hFourierContractive
    (DFMSTh31LocalEvaluationOperator_norm_le_one n)

theorem DFMSTh31LocalOracleProjectorFactorTwo.concrete_of_cellFourierContractive
    {n : Nat}
    {X : Type}
    (R : X → DFMSBitVector n → Prop)
    [DecidableRel R]
    (x : X)
    (hCellFourierContractive :
      ‖DFMSTh31CellFourierOperator n‖ ≤ 1) :
    DFMSTh31LocalOracleProjectorFactorTwo
      n
      (DFMSTh31LocalFourierOperator n)
      (DFMSTh31LocalOracleOperator n)
      (DFMSTh31LocalMatchProjectorOperator R x) :=
  DFMSTh31LocalOracleProjectorFactorTwo.concrete_of_fourierContractive
    R
    x
    (by
      rw [DFMSTh31LocalFourierOperator_norm_eq_cell n]
      exact hCellFourierContractive)

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

theorem DFMSOperatorCommutator.eq_neg_of_right_complement
    {A : Type} [Fintype A]
    (operator projector complement : DFMSContinuousOperator A)
    (hComplement : complement = 1 - projector) :
    DFMSOperatorCommutator operator complement =
      -DFMSOperatorCommutator operator projector := by
  subst hComplement
  ext vector
  simp [DFMSOperatorCommutator, sub_eq_add_neg, add_comm, add_left_comm,
    add_assoc]

theorem DFMSOperatorCommutator.norm_eq_of_right_complement
    {A : Type} [Fintype A]
    (operator projector complement : DFMSContinuousOperator A)
    (hComplement : complement = 1 - projector) :
    DFMSOperatorNorm
        (DFMSOperatorCommutator operator complement) =
      DFMSOperatorNorm
        (DFMSOperatorCommutator operator projector) := by
  rw [DFMSOperatorCommutator.eq_neg_of_right_complement
    operator projector complement hComplement]
  change ‖(-DFMSOperatorCommutator operator projector)‖ =
    ‖DFMSOperatorCommutator operator projector‖
  exact norm_neg _

theorem DFMSTh31NoMatchProjectorReduction.of_complement
    (n : Nat)
    (localOracle matchProjector noMatchProjector :
      DFMSContinuousOperator (DFMSTh31LocalQueryBasis n))
    (hComplement : noMatchProjector = 1 - matchProjector) :
    DFMSTh31NoMatchProjectorReduction
      n localOracle matchProjector noMatchProjector := by
  unfold DFMSTh31NoMatchProjectorReduction
  exact le_of_eq
    (DFMSOperatorCommutator.norm_eq_of_right_complement
      localOracle matchProjector noMatchProjector hComplement)

theorem DFMSTh31NoMatchProjectorReduction.concrete
    {n : Nat}
    {X : Type}
    (R : X → DFMSBitVector n → Prop)
    [DecidableRel R]
    (x : X) :
    DFMSTh31NoMatchProjectorReduction
      n
      (DFMSTh31LocalOracleOperator n)
      (DFMSTh31LocalMatchProjectorOperator R x)
      (DFMSTh31LocalNoMatchProjectorOperator R x) :=
  DFMSTh31NoMatchProjectorReduction.of_complement
    n
    (DFMSTh31LocalOracleOperator n)
    (DFMSTh31LocalMatchProjectorOperator R x)
    (DFMSTh31LocalNoMatchProjectorOperator R x)
    (DFMSTh31LocalNoMatchProjectorOperator_eq_one_sub_match R x)

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
  localNoMatchProjectorComplement :
    ∀ x,
      localNoMatchProjector x = 1 - localMatchProjector x
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

theorem DFMSTh31AnalyticProof.noMatchProjectorReduction
    {n : Nat}
    {X : Type} [Fintype X] [DecidableEq X]
    {R : X → DFMSBitVector n → Prop} [DecidableRel R]
    {operatorModel : DFMSTh31OperatorModel n X}
    (analytic : DFMSTh31AnalyticProof n X R operatorModel)
    (x : X) :
    DFMSTh31NoMatchProjectorReduction
      n
      (analytic.localOracle x)
      (analytic.localMatchProjector x)
      (analytic.localNoMatchProjector x) :=
  DFMSTh31NoMatchProjectorReduction.of_complement
    n
    (analytic.localOracle x)
    (analytic.localMatchProjector x)
    (analytic.localNoMatchProjector x)
    (analytic.localNoMatchProjectorComplement x)

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
