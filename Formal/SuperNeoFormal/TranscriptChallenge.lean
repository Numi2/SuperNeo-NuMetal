import SuperNeoFormal.Transcript
import SuperNeoFormal.PiRLCSoundness

/-!
Transcript-derived challenge schedule.

This module connects the ordered transcript model to the concrete finite
challenge sources used by the formal PiRLC layer.  The deriver remains abstract:
the file proves deterministic binding and support facts for whatever
transcript-to-seed function the verifier and prover share.  It does not model
SHA-256, random-oracle programming, or challenge uniformity.
-/

noncomputable section

namespace SuperNeoFormal

abbrev TranscriptChallengeSchedule (Challenge : Type) :=
  ChallengeDeriver Challenge

def transcriptPhi81ChallengeSeed
    (deriver : TranscriptChallengeSchedule Phi81ChallengeSeed)
    (state : TranscriptState) : Phi81ChallengeSeed :=
  deriveChallenge deriver state

def transcriptPhi81ChallengeCoefficients
    (deriver : TranscriptChallengeSchedule Phi81ChallengeSeed)
    (state : TranscriptState) : Phi81Coefficients :=
  phi81ChallengeCoefficients (transcriptPhi81ChallengeSeed deriver state)

def transcriptPhi81ChallengeElement
    (deriver : TranscriptChallengeSchedule Phi81ChallengeSeed)
    (state : TranscriptState) : Phi81 :=
  phi81ChallengeElement (transcriptPhi81ChallengeSeed deriver state)

def transcriptExpandedChallengeSeed
    (deriver : TranscriptChallengeSchedule Phi81ExpandedChallengeSeed)
    (state : TranscriptState) : Phi81ExpandedChallengeSeed :=
  deriveChallenge deriver state

def transcriptExpandedChallengeElements
    (deriver : TranscriptChallengeSchedule Phi81ExpandedChallengeSeed)
    (state : TranscriptState) : Fin challengeExpansionFactor → Phi81 :=
  phi81ExpandedChallengeElements (transcriptExpandedChallengeSeed deriver state)

def transcriptPiRLCChallengeSeed {count : Nat}
    (deriver : TranscriptChallengeSchedule (PiRLCChallengeSeed count))
    (state : TranscriptState) : PiRLCChallengeSeed count :=
  deriveChallenge deriver state

def transcriptPiRLCChallengeElements {count : Nat}
    (deriver : TranscriptChallengeSchedule (PiRLCChallengeSeed count))
    (state : TranscriptState) : Fin count → Phi81 :=
  pirlcChallengeElements (transcriptPiRLCChallengeSeed deriver state)

theorem transcriptPhi81ChallengeSeed_eq_of_transcript_eq
    (deriver : TranscriptChallengeSchedule Phi81ChallengeSeed)
    {lhs rhs : TranscriptState}
    (hTranscript : lhs = rhs) :
    transcriptPhi81ChallengeSeed deriver lhs =
      transcriptPhi81ChallengeSeed deriver rhs :=
  deriveChallenge_eq_of_transcript_eq deriver hTranscript

theorem transcriptPhi81ChallengeElement_eq_of_transcript_eq
    (deriver : TranscriptChallengeSchedule Phi81ChallengeSeed)
    {lhs rhs : TranscriptState}
    (hTranscript : lhs = rhs) :
    transcriptPhi81ChallengeElement deriver lhs =
      transcriptPhi81ChallengeElement deriver rhs := by
  rw [hTranscript]

theorem transcriptPhi81ChallengeSeed_after_equal_absorb_payloads
    (deriver : TranscriptChallengeSchedule Phi81ChallengeSeed)
    {state : TranscriptState}
    {count : Count64LE}
    {lhsPayload rhsPayload : List Byte}
    (hPayload : lhsPayload = rhsPayload) :
    transcriptPhi81ChallengeSeed deriver (transcriptAbsorb state count lhsPayload) =
      transcriptPhi81ChallengeSeed deriver (transcriptAbsorb state count rhsPayload) :=
  deriveChallenge_after_equal_absorb_payloads deriver hPayload

theorem transcriptPhi81ChallengeElement_after_equal_absorb_payloads
    (deriver : TranscriptChallengeSchedule Phi81ChallengeSeed)
    {state : TranscriptState}
    {count : Count64LE}
    {lhsPayload rhsPayload : List Byte}
    (hPayload : lhsPayload = rhsPayload) :
    transcriptPhi81ChallengeElement deriver (transcriptAbsorb state count lhsPayload) =
      transcriptPhi81ChallengeElement deriver (transcriptAbsorb state count rhsPayload) := by
  rw [hPayload]

theorem transcriptPhi81ChallengeSeed_after_equal_ordered_absorbs
    (deriver : TranscriptChallengeSchedule Phi81ChallengeSeed)
    {state : TranscriptState}
    {lhsAbsorbs rhsAbsorbs : List TranscriptFrame}
    (hAbsorbs : lhsAbsorbs = rhsAbsorbs) :
    transcriptPhi81ChallengeSeed deriver
        (transcriptAbsorbFrames state lhsAbsorbs) =
      transcriptPhi81ChallengeSeed deriver
        (transcriptAbsorbFrames state rhsAbsorbs) := by
  rw [hAbsorbs]

theorem transcriptPhi81ChallengeElement_after_equal_ordered_absorbs
    (deriver : TranscriptChallengeSchedule Phi81ChallengeSeed)
    {state : TranscriptState}
    {lhsAbsorbs rhsAbsorbs : List TranscriptFrame}
    (hAbsorbs : lhsAbsorbs = rhsAbsorbs) :
    transcriptPhi81ChallengeElement deriver
        (transcriptAbsorbFrames state lhsAbsorbs) =
      transcriptPhi81ChallengeElement deriver
        (transcriptAbsorbFrames state rhsAbsorbs) := by
  rw [hAbsorbs]

