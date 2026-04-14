import Mathlib
import Mathlib.Data.Nat.Digits.Lemmas
import SuperNeoFormal.GoldilocksExt2
import SuperNeoFormal.Phi81

/-!
Framed byte serialization model.

The Swift verifier uses explicit byte framing for proof envelopes, CE opening
digests, transcript absorption, and count-delimited vectors.  This module
formalizes the core byte-level property needed by later transcript work: a
single frame with a fixed-width count field has an injective encoding, and
domain tags make first-frame transcript encodings disjoint.
-/

namespace SuperNeoFormal

abbrev Byte :=
  Fin 256

abbrev Count64LE :=
  Fin 8 → Byte

def byteOfNat (value : Nat) (h : value < 256) : Byte :=
  ⟨value, h⟩

def zeroByte : Byte :=
  byteOfNat 0 (by native_decide)

def domainSeparatorTag : Byte :=
  byteOfNat 1 (by native_decide)

def transcriptPayloadTag : Byte :=
  byteOfNat 2 (by native_decide)

def proofEnvelopeHeaderTag : Byte :=
  byteOfNat 3 (by native_decide)

theorem domainSeparatorTag_ne_transcriptPayloadTag :
    domainSeparatorTag ≠ transcriptPayloadTag := by
  native_decide

theorem domainSeparatorTag_ne_proofEnvelopeHeaderTag :
    domainSeparatorTag ≠ proofEnvelopeHeaderTag := by
  native_decide

def zeroCount64LE : Count64LE :=
  fun _ => zeroByte

def count64Encode (count : Count64LE) : List Byte :=
  List.ofFn count

theorem count64Encode_length (count : Count64LE) :
    (count64Encode count).length = 8 := by
  simp [count64Encode]

theorem count64Encode_injective :
    Function.Injective count64Encode := by
  intro lhs rhs h
  simpa [count64Encode] using (List.ofFn_inj.mp h)

structure FramedBytes where
  tag : Byte
  count : Count64LE
  payload : List Byte

def frameHeader (frame : FramedBytes) : List Byte :=
  frame.tag :: count64Encode frame.count

def frameEncode (frame : FramedBytes) : List Byte :=
  frameHeader frame ++ frame.payload

theorem frameHeader_length (frame : FramedBytes) :
    (frameHeader frame).length = 9 := by
  simp [frameHeader, count64Encode_length]

theorem frameEncode_head_eq (frame : FramedBytes) :
    (frameEncode frame).head? = some frame.tag := by
  simp [frameEncode, frameHeader]

theorem frameEncode_injective :
    Function.Injective frameEncode := by
  intro lhs rhs h
  cases lhs with
  | mk lhsTag lhsCount lhsPayload =>
    cases rhs with
    | mk rhsTag rhsCount rhsPayload =>
      simp [frameEncode, frameHeader] at h ⊢
      rcases h with ⟨hTag, hTail⟩
      have hCountList :
          count64Encode lhsCount = count64Encode rhsCount := by
        have hTake := congrArg (List.take 8) hTail
        simpa [count64Encode] using hTake
      have hPayload :
          lhsPayload = rhsPayload := by
        have hDrop := congrArg (List.drop 8) hTail
        simpa [count64Encode] using hDrop
      exact ⟨hTag, count64Encode_injective hCountList, hPayload⟩

theorem frameEncode_eq_iff (lhs rhs : FramedBytes) :
    frameEncode lhs = frameEncode rhs ↔ lhs = rhs :=
  frameEncode_injective.eq_iff

theorem frameEncode_ne_of_tag_ne {lhs rhs : FramedBytes}
    (hTag : lhs.tag ≠ rhs.tag) :
    frameEncode lhs ≠ frameEncode rhs := by
  intro hEncode
  exact hTag (congrArg FramedBytes.tag (frameEncode_injective hEncode))

def domainFrame (domain : List Byte) : FramedBytes where
  tag := domainSeparatorTag
  count := zeroCount64LE
  payload := domain

def payloadFrame (tag : Byte) (payload : List Byte) : FramedBytes where
  tag := tag
  count := zeroCount64LE
  payload := payload

theorem domainFrame_ne_payloadFrame
    (domain payload : List Byte) :
    frameEncode (domainFrame domain) ≠
      frameEncode (payloadFrame transcriptPayloadTag payload) := by
  apply frameEncode_ne_of_tag_ne
  exact domainSeparatorTag_ne_transcriptPayloadTag

def transcriptEncode : List FramedBytes → List Byte
  | [] => []
  | frame :: rest => frameEncode frame ++ transcriptEncode rest

theorem transcriptEncode_head_eq (frame : FramedBytes) (rest : List FramedBytes) :
    (transcriptEncode (frame :: rest)).head? = some frame.tag := by
  simp [transcriptEncode, frameEncode_head_eq]

theorem transcriptEncode_cons_ne_of_tag_ne
    {lhs rhs : FramedBytes}
    {lhsRest rhsRest : List FramedBytes}
    (hTag : lhs.tag ≠ rhs.tag) :
    transcriptEncode (lhs :: lhsRest) ≠
      transcriptEncode (rhs :: rhsRest) := by
  intro hEncode
  have hHead :=
    congrArg List.head? hEncode
  rw [transcriptEncode_head_eq lhs lhsRest, transcriptEncode_head_eq rhs rhsRest] at hHead
  exact hTag (Option.some.inj hHead)

