**Decision**

Metal acceleration should be treated as a measured GPU prover path, not a blanket replacement for CPU. The current quick baseline on Apple M4 shows Metal is slower today, so the first goal is not “more kernels”; it is removing the structural reasons the GPU loses.

Current local baseline from `benchmark-results/report.md`:

| Case | CPU | Metal | Result |
| --- | ---: | ---: | --- |
| `fold/m64-K1-k0-binary` | 29 ms | 145 ms | Metal 5.0x slower |
| `fold/m256-K2-k1-binary` | 268 ms | 441 ms | Metal 1.6x slower |
| `kernel/ajtaiCommit/m64` | 170 us | 2608 us | Metal 15.3x slower |
| `kernel/transformedEvaluation/m64` | n/a | 17 ms | obvious hotspot |

So the plan is: make Metal win at the hot kernels, then make it win end-to-end, and keep CPU as the automatic path for tiny instances where GPU launch and transfer overhead dominate.

**What SuperNeo Needs Accelerated**

The paper makes the target clear: SuperNeo wins by using a norm-preserving field-to-ring embedding, field-native sum-check, sparse transformed matrices, and Ajtai commitments over `Phi_54`. That means the GPU work should focus on:

1. Ajtai commitments: `A * z` over `R_F`, especially batched commitments for fresh witnesses and the 14 decomposition limbs.
2. Transformed matrix evaluation: `Mbar * z`, then multilinear evaluation over the 54 coefficient streams.
3. Decomposition: split folded witnesses into norm-bounded limbs, commit all limbs, evaluate all limbs.
4. Random linear combination: ring-scaled commitments, public input, evaluations, and witness rings.
5. Sum-check only after the above; it has transcript dependencies and is not the first GPU win.

The important repo surfaces are [SuperNeoProtocols.swift](/Users/home/SuperNeo-NuMetal/SuperNeo-NuMetal/SuperNeo-NuMetal/Protocols/SuperNeoProtocols.swift):1135, [SuperNeoMetalBackend.swift](/Users/home/SuperNeo-NuMetal/SuperNeo-NuMetal/SuperNeo-NuMetal/MetalBackend/SuperNeoMetalBackend.swift):80, [SuperNeoKernels.metal](/Users/home/SuperNeo-NuMetal/SuperNeo-NuMetal/SuperNeo-NuMetal/MetalBackend/SuperNeoKernels.metal):21, and [Benchmarks/SuperNeoBenchmarks.swift](/Users/home/SuperNeo-NuMetal/SuperNeo-NuMetal/Benchmarks/SuperNeoBenchmarks/SuperNeoBenchmarks.swift):40.

**Why Metal Loses Today**

The current Metal multiplication is bit-serial: [SuperNeoKernels.metal](/Users/home/SuperNeo-NuMetal/SuperNeo-NuMetal/SuperNeo-NuMetal/MetalBackend/SuperNeoKernels.metal):21. Ring multiplication then nests that inside 54x54 loops: [SuperNeoKernels.metal](/Users/home/SuperNeo-NuMetal/SuperNeo-NuMetal/SuperNeo-NuMetal/MetalBackend/SuperNeoKernels.metal):113. The backend also allocates and uploads buffers inside hot calls: [SuperNeoMetalBackend.swift](/Users/home/SuperNeo-NuMetal/SuperNeo-NuMetal/SuperNeo-NuMetal/MetalBackend/SuperNeoMetalBackend.swift):96 and [SuperNeoMetalBackend.swift](/Users/home/SuperNeo-NuMetal/SuperNeo-NuMetal/SuperNeo-NuMetal/MetalBackend/SuperNeoMetalBackend.swift):122.

Most importantly: the paper says the SuperNeo transform preserves sparsity, but the current code materializes `RingMatrix` densely and the Metal kernel loops every ring column per row: [SuperNeoKernels.metal](/Users/home/SuperNeo-NuMetal/SuperNeo-NuMetal/SuperNeo-NuMetal/MetalBackend/SuperNeoKernels.metal):231. That is the wrong shape for state-of-the-art performance.

