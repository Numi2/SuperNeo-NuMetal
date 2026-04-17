# CLI Demo And Golden Vector

The `superneo` executable is a narrow integration and product-smoke frontend for
the library. It exists to show the full path from a real CCS workload to
versioned proof artifacts and verifier results.

Legacy fold, terminal, and compressed-terminal proof generation uses the
repository's `.highAssurance` execution policy. NumiSeal product proving is
exposed separately through `--seal numiseal` and accepts explicit NumiSeal
execution policies, including CPU-redundant Metal.

## Workloads

The `prove` command currently exposes two workloads. The `verify` and `inspect`
commands also understand checked NumiSeal terminal vector artifacts.

### `one-hot-vector-v1`

It proves knowledge of a committed private bit vector `b` such that:

- every private entry is binary: `b_i * (b_i - 1) = 0`, and
- exactly one entry is selected: `sum(b_i) = 1`.

This is encoded through `SuperNeoR1CSBuilder` as an R1CS relation
`A(z) * B(z) - C(z) = 0`, then normalized through
`SuperNeoCCSNormalizer` into the paper-normalized SuperNeo CCS shape:

- positive power-of-two rows,
- square field shape,
- identity first matrix, and
- whole-ring public input count.

The verifier learns the vector length and the public statement that the committed
vector is one-hot. It does not learn which private index is selected from the
fold-reduction artifact.

### `binary-addition-v1`

It proves knowledge of two committed private `n`-bit integers `x` and `y` such
that their bitwise sum equals public output bits.

For each bit position `i`, the R1CS constraints enforce:

```text
x_i + y_i + carry_i - sum_i - 2 * carry_{i+1} = 0
```

with `carry_0 = 0`, a final constraint `carry_n = sum_n`, and booleanity
constraints for every operand bit, output bit, and carry bit. The public input is
the constant one followed by `n + 1` little-endian public sum bits.

## Commands

Generate the default fold-reduction artifact:

```sh
swift run superneo prove \
  --workload one-hot \
  --bits 0,0,1,0,0,0,0,0 \
  --output /tmp/one-hot-proof.json
```

Generate an 8-bit binary-addition artifact proving `13 + 29 = 42`:

```sh
swift run superneo prove \
  --workload binary-add \
  --operand-bits 8 \
  --lhs 13 \
  --rhs 29 \
  --output /tmp/binary-add-proof.json
```

Default key seeds are deterministic and workload-scoped. The checked-in 8-bit
vectors keep their original compatibility seeds:
`SuperNeoCLI.one-hot-vector.v1` and `SuperNeoCLI.binary-addition.u8.v1`.
Generated non-8-bit workloads use parameter-separated seeds such as
`SuperNeoCLI.one-hot-vector.u4.v1` or
`SuperNeoCLI.binary-addition.u16.v1` unless `--key-seed` is provided.

Verify it:

```sh
swift run superneo verify /tmp/one-hot-proof.json
```

The short form is a local smoke check: it proves the artifact is internally
consistent. For any artifact supplied by another process or party, pin the
expected verifier context at the call site:

```sh
swift run superneo verify \
  --key-seed SuperNeoCLI.one-hot-vector.v1 \
  --expected-verifier-key-digest 7e6c4fc3ec5bee0e1872cde17322830a37fc0a2d17ed79a208f6113fd0186a86 \
  --expected-shape-digest 84d903373ff54785a9b7d99bd048e1527deedd1173309c272992a8a87b61a765 \
  --expected-statement-digest 786532c3daee5d41f54b619bde8b6bcc432f7ae1f40017e14953cc8ce38992e0 \
  --expected-public-inputs 1 \
  /tmp/one-hot-proof.json
```

Inspect the artifact metadata and envelope header:

```sh
swift run superneo inspect /tmp/one-hot-proof.json
```

Generate a terminal proof:

```sh
swift run superneo prove \
  --kind terminal \
  --bits 0,0,1,0 \
  --output /tmp/one-hot-terminal-proof.json
```

Generate a compressed terminal proof:

