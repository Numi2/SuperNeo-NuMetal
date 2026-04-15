import SuperNeoFormal.Ext2CallerSerialization

/-!
Executable vector checks for the formal wire surfaces.

These checks are not theorem assumptions.  They are concrete predicates over the
same representative serialization fixtures used by the Swift/Lean vector bridge,
kept outside the theorem barrel and guarded by `proof_import_wall`.
-/

namespace SuperNeoFormal
namespace VectorChecks

structure CheckCase where
  label : String
  run : Unit -> Bool

private def byteListString (bytes : List Byte) : String :=
  String.intercalate "," (bytes.map fun byte => toString byte.val)

private def optionIsNone {α : Type} : Option α → Bool
  | none => true
  | some _ => false

namespace Ext2

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

private def fixtureAddExpected : GoldilocksExt2 where
  c0 := (1302123111085380114 : Goldilocks)
  c1 := (1302123111085380114 : Goldilocks)

private def fixtureSubExpected : GoldilocksExt2 where
  c0 := (17289868677909969919 : Goldilocks)
  c1 := (1156875391504614402 : Goldilocks)

private def fixtureNegExpected : GoldilocksExt2 where
  c0 := (18374120209624201465 : Goldilocks)
  c1 := (17217244818119587063 : Goldilocks)

private def fixtureMulExpected : GoldilocksExt2 where
  c0 := (10846806218738057787 : Goldilocks)
  c1 := (15680787385049943039 : Goldilocks)

private def fixtureDenominatorExpected : Goldilocks :=
  (8244253219272608537 : Goldilocks)

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

private def ext2DecodeStatus (bytes : List Byte) : String :=
  match goldilocksExt2ElementDecode? bytes with
  | some value => "some:" ++ toString value.c0.val ++ "," ++ toString value.c1.val
  | none => "none"

private def ext2Matches (expected : GoldilocksExt2) : Option GoldilocksExt2 → Bool
  | some value => value.c0.val == expected.c0.val && value.c1.val == expected.c1.val
  | none => false

private def ext2ValueMatches (actual expected : GoldilocksExt2) : Bool :=
  actual.c0.val == expected.c0.val && actual.c1.val == expected.c1.val

private def ext2ListEntryMatches
    (values : List GoldilocksExt2) (index : Nat) (expected : GoldilocksExt2) : Bool :=
  match values[index]? with
  | some value => ext2ValueMatches value expected
  | none => false

private def ringMatchesFixture (ring : Phi81Ext2Coefficients) : Bool :=
  ext2ValueMatches (ring ⟨0, by native_decide⟩) fixtureElement &&
    ext2ValueMatches (ring ⟨1, by native_decide⟩) fixtureSwapped &&
    ext2ValueMatches (ring ⟨2, by native_decide⟩) goldilocksExt2Zero

private def ringDecodeMatchesFixture : Option Phi81Ext2Coefficients → Bool
  | some ring => ringMatchesFixture ring
  | none => false

private def sumcheckRoundParseMatches :
    Option (SwiftSumcheckRoundExt2Wire × List Byte) → Bool
  | some (round, rest) =>
      rest.isEmpty &&
        round.coeffCount.val == 2 &&
        round.coefficients.length == 2 &&
        ext2ListEntryMatches round.coefficients 0 fixtureSwapped &&
        ext2ListEntryMatches round.coefficients 1 fixtureElement
  | none => false

private def sumcheckProofParseMatches :
    Option (SwiftSumcheckProofExt2Wire × List Byte) → Bool
  | some (proof, rest) =>
      rest.isEmpty &&
        ext2ValueMatches proof.claimedSum fixtureElement &&
        proof.roundCount.val == 1 &&
        proof.rounds.length == 1 &&
        proof.finalPointCount.val == 1 &&
        proof.finalPoint.length == 1 &&
        ext2ListEntryMatches proof.finalPoint 0 fixtureElement &&
        ext2ValueMatches proof.finalValue fixtureSwapped
  | none => false

private def pointSurfaceParseMatches :
    Option (SwiftExt2PointEvaluationSurfaceWire × List Byte) → Bool
  | some (surface, rest) =>
      rest.isEmpty &&
        surface.prefixBytes.length == fixturePrefixBytes.length &&
        surface.pointCount.val == 1 &&
        surface.point.length == 1 &&
        ext2ListEntryMatches surface.point 0 fixtureSwapped &&
        surface.evaluationCount.val == 1 &&
        surface.evaluations.length == 1 &&
        match surface.evaluations[0]? with
        | some ring => ringMatchesFixture ring
        | none => false
  | none => false

