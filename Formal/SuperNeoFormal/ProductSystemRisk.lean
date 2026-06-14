import SuperNeoFormal.ProductSecurityTheorem
import SuperNeoFormal.TypedDigestSemantics

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

inductive ProductAttestationRole where
  | builder
  | sourceResolver
  | reproducibility
  | runtimeMeasurement
  | transparencyLog
  deriving DecidableEq, Fintype, Repr

def productAttestationRoleEncode : ProductAttestationRole → Byte
  | .builder => byteOfNat 64 (by native_decide)
  | .sourceResolver => byteOfNat 65 (by native_decide)
  | .reproducibility => byteOfNat 66 (by native_decide)
  | .runtimeMeasurement => byteOfNat 67 (by native_decide)
  | .transparencyLog => byteOfNat 68 (by native_decide)

theorem productAttestationRoleEncode_injective :
    Function.Injective productAttestationRoleEncode := by
  intro lhs rhs h
  cases lhs <;> cases rhs <;>
    simp [productAttestationRoleEncode, byteOfNat] at h ⊢

structure ProductProvenanceManifest where
  artifactDigest : TypedDigest384Wire
  provenanceDigest : TypedDigest384Wire
  replayDigest : TypedDigest384Wire
  componentRootDigest : TypedDigest384Wire
  randomnessSessionDigest : TypedDigest384Wire
  leakageDigest : TypedDigest384Wire
  carryDigest : TypedDigest384Wire
  artifactDomain :
    artifactDigest.domain = TypedDigestDomainFamily.artifact
  provenanceDomain :
    provenanceDigest.domain = TypedDigestDomainFamily.provenance
  replayDomain :
    replayDigest.domain = TypedDigestDomainFamily.replay
  componentRootDomain :
    componentRootDigest.domain = TypedDigestDomainFamily.componentRoot
  randomnessSessionDomain :
    randomnessSessionDigest.domain =
      TypedDigestDomainFamily.randomnessSession
  leakageDomain :
    leakageDigest.domain = TypedDigestDomainFamily.leakage
  carryDomain :
    carryDigest.domain = TypedDigestDomainFamily.carry

def ProductProvenanceManifestWellTyped
    (manifest : ProductProvenanceManifest) : Prop :=
  manifest.artifactDigest.domain = TypedDigestDomainFamily.artifact
    ∧ manifest.provenanceDigest.domain =
      TypedDigestDomainFamily.provenance
    ∧ manifest.replayDigest.domain = TypedDigestDomainFamily.replay
    ∧ manifest.componentRootDigest.domain =
      TypedDigestDomainFamily.componentRoot
    ∧ manifest.randomnessSessionDigest.domain =
      TypedDigestDomainFamily.randomnessSession
    ∧ manifest.leakageDigest.domain = TypedDigestDomainFamily.leakage
    ∧ manifest.carryDigest.domain = TypedDigestDomainFamily.carry

theorem ProductProvenanceManifest.wellTyped
    (manifest : ProductProvenanceManifest) :
    ProductProvenanceManifestWellTyped manifest :=
  ⟨manifest.artifactDomain,
    manifest.provenanceDomain,
    manifest.replayDomain,
    manifest.componentRootDomain,
    manifest.randomnessSessionDomain,
    manifest.leakageDomain,
    manifest.carryDomain⟩

def productProvenanceManifestEncode
    (manifest : ProductProvenanceManifest) : List Byte :=
  typedDigest384Encode manifest.artifactDigest ++
    typedDigest384Encode manifest.provenanceDigest ++
    typedDigest384Encode manifest.replayDigest ++
    typedDigest384Encode manifest.componentRootDigest ++
    typedDigest384Encode manifest.randomnessSessionDigest ++
    typedDigest384Encode manifest.leakageDigest ++
    typedDigest384Encode manifest.carryDigest

theorem productProvenanceManifestEncode_length
    (manifest : ProductProvenanceManifest) :
    (productProvenanceManifestEncode manifest).length = 343 := by
  simp [productProvenanceManifestEncode, typedDigest384Encode_length]

def productAttestationMessage
    (role : ProductAttestationRole)
    (manifest : ProductProvenanceManifest) : List Byte :=
  [productAttestationRoleEncode role] ++
    productProvenanceManifestEncode manifest

