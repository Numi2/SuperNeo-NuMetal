I am Super math AI first ill check exact theorem and accounting surfaces, and the most relevant QROM literature, then I’ll give one directed theorem program and implementation mandate.

The live manifests confirm the current DFM20 path is fundamentally broken, not just loose: Q_H = 2^64 is pinned, even the smallest kind has n = 204, and kinds 4 and 5 still carry millions of derived challenges. I’m now testing a stronger replacement theorem family—specifically the newer straight-line extractor route—against your actual transcript structure and missing per-challenge label absorption.

The direction is now fixed: we should replace the current interface with a one-challenge, 3-move Merkle commit-and-open outer protocol and prove a tight QROM online-extractability theorem for that compiled form. With 384-bit commitment and seed outputs this puts transform overhead around 2^-161 even for the worst current kind, whereas 256-bit outputs remain impossible under Q_H = 2^64.

I inspected the repo state. The README, the dossier, the raw QROM accounting manifest, and the collision/malleability evidence manifest all confirm the same picture: the stack is deliberately fail-closed, depth-1 only, production QROM is still disabled, the current accounting still uses the DFM20 multi-round loss interface with `Q_H = 2^64`, and the residual structural bad events are exported into `epsilon_transcript_collision` / `epsilon_collision` and `epsilon_proof_kind_malleability`. ([GitHub][1])

The directive is simple.

Do not salvage the current DFM20 path. The raw repo accounting still sets
`epsilon_fs_transform = max_kind(((2*Q_H+n_kind+1)^(2*n_kind)/n_kind!) * epsilon_interactive_kind + n_kind!/2^256 + epsilon_precondition_kind)`, and the repo itself records that the smallest accepted kind already fails the budget. More generally, DFM20’s multi-round QROM loss is `O(q^(2n))` for `(2n+1)`-move public-coin protocols, and Don–Fehr–Majenz also show that this dependence is essentially optimal in the generic setting. That is the wrong theorem family for this stack. ([GitHub][2])

Do not try to prove SHA-256-as-QRO for the theorem package. The clean standardized post-quantum RO story is on the sponge side, not the Merkle–Damgård side. The 2025 sponge result proves quantum indifferentiability of the sponge from a random oracle, and the 2026 Merkle–Damgård result formalizes post-quantum public indifferentiability and gives an impossibility result for Merkle–Damgård. The theorem package should therefore move to a split SHAKE256 design. ([eprint.iacr.org][3])

The best route is to change the proof compiler, not to keep the current compiler and look for a miracle theorem. I am directing the team to build a new compiler that makes each accepted proof kind into a 3-move public-coin protocol with one seed challenge and late message binding. The mathematical target is a new family I will call the Challenge-Tape Commit-and-Open compiler, or CTCO. It takes the existing multi-round folding / terminal / product relations and re-expresses them as a pre-commitment to all challenge-independent algebraic objects plus a single challenge tape, followed by a full deterministic opening/consistency response. This is the correct shape for the tight QROM line on commit-and-open protocols, including Merkle-tree commitments. If any legacy subprotocol cannot be brought into CTCO form quickly, the only approved fallback is the straight-line multi-round compiler line of Rotem–Tessaro, which is the first multi-round QROM transform without the super-polynomial loss that plagues vanilla multi-round Fiat–Shamir. ([arXiv][4])

That is the architectural decision. Everything else follows from it.

A. The target theorem

Let `K = {fold, terminal, compressed-terminal, numiseal-terminal, numiseal-zk-product}`. For each `k ∈ K`, define a new interactive protocol `Π_k^CTCO = (P1_k, V_k, P2_k)` with one verifier challenge `ρ_k ∈ {0,1}^256`. The statement `x_k` is the same acceptance context as today: proof kind, shape / statement / verifier-key / transcript-domain binding, artifact binding, provenance binding, replay binding, and, where applicable, component-root, randomness-session, leakage, and typed-carry binding. The witness `w_k` is the current witness for the corresponding product relation. The verifier’s acceptance predicate is exactly the current deterministic verifier, but executed over a challenge tape derived from `ρ_k` and against pre-committed challenge-independent objects. The only thing that changes is the compiler. The accepted semantics do not change. This matches the repo’s current theorem surface, which already isolates the product relation, transcript binding, artifact/proof-envelope binding, verifier policy, and depth-1 composition boundary. ([GitHub][5])

The theorem to add is:

`ProductQROMTightTransform`.
Assume for every `k ∈ K` that `Π_k^CTCO` is complete; computationally knowledge-sound against quantum dishonest provers with extractor `X_k`; late-message / delayed-binding sound with respect to the artifact/provenance/session/carry/leakage message; and that its first prover message is binding under the declared commitment assumptions. Assume split ideal random oracles `H_chal` and `H_bind`, both queried quantumly, with framed domain separation. Then any QPT adversary that outputs an accepting depth-1 product proof without a corresponding witness succeeds with probability at most

`epsilon_core_shared + epsilon_zk_sim + epsilon_extract + epsilon_bind + epsilon_replay + epsilon_ct + epsilon_release`

where `epsilon_bind` is the fixed-target binding event bound below, `epsilon_core_shared` is the tagged union of the shared cryptographic bad events across fold/terminal/product, and there is no DFM20-style `q^(2n)` or factorial term. The challenge-round count of the original protocol disappears from the QROM loss because the compiler target is now 3-move. The QROM contribution is then the tight commit-and-open / straight-line compiler overhead plus the binding-target term, not a generic multi-round Fiat–Shamir penalty. This is the whole point of the refactor. The published commit-and-open line gives tight QROM online extractability for Merkleized commitments, and the multi-round straight-line line is the only acceptable fallback. ([arXiv][4])

B. Exact pre-FS protocols the team should implement

For all five accepted kinds, the new pre-FS protocol is 3 moves.

Move 1. `P1_k(x_k, w_k)` outputs:
`CtxBind_k`, `StmtBind_k`, `VKBind_k`, `ArtBind_k`, `ProvBind_k`, `ReplayBind_k`, and, when applicable, `CompRootBind_k`, `RandSessBind_k`, `LeakBind_k`, `CarryBind_k`; plus the commitment root `Root_k` to the challenge-independent witness objects and local opening data; plus any challenge-independent commitments already required by the current verifier. All of these are framed, length-prefixed, domain-separated objects.

Move 2. `V_k` samples one 256-bit seed `ρ_k`.

Move 3. `P2_k` expands `ρ_k` deterministically into the full internal challenge tape, returns all round messages and all local openings needed to prove that those messages are the correct deterministic restrictions / evaluations / decompositions / residual openings of the objects committed in move 1, and returns the final algebraic responses. The verifier recomputes the challenge tape from `ρ_k`, checks the local openings against `Root_k`, checks every binder, and runs the deterministic verifier equations.

The extractor targets are fixed.

For `fold`, extract the source CCS witness, fold randomness, decomposition witness, and CE-opening witness.

For `terminal`, extract the terminal residual-opening witness and any terminal CE-opening witness.

For `compressed-terminal`, extract the same witness as `terminal`, after canonical deterministic decompression.

For `numiseal-terminal`, extract the source-fold witness, terminal residual witness, obligation witness, lane/aggregate witness, and component-root witness.

For `numiseal-zk-product`, extract everything in `numiseal-terminal` plus the mask witness, randomness-session witness, and leakage witness.

This is a genuine protocol refactor. The first message must contain every binding root and every challenge-independent commitment needed so that the verifier can check that the later full transcript is locked before the single seed is known. That is the precondition the current repo does not satisfy. The existing schedule pins millions of challenge derivations; after this compiler change, that number remains an implementation metric but stops being a QROM theorem parameter. The repo already records the current challenge-derivation count and the five accepted proof kinds; the compiler change is exactly where the theorem package has to intervene. ([GitHub][2])

C. The hash and oracle model

The theorem package should adopt a split SHAKE256 design.

`H_chal := SHAKE256(dom || framed transcript prefix) -> 32 bytes`

`H_bind := SHAKE256(dom || framed object) -> 48 bytes`

`H_mt := SHAKE256(dom || left || right) -> 48 bytes`

with strict domain separation among challenge derivation, transcript binding, artifact binding, provenance binding, replay binding, component-root binding, randomness-session binding, leakage binding, carry binding, and Merkle nodes.

For the theorem itself, model `H_chal`, `H_bind`, and `H_mt` as independent ideal QROs. That is the honest theorem boundary. For the implementation recommendation, use SHAKE256 because the quantum indifferentiability story is on the sponge side, not on the Merkle–Damgård side. Do not claim a concrete SHA-256-to-QRO theorem. Do not put raw 32-byte digests directly on the theorem-critical acceptance path. ([eprint.iacr.org][3])