theorem proofEnvelopeTranscriptChallengeSeed_eq_of_context_seed_eq
    (deriver : TranscriptChallengeSchedule Phi81ChallengeSeed)
    {domainCount seedCount : Count64LE}
    {lhsSeed rhsSeed : List Byte}
    {lhsContext rhsContext : ProofEnvelopeContextWire}
    (hSeed : lhsSeed = rhsSeed)
    (hContext : lhsContext = rhsContext) :
    transcriptPhi81ChallengeSeed deriver
        (proofEnvelopeTranscriptInit domainCount seedCount lhsSeed lhsContext) =
      transcriptPhi81ChallengeSeed deriver
        (proofEnvelopeTranscriptInit domainCount seedCount rhsSeed rhsContext) := by
  rw [hSeed, hContext]

theorem proofEnvelopeTranscriptChallengeElement_eq_of_context_seed_eq
    (deriver : TranscriptChallengeSchedule Phi81ChallengeSeed)
    {domainCount seedCount : Count64LE}
    {lhsSeed rhsSeed : List Byte}
    {lhsContext rhsContext : ProofEnvelopeContextWire}
    (hSeed : lhsSeed = rhsSeed)
    (hContext : lhsContext = rhsContext) :
    transcriptPhi81ChallengeElement deriver
        (proofEnvelopeTranscriptInit domainCount seedCount lhsSeed lhsContext) =
      transcriptPhi81ChallengeElement deriver
        (proofEnvelopeTranscriptInit domainCount seedCount rhsSeed rhsContext) := by
  rw [hSeed, hContext]

theorem proofEnvelopeOrderedAbsorbsChallengeSeed_eq
    (deriver : TranscriptChallengeSchedule Phi81ChallengeSeed)
    {domainCount seedCount : Count64LE}
    {lhsSeed rhsSeed : List Byte}
    {lhsContext rhsContext : ProofEnvelopeContextWire}
    {lhsAbsorbs rhsAbsorbs : List TranscriptFrame}
    (hSeed : lhsSeed = rhsSeed)
    (hContext : lhsContext = rhsContext)
    (hAbsorbs : lhsAbsorbs = rhsAbsorbs) :
    transcriptPhi81ChallengeSeed deriver
        (proofEnvelopeTranscriptWithAbsorbs
          domainCount seedCount lhsSeed lhsContext lhsAbsorbs) =
      transcriptPhi81ChallengeSeed deriver
        (proofEnvelopeTranscriptWithAbsorbs
          domainCount seedCount rhsSeed rhsContext rhsAbsorbs) := by
  rw [hSeed, hContext, hAbsorbs]

theorem proofEnvelopeOrderedAbsorbsChallengeElement_eq
    (deriver : TranscriptChallengeSchedule Phi81ChallengeSeed)
    {domainCount seedCount : Count64LE}
    {lhsSeed rhsSeed : List Byte}
    {lhsContext rhsContext : ProofEnvelopeContextWire}
    {lhsAbsorbs rhsAbsorbs : List TranscriptFrame}
    (hSeed : lhsSeed = rhsSeed)
    (hContext : lhsContext = rhsContext)
    (hAbsorbs : lhsAbsorbs = rhsAbsorbs) :
    transcriptPhi81ChallengeElement deriver
        (proofEnvelopeTranscriptWithAbsorbs
          domainCount seedCount lhsSeed lhsContext lhsAbsorbs) =
      transcriptPhi81ChallengeElement deriver
        (proofEnvelopeTranscriptWithAbsorbs
          domainCount seedCount rhsSeed rhsContext rhsAbsorbs) := by
  rw [hSeed, hContext, hAbsorbs]

theorem transcriptPhi81ChallengeCoefficients_bounded
    (deriver : TranscriptChallengeSchedule Phi81ChallengeSeed)
    (state : TranscriptState) :
    Phi81CoefficientsBounded normBound
      (transcriptPhi81ChallengeCoefficients deriver state) :=
  phi81ChallengeCoefficients_bounded (transcriptPhi81ChallengeSeed deriver state)

theorem transcriptPhi81ChallengeElement_mem_support
    (deriver : TranscriptChallengeSchedule Phi81ChallengeSeed)
    (state : TranscriptState) :
    transcriptPhi81ChallengeElement deriver state ∈ Phi81ChallengeSupport :=
  phi81ChallengeElement_mem_support (transcriptPhi81ChallengeSeed deriver state)

theorem transcriptExpandedChallengeElement_mem_support
    (deriver : TranscriptChallengeSchedule Phi81ExpandedChallengeSeed)
    (state : TranscriptState)
    (index : Fin challengeExpansionFactor) :
    transcriptExpandedChallengeElements deriver state index ∈ Phi81ChallengeSupport :=
  phi81ChallengeElement_mem_support
    ((transcriptExpandedChallengeSeed deriver state) index)

theorem transcriptPiRLCChallengeElements_mem_support {count : Nat}
    (deriver : TranscriptChallengeSchedule (PiRLCChallengeSeed count))
    (state : TranscriptState) :
    transcriptPiRLCChallengeElements deriver state ∈ PiRLCChallengeSupport count :=
  pirlcChallengeElements_mem_support (transcriptPiRLCChallengeSeed deriver state)

theorem transcriptStrongSamplingCapacity_of_profile_bounds
    {freshCount priorCount : Nat}
    (hFresh : freshCount ≤ freshBatchCount)
    (hPrior : priorCount ≤ decompositionLength) :
    StrongSamplingCapacity freshCount priorCount :=
  strongSamplingCapacity_of_profile_bounds hFresh hPrior

end SuperNeoFormal
