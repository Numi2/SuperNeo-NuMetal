# Relation Evaluation Plan, 2026-04-14

This pass tightens prover and verifier evaluation of the public CCS relation
inside the sum-check Q path. It does not change the SuperNeo relation,
Fiat-Shamir transcript, challenge derivation, proof bytes, verifier acceptance
rules, Ajtai parameters, Metal kernels, or CPU/Metal equality policy.

## Finding

The prover-side Q oracle precomputed fresh matrix rows for every CCS matrix and
then evaluated every matrix at each sum-check suffix before calling the relation
polynomial. Some public relations do not read every matrix, and some referenced
variables are backed by equal public matrices. The current m256 benchmark shape
uses matrices `[identity, identity, sparse]` while its relation uses the first
two variables as `M0 - M1`, so matrix 2 fresh-row work was not needed and the
fresh relation term collapses to zero over the duplicate identity sources.

## Work

- Added a private relation evaluation plan built from the serialized
  `RelationPolynomial`.
- Compacted nonzero monomial exponents into factor slots so relation evaluation
  reads only public relation-referenced variables.
- Changed the prover Q-oracle to precompute fresh matrix rows only for
  relation-referenced matrix indices.
- Added a prover-side relation source plan that merges exact-equal public CSR
  matrices, combines exponents over the merged sources, and cancels terms whose
  coefficients sum to zero after source aliasing.
- Changed the public Q verifier final check to use the same relation plan when
  reading proof-claim constants. The verifier intentionally evaluates the
  original relation over proof-claim variables rather than source-aliasing them.

## Measurement

Targeted Apple M4 quick slice:

```sh
SUPERNEO_BENCHMARK_CASE_FILTER=m256 Scripts/run-benchmarks.sh quick
```

The final dirty-tree report generated on 2026-04-14T02:04:44Z recorded
`stage/sumcheck/m256-K2-k1-binary` at `16 ms` and
`stage/prepared/sumcheck/m256-K2-k1-binary` at `15 ms`. This compares with
`17 ms` before the initial relation-plan pass and `16 ms` before duplicate-source
cancellation in the immediately preceding targeted report. Treat this as exact
public-relation cleanup with a small prepared-path gain, not a large throughput
claim.

## Validation

Run after this pass:

```sh
swift test --disable-swift-testing --filter ProtocolShapeTests/testSumcheckProverProofIsTranscriptAndFinalCheckBound
swift test --disable-swift-testing --filter ProtocolE2ETests/testPaperLinePiCCSPiRLCAndPiDECReferenceVectors
SUPERNEO_BENCHMARK_CASE_FILTER=m256 Scripts/run-benchmarks.sh quick
Scripts/test-slice.sh fast
Scripts/production-gate.sh
```