def vectorLines : List (String × String) := [
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

def checks : List CheckCase := [
  {
    label := "goldilocks_c0_encode_width",
    run := fun _ => (goldilocksElementEncode fixtureC0).length == 8
  },
  {
    label := "goldilocks_c0_roundtrip",
    run := fun _ =>
      match goldilocksElementDecode? (goldilocksElementEncode fixtureC0) with
      | some value => value.val == fixtureC0.val
      | none => false
  },
  {
    label := "goldilocks_ext2_encode_width",
    run := fun _ => (goldilocksExt2ElementEncode fixtureElement).length == 16
  },
  {
    label := "goldilocks_ext2_roundtrip",
    run := fun _ => ext2Matches fixtureElement
      (goldilocksExt2ElementDecode? (goldilocksExt2ElementEncode fixtureElement))
  },
  {
    label := "goldilocks_ext2_swapped_roundtrip",
    run := fun _ => ext2Matches fixtureSwapped
      (goldilocksExt2ElementDecode? (goldilocksExt2ElementEncode fixtureSwapped))
  },
  {
    label := "goldilocks_ext2_add_fixture",
    run := fun _ =>
      ext2ValueMatches (goldilocksExt2Add fixtureElement fixtureSwapped) fixtureAddExpected
  },
  {
    label := "goldilocks_ext2_sub_fixture",
    run := fun _ =>
      ext2ValueMatches (goldilocksExt2Sub fixtureElement fixtureSwapped) fixtureSubExpected
  },
  {
    label := "goldilocks_ext2_neg_fixture",
    run := fun _ =>
      ext2ValueMatches (goldilocksExt2Neg fixtureElement) fixtureNegExpected
  },
  {
    label := "goldilocks_ext2_mul_fixture",
    run := fun _ =>
      ext2ValueMatches (goldilocksExt2Mul fixtureElement fixtureSwapped) fixtureMulExpected
  },
  {
    label := "goldilocks_ext2_denominator_fixture",
    run := fun _ =>
      (goldilocksExt2Denominator fixtureElement).val == fixtureDenominatorExpected.val
  },
  {
    label := "goldilocks_ext2_noncanonical_c0_rejected",
    run := fun _ => optionIsNone (goldilocksExt2ElementDecode? fixtureNonCanonicalC0Bytes)
  },
  {
    label := "goldilocks_ext2_noncanonical_c1_rejected",
    run := fun _ => optionIsNone (goldilocksExt2ElementDecode? fixtureNonCanonicalC1Bytes)
  },
  {
    label := "goldilocks_ext2_wrong_length_rejected",
    run := fun _ => optionIsNone
      (goldilocksExt2ElementDecode? ((goldilocksExt2ElementEncode fixtureElement).take 15))
  },
  {
    label := "cyclotomic_ext2_ring54_encode_width",
    run := fun _ => (swiftCyclotomicExt2Ring54WireEncode fixtureRing).length == phi81Degree * 16
  },
  {
    label := "cyclotomic_ext2_ring54_roundtrip",
    run := fun _ => ringDecodeMatchesFixture
      (swiftCyclotomicExt2Ring54WireDecode?
        (swiftCyclotomicExt2Ring54WireEncode fixtureRing))
  },
  {
    label := "sumcheck_ext2_round_parse_roundtrip",
    run := fun _ => sumcheckRoundParseMatches
      (swiftSumcheckRoundExt2WireParse?
        (swiftSumcheckRoundExt2WireEncode fixtureRound))
  },
  {
    label := "sumcheck_ext2_proof_parse_roundtrip",
    run := fun _ => sumcheckProofParseMatches
      (swiftSumcheckProofExt2WireParse?
        (swiftSumcheckProofExt2WireEncode fixtureSumcheck))
  },
  {
    label := "point_evaluation_ext2_surface_parse_roundtrip",
    run := fun _ => pointSurfaceParseMatches
      (swiftExt2PointEvaluationSurfaceWireParse? fixturePrefixBytes.length
        (swiftExt2PointEvaluationSurfaceWireEncode fixturePointEvaluationSurface))
  }
]

end Ext2

namespace CE

private def fixtureByte (value : Nat) (hValue : value < 256 := by native_decide) : Byte :=
  ⟨value, hValue⟩

private def fixtureField (value : Nat) : Goldilocks :=
  (value : Goldilocks)

private def fixtureInt0 : CESwiftIntWire :=
  ⟨0, by native_decide⟩

private def fixtureInt1 : CESwiftIntWire :=
  ⟨1, by native_decide⟩

private def fixtureDigest (seed : Nat) : Digest256Wire :=
  fun index => fixtureByte ((seed + index.val) % 256) (by omega)

private def fixtureCommitmentA : CEOpeningProofCommitmentsWire where
  maskLinearDigest := fixtureDigest 10
  permutedMaskDigest := fixtureDigest 11
  permutedMaskedWitnessDigest := fixtureDigest 12

private def fixtureCommitmentB : CEOpeningProofCommitmentsWire where
  maskLinearDigest := fixtureDigest 13
  permutedMaskDigest := fixtureDigest 14
  permutedMaskedWitnessDigest := fixtureDigest 15

private def fixtureCommitments : Fin 2 → CEOpeningProofCommitmentsWire
  | ⟨0, _⟩ => fixtureCommitmentA
  | _ => fixtureCommitmentB

private def linearResponse
    (p0 p1 : CESwiftIntWire) (v0 v1 : Nat) : CEOpeningLinearResponseWire 2 where
  permutation := fun index =>
    if index.val = 0 then p0 else p1
  vector := fun index =>
    if index.val = 0 then fixtureField v0 else fixtureField v1

private def normResponse
    (m0 m1 w0 w1 : Nat) : CEOpeningNormResponseWire 2 where
  permutedMask := fun index =>
    if index.val = 0 then fixtureField m0 else fixtureField m1
  permutedWitness := fun index =>
    if index.val = 0 then fixtureField w0 else fixtureField w1

private def maskOpenings : Fin 2 → CEOpeningLinearResponseWire 2
  | ⟨0, _⟩ => linearResponse fixtureInt0 fixtureInt1 7 11
  | _ => linearResponse fixtureInt1 fixtureInt0 13 17

private def maskedWitnessOpenings : Fin 2 → CEOpeningLinearResponseWire 2
  | ⟨0, _⟩ => linearResponse fixtureInt1 fixtureInt1 19 23
  | _ => linearResponse fixtureInt0 fixtureInt0 29 31

private def permutedWitnessOpenings : Fin 2 → CEOpeningNormResponseWire 2
  | ⟨0, _⟩ => normResponse 37 41 43 47
  | _ => normResponse 53 59 61 67

private def hCount2 : 2 < 256 ^ 8 := by native_decide

private def hVector2 : 2 < 256 ^ 8 := by native_decide

private def hOpeningPositive2 : 0 < 2 := by native_decide

private def maskResponse : CEOpeningProofResponseWire 2 2 :=
  .mask maskOpenings

private def maskedWitnessResponse : CEOpeningProofResponseWire 2 2 :=
  .maskedWitness maskedWitnessOpenings

private def permutedWitnessResponse : CEOpeningProofResponseWire 2 2 :=
  .permutedWitness permutedWitnessOpenings

private def maskRound : CEOpeningProofRoundWire 2 2 where
  commitments := fixtureCommitments
  response := maskResponse

private def maskedWitnessRound : CEOpeningProofRoundWire 2 2 where
  commitments := fixtureCommitments
  response := maskedWitnessResponse

private def permutedWitnessRound : CEOpeningProofRoundWire 2 2 where
  commitments := fixtureCommitments
  response := permutedWitnessResponse

private def replaceByte (bytes : List Byte) (offset : Nat) (byte : Byte) : List Byte :=
  bytes.take offset ++ [byte] ++ bytes.drop (offset + 1)

private def maskResponseBytes : List Byte :=
  ceOpeningProofResponseWireEncode hCount2 hVector2 maskResponse

private def wrongRoundCountBytes : List Byte :=
  natCount64Encode 218 (by native_decide)

private def invalidResponseTagBytes : List Byte :=
  replaceByte maskResponseBytes 0 (fixtureByte 9)

private def wrongResponseCountBytes : List Byte :=
  replaceByte maskResponseBytes 1 (fixtureByte 1)

private def digestMatchesSeed (digest : Digest256Wire) (seed : Nat) : Bool :=
  (digest ⟨0, by native_decide⟩).val == seed % 256 &&
    (digest ⟨31, by native_decide⟩).val == (seed + 31) % 256

private def commitmentMatchesA (commitment : CEOpeningProofCommitmentsWire) : Bool :=
  digestMatchesSeed commitment.maskLinearDigest 10 &&
    digestMatchesSeed commitment.permutedMaskDigest 11 &&
    digestMatchesSeed commitment.permutedMaskedWitnessDigest 12

private def linearResponseMatches
    (response : CEOpeningLinearResponseWire 2)
    (p0 p1 v0 v1 : Nat) : Bool :=
  (response.permutation ⟨0, by native_decide⟩).val == p0 &&
    (response.permutation ⟨1, by native_decide⟩).val == p1 &&
    (response.vector ⟨0, by native_decide⟩).val == v0 &&
    (response.vector ⟨1, by native_decide⟩).val == v1

private def normResponseMatches
    (response : CEOpeningNormResponseWire 2)
    (m0 m1 w0 w1 : Nat) : Bool :=
  (response.permutedMask ⟨0, by native_decide⟩).val == m0 &&
    (response.permutedMask ⟨1, by native_decide⟩).val == m1 &&
    (response.permutedWitness ⟨0, by native_decide⟩).val == w0 &&
    (response.permutedWitness ⟨1, by native_decide⟩).val == w1

private def responseMatchesMask : CEOpeningProofResponseWire 2 2 → Bool
  | .mask openings =>
      linearResponseMatches (openings ⟨0, by native_decide⟩) 0 1 7 11 &&
        linearResponseMatches (openings ⟨1, by native_decide⟩) 1 0 13 17
  | _ => false

private def responseMatchesMaskedWitness : CEOpeningProofResponseWire 2 2 → Bool
  | .maskedWitness openings =>
      linearResponseMatches (openings ⟨0, by native_decide⟩) 1 1 19 23 &&
        linearResponseMatches (openings ⟨1, by native_decide⟩) 0 0 29 31
  | _ => false

private def responseMatchesPermutedWitness : CEOpeningProofResponseWire 2 2 → Bool
  | .permutedWitness openings =>
      normResponseMatches (openings ⟨0, by native_decide⟩) 37 41 43 47 &&
        normResponseMatches (openings ⟨1, by native_decide⟩) 53 59 61 67
  | _ => false

private def decodedResponseMatches
    (accepts : CEOpeningProofResponseWire 2 2 → Bool) :
    Option (CEOpeningProofResponseWire 2 2) → Bool
  | some response => accepts response
  | none => false

private def decodedCommitmentMatchesA :
    Option CEOpeningProofCommitmentsWire → Bool
  | some commitment => commitmentMatchesA commitment
  | none => false

private def decodedLinearResponseMatches
    (p0 p1 v0 v1 : Nat) : Option (CEOpeningLinearResponseWire 2) → Bool
  | some response => linearResponseMatches response p0 p1 v0 v1
  | none => false

private def decodedNormResponseMatches
    (m0 m1 w0 w1 : Nat) : Option (CEOpeningNormResponseWire 2) → Bool
  | some response => normResponseMatches response m0 m1 w0 w1
  | none => false

private def decodedRoundMatchesMask :
    Option (CEOpeningProofRoundWire 2 2) → Bool
  | some round =>
      commitmentMatchesA (round.commitments ⟨0, by native_decide⟩) &&
        responseMatchesMask round.response
  | none => false

def vectorLines : List (String × String) := [
  ("ce_response_mask_encode", byteListString (ceOpeningProofResponseWireEncode hCount2 hVector2 maskResponse)),
  ("ce_response_masked_witness_encode", byteListString (ceOpeningProofResponseWireEncode hCount2 hVector2 maskedWitnessResponse)),
  ("ce_response_permuted_witness_encode", byteListString (ceOpeningProofResponseWireEncode hCount2 hVector2 permutedWitnessResponse)),
  ("ce_round_mask_encode", byteListString (ceOpeningProofRoundWireEncode hCount2 hVector2 maskRound)),
  ("ce_round_masked_witness_encode", byteListString (ceOpeningProofRoundWireEncode hCount2 hVector2 maskedWitnessRound)),
  ("ce_round_permuted_witness_encode", byteListString (ceOpeningProofRoundWireEncode hCount2 hVector2 permutedWitnessRound)),
  ("ce_round_width", toString (ceOpeningProofRoundWireLength 2 2))
]

def checks : List CheckCase := [
  {
    label := "ce_response_tags_distinct",
    run := fun _ =>
      (ceOpeningResponseTagEncode CEOpeningResponseTagWire.mask).val !=
        (ceOpeningResponseTagEncode CEOpeningResponseTagWire.maskedWitness).val &&
      (ceOpeningResponseTagEncode CEOpeningResponseTagWire.maskedWitness).val !=
        (ceOpeningResponseTagEncode CEOpeningResponseTagWire.permutedWitness).val &&
      (ceOpeningResponseTagEncode CEOpeningResponseTagWire.mask).val !=
        (ceOpeningResponseTagEncode CEOpeningResponseTagWire.permutedWitness).val
  },
  {
    label := "ce_response_tag_mask_roundtrip",
    run := fun _ =>
      match ceOpeningResponseTagDecode?
        (ceOpeningResponseTagEncode CEOpeningResponseTagWire.mask) with
      | some CEOpeningResponseTagWire.mask => true
      | _ => false
  },
  {
    label := "ce_swift_int_roundtrip",
    run := fun _ =>
      match ceSwiftIntWireDecode? (ceSwiftIntWireEncode fixtureInt1) with
      | some value => value.val == fixtureInt1.val
      | none => false
  },
  {
    label := "ce_commitments_encode_width",
    run := fun _ => (ceOpeningProofCommitmentsWireEncode fixtureCommitmentA).length == 96
  },
  {
    label := "ce_commitments_roundtrip",
    run := fun _ => decodedCommitmentMatchesA
      (ceOpeningProofCommitmentsWireDecode?
        (ceOpeningProofCommitmentsWireEncode fixtureCommitmentA))
  },
  {
    label := "ce_linear_response_roundtrip",
    run := fun _ => decodedLinearResponseMatches 0 1 7 11
      (ceOpeningLinearResponseWireDecode? hVector2
        (ceOpeningLinearResponseWireEncode hVector2
          (linearResponse fixtureInt0 fixtureInt1 7 11)))
  },
  {
    label := "ce_norm_response_roundtrip",
    run := fun _ => decodedNormResponseMatches 37 41 43 47
      (ceOpeningNormResponseWireDecode? hVector2
        (ceOpeningNormResponseWireEncode hVector2 (normResponse 37 41 43 47)))
  },
  {
    label := "ce_response_mask_roundtrip",
    run := fun _ => decodedResponseMatches responseMatchesMask
      (ceOpeningProofResponseWireDecode? hCount2 hVector2
        (ceOpeningProofResponseWireEncode hCount2 hVector2 maskResponse))
  },
  {
    label := "ce_response_masked_witness_roundtrip",
    run := fun _ => decodedResponseMatches responseMatchesMaskedWitness
      (ceOpeningProofResponseWireDecode? hCount2 hVector2
        (ceOpeningProofResponseWireEncode hCount2 hVector2 maskedWitnessResponse))
  },
  {
    label := "ce_response_permuted_witness_roundtrip",
    run := fun _ => decodedResponseMatches responseMatchesPermutedWitness
      (ceOpeningProofResponseWireDecode? hCount2 hVector2
        (ceOpeningProofResponseWireEncode hCount2 hVector2 permutedWitnessResponse))
  },
  {
    label := "ce_round_roundtrip",
    run := fun _ => decodedRoundMatchesMask
      (ceOpeningProofRoundWireDecode? hOpeningPositive2 hCount2 hVector2
        (ceOpeningProofRoundWireEncode hCount2 hVector2 maskRound))
  },
  {
    label := "ce_proof_wrong_round_count_header_rejected",
    run := fun _ => optionIsNone
      (ceOpeningProofWireDecode? hOpeningPositive2 hCount2 hVector2 wrongRoundCountBytes)
  },
  {
    label := "ce_response_invalid_tag_rejected",
    run := fun _ => optionIsNone
      (ceOpeningProofResponseWireDecode? hCount2 hVector2 invalidResponseTagBytes)
  },
  {
    label := "ce_response_wrong_count_rejected",
    run := fun _ => optionIsNone
      (ceOpeningProofResponseWireDecode? hCount2 hVector2 wrongResponseCountBytes)
  }
]

end CE

def vectorLines : List (String × String) :=
  Ext2.vectorLines ++ CE.vectorLines

def checks : List CheckCase :=
  Ext2.checks ++ CE.checks

end VectorChecks
end SuperNeoFormal