theorem domainSeparatedTranscript_ne_payloadTranscript
    (domain payload : List Byte)
    (domainRest payloadRest : List FramedBytes) :
    transcriptEncode (domainFrame domain :: domainRest) ≠
      transcriptEncode (payloadFrame transcriptPayloadTag payload :: payloadRest) := by
  apply transcriptEncode_cons_ne_of_tag_ne
  exact domainSeparatorTag_ne_transcriptPayloadTag

/-!
Concrete Swift wire encodings.

These definitions mirror the fixed-width little-endian encodings used by
`SuperNeoByteEncodable` for primitive values and the proof-envelope transcript
binding.  Hash functions are intentionally outside this module; `Digest256Wire`
models already-computed 32-byte digest values.
-/

abbrev UIntLE (width : Nat) :=
  Fin (256 ^ width)

abbrev UInt16LE :=
  UIntLE 2

abbrev UInt32LE :=
  UIntLE 4

abbrev UInt64LE :=
  UIntLE 8

def uintLEEncode (width : Nat) (value : UIntLE width) : List Byte :=
  ((Nat.digits 256 value.val).attach.map fun digit =>
      (⟨digit.val, Nat.digits_lt_base (by norm_num : 1 < 256) digit.property⟩ : Byte)) ++
    List.replicate (width - (Nat.digits 256 value.val).length) zeroByte

theorem uintLEEncode_length (width : Nat) (value : UIntLE width) :
    (uintLEEncode width value).length = width := by
  simp [uintLEEncode]
  have hLen : (Nat.digits 256 value.val).length ≤ width := by
    rw [Nat.digits_length_le_iff (by norm_num : 1 < 256)]
    exact value.isLt
  omega

theorem uintLEEncode_natDigits (width : Nat) (value : UIntLE width) :
    (uintLEEncode width value).map (fun byte => byte.val) =
      Nat.digits 256 value.val ++
        List.replicate (width - (Nat.digits 256 value.val).length) 0 := by
  simp [uintLEEncode, zeroByte, byteOfNat]

theorem uintLEEncode_injective (width : Nat) :
    Function.Injective (uintLEEncode width) := by
  intro lhs rhs h
  apply Fin.ext
  have hNatLists := congrArg (List.map (fun byte : Byte => byte.val)) h
  rw [uintLEEncode_natDigits width lhs, uintLEEncode_natDigits width rhs] at hNatLists
  have hDigits := congrArg (Nat.ofDigits 256) hNatLists
  rw [Nat.ofDigits_append_replicate_zero, Nat.ofDigits_append_replicate_zero,
    Nat.ofDigits_digits, Nat.ofDigits_digits] at hDigits
  exact hDigits

def uintLEDecode? (width : Nat) (bytes : List Byte) : Option (UIntLE width) :=
  if bytes.length = width then
    let value := Nat.ofDigits 256 (bytes.map (fun byte => byte.val))
    if hValue : value < 256 ^ width then
      some ⟨value, hValue⟩
    else
      none
  else
    none

theorem uintLEDecode?_encode (width : Nat) (value : UIntLE width) :
    uintLEDecode? width (uintLEEncode width value) = some value := by
  simp [uintLEDecode?, uintLEEncode_length]
  rw [uintLEEncode_natDigits]
  simp [Nat.ofDigits_append_replicate_zero, Nat.ofDigits_digits]

def uint16LEEncode : UInt16LE → List Byte :=
  uintLEEncode 2

def uint32LEEncode : UInt32LE → List Byte :=
  uintLEEncode 4

def uint64LEEncode : UInt64LE → List Byte :=
  uintLEEncode 8

theorem uint16LEEncode_length (value : UInt16LE) :
    (uint16LEEncode value).length = 2 := by
  simp [uint16LEEncode, uintLEEncode_length]

theorem uint32LEEncode_length (value : UInt32LE) :
    (uint32LEEncode value).length = 4 := by
  simp [uint32LEEncode, uintLEEncode_length]

theorem uint64LEEncode_length (value : UInt64LE) :
    (uint64LEEncode value).length = 8 := by
  simp [uint64LEEncode, uintLEEncode_length]

theorem uint16LEEncode_injective :
    Function.Injective uint16LEEncode :=
  uintLEEncode_injective 2

theorem uint32LEEncode_injective :
    Function.Injective uint32LEEncode :=
  uintLEEncode_injective 4

theorem uint64LEEncode_injective :
    Function.Injective uint64LEEncode :=
  uintLEEncode_injective 8

def count64FromUInt64 (value : UInt64LE) : Count64LE :=
  fun index =>
    (uint64LEEncode value).get
      ⟨index.val, by simp [uint64LEEncode_length, index.isLt]⟩

theorem count64Encode_count64FromUInt64 (value : UInt64LE) :
    count64Encode (count64FromUInt64 value) = uint64LEEncode value := by
  apply List.ext_get
  · simp [count64Encode_length, uint64LEEncode_length]
  · intro index hLeft hRight
    have hIndex : index < 8 := by
      simpa [count64Encode_length] using hLeft
    interval_cases index <;> simp [count64Encode, count64FromUInt64]

def count64Decode? (count : Count64LE) : Option UInt64LE :=
  uintLEDecode? 8 (count64Encode count)

theorem count64Decode?_count64FromUInt64 (value : UInt64LE) :
    count64Decode? (count64FromUInt64 value) = some value := by
  simp [count64Decode?, count64Encode_count64FromUInt64, uint64LEEncode,
    uintLEDecode?_encode]

abbrev Digest256Wire :=
  Fin 32 → Byte

def digest256Encode (digest : Digest256Wire) : List Byte :=
  List.ofFn digest

