# SuperNeo Paper Implementation Tracks, 2026-04-25

This is the implementation tracker for the paper gaps identified in
[SuperNeoPaperDevelopmentNotes-2026-04-25.md](SuperNeoPaperDevelopmentNotes-2026-04-25.md).
It records the repo-facing development slices and their acceptance criteria.

## Tracks

| Track | Current state | Next acceptance check |
| --- | --- | --- |
| Paper reproduction docs | Missing DocC/script docs have replacement entry points. | `python3 Scripts/legacy-gates/validate-doc-links.py` and `Scripts/reproduce-superneo-paper.sh plan` |
| Pay-per-bit wins | Optimized base-2 decomposition commitment lane now emits only active limbs, benchmark rows exercise recomposition, and product proving output carries `SuperNeoPayPerBitWitnessEvidence` for prepared witnesses. | Extend the optimized lane into every product benchmark profile and Metal workspace path. |
| Recursive IVC/PCD | `NumiSealBoundedRecursiveDriver` builds selected-depth typed-carry chains and now has a bounded PCD DAG driver that binds fan-in parent sets into trusted frontend context and accounting. | Add CLI exposure and persisted run artifacts for depth-3 release evidence. |
| PQ signature demo | `SuperNeoXMSSWOTSPlusAggregationWorkload` adds XMSS/WOTS+ shaped verification as constraints: WOTS+ checksum digits, conditional chain completion, L-tree public-key compression, XMSS authentication path recomposition, and a `prepareManyForFolding` path that folds multiple signatures as separate CCS instances under the small-norm profile. | Extend the bit-sliced hash gadget toward an audited XMSS/SLH-DSA hash adapter and add larger parameter/performance runs. |
| General CCS import | R1CS builder and demo workloads exist. | Add stable CCS import diagnostics, padding reports, and non-SIMD negative tests. |
| Swift-to-Lean embedding vectors | Ext2 and CE bridges exist; embedding vector emission is being added. | Add Lean comparison for packing, transform constants, and evaluation homomorphism. |
| Parameter/security dossier | Dossiers and estimator scripts exist; paper entry docs now point to them. | Add sensitivity matrix rows for each selected profile parameter. |
| Proof compression | `SuperNeoSNARKStyleCompressionProof` now has a source-bound verifier path that re-verifies the accepted terminal or compressed-terminal source proof and checks the source digest before accepting the compression object. | Replace the local transcript proof digest with an independently checkable Spartan/FRI proof. |
| Ideal QRO vs concrete hash | QRO product architecture is explicit; concrete deployment remains unpromoted. | Add deployment-domain inventory and concrete-hash evidence gate. |
| Metal/side-channel modes | CPU default, optional Metal, and certificate evidence exist. | Add opt-in mode docs/tests that bind performance/security choices at API boundaries. |

## Non-Negotiable Split

Keep the high-assurance product path conservative while optimized lanes are
developed. Optimized pay-per-bit skipping, Metal acceleration, proof
compression, and concrete hash deployments must be explicit modes with their own
evidence, not silent changes to default product acceptance.
