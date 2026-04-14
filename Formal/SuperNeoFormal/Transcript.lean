import SuperNeoFormal.Serialization

/-!
Transcript absorption model.

Swift's `SumCheckTranscript` initializes by absorbing the domain separator and
seed, then every later absorb appends an eight-byte length frame followed by the
payload and rekeys the deterministic RNG with the accumulated byte string.  This
module models the ordered framed absorption layer.  It proves deterministic
challenge consistency for equal structured transcripts; it deliberately does not
model SHA-256 as a random oracle.
-/

namespace SuperNeoFormal

structure TranscriptFrame where
  count : Count64LE
  payload : List Byte
  deriving DecidableEq

def transcriptFrameEncode (frame : TranscriptFrame) : List Byte :=
  count64Encode frame.count ++ frame.payload

theorem transcriptFrameEncode_length (frame : TranscriptFrame) :
    (transcriptFrameEncode frame).length = 8 + frame.payload.length := by
  simp [transcriptFrameEncode, count64Encode_length]

theorem transcriptFrameEncode_injective :
    Function.Injective transcriptFrameEncode := by
  intro lhs rhs h
  cases lhs with
  | mk lhsCount lhsPayload =>
    cases rhs with
    | mk rhsCount rhsPayload =>
      simp [transcriptFrameEncode] at h ⊢
      have hCountList :
          count64Encode lhsCount = count64Encode rhsCount := by
        have hTake := congrArg (List.take 8) h
        simpa [count64Encode] using hTake
      have hPayload :
          lhsPayload = rhsPayload := by
        have hDrop := congrArg (List.drop 8) h
        simpa [count64Encode] using hDrop
      exact ⟨count64Encode_injective hCountList, hPayload⟩

theorem transcriptFrameEncode_eq_iff (lhs rhs : TranscriptFrame) :
    transcriptFrameEncode lhs = transcriptFrameEncode rhs ↔ lhs = rhs :=
  transcriptFrameEncode_injective.eq_iff

def transcriptFrame (count : Count64LE) (payload : List Byte) : TranscriptFrame where
  count := count
  payload := payload

structure TranscriptState where
  frames : List TranscriptFrame
  deriving DecidableEq

def transcriptFramesBytes : List TranscriptFrame → List Byte
  | [] => []
  | frame :: rest => transcriptFrameEncode frame ++ transcriptFramesBytes rest

def transcriptBytes (state : TranscriptState) : List Byte :=
  transcriptFramesBytes state.frames

theorem transcriptFramesBytes_append
    (lhs rhs : List TranscriptFrame) :
    transcriptFramesBytes (lhs ++ rhs) =
      transcriptFramesBytes lhs ++ transcriptFramesBytes rhs := by
  induction lhs with
  | nil =>
      simp [transcriptFramesBytes]
  | cons head tail ih =>
      simp [transcriptFramesBytes, ih, List.append_assoc]

def transcriptInit
    (domainCount : Count64LE)
    (domain : List Byte)
    (seedCount : Count64LE)
    (seed : List Byte) : TranscriptState where
  frames := [
    transcriptFrame domainCount domain,
    transcriptFrame seedCount seed
  ]

def transcriptAbsorb
    (state : TranscriptState)
    (count : Count64LE)
    (payload : List Byte) : TranscriptState where
  frames := state.frames ++ [transcriptFrame count payload]

theorem transcriptInit_frames
    (domainCount : Count64LE)
    (domain : List Byte)
    (seedCount : Count64LE)
    (seed : List Byte) :
    (transcriptInit domainCount domain seedCount seed).frames =
      [
        transcriptFrame domainCount domain,
        transcriptFrame seedCount seed
      ] :=
  rfl

theorem transcriptInit_frame_count
    (domainCount : Count64LE)
    (domain : List Byte)
    (seedCount : Count64LE)
    (seed : List Byte) :
    (transcriptInit domainCount domain seedCount seed).frames.length = 2 := by
  simp [transcriptInit]

theorem transcriptAbsorb_frames
    (state : TranscriptState)
    (count : Count64LE)
    (payload : List Byte) :
    (transcriptAbsorb state count payload).frames =
      state.frames ++ [transcriptFrame count payload] :=
  rfl

