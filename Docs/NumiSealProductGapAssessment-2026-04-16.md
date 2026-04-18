# NumiSeal Product Gap Assessment, 2026-04-16

Keep this note short. It exists so future agents can see what remains without
loading older long-form roadmap notes.

## Verdict

Mostly true: NumiSeal has production-facing inspection, verification, and local
product artifact generation for checked immediate-residual artifacts. It is not
a complete hosted production NumiSeal product.

Correction: repository-level SuperNeo formal status is now a completed formal
protocol theorem for the finite model. What remains is the listed
NumiSeal-specific product work plus the selected total-loss, release,
side-channel, operations, and audit evidence tracked outside the Lean theorem.

## Current Surface

- [x] `superneo inspect` parses checked NumiSeal artifacts.
- [x] `superneo verify --require-numiseal` verifies checked kind `4`
  immediate-residual artifacts.
- [x] `NumiSealArtifactVerifier` validates metadata, trust pins, envelope roots,
  public reconstruction, and `NumiSealVerifier` dispatch.
- [x] `SuperNeoNumiSealProductVerifier` provides hooks for expected context,
  authorization, provenance, replay, byte limits, and audit events.
- [x] Local CLI product controls provide signed context/provenance loading,
  signed revocation feed loading, SQLite replay, hash-chained audit export, and
  machine-readable product-ops readiness status.
- [x] `NumiSealProver`/`NumiSealVerifier` library APIs exist for the current
  immediate-residual path.
- [x] `NumiSealZK` kind `5` exists with checked masked residual proof syntax,
  randomness-session reuse guards, and exact rejection-sampled field mask
  distribution evidence.
- [x] Recursive typed carry now has a producer API that binds accepted parent
  proof context into the existing typed carry consumer relation.
- [x] Product recursive carry now has a typed-required parent-child path: a
  verified parent product can produce carry claims for a child artifact, and the
  product verifier requires the matching parent context for `typed-required`.
- [x] `NumiSealProductAPI` exposes product artifact generation outside
  deterministic vector tooling for prepared R1CS, one-hot vectors, and binary
  addition workloads.
- [x] Supported frontend outputs are now bound into
  `NumiSealProductTrustedContext`, which derives the frontend context digest
  carried by product artifacts.
- [x] Product artifacts emit pinned Swift trace/extractor metadata, CTCO
  context/root/challenge-tape metadata, 384-bit binding-width QROM metadata,
  and ZK simulator-coupling evidence metadata when ZK mode is selected.
- [x] Checked repository manifests now pin Swift trace/extractor evidence, ZK
  simulator-coupling evidence, and CTCO/QROM instantiation evidence with
  validators and production-gate coverage.
- [x] Local product controls can consume an already accepted recursive parent,
  including a parent that is itself recursive, through the replay ledger and
  carry replay roots.

## Remaining Work

- [ ] Recursive carry: promote the checked local chain replay policy to hosted
  selected-depth replay semantics and formal loss accounting.
- [ ] ZK: refresh product-sized hardware benchmark evidence on release hardware
  and finish side-channel review before changing product defaults.
- [ ] Product operations: hosted context storage, deployed key distribution,
  tenant authz, hosted audit retention, hosted revocation feed distribution, and
  signed releases.
- [ ] NumiSeal-specific product evidence: the completed finite Lean theorem
  stack is current, including well-formed transcripts, 384-bit theorem-critical
  bindings, constructive PiCCS/terminal CE finite bad sets, and the finite
  probability ledger. Remaining NumiSeal-specific work is release-grade Swift
  review of the pinned Swift extractor/trace surface, hosted selected-depth
  typed carry policy, release-hardware side-channel evidence, and numeric
  total-loss instantiation for source-fold, terminal, extractor, product
  operations, side-channel, and release terms. The ideal split-QRO
  compiler-overhead term and proof-level NumiSealZK simulator loss are now
  instantiated as zero, per-kind interactive security bounds are pinned outside
  `epsilon_qrom`, and the exact partial total-loss budget is wired.
- [ ] Self-owned review: cryptographic review, implementation review, and
  side-channel assessment recorded in repository evidence.

## Safe Wording

Use:

> NumiSeal currently generates and verifies checked immediate-residual product
> artifacts through supported Swift and CLI surfaces. It is not yet
> recursive-by-default, zero-knowledge-by-default, or a deployed production
> product.
