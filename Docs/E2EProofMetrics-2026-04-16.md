# E2E Proof Metrics

This note records the release-packet policy for end-to-end proof-size metrics.
It is an evidence index for deterministic vectors and local product smokes, not
a production latency or capacity claim.

## Checked Inputs

- `TestVectors/e2e-proof-metrics-v1.json` pins deterministic proof-size rows
  for the currently tracked release vectors and the generated NumiSeal product
  smoke budgets under `sourceDecompositionProfile = pay-per-bit-v1`.
- `Scripts/validate-e2e-proof-metrics.py` checks the metric schema, expected
  row identities, and fail-closed status.
- `Scripts/test-e2e-proof-metrics-validation.py` mutates the metric contract so
  missing rows, stale limits, and premature production claims are rejected.

## Current Boundary

The metric contract covers byte-size accounting for checked vectors and local
product smoke rows. It does not claim production latency, hosted throughput,
hardware-specific performance, or capacity planning. Those claims require fresh
benchmark evidence and remain separate from the selected-depth cryptographic
loss budget.

The local non-ZK diagnostic NumiSeal row and the NumiSealZK product smoke row are
expected to be close in size: NumiSealZK embeds the same accepted terminal base
proof and adds compact mask statements, masked residual statements,
leakage/session digests, and a ZK component root. The base terminal proof remains
the dominant byte contributor; the product verifier recomputes the ZK metadata
from the parsed ZK proof and rejects proof-kind, leakage, session, and
simulator-coupling drift.