theorem transcriptAbsorb_frame_count
    (state : TranscriptState)
    (count : Count64LE)
    (payload : List Byte) :
    (transcriptAbsorb state count payload).frames.length =
      state.frames.length + 1 := by
  simp [transcriptAbsorb]

theorem transcriptBytes_nil :
    transcriptBytes ⟨[]⟩ = [] :=
  rfl

theorem transcriptBytes_absorb
    (state : TranscriptState)
    (count : Count64LE)
    (payload : List Byte) :
    transcriptBytes (transcriptAbsorb state count payload) =
      transcriptBytes state ++ transcriptFrameEncode (transcriptFrame count payload) := by
  simp [transcriptBytes, transcriptAbsorb, transcriptFramesBytes_append, transcriptFramesBytes]

theorem transcriptAbsorb_order_two
    (state : TranscriptState)
    (firstCount : Count64LE)
    (firstPayload : List Byte)
    (secondCount : Count64LE)
    (secondPayload : List Byte) :
    (transcriptAbsorb
      (transcriptAbsorb state firstCount firstPayload)
      secondCount
      secondPayload).frames =
      state.frames ++ [
        transcriptFrame firstCount firstPayload,
        transcriptFrame secondCount secondPayload
      ] := by
  simp [transcriptAbsorb, List.append_assoc]

def transcriptAbsorbFrames
    (state : TranscriptState)
    (frames : List TranscriptFrame) : TranscriptState where
  frames := state.frames ++ frames

theorem transcriptAbsorbFrames_frames
    (state : TranscriptState)
    (frames : List TranscriptFrame) :
    (transcriptAbsorbFrames state frames).frames = state.frames ++ frames :=
  rfl

theorem transcriptAbsorbFrames_nil
    (state : TranscriptState) :
    transcriptAbsorbFrames state [] = state := by
  cases state
  simp [transcriptAbsorbFrames]

theorem transcriptAbsorbFrames_singleton
    (state : TranscriptState)
    (frame : TranscriptFrame) :
    transcriptAbsorbFrames state [frame] =
      transcriptAbsorb state frame.count frame.payload := by
  cases frame
  rfl

theorem transcriptAbsorbFrames_append
    (state : TranscriptState)
    (lhs rhs : List TranscriptFrame) :
    transcriptAbsorbFrames (transcriptAbsorbFrames state lhs) rhs =
      transcriptAbsorbFrames state (lhs ++ rhs) := by
  cases state
  simp [transcriptAbsorbFrames, List.append_assoc]

theorem transcriptBytes_absorbFrames
    (state : TranscriptState)
    (frames : List TranscriptFrame) :
    transcriptBytes (transcriptAbsorbFrames state frames) =
      transcriptBytes state ++ transcriptFramesBytes frames := by
  simp [transcriptBytes, transcriptAbsorbFrames, transcriptFramesBytes_append]

theorem transcriptInit_injective :
    Function.Injective
      (fun input : Count64LE × List Byte × Count64LE × List Byte =>
        transcriptInit input.1 input.2.1 input.2.2.1 input.2.2.2) := by
  intro lhs rhs h
  cases lhs with
  | mk lhsDomainCount lhsRest =>
    cases lhsRest with
    | mk lhsDomain lhsRest2 =>
      cases lhsRest2 with
      | mk lhsSeedCount lhsSeed =>
        cases rhs with
        | mk rhsDomainCount rhsRest =>
          cases rhsRest with
          | mk rhsDomain rhsRest2 =>
            cases rhsRest2 with
            | mk rhsSeedCount rhsSeed =>
              simp [transcriptInit, transcriptFrame] at h ⊢
              rcases h with ⟨hDomainFrame, hSeedFrame⟩
              rcases hDomainFrame with ⟨hDomainCount, hDomain⟩
              rcases hSeedFrame with ⟨hSeedCount, hSeed⟩
              exact ⟨hDomainCount, hDomain, hSeedCount, hSeed⟩

theorem transcriptInit_eq_iff
    (lhs rhs : Count64LE × List Byte × Count64LE × List Byte) :
    (transcriptInit lhs.1 lhs.2.1 lhs.2.2.1 lhs.2.2.2 =
      transcriptInit rhs.1 rhs.2.1 rhs.2.2.1 rhs.2.2.2) ↔ lhs = rhs :=
  transcriptInit_injective.eq_iff

