import SuperNeoFormal.CEByteSerialization

/-!
GoldilocksExt2 caller serialization surfaces.

The primitive `GoldilocksExt2` byte grammar is in `Serialization.lean`.  This
module models the higher Swift proof-object layouts that carry Ext2 values:
sum-check rounds/proofs and CCS/CE point-evaluation surfaces.  It is still a
byte grammar layer, not a proof that the executable Swift parser is mechanically
identical.
-/

namespace SuperNeoFormal

def opaqueBytesDecode? (width : Nat) (bytes : List Byte) : Option (List Byte) :=
  if bytes.length = width then
    some bytes
  else
    none

theorem opaqueBytesDecode?_encode (bytes : List Byte) :
    opaqueBytesDecode? bytes.length bytes = some bytes := by
  simp [opaqueBytesDecode?]

theorem opaqueBytesDecode?_none_of_length_ne
    {width : Nat} {bytes : List Byte} (hLength : bytes.length ≠ width) :
    opaqueBytesDecode? width bytes = none := by
  simp [opaqueBytesDecode?, hLength]

theorem parseOpaqueBytes?_encode_append (bytes tail : List Byte) :
    parseFixed? (opaqueBytesDecode? bytes.length) bytes.length (bytes ++ tail) =
      some (bytes, tail) := by
  simp [parseFixed?, opaqueBytesDecode?]

def parseList? {α : Type} (parse : List Byte → Option (α × List Byte)) :
    Nat → List Byte → Option (List α × List Byte)
  | 0, bytes => some ([], bytes)
  | n + 1, bytes =>
      match parse bytes with
      | some (head, rest) =>
          match parseList? parse n rest with
          | some (tail, finalRest) => some (head :: tail, finalRest)
          | none => none
      | none => none

theorem parseList?_encode_append {α : Type}
    {parse : List Byte → Option (α × List Byte)}
    {encode : α → List Byte}
    (hParse : ∀ value tail, parse (encode value ++ tail) = some (value, tail)) :
    ∀ (values : List α) (tail : List Byte),
      parseList? parse values.length (values.flatMap encode ++ tail) =
        some (values, tail)
  | [], tail => by
      simp [parseList?]
  | value :: rest, tail => by
      have hTail := parseList?_encode_append hParse rest tail
      simp [parseList?, hParse, hTail]

theorem parseList?_encode_append_of_mem {α : Type}
    {parse : List Byte → Option (α × List Byte)}
    {encode : α → List Byte} :
    ∀ (values : List α),
      (∀ value, value ∈ values →
        ∀ tail, parse (encode value ++ tail) = some (value, tail)) →
      ∀ tail,
        parseList? parse values.length (values.flatMap encode ++ tail) =
          some (values, tail)
  | [], _hParse, tail => by
      simp [parseList?]
  | value :: rest, hParse, tail => by
      have hHead : parse (encode value ++ (rest.flatMap encode ++ tail)) =
          some (value, rest.flatMap encode ++ tail) :=
        hParse value (by simp) (rest.flatMap encode ++ tail)
      have hTail :=
        parseList?_encode_append_of_mem
          rest
          (by
            intro item hMem itemTail
            exact hParse item (by simp [hMem]) itemTail)
          tail
      simp [parseList?, hHead, hTail]

def countedListEncode
    {α : Type}
    (encode : α → List Byte)
    (count : UInt64LE)
    (values : List α) : List Byte :=
  uint64LEEncode count ++ values.flatMap encode

def countedFixedListParse?
    {α : Type}
    (decode : List Byte → Option α)
    (width : Nat)
    (bytes : List Byte) : Option (UInt64LE × List α × List Byte) := do
  let (count, rest) ← parseFixed? (uintLEDecode? 8) 8 bytes
  let (values, finalRest) ← parseList? (parseFixed? decode width) count.val rest
  some (count, values, finalRest)

