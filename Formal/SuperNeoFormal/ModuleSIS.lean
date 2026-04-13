import SuperNeoFormal.Embedding
import SuperNeoFormal.Ajtai

/-!
Concrete Module-SIS parameter surface for the implemented Goldilocks/Phi81
profile.

This does not assert lattice hardness.  It packages the exact Lean-side
parameters that correspond to the estimator artifact and names the concrete
no-short-kernel predicate used by the Ajtai binding reduction.
-/

noncomputable section

namespace SuperNeoFormal

structure ModuleSISProfile where
  modulus : Nat
  degree : Nat
  rank : Nat
  coefficientDimension : Nat
  decompositionLength : Nat
  normBound : Nat
  estimatorLength : Nat
  claimedSecurityBits : Nat

def goldilocksPhi81ModuleSISProfile : ModuleSISProfile where
  modulus := goldilocksModulus
  degree := phi81Degree
  rank := kappa
  coefficientDimension := moduleSISDimension
  decompositionLength := decompositionLength
  normBound := normBound
  estimatorLength := estimatorMSISLength
  claimedSecurityBits := paperClaimThresholdBits

structure EstimatorTuple where
  modulus : Nat
  nSIS : Nat
  length : Nat
  claimedSecurityBits : Nat

def goldilocksPhi81EstimatorTuple : EstimatorTuple where
  modulus := goldilocksModulus
  nSIS := moduleSISDimension
  length := estimatorMSISLength
  claimedSecurityBits := paperClaimThresholdBits

def ModuleSISNoShortKernel
    {columns : Nat}
    (A : AjtaiMatrix Phi81 kappa columns)
    (bounded : Message Phi81 columns → Prop) : Prop :=
  NoShortKernel A bounded

theorem goldilocksPhi81ModuleSISProfile_modulus :
    goldilocksPhi81ModuleSISProfile.modulus = goldilocksModulus := rfl

theorem goldilocksPhi81ModuleSISProfile_degree :
    goldilocksPhi81ModuleSISProfile.degree = 54 := by
  native_decide

theorem goldilocksPhi81ModuleSISProfile_rank :
    goldilocksPhi81ModuleSISProfile.rank = 18 := by
  native_decide

theorem goldilocksPhi81ModuleSISProfile_coefficientDimension :
    goldilocksPhi81ModuleSISProfile.coefficientDimension = 972 := by
  native_decide

theorem goldilocksPhi81ModuleSISProfile_decompositionLength :
    goldilocksPhi81ModuleSISProfile.decompositionLength = 14 := by
  native_decide

theorem goldilocksPhi81ModuleSISProfile_normBound :
    goldilocksPhi81ModuleSISProfile.normBound = 2 := by
  native_decide

theorem goldilocksPhi81EstimatorTuple_matches_profile :
    goldilocksPhi81EstimatorTuple.modulus = goldilocksPhi81ModuleSISProfile.modulus ∧
      goldilocksPhi81EstimatorTuple.nSIS =
        goldilocksPhi81ModuleSISProfile.coefficientDimension ∧
      goldilocksPhi81EstimatorTuple.length =
        goldilocksPhi81ModuleSISProfile.estimatorLength ∧
      goldilocksPhi81EstimatorTuple.claimedSecurityBits =
        goldilocksPhi81ModuleSISProfile.claimedSecurityBits := by
  exact ⟨rfl, rfl, rfl, rfl⟩

theorem goldilocksPhi81EstimatorTuple_values :
    goldilocksPhi81EstimatorTuple.modulus = 18446744069414584321 ∧
      goldilocksPhi81EstimatorTuple.nSIS = 972 ∧
      goldilocksPhi81EstimatorTuple.length = 1073741824 ∧
      goldilocksPhi81EstimatorTuple.claimedSecurityBits = 129 := by
  native_decide

theorem moduleSISNoShortKernel_is_concrete_noShortKernel
    {columns : Nat}
    {A : AjtaiMatrix Phi81 kappa columns}
    {bounded : Message Phi81 columns → Prop} :
    ModuleSISNoShortKernel A bounded ↔ NoShortKernel A bounded := by
  rfl

end SuperNeoFormal