```sh
swift run superneo prove \
  --kind compressed-terminal \
  --bits 0,0,1,0 \
  --output /tmp/one-hot-compressed-terminal-proof.json

swift run superneo verify \
  --require-terminal \
  /tmp/one-hot-compressed-terminal-proof.json
```

Generate a public NumiSeal product artifact:

```sh
swift run superneo prove \
  --seal numiseal \
  --bits 0,0,1,0 \
  --numiseal-zk-mode none \
  --numiseal-execution-policy default-product \
  --max-obligations-per-aggregate 32 \
  --output /tmp/one-hot-numiseal.json

swift run superneo inspect /tmp/one-hot-numiseal.json

swift run superneo verify \
  --require-numiseal \
  /tmp/one-hot-numiseal.json
```

`--seal numiseal` emits `artifactVersion = 2`. The artifact contains both the
source fold envelope and the NumiSeal kind `4` terminal seal. Verification first
reduces the source fold envelope, reconstructs source output-claim digests, then
reconstructs NumiSeal obligations and verifies the terminal seal. The supported
public proving API is `NumiSealProductAPI`,
`NumiSealProductTrustedContext`, `NumiSealProductProvingOutput`,
`NumiSealProductArtifact`, `NumiSealProductVerifier`, and
`SuperNeoR1CSProgram.proveNumiSealProduct(...)`. Product artifacts also carry
frontend-context, Swift trace/extractor, CTCO, and QROM evidence metadata.

To emit a masked NumiSealZK product artifact, request the ZK mode explicitly:

```sh
swift run superneo prove \
  --seal numiseal \
  --bits 0,0,1,0 \
  --numiseal-zk-mode masked-digit-tensor-v1 \
  --numiseal-execution-policy zk-high-assurance-cpu \
  --output /tmp/one-hot-numiseal-zk.json

swift run superneo verify \
  --require-numiseal \
  /tmp/one-hot-numiseal-zk.json
```

The ZK product artifact uses `proofKind = "numiseal-zk"`,
`sealMode = "numiseal-zk-v1"`, and proof-envelope kind `5`. Its embedded base
NumiSeal terminal proof is still verified under the same public-statement and
obligation checks; the outer ZK body binds mask statements and masked residual
statements into the component root and proof transcript.

For product-controlled NumiSealZK acceptance, use signed context/provenance
material. A side-channel certificate may be supplied as optional release
metadata, but it is not part of the proof and is not required for private
development:

```sh
swift run superneo verify \
  --product \
  --operator-profile profile.json \
  --context-pack context.json \
  --artifact-provenance provenance.json \
  --revocation-feed revocations.json \
  /tmp/one-hot-numiseal-zk.json

swift run superneo verify \
  --product \
  --operator-profile profile.json \
  --context-pack context.json \
  --artifact-provenance child-provenance.json \
  --revocation-feed revocations.json \
  --recursive-carry-parent parent-numiseal-product.json \
  --recursive-carry-parent-provenance parent-provenance.json \
  /tmp/child-numiseal-product.json

swift run superneo product-export-audit \
  --operator-profile profile.json \
  --context-pack context.json \
  --revocation-feed revocations.json \
  --output audit-export.json

swift run superneo product-status \
  --operator-profile profile.json \
  --context-pack context.json \
  --revocation-feed revocations.json \
  --format json
```

When supplied, a side-channel certificate binds the release build, context ID, ZK mode,
Metal mode, execution policy, leakage digest, proof body versions, reviewed
kernels/stages, and evidence digests. Product verification rejects
`numiseal-zk` trusted contexts that omit ZK policy, and rejects supplied
certificates whose digest or bindings differ from the artifact.
For `carryMode = "typed-required"`, product verification requires
`--recursive-carry-parent` and `--recursive-carry-parent-provenance`, verifies
that parent artifact under the same signed context, requires the parent proof
identity to already be accepted in the local replay ledger, and binds the child
recursive carry replay roots into the durable replay identity and audit record.
`product-export-audit` validates the local hash-chained JSONL audit log before
writing a sorted-key JSON export that includes the active context digest,
issuer-key digest, signed revocation feed digest, replay count, audit-log
digest, chain status, records, and `operationsStatus`. `product-status --format
json` emits that same canonical operations-readiness object directly, including
revocation feed, audit-retention, and retry policy fields.

