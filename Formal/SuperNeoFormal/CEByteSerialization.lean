import SuperNeoFormal.Serialization
import SuperNeoFormal.TerminalCEConcreteSpecialSoundness
import SuperNeoFormal.TerminalCEVerifierSemantics

/-!
CE opening proof byte grammar.

This module models the Swift `CEOpeningProof` wire grammar: digest triples,
challenge-tagged response payloads, fixed round count, and count-delimited
vectors.  It is intentionally a parser/serialization layer only.  The future
byte-for-byte CE verifier theorem must still connect decoded proofs to
`TerminalCEVerifierTraceAccepts`.
-/

namespace SuperNeoFormal

def ceOpeningProofRoundCount : Nat :=
  226

theorem ceOpeningProofRoundCount_eq :
    ceOpeningProofRoundCount = 226 := by
  rfl

def natUInt64LE (value : Nat) (hValue : value < 256 ^ 8) : UInt64LE :=
  ⟨value, hValue⟩

def natCount64Encode (value : Nat) (hValue : value < 256 ^ 8) : List Byte :=
  uint64LEEncode (natUInt64LE value hValue)

theorem natCount64Encode_length (value : Nat) (hValue : value < 256 ^ 8) :
    (natCount64Encode value hValue).length = 8 := by
  simp [natCount64Encode, uint64LEEncode_length]

def natCount64DecodeEq? (expected : Nat) (bytes : List Byte) : Option Unit :=
  match uintLEDecode? 8 bytes with
  | some value =>
      if value.val = expected then
        some ()
      else
        none
  | none => none

theorem natCount64DecodeEq?_encode
    (value : Nat) (hValue : value < 256 ^ 8) :
    natCount64DecodeEq? value (natCount64Encode value hValue) = some () := by
  simp [natCount64DecodeEq?, natCount64Encode, natUInt64LE, uint64LEEncode,
    uintLEDecode?_encode]

theorem natCount64DecodeEq?_none_of_length_ne
    {expected : Nat} {bytes : List Byte} (hLength : bytes.length ≠ 8) :
    natCount64DecodeEq? expected bytes = none := by
  simp [natCount64DecodeEq?, uintLEDecode?, hLength]

def parseFixed? {α : Type} (decode : List Byte → Option α) (width : Nat)
    (bytes : List Byte) : Option (α × List Byte) :=
  match decode (bytes.take width) with
  | some value => some (value, bytes.drop width)
  | none => none

theorem parseFixed?_encode_append {α : Type}
    {encode : α → List Byte} {decode : List Byte → Option α} {width : Nat}
    (hLen : ∀ value, (encode value).length = width)
    (hRoundTrip : ∀ value, decode (encode value) = some value)
    (value : α) (tail : List Byte) :
    parseFixed? decode width (encode value ++ tail) = some (value, tail) := by
  simp [parseFixed?, hLen, hRoundTrip]

def parseCountEq? (expected : Nat) (bytes : List Byte) :
    Option (Unit × List Byte) :=
  parseFixed? (natCount64DecodeEq? expected) 8 bytes

theorem parseCountEq?_encode_append
    (value : Nat) (hValue : value < 256 ^ 8) (tail : List Byte) :
    parseCountEq? value (natCount64Encode value hValue ++ tail) =
      some ((), tail) := by
  exact parseFixed?_encode_append
    (fun _ => natCount64Encode_length value hValue)
    (fun _ => natCount64DecodeEq?_encode value hValue)
    () tail

def parseVector? {α : Type} (decode : List Byte → Option α) (width : Nat) :
    {n : Nat} → List Byte → Option ((Fin n → α) × List Byte)
  | 0, bytes => some (fun index => Fin.elim0 index, bytes)
  | n + 1, bytes =>
      match parseFixed? decode width bytes with
      | some (head, rest) =>
          match parseVector? decode width (n := n) rest with
          | some (tail, finalRest) => some (Fin.cases head tail, finalRest)
          | none => none
      | none => none

theorem parseVector?_encode_append {α : Type}
    {encode : α → List Byte} {decode : List Byte → Option α} {width : Nat}
    (hLen : ∀ value, (encode value).length = width)
    (hRoundTrip : ∀ value, decode (encode value) = some value) :
    ∀ {n : Nat} (values : Fin n → α) (tail : List Byte),
      parseVector? decode width (n := n) (finVectorEncode encode values ++ tail) =
        some (values, tail)
  | 0, values, tail => by
      simp [finVectorEncode, parseVector?]
      funext index
      exact Fin.elim0 index
  | n + 1, values, tail => by
      have hTail :=
        parseVector?_encode_append hLen hRoundTrip
          (fun index : Fin n => values index.succ) tail
      simp [finVectorEncode, parseVector?, parseFixed?_encode_append hLen hRoundTrip,
        hTail]
      funext index
      cases index using Fin.cases with
      | zero => simp
      | succ index => simp

def exactParse? {α : Type} (parse : List Byte → Option (α × List Byte))
    (bytes : List Byte) : Option α :=
  match parse bytes with
  | some (value, []) => some value
  | _ => none

