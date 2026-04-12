# Proof Envelope Format

Proof envelopes are the public binary containers used by this repository to bind
proof bytes to the statement that a verifier intends to check. They are versioned
and deterministic, and all multi-byte integers are little-endian.

This document describes `ProofEnvelopeHeader.version == 4`.

## Envelope Kinds

| Kind | Raw value | Body type | Meaning |
| --- | ---: | --- | --- |
| `foldReduction` | `1` | `FoldProof` | Verifies PiCCS, PiRLC, and PiDEC and returns output CE claims. It is not terminal acceptance. |
| `terminalLocal` | `2` | `TerminalFoldProof` | Verifies the fold proof plus local terminal CE opening proof for the output claims. |
| `compressedPublic` | `3` | `CompressedTerminalProof` | Verifies a public compressed terminal envelope by digest-binding the fold proof and CE opening proof, then reconstructing terminal verification. |

Do not treat kind `1` as a complete proof of an application statement. It is a
fold reduction whose output claims must still be checked.

## Header Layout

`ProofEnvelopeHeader.byteCount == 141`.

| Offset | Size | Field | Encoding |
| ---: | ---: | --- | --- |
| `0` | `4` | magic | UInt32 little-endian value `0x4E554D51` |
| `4` | `2` | version | UInt16 little-endian, currently `4` |
| `6` | `2` | profile ID | UInt16 little-endian, `1` for `Goldilocks/Phi81(d=54)` |
| `8` | `1` | proof kind | UInt8, values listed above |
| `9` | `32` | shape digest | SHA-256 digest bytes |
| `41` | `32` | statement digest | SHA-256 digest bytes |
| `73` | `32` | verifier-key digest | SHA-256 digest bytes |
| `105` | `32` | transcript domain | SHA-256 digest bytes |
| `137` | `4` | body length | UInt32 little-endian |

The body immediately follows the header and must contain exactly `bodyLength`
bytes. Parsers reject unsupported magic, unsupported version, unsupported kind,
body length mismatch, malformed body encodings, and trailing bytes.

## Header Binding

The prover and verifier use the header, except `bodyLength`, as the transcript
binding seed:

```text
magic || version || profileID || kind ||
shapeDigest || statementDigest || verifierKeyDigest || transcriptDomain
```

This means that a proof generated for one profile, proof kind, CCS shape,
statement, verifier key, or transcript domain should not verify under another
context.

The default transcript-domain digest is:

```text
SHA256("SuperNeo-NuMetal.fold.v1")
```

Compressed public terminal proofs additionally use:

```text
SHA256("SuperNeo-NuMetal.compressed-public.statement.v1")
SHA256("SuperNeo-NuMetal.compressed-public.proof.v2")
```

## Digest Inputs

The verifier recomputes and checks the public context:

- `shapeDigest` must match the supplied `CCSShape`.
- `statementDigest` must match the `CCSStatement` built from the shape digest,
  public CCS instances, and prior CE instances.
- `verifierKeyDigest` must match the supplied `AjtaiCommitmentKey`.
- `transcriptDomain` must match the caller's expected `ProofEnvelopeContext`.

The verifier key digest is SHA-256 over:

```text
"SuperNeo-NuMetal.ajtai-verifier-key.v1" ||
profileID || kappa || ringDegree || normBound || decompositionLength ||
matrix.rows || matrix.columns || matrix elements
```

Integer fields in this digest are little-endian and matrix elements use the
canonical ring encoding.

## Canonical Element Encodings

| Type | Encoding |
| --- | --- |
| `GoldilocksField` | 8 little-endian bytes, value must be `< q` |
| `GoldilocksExt2` | `c0 || c1`, two canonical field elements |
| `CyclotomicRing54` | 54 canonical field elements |
| `CyclotomicExt2Ring54` | 54 canonical extension-field elements |
| `AjtaiCommitment` | `kappa` ring elements; `kappa = 18` for profile 1 |
| Count | UInt64 little-endian with context-specific maximums |

The parser rejects non-canonical field elements, excessive counts, empty objects
where the protocol requires data, and count/body inconsistencies before the
verifier reaches algebraic checks.

## Body Sketch

`FoldProof` is encoded as:

```text
PiCCSSection || PiRLCSection || PiDECSection
```

`PiCCSSection` is:

```text
SumcheckProof || count(finalClaims) || finalClaims...
```

`PiRLCSection` is:

```text
count(challenges) || challenge rings... || foldedClaim
```

The challenge count must equal the PiCCS final-claim count.

`PiDECSection` is:

```text
DecompositionProof || count(outputClaims) || outputClaims...
```

The output-claim count must equal `decompositionLength`, and decomposition
commitments/evaluations must match the output claims.

`TerminalFoldProof` is:

```text
FoldProof || TerminalCEStatement || CEOpeningProof
```

The terminal statement output claims must match the fold proof output claims.

`CompressedTerminalProof` is:

```text
CompressedTerminalStatement ||
foldProofDigest || ceOpeningProofDigest || compressionDigest ||
FoldProof || CEOpeningProof
```

The parser recomputes `foldProofDigest`, `ceOpeningProofDigest`, and
`compressionDigest` before verification accepts.

## Versioning Policy

Any incompatible change to field encodings, count encodings, proof body order,
header fields, transcript binding, profile semantics, or proof-kind semantics
requires a new `ProofEnvelopeHeader.version`.

Any parameter change that preserves the byte grammar but changes security
semantics requires a new `profileID`.
