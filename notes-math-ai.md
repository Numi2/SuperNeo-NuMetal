# SuperNeo / NumiSeal QROM theorem package (proposed)

## Bottom line

The current pinned DFM20-style QROM interface cannot certify the target budget. This is true for three independent reasons.

1. The current additive ordering term is already fatal: for the smallest accepted `n = 204`, `log2(204!) ≈ 1276.03`, so `204! / 2^256 ≈ 2^1020.03 > 1`.
2. Even after repairing the round count, generic multi-round Fiat–Shamir in the QROM with `Q_H = 2^64` is incompatible with an underlying interactive security level around `2^-129`; even a one-challenge proof would need roughly 258 bits of interactive soundness.
3. If acceptance-critical binding relies on 256-bit digests and `Q_H = 2^64`, the natural quantum fixed-target search bound leaves essentially no slack. A 384-bit binding layer is the clean fix.

## Recommended theorem route

Use a split-hash oracle model:

- `H_chal : {0,1}^* -> {0,1}^256` for Fiat–Shamir challenge seeds and counter expansion;
- `H_bind : {0,1}^* -> {0,1}^384` for acceptance-critical binding digests.

Refactor each accepted proof kind into a 3-move public-coin commit-and-open / open-and-sign style protocol:

1. prover sends a root digest binding all witness-dependent trace blocks,
2. verifier sends one 256-bit seed,
3. prover opens the blocks selected by deterministic expansion of that seed.

This gives `n_kind = 1` for all five proof kinds and allows a tight QROM theorem instead of the current DFM20 accounting.

## Collision bound

Let `m_target = 9` be the number of exported structural fixed-target binding events.
With a conservative Grover-style bound,

`epsilon_collision <= 4 * m_target * Q_H^2 / 2^lambda_bind`.

At `Q_H = 2^64`:

- with `lambda_bind = 256`, `epsilon_collision <= 36 * 2^-128`, which is not budget-safe;
- with `lambda_bind = 384`, `epsilon_collision <= 36 * 2^-256`, which is negligible for the selected budget.

## Ledger repair

Interactive soundness must be charged outside `epsilon_qrom`. The current shape appears to charge it twice: once through `epsilon_fold` / `epsilon_terminal` / `epsilon_extract`, and again inside the DFM20-style `epsilon_qrom` term. The repaired ledger should charge:

- interactive knowledge soundness in the layer terms,
- only transform overhead and hash-model gap in `epsilon_qrom`, and
- structural binding failures in `epsilon_collision`.

## Minimal viable change set

1. Replace the current QROM transform claim by a tight commit-and-open / open-and-sign transform.
2. Add a 384-bit binding digest layer over acceptance-critical framed encodings.
3. Keep 256-bit challenge seeds and counter expansion.
4. De-duplicate shared bad events in the selected-depth ledger. If that is not done, raise the underlying lattice margin from `129.1` effective bits to at least `130-132` effective bits depending on how many rows remain separately charged.


----

I used the Lean snippet and manifest summaries in your prompt as the pinned state; the absolute local paths were not mounted in this environment.

Companion note: [numiseal_qrom_theorem_package.md](sandbox:/mnt/data/numiseal_qrom_theorem_package.md)

The short verdict is this: the current pinned system does **not** admit an honest depth-1 `2^-128` QROM claim. That is not just because of the `204!/2^256` term. There are three independent blockers.

First, the current DFM20-style interface is dead on arrival: `n = 204` already gives `log2(204!) ≈ 1276.03`, so `204!/2^256 ≈ 2^1020.03 > 1`, and kinds 4 and 5 are vastly worse. Second, even after repairing the round accounting, generic multi-round Fiat–Shamir in the QROM is the wrong theorem family for `Q_H = 2^64`; DFM20’s loss is for `(2n+1)`-round public-coin protocols and the quadratic loss is essentially optimal up to a round-dependent constant, while Attema–Fehr–Klooß show that generic multi-round FS can degrade exponentially with the number of rounds. ([eprint iacr][1]) Third, if acceptance-critical bindings stay at 256 bits, then at `Q_H = 2^64` you have essentially no quantum slack even for fixed-target digest matching, and generic quantum collision-finding is worse still. Grover gives square-root speedups for fixed-target search, and BHT gives `N^{1/3}`-type quantum collision finding for random functions. ([arXiv][2])

So the clean route is not “make current DFM20 work.” The clean route is:

1. separate **interactive soundness** from **FS transform overhead** in the ledger,
2. split the hash roles into a 256-bit challenge oracle and a 384-bit binding oracle,
3. refactor each accepted proof kind into a **3-move commit-and-open / open-and-sign style public-coin protocol** with one seed challenge, and
4. deduplicate shared bad events in the selected-depth ledger.

A. Paper-grade theorem statement

Let `K = {fold, terminal, compressed-terminal, numiseal-terminal, numiseal-zk-product}`. For each `k ∈ K`, define a relation `R_k(x,w)` over the actual product system:

`R_fold` says that `w` contains a valid source CCS witness, fold randomness, and CE-opening witness whose committed/output claims match the public fold statement.

`R_terminal` says that `w` contains valid NumiSeal terminal residual-opening material and terminal obligation witness matching the public statement root, verifier key, and terminal policy.

`R_compressed_terminal` is the same relation as `R_terminal`, but the public proof body is required to be the canonical compressed encoding whose deterministic decompression yields the unique terminal transcript.

`R_numiseal_terminal` says that `w` contains a valid source-fold witness, valid terminal witness, valid product obligation witness, and valid component-root witness matching the lane/aggregate/product context, artifact/provenance binding, and verifier acceptance policy.

`R_numiseal_zk_product` says that `w` contains everything in `R_numiseal_terminal` plus mask witness, randomness-session witness, and leakage witness, such that the masked residual relation holds and the public leakage digest equals the declared leakage view.

`R_carry` says that `w` contains the typed parent/child carry witness linking parent artifact, parent acceptance, producer proof envelope, lane, aggregate, child session, and next recursion level through the carry replay-binding digest.

Now define the product relation `R_prod^1` at selected depth `1` to mean: the accepted proof kind is one of the five allowed kinds, the proof-envelope/artifact/provenance/replay/carry/session/leakage bindings all match the expected context, and the corresponding kind-specific relation above holds. At depth `1`, the carry multiplicity is zero unless the accepted artifact explicitly uses `typed-required`.

Define two independent framed random oracles:

`H_chal : {0,1}* -> {0,1}^256` for Fiat–Shamir challenge seeds and counter expansion.

`H_bind : {0,1}* -> {0,1}^384` for all acceptance-critical binding digests.

All oracle inputs are length-prefixed framed byte strings using the existing Lean framing discipline. The proof kind byte is one of `{1,2,3,4,5}` exactly as in `Serialization.lean`. The first frame is always a versioned domain separator; the proof kind and selected-depth context are always explicit frames. The existing `proofEnvelopeTranscriptBindingEncode` lemma gives the injective raw context encoding that should become the preimage to `H_bind`.

The theorem I recommend is:

**Theorem (ProductQROMTightTransform, depth 1, split-QRO model).**
Assume that for each accepted proof kind `k`, the pre-FS protocol `Π_k^CO` is a 3-move public-coin commit-and-open protocol with first prover message `α_k`, one verifier challenge seed `ρ_k ∈ {0,1}^256`, and response `β_k`, satisfying completeness, special soundness / online extractability, and the declared transcript-binding preconditions. Assume also that all acceptance-critical bindings are computed with `H_bind`, that all challenge seeds and counter expansions are computed with `H_chal`, and that cross-kind/domain/session/carry swaps are only possible via one of the explicit exported binding-target bad events. Then for every QPT adversary `A` making at most `Q_H` quantum queries to each oracle, the probability that `A` outputs an accepting depth-1 product artifact for which no witness for `R_prod^1` exists is at most

```text
Pr[Bad_MSIS_shared]
+ Pr[Bad_ZK_sim]
+ Pr[Bad_bind_target]
+ Pr[Bad_replay]
+ Pr[Bad_ct]
+ Pr[Bad_release]
```

where `Bad_bind_target` is the union of the nine explicit structural fixed-target binding failures, and where the Fiat–Shamir transform itself contributes no additional multiplicative `Q_H^(2n)` loss beyond the already-charged interactive soundness terms, because the transform is tight in the selected theorem family.

That route is aligned with the QROM literature on tight online extractability for commit-and-open Sigma protocols, and with the more recent straight-line / open-and-sign line for recursive composition. ([arXiv][3])

B. Exact pre-FS interactive protocol definitions

I do **not** recommend keeping the current long-round pre-FS schedule as the theorem target. I recommend replacing it with the following common outer protocol shape for all five accepted proof kinds.

For each kind `k`, let public input be `x_k`, witness be `w_k`, and let `Trace_k(x_k,w_k;r)` be the full witness-dependent trace blocks that the verifier may later need to inspect. Let `Root_k = H_bind(dom="root/k/v2" || framed(x_k) || framed(TraceCommitments_k))`.