theorem productAttestationMessage_length
    (role : ProductAttestationRole)
    (manifest : ProductProvenanceManifest) :
    (productAttestationMessage role manifest).length = 344 := by
  simp [productAttestationMessage,
    productProvenanceManifestEncode_length]

structure ProductProvenanceVerificationBundle where
  manifest : ProductProvenanceManifest
  builderMessage : List Byte
  sourceResolverMessage : List Byte
  reproducibilityMessage : List Byte
  runtimeMeasurementMessage : List Byte
  transparencyLogMessage : List Byte
  builderMessage_eq :
    builderMessage =
      productAttestationMessage .builder manifest
  sourceResolverMessage_eq :
    sourceResolverMessage =
      productAttestationMessage .sourceResolver manifest
  reproducibilityMessage_eq :
    reproducibilityMessage =
      productAttestationMessage .reproducibility manifest
  runtimeMeasurementMessage_eq :
    runtimeMeasurementMessage =
      productAttestationMessage .runtimeMeasurement manifest
  transparencyLogMessage_eq :
    transparencyLogMessage =
      productAttestationMessage .transparencyLog manifest

def ProductProvenanceVerificationBundleAccepted
    (bundle : ProductProvenanceVerificationBundle) : Prop :=
  ProductProvenanceManifestWellTyped bundle.manifest
    ∧ bundle.builderMessage =
      productAttestationMessage .builder bundle.manifest
    ∧ bundle.sourceResolverMessage =
      productAttestationMessage .sourceResolver bundle.manifest
    ∧ bundle.reproducibilityMessage =
      productAttestationMessage .reproducibility bundle.manifest
    ∧ bundle.runtimeMeasurementMessage =
      productAttestationMessage .runtimeMeasurement bundle.manifest
    ∧ bundle.transparencyLogMessage =
      productAttestationMessage .transparencyLog bundle.manifest

theorem ProductProvenanceVerificationBundle.accepted
    (bundle : ProductProvenanceVerificationBundle) :
    ProductProvenanceVerificationBundleAccepted bundle :=
  ⟨bundle.manifest.wellTyped,
    bundle.builderMessage_eq,
    bundle.sourceResolverMessage_eq,
    bundle.reproducibilityMessage_eq,
    bundle.runtimeMeasurementMessage_eq,
    bundle.transparencyLogMessage_eq⟩

def ProductZeroNumericLossTerm : ProductNumericLossTerm where
  value := 0
  budget := 0
  nonnegative := by norm_num
  withinBudget := by norm_num

def ProductScaledNumericLossTerm
    (left right : Nat)
    (term : ProductNumericLossTerm) : ProductNumericLossTerm where
  value := ((left : ℚ) * (right : ℚ)) * term.value
  budget := ((left : ℚ) * (right : ℚ)) * term.budget
  nonnegative := by
    exact mul_nonneg
      (mul_nonneg (Nat.cast_nonneg left) (Nat.cast_nonneg right))
      term.nonnegative
  withinBudget := by
    exact mul_le_mul_of_nonneg_left term.withinBudget
      (mul_nonneg (Nat.cast_nonneg left) (Nat.cast_nonneg right))

theorem ProductScaledNumericLossTerm.accepted
    (left right : Nat)
    (term : ProductNumericLossTerm) :
    ProductNumericLossTermAccepted
      (ProductScaledNumericLossTerm left right term) :=
  (ProductScaledNumericLossTerm left right term).accepted

structure ProductConcreteHashGapDerivation where
  queryPairBound : Nat
  queryPairBoundPositive : 0 < queryPairBound
  bindingCollisionMultiplier : Nat
  bindingCollisionMultiplier_eq :
    bindingCollisionMultiplier = ProductBindingCollisionMultiplier
  primitiveCollisionTerm : ProductNumericLossTerm
  provenanceVerification : ProductProvenanceVerificationBundle
  concreteModelGap : ProductNumericLossTerm
  concreteModelGap_eq :
    concreteModelGap =
      ProductScaledNumericLossTerm
        queryPairBound
        bindingCollisionMultiplier
        primitiveCollisionTerm