theorem transcriptInit_domain_ne
    {domainCount seedCount : Count64LE}
    {domain otherDomain seed : List Byte}
    (hDomain : domain ≠ otherDomain) :
    transcriptInit domainCount domain seedCount seed ≠
      transcriptInit domainCount otherDomain seedCount seed := by
  intro h
  have hInputs :
      (domainCount, domain, seedCount, seed) =
        (domainCount, otherDomain, seedCount, seed) :=
    transcriptInit_injective h
  cases hInputs
  exact hDomain rfl

theorem transcriptInit_seed_ne
    {domainCount seedCount : Count64LE}
    {domain seed otherSeed : List Byte}
    (hSeed : seed ≠ otherSeed) :
    transcriptInit domainCount domain seedCount seed ≠
      transcriptInit domainCount domain seedCount otherSeed := by
  intro h
  have hInputs :
      (domainCount, domain, seedCount, seed) =
        (domainCount, domain, seedCount, otherSeed) :=
    transcriptInit_injective h
  cases hInputs
  exact hSeed rfl

def payloadLengthUInt64? (payload : List Byte) : Option UInt64LE :=
  if hLength : payload.length < 256 ^ 8 then
    some ⟨payload.length, hLength⟩
  else
    none

theorem payloadLengthUInt64?_eq_some_of_lt
    (payload : List Byte) (hLength : payload.length < 256 ^ 8) :
    payloadLengthUInt64? payload = some ⟨payload.length, hLength⟩ := by
  have hActual : payload.length < 18446744073709551616 := by
    norm_num at hLength ⊢
    exact hLength
  simp [payloadLengthUInt64?, hActual]

def payloadLengthCount64? (payload : List Byte) : Option Count64LE :=
  (payloadLengthUInt64? payload).map count64FromUInt64

theorem payloadLengthCount64?_eq_some_of_lt
    (payload : List Byte) (hLength : payload.length < 256 ^ 8) :
    payloadLengthCount64? payload =
      some (count64FromUInt64 ⟨payload.length, hLength⟩) := by
  simp [payloadLengthCount64?, payloadLengthUInt64?_eq_some_of_lt payload hLength]

def lengthCountedTranscriptFrame? (payload : List Byte) : Option TranscriptFrame :=
  (payloadLengthCount64? payload).map (fun count => transcriptFrame count payload)

theorem lengthCountedTranscriptFrame?_eq_some_of_lt
    (payload : List Byte) (hLength : payload.length < 256 ^ 8) :
    lengthCountedTranscriptFrame? payload =
      some (transcriptFrame (count64FromUInt64 ⟨payload.length, hLength⟩) payload) := by
  simp [lengthCountedTranscriptFrame?, payloadLengthCount64?_eq_some_of_lt payload hLength]

theorem transcriptFrameEncode_lengthCounted_of_lt
    (payload : List Byte) (hLength : payload.length < 256 ^ 8) :
    transcriptFrameEncode
        (transcriptFrame (count64FromUInt64 ⟨payload.length, hLength⟩) payload) =
      uint64LEEncode ⟨payload.length, hLength⟩ ++ payload := by
  simp [transcriptFrameEncode, transcriptFrame, count64Encode_count64FromUInt64]

theorem lengthCountedTranscriptFrame?_encode_of_lt
    (payload : List Byte) (hLength : payload.length < 256 ^ 8) :
    (lengthCountedTranscriptFrame? payload).map transcriptFrameEncode =
      some (uint64LEEncode ⟨payload.length, hLength⟩ ++ payload) := by
  simp [lengthCountedTranscriptFrame?_eq_some_of_lt payload hLength,
    transcriptFrameEncode_lengthCounted_of_lt payload hLength]

def lengthCountedTranscriptInit? (domain seed : List Byte) : Option TranscriptState :=
  match payloadLengthCount64? domain, payloadLengthCount64? seed with
  | some domainCount, some seedCount => some (transcriptInit domainCount domain seedCount seed)
  | _, _ => none

