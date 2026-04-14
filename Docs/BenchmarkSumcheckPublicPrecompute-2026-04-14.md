# Sum-Check Public Precompute Cleanup, 2026-04-14

This pass tightens public and shape-derived work in the CPU sum-check prover
path. It does not change the SuperNeo relation, Fiat-Shamir transcript,
challenge derivation, proof bytes, verifier acceptance rules, Ajtai parameters,
or CPU/Metal equality policy.

## Finding

The prover-side Q oracle rebuilt Boolean-suffix equality products while
evaluating each partial hypercube sum, and the fixed sample grid interpolation
rebuilt the same Lagrange basis every sum-check round. Relation polynomial
evaluation also routed public exponent `0` and `1` cases through the generic
power helper.

These are not cryptographic randomness or witness-dependent policy decisions;
they are public shape, round, and relation computations.

## Work

- Precomputed suffix equality weights once per fixed prefix for the alpha point
  and optional prior-claim point, then indexed the table for each suffix.
- Precomputed the Lagrange interpolation basis for the fixed Q-polynomial
  sample grid during `CCSQOracle` construction.
- Specialized relation polynomial evaluation for public exponents `0` and `1`
  while leaving higher exponents on the existing power path.

## Measurement

Targeted Apple M4 quick slice:

```sh
SUPERNEO_BENCHMARK_CASE_FILTER=m256 Scripts/run-benchmarks.sh quick
```

The final dirty-tree report generated on 2026-04-14 recorded
`stage/sumcheck/m256-K2-k1-binary` at `17 ms` and
`stage/prepared/sumcheck/m256-K2-k1-binary` at `17 ms`. Earlier dirty runs in
the same session were also around `16-17 ms`, so this pass is retained as a
shape/public-work cleanup rather than a benchmark improvement claim.

## Validation

Run after this pass:

```sh
swift test --disable-swift-testing --filter ProtocolShapeTests/testSumcheckProverProofIsTranscriptAndFinalCheckBound
swift test --disable-swift-testing --filter ProtocolE2ETests/testPaperLinePiCCSPiRLCAndPiDECReferenceVectors
SUPERNEO_BENCHMARK_CASE_FILTER=m256 Scripts/run-benchmarks.sh quick
Scripts/test-slice.sh fast
Scripts/production-gate.sh
```