theorem digest256Encode_length (digest : Digest256Wire) :
    (digest256Encode digest).length = 32 := by
  simp [digest256Encode]

theorem digest256Encode_injective :
    Function.Injective digest256Encode := by
  intro lhs rhs h
  simpa [digest256Encode] using (List.ofFn_inj.mp h)

def fixedVectorDecode? (width : Nat) (bytes : List Byte) : Option (Fin width → Byte) :=
  if hLength : bytes.length = width then
    some (fun index : Fin width =>
      bytes.get ⟨index.val, by simp [hLength, index.isLt]⟩)
  else
    none

theorem fixedVectorDecode?_ofFn (width : Nat) (value : Fin width → Byte) :
    fixedVectorDecode? width (List.ofFn value) = some value := by
  simp [fixedVectorDecode?]

def digest256Decode? (bytes : List Byte) : Option Digest256Wire :=
  fixedVectorDecode? 32 bytes

theorem digest256Decode?_encode (digest : Digest256Wire) :
    digest256Decode? (digest256Encode digest) = some digest := by
  exact fixedVectorDecode?_ofFn 32 digest

abbrev GoldilocksWire :=
  Fin goldilocksModulus

def goldilocksWireToUInt64 (value : GoldilocksWire) : UInt64LE :=
  ⟨value.val, by
    have hMod : goldilocksModulus < 256 ^ 8 := by native_decide
    exact value.isLt.trans hMod⟩

def goldilocksWireEncode (value : GoldilocksWire) : List Byte :=
  uint64LEEncode (goldilocksWireToUInt64 value)

theorem goldilocksWireEncode_length (value : GoldilocksWire) :
    (goldilocksWireEncode value).length = 8 := by
  simp [goldilocksWireEncode, uint64LEEncode_length]

theorem goldilocksWireEncode_injective :
    Function.Injective goldilocksWireEncode := by
  intro lhs rhs h
  have hUInt := uint64LEEncode_injective h
  apply Fin.ext
  simpa [goldilocksWireToUInt64] using congrArg Fin.val hUInt

def goldilocksWireDecode? (bytes : List Byte) : Option GoldilocksWire :=
  match uintLEDecode? 8 bytes with
  | some value =>
      if hValue : value.val < goldilocksModulus then
        some ⟨value.val, hValue⟩
      else
        none
  | none => none

theorem goldilocksWireDecode?_encode (value : GoldilocksWire) :
    goldilocksWireDecode? (goldilocksWireEncode value) = some value := by
  simp [goldilocksWireDecode?, goldilocksWireEncode, uint64LEEncode,
    uintLEDecode?_encode, goldilocksWireToUInt64]

theorem goldilocksWireDecode?_none_of_length_ne {bytes : List Byte}
    (hLength : bytes.length ≠ 8) :
    goldilocksWireDecode? bytes = none := by
  simp [goldilocksWireDecode?, uintLEDecode?, hLength]

theorem goldilocksWireDecode?_uint64Encode_of_ge_modulus
    (value : UInt64LE) (hValue : goldilocksModulus ≤ value.val) :
    goldilocksWireDecode? (uint64LEEncode value) = none := by
  simp [goldilocksWireDecode?, uint64LEEncode, uintLEDecode?_encode,
    Nat.not_lt.mpr hValue]

def goldilocksElementWire (value : Goldilocks) : GoldilocksWire :=
  ⟨value.val, value.2⟩

def goldilocksElementEncode (value : Goldilocks) : List Byte :=
  goldilocksWireEncode (goldilocksElementWire value)

theorem goldilocksElementEncode_length (value : Goldilocks) :
    (goldilocksElementEncode value).length = 8 := by
  simp [goldilocksElementEncode, goldilocksWireEncode_length]

theorem goldilocksElementEncode_injective :
    Function.Injective goldilocksElementEncode := by
  intro lhs rhs h
  have hWire := goldilocksWireEncode_injective h
  have hVal : lhs.val = rhs.val := by
    simpa [goldilocksElementWire] using congrArg Fin.val hWire
  exact ZMod.val_injective goldilocksModulus hVal

def goldilocksElementDecode? (bytes : List Byte) : Option Goldilocks :=
  match goldilocksWireDecode? bytes with
  | some value => some (value.val : Goldilocks)
  | none => none

theorem goldilocksElementDecode?_encode (value : Goldilocks) :
    goldilocksElementDecode? (goldilocksElementEncode value) = some value := by
  simp [goldilocksElementDecode?, goldilocksElementEncode,
    goldilocksWireDecode?_encode, goldilocksElementWire]

theorem goldilocksElementDecode?_none_of_length_ne {bytes : List Byte}
    (hLength : bytes.length ≠ 8) :
    goldilocksElementDecode? bytes = none := by
  simp [goldilocksElementDecode?, goldilocksWireDecode?_none_of_length_ne hLength]

theorem goldilocksElementDecode?_length_of_some
    {bytes : List Byte} {value : Goldilocks}
    (hDecode : goldilocksElementDecode? bytes = some value) :
    bytes.length = 8 := by
  by_contra hLength
  rw [goldilocksElementDecode?_none_of_length_ne hLength] at hDecode
  contradiction

abbrev GoldilocksExt2Wire :=
  Goldilocks × Goldilocks

def goldilocksExt2WireEncode (value : GoldilocksExt2Wire) : List Byte :=
  goldilocksElementEncode value.1 ++ goldilocksElementEncode value.2

theorem goldilocksExt2WireEncode_length (value : GoldilocksExt2Wire) :
    (goldilocksExt2WireEncode value).length = 16 := by
  simp [goldilocksExt2WireEncode, goldilocksElementEncode_length]

