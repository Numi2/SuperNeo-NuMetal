import SuperNeoFormal.Transcript

/-!
NumiSeal dense sum-check transcript hook.

This module names the framed absorption schedule used by Swift's
`NumiSealSumcheckOracle` dense prover and verifier.  It is intentionally a
wire/transcript scaffold: it fixes the public frame order that later soundness
work can connect to the generic sum-check transcript model without re-deriving
the byte layout from implementation prose.
-/

namespace SuperNeoFormal

structure NumiSealLaneIDWire where
  byteCount : UInt64LE
  bytes : List Byte
  deriving DecidableEq

def numiSealLaneIDWireEncode (laneID : NumiSealLaneIDWire) : List Byte :=
  uint64LEEncode laneID.byteCount ++ laneID.bytes

theorem numiSealLaneIDWireEncode_length (laneID : NumiSealLaneIDWire) :
    (numiSealLaneIDWireEncode laneID).length = 8 + laneID.bytes.length := by
  simp [numiSealLaneIDWireEncode, uint64LEEncode_length]

structure NumiSealLaneKeyWire where
  profileID : UInt16LE
  shapeDigest : Digest256Wire
  verifierKeyDigest : Digest256Wire
  evalPointDigest : Digest256Wire
  laneID : NumiSealLaneIDWire
  deriving DecidableEq

def numiSealLaneKeyWireEncode (laneKey : NumiSealLaneKeyWire) : List Byte :=
  uint16LEEncode laneKey.profileID ++
    digest256Encode laneKey.shapeDigest ++
    digest256Encode laneKey.verifierKeyDigest ++
    digest256Encode laneKey.evalPointDigest ++
    numiSealLaneIDWireEncode laneKey.laneID

theorem numiSealLaneKeyWireEncode_length (laneKey : NumiSealLaneKeyWire) :
    (numiSealLaneKeyWireEncode laneKey).length =
      106 + laneKey.laneID.bytes.length := by
  simp [numiSealLaneKeyWireEncode, numiSealLaneIDWireEncode_length,
    uint16LEEncode_length, digest256Encode_length]
  omega

def numiSealSumcheckDomainSeparator : List Byte := [
  byteOfNat 83 (by native_decide),
  byteOfNat 117 (by native_decide),
  byteOfNat 112 (by native_decide),
  byteOfNat 101 (by native_decide),
  byteOfNat 114 (by native_decide),
  byteOfNat 78 (by native_decide),
  byteOfNat 101 (by native_decide),
  byteOfNat 111 (by native_decide),
  byteOfNat 45 (by native_decide),
  byteOfNat 78 (by native_decide),
  byteOfNat 117 (by native_decide),
  byteOfNat 77 (by native_decide),
  byteOfNat 101 (by native_decide),
  byteOfNat 116 (by native_decide),
  byteOfNat 97 (by native_decide),
  byteOfNat 108 (by native_decide),
  byteOfNat 46 (by native_decide),
  byteOfNat 110 (by native_decide),
  byteOfNat 117 (by native_decide),
  byteOfNat 109 (by native_decide),
  byteOfNat 105 (by native_decide),
  byteOfNat 115 (by native_decide),
  byteOfNat 101 (by native_decide),
  byteOfNat 97 (by native_decide),
  byteOfNat 108 (by native_decide),
  byteOfNat 46 (by native_decide),
  byteOfNat 115 (by native_decide),
  byteOfNat 117 (by native_decide),
  byteOfNat 109 (by native_decide),
  byteOfNat 99 (by native_decide),
  byteOfNat 104 (by native_decide),
  byteOfNat 101 (by native_decide),
  byteOfNat 99 (by native_decide),
  byteOfNat 107 (by native_decide),
  byteOfNat 46 (by native_decide),
  byteOfNat 118 (by native_decide),
  byteOfNat 49 (by native_decide)
]

def numiSealSumcheckDomainCount : Count64LE :=
  count64FromUInt64 ⟨numiSealSumcheckDomainSeparator.length, by native_decide⟩

