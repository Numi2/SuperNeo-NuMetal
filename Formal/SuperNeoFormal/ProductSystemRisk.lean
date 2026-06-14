import SuperNeoFormal.ProductSecurityTheorem

/-!
System-risk composition around the ideal SplitQRO product theorem.

The core product theorem stays an ideal-model cryptographic statement.  This
module records the separate wrapper shape for concrete-hash transfer and
artifact/provenance/pinning trust assumptions: each residual term is numeric
and budgeted, not a free acceptance flag.
-/

namespace SuperNeoFormal

inductive ProductHashClaimMode where
  | idealOnly
  | realAssumedGap
  | realProvedGap
  deriving DecidableEq, Repr

structure ProductHashModelTransferCertificate where
  claimMode : ProductHashClaimMode
  idealSplitQROModel : ProductIdealSplitQROModel
  hashModelGap : ProductHashModelGapCertificate
  idealOnlyConcreteGapZero :
    claimMode = ProductHashClaimMode.idealOnly →
      hashModelGap.concreteModelGap.value = 0
  realModeGapBounded :
    claimMode ≠ ProductHashClaimMode.idealOnly →
      ProductNumericLossTermAccepted hashModelGap.concreteModelGap

def ProductHashModelTransferCertificateAccepted
    (certificate : ProductHashModelTransferCertificate) : Prop :=
  ProductIdealSplitQROModelAccepted certificate.idealSplitQROModel
    ∧ ProductHashModelGapCertificateAccepted certificate.hashModelGap
    ∧ (certificate.claimMode = ProductHashClaimMode.idealOnly →
      certificate.hashModelGap.concreteModelGap.value = 0)
    ∧ (certificate.claimMode ≠ ProductHashClaimMode.idealOnly →
      ProductNumericLossTermAccepted
        certificate.hashModelGap.concreteModelGap)

theorem ProductHashModelTransferCertificate.accepted
    (certificate : ProductHashModelTransferCertificate) :
    ProductHashModelTransferCertificateAccepted certificate :=
  ⟨certificate.idealSplitQROModel.accepted,
    certificate.hashModelGap.accepted,
    certificate.idealOnlyConcreteGapZero,
    certificate.realModeGapBounded⟩

inductive ProductBindingObjectType where
  | artifact
  | system
  | implementation
  | parameters
  | hashModel
  | theoremStatement
  | environment
  deriving DecidableEq, Fintype, Repr

def ProductBindingObjectTypeCount : Nat :=
  Fintype.card ProductBindingObjectType

theorem productBindingObjectTypeCount_eq_seven :
    ProductBindingObjectTypeCount = 7 := by
  native_decide

def ProductBindingCollisionMultiplier : Nat :=
  ProductBindingObjectTypeCount + 1

theorem productBindingCollisionMultiplier_eq_eight :
    ProductBindingCollisionMultiplier = 8 := by
  rw [ProductBindingCollisionMultiplier,
    productBindingObjectTypeCount_eq_seven]

structure ProductFullSystemRiskTerms where
  idealSplitQROMProof : ProductNumericLossTerm
  onlineExtraction : ProductNumericLossTerm
  hashModelGap : ProductNumericLossTerm
  signatureForgery : ProductNumericLossTerm
  typedAndManifestHashCollision : ProductNumericLossTerm
  attesterTrust : ProductNumericLossTerm
  transparencyLog : ProductNumericLossTerm
  policyCorrectness : ProductNumericLossTerm
  runtimeMeasurement : ProductNumericLossTerm
  sourceResolver : ProductNumericLossTerm
  reproducibility : ProductNumericLossTerm
  canonicalization : ProductNumericLossTerm

def ProductFullSystemRiskTerms.valueTotal
    (terms : ProductFullSystemRiskTerms) : ℚ :=
  terms.idealSplitQROMProof.value
    + terms.onlineExtraction.value
    + terms.hashModelGap.value
    + terms.signatureForgery.value
    + terms.typedAndManifestHashCollision.value
    + terms.attesterTrust.value
    + terms.transparencyLog.value
    + terms.policyCorrectness.value
    + terms.runtimeMeasurement.value
    + terms.sourceResolver.value
    + terms.reproducibility.value
    + terms.canonicalization.value

def ProductFullSystemRiskTerms.budgetTotal
    (terms : ProductFullSystemRiskTerms) : ℚ :=
  terms.idealSplitQROMProof.budget
    + terms.onlineExtraction.budget
    + terms.hashModelGap.budget
    + terms.signatureForgery.budget
    + terms.typedAndManifestHashCollision.budget
    + terms.attesterTrust.budget
    + terms.transparencyLog.budget
    + terms.policyCorrectness.budget
    + terms.runtimeMeasurement.budget
    + terms.sourceResolver.budget
    + terms.reproducibility.budget
    + terms.canonicalization.budget

