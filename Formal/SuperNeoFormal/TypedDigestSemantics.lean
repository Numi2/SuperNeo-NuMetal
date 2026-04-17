import SuperNeoFormal.Serialization

/-!
Typed digest wire semantics.

The theorem-surface files talk about many different digest obligations.  This
module gives those obligations a byte-typed object: a digest is not just 32
bytes, but 32 bytes paired with an explicit semantic kind and an injective wire
encoding.
-/

namespace SuperNeoFormal

inductive TypedDigestKind where
  | producerEnvelope
  | producerTranscript
  | parentStatement
  | parentPublicStatement
  | residualOpening
  | consumerContext
  | productContext
  | carry
  | leakage
  deriving DecidableEq

def typedDigestKindEncode : TypedDigestKind → Byte
  | .producerEnvelope => byteOfNat 16 (by native_decide)
  | .producerTranscript => byteOfNat 17 (by native_decide)
  | .parentStatement => byteOfNat 18 (by native_decide)
  | .parentPublicStatement => byteOfNat 19 (by native_decide)
  | .residualOpening => byteOfNat 20 (by native_decide)
  | .consumerContext => byteOfNat 21 (by native_decide)
  | .productContext => byteOfNat 22 (by native_decide)
  | .carry => byteOfNat 23 (by native_decide)
  | .leakage => byteOfNat 24 (by native_decide)

theorem typedDigestKindEncode_injective :
    Function.Injective typedDigestKindEncode := by
  intro lhs rhs h
  cases lhs <;> cases rhs <;> simp [typedDigestKindEncode, byteOfNat] at h ⊢

structure TypedDigestWire where
  kind : TypedDigestKind
  digest : Digest256Wire
  deriving DecidableEq

theorem typedDigestWire_ext
    {lhs rhs : TypedDigestWire}
    (hKind : lhs.kind = rhs.kind)
    (hDigest : lhs.digest = rhs.digest) :
    lhs = rhs := by
  cases lhs
  cases rhs
  cases hKind
  cases hDigest
  rfl

def typedDigestEncode (value : TypedDigestWire) : List Byte :=
  [typedDigestKindEncode value.kind] ++ digest256Encode value.digest

theorem typedDigestEncode_length (value : TypedDigestWire) :
    (typedDigestEncode value).length = 33 := by
  simp [typedDigestEncode, digest256Encode_length]

theorem typedDigestEncode_kind_slice (value : TypedDigestWire) :
    (typedDigestEncode value).take 1 =
      [typedDigestKindEncode value.kind] := by
  simp [typedDigestEncode]

theorem typedDigestEncode_digest_slice (value : TypedDigestWire) :
    (typedDigestEncode value).drop 1 =
      digest256Encode value.digest := by
  simp [typedDigestEncode]

theorem typedDigestEncode_injective :
    Function.Injective typedDigestEncode := by
  intro lhs rhs h
  have hKindBytes :
      [typedDigestKindEncode lhs.kind] =
        [typedDigestKindEncode rhs.kind] := by
    have hTake := congrArg (List.take 1) h
    simpa [typedDigestEncode_kind_slice] using hTake
  have hDigestBytes :
      digest256Encode lhs.digest =
        digest256Encode rhs.digest := by
    have hDrop := congrArg (List.drop 1) h
    simpa [typedDigestEncode_digest_slice] using hDrop
  exact typedDigestWire_ext
    (typedDigestKindEncode_injective (List.cons.inj hKindBytes).1)
    (digest256Encode_injective hDigestBytes)

def typedDigestFrameTag : Byte :=
  byteOfNat 25 (by native_decide)

def typedDigestFrame (value : TypedDigestWire) : FramedBytes where
  tag := typedDigestFrameTag
  count := count64FromUInt64 ⟨33, by native_decide⟩
  payload := typedDigestEncode value

theorem typedDigestFrame_payload_length (value : TypedDigestWire) :
    (typedDigestFrame value).payload.length = 33 := by
  simp [typedDigestFrame, typedDigestEncode_length]

theorem typedDigestFrameEncode_injective :
    Function.Injective (fun value => frameEncode (typedDigestFrame value)) := by
  intro lhs rhs h
  have hFrame := frameEncode_injective h
  exact typedDigestEncode_injective (congrArg FramedBytes.payload hFrame)

structure TypedDigestBinding where
  expected : TypedDigestWire
  observed : TypedDigestWire

def TypedDigestBinding.Holds (binding : TypedDigestBinding) : Prop :=
  binding.expected = binding.observed

theorem typedDigestBinding_holds_of_encoded_eq
    {binding : TypedDigestBinding}
    (hEncode :
      typedDigestEncode binding.expected =
        typedDigestEncode binding.observed) :
    binding.Holds :=
  typedDigestEncode_injective hEncode

theorem typedDigestBinding_holds_of_frame_eq
    {binding : TypedDigestBinding}
    (hFrame :
      frameEncode (typedDigestFrame binding.expected) =
        frameEncode (typedDigestFrame binding.observed)) :
    binding.Holds :=
  typedDigestFrameEncode_injective hFrame

end SuperNeoFormal