theorem goldilocksExt2WireEncode_injective :
    Function.Injective goldilocksExt2WireEncode := by
  intro lhs rhs h
  have hFstBytes : goldilocksElementEncode lhs.1 = goldilocksElementEncode rhs.1 := by
    have hTake := congrArg (List.take 8) h
    simpa [goldilocksExt2WireEncode, goldilocksElementEncode_length] using hTake
  have hSndBytes : goldilocksElementEncode lhs.2 = goldilocksElementEncode rhs.2 := by
    have hDrop := congrArg (List.drop 8) h
    simpa [goldilocksExt2WireEncode, goldilocksElementEncode_length] using hDrop
  exact Prod.ext (goldilocksElementEncode_injective hFstBytes)
    (goldilocksElementEncode_injective hSndBytes)

def goldilocksExt2WireDecode? (bytes : List Byte) : Option GoldilocksExt2Wire :=
  if bytes.length = 16 then
    match goldilocksElementDecode? (bytes.take 8),
        goldilocksElementDecode? (bytes.drop 8) with
    | some c0, some c1 => some (c0, c1)
    | _, _ => none
  else
    none

theorem goldilocksExt2WireDecode?_encode (value : GoldilocksExt2Wire) :
    goldilocksExt2WireDecode? (goldilocksExt2WireEncode value) = some value := by
  simp [goldilocksExt2WireDecode?, goldilocksExt2WireEncode,
    goldilocksElementEncode_length, goldilocksElementDecode?_encode]

theorem goldilocksExt2WireDecode?_none_of_length_ne {bytes : List Byte}
    (hLength : bytes.length ≠ 16) :
    goldilocksExt2WireDecode? bytes = none := by
  simp [goldilocksExt2WireDecode?, hLength]

theorem goldilocksExt2WireDecode?_length_of_some
    {bytes : List Byte} {value : GoldilocksExt2Wire}
    (hDecode : goldilocksExt2WireDecode? bytes = some value) :
    bytes.length = 16 := by
  by_contra hLength
  rw [goldilocksExt2WireDecode?_none_of_length_ne hLength] at hDecode
  contradiction

def goldilocksExt2ElementWire (value : GoldilocksExt2) : GoldilocksExt2Wire :=
  (value.c0, value.c1)

def goldilocksExt2ElementEncode (value : GoldilocksExt2) : List Byte :=
  goldilocksExt2WireEncode (goldilocksExt2ElementWire value)

theorem goldilocksExt2ElementEncode_length (value : GoldilocksExt2) :
    (goldilocksExt2ElementEncode value).length = 16 := by
  simp [goldilocksExt2ElementEncode, goldilocksExt2WireEncode_length]

theorem goldilocksExt2ElementEncode_injective :
    Function.Injective goldilocksExt2ElementEncode := by
  intro lhs rhs h
  have hWire := goldilocksExt2WireEncode_injective h
  cases lhs
  cases rhs
  simp [goldilocksExt2ElementWire] at hWire ⊢
  exact hWire

def goldilocksExt2ElementDecode? (bytes : List Byte) : Option GoldilocksExt2 :=
  match goldilocksExt2WireDecode? bytes with
  | some value => some ⟨value.1, value.2⟩
  | none => none

theorem goldilocksExt2ElementDecode?_encode (value : GoldilocksExt2) :
    goldilocksExt2ElementDecode? (goldilocksExt2ElementEncode value) = some value := by
  cases value
  simp [goldilocksExt2ElementDecode?, goldilocksExt2ElementEncode,
    goldilocksExt2ElementWire, goldilocksExt2WireDecode?_encode]

theorem goldilocksExt2ElementDecode?_none_of_length_ne {bytes : List Byte}
    (hLength : bytes.length ≠ 16) :
    goldilocksExt2ElementDecode? bytes = none := by
  simp [goldilocksExt2ElementDecode?, goldilocksExt2WireDecode?_none_of_length_ne hLength]

theorem goldilocksExt2ElementDecode?_length_of_some
    {bytes : List Byte} {value : GoldilocksExt2}
    (hDecode : goldilocksExt2ElementDecode? bytes = some value) :
    bytes.length = 16 := by
  by_contra hLength
  rw [goldilocksExt2ElementDecode?_none_of_length_ne hLength] at hDecode
  contradiction

def finVectorEncode {α : Type} (encode : α → List Byte) :
    {n : Nat} → (Fin n → α) → List Byte
  | 0, _ => []
  | n + 1, values =>
      encode (values 0) ++
        finVectorEncode encode (fun index : Fin n => values index.succ)

theorem finVectorEncode_length {α : Type} {encode : α → List Byte} {width : Nat}
    (hLen : ∀ value, (encode value).length = width) :
    ∀ {n : Nat} (values : Fin n → α),
      (finVectorEncode encode values).length = n * width
  | 0, _ => by simp [finVectorEncode]
  | n + 1, values => by
      simp [finVectorEncode, hLen,
        finVectorEncode_length hLen (fun index : Fin n => values index.succ),
        Nat.succ_mul, Nat.add_comm]