def ProductFullSystemRiskTermsAccepted
    (terms : ProductFullSystemRiskTerms) : Prop :=
  ProductNumericLossTermAccepted terms.idealSplitQROMProof
    ∧ ProductNumericLossTermAccepted terms.onlineExtraction
    ∧ ProductNumericLossTermAccepted terms.hashModelGap
    ∧ ProductNumericLossTermAccepted terms.signatureForgery
    ∧ ProductNumericLossTermAccepted
      terms.typedAndManifestHashCollision
    ∧ ProductNumericLossTermAccepted terms.attesterTrust
    ∧ ProductNumericLossTermAccepted terms.transparencyLog
    ∧ ProductNumericLossTermAccepted terms.policyCorrectness
    ∧ ProductNumericLossTermAccepted terms.runtimeMeasurement
    ∧ ProductNumericLossTermAccepted terms.sourceResolver
    ∧ ProductNumericLossTermAccepted terms.reproducibility
    ∧ ProductNumericLossTermAccepted terms.canonicalization

theorem ProductFullSystemRiskTerms.accepted
    (terms : ProductFullSystemRiskTerms) :
    ProductFullSystemRiskTermsAccepted terms :=
  ⟨terms.idealSplitQROMProof.accepted,
    terms.onlineExtraction.accepted,
    terms.hashModelGap.accepted,
    terms.signatureForgery.accepted,
    terms.typedAndManifestHashCollision.accepted,
    terms.attesterTrust.accepted,
    terms.transparencyLog.accepted,
    terms.policyCorrectness.accepted,
    terms.runtimeMeasurement.accepted,
    terms.sourceResolver.accepted,
    terms.reproducibility.accepted,
    terms.canonicalization.accepted⟩

theorem ProductFullSystemRiskTerms.valueTotal_le_budgetTotal
    (terms : ProductFullSystemRiskTerms) :
    terms.valueTotal ≤ terms.budgetTotal := by
  unfold ProductFullSystemRiskTerms.valueTotal
  unfold ProductFullSystemRiskTerms.budgetTotal
  linarith
    [terms.idealSplitQROMProof.withinBudget,
      terms.onlineExtraction.withinBudget,
      terms.hashModelGap.withinBudget,
      terms.signatureForgery.withinBudget,
      terms.typedAndManifestHashCollision.withinBudget,
      terms.attesterTrust.withinBudget,
      terms.transparencyLog.withinBudget,
      terms.policyCorrectness.withinBudget,
      terms.runtimeMeasurement.withinBudget,
      terms.sourceResolver.withinBudget,
      terms.reproducibility.withinBudget,
      terms.canonicalization.withinBudget]

structure ProductFullSystemRiskCertificate where
  terms : ProductFullSystemRiskTerms
  totalLoss : ProductNumericLossTerm
  totalLossValue_eq : totalLoss.value = terms.valueTotal
  totalLossBudget_eq : totalLoss.budget = terms.budgetTotal

def ProductFullSystemRiskCertificateAccepted
    (certificate : ProductFullSystemRiskCertificate) : Prop :=
  ProductFullSystemRiskTermsAccepted certificate.terms
    ∧ ProductNumericLossTermAccepted certificate.totalLoss
    ∧ certificate.totalLoss.value =
      certificate.terms.valueTotal
    ∧ certificate.totalLoss.budget =
      certificate.terms.budgetTotal
    ∧ certificate.terms.valueTotal ≤
      certificate.terms.budgetTotal

theorem ProductFullSystemRiskCertificate.accepted
    (certificate : ProductFullSystemRiskCertificate) :
    ProductFullSystemRiskCertificateAccepted certificate :=
  ⟨certificate.terms.accepted,
    certificate.totalLoss.accepted,
    certificate.totalLossValue_eq,
    certificate.totalLossBudget_eq,
    certificate.terms.valueTotal_le_budgetTotal⟩

theorem productFullSystemRiskBound
    (certificate : ProductFullSystemRiskCertificate) :
    ProductFullSystemRiskCertificateAccepted certificate
      ∧ certificate.totalLoss.value =
        certificate.terms.valueTotal
      ∧ certificate.terms.valueTotal ≤
        certificate.terms.budgetTotal :=
  ⟨certificate.accepted,
    certificate.totalLossValue_eq,
    certificate.terms.valueTotal_le_budgetTotal⟩

end SuperNeoFormal