theorem exactParse?_encode {α : Type}
    {parse : List Byte → Option (α × List Byte)}
    {encode : α → List Byte}
    (hParse : ∀ value tail, parse (encode value ++ tail) = some (value, tail))
    (value : α) :
    exactParse? parse (encode value) = some value := by
  change (match parse (encode value) with
    | some (value, []) => some value
    | _ => none) = some value
  rw [show encode value = encode value ++ [] by simp]
  rw [hParse value []]

inductive CEOpeningResponseTagWire where
  | mask
  | maskedWitness
  | permutedWitness
  deriving DecidableEq

def ceOpeningResponseTagEncode : CEOpeningResponseTagWire → Byte
  | .mask => byteOfNat 0 (by native_decide)
  | .maskedWitness => byteOfNat 1 (by native_decide)
  | .permutedWitness => byteOfNat 2 (by native_decide)

theorem ceOpeningResponseTagEncode_injective :
    Function.Injective ceOpeningResponseTagEncode := by
  intro lhs rhs h
  cases lhs <;> cases rhs <;> simp [ceOpeningResponseTagEncode, byteOfNat] at h ⊢

def ceOpeningResponseTagDecode? (byte : Byte) : Option CEOpeningResponseTagWire :=
  if byte = ceOpeningResponseTagEncode .mask then
    some .mask
  else if byte = ceOpeningResponseTagEncode .maskedWitness then
    some .maskedWitness
  else if byte = ceOpeningResponseTagEncode .permutedWitness then
    some .permutedWitness
  else
    none

theorem ceOpeningResponseTagDecode?_encode
    (tag : CEOpeningResponseTagWire) :
    ceOpeningResponseTagDecode? (ceOpeningResponseTagEncode tag) = some tag := by
  cases tag <;> simp [ceOpeningResponseTagDecode?, ceOpeningResponseTagEncode, byteOfNat]

def ceOpeningResponseTagListDecode? : List Byte → Option CEOpeningResponseTagWire
  | [byte] => ceOpeningResponseTagDecode? byte
  | _ => none

theorem ceOpeningResponseTagListDecode?_encode
    (tag : CEOpeningResponseTagWire) :
    ceOpeningResponseTagListDecode? [ceOpeningResponseTagEncode tag] = some tag := by
  simp [ceOpeningResponseTagListDecode?, ceOpeningResponseTagDecode?_encode]

theorem ceOpeningResponseTagParse?_encode_append
    (tag : CEOpeningResponseTagWire) (tail : List Byte) :
    parseFixed? ceOpeningResponseTagListDecode? 1
      ([ceOpeningResponseTagEncode tag] ++ tail) = some (tag, tail) := by
  exact parseFixed?_encode_append
    (encode := fun tag => [ceOpeningResponseTagEncode tag])
    (decode := ceOpeningResponseTagListDecode?)
    (width := 1)
    (fun _ => by simp)
    ceOpeningResponseTagListDecode?_encode
    tag tail

theorem ceOpeningResponseTagParse?_encode_cons
    (tag : CEOpeningResponseTagWire) (tail : List Byte) :
    parseFixed? ceOpeningResponseTagListDecode? 1
      (ceOpeningResponseTagEncode tag :: tail) = some (tag, tail) := by
  simpa using ceOpeningResponseTagParse?_encode_append tag tail

def ceOpeningResponseTagSymbol : CEOpeningResponseTagWire → CEOpeningChallengeSymbol
  | .mask => ⟨0, by native_decide⟩
  | .maskedWitness => ⟨1, by native_decide⟩
  | .permutedWitness => ⟨2, by native_decide⟩

def ceOpeningResponseTagChallenge
    (tag : CEOpeningResponseTagWire) : CEOpeningVerifierChallenge :=
  ceOpeningChallengeFromSymbol (ceOpeningResponseTagSymbol tag)

theorem ceOpeningResponseTagChallenge_cases :
    ceOpeningResponseTagChallenge .mask = CEOpeningVerifierChallenge.mask ∧
      ceOpeningResponseTagChallenge .maskedWitness =
        CEOpeningVerifierChallenge.maskedWitness ∧
      ceOpeningResponseTagChallenge .permutedWitness =
        CEOpeningVerifierChallenge.permutedWitness := by
  native_decide

theorem ceOpeningResponseTagChallenge_mem_domain
    (tag : CEOpeningResponseTagWire) :
    ceOpeningResponseTagChallenge tag ∈ CEOpeningChallengeDomain := by
  exact ceOpeningChallengeFromSymbol_mem_domain (ceOpeningResponseTagSymbol tag)

abbrev CESwiftIntWire :=
  Fin (2 ^ 63)

def ceSwiftIntWireToUInt64 (value : CESwiftIntWire) : UInt64LE :=
  ⟨value.val, by
    have hBound : 2 ^ 63 < 256 ^ 8 := by native_decide
    exact value.isLt.trans hBound⟩

def ceSwiftIntWireEncode (value : CESwiftIntWire) : List Byte :=
  uint64LEEncode (ceSwiftIntWireToUInt64 value)

theorem ceSwiftIntWireEncode_length (value : CESwiftIntWire) :
    (ceSwiftIntWireEncode value).length = 8 := by
  simp [ceSwiftIntWireEncode, uint64LEEncode_length]