Apple’s current Metal feature tables show M4 is Apple9, with 64-bit integer math, SIMD-scoped reductions, nonuniform threadgroups, binary archives, and 64-bit atomics available. Apple’s Metal guidance also points directly at our main fixes: persistent objects and buffers, few command buffers, pipeline prewarming, and storage-mode discipline. Sources: [Metal Feature Set Tables](https://developer.apple.com/metal/Metal-Feature-Set-Tables.pdf), [Persistent Objects](https://developer.apple.com/library/archive/documentation/3DDrawing/Conceptual/MTLBestPracticesGuide/PersistentObjects.html), [Command Buffers](https://developer.apple.com/library/archive/documentation/3DDrawing/Conceptual/MTLBestPracticesGuide/CommandBuffers.html), [Resource Options](https://developer.apple.com/library/archive/documentation/3DDrawing/Conceptual/MTLBestPracticesGuide/ResourceOptions.html), and Apple’s 2026 [Metal Performance Primitives guide](https://developer.apple.com/download/files/Metal-Performance-Primitives-Programming-Guide.pdf).

**Execution Plan**

Phase 0: lock the benchmark contract.

- Keep CPU as the control benchmark and correctness oracle.
- Add CPU and Metal timings for every hot kernel: field multiply, ring multiply, small-scalar ring multiply, Ajtai single, Ajtai batch, sparse transformed evaluation, PiDEC batch, PiRLC.
- Report both wall-clock and GPU command-buffer time.
- Gate every Metal result against exact CPU equality, as the benchmark already does for fold output.
- Add hardware-class baselines: `apple-m4-release`, `apple-m3-release`, later `apple-m5-release`.

Phase 1: replace Goldilocks arithmetic.

- Replace `goldilocks_mul_fallback` with a 32-bit limb wide multiply and Goldilocks reduction for `p = 2^64 - 2^32 + 1`.
- Keep specialized paths for `0, ±1, ±2`, because SuperNeo witnesses, decomposition limbs, and challenge coefficients are small by design.
- Add differential tests for boundary values, random corpus, ring products, Ajtai commitments, and transformed evaluations.
- Do not proceed to kernel tuning until Metal field multiplication is within striking distance of CPU arithmetic.

Phase 2: fix the data model.

- Add a sparse transformed-ring matrix type instead of dense `RingMatrix` for `Mbar`.
- Store transformed matrices in CSR/ELL-style buffers: row offsets, ring-column indices, ring coefficients.
- Stop writing full `rows: [CyclotomicRing54]` unless a caller truly needs it.
- Fuse transformed matvec plus multilinear evaluation so the GPU computes the final `CyclotomicExt2Ring54` directly.

Phase 3: build a real Metal workspace.

- Add a `SuperNeoMetalWorkspace` that owns persistent `MTLBuffer`s for the key matrix, transformed matrices, witnesses, limbs, `rHat`, partials, and outputs.
- Upload static data once per fixture/prover, not once per kernel call.
- Use shared/staging buffers for CPU-fed inputs and private buffers for large GPU-only static data where appropriate.
- Encode a whole fold stage into one command buffer where dependencies allow it. Current `waitUntilCompleted` per primitive is acceptable for correctness, not performance.

Phase 4: rewrite Ajtai as the primary GPU kernel.

- Target batched Ajtai first: fresh claims plus 14 decomposition limbs.
- Use one kernel family specialized by function constants for `degree = 54`, `kappa = 18`, tile size, batch size, and witness kind.
- Use simdgroup reductions for coefficient accumulation.
- Exploit small witness coefficients so ring products become rotations, additions, and negations instead of full modular multiplication.
- Keep a full-scalar fallback for folded/RLC data, but ensure the common limb path is the fast path.

Phase 5: fuse PiDEC.

- Move `splitSignedBase` for the folded witness/public input onto GPU.
- Commit all 14 limbs in one batched Ajtai pass.
- Evaluate all limb claims in one sparse fused transformed-evaluation pass.
- Copy back only commitments and final evaluation rings needed for proof assembly.

Phase 6: integrate adaptively.

- Add a backend policy: CPU for small `m`, Metal for large `m` or large batch/decomposition work.
- Initial cutoff should be empirical, not guessed. Based on current numbers, Metal should be disabled for `m64` and probably `m256` until the arithmetic/data fixes land.
- Production gate: Metal must be exact, deterministic, and faster on the full profile before becoming default.

**Benchmark Gates**

I would use these merge gates:

- Correctness: CPU and Metal proof output must match byte-for-byte for benchmark fixtures.
- Kernel gate: Ajtai batch and sparse transformed evaluation must beat CPU at `m >= 4096`.
- Protocol gate: `fold/metal` must be at least `2x` faster than `fold/cpu` at `m >= 4096`.
- Small-case gate: adaptive backend must avoid regressions over `10%` at `m <= 256`.
- Regression gate: stable kernel regressions over `5%`, full protocol regressions over `10%`, matching the existing benchmark doc policy in [Docs/Benchmarking.md](/Users/home/SuperNeo-NuMetal/SuperNeo-NuMetal/Docs/Benchmarking.md):45.

**Bottom Line**

The decisive path is: sparse transformed matrices, fast Goldilocks multiply, persistent buffers, fused transformed evaluation, batched Ajtai, then fused PiDEC. MPS/MPP-style generic matrix multiplication is not the core solution because SuperNeo needs exact modular finite-field/ring arithmetic, but Apple’s current tiling and simdgroup guidance absolutely applies to how we design the kernels.

