# PiRLC Benchmark Isolation, 2026-04-14

This pass tightened the stage benchmark boundary for PiRLC without changing
protocol bytes, verifier acceptance, transcript domains, cryptographic
parameters, Ajtai commitments, or CPU/Metal trust policy.

## Finding

The `stage/piRLC/*` benchmark rows were using `benchmarkPiRLC(input:claims:)`,
which rebuilt the sum-check proof inside every PiRLC benchmark iteration only
to recover the transcript state immediately before PiCCS claim absorption. That
made the row useful as an integration check, but it over-counted the PiRLC stage
by charging sum-check proving work to PiRLC.

## Work

- Added `SuperNeoPreparedPiRLCTranscript` as benchmark SPI for the transcript
  state after a validated sum-check proof.
- Added `preparePiRLCTranscript(input:sumCheck:claims:transcriptSeed:)`, which
  replays the sum-check transcript from an existing proof, checks the claimed
  sum, round transcript consistency, final point, final value, claim count, and
  PiCCS final-point binding once during benchmark setup.
- Routed benchmark `stage/piRLC/*` and `stage/prepared/piRLC/*` rows through the
  prepared transcript so iterations measure PiCCS claim absorption, Fiat-Shamir
  challenge-ring derivation, and random-linear-combination arithmetic.
- Kept the older benchmark helpers available for integration-style callers; they
  now delegate through the same prepared transcript path after constructing a
  fresh sum-check proof.
- Added regression coverage that the prepared transcript reproduces fold
  challenges and folded claims, and rejects PiCCS claims at the wrong
  sum-check final point.

## Trust Boundary

This is a benchmark accounting change. It does not relax production verification
or make benchmark setup trusted input for protocol acceptance. The prepared
transcript is exposed only through `@_spi(Benchmarking)`, and the production
fold path continues to build the transcript linearly inside `foldWithOutput`.

## Validation

Run after this pass:

```sh
Scripts/test-slice.sh fast
swift test --disable-swift-testing --filter ProtocolE2ETests/testPreparedPiRLCTranscriptMatchesFoldAndRejectsWrongPoint
SUPERNEO_BENCHMARK_CASE_FILTER=m64 Scripts/run-benchmarks.sh quick
```