def ceSwiftIntWireDecode? (bytes : List Byte) : Option CESwiftIntWire :=
  match uintLEDecode? 8 bytes with
  | some value =>
      if hValue : value.val < 2 ^ 63 then
        some ⟨value.val, hValue⟩
      else
        none
  | none => none

theorem ceSwiftIntWireDecode?_encode (value : CESwiftIntWire) :
    ceSwiftIntWireDecode? (ceSwiftIntWireEncode value) = some value := by
  simp [ceSwiftIntWireDecode?, ceSwiftIntWireEncode, uint64LEEncode,
    uintLEDecode?_encode, ceSwiftIntWireToUInt64]

theorem ceSwiftIntWireDecode?_none_of_length_ne
    {bytes : List Byte} (hLength : bytes.length ≠ 8) :
    ceSwiftIntWireDecode? bytes = none := by
  simp [ceSwiftIntWireDecode?, uintLEDecode?, hLength]

theorem ceSwiftIntWireDecode?_uint64Encode_of_ge_intMax
    (value : UInt64LE) (hValue : 2 ^ 63 ≤ value.val) :
    ceSwiftIntWireDecode? (uint64LEEncode value) = none := by
  have hValue' : ¬ value.val < 9223372036854775808 := by
    have hPow : (9223372036854775808 : Nat) = 2 ^ 63 := by norm_num
    rw [hPow]
    exact Nat.not_lt.mpr hValue
  simp [ceSwiftIntWireDecode?, uint64LEEncode, uintLEDecode?_encode, hValue']

structure CEOpeningProofCommitmentsWire where
  maskLinearDigest : Digest256Wire
  permutedMaskDigest : Digest256Wire
  permutedMaskedWitnessDigest : Digest256Wire
  deriving DecidableEq

def ceOpeningProofCommitmentsWireEncode
    (commitments : CEOpeningProofCommitmentsWire) : List Byte :=
  digest256Encode commitments.maskLinearDigest ++
    digest256Encode commitments.permutedMaskDigest ++
    digest256Encode commitments.permutedMaskedWitnessDigest

theorem ceOpeningProofCommitmentsWireEncode_length
    (commitments : CEOpeningProofCommitmentsWire) :
    (ceOpeningProofCommitmentsWireEncode commitments).length = 96 := by
  simp [ceOpeningProofCommitmentsWireEncode, digest256Encode_length]

def ceOpeningProofCommitmentsWireParse?
    (bytes : List Byte) : Option (CEOpeningProofCommitmentsWire × List Byte) := do
  let (maskLinearDigest, rest) ← parseFixed? digest256Decode? 32 bytes
  let (permutedMaskDigest, rest) ← parseFixed? digest256Decode? 32 rest
  let (permutedMaskedWitnessDigest, rest) ← parseFixed? digest256Decode? 32 rest
  some ({
    maskLinearDigest := maskLinearDigest
    permutedMaskDigest := permutedMaskDigest
    permutedMaskedWitnessDigest := permutedMaskedWitnessDigest
  }, rest)

theorem ceOpeningProofCommitmentsWireParse?_encode_append
    (commitments : CEOpeningProofCommitmentsWire) (tail : List Byte) :
    ceOpeningProofCommitmentsWireParse?
      (ceOpeningProofCommitmentsWireEncode commitments ++ tail) =
        some (commitments, tail) := by
  cases commitments
  simp [ceOpeningProofCommitmentsWireParse?, ceOpeningProofCommitmentsWireEncode,
    parseFixed?_encode_append digest256Encode_length digest256Decode?_encode]

def ceOpeningProofCommitmentsWireDecode?
    (bytes : List Byte) : Option CEOpeningProofCommitmentsWire :=
  exactParse? ceOpeningProofCommitmentsWireParse? bytes

theorem ceOpeningProofCommitmentsWireDecode?_encode
    (commitments : CEOpeningProofCommitmentsWire) :
    ceOpeningProofCommitmentsWireDecode?
      (ceOpeningProofCommitmentsWireEncode commitments) = some commitments := by
  exact exactParse?_encode ceOpeningProofCommitmentsWireParse?_encode_append commitments

structure CEOpeningLinearResponseWire (vectorLength : Nat) where
  permutation : Fin vectorLength → CESwiftIntWire
  vector : Fin vectorLength → Goldilocks
  deriving DecidableEq

def ceOpeningLinearResponseWireLength (vectorLength : Nat) : Nat :=
  16 + vectorLength * 16

def ceOpeningLinearResponseWireEncode {vectorLength : Nat}
    (hVectorLength : vectorLength < 256 ^ 8)
    (response : CEOpeningLinearResponseWire vectorLength) : List Byte :=
  natCount64Encode vectorLength hVectorLength ++
    finVectorEncode ceSwiftIntWireEncode response.permutation ++
    natCount64Encode vectorLength hVectorLength ++
    finVectorEncode goldilocksElementEncode response.vector

theorem ceOpeningLinearResponseWireEncode_length {vectorLength : Nat}
    (hVectorLength : vectorLength < 256 ^ 8)
    (response : CEOpeningLinearResponseWire vectorLength) :
    (ceOpeningLinearResponseWireEncode hVectorLength response).length =
      ceOpeningLinearResponseWireLength vectorLength := by
  simp [ceOpeningLinearResponseWireEncode, ceOpeningLinearResponseWireLength,
    natCount64Encode_length, finVectorEncode_length, ceSwiftIntWireEncode_length,
    goldilocksElementEncode_length]
  omega

def ceOpeningLinearResponseWireParse? {vectorLength : Nat}
    (_hVectorLength : vectorLength < 256 ^ 8)
    (bytes : List Byte) : Option (CEOpeningLinearResponseWire vectorLength × List Byte) := do
  let (_, rest) ← parseCountEq? vectorLength bytes
  let (permutation, rest) ←
    parseVector? ceSwiftIntWireDecode? 8 (n := vectorLength) rest
  let (_, rest) ← parseCountEq? vectorLength rest
  let (vector, rest) ←
    parseVector? goldilocksElementDecode? 8 (n := vectorLength) rest
  some ({ permutation := permutation, vector := vector }, rest)

theorem ceOpeningLinearResponseWireParse?_encode_append {vectorLength : Nat}
    (hVectorLength : vectorLength < 256 ^ 8)
    (response : CEOpeningLinearResponseWire vectorLength) (tail : List Byte) :
    ceOpeningLinearResponseWireParse? hVectorLength
      (ceOpeningLinearResponseWireEncode hVectorLength response ++ tail) =
        some (response, tail) := by
  cases response
  simp [ceOpeningLinearResponseWireParse?, ceOpeningLinearResponseWireEncode,
    parseCountEq?_encode_append, parseVector?_encode_append,
    ceSwiftIntWireEncode_length, ceSwiftIntWireDecode?_encode,
    goldilocksElementEncode_length, goldilocksElementDecode?_encode]

def ceOpeningLinearResponseWireDecode? {vectorLength : Nat}
    (hVectorLength : vectorLength < 256 ^ 8)
    (bytes : List Byte) : Option (CEOpeningLinearResponseWire vectorLength) :=
  exactParse? (ceOpeningLinearResponseWireParse? hVectorLength) bytes

theorem ceOpeningLinearResponseWireDecode?_encode {vectorLength : Nat}
    (hVectorLength : vectorLength < 256 ^ 8)
    (response : CEOpeningLinearResponseWire vectorLength) :
    ceOpeningLinearResponseWireDecode? hVectorLength
      (ceOpeningLinearResponseWireEncode hVectorLength response) = some response := by
  exact exactParse?_encode
    (ceOpeningLinearResponseWireParse?_encode_append hVectorLength) response

structure CEOpeningNormResponseWire (vectorLength : Nat) where
  permutedMask : Fin vectorLength → Goldilocks
  permutedWitness : Fin vectorLength → Goldilocks
  deriving DecidableEq

def ceOpeningNormResponseWireLength (vectorLength : Nat) : Nat :=
  16 + vectorLength * 16

def ceOpeningNormResponseWireEncode {vectorLength : Nat}
    (hVectorLength : vectorLength < 256 ^ 8)
    (response : CEOpeningNormResponseWire vectorLength) : List Byte :=
  natCount64Encode vectorLength hVectorLength ++
    finVectorEncode goldilocksElementEncode response.permutedMask ++
    natCount64Encode vectorLength hVectorLength ++
    finVectorEncode goldilocksElementEncode response.permutedWitness

theorem ceOpeningNormResponseWireEncode_length {vectorLength : Nat}
    (hVectorLength : vectorLength < 256 ^ 8)
    (response : CEOpeningNormResponseWire vectorLength) :
    (ceOpeningNormResponseWireEncode hVectorLength response).length =
      ceOpeningNormResponseWireLength vectorLength := by
  simp [ceOpeningNormResponseWireEncode, ceOpeningNormResponseWireLength,
    natCount64Encode_length, finVectorEncode_length, goldilocksElementEncode_length]
  omega

def ceOpeningNormResponseWireParse? {vectorLength : Nat}
    (_hVectorLength : vectorLength < 256 ^ 8)
    (bytes : List Byte) : Option (CEOpeningNormResponseWire vectorLength × List Byte) := do
  let (_, rest) ← parseCountEq? vectorLength bytes
  let (permutedMask, rest) ←
    parseVector? goldilocksElementDecode? 8 (n := vectorLength) rest
  let (_, rest) ← parseCountEq? vectorLength rest
  let (permutedWitness, rest) ←
    parseVector? goldilocksElementDecode? 8 (n := vectorLength) rest
  some ({
    permutedMask := permutedMask
    permutedWitness := permutedWitness
  }, rest)

theorem ceOpeningNormResponseWireParse?_encode_append {vectorLength : Nat}
    (hVectorLength : vectorLength < 256 ^ 8)
    (response : CEOpeningNormResponseWire vectorLength) (tail : List Byte) :
    ceOpeningNormResponseWireParse? hVectorLength
      (ceOpeningNormResponseWireEncode hVectorLength response ++ tail) =
        some (response, tail) := by
  cases response
  simp [ceOpeningNormResponseWireParse?, ceOpeningNormResponseWireEncode,
    parseCountEq?_encode_append, parseVector?_encode_append,
    goldilocksElementEncode_length, goldilocksElementDecode?_encode]

def ceOpeningNormResponseWireDecode? {vectorLength : Nat}
    (hVectorLength : vectorLength < 256 ^ 8)
    (bytes : List Byte) : Option (CEOpeningNormResponseWire vectorLength) :=
  exactParse? (ceOpeningNormResponseWireParse? hVectorLength) bytes

theorem ceOpeningNormResponseWireDecode?_encode {vectorLength : Nat}
    (hVectorLength : vectorLength < 256 ^ 8)
    (response : CEOpeningNormResponseWire vectorLength) :
    ceOpeningNormResponseWireDecode? hVectorLength
      (ceOpeningNormResponseWireEncode hVectorLength response) = some response := by
  exact exactParse?_encode
    (ceOpeningNormResponseWireParse?_encode_append hVectorLength) response

inductive CEOpeningProofResponseWire (openingCount vectorLength : Nat) where
  | mask : (Fin openingCount → CEOpeningLinearResponseWire vectorLength) →
      CEOpeningProofResponseWire openingCount vectorLength
  | maskedWitness : (Fin openingCount → CEOpeningLinearResponseWire vectorLength) →
      CEOpeningProofResponseWire openingCount vectorLength
  | permutedWitness : (Fin openingCount → CEOpeningNormResponseWire vectorLength) →
      CEOpeningProofResponseWire openingCount vectorLength
  deriving DecidableEq

def ceOpeningProofResponseWireLength (openingCount vectorLength : Nat) : Nat :=
  9 + openingCount * ceOpeningLinearResponseWireLength vectorLength

def ceOpeningProofResponseWireEncode {openingCount vectorLength : Nat}
    (hOpeningCount : openingCount < 256 ^ 8)
    (hVectorLength : vectorLength < 256 ^ 8)
    (response : CEOpeningProofResponseWire openingCount vectorLength) : List Byte :=
  match response with
  | .mask openings =>
      [ceOpeningResponseTagEncode .mask] ++
        natCount64Encode openingCount hOpeningCount ++
        finVectorEncode (ceOpeningLinearResponseWireEncode hVectorLength) openings
  | .maskedWitness openings =>
      [ceOpeningResponseTagEncode .maskedWitness] ++
        natCount64Encode openingCount hOpeningCount ++
        finVectorEncode (ceOpeningLinearResponseWireEncode hVectorLength) openings
  | .permutedWitness openings =>
      [ceOpeningResponseTagEncode .permutedWitness] ++
        natCount64Encode openingCount hOpeningCount ++
        finVectorEncode (ceOpeningNormResponseWireEncode hVectorLength) openings

theorem ceOpeningProofResponseWireEncode_length {openingCount vectorLength : Nat}
    (hOpeningCount : openingCount < 256 ^ 8)
    (hVectorLength : vectorLength < 256 ^ 8)
    (response : CEOpeningProofResponseWire openingCount vectorLength) :
    (ceOpeningProofResponseWireEncode hOpeningCount hVectorLength response).length =
      ceOpeningProofResponseWireLength openingCount vectorLength := by
  cases response <;>
    simp [ceOpeningProofResponseWireEncode, ceOpeningProofResponseWireLength,
      natCount64Encode_length, finVectorEncode_length,
      ceOpeningLinearResponseWireEncode_length,
      ceOpeningNormResponseWireEncode_length,
      ceOpeningLinearResponseWireLength, ceOpeningNormResponseWireLength]
    <;> omega

def ceOpeningProofResponseWireParse? {openingCount vectorLength : Nat}
    (_hOpeningCount : openingCount < 256 ^ 8)
    (hVectorLength : vectorLength < 256 ^ 8)
    (bytes : List Byte) :
    Option (CEOpeningProofResponseWire openingCount vectorLength × List Byte) := do
  let (tag, rest) ← parseFixed? ceOpeningResponseTagListDecode? 1 bytes
  let (_, rest) ← parseCountEq? openingCount rest
  match tag with
  | .mask =>
      let (openings, rest) ←
        parseVector? (ceOpeningLinearResponseWireDecode? hVectorLength)
          (ceOpeningLinearResponseWireLength vectorLength)
          (n := openingCount) rest
      some (.mask openings, rest)
  | .maskedWitness =>
      let (openings, rest) ←
        parseVector? (ceOpeningLinearResponseWireDecode? hVectorLength)
          (ceOpeningLinearResponseWireLength vectorLength)
          (n := openingCount) rest
      some (.maskedWitness openings, rest)
  | .permutedWitness =>
      let (openings, rest) ←
        parseVector? (ceOpeningNormResponseWireDecode? hVectorLength)
          (ceOpeningNormResponseWireLength vectorLength)
          (n := openingCount) rest
      some (.permutedWitness openings, rest)

theorem ceOpeningProofResponseWireParse?_encode_append {openingCount vectorLength : Nat}
    (hOpeningCount : openingCount < 256 ^ 8)
    (hVectorLength : vectorLength < 256 ^ 8)
    (response : CEOpeningProofResponseWire openingCount vectorLength)
    (tail : List Byte) :
    ceOpeningProofResponseWireParse? hOpeningCount hVectorLength
      (ceOpeningProofResponseWireEncode hOpeningCount hVectorLength response ++ tail) =
        some (response, tail) := by
  cases response <;>
    simp [ceOpeningProofResponseWireParse?, ceOpeningProofResponseWireEncode,
      ceOpeningResponseTagParse?_encode_cons, parseCountEq?_encode_append,
      parseVector?_encode_append,
      ceOpeningLinearResponseWireEncode_length,
      ceOpeningLinearResponseWireDecode?_encode,
      ceOpeningNormResponseWireEncode_length,
      ceOpeningNormResponseWireDecode?_encode]

def ceOpeningProofResponseWireDecode? {openingCount vectorLength : Nat}
    (hOpeningCount : openingCount < 256 ^ 8)
    (hVectorLength : vectorLength < 256 ^ 8)
    (bytes : List Byte) : Option (CEOpeningProofResponseWire openingCount vectorLength) :=
  exactParse? (ceOpeningProofResponseWireParse? hOpeningCount hVectorLength) bytes

theorem ceOpeningProofResponseWireDecode?_encode {openingCount vectorLength : Nat}
    (hOpeningCount : openingCount < 256 ^ 8)
    (hVectorLength : vectorLength < 256 ^ 8)
    (response : CEOpeningProofResponseWire openingCount vectorLength) :
    ceOpeningProofResponseWireDecode? hOpeningCount hVectorLength
      (ceOpeningProofResponseWireEncode hOpeningCount hVectorLength response) =
        some response := by
  exact exactParse?_encode
    (ceOpeningProofResponseWireParse?_encode_append hOpeningCount hVectorLength)
    response

structure CEOpeningProofRoundWire (openingCount vectorLength : Nat) where
  commitments : Fin openingCount → CEOpeningProofCommitmentsWire
  response : CEOpeningProofResponseWire openingCount vectorLength
  deriving DecidableEq

def ceOpeningProofRoundWireLength (openingCount vectorLength : Nat) : Nat :=
  8 + openingCount * 96 +
    ceOpeningProofResponseWireLength openingCount vectorLength

def ceOpeningProofRoundWireEncode {openingCount vectorLength : Nat}
    (hOpeningCount : openingCount < 256 ^ 8)
    (hVectorLength : vectorLength < 256 ^ 8)
    (round : CEOpeningProofRoundWire openingCount vectorLength) : List Byte :=
  natCount64Encode openingCount hOpeningCount ++
    finVectorEncode ceOpeningProofCommitmentsWireEncode round.commitments ++
    ceOpeningProofResponseWireEncode hOpeningCount hVectorLength round.response

theorem ceOpeningProofRoundWireEncode_length {openingCount vectorLength : Nat}
    (hOpeningCount : openingCount < 256 ^ 8)
    (hVectorLength : vectorLength < 256 ^ 8)
    (round : CEOpeningProofRoundWire openingCount vectorLength) :
    (ceOpeningProofRoundWireEncode hOpeningCount hVectorLength round).length =
      ceOpeningProofRoundWireLength openingCount vectorLength := by
  simp [ceOpeningProofRoundWireEncode, ceOpeningProofRoundWireLength,
    natCount64Encode_length, finVectorEncode_length,
    ceOpeningProofCommitmentsWireEncode_length,
    ceOpeningProofResponseWireEncode_length]
  omega

def ceOpeningProofRoundWireParse? {openingCount vectorLength : Nat}
    (_hOpeningPositive : 0 < openingCount)
    (hOpeningCount : openingCount < 256 ^ 8)
    (hVectorLength : vectorLength < 256 ^ 8)
    (bytes : List Byte) :
    Option (CEOpeningProofRoundWire openingCount vectorLength × List Byte) := do
  let (_, rest) ← parseCountEq? openingCount bytes
  let (commitments, rest) ←
    parseVector? ceOpeningProofCommitmentsWireDecode? 96
      (n := openingCount) rest
  let (response, rest) ←
    ceOpeningProofResponseWireParse? hOpeningCount hVectorLength rest
  some ({ commitments := commitments, response := response }, rest)

theorem ceOpeningProofRoundWireParse?_encode_append {openingCount vectorLength : Nat}
    (hOpeningPositive : 0 < openingCount)
    (hOpeningCount : openingCount < 256 ^ 8)
    (hVectorLength : vectorLength < 256 ^ 8)
    (round : CEOpeningProofRoundWire openingCount vectorLength)
    (tail : List Byte) :
    ceOpeningProofRoundWireParse? hOpeningPositive hOpeningCount hVectorLength
      (ceOpeningProofRoundWireEncode hOpeningCount hVectorLength round ++ tail) =
        some (round, tail) := by
  cases round
  simp [ceOpeningProofRoundWireParse?, ceOpeningProofRoundWireEncode,
    parseCountEq?_encode_append, parseVector?_encode_append,
    ceOpeningProofCommitmentsWireEncode_length,
    ceOpeningProofCommitmentsWireDecode?_encode,
    ceOpeningProofResponseWireParse?_encode_append]

def ceOpeningProofRoundWireDecode? {openingCount vectorLength : Nat}
    (hOpeningPositive : 0 < openingCount)
    (hOpeningCount : openingCount < 256 ^ 8)
    (hVectorLength : vectorLength < 256 ^ 8)
    (bytes : List Byte) : Option (CEOpeningProofRoundWire openingCount vectorLength) :=
  exactParse?
    (ceOpeningProofRoundWireParse? hOpeningPositive hOpeningCount hVectorLength)
    bytes

theorem ceOpeningProofRoundWireDecode?_encode {openingCount vectorLength : Nat}
    (hOpeningPositive : 0 < openingCount)
    (hOpeningCount : openingCount < 256 ^ 8)
    (hVectorLength : vectorLength < 256 ^ 8)
    (round : CEOpeningProofRoundWire openingCount vectorLength) :
    ceOpeningProofRoundWireDecode? hOpeningPositive hOpeningCount hVectorLength
      (ceOpeningProofRoundWireEncode hOpeningCount hVectorLength round) =
        some round := by
  exact exactParse?_encode
    (ceOpeningProofRoundWireParse?_encode_append
      hOpeningPositive hOpeningCount hVectorLength)
    round

structure CEOpeningProofWire (openingCount vectorLength : Nat) where
  rounds : Fin ceOpeningProofRoundCount →
    CEOpeningProofRoundWire openingCount vectorLength
  deriving DecidableEq

def ceOpeningProofWireEncode {openingCount vectorLength : Nat}
    (hOpeningCount : openingCount < 256 ^ 8)
    (hVectorLength : vectorLength < 256 ^ 8)
    (proof : CEOpeningProofWire openingCount vectorLength) : List Byte :=
  natCount64Encode ceOpeningProofRoundCount (by native_decide) ++
    finVectorEncode
      (ceOpeningProofRoundWireEncode hOpeningCount hVectorLength)
      proof.rounds

def ceOpeningProofWireLength (openingCount vectorLength : Nat) : Nat :=
  8 + ceOpeningProofRoundCount *
    ceOpeningProofRoundWireLength openingCount vectorLength

theorem ceOpeningProofWireEncode_length {openingCount vectorLength : Nat}
    (hOpeningCount : openingCount < 256 ^ 8)
    (hVectorLength : vectorLength < 256 ^ 8)
    (proof : CEOpeningProofWire openingCount vectorLength) :
    (ceOpeningProofWireEncode hOpeningCount hVectorLength proof).length =
      ceOpeningProofWireLength openingCount vectorLength := by
  simp [ceOpeningProofWireEncode, ceOpeningProofWireLength,
    natCount64Encode_length, finVectorEncode_length,
    ceOpeningProofRoundWireEncode_length]

def ceOpeningProofWireParse? {openingCount vectorLength : Nat}
    (hOpeningPositive : 0 < openingCount)
    (hOpeningCount : openingCount < 256 ^ 8)
    (hVectorLength : vectorLength < 256 ^ 8)
    (bytes : List Byte) : Option (CEOpeningProofWire openingCount vectorLength × List Byte) := do
  let (_, rest) ← parseCountEq? ceOpeningProofRoundCount bytes
  let (rounds, rest) ←
    parseVector?
      (ceOpeningProofRoundWireDecode?
        hOpeningPositive hOpeningCount hVectorLength)
      (ceOpeningProofRoundWireLength openingCount vectorLength)
      (n := ceOpeningProofRoundCount) rest
  some ({ rounds := rounds }, rest)

theorem ceOpeningProofWireParse?_encode_append {openingCount vectorLength : Nat}
    (hOpeningPositive : 0 < openingCount)
    (hOpeningCount : openingCount < 256 ^ 8)
    (hVectorLength : vectorLength < 256 ^ 8)
    (proof : CEOpeningProofWire openingCount vectorLength)
    (tail : List Byte) :
    ceOpeningProofWireParse? hOpeningPositive hOpeningCount hVectorLength
      (ceOpeningProofWireEncode hOpeningCount hVectorLength proof ++ tail) =
        some (proof, tail) := by
  cases proof
  simp [ceOpeningProofWireParse?, ceOpeningProofWireEncode,
    parseCountEq?_encode_append, parseVector?_encode_append,
    ceOpeningProofRoundWireEncode_length,
    ceOpeningProofRoundWireDecode?_encode]

def ceOpeningProofWireDecode? {openingCount vectorLength : Nat}
    (hOpeningPositive : 0 < openingCount)
    (hOpeningCount : openingCount < 256 ^ 8)
    (hVectorLength : vectorLength < 256 ^ 8)
    (bytes : List Byte) : Option (CEOpeningProofWire openingCount vectorLength) :=
  exactParse?
    (ceOpeningProofWireParse? hOpeningPositive hOpeningCount hVectorLength)
    bytes

theorem ceOpeningProofWireDecode?_encode {openingCount vectorLength : Nat}
    (hOpeningPositive : 0 < openingCount)
    (hOpeningCount : openingCount < 256 ^ 8)
    (hVectorLength : vectorLength < 256 ^ 8)
    (proof : CEOpeningProofWire openingCount vectorLength) :
    ceOpeningProofWireDecode? hOpeningPositive hOpeningCount hVectorLength
      (ceOpeningProofWireEncode hOpeningCount hVectorLength proof) =
        some proof := by
  exact exactParse?_encode
    (ceOpeningProofWireParse?_encode_append
      hOpeningPositive hOpeningCount hVectorLength)
    proof

namespace SwiftCEProof

def decode? {openingCount vectorLength : Nat}
    (hOpeningPositive : 0 < openingCount)
    (hOpeningCount : openingCount < 256 ^ 8)
    (hVectorLength : vectorLength < 256 ^ 8)
    (bytes : List Byte) : Option (CEOpeningProofWire openingCount vectorLength) :=
  ceOpeningProofWireDecode? hOpeningPositive hOpeningCount hVectorLength bytes

end SwiftCEProof

theorem swift_ceProof_decode?_eq_lean {openingCount vectorLength : Nat}
    (hOpeningPositive : 0 < openingCount)
    (hOpeningCount : openingCount < 256 ^ 8)
    (hVectorLength : vectorLength < 256 ^ 8) :
    SwiftCEProof.decode? hOpeningPositive hOpeningCount hVectorLength =
      ceOpeningProofWireDecode? hOpeningPositive hOpeningCount hVectorLength :=
  rfl

def swiftCEProofResponseTag {openingCount vectorLength : Nat}
    (response : CEOpeningProofResponseWire openingCount vectorLength) :
    CEOpeningResponseTagWire :=
  match response with
  | .mask _ => .mask
  | .maskedWitness _ => .maskedWitness
  | .permutedWitness _ => .permutedWitness

def swiftCETranscriptBranch {openingCount vectorLength : Nat}
    (response : CEOpeningProofResponseWire openingCount vectorLength) :
    CEOpeningVerifierChallenge :=
  match response with
  | .mask _ => CEOpeningVerifierChallenge.mask
  | .maskedWitness _ => CEOpeningVerifierChallenge.maskedWitness
  | .permutedWitness _ => CEOpeningVerifierChallenge.permutedWitness

def leanCETranscriptBranch {openingCount vectorLength : Nat}
    (response : CEOpeningProofResponseWire openingCount vectorLength) :
    CEOpeningVerifierChallenge :=
  ceOpeningResponseTagChallenge (swiftCEProofResponseTag response)

theorem swift_ceResponseTag_branch_eq_lean
    (tag : CEOpeningResponseTagWire) :
    ceOpeningResponseTagChallenge tag =
      match tag with
      | .mask => CEOpeningVerifierChallenge.mask
      | .maskedWitness => CEOpeningVerifierChallenge.maskedWitness
      | .permutedWitness => CEOpeningVerifierChallenge.permutedWitness := by
  cases tag <;> native_decide

theorem swift_ceTranscriptBranch_eq_lean {openingCount vectorLength : Nat}
    (response : CEOpeningProofResponseWire openingCount vectorLength) :
    swiftCETranscriptBranch response = leanCETranscriptBranch response := by
  cases response <;>
    simp [swiftCETranscriptBranch, leanCETranscriptBranch, swiftCEProofResponseTag,
      ceOpeningResponseTagChallenge, ceOpeningResponseTagSymbol,
      ceOpeningChallengeFromSymbol]

structure SwiftCEVerifierTrace
    (Commitment Response Witness Seed : Type)
    (roundCount : Nat) where
  terminalTrace : TerminalCEVerifierTrace Commitment Response Witness Seed roundCount
  responseTags : Fin roundCount → CEOpeningResponseTagWire
  responseTags_match :
    ∀ round,
      (terminalTrace.rounds round).challenge =
        ceOpeningResponseTagChallenge (responseTags round)

def SwiftCEVerifierAccepts
    {Commitment Response Witness Seed : Type}
    {roundCount : Nat}
    (trace : SwiftCEVerifierTrace Commitment Response Witness Seed roundCount) :
    Prop :=
  ∀ round,
    (trace.terminalTrace.rounds round).verifierChecks
      (ceOpeningResponseTagChallenge (trace.responseTags round))

theorem swift_ceVerifier_accepts_implies_traceAccepts
    {Commitment Response Witness Seed : Type}
    {roundCount : Nat}
    {trace : SwiftCEVerifierTrace Commitment Response Witness Seed roundCount}
    (hAccepts : SwiftCEVerifierAccepts trace) :
    TerminalCEVerifierTraceAccepts trace.terminalTrace := by
  intro round
  unfold CEOpeningRoundAccepts
  rw [trace.responseTags_match round]
  exact hAccepts round

theorem swift_ceVerifier_accepts_sound_from_concrete_extractor
    {Claim Witness Seed Commitment Response : Type}
    {count roundCount : Nat}
    {trace : SwiftCEVerifierTrace Commitment Response Witness Seed roundCount}
    {statement : TerminalCEStatement Claim count}
    {opens : Claim → Witness → Prop}
    (hAccepts : SwiftCEVerifierAccepts trace)
    (semantics :
      TerminalCEConcreteExtractorSemantics
        trace.terminalTrace
        statement
        opens) :
    TerminalCEVerifierTraceAccepts trace.terminalTrace ∧
      ∃ witnesses : Fin count → Witness,
        TerminalLocalBatchRelation statement witnesses opens :=
  ⟨
    swift_ceVerifier_accepts_implies_traceAccepts hAccepts,
    terminalCEConcrete_extract_batch semantics
  ⟩

end SuperNeoFormal
