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
| `numiSealTerminal` | `4` | `NumiSealProof` | NumiSeal terminal-seal container. It is accepted only by NumiSeal-specific terminal policy and preflight. |

Do not treat kind `1` as a complete proof of an application statement. It is a
fold reduction whose output claims must still be checked.

Application integrations that need terminal acceptance should use
`SuperNeoTerminalProofAcceptancePolicy` and
`SuperNeoVerifier.verifyTerminalProofEnvelope(..., policy:)`. The policy
validates trusted profile, shape, statement, verifier-key, transcript-domain,
accepted terminal envelope form, and optional proof byte limit before dispatching
to terminal verification.

NumiSeal terminal envelopes deliberately use a separate policy surface:
`NumiSealTerminalProofAcceptancePolicy`. Existing terminal-local and compressed
terminal policy rejects kind `4`, and NumiSeal policy rejects kinds `1`, `2`,
and `3` before proof-body parsing advances to algebraic verification.

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

Code that needs to inspect or preflight public bytes should use
`ProofEnvelopeHeader.parsePrefix(from:)` followed by
`validateEnvelopeLength(totalByteCount:)`. The CLI and checked-in vector
validator use this path before trusting JSON wrapper metadata.

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

`NumiSealProof` is:

```text
bodyVersion ||
framed(NumiSealPublicStatement) ||
aggregateCount ||
laneProofCount ||
framed(NumiSealLaneProof)... ||
componentDigestRoot ||
transcriptDigest
```

`bodyVersion` is UInt16 little-endian value `10`. `aggregateCount` and
`laneProofCount` are UInt64 little-endian counts and must match exactly.
Each framed object is `byteCount || bytes` where `byteCount` is UInt64
little-endian and the parser enforces context-specific maximums before reading
the payload. Trailing bytes fail.

`NumiSealLaneProof` is:

```text
laneKey ||
aggregateIndex ||
aggregateDigest ||
decompositionKeyDigest ||
decompositionCommitment ||
scalarizationDigest ||
framed(SumcheckProof) ||
framed(residualOpening) ||
carryTag ||
optional framed(carryClaim)
```

`carryTag == 0` means the carry component is absent. `carryTag == 1` means a
carry claim is present and framed immediately after the tag. Other tag values
fail. Absent carry is still bound into `componentDigestRoot` with a typed
`numiseal.absent-component.v1` leaf, never a zero digest.

NumiSeal component leaves use these labels:

| Component | Label |
| --- | --- |
| Public statement | `numiseal.public-statement.v1` |
| Lane aggregate | `numiseal.lane-aggregate.v1` |
| Decomposition metadata | `numiseal.decomposition.v1` |
| Scalarization | `numiseal.scalarization.v1` |
| Sum-check | `numiseal.sumcheck.v1` |
| Residual opening | `numiseal.residual-opening.v1` |
| Carry claim | `numiseal.carry.v1` |
| Absent optional component | `numiseal.absent-component.v1` |

`componentDigestRoot` is `numiseal.component-digest-root.v1` over typed component
leaf digests in public-statement then lane-major, aggregate-index order.
`transcriptDigest` is `numiseal.proof-transcript.v1` over body version, public
statement digest, aggregate counts, lane-proof digests, and the component root.

### NumiSeal Decomposition Handoff

The decomposition key digest carried by `NumiSealLaneProof` is now derived from
public data, not an arbitrary placeholder. `NumiSealDecompositionKeyDerivation`
is:

```text
domain ||
version ||
verifierKeyDigest ||
laneKey ||
aggregateIndex ||
requiredColumnCount ||
derivationDigest
```

`domain` is `SHA256("SuperNeo-NuMetal.numiseal.decomposition-key.v1")`.
`version` is UInt16 little-endian value `10`. `aggregateIndex` and
`requiredColumnCount` are UInt64 little-endian counts. `derivationDigest` is:

```text
H_numiseal("numiseal.decomposition-key.v1",
  version || verifierKeyDigest || laneKey || aggregateIndex ||
  requiredColumnCount)
```

That digest is used as the deterministic seed for the derived Ajtai
decomposition key `A_dec`. Changing verifier key digest, lane key, aggregate
index, or required column count changes the key digest.

`NumiSealDigitTensor` is the bounded private witness-side byte grammar used by
the CPU reference decomposition commitment tests:

```text
domain ||
version ||
laneKey ||
aggregateIndex ||
columnCount ||
activeDigitCount ||
digit...
```

`domain` is `SHA256("SuperNeo-NuMetal.numiseal.digit-tensor.v1")`.
Digits are one byte: `0x00` for `0`, `0x01` for `1`, and `0xFF` for `-1`.
Every other byte fails. The number of digit bytes must be
`columnCount * 54`, and all positions at or beyond `activeDigitCount` must be
zero. The current bounded parser caps `columnCount` at `4096`.

`NumiSealDecompositionCommitment` binds:

```text
domain ||
version ||
framed(NumiSealDecompositionKeyDerivation) ||
digitTensorDigest ||
decompositionCommitment ||
commitmentDigest
```

The commitment is the CPU reference Ajtai commitment of the reconstructed
ternary digit-tensor message under the derived key. This is a decomposition
handoff fixture and pre-sum-check binding point; it is not yet a complete
NumiSeal verifier.

### NumiSeal Scalarization Handoff

