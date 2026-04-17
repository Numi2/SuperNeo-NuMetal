import SuperNeoFormal.Phi81CRT

/-!
Concrete PiRLC collision support over the Phi81 CRT components.

This module is the bridge from the abstract random-linear-combination lemmas to
the concrete CRT decomposition.  A nonzero Phi81 delta has a nonzero projection
to at least one degree-27 component, and those components are fields, so the
usual one-bad-pivot-value lemma applies componentwise.
-/

noncomputable section

namespace SuperNeoFormal

open Finset

def pirlcCRTLeftProjectedChallenges
    {count : Nat}
    (challenges : Fin count → Phi81) :
    Fin count → Phi81CRTLeft :=
  fun index => phi81CRTLeftProjection (challenges index)

def pirlcCRTRightProjectedChallenges
    {count : Nat}
    (challenges : Fin count → Phi81) :
    Fin count → Phi81CRTRight :=
  fun index => phi81CRTRightProjection (challenges index)

def pirlcCRTLeftProjectedDeltas
    {count : Nat}
    (deltas : Fin count → Phi81) :
    Fin count → Phi81CRTLeft :=
  fun index => phi81CRTLeftProjection (deltas index)

def pirlcCRTRightProjectedDeltas
    {count : Nat}
    (deltas : Fin count → Phi81) :
    Fin count → Phi81CRTRight :=
  fun index => phi81CRTRightProjection (deltas index)

theorem phi81CRTLeftProjection_rlcWeightedSum
    {count : Nat}
    (challenges deltas : Fin count → Phi81) :
    phi81CRTLeftProjection (rlcWeightedSum challenges deltas) =
      rlcWeightedSum
        (pirlcCRTLeftProjectedChallenges challenges)
        (pirlcCRTLeftProjectedDeltas deltas) := by
  simp [rlcWeightedSum, pirlcCRTLeftProjectedChallenges, pirlcCRTLeftProjectedDeltas]

theorem phi81CRTRightProjection_rlcWeightedSum
    {count : Nat}
    (challenges deltas : Fin count → Phi81) :
    phi81CRTRightProjection (rlcWeightedSum challenges deltas) =
      rlcWeightedSum
        (pirlcCRTRightProjectedChallenges challenges)
        (pirlcCRTRightProjectedDeltas deltas) := by
  simp [rlcWeightedSum, pirlcCRTRightProjectedChallenges, pirlcCRTRightProjectedDeltas]

theorem pirlcCRT_nonzero_pivot_has_nonzero_component
    {count : Nat}
    {pivot : Fin count}
    {deltas : Fin count → Phi81}
    (hPivot : deltas pivot ≠ 0) :
    pirlcCRTLeftProjectedDeltas deltas pivot ≠ 0 ∨
      pirlcCRTRightProjectedDeltas deltas pivot ≠ 0 := by
  simpa [pirlcCRTLeftProjectedDeltas, pirlcCRTRightProjectedDeltas] using
    phi81CRT_nonzero_has_nonzero_component hPivot

theorem pirlcCRT_left_projected_nonzero_is_unit
    {count : Nat}
    {pivot : Fin count}
    {deltas : Fin count → Phi81}
    (hPivot : pirlcCRTLeftProjectedDeltas deltas pivot ≠ 0) :
    IsUnit (pirlcCRTLeftProjectedDeltas deltas pivot) :=
  phi81CRTLeft_isUnit_of_ne_zero hPivot

theorem pirlcCRT_right_projected_nonzero_is_unit
    {count : Nat}
    {pivot : Fin count}
    {deltas : Fin count → Phi81}
    (hPivot : pirlcCRTRightProjectedDeltas deltas pivot ≠ 0) :
    IsUnit (pirlcCRTRightProjectedDeltas deltas pivot) :=
  phi81CRTRight_isUnit_of_ne_zero hPivot

def pirlcCRTLeftBadPivotValues
    {count : Nat}
    [DecidableEq Phi81CRTLeft]
    (support : Finset Phi81CRTLeft)
    (fixedChallenges : Fin count → Phi81)
    (pivot : Fin count)
    (deltas : Fin count → Phi81) :
    Finset Phi81CRTLeft :=
  scalarRLCBadPivotValues
    support
    (pirlcCRTLeftProjectedChallenges fixedChallenges)
    pivot
    (pirlcCRTLeftProjectedDeltas deltas)

def pirlcCRTRightBadPivotValues
    {count : Nat}
    [DecidableEq Phi81CRTRight]
    (support : Finset Phi81CRTRight)
    (fixedChallenges : Fin count → Phi81)
    (pivot : Fin count)
    (deltas : Fin count → Phi81) :
    Finset Phi81CRTRight :=
  scalarRLCBadPivotValues
    support
    (pirlcCRTRightProjectedChallenges fixedChallenges)
    pivot
    (pirlcCRTRightProjectedDeltas deltas)

theorem pirlcCRTLeftBadPivotValues_card_le_one
    {count : Nat}
    [DecidableEq Phi81CRTLeft]
    (support : Finset Phi81CRTLeft)
    (fixedChallenges : Fin count → Phi81)
    (pivot : Fin count)
    (deltas : Fin count → Phi81)
    (hPivot : pirlcCRTLeftProjectedDeltas deltas pivot ≠ 0) :
    (pirlcCRTLeftBadPivotValues
      support
      fixedChallenges
      pivot
      deltas).card ≤ 1 :=
  scalarRLCBadPivotValues_card_le_one
    support
    (pirlcCRTLeftProjectedChallenges fixedChallenges)
    pivot
    (pirlcCRTLeftProjectedDeltas deltas)
    hPivot

theorem pirlcCRTRightBadPivotValues_card_le_one
    {count : Nat}
    [DecidableEq Phi81CRTRight]
    (support : Finset Phi81CRTRight)
    (fixedChallenges : Fin count → Phi81)
    (pivot : Fin count)
    (deltas : Fin count → Phi81)
    (hPivot : pirlcCRTRightProjectedDeltas deltas pivot ≠ 0) :
    (pirlcCRTRightBadPivotValues
      support
      fixedChallenges
      pivot
      deltas).card ≤ 1 :=
  scalarRLCBadPivotValues_card_le_one
    support
    (pirlcCRTRightProjectedChallenges fixedChallenges)
    pivot
    (pirlcCRTRightProjectedDeltas deltas)
    hPivot

end SuperNeoFormal
