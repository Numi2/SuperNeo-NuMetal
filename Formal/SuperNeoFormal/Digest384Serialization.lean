import SuperNeoFormal.Serialization

/-!
384-bit theorem-critical digest serialization.

The existing proof-envelope context remains available with 256-bit digest wires
for compatibility.  This module adds the 384-bit companion used by acceptance
and theorem-critical binding statements.
-/

namespace SuperNeoFormal

abbrev DigestWire (width : Nat) :=
  Fin width → Byte

def digestEncode (width : Nat) (digest : DigestWire width) : List Byte :=
  List.ofFn digest

theorem digestEncode_length (width : Nat) (digest : DigestWire width) :
    (digestEncode width digest).length = width := by
  simp [digestEncode]

theorem digestEncode_injective (width : Nat) :
    Function.Injective (digestEncode width) := by
  intro lhs rhs h
  simpa [digestEncode] using (List.ofFn_inj.mp h)

def digestDecode? (width : Nat) (bytes : List Byte) : Option (DigestWire width) :=
  fixedVectorDecode? width bytes

theorem digestDecode?_encode (width : Nat) (digest : DigestWire width) :
    digestDecode? width (digestEncode width digest) = some digest := by
  exact fixedVectorDecode?_ofFn width digest

abbrev Digest384Wire :=
  DigestWire 48

def digest384Encode (digest : Digest384Wire) : List Byte :=
  digestEncode 48 digest

theorem digest384Encode_length (digest : Digest384Wire) :
    (digest384Encode digest).length = 48 := by
  simp [digest384Encode, digestEncode_length]

theorem digest384Encode_injective :
    Function.Injective digest384Encode :=
  digestEncode_injective 48

def digest384Decode? (bytes : List Byte) : Option Digest384Wire :=
  digestDecode? 48 bytes

theorem digest384Decode?_encode (digest : Digest384Wire) :
    digest384Decode? (digest384Encode digest) = some digest := by
  exact digestDecode?_encode 48 digest

structure ProofEnvelopeContext384Wire where
  profileID : UInt16LE
  kind : ProofEnvelopeKindWire
  shapeDigest : Digest384Wire
  statementDigest : Digest384Wire
  verifierKeyDigest : Digest384Wire
  transcriptDomain : Digest384Wire
  deriving DecidableEq

theorem proofEnvelopeContext384Wire_ext
    {lhs rhs : ProofEnvelopeContext384Wire}
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
      simp only [ProofEnvelopeContext384Wire.mk.injEq]
      exact ⟨hProfileID, hKind, hShapeDigest, hStatementDigest,
        hVerifierKeyDigest, hTranscriptDomain⟩

def proofEnvelopeTranscriptBinding384Encode
    (context : ProofEnvelopeContext384Wire) : List Byte :=
  uint32LEEncode proofEnvelopeMagic ++
    uint16LEEncode proofEnvelopeVersion ++
    uint16LEEncode context.profileID ++
    [proofEnvelopeKindEncode context.kind] ++
    digest384Encode context.shapeDigest ++
    digest384Encode context.statementDigest ++
    digest384Encode context.verifierKeyDigest ++
    digest384Encode context.transcriptDomain

theorem proofEnvelopeTranscriptBinding384Encode_length
    (context : ProofEnvelopeContext384Wire) :
    (proofEnvelopeTranscriptBinding384Encode context).length = 201 := by
  simp [proofEnvelopeTranscriptBinding384Encode, uint32LEEncode_length,
    uint16LEEncode_length, digest384Encode_length]

theorem proofEnvelopeTranscriptBinding384Encode_magic_slice
    (context : ProofEnvelopeContext384Wire) :
    (proofEnvelopeTranscriptBinding384Encode context).take 4 =
      uint32LEEncode proofEnvelopeMagic := by
  simp [proofEnvelopeTranscriptBinding384Encode, uint32LEEncode_length]

theorem proofEnvelopeTranscriptBinding384Encode_version_slice
    (context : ProofEnvelopeContext384Wire) :
    ((proofEnvelopeTranscriptBinding384Encode context).drop 4).take 2 =
      uint16LEEncode proofEnvelopeVersion := by
  simp [proofEnvelopeTranscriptBinding384Encode, uint32LEEncode_length,
    uint16LEEncode_length]

theorem proofEnvelopeTranscriptBinding384Encode_profile_slice
    (context : ProofEnvelopeContext384Wire) :
    ((proofEnvelopeTranscriptBinding384Encode context).drop 6).take 2 =
      uint16LEEncode context.profileID := by
  simp [proofEnvelopeTranscriptBinding384Encode, List.drop_append,
    List.drop_eq_nil_of_le, uint32LEEncode_length, uint16LEEncode_length]

theorem proofEnvelopeTranscriptBinding384Encode_kind_slice
    (context : ProofEnvelopeContext384Wire) :
    ((proofEnvelopeTranscriptBinding384Encode context).drop 8).take 1 =
      [proofEnvelopeKindEncode context.kind] := by
  simp [proofEnvelopeTranscriptBinding384Encode, List.drop_append,
    List.drop_eq_nil_of_le, uint32LEEncode_length, uint16LEEncode_length]