The scalarization digest carried by `NumiSealLaneProof` is now produced by a
public, transcript-bound linear residual object. `NumiSealScalarizationStatement`
is:

```text
domain ||
version ||
publicStatementDigest ||
laneKey ||
aggregateIndex ||
aggregateDigest ||
decompositionKeyDigest ||
decompositionCommitmentDigest ||
aggregateCommitmentDigest ||
aggregatePublicInputDigest ||
aggregateMatrixEvaluationDigest ||
statementDigest
```

`domain` is `SHA256("SuperNeo-NuMetal.numiseal.scalarization-statement.v1")`.
`version` is UInt16 little-endian value `10`. The statement validates that the
aggregate lane is covered by the public statement, that profile/shape/verifier
context agrees, and that the decomposition commitment belongs to the same lane
aggregate.

`NumiSealScalarizationWeights` are derived from
`"SuperNeo-NuMetal.numiseal.scalarization.v1"` by absorbing the scalarization
statement digest, public-statement digest, aggregate digest, decomposition
commitment digest, lane key, aggregate index, and the public vector lengths.
The deterministic weight digest binds the generated weights for:

```text
aggregate commitment coefficients ||
decomposition commitment coefficients ||
public input slots ||
aggregate matrix-evaluation coefficients
```

`NumiSealLinearResidual` is:

```text
domain ||
version ||
framed(NumiSealScalarizationStatement) ||
weightsDigest ||
residualValue ||
residualDigest
```

`domain` is `SHA256("SuperNeo-NuMetal.numiseal.linear-residual.v1")`.
`residualValue` is the extension-field linear combination of the aggregate
commitment, decomposition commitment, public input field elements, and aggregate
matrix evaluations under the derived weights. `residualDigest` is:

```text
H_numiseal("numiseal.linear-residual.v1",
  version || statementDigest || weightsDigest || residualValue)
```

This is the public scalarization oracle and proof-body binding point for the
sum-check and residual-opening handoffs. It does not yet prove the full residual
CE relation by itself.

`NumiSealAggregateEvaluationOracle` is the non-proof handoff checker for this
phase. Given witnessed claims in canonical aggregate order, it rebuilds the
lane-local RLC witness, checks that the public aggregate commitment/public
input/matrix-evaluation surface matches those claims, and recomputes sparse
transformed CCS evaluations from the existing `CCSShape` and Ajtai key. This
object is not serialized into the proof envelope.

### NumiSeal Sum-Check Handoff

`NumiSealSumcheckOracle` is the current bounded reference handoff for the
`framed(SumcheckProof)` component carried by `NumiSealLaneProof`. It binds the
sum-check transcript to:

```text
linearResidualDigest ||
scalarizationStatementDigest ||
digitTensorDigest ||
laneKey ||
aggregateIndex ||
paddedSlotCount ||
variableCount ||
sumcheckWeightDigest
```

The reference polynomial is degree-4-compatible and checks:

```text
residualValue * eq_0(X)
+ eta_lang * D(X)(D(X)-1)(D(X)+1)
+ eta_pad * P(X)D(X)
```

`D` is the multilinear extension of the digit tensor, padded to a power of two.
`P` is the padding selector. `eta_lang` and `eta_pad` are transcript-derived
weights. For a valid ternary, zero-padded tensor, the Boolean-hypercube sum is
the scalar residual value, so `proof.claimedSum == residualValue`.

This reference oracle caps the variable count for exhaustive interpolation and
exists to bind proof-body bytes to the digit language and residual. It is not
the final optimized NumiSeal prover/verifier.

### NumiSeal Residual Opening Handoff

`framed(residualOpening)` now contains a typed immediate residual-opening
object, not arbitrary bytes:

```text
domain ||
version ||
laneKey ||
aggregateIndex ||
linearResidualDigest ||
sumcheckProofDigest ||
terminalStatementDigest ||
ceOpeningProofDigest ||
framed(TerminalCEStatement) ||
framed(CEOpeningProof) ||
openingDigest
```

`domain` is `SHA256("SuperNeo-NuMetal.numiseal.residual-opening.v1")`.
`version` is UInt16 little-endian value `10`. `linearResidualDigest` must match
the lane proof's `scalarizationDigest`. `sumcheckProofDigest` is
`H_numiseal("numiseal.sumcheck.v1", SumcheckProof)`.
`terminalStatementDigest` is the canonical `TerminalCEStatement` digest.
`ceOpeningProofDigest` is
`H_numiseal("numiseal.residual-opening.ce-proof.v1", CEOpeningProof)`.
`openingDigest` is

```text
H_numiseal("numiseal.residual-opening.v1",
  version || laneKey || aggregateIndex || linearResidualDigest ||
  sumcheckProofDigest || terminalStatementDigest || ceOpeningProofDigest ||
  framed(TerminalCEStatement) || framed(CEOpeningProof))
```

The immediate residual preflight checks lane/aggregate scope, scalarization
digest binding, sum-check proof digest binding, terminal CE statement
profile/shape/verifier/evaluation-point scope, and per-round CE opening-count
agreement. This still does not run the full residual CE relation verifier; that
remains the Phase 6 algebraic verification boundary.

## Versioning Policy

Any incompatible change to field encodings, count encodings, proof body order,
header fields, transcript binding, profile semantics, or proof-kind semantics
requires a new `ProofEnvelopeHeader.version`.

Any parameter change that preserves the byte grammar but changes security
semantics requires a new `profileID`.