theorem finVectorEncode_injective {α : Type} {encode : α → List Byte} {width : Nat}
    (hLen : ∀ value, (encode value).length = width)
    (hInj : Function.Injective encode) :
    ∀ {n : Nat}, Function.Injective (finVectorEncode encode : (Fin n → α) → List Byte)
  | 0 => by
      intro lhs rhs _
      funext index
      exact Fin.elim0 index
  | n + 1 => by
      intro lhs rhs h
      have hHeadBytes : encode (lhs 0) = encode (rhs 0) := by
        have hTake := congrArg (List.take width) h
        simpa [finVectorEncode, hLen] using hTake
      have hTailBytes :
          finVectorEncode encode (fun index : Fin n => lhs index.succ) =
            finVectorEncode encode (fun index : Fin n => rhs index.succ) := by
        have hDrop := congrArg (List.drop width) h
        simpa [finVectorEncode, hLen] using hDrop
      have hHead : lhs 0 = rhs 0 := hInj hHeadBytes
      have hTail :
          (fun index : Fin n => lhs index.succ) =
            (fun index : Fin n => rhs index.succ) :=
        finVectorEncode_injective hLen hInj hTailBytes
      funext index
      cases index using Fin.cases with
      | zero => exact hHead
      | succ index => exact congrFun hTail index

def finVectorDecode? {α : Type} (decode : List Byte → Option α) (width : Nat) :
    {n : Nat} → List Byte → Option (Fin n → α)
  | 0, bytes =>
      if bytes = [] then
        some (fun index => Fin.elim0 index)
      else
        none
  | n + 1, bytes =>
      if bytes.length = (n + 1) * width then
        match decode (bytes.take width),
            finVectorDecode? decode width (n := n) (bytes.drop width) with
        | some head, some tail => some (Fin.cases head tail)
        | _, _ => none
      else
        none

theorem finVectorDecode?_encode {α : Type} {encode : α → List Byte}
    {decode : List Byte → Option α} {width : Nat}
    (hLen : ∀ value, (encode value).length = width)
    (hRoundTrip : ∀ value, decode (encode value) = some value) :
    ∀ {n : Nat} (values : Fin n → α),
      finVectorDecode? decode width (finVectorEncode encode values) = some values
  | 0, values => by
      simp [finVectorEncode, finVectorDecode?]
      funext index
      exact Fin.elim0 index
  | n + 1, values => by
      have hTail :=
        finVectorDecode?_encode hLen hRoundTrip
          (fun index : Fin n => values index.succ)
      simp [finVectorEncode, finVectorDecode?, hLen,
        finVectorEncode_length hLen (fun index : Fin n => values index.succ),
        hRoundTrip, hTail, Nat.succ_mul]
      constructor
      · omega
      · funext index
        cases index using Fin.cases with
        | zero => simp
        | succ index => simp

theorem finVectorDecode?_none_of_length_ne {α : Type}
    {decode : List Byte → Option α} {width : Nat} :
    ∀ {n : Nat} {bytes : List Byte},
      bytes.length ≠ n * width →
        finVectorDecode? decode width (n := n) bytes = none
  | 0, bytes, hLength => by
      simp [finVectorDecode?]
      intro hBytes
      apply hLength
      simp [hBytes]
  | n + 1, bytes, hLength => by
      simp [finVectorDecode?, hLength]

theorem finVectorDecode?_length_of_some {α : Type}
    {decode : List Byte → Option α} {width : Nat}
    {n : Nat} {bytes : List Byte} {values : Fin n → α}
    (hDecode : finVectorDecode? decode width (n := n) bytes = some values) :
    bytes.length = n * width := by
  by_contra hLength
  rw [finVectorDecode?_none_of_length_ne hLength] at hDecode
  contradiction

def phi81CoefficientsWireEncode (coefficients : Phi81Coefficients) : List Byte :=
  finVectorEncode goldilocksElementEncode coefficients

theorem phi81CoefficientsWireEncode_length (coefficients : Phi81Coefficients) :
    (phi81CoefficientsWireEncode coefficients).length = phi81Degree * 8 := by
  exact finVectorEncode_length goldilocksElementEncode_length coefficients

theorem phi81CoefficientsWireEncode_injective :
    Function.Injective phi81CoefficientsWireEncode :=
  finVectorEncode_injective goldilocksElementEncode_length goldilocksElementEncode_injective

abbrev Phi81Ext2Coefficients :=
  Fin phi81Degree → GoldilocksExt2

def phi81Ext2CoefficientsWireEncode
    (coefficients : Phi81Ext2Coefficients) : List Byte :=
  finVectorEncode goldilocksExt2ElementEncode coefficients

theorem phi81Ext2CoefficientsWireEncode_length
    (coefficients : Phi81Ext2Coefficients) :
    (phi81Ext2CoefficientsWireEncode coefficients).length = phi81Degree * 16 := by
  exact finVectorEncode_length goldilocksExt2ElementEncode_length coefficients

theorem phi81Ext2CoefficientsWireEncode_injective :
    Function.Injective phi81Ext2CoefficientsWireEncode :=
  finVectorEncode_injective goldilocksExt2ElementEncode_length
    goldilocksExt2ElementEncode_injective

def phi81Ext2CoefficientsWireDecode?
    (bytes : List Byte) : Option Phi81Ext2Coefficients :=
  finVectorDecode? goldilocksExt2ElementDecode? 16 (n := phi81Degree) bytes

theorem phi81Ext2CoefficientsWireDecode?_encode
    (coefficients : Phi81Ext2Coefficients) :
    phi81Ext2CoefficientsWireDecode?
      (phi81Ext2CoefficientsWireEncode coefficients) = some coefficients := by
  exact finVectorDecode?_encode goldilocksExt2ElementEncode_length
    goldilocksExt2ElementDecode?_encode coefficients

theorem phi81Ext2CoefficientsWireDecode?_none_of_length_ne
    {bytes : List Byte} (hLength : bytes.length ≠ phi81Degree * 16) :
    phi81Ext2CoefficientsWireDecode? bytes = none := by
  exact finVectorDecode?_none_of_length_ne hLength