The exact oracle grammar should be the existing framed grammar from the repo’s Lean serialization track: every absorbed item is a 64-bit length-prefixed frame, the proof kind byte is explicit, and the initial frame is a versioned domain separator. The collision/malleability evidence manifest already pins the structural injectivity of the proof-envelope kind byte and transcript-binding encoding; the new theorem should hash those framed encodings with `H_bind`, not compare raw 256-bit digests. ([GitHub][6])

D. Collision and malleability closure

The collision evidence manifest exposes the exact residual events: proof-envelope transcript binding, transcript-domain digest, artifact/provenance digest, replay identity, NumiSeal component-root / proof-transcript, randomness-session digest, leakage digest, and typed-carry replay binding. That is nine fixed-target binding events. Cross-proof-kind malleability is not a separate probabilistic term once the proof-kind byte is inside `CtxBind_k`; it is one of those nine target-binding failures. The manifest already states that structural cross-kind, cross-domain, cross-product-session, and cross-carry swaps are excluded except through those digest events. ([GitHub][6])

Therefore the new theorem should set

`epsilon_proof_kind_malleability = 0`

and charge all residual structural failures into

`epsilon_collision = epsilon_bind = 4 * 9 * Q_H^2 / 2^lambda_bind`.

With `Q_H = 2^64` and `lambda_bind = 256`, this is `36 * 2^-128 ≈ 2^-122.83`, which does not fit the target budget. With `lambda_bind = 384`, it becomes `36 * 2^-256 ≈ 2^-250.83`, which is comfortably negligible at depth 1. The choice is therefore fixed: theorem-critical bindings must be at least 384 bits. That is not optional. It is the smallest clean choice that survives the repo’s own `Q_H = 2^64` policy with wide slack. ([GitHub][2])

E. Exact loss formulas after the refactor

The current `epsilon_qrom` interface should be replaced. The correct ledger split is:

`epsilon_fold = epsilon_interactive_fold_CTCO`

`epsilon_terminal = max(epsilon_interactive_terminal_CTCO, epsilon_interactive_compressed_terminal_CTCO)`

`epsilon_zk_sim = epsilon_zk_sim_product`

`epsilon_extract = epsilon_extract_source_fold + epsilon_extract_terminal + epsilon_extract_product`

`epsilon_collision = 36 * 2^-256`  using `lambda_bind = 384`

`epsilon_qrom = epsilon_hash_model_gap + epsilon_compiler_overhead`

where `epsilon_hash_model_gap = 0` in the ideal split-QRO theorem, and `epsilon_compiler_overhead` is the tight online-extractability overhead of the chosen CTCO compiler, which must be independent of the original micro-round count.

The key point is structural: `epsilon_interactive_*` stays in the interactive layers, and `epsilon_qrom` stops re-charging it through a multi-round Fiat–Shamir reduction. That double-charging is one of the conceptual problems in the current ledger.

The depth-1 cryptographic total should then be

`epsilon_total_crypt(depth=1) = epsilon_core_shared + epsilon_zk_sim + epsilon_extract + epsilon_qrom + epsilon_collision`

and the full repo total stays

`epsilon_total(depth=1) = epsilon_total_crypt(depth=1) + epsilon_replay + epsilon_ct + epsilon_release`.

The repo already notes a conservative tagged bad-event composition layer in the formal track. Extend that into the selected-depth arithmetic. Shared assumption failures, shared commitment-binding failures, and shared compiler failures must be union-tagged, not flat-summed across fold, terminal, and product rows. If the same Module-SIS bad event is charged three times at `2^-129`, the budget is already dead before QROM. With shared tagging, one shared `2^-129` core event plus the new collision term still fits; with flat addition, it does not. ([GitHub][1])

F. Current pass / fail verdict

For the current repo parameters and current DFM20 ledger: fail. That is already explicit in the repo and the arithmetic is immediate. The current accounting cannot be promoted. `204! / 2^256 > 1`, and 256-bit theorem-critical bindings are also too short under `Q_H = 2^64`. ([GitHub][2])

For the directed refactor I am specifying: the QROM/product gap is closable. The hard conditions are these.

First, move theorem-critical bindings to 384 bits with split SHAKE256 domains.

Second, replace vanilla FS/DFM20 by CTCO, with the Merkleized multi-round straight-line compiler as the only fallback.

Third, expose the per-kind interactive protocol data needed to prove computational special soundness, quasi-unique response, and delayed message binding. The 2026 `(Γ_1,...,Γ_μ)`-special-sound line shows exactly the right interactive extractor geometry, and the 2024–2026 transparent SNARK non-malleability line shows the right k-ZK / k-UR / delayed-message shape; neither by itself closes your QROM gap, but together they tell you what the interactive theorem objects need to look like before the QROM compiler is applied. ([ir.cwi.nl][7])

