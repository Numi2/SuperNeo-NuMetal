# CLI Demo And Golden Vector

The `superneo` executable is a narrow integration demo for the library. It is
not a product frontend. It exists to show the full path from a real CCS workload
to a versioned proof envelope and verifier result.

## Workloads

The CLI currently exposes two workloads.

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

Terminal mode is complete but intentionally not the default. In local Debug
runs, even a small terminal proof is much larger and slower because it includes
the public CE opening proof. Fold mode is the fast integration vector and reports
that terminal relation verification remains required.

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
- shape digest,
- statement digest, and
- verifier-key digest.

The verifier reconstructs the workload shape and public input, regenerates the
Ajtai verifier key from the seed, checks all three digests, and then verifies the
proof envelope. Without `--key-seed` and `--expected-*` arguments, the seed and
digests are read from the artifact, so verification is a self-consistency check
rather than a policy decision. Production callers should store the expected
seed, public inputs, proof kind, shape digest, statement digest, and verifier-key
digest outside the artifact.

## Checked-In Vectors

Current golden vectors:

- `TestVectors/one-hot-vector-fold-v1.json`
- `TestVectors/binary-addition-u8-fold-v1.json`

The `UsabilitySurfaceTests` load these files, reconstruct the public input and
verifier key, and verify the fold envelopes.

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
```

An unintentional digest change should be treated as a compatibility regression
until explained.