def ProductConcreteHashGapDerivationAccepted
    (derivation : ProductConcreteHashGapDerivation) : Prop :=
  0 < derivation.queryPairBound
    ∧ derivation.bindingCollisionMultiplier =
      ProductBindingCollisionMultiplier
    ∧ ProductNumericLossTermAccepted derivation.primitiveCollisionTerm
    ∧ ProductProvenanceVerificationBundleAccepted
      derivation.provenanceVerification
    ∧ derivation.concreteModelGap =
      ProductScaledNumericLossTerm
        derivation.queryPairBound
        derivation.bindingCollisionMultiplier
        derivation.primitiveCollisionTerm
    ∧ ProductNumericLossTermAccepted derivation.concreteModelGap

theorem ProductConcreteHashGapDerivation.accepted
    (derivation : ProductConcreteHashGapDerivation) :
    ProductConcreteHashGapDerivationAccepted derivation := by
  have hGapAccepted :
      ProductNumericLossTermAccepted derivation.concreteModelGap := by
    rw [derivation.concreteModelGap_eq]
    exact ProductScaledNumericLossTerm.accepted
      derivation.queryPairBound
      derivation.bindingCollisionMultiplier
      derivation.primitiveCollisionTerm
  exact
    ⟨derivation.queryPairBoundPositive,
      derivation.bindingCollisionMultiplier_eq,
      derivation.primitiveCollisionTerm.accepted,
      derivation.provenanceVerification.accepted,
      derivation.concreteModelGap_eq,
      hGapAccepted⟩

def ProductHashModelGapCertificate.ofConcreteHashGapDerivation
    (derivation : ProductConcreteHashGapDerivation) :
    ProductHashModelGapCertificate where
  idealSplitGap := ProductZeroNumericLossTerm
  idealSplitGapValueZero := rfl
  idealSplitGapBudgetZero := rfl
  concreteModelGap := derivation.concreteModelGap

def ProductHashModelTransferCertificate.ofConcreteHashGapDerivation
    (idealModel : ProductIdealSplitQROModel)
    (derivation : ProductConcreteHashGapDerivation) :
    ProductHashModelTransferCertificate where
  claimMode := ProductHashClaimMode.realProvedGap
  idealSplitQROModel := idealModel
  hashModelGap :=
    ProductHashModelGapCertificate.ofConcreteHashGapDerivation derivation
  idealOnlyConcreteGapZero := by
    intro hMode
    cases hMode
  realModeGapBounded := by
    intro _hMode
    exact derivation.concreteModelGap.accepted

def ProductConcreteHashModelTransferCertificateAccepted
    (idealModel : ProductIdealSplitQROModel)
    (derivation : ProductConcreteHashGapDerivation) : Prop :=
  ProductIdealSplitQROModelAccepted idealModel
    ∧ ProductConcreteHashGapDerivationAccepted derivation
    ∧ ProductHashModelTransferCertificateAccepted
      (ProductHashModelTransferCertificate.ofConcreteHashGapDerivation
        idealModel
        derivation)

theorem productConcreteHashModelTransferCertificateAccepted
    {idealModel : ProductIdealSplitQROModel}
    {derivation : ProductConcreteHashGapDerivation}
    (hIdealModel : ProductIdealSplitQROModelAccepted idealModel)
    (hDerivation : ProductConcreteHashGapDerivationAccepted derivation) :
    ProductConcreteHashModelTransferCertificateAccepted
      idealModel
      derivation :=
  ⟨hIdealModel,
    hDerivation,
    ProductHashModelTransferCertificate.accepted
      (ProductHashModelTransferCertificate.ofConcreteHashGapDerivation
        idealModel
        derivation)⟩

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
  provenanceVerification : ProductProvenanceVerificationBundle
  totalLossValue_eq : totalLoss.value = terms.valueTotal
  totalLossBudget_eq : totalLoss.budget = terms.budgetTotal

def ProductFullSystemRiskCertificateAccepted
    (certificate : ProductFullSystemRiskCertificate) : Prop :=
  ProductFullSystemRiskTermsAccepted certificate.terms
    ∧ ProductNumericLossTermAccepted certificate.totalLoss
    ∧ ProductProvenanceVerificationBundleAccepted
      certificate.provenanceVerification
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
    certificate.provenanceVerification.accepted,
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
