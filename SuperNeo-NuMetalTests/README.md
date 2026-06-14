# Test Slices

The XCTest suite is split by debugging purpose so day-to-day work does not need
to pay for every protocol and Metal path.

Run `Scripts/test-slice.sh fast` for the normal inner loop. It covers the
deterministic field/ring/evaluation corpus and CCS/transcript/serialization
shape checks. The Ajtai commitment corpus is high-signal but slower, so it has
its own slice.

Run `Scripts/fuzz-malformed-artifacts.sh` when changing artifact parsing,
canonical serialization, transcript binding, or verifier acceptance. It attacks
the CLI verifier with mutated proof artifacts and fails if a mutant verifies.

Use the focused slices when changing a specific layer:

```sh
Scripts/test-slice.sh algebra
Scripts/test-slice.sh commitment
Scripts/test-slice.sh evaluation
Scripts/test-slice.sh shape
Scripts/test-slice.sh protocol
Scripts/test-slice.sh ce-opening
Scripts/test-slice.sh metal
Scripts/test-slice.sh all
```

The classes intentionally map to the filters:

| Slice | XCTest class | Use when touching |
| --- | --- | --- |
| `algebra` | `AlgebraCoreTests`, `EvaluationCoreTests` | fields, rings, embeddings, multilinear evaluation |
| `commitment` | `CommitmentCoreTests` | Ajtai commitment key generation and linearity |
| `evaluation` | `EvaluationCoreTests` | multilinear evaluation and hypercube oracle checks |
| `shape` | `ProtocolShapeTests` | sumcheck transcript binding, matrices, CCS shape encoding, public-instance digests |
| `protocol` | `ProtocolSmokeTests`, `ProtocolE2ETests` | fold proof construction, verification, envelopes, adversarial mutations |
| `ce-opening` | `CEOpeningProtocolTests` | CE opening local relation and heavyweight public proof verification |
| `metal` | `MetalDifferentialTests` | Metal kernels and GPU/CPU differential behavior |

## Running `swift test` directly

This package defines **XCTest** targets only. From the repository root you can run:

```sh
swift test --disable-swift-testing
```

`Scripts/test-slice.sh` passes `--disable-swift-testing` for you so SwiftPM does not also spin up the Swift Testing harness (which this repo does not use). Extra arguments are forwarded, for example:

```sh
Scripts/test-slice.sh protocol -v
```

To opt into Swift Testing later, append `--enable-swift-testing` after the slice name.

## If tests look hung or stuck

**SwiftPM lock.** Only one SwiftPM process can use the shared `.build` directory at a time. If another `swift test` or `swift build` is running in the same package, the next command waits with a message like `Another instance of SwiftPM … is already running`. Wait for the other process to finish, or stop it. Running two suites at once is not supported.

**Long CPU stretches with little output.** The full suite (`Scripts/test-slice.sh all` or `swift test` over all cases) spends a large fraction of wall time in fold and protocol checks. Expect on the order of a minute before completion on a typical laptop; that is normal, not a deadlock.

**Isolated build directory.** If you must run tests in parallel with another SwiftPM job against the same sources, use a separate scratch path so the builds do not contend (slower, cold build):

```sh
swift test --disable-swift-testing --scratch-path /tmp/superneo-spm-build
```

If a change crosses layers, run the smallest affected set first, then
`Scripts/test-slice.sh all` before handing off.

The default SwiftPM test target intentionally excludes long research suites for
proof compression, IVC/PCD, paper-track, or XMSS coverage. Run those classes
explicitly when changing their layer.
