import SuperNeoFormal.CEOpeningRelation

/-!
Certified Ajtai key surface.

This module is the completed-formal-status replacement for the previous
MSIS-boundary groups.  It does not assert that every matrix is binding.  Instead,
binding consumers take an explicit Lean-checkable certificate whose payload is
the concrete no-short-kernel theorem for the matrix that the verifier key names.
-/

noncomputable section

namespace SuperNeoFormal

structure CertifiedKernelMatrix
    (RF : Type) [CommRing RF]
    (rows columns : Nat)
    (bounded : Message RF columns → Prop) where
  matrix : AjtaiMatrix RF rows columns
  noShortKernel : NoShortKernel matrix bounded

theorem certifiedKernelMatrix_noShortKernel
    {RF : Type} [CommRing RF]
    {rows columns : Nat}
    {bounded : Message RF columns → Prop}
    (certified : CertifiedKernelMatrix RF rows columns bounded) :
    NoShortKernel certified.matrix bounded :=
  certified.noShortKernel

theorem certifiedBinding_from_kernelMatrix
    {RF : Type} [CommRing RF]
    {rows columns : Nat}
    {bounded : Message RF columns → Prop}
    (certified : CertifiedKernelMatrix RF rows columns bounded)
    {lhs rhs : Message RF columns}
    (hlhs : bounded lhs)
    (hrhs : bounded rhs)
    (hCommit : commit certified.matrix lhs = commit certified.matrix rhs) :
    lhs = rhs :=
  binding_from_noShortKernel
    certified.noShortKernel
    hlhs
    hrhs
    hCommit

structure CertifiedAjtaiKey (columns : Nat) where
  matrix : ConcreteAjtaiMatrix columns
  profileID : Nat
  verifierKeyDigest : Nat

structure AjtaiKernelCertificate
    {columns : Nat}
    (bounded : ConcreteAjtaiMessage columns → Prop) where
  matrix : ConcreteAjtaiMatrix columns
  profileID : Nat
  verifierKeyDigest : Nat
  noShortKernel : ModuleSISNoShortKernel matrix bounded

def checkAjtaiKernelCertificate
    {columns : Nat}
    {bounded : ConcreteAjtaiMessage columns → Prop}
    (key : CertifiedAjtaiKey columns)
    (certificate : AjtaiKernelCertificate bounded) : Prop :=
  certificate.matrix = key.matrix ∧
    certificate.profileID = key.profileID ∧
      certificate.verifierKeyDigest = key.verifierKeyDigest

theorem checkedAjtaiKernelCertificate_noShortKernel
    {columns : Nat}
    {key : CertifiedAjtaiKey columns}
    {bounded : ConcreteAjtaiMessage columns → Prop}
    {certificate : AjtaiKernelCertificate bounded}
    (hCheck : checkAjtaiKernelCertificate key certificate) :
    ModuleSISNoShortKernel key.matrix bounded := by
  rcases hCheck with ⟨hMatrix, _hProfile, _hDigest⟩
  simpa [hMatrix] using certificate.noShortKernel

def VerifiedAjtaiKernelCertificate
    {columns : Nat}
    (key : CertifiedAjtaiKey columns)
    (bounded : ConcreteAjtaiMessage columns → Prop) : Type :=
  { certificate : AjtaiKernelCertificate bounded //
      checkAjtaiKernelCertificate key certificate }

theorem verifiedCertificate_noShortKernel
    {columns : Nat}
    {key : CertifiedAjtaiKey columns}
    {bounded : ConcreteAjtaiMessage columns → Prop}
    (certificate : VerifiedAjtaiKernelCertificate key bounded) :
    ModuleSISNoShortKernel key.matrix bounded :=
  checkedAjtaiKernelCertificate_noShortKernel certificate.property

theorem certifiedConcreteBinding_from_verifiedCertificate
    {columns : Nat}
    {key : CertifiedAjtaiKey columns}
    {bounded : ConcreteAjtaiMessage columns → Prop}
    {lhs rhs : ConcreteAjtaiMessage columns}
    (certificate : VerifiedAjtaiKernelCertificate key bounded)
    (hlhs : bounded lhs)
    (hrhs : bounded rhs)
    (hCommit : concreteCommit key.matrix lhs = concreteCommit key.matrix rhs) :
    lhs = rhs :=
  concreteBinding_from_moduleSISNoShortKernel
    (verifiedCertificate_noShortKernel certificate)
    hlhs
    hrhs
    hCommit