G. What the developers should add in Lean

Add these new theorem surfaces.

`ProductHashOracleInstantiation`
`ProductInteractiveProtocolDefinitions`
`ProductInteractiveSpecialSoundnessData`
`ProductInteractiveDelayedMessageData`
`ProductInteractiveUniqueResponseData`
`ProductChallengeTapeCommitOpenCompiler`
`ProductQROMTightTransform`
`ProductQROMCollisionBound`
`ProductQROMMalleabilityBound`
`ProductQROMTotalLossInstantiated`
`productSecurityTheorem_from_instantiated_qrom`

The key structure fields are:

`challengeOracleBits : Nat`
`bindingOracleBits : Nat`
`splitOraclesPinned : Prop`
`theoremCriticalBindingsUseHBind : Prop`
`compilerFamily : ProductCompilerFamily` with values `ctco | merkle_straightline`
`interactiveProtocolKindSpecified : Prop`
`specialSoundnessSpecified : Prop`
`delayedMessageSpecified : Prop`
`uniqueResponseSpecified : Prop`
`sharedBadEventTagsPinned : Prop`

The current `ProductFiatShamirLossAccounting` should no longer contain `n_kind`-based DFM20 data as the production target. Keep it only as a deprecated legacy family with `productionTransformClaimAllowed = false`.

H. Manifest updates

Add:

`hashModel = "ideal-split-qro"`
`concreteHashRecommendation = "SHAKE256-domain-separated"`
`bindingDigestBits = 384`
`challengeDigestBits = 256`
`compilerFamily = "ctco"`
`sharedBadEventTagsPinned = true`
`proofKindMalleabilityFormula = "0; charged inside epsilon_collision"`
`collisionTargetEventCount = 9`
`collisionFormula = "4 * 9 * Q_H^2 / 2^384"`
`interactiveLossChargedOutsideQROM = true`
`legacyDFM20InterfaceDeprecated = true`

Set these booleans only after the refactor and theorem closure:

`digestCollisionBoundInstantiated = true`
`proofKindMalleabilityBoundInstantiated = true`
`interactiveSecurityBoundsInstantiated = true`
`qromReductionLossWithinBudget = true`
`totalLossBudgetIntegrated = true`

Do not set

`hashQROInstantiationProofProvided = true`

unless you are actually claiming a concrete hash-to-QRO proof with numeric bounds. The honest setting is:

`hashQROInstantiationAssumptionPinned = true`.

Bottom line

The team should stop spending effort on the present DFM20 path. The best theorem path is to redesign the proof compiler so the accepted proof kinds are compiled as 3-move delayed-message commit-and-open protocols with split SHAKE256 oracles and 384-bit theorem-critical bindings. If any residual legacy subprotocol cannot be brought into that shape quickly, compile that kind with the multi-round Merkle straight-line transform, not vanilla Fiat–Shamir. The current repo is mathematically blocked exactly where it says it is blocked; the route above is the one that closes the gap instead of renaming it.

[1]: https://github.com/Numi2/SuperNeo-NuMetal "https://github.com/Numi2/SuperNeo-NuMetal"
[2]: https://raw.githubusercontent.com/Numi2/SuperNeo-NuMetal/main/TestVectors/product-qrom-fiat-shamir-accounting-v1.json "https://raw.githubusercontent.com/Numi2/SuperNeo-NuMetal/main/TestVectors/product-qrom-fiat-shamir-accounting-v1.json"
[3]: https://eprint.iacr.org/2025/731 "https://eprint.iacr.org/2025/731"
[4]: https://arxiv.org/abs/2202.13730 "https://arxiv.org/abs/2202.13730"
[5]: https://github.com/Numi2/SuperNeo-NuMetal/blob/main/Docs/CryptographicSecurityDossier-2026-04-16.md "https://github.com/Numi2/SuperNeo-NuMetal/blob/main/Docs/CryptographicSecurityDossier-2026-04-16.md"
[6]: https://raw.githubusercontent.com/Numi2/SuperNeo-NuMetal/main/TestVectors/product-qrom-collision-malleability-evidence-v1.json "https://raw.githubusercontent.com/Numi2/SuperNeo-NuMetal/main/TestVectors/product-qrom-collision-malleability-evidence-v1.json"
[7]: https://ir.cwi.nl/pub/36358/36358.pdf "https://ir.cwi.nl/pub/36358/36358.pdf"