theorem proofEnvelopeTranscriptBinding384Encode_shape_slice
    (context : ProofEnvelopeContext384Wire) :
    ((proofEnvelopeTranscriptBinding384Encode context).drop 9).take 48 =
      digest384Encode context.shapeDigest := by
  simp [proofEnvelopeTranscriptBinding384Encode, List.drop_append,
    List.drop_eq_nil_of_le, uint32LEEncode_length, uint16LEEncode_length,
    digest384Encode_length]

theorem proofEnvelopeTranscriptBinding384Encode_statement_slice
    (context : ProofEnvelopeContext384Wire) :
    ((proofEnvelopeTranscriptBinding384Encode context).drop 57).take 48 =
      digest384Encode context.statementDigest := by
  simp [proofEnvelopeTranscriptBinding384Encode, List.drop_append,
    List.drop_eq_nil_of_le, uint32LEEncode_length, uint16LEEncode_length,
    digest384Encode_length]

theorem proofEnvelopeTranscriptBinding384Encode_verifierKey_slice
    (context : ProofEnvelopeContext384Wire) :
    ((proofEnvelopeTranscriptBinding384Encode context).drop 105).take 48 =
      digest384Encode context.verifierKeyDigest := by
  simp [proofEnvelopeTranscriptBinding384Encode, List.drop_append,
    List.drop_eq_nil_of_le, uint32LEEncode_length, uint16LEEncode_length,
    digest384Encode_length]

theorem proofEnvelopeTranscriptBinding384Encode_transcriptDomain_slice
    (context : ProofEnvelopeContext384Wire) :
    ((proofEnvelopeTranscriptBinding384Encode context).drop 153).take 48 =
      digest384Encode context.transcriptDomain := by
  simp [proofEnvelopeTranscriptBinding384Encode, List.drop_append,
    List.drop_eq_nil_of_le, uint32LEEncode_length, uint16LEEncode_length,
    digest384Encode_length]

def proofEnvelopeTranscriptBinding384Decode?
    (bytes : List Byte) : Option ProofEnvelopeContext384Wire :=
  if bytes.length = 201 then
    if bytes.take 4 = uint32LEEncode proofEnvelopeMagic then
      if (bytes.drop 4).take 2 = uint16LEEncode proofEnvelopeVersion then
        match uintLEDecode? 2 ((bytes.drop 6).take 2),
            proofEnvelopeKindListDecode? ((bytes.drop 8).take 1),
            digest384Decode? ((bytes.drop 9).take 48),
            digest384Decode? ((bytes.drop 57).take 48),
            digest384Decode? ((bytes.drop 105).take 48),
            digest384Decode? ((bytes.drop 153).take 48) with
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

theorem proofEnvelopeTranscriptBinding384Decode?_encode
    (context : ProofEnvelopeContext384Wire) :
    proofEnvelopeTranscriptBinding384Decode?
      (proofEnvelopeTranscriptBinding384Encode context) = some context := by
  simp [proofEnvelopeTranscriptBinding384Decode?,
    proofEnvelopeTranscriptBinding384Encode_length,
    proofEnvelopeTranscriptBinding384Encode_magic_slice,
    proofEnvelopeTranscriptBinding384Encode_version_slice,
    proofEnvelopeTranscriptBinding384Encode_profile_slice,
    proofEnvelopeTranscriptBinding384Encode_kind_slice,
    proofEnvelopeTranscriptBinding384Encode_shape_slice,
    proofEnvelopeTranscriptBinding384Encode_statement_slice,
    proofEnvelopeTranscriptBinding384Encode_verifierKey_slice,
    proofEnvelopeTranscriptBinding384Encode_transcriptDomain_slice,
    uint16LEEncode, uintLEDecode?_encode, digest384Decode?_encode,
    proofEnvelopeKindListDecode?_encode]

theorem proofEnvelopeTranscriptBinding384Decode?_length_of_some
    {bytes : List Byte} {context : ProofEnvelopeContext384Wire}
    (hDecode : proofEnvelopeTranscriptBinding384Decode? bytes = some context) :
    bytes.length = 201 := by
  unfold proofEnvelopeTranscriptBinding384Decode? at hDecode
  split_ifs at hDecode with hLength hMagic hVersion
  exact hLength

theorem proofEnvelopeTranscriptBinding384Decode?_magic_of_some
    {bytes : List Byte} {context : ProofEnvelopeContext384Wire}
    (hDecode : proofEnvelopeTranscriptBinding384Decode? bytes = some context) :
    bytes.take 4 = uint32LEEncode proofEnvelopeMagic := by
  unfold proofEnvelopeTranscriptBinding384Decode? at hDecode
  split_ifs at hDecode with hLength hMagic hVersion
  exact hMagic