theorem countedFixedListParse?_encode_append
    {α : Type}
    {encode : α → List Byte}
    {decode : List Byte → Option α}
    {width : Nat}
    (hLen : ∀ value, (encode value).length = width)
    (hRoundTrip : ∀ value, decode (encode value) = some value)
    (count : UInt64LE)
    (values : List α)
    (hCount : count.val = values.length)
    (tail : List Byte) :
    countedFixedListParse? decode width
      (countedListEncode encode count values ++ tail) =
        some (count, values, tail) := by
  rw [countedFixedListParse?, countedListEncode]
  have hCountParse :
      parseFixed? (uintLEDecode? 8) 8
        (uint64LEEncode count ++ values.flatMap encode ++ tail) =
          some (count, values.flatMap encode ++ tail) := by
    simpa [List.append_assoc] using parseFixed?_encode_append
      uint64LEEncode_length
      (fun value => uintLEDecode?_encode 8 value)
      count
      (values.flatMap encode ++ tail)
  rw [hCountParse]
  have hList :=
    parseList?_encode_append
      (parse := parseFixed? decode width)
      (encode := encode)
      (by
        intro value tail
        exact parseFixed?_encode_append hLen hRoundTrip value tail)
      values tail
  simp [hCount, hList]

def countedDynamicListParse?
    {α : Type}
    (parse : List Byte → Option (α × List Byte))
    (bytes : List Byte) : Option (UInt64LE × List α × List Byte) := do
  let (count, rest) ← parseFixed? (uintLEDecode? 8) 8 bytes
  let (values, finalRest) ← parseList? parse count.val rest
  some (count, values, finalRest)

theorem countedDynamicListParse?_encode_append
    {α : Type}
    {parse : List Byte → Option (α × List Byte)}
    {encode : α → List Byte}
    (count : UInt64LE)
    (values : List α)
    (hCount : count.val = values.length)
    (hParse :
      ∀ value, value ∈ values →
        ∀ tail, parse (encode value ++ tail) = some (value, tail))
    (tail : List Byte) :
    countedDynamicListParse? parse
      (countedListEncode encode count values ++ tail) =
        some (count, values, tail) := by
  rw [countedDynamicListParse?, countedListEncode]
  have hCountParse :
      parseFixed? (uintLEDecode? 8) 8
        (uint64LEEncode count ++ values.flatMap encode ++ tail) =
          some (count, values.flatMap encode ++ tail) := by
    simpa [List.append_assoc] using parseFixed?_encode_append
      uint64LEEncode_length
      (fun value => uintLEDecode?_encode 8 value)
      count
      (values.flatMap encode ++ tail)
  rw [hCountParse]
  have hList := parseList?_encode_append_of_mem values hParse tail
  simp [hCount, hList]

structure SwiftGoldilocksExt2VectorWire where
  count : UInt64LE
  values : List GoldilocksExt2
  deriving DecidableEq

def swiftGoldilocksExt2VectorWireEncode
    (vector : SwiftGoldilocksExt2VectorWire) : List Byte :=
  countedListEncode goldilocksExt2ElementEncode vector.count vector.values

def swiftGoldilocksExt2VectorWireParse?
    (bytes : List Byte) : Option (UInt64LE × List GoldilocksExt2 × List Byte) :=
  countedFixedListParse? goldilocksExt2ElementDecode? 16 bytes

theorem swiftGoldilocksExt2VectorWireParse?_encode_append
    (vector : SwiftGoldilocksExt2VectorWire)
    (hCount : vector.count.val = vector.values.length)
    (tail : List Byte) :
    swiftGoldilocksExt2VectorWireParse?
      (swiftGoldilocksExt2VectorWireEncode vector ++ tail) =
        some (vector.count, vector.values, tail) := by
  exact countedFixedListParse?_encode_append
    goldilocksExt2ElementEncode_length
    goldilocksExt2ElementDecode?_encode
    vector.count
    vector.values
    hCount
    tail

structure SwiftCyclotomicExt2Ring54VectorWire where
  count : UInt64LE
  values : List Phi81Ext2Coefficients
  deriving DecidableEq