Available NumiSeal execution policies are:

- `default-product`: uses CPU-redundant Metal when a Metal context is available,
  otherwise CPU reference. The CLI keeps this policy on CPU reference by
  default; callers that want Metal coverage should request an explicit Metal
  policy.
- `zk-redundant-metal`: requires Metal and cross-checks covered Metal outputs
  against CPU.
- `zk-metal-accelerated`: requires Metal and treats it as the primary prover
  accelerator.
- `zk-high-assurance-cpu`: CPU-only reference/certification mode.

Inspect and verify a checked NumiSeal terminal vector:

```sh
swift run superneo inspect TestVectors/numiseal-terminal-single-aggregate-v1.json

swift run superneo verify \
  --require-numiseal \
  --key-seed SuperNeoNumiSeal.vector.single-aggregate.key.v1 \
  --expected-verifier-key-digest fd2605390a4f450fdfdcde6259aa8bb06c51bf66d1def285fbe9cabc5eb09a73 \
  --expected-shape-digest 31c29845341f90a02918b6693f671751b0d5416e05412d4d7b6ff1eab687fb9e \
  --expected-statement-digest 9a8a92e65a81372c4be1b6a853c4fb6417011de99fa1167fae0948e0d20e451e \
  --expected-transcript-domain-digest 018865fb07dbefdbbf9764906781d45b20b36d72ed36c2a13c827e585c7be9de \
  --expected-public-statement-digest b38d814282d7273508a1ce56ac98bfca87018250080c26b7ad98b9fa6b8b9070 \
  --expected-obligation-root f2885132eb7e2354904f2171e7fb1a7f8764a8a96a1dab2fa059c8923bce6f13 \
  --expected-lane-summary-root 53141d23dc57cbf7bba102aa3c92de94997139d416f007b69cf50e3b57953147 \
  --expected-aggregate-digests 6bd43ca109ddc7578de000d6a0983a878e3a7d76df4ccb60d74b08f9fbfd25ae \
  --expected-component-digest-root 5320b1bf387199838f8f1ebd9fbfa2efec054555af3a4d07cea001e17ec510ad \
  --expected-proof-transcript-digest f4315994c550045181389647af20533bfee3a2383b6a23072d1715f854c8c7b4 \
  --expected-public-inputs 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 \
  TestVectors/numiseal-terminal-single-aggregate-v1.json
```

NumiSeal kind `4` artifacts and NumiSeal product artifacts fail closed unless
`--require-numiseal` is present. They are not accepted by `--require-terminal`,
which remains the policy gate for legacy terminal-local and compressed-public
envelopes.

Terminal mode is complete but intentionally not the default. In local Debug
runs, even a small terminal proof is much larger and slower because it includes
the public CE opening proof. `compressed-terminal` keeps terminal acceptance and
compresses public terminal statement material behind digest bindings. Fold mode
is the fast integration vector and reports that terminal relation verification
remains required.

## Artifact Fields

The JSON artifact stores:

- artifact version,
- workload name,
- profile name,
- proof kind,
- bit count,
- expected selected count,
- verifier-key seed used to deterministically regenerate the public Ajtai key,
- public inputs,
- public commitment bytes,
- proof envelope bytes,
- artifact byte count in CLI output,
- shape digest,
- statement digest, and
- verifier-key digest.

NumiSeal product artifacts additionally store `sealMode`, `carryMode`, `zkMode`,
`metalMode`, source fold envelope bytes, source fold output-claim digests,
NumiSeal proof envelope bytes, public statement roots, aggregate digests,
component root, proof transcript digest, aggregate limits, and execution-policy
metadata. Public product proving derives its NumiSeal digit tensor internally
from aggregate witness material; caller-supplied digit tensors remain SPI and
test-vector-only.
Product proving and verification print source fold envelope bytes, NumiSeal
proof envelope bytes, and product artifact bytes so release budget regressions
are visible during CLI development as well as in the production gate.