theorem proofEnvelopeTranscriptBinding384Decode?_version_of_some
    {bytes : List Byte} {context : ProofEnvelopeContext384Wire}
    (hDecode : proofEnvelopeTranscriptBinding384Decode? bytes = some context) :
    (bytes.drop 4).take 2 = uint16LEEncode proofEnvelopeVersion := by
  unfold proofEnvelopeTranscriptBinding384Decode? at hDecode
  split_ifs at hDecode with hLength hMagic hVersion
  exact hVersion

theorem proofEnvelopeTranscriptBinding384Encode_injective :
    Function.Injective proofEnvelopeTranscriptBinding384Encode := by
  intro lhs rhs h
  have hAfterCommon :
      uint16LEEncode lhs.profileID ++
          [proofEnvelopeKindEncode lhs.kind] ++
          digest384Encode lhs.shapeDigest ++
          digest384Encode lhs.statementDigest ++
          digest384Encode lhs.verifierKeyDigest ++
          digest384Encode lhs.transcriptDomain =
        uint16LEEncode rhs.profileID ++
          [proofEnvelopeKindEncode rhs.kind] ++
          digest384Encode rhs.shapeDigest ++
          digest384Encode rhs.statementDigest ++
          digest384Encode rhs.verifierKeyDigest ++
          digest384Encode rhs.transcriptDomain := by
    simpa [proofEnvelopeTranscriptBinding384Encode] using h
  have hProfileBytes :
      uint16LEEncode lhs.profileID = uint16LEEncode rhs.profileID := by
    have hTake := congrArg (List.take 2) hAfterCommon
    simpa [uint16LEEncode_length] using hTake
  have hAfterProfile :
      [proofEnvelopeKindEncode lhs.kind] ++
          digest384Encode lhs.shapeDigest ++
          digest384Encode lhs.statementDigest ++
          digest384Encode lhs.verifierKeyDigest ++
          digest384Encode lhs.transcriptDomain =
        [proofEnvelopeKindEncode rhs.kind] ++
          digest384Encode rhs.shapeDigest ++
          digest384Encode rhs.statementDigest ++
          digest384Encode rhs.verifierKeyDigest ++
          digest384Encode rhs.transcriptDomain := by
    have hDrop := congrArg (List.drop 2) hAfterCommon
    simpa [uint16LEEncode_length] using hDrop
  have hKindByte :
      proofEnvelopeKindEncode lhs.kind = proofEnvelopeKindEncode rhs.kind := by
    have hTake := congrArg (List.take 1) hAfterProfile
    simpa using hTake
  have hAfterKind :
      digest384Encode lhs.shapeDigest ++
          digest384Encode lhs.statementDigest ++
          digest384Encode lhs.verifierKeyDigest ++
          digest384Encode lhs.transcriptDomain =
        digest384Encode rhs.shapeDigest ++
          digest384Encode rhs.statementDigest ++
          digest384Encode rhs.verifierKeyDigest ++
          digest384Encode rhs.transcriptDomain := by
    have hDrop := congrArg (List.drop 1) hAfterProfile
    simpa using hDrop
  have hShapeBytes :
      digest384Encode lhs.shapeDigest = digest384Encode rhs.shapeDigest := by
    have hTake := congrArg (List.take 48) hAfterKind
    simpa [digest384Encode_length] using hTake
  have hAfterShape :
      digest384Encode lhs.statementDigest ++
          digest384Encode lhs.verifierKeyDigest ++
          digest384Encode lhs.transcriptDomain =
        digest384Encode rhs.statementDigest ++
          digest384Encode rhs.verifierKeyDigest ++
          digest384Encode rhs.transcriptDomain := by
    have hDrop := congrArg (List.drop 48) hAfterKind
    simpa [digest384Encode_length] using hDrop
  have hStatementBytes :
      digest384Encode lhs.statementDigest = digest384Encode rhs.statementDigest := by
    have hTake := congrArg (List.take 48) hAfterShape
    simpa [digest384Encode_length] using hTake
  have hAfterStatement :
      digest384Encode lhs.verifierKeyDigest ++
          digest384Encode lhs.transcriptDomain =
        digest384Encode rhs.verifierKeyDigest ++
          digest384Encode rhs.transcriptDomain := by
    have hDrop := congrArg (List.drop 48) hAfterShape
    simpa [digest384Encode_length] using hDrop
  have hVerifierKeyBytes :
      digest384Encode lhs.verifierKeyDigest = digest384Encode rhs.verifierKeyDigest := by
    have hTake := congrArg (List.take 48) hAfterStatement
    simpa [digest384Encode_length] using hTake
  have hTranscriptDomainBytes :
      digest384Encode lhs.transcriptDomain = digest384Encode rhs.transcriptDomain := by
    have hDrop := congrArg (List.drop 48) hAfterStatement
    simpa [digest384Encode_length] using hDrop
  exact proofEnvelopeContext384Wire_ext
    (uint16LEEncode_injective hProfileBytes)
    (proofEnvelopeKindEncode_injective hKindByte)
    (digest384Encode_injective hShapeBytes)
    (digest384Encode_injective hStatementBytes)
    (digest384Encode_injective hVerifierKeyBytes)
    (digest384Encode_injective hTranscriptDomainBytes)

end SuperNeoFormal
