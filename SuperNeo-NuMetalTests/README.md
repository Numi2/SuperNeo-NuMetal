# Test Slices

The XCTest suite is split by debugging purpose so day-to-day work does not need
to pay for every protocol and Metal path.

Run `Scripts/test-slice.sh fast` for the normal inner loop. It covers the
deterministic field/ring/evaluation corpus and CCS/transcript/serialization
shape checks. The Ajtai commitment corpus is high-signal but slower, so it has
its own slice.

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

If a change crosses layers, run the smallest affected set first, then
`Scripts/test-slice.sh all` before handing off.
