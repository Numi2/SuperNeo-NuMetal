# E2E Proof Metrics

This note records the release-packet policy for end-to-end proof-size metrics.
It is an evidence index for deterministic vectors and local product smokes, not
a production latency or capacity claim.

## Checked Inputs

- `TestVectors/e2e-proof-metrics-v1.json` pins deterministic proof-size rows
  for the currently tracked release vectors.
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