theorem certifiedConcreteBindingSecure_from_verifiedCertificate
    {columns : Nat}
    {key : CertifiedAjtaiKey columns}
    {bounded : ConcreteAjtaiMessage columns → Prop}
    (certificate : VerifiedAjtaiKernelCertificate key bounded) :
    ConcreteBindingSecure key.matrix bounded :=
  concreteBindingSecure_from_moduleSISNoShortKernel
    (verifiedCertificate_noShortKernel certificate)

theorem certifiedOpening_messages_equal_from_verifiedCertificate
    {columns : Nat}
    {key : CertifiedAjtaiKey columns}
    {bounded : ConcreteAjtaiMessage columns → Prop}
    {lhs rhs : ConcreteAjtaiMessage columns}
    {c : ConcreteAjtaiCommitment}
    (certificate : VerifiedAjtaiKernelCertificate key bounded)
    (hlhs : ConcreteOpening key.matrix c bounded lhs)
    (hrhs : ConcreteOpening key.matrix c bounded rhs) :
    lhs = rhs :=
  opening_messages_equal_from_noShortKernel
    (verifiedCertificate_noShortKernel certificate)
    hlhs
    hrhs

theorem certifiedCeLocalOpening_witness_unique_from_verifiedCertificate
    {columns publicCount evalCount pointVars : Nat}
    {key : CertifiedAjtaiKey columns}
    {bounded : ConcreteAjtaiMessage columns → Prop}
    {shape : CEOpeningShape}
    {context : CEOpeningPublicContext}
    {publicBound : Phi81 → Prop}
    {evaluationRelation :
      ConcreteAjtaiMessage columns →
        ProtocolVector Phi81 pointVars →
        ProtocolVector Phi81 evalCount →
        Prop}
    {statement : CELocalStatement Phi81 kappa publicCount evalCount pointVars}
    {lhs rhs : ConcreteAjtaiMessage columns}
    (certificate : VerifiedAjtaiKernelCertificate key bounded)
    (hlhs :
      CELocalOpeningRelation
        shape context key.matrix bounded publicBound evaluationRelation statement lhs)
    (hrhs :
      CELocalOpeningRelation
        shape context key.matrix bounded publicBound evaluationRelation statement rhs) :
    lhs = rhs :=
  ceLocalOpening_witness_unique_from_noShortKernel
    (verifiedCertificate_noShortKernel certificate)
    hlhs
    hrhs

theorem certifiedCeTerminalLocalBatch_witnesses_unique_from_verifiedCertificate
    {count columns publicCount evalCount pointVars : Nat}
    {key : CertifiedAjtaiKey columns}
    {bounded : ConcreteAjtaiMessage columns → Prop}
    {shape : CEOpeningShape}
    {context : CEOpeningPublicContext}
    {publicBound : Phi81 → Prop}
    {evaluationRelation :
      ConcreteAjtaiMessage columns →
        ProtocolVector Phi81 pointVars →
        ProtocolVector Phi81 evalCount →
        Prop}
    {statement : CETerminalStatement Phi81 count kappa publicCount evalCount pointVars}
    {lhs rhs : Fin count → ConcreteAjtaiMessage columns}
    (certificate : VerifiedAjtaiKernelCertificate key bounded)
    (hlhs :
      CETerminalLocalBatchRelation
        shape context key.matrix bounded publicBound evaluationRelation statement lhs)
    (hrhs :
      CETerminalLocalBatchRelation
        shape context key.matrix bounded publicBound evaluationRelation statement rhs) :
    lhs = rhs :=
  ceTerminalLocalBatch_witnesses_unique_from_noShortKernel
    (verifiedCertificate_noShortKernel certificate)
    hlhs
    hrhs

theorem arbitraryNoShortKernelTheorem_false
    {RF : Type} [CommRing RF] [Nontrivial RF] :
    ∃ A : AjtaiMatrix RF 1 1,
      ∃ bounded : Message RF 1 → Prop,
        ¬ NoShortKernel A bounded := by
  let A : AjtaiMatrix RF 1 1 := fun _ _ => 0
  let bounded : Message RF 1 → Prop := fun _ => True
  refine ⟨A, bounded, ?_⟩
  intro hKernel
  let diff : Message RF 1 := fun _ => 1
  have hDiff : DifferenceOfBounded bounded diff := by
    refine ⟨diff, 0, trivial, trivial, ?_⟩
    funext column
    simp [diff]
  have hCommit : commit A diff = 0 := by
    funext row
    simp [commit, A]
  have hZero : diff = 0 := hKernel diff hDiff hCommit
  have hOneZero : (1 : RF) = 0 := by
    simpa [diff] using congrFun hZero ⟨0, by decide⟩
  exact one_ne_zero hOneZero

end SuperNeoFormal