Move 1, prover message `α_k`.
The prover sends:

* the public commitment material already required by kind `k`,
* a 384-bit root digest `Root_k`,
* the 384-bit context-binding digest `CtxBind_k = H_bind(dom="ctx/k/v2" || proofEnvelopeTranscriptBindingEncode(context_k))`,
* and, when applicable, 384-bit binders for artifact, provenance, replay, carry, randomness-session, and leakage.

Move 2, verifier challenge `ρ_k`.
The verifier samples one 256-bit uniform seed:
`ρ_k <- {0,1}^256`.

Move 3, prover response `β_k`.
The prover expands `ρ_k` deterministically by
`Expand(ρ_k,label,i) = H_chal(dom="expand/k/v2" || framed(label) || framed(ρ_k) || framed(u64(i)))`
and uses the expanded values as the full internal micro-challenge tape. The prover then returns:

* the opened trace blocks selected by the challenge tape,
* authentication paths against `Root_k`,
* the explicit algebraic responses needed by the deterministic checker,
* and, for kind 5, the masked residual openings together with session/leakage consistency material.

The verifier recomputes the challenge tape from `ρ_k`, checks every opening against `Root_k`, checks every binding digest against the expected context, and runs the exact algebraic verifier for that kind.

Under this recommended refactor, the move count is `3` and the challenge count is `1` for **all five kinds**:

```text
n_fold = 1
n_terminal = 1
n_compressed_terminal = 1
n_numiseal_terminal = 1
n_numiseal_zk_product = 1
```

The kind-specific extractor targets are:

`fold`: extract `(source CCS witness, fold randomness, CE-opening witness)`.

`terminal`: extract `(terminal residual witness, terminal obligation witness, CE-opening witness)`.

`compressed-terminal`: extract the same as `terminal`, after deterministic decompression.

`numiseal-terminal`: extract `(source-fold witness, terminal witness, product obligation witness, component-root witness, optional carry witness)`.

`numiseal-zk-product`: extract everything in `numiseal-terminal` plus `(mask witness, randomness-session witness, leakage witness)`.

The current protocol does **not** satisfy these preconditions as stated, because the CE-opening and product schedules do not yet provide a single pre-challenge root that binds all later challenge-dependent material. That is the exact precondition failure. The required protocol modification is: add a root commitment over all witness-dependent trace blocks that would otherwise be revealed incrementally after later challenges.

C. Symbolic loss formulas

I would replace the current accounting by the following.

Per-kind interactive losses:

```text
epsilon_interactive_fold
  = epsilon_MSIS_shared + epsilon_fold_algebraic

epsilon_interactive_terminal
  = epsilon_MSIS_shared + epsilon_terminal_algebraic

epsilon_interactive_compressed_terminal
  = epsilon_interactive_terminal

epsilon_interactive_numiseal_terminal
  = epsilon_MSIS_shared + epsilon_numiseal_algebraic

epsilon_interactive_numiseal_zk_product
  = epsilon_MSIS_shared + epsilon_numiseal_algebraic + epsilon_mask_session
```

For the current dossier, the only numerically pinned computational failure term you gave is the Module-SIS/Ajtai lane at about `129.1` bits. The clean conservative instantiation is therefore

```text
epsilon_MSIS_shared := 2^-129
epsilon_fold_algebraic := 0
epsilon_terminal_algebraic := 0
epsilon_numiseal_algebraic := 0
epsilon_mask_session := 0
```

so that every `epsilon_interactive_kind` is conservatively `2^-129`. That is the right way to instantiate them **before** the FS transform is applied.

Now fix the QROM transform ledger. `epsilon_qrom` should not re-charge the underlying interactive soundness; that is already what the layer terms are for. The repaired split is:

```text
epsilon_qrom
  = epsilon_fs_transform_extra
  + epsilon_hash_model_gap
  + epsilon_proof_kind_malleability
```

with

```text
epsilon_fs_transform_extra = 0
```

in the ideal split-QRO model once the commit-and-open / open-and-sign theorem preconditions are closed,

```text
epsilon_hash_model_gap = 0
```

in the ideal split-QRO model, and

```text
epsilon_proof_kind_malleability = 0
```

because the remaining cross-kind malleability paths are already charged to explicit binding-target failures in `epsilon_collision`.

The binding/collision term should be

```text
epsilon_transcript_collision
  = 4 * m_target * Q_H^2 / 2^lambda_bind
```

