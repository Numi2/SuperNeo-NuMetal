# SuperNeo Paper Development Notes, 2026-04-25

Source reviewed: `SuperNeo-NuMetal/SuperNeo_NuMetal.docc/superneopaper.md`.

This note maps the paper's main construction claims to the current repository
surface and records development work that would make the implementation track
the paper more tightly. It is a roadmap note, not a security claim.

## Paper Claims Already Represented

- The six-desiderata framing is reflected in the repository shape: Goldilocks
  arithmetic, Phi81 ring arithmetic, Ajtai commitments, field-native sum-check,
  general CCS/R1CS frontends, terminal CE verification, NumiSeal product
  wrappers, and checked evidence manifests.
- The main folding path is implemented as the paper's PiCCS/PiRLC/PiDEC split:
  `SuperNeoProver.foldWithOutput` builds repeated PiCCS tapes, PiRLC branches,
  and PiDEC decomposition output claims, while `SuperNeoVerifier.reduceFold`
  verifies the public reduction before terminal acceptance.
- The SuperNeo coefficient embedding is represented by `SuperNeoEmbedding`,
  `CCSShape.compiledSparseForSuperNeo`, transformed sparse ring matrices, and
  terminal CE opening checks.
- The selected concrete profile is present as Goldilocks/Phi81(d=54), with
  `kappa = 18`, norm bound `2`, challenge coefficients `[-2, -1, 0, 1, 2]`,
  decomposition length `14`, and the 129-bit assumption-scoped estimator lane.
- The repository has a serious formal and attack-oriented track: Lean protocol
  surfaces, verifier-negative tests, malformed-artifact fuzzing, stable vectors,
  QRO/QROM threat analysis, and benchmark instrumentation.

## Development Priorities

1. Make the paper reproduction surface first-class.

   The paper-reproduction script and DocC topic still mention older parameter,
   estimator, GPU, threat-model, high-assurance, and paper-reproduction docs
   that are absent from the current `Docs/` tree. The source-of-truth material
   exists in newer dossiers and evidence files, but the paper-facing entry
   points are fragmented. Add compact replacement docs or update those
   references so a reviewer can go from paper claim to command to evidence
   without knowing the repo history.

2. Promote pay-per-bit from model/evidence into measured implementation wins.

   The paper's D2 claim is not just adaptive decomposition; it is commitment
   cost scaling with witness bit width. The repo has `pay-per-bit-v1`,
   `AjtaiCommitter.workProfile`, profile-evaluation tooling, and pay-per-bit
   tests, but the default high-assurance path deliberately avoids
   witness-dependent skipping. Keep that default, but develop an explicit
   optimized performance lane with benchmark rows that demonstrate end-to-end
   bit-width scaling for commitments, PiCCS output claims, PiDEC, and product
   proofs.

3. Build a real recursive IVC/PCD driver.

   The paper emphasizes standard compilers to IVC/PCD and low recursive
   overhead. The repo currently has fold reductions, terminal proofs, and local
   typed recursive carry, while the product dossier still limits promoted-depth
   claims. A useful next milestone is a bounded-depth recursive aggregation API
   that repeatedly consumes prior CE/product carry claims, emits depth-indexed
   artifacts, and ties its extractor/loss accounting to the existing ledgers.

4. Add a paper-motivated post-quantum signature aggregation demo.

   The introduction motivates aggregating post-quantum signatures. Current
   public workloads are one-hot and binary addition, which are good test
   vectors but do not exercise that story. A small Lamport/XMSS/SLH-DSA-style
   verification circuit, folded across many signatures, would make the repo's
   product and benchmark story much closer to the paper's motivating use case.

5. Broaden the general-CCS frontend beyond demo R1CS workloads.

   SuperNeo's D4 advantage is general CCS without SIMD constraints. The repo
   has a R1CS builder, normalizer, and two workloads; it should grow a stable
   CCS import/build API with shape normalization, identity-matrix insertion,
   power-of-two padding diagnostics, and negative tests for non-SIMD constraint
   systems. A Plonkish or AIR adapter would be a strong later target.

6. Tighten the Swift-to-formal embedding bridge.

   The paper's core technical move is the transformed coefficient embedding and
   evaluation homomorphism. The implementation compiles transformed sparse ring
   matrices, and the Lean tree has embedding/Phi81 material, but this deserves a
   direct conformance artifact: generated Swift vectors for matrix transform,
   constant-term product, multilinear evaluation, and RLC homomorphism, checked
   against Lean or a small independent reference.

7. Turn parameter security into a maintained dossier.

   The paper relies on Module-SIS, strong sampling sets, low-norm invertibility,
   and estimator lanes. The repo has the pinned profile and validation scripts,
   but a maintained parameter dossier should expose the exact derivation,
   sensitivity rows, estimator toolchain status, and why production PQ wording
   remains disabled. This should replace the missing older parameter/estimator
   docs rather than adding another parallel source.

8. Separate ideal QRO theorem claims from concrete hash deployment work.

   The QRO product architecture is much stronger than an artifact-selected
   Fiat-Shamir seed path, but the docs correctly keep production QROM and
   concrete-hash promotion disabled. The next development work is a concrete
   hash/QRO instantiation plan: domain separation inventory, public-coin service
   semantics, replay freshness, side-channel assumptions, and a proof/evidence
   story for deployment rather than just repository-local split-QRO modeling.

9. Add actual proof compression rather than only digest-bound compression.

   The paper notes that Goldilocks-native folding can be compressed efficiently
   with SNARK-friendly proof systems. The repo has terminal and
   compressed-terminal envelopes, but compressed terminal proofs are digest-bound
   wrappers, not a Spartan/FRI-style proof-compression layer. A clean compression
   interface plus a small proof-of-concept would close a visible paper-to-product
   gap.

10. Continue hardening Metal and side-channel lanes as explicit modes.

    The paper's performance discussion is CPU/vectorization-oriented, while this
    repo differentiates itself with Apple Metal. The current policies are
    conservative: default/high-assurance CPU, optional Metal, and CPU-redundant
    cross-checks. Keep that split and develop the optimized Metal lane with
    differential tests, benchmark coverage, and signed side-channel certificate
    evidence, without blurring it into the default security claim.

## Suggested Ordering

Do the documentation/reproduction cleanup first, because it removes ambiguity
for every later claim. Then develop pay-per-bit performance evidence and the
Swift-to-formal embedding vectors, because those directly support the paper's
distinctive technical contributions. After that, invest in recursive aggregation
and a post-quantum signature workload; those are larger features but would make
the repo demonstrate the paper's intended application rather than only its core
protocol mechanics.
