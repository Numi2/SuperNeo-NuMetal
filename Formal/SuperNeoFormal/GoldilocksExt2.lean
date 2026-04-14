import SuperNeoFormal.Goldilocks

/-!
Goldilocks quadratic-extension wire model.

Swift represents an extension element as `c0 + c1 u` with `u^2 = 7`.  This file
records the concrete operations and the certificate surface consumed by the
finite-field sum-check model.  The field-law certificate is explicit, so later
passes can replace it with a full irreducibility proof without changing theorem
consumers.
-/

namespace SuperNeoFormal

structure GoldilocksExt2 where
  c0 : Goldilocks
  c1 : Goldilocks
  deriving DecidableEq

def goldilocksExt2NonResidue : Goldilocks :=
  7

def goldilocksExt2Zero : GoldilocksExt2 where
  c0 := 0
  c1 := 0

def goldilocksExt2One : GoldilocksExt2 where
  c0 := 1
  c1 := 0

def goldilocksExt2Add (lhs rhs : GoldilocksExt2) : GoldilocksExt2 where
  c0 := lhs.c0 + rhs.c0
  c1 := lhs.c1 + rhs.c1

def goldilocksExt2Neg (value : GoldilocksExt2) : GoldilocksExt2 where
  c0 := -value.c0
  c1 := -value.c1

def goldilocksExt2Sub (lhs rhs : GoldilocksExt2) : GoldilocksExt2 :=
  goldilocksExt2Add lhs (goldilocksExt2Neg rhs)

def goldilocksExt2Mul (lhs rhs : GoldilocksExt2) : GoldilocksExt2 where
  c0 := lhs.c0 * rhs.c0 + lhs.c1 * rhs.c1 * goldilocksExt2NonResidue
  c1 := (lhs.c0 + lhs.c1) * (rhs.c0 + rhs.c1) -
    lhs.c0 * rhs.c0 - lhs.c1 * rhs.c1

def goldilocksExt2Denominator (value : GoldilocksExt2) : Goldilocks :=
  value.c0 * value.c0 - value.c1 * value.c1 * goldilocksExt2NonResidue

def goldilocksExt2InvData (value : GoldilocksExt2) (denominatorInv : Goldilocks) :
    GoldilocksExt2 where
  c0 := value.c0 * denominatorInv
  c1 := -value.c1 * denominatorInv

structure GoldilocksExt2FieldCertificate where
  denominator_nonzero :
    ∀ value : GoldilocksExt2,
      value ≠ goldilocksExt2Zero →
        goldilocksExt2Denominator value ≠ 0
  denominator_inverse :
    ∀ value : GoldilocksExt2,
      value ≠ goldilocksExt2Zero →
        ∃ denominatorInv,
          goldilocksExt2Denominator value * denominatorInv = 1

def GoldilocksExt2FieldModel : Prop :=
  ∃ _certificate : GoldilocksExt2FieldCertificate, True

theorem goldilocksExt2_operations_match_swift_mul
    (lhs rhs : GoldilocksExt2) :
    goldilocksExt2Mul lhs rhs =
      { c0 := lhs.c0 * rhs.c0 + lhs.c1 * rhs.c1 * goldilocksExt2NonResidue
        c1 := (lhs.c0 + lhs.c1) * (rhs.c0 + rhs.c1) -
          lhs.c0 * rhs.c0 - lhs.c1 * rhs.c1 } := by
  rfl

theorem goldilocksExt2_inverse_data_denominator
    (value : GoldilocksExt2)
    {denominatorInv : Goldilocks}
    (hInv : goldilocksExt2Denominator value * denominatorInv = 1) :
    goldilocksExt2Denominator value * (goldilocksExt2InvData value denominatorInv).c0 =
      value.c0 := by
  simp [goldilocksExt2InvData]
  calc
    goldilocksExt2Denominator value * (value.c0 * denominatorInv) =
        value.c0 * (goldilocksExt2Denominator value * denominatorInv) := by
      ring
    _ = value.c0 := by
      rw [hInv]
      ring

theorem goldilocksExt2_field_model_from_certificate
    (certificate : GoldilocksExt2FieldCertificate) :
    GoldilocksExt2FieldModel :=
  ⟨certificate, trivial⟩

end SuperNeoFormal