def numiSealDigestFrame (digest : Digest256Wire) : TranscriptFrame :=
  transcriptFrame (count64FromUInt64 ⟨32, by native_decide⟩) (digest256Encode digest)

def numiSealUInt64Frame (value : UInt64LE) : TranscriptFrame :=
  transcriptFrame (count64FromUInt64 ⟨8, by native_decide⟩) (uint64LEEncode value)

structure NumiSealSumcheckTranscriptContextWire where
  linearResidualDigest : Digest256Wire
  scalarizationStatementDigest : Digest256Wire
  digitTensorDigest : Digest256Wire
  laneKey : NumiSealLaneKeyWire
  aggregateIndex : UInt64LE
  paddedSlotCount : UInt64LE
  variableCount : UInt64LE
  weightDigest : Digest256Wire
  deriving DecidableEq

structure NumiSealSumcheckTranscriptFrameCounts where
  laneKeyByteCount : Count64LE
  deriving DecidableEq

def numiSealSumcheckTranscriptAbsorbFrames
    (counts : NumiSealSumcheckTranscriptFrameCounts)
    (context : NumiSealSumcheckTranscriptContextWire) : List TranscriptFrame := [
  numiSealDigestFrame context.linearResidualDigest,
  numiSealDigestFrame context.scalarizationStatementDigest,
  numiSealDigestFrame context.digitTensorDigest,
  transcriptFrame counts.laneKeyByteCount (numiSealLaneKeyWireEncode context.laneKey),
  numiSealUInt64Frame context.aggregateIndex,
  numiSealUInt64Frame context.paddedSlotCount,
  numiSealUInt64Frame context.variableCount,
  numiSealDigestFrame context.weightDigest
]

theorem numiSealSumcheckTranscript_absorb_frame_count
    (counts : NumiSealSumcheckTranscriptFrameCounts)
    (context : NumiSealSumcheckTranscriptContextWire) :
    (numiSealSumcheckTranscriptAbsorbFrames counts context).length = 8 := by
  simp [numiSealSumcheckTranscriptAbsorbFrames]

theorem numiSealSumcheckTranscript_payload_order
    (counts : NumiSealSumcheckTranscriptFrameCounts)
    (context : NumiSealSumcheckTranscriptContextWire) :
    (numiSealSumcheckTranscriptAbsorbFrames counts context).map TranscriptFrame.payload = [
      digest256Encode context.linearResidualDigest,
      digest256Encode context.scalarizationStatementDigest,
      digest256Encode context.digitTensorDigest,
      numiSealLaneKeyWireEncode context.laneKey,
      uint64LEEncode context.aggregateIndex,
      uint64LEEncode context.paddedSlotCount,
      uint64LEEncode context.variableCount,
      digest256Encode context.weightDigest
    ] := by
  simp [numiSealSumcheckTranscriptAbsorbFrames, numiSealDigestFrame, numiSealUInt64Frame,
    transcriptFrame]

def numiSealDenseSumcheckTranscript
    (seedCount : Count64LE)
    (seed : List Byte)
    (counts : NumiSealSumcheckTranscriptFrameCounts)
    (context : NumiSealSumcheckTranscriptContextWire) : TranscriptState :=
  transcriptAbsorbFrames
    (transcriptInit numiSealSumcheckDomainCount numiSealSumcheckDomainSeparator seedCount seed)
    (numiSealSumcheckTranscriptAbsorbFrames counts context)

theorem numiSealDenseSumcheckTranscript_frames
    (seedCount : Count64LE)
    (seed : List Byte)
    (counts : NumiSealSumcheckTranscriptFrameCounts)
    (context : NumiSealSumcheckTranscriptContextWire) :
    (numiSealDenseSumcheckTranscript seedCount seed counts context).frames =
      [
        transcriptFrame numiSealSumcheckDomainCount numiSealSumcheckDomainSeparator,
        transcriptFrame seedCount seed
      ] ++ numiSealSumcheckTranscriptAbsorbFrames counts context :=
  rfl

end SuperNeoFormal
