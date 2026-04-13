import Mathlib

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

end SuperNeoFormal
