import SuperNeoFormal.Digest384Serialization

/-!
Typed digest wire semantics.

The theorem surface talks about several semantically different digest domains.
This module makes that taxonomy explicit and parameterizes the digest width.
The default width remains 256 bits for compatibility, while the theorem-critical
binding instance is 384 bits.
-/

namespace SuperNeoFormal

inductive TypedDigestDomainFamily where
  | artifact
  | provenance
  | replay
  | componentRoot
  | randomnessSession
  | leakage
  | carry
  deriving DecidableEq

abbrev TypedDigestKind :=
  TypedDigestDomainFamily

def typedDigestDomainFamilyEncode : TypedDigestDomainFamily → Byte
  | .artifact => byteOfNat 16 (by native_decide)
  | .provenance => byteOfNat 17 (by native_decide)
  | .replay => byteOfNat 18 (by native_decide)
  | .componentRoot => byteOfNat 19 (by native_decide)
  | .randomnessSession => byteOfNat 20 (by native_decide)
  | .leakage => byteOfNat 21 (by native_decide)
  | .carry => byteOfNat 22 (by native_decide)

def typedDigestKindEncode : TypedDigestKind → Byte :=
  typedDigestDomainFamilyEncode

theorem typedDigestDomainFamilyEncode_injective :
    Function.Injective typedDigestDomainFamilyEncode := by
  intro lhs rhs h
  cases lhs <;> cases rhs <;> simp [typedDigestDomainFamilyEncode, byteOfNat] at h ⊢

theorem typedDigestKindEncode_injective :
    Function.Injective typedDigestKindEncode :=
  typedDigestDomainFamilyEncode_injective

def theoremCriticalDigestDomainFamilies : List TypedDigestDomainFamily :=
  [
    .artifact,
    .provenance,
    .replay,
    .componentRoot,
    .randomnessSession,
    .leakage,
    .carry
  ]

theorem theoremCriticalDigestDomainFamilies_pairwise_distinct :
    theoremCriticalDigestDomainFamilies.Pairwise (· ≠ ·) := by
  native_decide

structure TypedDigestWire (width : Nat := 32) where
  domain : TypedDigestDomainFamily
  digest : DigestWire width
  deriving DecidableEq

abbrev TypedDigest384Wire :=
  TypedDigestWire 48

theorem typedDigestWire_ext
    {width : Nat}
    {lhs rhs : TypedDigestWire width}
    (hDomain : lhs.domain = rhs.domain)
    (hDigest : lhs.digest = rhs.digest) :
    lhs = rhs := by
  cases lhs
  cases rhs
  cases hDomain
  cases hDigest
  rfl

def typedDigestEncode {width : Nat} (value : TypedDigestWire width) : List Byte :=
  [typedDigestDomainFamilyEncode value.domain] ++ digestEncode width value.digest

theorem typedDigestEncode_length {width : Nat} (value : TypedDigestWire width) :
    (typedDigestEncode value).length = 1 + width := by
  simp [typedDigestEncode, digestEncode_length]
  omega

def typedDigest384Encode (value : TypedDigest384Wire) : List Byte :=
  typedDigestEncode value

theorem typedDigest384Encode_length (value : TypedDigest384Wire) :
    (typedDigest384Encode value).length = 49 := by
  simp [typedDigest384Encode, typedDigestEncode_length]

theorem typedDigestEncode_kind_slice {width : Nat} (value : TypedDigestWire width) :
    (typedDigestEncode value).take 1 =
      [typedDigestDomainFamilyEncode value.domain] := by
  simp [typedDigestEncode]

theorem typedDigestEncode_digest_slice {width : Nat} (value : TypedDigestWire width) :
    (typedDigestEncode value).drop 1 =
      digestEncode width value.digest := by
  simp [typedDigestEncode]

theorem typedDigestEncode_injective {width : Nat} :
    Function.Injective (typedDigestEncode : TypedDigestWire width → List Byte) := by
  intro lhs rhs h
  have hDomainBytes :
      [typedDigestDomainFamilyEncode lhs.domain] =
        [typedDigestDomainFamilyEncode rhs.domain] := by
    have hTake := congrArg (List.take 1) h
    simpa [typedDigestEncode_kind_slice] using hTake
  have hDigestBytes :
      digestEncode width lhs.digest =
        digestEncode width rhs.digest := by
    have hDrop := congrArg (List.drop 1) h
    simpa [typedDigestEncode_digest_slice] using hDrop
  exact typedDigestWire_ext
    (typedDigestDomainFamilyEncode_injective (List.cons.inj hDomainBytes).1)
    (digestEncode_injective width hDigestBytes)

theorem typedDigest384Encode_injective :
    Function.Injective typedDigest384Encode := by
  intro lhs rhs h
  exact typedDigestEncode_injective h

theorem typedDigestDomainSeparation
    {width : Nat}
    {lhs rhs : TypedDigestWire width}
    (hDomain : lhs.domain ≠ rhs.domain) :
    typedDigestEncode lhs ≠ typedDigestEncode rhs := by
  intro hEncode
  exact hDomain (congrArg TypedDigestWire.domain (typedDigestEncode_injective hEncode))

