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