The initial `NumiSealZK` proof body is envelope kind `5`, body version `13`,
and `zkMode = "masked-digit-tensor-v1"`. It is available through the library
surface (`NumiSealZKProver`, `NumiSealZKProofEnvelope`, and
`NumiSealZKVerifier`) and through explicit CLI product proving via
`--numiseal-zk-mode masked-digit-tensor-v1`. The CLI default remains
`zkMode = "none"` while accelerated side-channel evidence remains out-of-band
release metadata rather than proof bytes.

NumiSeal vector artifacts additionally store residual mode, lane IDs,
fold/source/CE deterministic vector seeds, aggregate limits, transcript-domain
digest, public-statement digest, obligation root, lane-summary root, aggregate
digests, component digest root, and proof-transcript digest. `superneo verify
--require-numiseal` delegates artifact metadata validation, public-obligation
reconstruction, NumiSeal policy construction, envelope digest checks, expected
trust-pin checks, and final `NumiSealVerifier` dispatch to the shared
`NumiSealArtifactVerifier` library boundary.

The verifier reconstructs the workload shape and public input, regenerates the
Ajtai verifier key from the seed, checks all three digests, and then verifies the
proof envelope. Without `--key-seed` and `--expected-*` arguments, the seed and
digests are read from the artifact, so verification is a self-consistency check
rather than a policy decision. Production callers should store the expected
seed, public inputs, proof kind, shape digest, statement digest, and verifier-key
digest outside the artifact. For NumiSeal, callers should also pin the
transcript domain, public-statement digest, obligation root, lane-summary root,
aggregate digests, component digest root, and proof-transcript digest.

The CLI rejects artifacts with unknown top-level JSON fields before decoding.
This keeps the verifier aligned with the published artifact schema and prevents
unsupported wrapper metadata from being silently ignored.

## Checked-In Vectors

Current golden vectors:

- `TestVectors/one-hot-vector-fold-v1.json`
- `TestVectors/one-hot-vector-terminal-v1.json`
- `TestVectors/one-hot-vector-compressed-terminal-v1.json`
- `TestVectors/binary-addition-u8-fold-v1.json`
- `TestVectors/binary-addition-u8-terminal-v1.json`
- `TestVectors/numiseal-terminal-single-aggregate-v1.json`
- `TestVectors/numiseal-terminal-two-aggregate-v1.json`
- `TestVectors/numiseal-terminal-two-lane-v1.json`

The `UsabilitySurfaceTests` cover the checked-in fold, terminal, and
compressed-terminal vectors. The manifest validator reconstructs trusted context
for every checked-in vector and verifies terminal and compressed-terminal
vectors with `--require-terminal`. `superneo-numiseal-vectors` remains the
deterministic NumiSeal generator/manifest validator, while the manifest strict
commands now target `superneo verify --require-numiseal` with caller-owned trust
pins. `superneo inspect` and `superneo verify --require-numiseal` are the
production-facing reader and verifier surfaces for checked NumiSeal terminal
artifacts.

For external implementations, `TestVectors/manifest.json` records each vector's
SHA-256 hash, byte count, workload, proof kind, trusted expected verifier
context, and strict verification command. `TestVectors/artifact.schema.json` is
the machine-readable artifact schema.
Validate the checked-in vectors with:

```sh
swift Scripts/validate-test-vectors.swift
```

If proof serialization, transcript binding, profile parameters, or the workload
encoding changes intentionally, regenerate the vector with:

```sh
swift run superneo prove \
  --workload one-hot \
  --kind fold \
  --bits 0,0,1,0,0,0,0,0 \
  --output TestVectors/one-hot-vector-fold-v1.json

swift run superneo prove \
  --workload binary-add \
  --kind fold \
  --operand-bits 8 \
  --lhs 13 \
  --rhs 29 \
  --key-seed SuperNeoCLI.binary-addition.u8.v1 \
  --output TestVectors/binary-addition-u8-fold-v1.json

swift run superneo prove \
  --workload binary-add \
  --kind terminal \
  --operand-bits 8 \
  --lhs 13 \
  --rhs 29 \
  --key-seed SuperNeoCLI.binary-addition.u8.v1 \
  --output TestVectors/binary-addition-u8-terminal-v1.json
```

An unintentional digest change should be treated as a compatibility regression
until explained.
