import SuperNeoFormal.Ext2CallerSerialization

namespace SuperNeoFormal

private def fixtureC0Raw : Nat :=
  0x0102_0304_0506_0708

private def fixtureC1Raw : Nat :=
  0x1110_0F0E_0D0C_0B0A

private def fixtureC0 : Goldilocks :=
  (fixtureC0Raw : Goldilocks)

private def fixtureC1 : Goldilocks :=
  (fixtureC1Raw : Goldilocks)

private def fixtureElement : GoldilocksExt2 where
  c0 := fixtureC0
  c1 := fixtureC1

private def fixtureSwapped : GoldilocksExt2 where
  c0 := fixtureC1
  c1 := fixtureC0

private def fixtureCount1 : UInt64LE :=
  ⟨1, by native_decide⟩

private def fixtureCount2 : UInt64LE :=
  ⟨2, by native_decide⟩

private def fixtureByte (value : Nat) (hValue : value < 256 := by native_decide) : Byte :=
  ⟨value, hValue⟩

private def fixturePrefixBytes : List Byte :=
  [fixtureByte 160, fixtureByte 161, fixtureByte 162, fixtureByte 163, fixtureByte 164]

private def fixtureRing : Phi81Ext2Coefficients :=
  fun index =>
    if index.val = 0 then
      fixtureElement
    else if index.val = 1 then
      fixtureSwapped
    else
      goldilocksExt2Zero

private def fixtureRound : SwiftSumcheckRoundExt2Wire where
  coeffCount := fixtureCount2
  coefficients := [fixtureSwapped, fixtureElement]

private def fixtureSumcheck : SwiftSumcheckProofExt2Wire where
  claimedSum := fixtureElement
  roundCount := fixtureCount1
  rounds := [fixtureRound]
  finalPointCount := fixtureCount1
  finalPoint := [fixtureElement]
  finalValue := fixtureSwapped

private def fixturePointEvaluationSurface : SwiftExt2PointEvaluationSurfaceWire where
  prefixBytes := fixturePrefixBytes
  pointCount := fixtureCount1
  point := [fixtureSwapped]
  evaluationCount := fixtureCount1
  evaluations := [fixtureRing]

private def fixtureModulusUInt64 : UInt64LE :=
  ⟨goldilocksModulus, by native_decide⟩

private def fixtureNonCanonicalC0Bytes : List Byte :=
  uint64LEEncode fixtureModulusUInt64 ++ goldilocksElementEncode fixtureC1

private def fixtureNonCanonicalC1Bytes : List Byte :=
  goldilocksElementEncode fixtureC0 ++ uint64LEEncode fixtureModulusUInt64

private def byteListString (bytes : List Byte) : String :=
  String.intercalate "," (bytes.map fun byte => toString byte.val)

private def ext2DecodeStatus (bytes : List Byte) : String :=
  match goldilocksExt2ElementDecode? bytes with
  | some value => "some:" ++ toString value.c0.val ++ "," ++ toString value.c1.val
  | none => "none"

private def vectorLines : List (String × String) := [
  ("goldilocks_c0_encode", byteListString (goldilocksElementEncode fixtureC0)),
  ("goldilocks_c1_encode", byteListString (goldilocksElementEncode fixtureC1)),
  ("goldilocks_ext2_encode", byteListString (goldilocksExt2ElementEncode fixtureElement)),
  ("goldilocks_ext2_swapped_encode", byteListString (goldilocksExt2ElementEncode fixtureSwapped)),
  ("goldilocks_ext2_decode_valid", ext2DecodeStatus (goldilocksExt2ElementEncode fixtureElement)),
  ("goldilocks_ext2_decode_noncanonical_c0", ext2DecodeStatus fixtureNonCanonicalC0Bytes),
  ("goldilocks_ext2_decode_noncanonical_c1", ext2DecodeStatus fixtureNonCanonicalC1Bytes),
  ("goldilocks_ext2_decode_wrong_length", ext2DecodeStatus ((goldilocksExt2ElementEncode fixtureElement).take 15)),
  ("cyclotomic_ext2_ring54_encode", byteListString (swiftCyclotomicExt2Ring54WireEncode fixtureRing)),
  ("sumcheck_ext2_surface_encode", byteListString (swiftSumcheckProofExt2WireEncode fixtureSumcheck)),
  ("point_evaluation_ext2_surface_encode", byteListString (swiftExt2PointEvaluationSurfaceWireEncode fixturePointEvaluationSurface))
]

end SuperNeoFormal

def main : IO Unit := do
  for (label, value) in SuperNeoFormal.vectorLines do
    IO.println s!"{label}={value}"
