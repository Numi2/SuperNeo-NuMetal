import SuperNeoFormal.Digest384Serialization
import SuperNeoFormal.Transcript

/-!
Well-formed transcript states.

`TranscriptState` is intentionally a low-level byte model: a frame stores a
count field and a payload, but the type itself does not force the count to be
the payload length.  Security-facing statements should quantify over the
length-counted subset instead.  This module packages that subset and proves
byte injectivity only for well-formed frame lists.
-/

namespace SuperNeoFormal

theorem count64FromUInt64_injective :
    Function.Injective count64FromUInt64 := by
  intro lhs rhs hCount
  apply uint64LEEncode_injective
  rw [← count64Encode_count64FromUInt64 lhs,
    ← count64Encode_count64FromUInt64 rhs,
    hCount]

def WellFormedTranscriptFrame (frame : TranscriptFrame) : Prop :=
  ∃ hLength : frame.payload.length < 256 ^ 8,
    frame.count = count64FromUInt64 ⟨frame.payload.length, hLength⟩

def WellFormedTranscriptFrames : List TranscriptFrame → Prop
  | [] => True
  | frame :: rest =>
      WellFormedTranscriptFrame frame ∧ WellFormedTranscriptFrames rest

def WellFormedTranscriptState (state : TranscriptState) : Prop :=
  WellFormedTranscriptFrames state.frames

structure WellFormedTranscript where
  state : TranscriptState
  wellFormed : WellFormedTranscriptState state
  deriving DecidableEq

theorem wellFormedTranscriptFrame_payload_length_lt
    {frame : TranscriptFrame}
    (hFrame : WellFormedTranscriptFrame frame) :
    frame.payload.length < 256 ^ 8 :=
  hFrame.choose

theorem wellFormedTranscriptFrame_count_eq
    {frame : TranscriptFrame}
    (hFrame : WellFormedTranscriptFrame frame) :
    frame.count =
      count64FromUInt64
        ⟨frame.payload.length,
          wellFormedTranscriptFrame_payload_length_lt hFrame⟩ := by
  exact hFrame.choose_spec

theorem wellFormedTranscriptFrame_payload_length_eq_of_count_eq
    {lhs rhs : TranscriptFrame}
    (hLhs : WellFormedTranscriptFrame lhs)
    (hRhs : WellFormedTranscriptFrame rhs)
    (hCount : lhs.count = rhs.count) :
    lhs.payload.length = rhs.payload.length := by
  have hUInt :
      (⟨lhs.payload.length,
        wellFormedTranscriptFrame_payload_length_lt hLhs⟩ : UInt64LE) =
        ⟨rhs.payload.length,
          wellFormedTranscriptFrame_payload_length_lt hRhs⟩ := by
    apply count64FromUInt64_injective
    rw [← wellFormedTranscriptFrame_count_eq hLhs,
      ← wellFormedTranscriptFrame_count_eq hRhs,
      hCount]
  exact congrArg Fin.val hUInt

theorem wellFormedTranscriptFrames_tail
    {frame : TranscriptFrame}
    {rest : List TranscriptFrame}
    (hFrames : WellFormedTranscriptFrames (frame :: rest)) :
    WellFormedTranscriptFrames rest :=
  hFrames.2

theorem wellFormedTranscriptFrames_frame
    {frame : TranscriptFrame}
    {rest : List TranscriptFrame}
    (hFrames : WellFormedTranscriptFrames (frame :: rest)) :
    WellFormedTranscriptFrame frame :=
  hFrames.1

theorem wellFormedTranscriptFrames_append
    {lhs rhs : List TranscriptFrame}
    (hLhs : WellFormedTranscriptFrames lhs)
    (hRhs : WellFormedTranscriptFrames rhs) :
    WellFormedTranscriptFrames (lhs ++ rhs) := by
  induction lhs with
  | nil =>
      exact hRhs
  | cons frame rest ih =>
      exact ⟨hLhs.1, ih hLhs.2⟩

def wellFormedTranscriptFrameOfPayload
    (payload : List Byte)
    (hLength : payload.length < 256 ^ 8) : TranscriptFrame :=
  transcriptFrame
    (count64FromUInt64 ⟨payload.length, hLength⟩)
    payload

theorem wellFormedTranscriptFrameOfPayload_wellFormed
    (payload : List Byte)
    (hLength : payload.length < 256 ^ 8) :
    WellFormedTranscriptFrame
      (wellFormedTranscriptFrameOfPayload payload hLength) := by
  exact ⟨hLength, rfl⟩

