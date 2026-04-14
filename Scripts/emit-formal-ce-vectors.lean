import SuperNeoFormal.CEByteSerialization

namespace SuperNeoFormal

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

private def proofRound (index : Fin ceOpeningProofRoundCount) :
    CEOpeningProofRoundWire 2 2 :=
  if index.val % 3 = 0 then
    maskRound
  else if index.val % 3 = 1 then
    maskedWitnessRound
  else
    permutedWitnessRound

private def fixtureProof : CEOpeningProofWire 2 2 where
  rounds := proofRound

private def byteListString (bytes : List Byte) : String :=
  String.intercalate "," (bytes.map fun byte => toString byte.val)

private def branchName : CEOpeningProofResponseWire 2 2 → String
  | .mask _ => "mask"
  | .maskedWitness _ => "maskedWitness"
  | .permutedWitness _ => "permutedWitness"

private def proofDecodeStatus (bytes : List Byte) : String :=
  match ceOpeningProofWireDecode? hOpeningPositive2 hCount2 hVector2 bytes with
  | some proof =>
      "some:rounds=" ++ toString ceOpeningProofRoundCount ++
        ",branches=" ++
        String.intercalate "," [
          branchName (proof.rounds ⟨0, by native_decide⟩).response,
          branchName (proof.rounds ⟨1, by native_decide⟩).response,
          branchName (proof.rounds ⟨2, by native_decide⟩).response
        ]
  | none => "none"

private def replaceByte (bytes : List Byte) (offset : Nat) (byte : Byte) : List Byte :=
  bytes.take offset ++ [byte] ++ bytes.drop (offset + 1)

private def proofBytes : List Byte :=
  ceOpeningProofWireEncode hCount2 hVector2 fixtureProof

private def wrongRoundCountBytes : List Byte :=
  natCount64Encode 218 (by native_decide) ++ proofBytes.drop 8

private def responseTagOffsetInRound : Nat :=
  8 + 2 * 3 * 32

private def firstResponseTagOffset : Nat :=
  8 + responseTagOffsetInRound

private def invalidTagBytes : List Byte :=
  replaceByte proofBytes firstResponseTagOffset (fixtureByte 9)

private def wrongResponseCountBytes : List Byte :=
  replaceByte proofBytes (firstResponseTagOffset + 1) (fixtureByte 1)

private def vectorLines : List (String × String) := [
  ("ce_response_mask_encode", byteListString (ceOpeningProofResponseWireEncode hCount2 hVector2 maskResponse)),
  ("ce_response_masked_witness_encode", byteListString (ceOpeningProofResponseWireEncode hCount2 hVector2 maskedWitnessResponse)),
  ("ce_response_permuted_witness_encode", byteListString (ceOpeningProofResponseWireEncode hCount2 hVector2 permutedWitnessResponse)),
  ("ce_round_mask_encode", byteListString (ceOpeningProofRoundWireEncode hCount2 hVector2 maskRound)),
  ("ce_round_masked_witness_encode", byteListString (ceOpeningProofRoundWireEncode hCount2 hVector2 maskedWitnessRound)),
  ("ce_round_permuted_witness_encode", byteListString (ceOpeningProofRoundWireEncode hCount2 hVector2 permutedWitnessRound)),
  ("ce_round_width", toString (ceOpeningProofRoundWireLength 2 2)),
  ("ce_first_response_tag_offset", toString firstResponseTagOffset),
  ("ce_proof_encode", byteListString proofBytes),
  ("ce_proof_decode_valid", proofDecodeStatus proofBytes),
  ("ce_proof_decode_wrong_round_count", proofDecodeStatus wrongRoundCountBytes),
  ("ce_proof_decode_invalid_tag", proofDecodeStatus invalidTagBytes),
  ("ce_proof_decode_wrong_response_count", proofDecodeStatus wrongResponseCountBytes)
]

end SuperNeoFormal

def main : IO Unit := do
  for (label, value) in SuperNeoFormal.vectorLines do
    IO.println s!"{label}={value}"
