# E2E Proof Metrics, 2026-04-16

This document records the checked proof-size and product-smoke budget surface.
It is deliberately separate from proof bytes: metrics and release evidence do
not change verifier semantics or proof size.
Whole-stack benchmark row coverage is tracked separately in
`TestVectors/benchmark-coverage-v1.json`.

## Machine-Checked Surface

`TestVectors/e2e-proof-metrics-v1.json` records:

- exact artifact byte counts for checked R1CS and NumiSeal vectors,
- exact decoded proof-envelope byte counts for those vectors,
- maximum artifact and proof-envelope byte budgets for checked vectors,
- generated NumiSeal product and NumiSealZK product smoke budgets,
- the benchmark command required before making hardware latency claims.

`Scripts/validate-e2e-proof-metrics.py` checks the manifest against the actual
JSON artifacts and decoded base64 proof envelopes. It also validates generated
product artifacts when passed `--generated-product-artifact budget-id:path`.

`Scripts/test-e2e-proof-metrics-validation.py` mutates schema version, tracked
vector coverage, recorded byte counts, budget ceilings, latency policy, and
generated product proof kind to keep the validator fail-closed.

## Gate Integration

`Scripts/production-gate.sh` now runs the E2E proof metrics validator and its
regression tests before release-readiness validation. The gate also validates
the generated product smoke artifacts:

- `numiseal-product-smoke` for `proofKind = "numiseal-terminal"` and
  `zkMode = "none"`,
- `numiseal-zk-product-smoke` for `proofKind = "numiseal-zk"` and
  `zkMode = "masked-digit-tensor-v1"`.

The generated budgets bind artifact size, source fold envelope size, NumiSeal
proof envelope size, seal mode, carry mode, ZK mode, Metal mode, execution
policy, and source output-claim count.

## Release Evidence

`Scripts/generate-release-candidate-evidence.py` pins the E2E proof metrics
version, digest, tracked artifact count, and generated budget count. The release
candidate evidence validator rejects packets that omit or downgrade this
surface.

## Boundaries

The metrics manifest is a deterministic serialization and budget gate. It does
not claim universal latency, because latency depends on toolchain, build mode,
hardware, thermal state, and Metal availability. Production performance claims
must attach a fresh report from `Scripts/run-benchmarks.sh quick` for the named
hardware class, with the required row families still covered by
`TestVectors/benchmark-coverage-v1.json`.
