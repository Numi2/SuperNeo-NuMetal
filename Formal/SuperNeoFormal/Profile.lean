import Mathlib

/-!
Lean-side constants for the implemented SuperNeo NuMetal profile.

This file intentionally models the repository's current target:
Goldilocks/Phi81(d=54), where Phi_81(X) = X^54 + X^27 + 1.
AG64 / X^64 + 1 is a different profile and is out of scope here.
-/

namespace SuperNeoFormal

def goldilocksModulus : Nat := 18446744069414584321
def phi81Index : Nat := 81
def phi81Degree : Nat := 54
def kappa : Nat := 18
def decompositionLength : Nat := 14
def normBound : Nat := 2
def challengeExpansionFactor : Nat := 216
def freshBatchCount : Nat := 61
def paperClaimThresholdBits : Nat := 129
def moduleSISDimension : Nat := kappa * phi81Degree
def estimatorMSISLength : Nat := 2 ^ 30
def decompositionRadixBound : Nat := normBound ^ decompositionLength
def strongSamplingLeft : Nat := (freshBatchCount + decompositionLength) * challengeExpansionFactor * (normBound - 1)

theorem goldilocksModulus_eq : goldilocksModulus = 18446744069414584321 := rfl
theorem phi81Index_eq : phi81Index = 81 := rfl
theorem phi81Degree_eq : phi81Degree = 54 := rfl
theorem kappa_eq : kappa = 18 := rfl
theorem decompositionLength_eq : decompositionLength = 14 := rfl
theorem moduleSISDimension_eq : moduleSISDimension = 972 := by native_decide
theorem estimatorMSISLength_eq : estimatorMSISLength = 1073741824 := by native_decide
theorem decompositionRadixBound_eq : decompositionRadixBound = 16384 := by native_decide
theorem strongSamplingLeft_eq : strongSamplingLeft = 16200 := by native_decide
theorem strongSampling_holds : strongSamplingLeft < decompositionRadixBound := by native_decide

end SuperNeoFormal