theorem phi81Ext2CoefficientsWireDecode?_length_of_some
    {bytes : List Byte} {coefficients : Phi81Ext2Coefficients}
    (hDecode : phi81Ext2CoefficientsWireDecode? bytes = some coefficients) :
    bytes.length = phi81Degree * 16 := by
  exact finVectorDecode?_length_of_some hDecode

inductive ProofEnvelopeKindWire where
  | foldReduction
  | terminalLocal
  | compressedPublic
  deriving DecidableEq

def proofEnvelopeKindEncode : ProofEnvelopeKindWire → Byte
  | .foldReduction => byteOfNat 1 (by native_decide)
  | .terminalLocal => byteOfNat 2 (by native_decide)
  | .compressedPublic => byteOfNat 3 (by native_decide)

theorem proofEnvelopeKindEncode_injective :
    Function.Injective proofEnvelopeKindEncode := by
  intro lhs rhs h
  cases lhs <;> cases rhs <;> simp [proofEnvelopeKindEncode, byteOfNat] at h ⊢

def proofEnvelopeKindDecode? (byte : Byte) : Option ProofEnvelopeKindWire :=
  if byte = proofEnvelopeKindEncode .foldReduction then
    some .foldReduction
  else if byte = proofEnvelopeKindEncode .terminalLocal then
    some .terminalLocal
  else if byte = proofEnvelopeKindEncode .compressedPublic then
    some .compressedPublic
  else
    none

theorem proofEnvelopeKindDecode?_encode (kind : ProofEnvelopeKindWire) :
    proofEnvelopeKindDecode? (proofEnvelopeKindEncode kind) = some kind := by
  cases kind <;> simp [proofEnvelopeKindDecode?, proofEnvelopeKindEncode, byteOfNat]

def proofEnvelopeKindListDecode? : List Byte → Option ProofEnvelopeKindWire
  | [byte] => proofEnvelopeKindDecode? byte
  | _ => none

theorem proofEnvelopeKindListDecode?_encode (kind : ProofEnvelopeKindWire) :
    proofEnvelopeKindListDecode? [proofEnvelopeKindEncode kind] = some kind := by
  simp [proofEnvelopeKindListDecode?, proofEnvelopeKindDecode?_encode]

def proofEnvelopeMagic : UInt32LE :=
  ⟨0x4E554D51, by native_decide⟩

def proofEnvelopeVersion : UInt16LE :=
  ⟨4, by native_decide⟩

structure ProofEnvelopeContextWire where
  profileID : UInt16LE
  kind : ProofEnvelopeKindWire
  shapeDigest : Digest256Wire
  statementDigest : Digest256Wire
  verifierKeyDigest : Digest256Wire
  transcriptDomain : Digest256Wire
  deriving DecidableEq

theorem proofEnvelopeContextWire_ext
    {lhs rhs : ProofEnvelopeContextWire}
    (hProfileID : lhs.profileID = rhs.profileID)
    (hKind : lhs.kind = rhs.kind)
    (hShapeDigest : lhs.shapeDigest = rhs.shapeDigest)
    (hStatementDigest : lhs.statementDigest = rhs.statementDigest)
    (hVerifierKeyDigest : lhs.verifierKeyDigest = rhs.verifierKeyDigest)
    (hTranscriptDomain : lhs.transcriptDomain = rhs.transcriptDomain) :
    lhs = rhs := by
  cases lhs with
  | mk lhsProfile lhsKind lhsShape lhsStatement lhsVerifierKey lhsTranscriptDomain =>
    cases rhs with
    | mk rhsProfile rhsKind rhsShape rhsStatement rhsVerifierKey rhsTranscriptDomain =>
      simp only [ProofEnvelopeContextWire.mk.injEq]
      exact ⟨hProfileID, hKind, hShapeDigest, hStatementDigest,
        hVerifierKeyDigest, hTranscriptDomain⟩

def proofEnvelopeTranscriptBindingEncode
    (context : ProofEnvelopeContextWire) : List Byte :=
  uint32LEEncode proofEnvelopeMagic ++
    uint16LEEncode proofEnvelopeVersion ++
    uint16LEEncode context.profileID ++
    [proofEnvelopeKindEncode context.kind] ++
    digest256Encode context.shapeDigest ++
    digest256Encode context.statementDigest ++
    digest256Encode context.verifierKeyDigest ++
    digest256Encode context.transcriptDomain

theorem proofEnvelopeTranscriptBindingEncode_length
    (context : ProofEnvelopeContextWire) :
    (proofEnvelopeTranscriptBindingEncode context).length = 137 := by
  simp [proofEnvelopeTranscriptBindingEncode, uint32LEEncode_length,
    uint16LEEncode_length, digest256Encode_length]

theorem proofEnvelopeTranscriptBindingEncode_magic_slice
    (context : ProofEnvelopeContextWire) :
    (proofEnvelopeTranscriptBindingEncode context).take 4 =
      uint32LEEncode proofEnvelopeMagic := by
  simp [proofEnvelopeTranscriptBindingEncode, uint32LEEncode_length]

theorem proofEnvelopeTranscriptBindingEncode_version_slice
    (context : ProofEnvelopeContextWire) :
    ((proofEnvelopeTranscriptBindingEncode context).drop 4).take 2 =
      uint16LEEncode proofEnvelopeVersion := by
  simp [proofEnvelopeTranscriptBindingEncode, uint32LEEncode_length, uint16LEEncode_length]