def wellFormedTranscriptInit
    (domain seed : List Byte)
    (hDomain : domain.length < 256 ^ 8)
    (hSeed : seed.length < 256 ^ 8) : WellFormedTranscript where
  state :=
    transcriptInit
      (count64FromUInt64 ⟨domain.length, hDomain⟩)
      domain
      (count64FromUInt64 ⟨seed.length, hSeed⟩)
      seed
  wellFormed := by
    exact
      ⟨wellFormedTranscriptFrameOfPayload_wellFormed domain hDomain,
        ⟨wellFormedTranscriptFrameOfPayload_wellFormed seed hSeed, trivial⟩⟩

def wellFormedTranscriptAbsorb
    (transcript : WellFormedTranscript)
    (payload : List Byte)
    (hLength : payload.length < 256 ^ 8) : WellFormedTranscript where
  state :=
    transcriptAbsorb
      transcript.state
      (count64FromUInt64 ⟨payload.length, hLength⟩)
      payload
  wellFormed := by
    rw [WellFormedTranscriptState, transcriptAbsorb_frames]
    exact
      wellFormedTranscriptFrames_append
        transcript.wellFormed
        ⟨wellFormedTranscriptFrameOfPayload_wellFormed payload hLength, trivial⟩

theorem wellFormedTranscriptFrames_bytes_injective :
    ∀ {lhs rhs : List TranscriptFrame},
      WellFormedTranscriptFrames lhs →
        WellFormedTranscriptFrames rhs →
          transcriptFramesBytes lhs = transcriptFramesBytes rhs →
            lhs = rhs := by
  intro lhs
  induction lhs with
  | nil =>
      intro rhs _hLhs hRhs hBytes
      cases rhs with
      | nil => rfl
      | cons frame rest =>
          have hLength := congrArg List.length hBytes
          simp [transcriptFramesBytes, transcriptFrameEncode_length] at hLength
          omega
  | cons lhsFrame lhsRest ih =>
      intro rhs hLhs hRhs hBytes
      cases rhs with
      | nil =>
          have hLength := congrArg List.length hBytes
          simp [transcriptFramesBytes, transcriptFrameEncode_length] at hLength
      | cons rhsFrame rhsRest =>
          have hCountBytes :
              count64Encode lhsFrame.count =
                count64Encode rhsFrame.count := by
            have hTake := congrArg (List.take 8) hBytes
            simpa [transcriptFramesBytes, transcriptFrameEncode,
              count64Encode_length] using hTake
          have hPayloadLength :
              lhsFrame.payload.length = rhsFrame.payload.length :=
            wellFormedTranscriptFrame_payload_length_eq_of_count_eq
              hLhs.1
              hRhs.1
              (count64Encode_injective hCountBytes)
          have hFrameLength :
              (transcriptFrameEncode lhsFrame).length =
                (transcriptFrameEncode rhsFrame).length := by
            simp [transcriptFrameEncode_length, hPayloadLength]
          have hFrameBytes :
              transcriptFrameEncode lhsFrame =
                transcriptFrameEncode rhsFrame := by
            have hTake :=
              congrArg (List.take (transcriptFrameEncode lhsFrame).length) hBytes
            simpa [transcriptFramesBytes, hFrameLength] using hTake
          have hRestBytes :
              transcriptFramesBytes lhsRest =
                transcriptFramesBytes rhsRest := by
            have hDrop :=
              congrArg (List.drop (transcriptFrameEncode lhsFrame).length) hBytes
            simpa [transcriptFramesBytes, hFrameLength] using hDrop
          have hFrame : lhsFrame = rhsFrame :=
            transcriptFrameEncode_injective hFrameBytes
          have hRest : lhsRest = rhsRest :=
            ih hLhs.2 hRhs.2 hRestBytes
          rw [hFrame, hRest]

theorem transcriptFramesBytes_injective_of_wellFormed
    {lhs rhs : List TranscriptFrame}
    (hLhs : WellFormedTranscriptFrames lhs)
    (hRhs : WellFormedTranscriptFrames rhs)
    (hBytes : transcriptFramesBytes lhs = transcriptFramesBytes rhs) :
    lhs = rhs :=
  wellFormedTranscriptFrames_bytes_injective hLhs hRhs hBytes

theorem transcriptBytes_injective_of_wellFormed
    {lhs rhs : TranscriptState}
    (hLhs : WellFormedTranscriptState lhs)
    (hRhs : WellFormedTranscriptState rhs)
    (hBytes : transcriptBytes lhs = transcriptBytes rhs) :
    lhs = rhs := by
  cases lhs with
  | mk lhsFrames =>
      cases rhs with
      | mk rhsFrames =>
          simp [transcriptBytes, WellFormedTranscriptState] at hLhs hRhs hBytes ⊢
          exact transcriptFramesBytes_injective_of_wellFormed hLhs hRhs hBytes