theorem lengthCountedTranscriptInit?_eq_some_of_lt
    (domain seed : List Byte)
    (hDomain : domain.length < 256 ^ 8)
    (hSeed : seed.length < 256 ^ 8) :
    lengthCountedTranscriptInit? domain seed =
      some (transcriptInit
        (count64FromUInt64 ⟨domain.length, hDomain⟩)
        domain
        (count64FromUInt64 ⟨seed.length, hSeed⟩)
        seed) := by
  simp [lengthCountedTranscriptInit?, payloadLengthCount64?_eq_some_of_lt domain hDomain,
    payloadLengthCount64?_eq_some_of_lt seed hSeed]

theorem transcriptBytes_lengthCountedInit_of_lt
    (domain seed : List Byte)
    (hDomain : domain.length < 256 ^ 8)
    (hSeed : seed.length < 256 ^ 8) :
    transcriptBytes
        (transcriptInit
          (count64FromUInt64 ⟨domain.length, hDomain⟩)
          domain
          (count64FromUInt64 ⟨seed.length, hSeed⟩)
          seed) =
      uint64LEEncode ⟨domain.length, hDomain⟩ ++ domain ++
        uint64LEEncode ⟨seed.length, hSeed⟩ ++ seed := by
  simp [transcriptBytes, transcriptInit, transcriptFramesBytes, transcriptFrameEncode,
    transcriptFrame, count64Encode_count64FromUInt64, List.append_assoc]

theorem lengthCountedTranscriptInit?_bytes_of_lt
    (domain seed : List Byte)
    (hDomain : domain.length < 256 ^ 8)
    (hSeed : seed.length < 256 ^ 8) :
    (lengthCountedTranscriptInit? domain seed).map transcriptBytes =
      some (uint64LEEncode ⟨domain.length, hDomain⟩ ++ domain ++
        uint64LEEncode ⟨seed.length, hSeed⟩ ++ seed) := by
  simp [lengthCountedTranscriptInit?_eq_some_of_lt domain seed hDomain hSeed,
    transcriptBytes_lengthCountedInit_of_lt domain seed hDomain hSeed]

def transcriptFirstPayload? (state : TranscriptState) : Option (List Byte) :=
  state.frames.head?.map TranscriptFrame.payload

def proofEnvelopeTranscriptInit
    (domainCount : Count64LE)
    (seedCount : Count64LE)
    (seed : List Byte)
    (context : ProofEnvelopeContextWire) : TranscriptState :=
  transcriptInit domainCount (proofEnvelopeTranscriptBindingEncode context) seedCount seed

def proofEnvelopeTranscriptWithAbsorbs
    (domainCount : Count64LE)
    (seedCount : Count64LE)
    (seed : List Byte)
    (context : ProofEnvelopeContextWire)
    (absorbs : List TranscriptFrame) : TranscriptState :=
  transcriptAbsorbFrames
    (proofEnvelopeTranscriptInit domainCount seedCount seed context)
    absorbs

theorem proofEnvelopeTranscriptInit_frames
    (domainCount seedCount : Count64LE)
    (seed : List Byte)
    (context : ProofEnvelopeContextWire) :
    (proofEnvelopeTranscriptInit domainCount seedCount seed context).frames =
      [transcriptFrame domainCount (proofEnvelopeTranscriptBindingEncode context),
        transcriptFrame seedCount seed] :=
  rfl

theorem proofEnvelopeTranscriptWithAbsorbs_frames
    (domainCount seedCount : Count64LE)
    (seed : List Byte)
    (context : ProofEnvelopeContextWire)
    (absorbs : List TranscriptFrame) :
    (proofEnvelopeTranscriptWithAbsorbs
      domainCount seedCount seed context absorbs).frames =
        [transcriptFrame domainCount (proofEnvelopeTranscriptBindingEncode context),
          transcriptFrame seedCount seed] ++ absorbs := by
  rfl

theorem proofEnvelopeTranscriptWithAbsorbs_bytes
    (domainCount seedCount : Count64LE)
    (seed : List Byte)
    (context : ProofEnvelopeContextWire)
    (absorbs : List TranscriptFrame) :
    transcriptBytes
        (proofEnvelopeTranscriptWithAbsorbs
          domainCount seedCount seed context absorbs) =
      transcriptBytes (proofEnvelopeTranscriptInit domainCount seedCount seed context) ++
        transcriptFramesBytes absorbs := by
  simp [proofEnvelopeTranscriptWithAbsorbs, transcriptBytes_absorbFrames]