theorem proofEnvelopeTranscriptBindingEncode_profile_slice
    (context : ProofEnvelopeContextWire) :
    ((proofEnvelopeTranscriptBindingEncode context).drop 6).take 2 =
      uint16LEEncode context.profileID := by
  simp [proofEnvelopeTranscriptBindingEncode, List.drop_append,
    List.drop_eq_nil_of_le, uint32LEEncode_length, uint16LEEncode_length]

theorem proofEnvelopeTranscriptBindingEncode_kind_slice
    (context : ProofEnvelopeContextWire) :
    ((proofEnvelopeTranscriptBindingEncode context).drop 8).take 1 =
      [proofEnvelopeKindEncode context.kind] := by
  simp [proofEnvelopeTranscriptBindingEncode, List.drop_append,
    List.drop_eq_nil_of_le, uint32LEEncode_length, uint16LEEncode_length]

theorem proofEnvelopeTranscriptBindingEncode_shape_slice
    (context : ProofEnvelopeContextWire) :
    ((proofEnvelopeTranscriptBindingEncode context).drop 9).take 32 =
      digest256Encode context.shapeDigest := by
  simp [proofEnvelopeTranscriptBindingEncode, List.drop_append,
    List.drop_eq_nil_of_le, uint32LEEncode_length, uint16LEEncode_length,
    digest256Encode_length]

theorem proofEnvelopeTranscriptBindingEncode_statement_slice
    (context : ProofEnvelopeContextWire) :
    ((proofEnvelopeTranscriptBindingEncode context).drop 41).take 32 =
      digest256Encode context.statementDigest := by
  simp [proofEnvelopeTranscriptBindingEncode, List.drop_append,
    List.drop_eq_nil_of_le, uint32LEEncode_length, uint16LEEncode_length,
    digest256Encode_length]

theorem proofEnvelopeTranscriptBindingEncode_verifierKey_slice
    (context : ProofEnvelopeContextWire) :
    ((proofEnvelopeTranscriptBindingEncode context).drop 73).take 32 =
      digest256Encode context.verifierKeyDigest := by
  simp [proofEnvelopeTranscriptBindingEncode, List.drop_append,
    List.drop_eq_nil_of_le, uint32LEEncode_length, uint16LEEncode_length,
    digest256Encode_length]

theorem proofEnvelopeTranscriptBindingEncode_transcriptDomain_slice
    (context : ProofEnvelopeContextWire) :
    ((proofEnvelopeTranscriptBindingEncode context).drop 105).take 32 =
      digest256Encode context.transcriptDomain := by
  simp [proofEnvelopeTranscriptBindingEncode, List.drop_append,
    List.drop_eq_nil_of_le, uint32LEEncode_length, uint16LEEncode_length,
    digest256Encode_length]

def proofEnvelopeTranscriptBindingDecode?
    (bytes : List Byte) : Option ProofEnvelopeContextWire :=
  if bytes.length = 137 then
    if bytes.take 4 = uint32LEEncode proofEnvelopeMagic then
      if (bytes.drop 4).take 2 = uint16LEEncode proofEnvelopeVersion then
        match uintLEDecode? 2 ((bytes.drop 6).take 2),
            proofEnvelopeKindListDecode? ((bytes.drop 8).take 1),
            digest256Decode? ((bytes.drop 9).take 32),
            digest256Decode? ((bytes.drop 41).take 32),
            digest256Decode? ((bytes.drop 73).take 32),
            digest256Decode? ((bytes.drop 105).take 32) with
        | some profileID, some kind, some shapeDigest, some statementDigest,
            some verifierKeyDigest, some transcriptDomain =>
            some {
              profileID := profileID,
              kind := kind,
              shapeDigest := shapeDigest,
              statementDigest := statementDigest,
              verifierKeyDigest := verifierKeyDigest,
              transcriptDomain := transcriptDomain
            }
        | _, _, _, _, _, _ => none
      else
        none
    else
      none
  else
    none

theorem proofEnvelopeTranscriptBindingDecode?_encode
    (context : ProofEnvelopeContextWire) :
    proofEnvelopeTranscriptBindingDecode?
      (proofEnvelopeTranscriptBindingEncode context) = some context := by
  simp [proofEnvelopeTranscriptBindingDecode?, proofEnvelopeTranscriptBindingEncode_length,
    proofEnvelopeTranscriptBindingEncode_magic_slice,
    proofEnvelopeTranscriptBindingEncode_version_slice,
    proofEnvelopeTranscriptBindingEncode_profile_slice,
    proofEnvelopeTranscriptBindingEncode_kind_slice,
    proofEnvelopeTranscriptBindingEncode_shape_slice,
    proofEnvelopeTranscriptBindingEncode_statement_slice,
    proofEnvelopeTranscriptBindingEncode_verifierKey_slice,
    proofEnvelopeTranscriptBindingEncode_transcriptDomain_slice,
    uint16LEEncode, uintLEDecode?_encode, digest256Decode?_encode,
    proofEnvelopeKindListDecode?_encode]

theorem proofEnvelopeTranscriptBindingDecode?_length_of_some
    {bytes : List Byte} {context : ProofEnvelopeContextWire}
    (hDecode : proofEnvelopeTranscriptBindingDecode? bytes = some context) :
    bytes.length = 137 := by
  unfold proofEnvelopeTranscriptBindingDecode? at hDecode
  split_ifs at hDecode with hLength hMagic hVersion
  exact hLength

