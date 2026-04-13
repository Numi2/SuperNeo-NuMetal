import SuperNeoFormal.Phi81

/-!
Field-to-Phi81 coefficient packing.

Swift packs Goldilocks witness vectors into consecutive degree-54
`CyclotomicRing54` coefficient blocks, padding the last block with zeroes.  This
module formalizes that indexing discipline and proves the exact-pack/unpack
round trip plus coefficient-bound preservation.
-/

noncomputable section

namespace SuperNeoFormal

abbrev FieldVector (n : Nat) :=
  Fin n → Goldilocks

abbrev Phi81CoeffVector (columns : Nat) :=
  Fin columns → Phi81Coefficients

theorem phi81Degree_pos : 0 < phi81Degree := by
  native_decide

def embeddingFlattenIndex {columns : Nat}
    (column : Fin columns)
    (coeff : Fin phi81Degree) : Fin (columns * phi81Degree) :=
  ⟨column.val * phi81Degree + coeff.val, by
    have hColumn : column.val < columns := column.isLt
    have hCoeff : coeff.val < phi81Degree := coeff.isLt
    nlinarith [hColumn, hCoeff]⟩

def packExactCoefficients {columns : Nat}
    (fieldVector : FieldVector (columns * phi81Degree)) : Phi81CoeffVector columns :=
  fun column coeff => fieldVector (embeddingFlattenIndex column coeff)

def unpackExactCoefficients {columns : Nat}
    (rings : Phi81CoeffVector columns) : FieldVector (columns * phi81Degree) :=
  fun index =>
    rings
      ⟨index.val / phi81Degree, by
        have hlt : index.val < phi81Degree * columns := by
          simp [Nat.mul_comm, index.isLt]
        exact Nat.div_lt_of_lt_mul hlt⟩
      ⟨index.val % phi81Degree, Nat.mod_lt _ phi81Degree_pos⟩

def packedColumnCount (length : Nat) : Nat :=
  (length + phi81Degree - 1) / phi81Degree

def paddedFieldVector {length : Nat}
    (fieldVector : FieldVector length) :
    FieldVector (packedColumnCount length * phi81Degree) :=
  fun index =>
    if hIndex : index.val < length then
      fieldVector ⟨index.val, hIndex⟩
    else
      0

def packPaddedCoefficients {length : Nat}
    (fieldVector : FieldVector length) : Phi81CoeffVector (packedColumnCount length) :=
  packExactCoefficients (paddedFieldVector fieldVector)

def packExactPhi81 {columns : Nat}
    (fieldVector : FieldVector (columns * phi81Degree)) : Fin columns → Phi81 :=
  fun column => phi81CoeffsToQuotient (packExactCoefficients fieldVector column)

def packPaddedPhi81 {length : Nat}
    (fieldVector : FieldVector length) : Fin (packedColumnCount length) → Phi81 :=
  fun column => phi81CoeffsToQuotient (packPaddedCoefficients fieldVector column)

def FieldVectorCoeffBounded {length : Nat}
    (bound : Nat)
    (fieldVector : FieldVector length) : Prop :=
  ∀ index, goldilocksCenteredNorm (fieldVector index) ≤ bound

def Phi81CoeffVectorBounded {columns : Nat}
    (bound : Nat)
    (rings : Phi81CoeffVector columns) : Prop :=
  ∀ column coeff, goldilocksCenteredNorm (rings column coeff) ≤ bound

theorem goldilocksCenteredNorm_zero :
    goldilocksCenteredNorm (0 : Goldilocks) = 0 := by
  simp [goldilocksCenteredNorm]

theorem unpackExact_packExact {columns : Nat}
    (fieldVector : FieldVector (columns * phi81Degree)) :
    unpackExactCoefficients (packExactCoefficients fieldVector) = fieldVector := by
  funext index
  simp [unpackExactCoefficients, packExactCoefficients, embeddingFlattenIndex]
  congr
  simpa [Nat.mul_comm] using Nat.div_add_mod index.val phi81Degree

theorem packExact_unpackExact {columns : Nat}
    (rings : Phi81CoeffVector columns) :
    packExactCoefficients (unpackExactCoefficients rings) = rings := by
  funext column coeff
  simp [packExactCoefficients, unpackExactCoefficients, embeddingFlattenIndex]
  congr
  · apply Nat.div_eq_of_lt_le
    · exact Nat.le_add_right _ _
    · have hCoeff : coeff.val < phi81Degree := coeff.isLt
      nlinarith
  · exact Nat.mod_eq_of_lt coeff.isLt

theorem packExactCoeffBounded_iff {columns bound : Nat}
    (fieldVector : FieldVector (columns * phi81Degree)) :
    Phi81CoeffVectorBounded bound (packExactCoefficients fieldVector) ↔
      FieldVectorCoeffBounded bound fieldVector := by
  constructor
  · intro hPacked index
    let column : Fin columns := ⟨index.val / phi81Degree, by
      have hlt : index.val < phi81Degree * columns := by
        simp [Nat.mul_comm, index.isLt]
      exact Nat.div_lt_of_lt_mul hlt⟩
    let coeff : Fin phi81Degree := ⟨index.val % phi81Degree, Nat.mod_lt _ phi81Degree_pos⟩
    have hValue := congrFun (unpackExact_packExact fieldVector) index
    rw [← hValue]
    exact hPacked column coeff
  · intro hField column coeff
    exact hField (embeddingFlattenIndex column coeff)

theorem packPaddedCoeffBounded_of_field {length bound : Nat}
    {fieldVector : FieldVector length}
    (hField : FieldVectorCoeffBounded bound fieldVector) :
    Phi81CoeffVectorBounded bound (packPaddedCoefficients fieldVector) := by
  intro column coeff
  unfold packPaddedCoefficients packExactCoefficients paddedFieldVector embeddingFlattenIndex
  by_cases hIndex : column.val * phi81Degree + coeff.val < length
  · simpa [hIndex] using hField ⟨column.val * phi81Degree + coeff.val, hIndex⟩
  · simp [hIndex, goldilocksCenteredNorm_zero]

theorem packExactCoeffBounded_of_field {columns bound : Nat}
    {fieldVector : FieldVector (columns * phi81Degree)}
    (hField : FieldVectorCoeffBounded bound fieldVector) :
    Phi81CoeffVectorBounded bound (packExactCoefficients fieldVector) :=
  (packExactCoeffBounded_iff fieldVector).mpr hField

theorem fieldCoeffBounded_of_packExact {columns bound : Nat}
    {fieldVector : FieldVector (columns * phi81Degree)}
    (hPacked : Phi81CoeffVectorBounded bound (packExactCoefficients fieldVector)) :
    FieldVectorCoeffBounded bound fieldVector :=
  (packExactCoeffBounded_iff fieldVector).mp hPacked

end SuperNeoFormal
