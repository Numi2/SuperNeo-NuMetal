# Competitive Performance, 2026-04-21

This note pins a fresh same-hardware comparison table on the Apple M4 MacBook
Air described in `Docs/BenchmarkReports/competitive-performance-2026-04-21-metadata.json`.
It is separate from the repository-local promotion gate: local proof-size
budgets and benchmark-surface coverage remain the production-gated evidence, and
this document exists for external comparison claims.

## Boundaries

- Same hardware does not mean the same arithmetic relation, statement size, or
  security target.
- The SuperNeo row uses the checked end-to-end NumiSeal product-smoke surface
  (`one-hot-u2`) because that is the pinned public artifact path in this repo.
- The LatticeFold and Winterfell rows use each upstream project's published
  example harness on the same machine; they are nearby comparators, not
  normalized statement-equivalence claims.

## Same-Hardware Table

| System | Workload | Proof bytes | Prover time | Verifier time | Peak memory | Recursion overhead | Metal vs CPU cost | ZK overhead | Parameter-security level |
| --- | --- | ---: | ---: | ---: | ---: | --- | --- | --- | --- |
| SuperNeo NumiSeal product | one-hot-u2 terminal product smoke | 244225 B proof envelope; 1726630 B artifact | 420 ms | 165 ms | 23724032 B prove RSS; 26001408 B verify RSS | child +65 ms prove (+15.4762%), -9 ms verify (-5.4545%) | fold m256 proxy: Metal 88 ms vs CPU 56 ms (1.5714x slower) | -1 ms prove (-0.2381%), -9 ms verify (-5.4545%), +1210 B proof envelope (+0.4954%), +2072 B artifact (+0.12%) | Module-SIS Goldilocks/Phi81, kappa=18, default estimator lane 129.1 rop bits; broad 128-bit PQ claim still assumption-scoped |
| LatticeFold e2e example | upstream e2e NIFS example | 124.78 KiB compressed; 249.56 KiB uncompressed | 38.7335 ms | 36.122791 ms | 4472832 B max RSS | n/a in selected example | n/a (CPU-only example) | n/a (no toggled ZK/non-ZK pair) | example constants pin KAPPA=4; upstream example does not emit a bit-level estimate |
| Winterfell Lamport aggregate | 64 Lamport+ signatures | 72.7 KB | 831 ms | 0.8 ms | 607846400 B max RSS | n/a in selected example | n/a (CPU-only example) | n/a (no toggled ZK/non-ZK pair) | conjectured 99 bits; proven 56/39 bits |

## Sources

- Machine-readable comparison table: `TestVectors/competitive-performance-comparison-v1.json`
- Fresh local benchmark rows: `Docs/BenchmarkReports/competitive-performance-2026-04-21-report.md`
- Fresh local benchmark metadata: `Docs/BenchmarkReports/competitive-performance-2026-04-21-metadata.json`
- SuperNeo proof-byte and RSS measurements:

```sh
/usr/bin/time -l .build/release/superneo prove \
  --seal numiseal \
  --numiseal-zk-mode masked-digit-tensor-v1 \
  --numiseal-execution-policy zk-high-assurance-cpu \
  --bits 0,1 \
  --max-obligations-per-aggregate 32 \
  --output /tmp/numiseal-zk-terminal.json

/usr/bin/time -l .build/release/superneo verify /tmp/numiseal-zk-terminal.json

/usr/bin/time -l .build/release/superneo prove \
  --seal numiseal \
  --numiseal-zk-mode masked-digit-tensor-v1 \
  --numiseal-execution-policy zk-high-assurance-cpu \
  --bits 0,1 \
  --max-obligations-per-aggregate 32 \
  --output /tmp/numiseal-zk.json

/usr/bin/time -l .build/release/superneo verify /tmp/numiseal-zk.json
```

- Comparator commands:

```sh
/usr/bin/time -l /tmp/superneo-competitors/latticefold/target/release/examples/e2e
/usr/bin/time -l /tmp/superneo-competitors/winterfell/target/release/winterfell lamport-a -n 64
```

## Usage

Quote competitor-comparison numbers only from this note and
`TestVectors/competitive-performance-comparison-v1.json`, and refresh both when
the local benchmark report, proof bytes, or comparator revisions change.