def swiftCyclotomicExt2Ring54WireEncode
    (ring : Phi81Ext2Coefficients) : List Byte :=
  phi81Ext2CoefficientsWireEncode ring

def swiftCyclotomicExt2Ring54WireDecode?
    (bytes : List Byte) : Option Phi81Ext2Coefficients :=
  phi81Ext2CoefficientsWireDecode? bytes

theorem swiftCyclotomicExt2Ring54WireDecode?_encode
    (ring : Phi81Ext2Coefficients) :
    swiftCyclotomicExt2Ring54WireDecode?
      (swiftCyclotomicExt2Ring54WireEncode ring) = some ring := by
  exact phi81Ext2CoefficientsWireDecode?_encode ring

def swiftCyclotomicExt2Ring54VectorWireEncode
    (vector : SwiftCyclotomicExt2Ring54VectorWire) : List Byte :=
  countedListEncode swiftCyclotomicExt2Ring54WireEncode vector.count vector.values

def swiftCyclotomicExt2Ring54VectorWireParse?
    (bytes : List Byte) :
    Option (UInt64LE × List Phi81Ext2Coefficients × List Byte) :=
  countedFixedListParse?
    swiftCyclotomicExt2Ring54WireDecode?
    (phi81Degree * 16)
    bytes

theorem swiftCyclotomicExt2Ring54VectorWireParse?_encode_append
    (vector : SwiftCyclotomicExt2Ring54VectorWire)
    (hCount : vector.count.val = vector.values.length)
    (tail : List Byte) :
    swiftCyclotomicExt2Ring54VectorWireParse?
      (swiftCyclotomicExt2Ring54VectorWireEncode vector ++ tail) =
        some (vector.count, vector.values, tail) := by
  exact countedFixedListParse?_encode_append
    phi81Ext2CoefficientsWireEncode_length
    swiftCyclotomicExt2Ring54WireDecode?_encode
    vector.count
    vector.values
    hCount
    tail

structure SwiftSumcheckRoundExt2Wire where
  coeffCount : UInt64LE
  coefficients : List GoldilocksExt2
  deriving DecidableEq

def swiftSumcheckRoundExt2WireEncode
    (round : SwiftSumcheckRoundExt2Wire) : List Byte :=
  countedListEncode goldilocksExt2ElementEncode round.coeffCount round.coefficients

def swiftSumcheckRoundExt2WireParse?
    (bytes : List Byte) : Option (SwiftSumcheckRoundExt2Wire × List Byte) := do
  let (count, coefficients, rest) ← swiftGoldilocksExt2VectorWireParse? bytes
  some ({ coeffCount := count, coefficients := coefficients }, rest)

theorem swiftSumcheckRoundExt2WireParse?_encode_append
    (round : SwiftSumcheckRoundExt2Wire)
    (hCount : round.coeffCount.val = round.coefficients.length)
    (tail : List Byte) :
    swiftSumcheckRoundExt2WireParse?
      (swiftSumcheckRoundExt2WireEncode round ++ tail) =
        some (round, tail) := by
  rw [swiftSumcheckRoundExt2WireParse?, swiftSumcheckRoundExt2WireEncode]
  have hVector :
      swiftGoldilocksExt2VectorWireParse?
        (countedListEncode goldilocksExt2ElementEncode round.coeffCount round.coefficients ++
          tail) =
            some (round.coeffCount, round.coefficients, tail) :=
    swiftGoldilocksExt2VectorWireParse?_encode_append
      { count := round.coeffCount, values := round.coefficients }
      hCount
      tail
  rw [hVector]
  cases round
  rfl

structure SwiftSumcheckProofExt2Wire where
  claimedSum : GoldilocksExt2
  roundCount : UInt64LE
  rounds : List SwiftSumcheckRoundExt2Wire
  finalPointCount : UInt64LE
  finalPoint : List GoldilocksExt2
  finalValue : GoldilocksExt2
  deriving DecidableEq