theorem proofEnvelopeTranscriptBindingDecode?_magic_of_some
    {bytes : List Byte} {context : ProofEnvelopeContextWire}
    (hDecode : proofEnvelopeTranscriptBindingDecode? bytes = some context) :
    bytes.take 4 = uint32LEEncode proofEnvelopeMagic := by
  unfold proofEnvelopeTranscriptBindingDecode? at hDecode
  split_ifs at hDecode with hLength hMagic hVersion
  exact hMagic

theorem proofEnvelopeTranscriptBindingDecode?_version_of_some
    {bytes : List Byte} {context : ProofEnvelopeContextWire}
    (hDecode : proofEnvelopeTranscriptBindingDecode? bytes = some context) :
    (bytes.drop 4).take 2 = uint16LEEncode proofEnvelopeVersion := by
  unfold proofEnvelopeTranscriptBindingDecode? at hDecode
  split_ifs at hDecode with hLength hMagic hVersion
  exact hVersion

theorem proofEnvelopeTranscriptBindingEncode_injective :
    Function.Injective proofEnvelopeTranscriptBindingEncode := by
  intro lhs rhs h
  have hAfterCommon :
      uint16LEEncode lhs.profileID ++
          [proofEnvelopeKindEncode lhs.kind] ++
          digest256Encode lhs.shapeDigest ++
          digest256Encode lhs.statementDigest ++
          digest256Encode lhs.verifierKeyDigest ++
          digest256Encode lhs.transcriptDomain =
        uint16LEEncode rhs.profileID ++
          [proofEnvelopeKindEncode rhs.kind] ++
          digest256Encode rhs.shapeDigest ++
          digest256Encode rhs.statementDigest ++
          digest256Encode rhs.verifierKeyDigest ++
          digest256Encode rhs.transcriptDomain := by
    simpa [proofEnvelopeTranscriptBindingEncode] using h
  have hProfileBytes :
      uint16LEEncode lhs.profileID = uint16LEEncode rhs.profileID := by
    have hTake := congrArg (List.take 2) hAfterCommon
    simpa [uint16LEEncode_length] using hTake
  have hAfterProfile :
      [proofEnvelopeKindEncode lhs.kind] ++
          digest256Encode lhs.shapeDigest ++
          digest256Encode lhs.statementDigest ++
          digest256Encode lhs.verifierKeyDigest ++
          digest256Encode lhs.transcriptDomain =
        [proofEnvelopeKindEncode rhs.kind] ++
          digest256Encode rhs.shapeDigest ++
          digest256Encode rhs.statementDigest ++
          digest256Encode rhs.verifierKeyDigest ++
          digest256Encode rhs.transcriptDomain := by
    have hDrop := congrArg (List.drop 2) hAfterCommon
    simpa [uint16LEEncode_length] using hDrop
  have hKindByte :
      proofEnvelopeKindEncode lhs.kind = proofEnvelopeKindEncode rhs.kind := by
    have hTake := congrArg (List.take 1) hAfterProfile
    simpa using hTake
  have hAfterKind :
      digest256Encode lhs.shapeDigest ++
          digest256Encode lhs.statementDigest ++
          digest256Encode lhs.verifierKeyDigest ++
          digest256Encode lhs.transcriptDomain =
        digest256Encode rhs.shapeDigest ++
          digest256Encode rhs.statementDigest ++
          digest256Encode rhs.verifierKeyDigest ++
          digest256Encode rhs.transcriptDomain := by
    have hDrop := congrArg (List.drop 1) hAfterProfile
    simpa using hDrop
  have hShapeBytes :
      digest256Encode lhs.shapeDigest = digest256Encode rhs.shapeDigest := by
    have hTake := congrArg (List.take 32) hAfterKind
    simpa [digest256Encode_length] using hTake
  have hAfterShape :
      digest256Encode lhs.statementDigest ++
          digest256Encode lhs.verifierKeyDigest ++
          digest256Encode lhs.transcriptDomain =
        digest256Encode rhs.statementDigest ++
          digest256Encode rhs.verifierKeyDigest ++
          digest256Encode rhs.transcriptDomain := by
    have hDrop := congrArg (List.drop 32) hAfterKind
    simpa [digest256Encode_length] using hDrop
  have hStatementBytes :
      digest256Encode lhs.statementDigest = digest256Encode rhs.statementDigest := by
    have hTake := congrArg (List.take 32) hAfterShape
    simpa [digest256Encode_length] using hTake
  have hAfterStatement :
      digest256Encode lhs.verifierKeyDigest ++
          digest256Encode lhs.transcriptDomain =
        digest256Encode rhs.verifierKeyDigest ++
          digest256Encode rhs.transcriptDomain := by
    have hDrop := congrArg (List.drop 32) hAfterShape
    simpa [digest256Encode_length] using hDrop
  have hVerifierKeyBytes :
      digest256Encode lhs.verifierKeyDigest = digest256Encode rhs.verifierKeyDigest := by
    have hTake := congrArg (List.take 32) hAfterStatement
    simpa [digest256Encode_length] using hTake
  have hTranscriptDomainBytes :
      digest256Encode lhs.transcriptDomain = digest256Encode rhs.transcriptDomain := by
    have hDrop := congrArg (List.drop 32) hAfterStatement
    simpa [digest256Encode_length] using hDrop
  exact proofEnvelopeContextWire_ext
    (uint16LEEncode_injective hProfileBytes)
    (proofEnvelopeKindEncode_injective hKindByte)
    (digest256Encode_injective hShapeBytes)
    (digest256Encode_injective hStatementBytes)
    (digest256Encode_injective hVerifierKeyBytes)
    (digest256Encode_injective hTranscriptDomainBytes)

end SuperNeoFormal