theorem proofEnvelopeTranscriptInit_first_payload
    (domainCount seedCount : Count64LE)
    (seed : List Byte)
    (context : ProofEnvelopeContextWire) :
    transcriptFirstPayload? (proofEnvelopeTranscriptInit domainCount seedCount seed context) =
      some (proofEnvelopeTranscriptBindingEncode context) :=
  rfl

theorem proofEnvelopeTranscriptInit_first_payload_decodes
    (domainCount seedCount : Count64LE)
    (seed : List Byte)
    (context : ProofEnvelopeContextWire) :
    (transcriptFirstPayload? (proofEnvelopeTranscriptInit domainCount seedCount seed context)).bind
        proofEnvelopeTranscriptBindingDecode? = some context := by
  simp [proofEnvelopeTranscriptInit_first_payload, proofEnvelopeTranscriptBindingDecode?_encode]

theorem proofEnvelopeTranscriptInit_context_injective
    (domainCount seedCount : Count64LE)
    (seed : List Byte) :
    Function.Injective (proofEnvelopeTranscriptInit domainCount seedCount seed) := by
  intro lhs rhs h
  have hInputs :
      (domainCount, proofEnvelopeTranscriptBindingEncode lhs, seedCount, seed) =
        (domainCount, proofEnvelopeTranscriptBindingEncode rhs, seedCount, seed) :=
    transcriptInit_injective h
  have hBytes :
      proofEnvelopeTranscriptBindingEncode lhs = proofEnvelopeTranscriptBindingEncode rhs :=
    congrArg (fun input : Count64LE × List Byte × Count64LE × List Byte => input.2.1)
      hInputs
  exact proofEnvelopeTranscriptBindingEncode_injective hBytes

def proofEnvelopeLengthCountedTranscriptInit?
    (seed : List Byte) (context : ProofEnvelopeContextWire) : Option TranscriptState :=
  lengthCountedTranscriptInit? (proofEnvelopeTranscriptBindingEncode context) seed

theorem proofEnvelopeLengthCountedTranscriptInit?_first_payload_decodes
    (seed : List Byte) (hSeed : seed.length < 256 ^ 8)
    (context : ProofEnvelopeContextWire) :
    (proofEnvelopeLengthCountedTranscriptInit? seed context).bind
        (fun state => (transcriptFirstPayload? state).bind proofEnvelopeTranscriptBindingDecode?) =
      some context := by
  unfold proofEnvelopeLengthCountedTranscriptInit?
  have hDomain : (proofEnvelopeTranscriptBindingEncode context).length < 256 ^ 8 := by
    rw [proofEnvelopeTranscriptBindingEncode_length]
    native_decide
  rw [lengthCountedTranscriptInit?_eq_some_of_lt _ _ hDomain hSeed]
  simp [transcriptInit, transcriptFirstPayload?, transcriptFrame,
    proofEnvelopeTranscriptBindingDecode?_encode]

def ChallengeDeriver (Challenge : Type) :=
  TranscriptState → Challenge

def deriveChallenge {Challenge : Type}
    (deriver : ChallengeDeriver Challenge)
    (state : TranscriptState) : Challenge :=
  deriver state

theorem deriveChallenge_eq_of_transcript_eq {Challenge : Type}
    (deriver : ChallengeDeriver Challenge)
    {lhs rhs : TranscriptState}
    (hTranscript : lhs = rhs) :
    deriveChallenge deriver lhs = deriveChallenge deriver rhs := by
  rw [hTranscript]

theorem deriveChallenge_after_same_absorbs {Challenge : Type}
    (deriver : ChallengeDeriver Challenge)
    (state : TranscriptState)
    (count : Count64LE)
    (payload : List Byte) :
    deriveChallenge deriver (transcriptAbsorb state count payload) =
      deriveChallenge deriver (transcriptAbsorb state count payload) :=
  rfl

theorem deriveChallenge_after_equal_absorb_payloads {Challenge : Type}
    (deriver : ChallengeDeriver Challenge)
    {state : TranscriptState}
    {count : Count64LE}
    {lhsPayload rhsPayload : List Byte}
    (hPayload : lhsPayload = rhsPayload) :
    deriveChallenge deriver (transcriptAbsorb state count lhsPayload) =
      deriveChallenge deriver (transcriptAbsorb state count rhsPayload) := by
  rw [hPayload]

end SuperNeoFormal