def swiftSumcheckProofExt2WireEncode
    (proof : SwiftSumcheckProofExt2Wire) : List Byte :=
  goldilocksExt2ElementEncode proof.claimedSum ++
    countedListEncode swiftSumcheckRoundExt2WireEncode proof.roundCount proof.rounds ++
    countedListEncode goldilocksExt2ElementEncode proof.finalPointCount proof.finalPoint ++
    goldilocksExt2ElementEncode proof.finalValue

def swiftSumcheckProofExt2WireParse?
    (bytes : List Byte) : Option (SwiftSumcheckProofExt2Wire × List Byte) := do
  let (claimedSum, afterClaimedSum) ←
    parseFixed? goldilocksExt2ElementDecode? 16 bytes
  let (roundCount, rounds, afterRounds) ←
    countedDynamicListParse? swiftSumcheckRoundExt2WireParse? afterClaimedSum
  let (finalPointCount, finalPoint, afterFinalPoint) ←
    swiftGoldilocksExt2VectorWireParse? afterRounds
  let (finalValue, rest) ←
    parseFixed? goldilocksExt2ElementDecode? 16 afterFinalPoint
  some ({
    claimedSum := claimedSum,
    roundCount := roundCount,
    rounds := rounds,
    finalPointCount := finalPointCount,
    finalPoint := finalPoint,
    finalValue := finalValue
  }, rest)

structure SwiftExt2PointEvaluationSurfaceWire where
  prefixBytes : List Byte
  pointCount : UInt64LE
  point : List GoldilocksExt2
  evaluationCount : UInt64LE
  evaluations : List Phi81Ext2Coefficients
  deriving DecidableEq

def swiftExt2PointEvaluationSurfaceWireEncode
    (surface : SwiftExt2PointEvaluationSurfaceWire) : List Byte :=
  surface.prefixBytes ++
    countedListEncode goldilocksExt2ElementEncode surface.pointCount surface.point ++
    countedListEncode swiftCyclotomicExt2Ring54WireEncode
      surface.evaluationCount
      surface.evaluations

def swiftExt2PointEvaluationSurfaceWireParse?
    (prefixWidth : Nat)
    (bytes : List Byte) :
    Option (SwiftExt2PointEvaluationSurfaceWire × List Byte) := do
  let (prefixBytes, afterPrefix) ←
    parseFixed? (opaqueBytesDecode? prefixWidth) prefixWidth bytes
  let (pointCount, point, afterPoint) ←
    swiftGoldilocksExt2VectorWireParse? afterPrefix
  let (evaluationCount, evaluations, rest) ←
    swiftCyclotomicExt2Ring54VectorWireParse? afterPoint
  some ({
    prefixBytes := prefixBytes,
    pointCount := pointCount,
    point := point,
    evaluationCount := evaluationCount,
    evaluations := evaluations
  }, rest)

abbrev SwiftCCSEvaluationClaimExt2SurfaceWire :=
  SwiftExt2PointEvaluationSurfaceWire

def swiftCCSEvaluationClaimExt2SurfaceWireEncode :
    SwiftCCSEvaluationClaimExt2SurfaceWire → List Byte :=
  swiftExt2PointEvaluationSurfaceWireEncode

def swiftCCSEvaluationClaimExt2SurfaceWireParse? :
    Nat → List Byte → Option (SwiftCCSEvaluationClaimExt2SurfaceWire × List Byte) :=
  swiftExt2PointEvaluationSurfaceWireParse?

abbrev SwiftCEInstanceExt2SurfaceWire :=
  SwiftExt2PointEvaluationSurfaceWire

def swiftCEInstanceExt2SurfaceWireEncode :
    SwiftCEInstanceExt2SurfaceWire → List Byte :=
  swiftExt2PointEvaluationSurfaceWireEncode

def swiftCEInstanceExt2SurfaceWireParse? :
    Nat → List Byte → Option (SwiftCEInstanceExt2SurfaceWire × List Byte) :=
  swiftExt2PointEvaluationSurfaceWireParse?

end SuperNeoFormal