theorem wellFormedTranscript_bytes_injective :
    Function.Injective (fun transcript : WellFormedTranscript => transcriptBytes transcript.state) := by
  intro lhs rhs hBytes
  cases lhs with
  | mk lhsState lhsWF =>
      cases rhs with
      | mk rhsState rhsWF =>
          have hState :
              lhsState = rhsState :=
            transcriptBytes_injective_of_wellFormed lhsWF rhsWF hBytes
          cases hState
          rfl

theorem wellFormedTranscriptInit_domain_bytes_ne
    {domain otherDomain seed : List Byte}
    {hDomain : domain.length < 256 ^ 8}
    {hOtherDomain : otherDomain.length < 256 ^ 8}
    {hSeed : seed.length < 256 ^ 8}
    (hDomainNe : domain ≠ otherDomain) :
    transcriptBytes
        (wellFormedTranscriptInit domain seed hDomain hSeed).state ≠
      transcriptBytes
        (wellFormedTranscriptInit otherDomain seed hOtherDomain hSeed).state := by
  intro hBytes
  have hState :
      (wellFormedTranscriptInit domain seed hDomain hSeed).state =
        (wellFormedTranscriptInit otherDomain seed hOtherDomain hSeed).state :=
    transcriptBytes_injective_of_wellFormed
      (wellFormedTranscriptInit domain seed hDomain hSeed).wellFormed
      (wellFormedTranscriptInit otherDomain seed hOtherDomain hSeed).wellFormed
      hBytes
  have hInputs :
      (count64FromUInt64 ⟨domain.length, hDomain⟩,
          domain,
          count64FromUInt64 ⟨seed.length, hSeed⟩,
          seed) =
        (count64FromUInt64 ⟨otherDomain.length, hOtherDomain⟩,
          otherDomain,
          count64FromUInt64 ⟨seed.length, hSeed⟩,
          seed) :=
    transcriptInit_injective hState
  exact hDomainNe
    (congrArg
      (fun input : Count64LE × List Byte × Count64LE × List Byte => input.2.1)
      hInputs)

def wellFormedProofEnvelope384TranscriptInit
    (seed : List Byte)
    (context : ProofEnvelopeContext384Wire)
    (hSeed : seed.length < 256 ^ 8) : WellFormedTranscript :=
  wellFormedTranscriptInit
    (proofEnvelopeTranscriptBinding384Encode context)
    seed
    (by
      rw [proofEnvelopeTranscriptBinding384Encode_length]
      native_decide)
    hSeed

theorem wellFormedProofEnvelope384Transcript_kind_bytes_ne
    {seed : List Byte}
    {hSeed : seed.length < 256 ^ 8}
    {lhs rhs : ProofEnvelopeContext384Wire}
    (hKind : lhs.kind ≠ rhs.kind) :
    transcriptBytes
        (wellFormedProofEnvelope384TranscriptInit seed lhs hSeed).state ≠
      transcriptBytes
        (wellFormedProofEnvelope384TranscriptInit seed rhs hSeed).state := by
  intro hBytes
  have hState :
      (wellFormedProofEnvelope384TranscriptInit seed lhs hSeed).state =
        (wellFormedProofEnvelope384TranscriptInit seed rhs hSeed).state :=
    transcriptBytes_injective_of_wellFormed
      (wellFormedProofEnvelope384TranscriptInit seed lhs hSeed).wellFormed
      (wellFormedProofEnvelope384TranscriptInit seed rhs hSeed).wellFormed
      hBytes
  have hInputs :
      (count64FromUInt64
          ⟨(proofEnvelopeTranscriptBinding384Encode lhs).length,
            by
              rw [proofEnvelopeTranscriptBinding384Encode_length]
              native_decide⟩,
          proofEnvelopeTranscriptBinding384Encode lhs,
          count64FromUInt64 ⟨seed.length, hSeed⟩,
          seed) =
        (count64FromUInt64
          ⟨(proofEnvelopeTranscriptBinding384Encode rhs).length,
            by
              rw [proofEnvelopeTranscriptBinding384Encode_length]
              native_decide⟩,
          proofEnvelopeTranscriptBinding384Encode rhs,
          count64FromUInt64 ⟨seed.length, hSeed⟩,
          seed) :=
    transcriptInit_injective hState
  have hContextBytes :
      proofEnvelopeTranscriptBinding384Encode lhs =
        proofEnvelopeTranscriptBinding384Encode rhs :=
    congrArg
      (fun input : Count64LE × List Byte × Count64LE × List Byte => input.2.1)
      hInputs
  exact hKind
    (congrArg ProofEnvelopeContext384Wire.kind
      (proofEnvelopeTranscriptBinding384Encode_injective hContextBytes))

end SuperNeoFormal
