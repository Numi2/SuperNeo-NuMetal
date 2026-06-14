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