theorem typedDigestDomainFamily_artifact_ne_provenance :
    TypedDigestDomainFamily.artifact ≠ TypedDigestDomainFamily.provenance := by
  native_decide

theorem typedDigestDomainFamily_artifact_ne_replay :
    TypedDigestDomainFamily.artifact ≠ TypedDigestDomainFamily.replay := by
  native_decide

theorem typedDigestDomainFamily_provenance_ne_replay :
    TypedDigestDomainFamily.provenance ≠ TypedDigestDomainFamily.replay := by
  native_decide

theorem typedDigestDomainFamily_componentRoot_ne_randomnessSession :
    TypedDigestDomainFamily.componentRoot ≠ TypedDigestDomainFamily.randomnessSession := by
  native_decide

theorem typedDigestDomainFamily_leakage_ne_carry :
    TypedDigestDomainFamily.leakage ≠ TypedDigestDomainFamily.carry := by
  native_decide

def typedDigestFrameTag : Byte :=
  byteOfNat 25 (by native_decide)

def typedDigestFrameWithBound
    {width : Nat}
    (hWidth : 1 + width < 256 ^ 8)
    (value : TypedDigestWire width) : FramedBytes where
  tag := typedDigestFrameTag
  count := count64FromUInt64 ⟨1 + width, hWidth⟩
  payload := typedDigestEncode value

theorem typedDigestFrameWithBound_payload_length
    {width : Nat}
    (hWidth : 1 + width < 256 ^ 8)
    (value : TypedDigestWire width) :
    (typedDigestFrameWithBound hWidth value).payload.length = 1 + width := by
  simp [typedDigestFrameWithBound, typedDigestEncode_length]

def typedDigestFrame (value : TypedDigestWire) : FramedBytes :=
  typedDigestFrameWithBound (by native_decide : 1 + 32 < 256 ^ 8) value

theorem typedDigestFrame_payload_length (value : TypedDigestWire) :
    (typedDigestFrame value).payload.length = 33 := by
  simp [typedDigestFrame, typedDigestFrameWithBound_payload_length]

def typedDigest384Frame (value : TypedDigest384Wire) : FramedBytes :=
  typedDigestFrameWithBound (by native_decide : 1 + 48 < 256 ^ 8) value

theorem typedDigest384Frame_payload_length (value : TypedDigest384Wire) :
    (typedDigest384Frame value).payload.length = 49 := by
  simp [typedDigest384Frame, typedDigestFrameWithBound_payload_length]

theorem typedDigestFrameWithBoundEncode_injective
    {width : Nat}
    {hWidth : 1 + width < 256 ^ 8} :
    Function.Injective
      (fun value : TypedDigestWire width =>
        frameEncode (typedDigestFrameWithBound hWidth value)) := by
  intro lhs rhs h
  have hFrame := frameEncode_injective h
  exact typedDigestEncode_injective (congrArg FramedBytes.payload hFrame)

theorem typedDigestFrameEncode_injective :
    Function.Injective (fun value => frameEncode (typedDigestFrame value)) :=
  typedDigestFrameWithBoundEncode_injective

theorem typedDigest384FrameEncode_injective :
    Function.Injective (fun value => frameEncode (typedDigest384Frame value)) :=
  typedDigestFrameWithBoundEncode_injective

structure TypedDigestBinding (width : Nat := 32) where
  expected : TypedDigestWire width
  observed : TypedDigestWire width

def TypedDigestBinding.Holds {width : Nat} (binding : TypedDigestBinding width) : Prop :=
  binding.expected = binding.observed

abbrev TypedDigest384Binding :=
  TypedDigestBinding 48

theorem typedDigestBinding_holds_of_encoded_eq
    {width : Nat}
    {binding : TypedDigestBinding width}
    (hEncode :
      typedDigestEncode binding.expected =
        typedDigestEncode binding.observed) :
    binding.Holds :=
  typedDigestEncode_injective hEncode

theorem typedDigest384Binding_holds_of_encoded_eq
    {binding : TypedDigest384Binding}
    (hEncode :
      typedDigest384Encode binding.expected =
        typedDigest384Encode binding.observed) :
    binding.Holds :=
  typedDigest384Encode_injective hEncode

theorem typedDigestBinding_holds_of_frame_eq
    {binding : TypedDigestBinding}
    (hFrame :
      frameEncode (typedDigestFrame binding.expected) =
        frameEncode (typedDigestFrame binding.observed)) :
    binding.Holds :=
  typedDigestFrameEncode_injective hFrame

theorem typedDigest384Binding_holds_of_frame_eq
    {binding : TypedDigest384Binding}
    (hFrame :
      frameEncode (typedDigest384Frame binding.expected) =
        frameEncode (typedDigest384Frame binding.observed)) :
    binding.Holds :=
  typedDigest384FrameEncode_injective hFrame

end SuperNeoFormal