where `m_target = 9` is the number of exported fixed-target binding events and `lambda_bind` is the binding digest length. Then

```text
epsilon_collision = epsilon_transcript_collision
```

because the structural manifest already exports those events to the collision ledger.

The full cryptographic depth-1 total is then

```text
epsilon_total_crypt(depth=1)
  = epsilon_fold
  + epsilon_terminal
  + epsilon_zk_sim
  + epsilon_qrom
  + epsilon_extract
  + epsilon_collision
```

and the repo-wide total remains

```text
epsilon_total(depth=1)
  = epsilon_total_crypt(depth=1)
  + epsilon_replay
  + epsilon_ct
  + epsilon_release
```

D. Exact numeric instantiated bounds for the current pinned parameters

Current pinned route, as written, fails immediately:

```text
epsilon_qrom_current(depth=1)
  >= 204! / 2^256
  ≈ 2^1020.03
  > 1
```

So the current `DFM20 + 256-bit challenge space + current n_kind accounting` cannot be repaired by a constant-factor tweak.

It is even worse than that. Even if you repaired the round accounting all the way down to a one-challenge public-coin proof and kept generic FS/QROM with `Q_H = 2^64`, the multiplicative factor would still be about `2^130`, so a `2^-129` interactive bound would already be vacuous.

Current structural binding with 256-bit acceptance-critical digests is also not certifiable at `Q_H = 2^64`. Using the conservative fixed-target quantum search bound with `m_target = 9` gives

```text
epsilon_collision_current
  <= 4 * 9 * 2^128 / 2^256
  = 36 * 2^-128
  ≈ 2^-122.83
```

Even the optimistic constant-1 version would be `9 * 2^-128 ≈ 2^-124.83`, still above the selected `2^-128` budget.

So the current pinned parameters are a clear **fail**.

E. Minimal viable change set

This is the smallest honest set I would recommend.

1. Keep `challengeRange = 2^256`, but use it **only** for `H_chal` challenge seeds and counter expansion.

2. Add a distinct 384-bit binding layer `H_bind`. Do **not** rely on raw 256-bit metadata digests for acceptance-critical equality tests at `Q_H = 2^64`. Instead, hash the existing canonical framed encodings with `H_bind` and compare those 384-bit binders. This can be done without changing every raw metadata field.

3. Replace the current long-round FS target by the 3-move commit-and-open / open-and-sign wrapper above, so every accepted proof kind has one challenge seed.

4. Separate interactive soundness from transform overhead in the ledger. The present `epsilon_qrom` interface appears to double-count the interactive term.

5. Add shared bad-event tagging to the selected-depth ledger, so the same underlying Module-SIS failure is not summed multiple times under different row names.

Under that change set, the depth-1 **cryptographic** loss becomes

```text
epsilon_collision_new
  = 36 * 2^-256
  ≈ 2^-250.83
```

and if you charge the shared Module-SIS bad event only once,

```text
epsilon_total_crypt(depth=1)
  <= 2^-129 + 36 * 2^-256
  < 2^-128 .
```

So with bad-event deduplication, the current `129.1`-bit dossier is enough for the cryptographic slice.

If you refuse bad-event deduplication and keep flat additive rows, then the mathematical minimum depends on how many rows keep charging the same underlying assumption. Three equally-sized dominant rows need at least `130` effective bits; four need `131` practical bits; `132` is the clean recommendation. So the “no-ledger-redesign” fallback is: raise the lattice lane from `129.1` to about `132` effective bits, while still doing the split-hash and C&O/open-and-sign refactor.

F. Lean-facing proposition names and structure fields

The theorem names you suggested are good. I would add:

```text
ProductQROMHashInstantiation
ProductQROMCollisionBound
ProductQROMMalleabilityBound
ProductInteractiveSecurityBounds
ProductQROMTightTransform
ProductQROMTotalLossInstantiated
productSecurityTheorem_from_instantiated_qrom
```

I would add a new structure, conceptually:

```text
structure ProductHashOracleInstantiation where
  challengeOracleBits : Nat
  bindingOracleBits : Nat
  splitOraclesPinned : Prop
  framedEncodingInjective : Prop
  proofKindBytesInjective : Prop
  challengeDomainsSeparated : Prop
  bindingDomainsSeparated : Prop
  bindingTargetEventCountPinned : Prop
  concreteHashAssumptionPinned : Prop
```

I would extend `ProductFiatShamirLossAccounting` with fields like:

```text
interactiveLossChargedOutsideQROM : Prop
splitChallengeAndBindingOraclesPinned : Prop
bindingDigestBitLengthPinned : Prop
bindingTargetCollisionBoundInstantiated : Prop
proofKindMalleabilityChargedToCollisionLedger : Prop
qromExtraLossOnly : Prop
```

I would broaden `ProductQROMInteractiveReduction` so the theorem family is not hard-coded to DFM20:

```text
inductive ProductQROMTransformFamily where
  | dfm20
  | commitOpenTight
  | openAndSign
```

and then pin the selected family in the manifest and Lean structure.

G. Manifest field updates

I would add or change these fields.

```json
{
  "hashModel": "ideal-split-qro",
  "challengeOracle": {
    "outputBits": 256,
    "domain": "superneo/numiseal/chal/v2",
    "counterExpansion": "sha256-counter"
  },
  "bindingOracle": {
    "outputBits": 384,
    "domain": "superneo/numiseal/bind/v2",
    "bindingTargetEventCount": 9
  },
  "qromTransformFamily": "commit-open-tight",
  "interactiveLossChargedOutsideQROM": true,
  "challengeMessageCountByKind": {
    "fold": 1,
    "terminal": 1,
    "compressed-terminal": 1,
    "numiseal-terminal": 1,
    "numiseal-zk-product": 1
  },
  "bindingCollisionFormula": "4 * bindingTargetEventCount * Q_H^2 / 2^bindingOracle.outputBits",
  "proofKindMalleabilityFormula": "0",
  "sharedBadEventTagsPinned": true,
  "digestCollisionBoundInstantiated": true,
  "proofKindMalleabilityBoundInstantiated": true,
  "interactiveSecurityBoundsInstantiated": true,
  "qromReductionLossWithinBudget": true
}
```

For the booleans you listed, the honest settings are:

```text
hashQROInstantiationProofProvided = false
```

unless you truly prove a concrete SHA instantiation. Replace it with

```text
hashQROInstantiationAssumptionPinned = true
```

If the repo insists that `productionQROMClaimAllowed` means “under the ideal split-QRO assumption,” then it may become `true` after the refactor. If it means “for concrete SHA with no idealization,” keep it `false`.

H. Implementation-facing transcript/oracle requirements

Every acceptance-critical digest comparison must be against a 384-bit `H_bind` output over a **versioned framed encoding**, not against a raw 256-bit metadata digest.

The first transcript frame must be a versioned domain separator. The proof kind byte must always be explicit. The existing Lean framing and injectivity lemmas are exactly the right foundation.

`proofEnvelopeTranscriptBindingEncode(context)` should remain the canonical raw encoding, but the verifier should compare `CtxBind = H_bind(dom="ctx/k/v2" || proofEnvelopeTranscriptBindingEncode(context))`.

The challenge oracle input should include the 384-bit context binder, not the raw 256-bit subdigests.

Counter expansion labels must be unique and versioned. A good shape is:
`fold/v2`, `terminal/v2`, `compressed-terminal/v2`, `numiseal-terminal/v2`, `numiseal-zk-product/v2`, with inner labels like `ce`, `lane`, `obligation`, `mask`, `carry`.

For compressed-terminal, the verifier must decompress to the unique canonical terminal transcript before any acceptance-critical binding comparison.

For typed carry, the 384-bit carry-binding digest must cover at least:
parent artifact digest, parent acceptance digest, producer proof envelope digest, lane, aggregate, child session digest, and next recursion level.

Pass/fail verdict

For the **current** pinned parameters and theorem interface: **fail**.

For the smallest honest route I recommend:

* split `H_chal`/`H_bind`,
* add 384-bit binding digests,
* move to a 3-move commit-and-open / open-and-sign pre-FS protocol per kind,
* charge interactive soundness outside `epsilon_qrom`,
* deduplicate shared bad events.

Under that route, the depth-1 **cryptographic** theorem can fit the `2^-128` budget without changing the current 129.1-bit lattice lane, but only if the ledger deduplicates the shared Module-SIS bad event. If you keep flat additive rows, raise the effective lattice margin to about `132` bits.

The remaining repo-wide blockers are still the non-math terms you already separated: `epsilon_ct` and `epsilon_release`, a

nd `epsilon_replay` if you insist on counting it as a probabilistic term rather than as deterministic policy enforcement.

[1]: https://eprint.iacr.org/2020/282.pdf "https://eprint.iacr.org/2020/282.pdf"
[2]: https://arxiv.org/abs/2009.00621 "https://arxiv.org/abs/2009.00621"
[3]: https://arxiv.org/abs/2202.13730 "https://arxiv.org/abs/2202.13730"
