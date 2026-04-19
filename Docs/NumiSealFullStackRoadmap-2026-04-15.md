# NumiSeal Full Stack Roadmap - 2026-04-15

Keep this file short. Completed implementation details belong in code, tests,
and byte-format docs. Future agents should update the unchecked items when the
work is actually merged and validated.

## Current Status

NumiSeal has production-facing inspection, verification, and local product
artifact-generation surfaces for checked immediate-residual artifacts. It is not
a complete hosted production NumiSeal product.

Formal wording: SuperNeo has a corrected finite-model core with open
theorem-critical integrations. NumiSeal-specific product claims remain scoped
to the checklist below.

## Done

- [x] `numiSealTerminal` proof envelope kind `4`.
- [x] NumiSeal public statement, lane IDs, lane keys, canonical obligations,
  lane summaries, obligation root, and lane-summary root.
- [x] Bounded NumiSeal proof-body parser with component digest root,
  transcript digest, lane-major ordering, and typed absent carry leaf.
- [x] NumiSeal terminal preflight policy for profile, shape, statement,
  verifier key, transcript domain, accepted lanes, residual mode, carry mode,
  proof byte limit, lane count, and aggregate count.
- [x] Deterministic lane-local aggregation.
- [x] Decomposition key derivation, bounded ternary digit tensor, zero-padding
  checks, and CPU decomposition commitment checks.
- [x] Public scalarization residual.
- [x] Dense degree-4 NumiSeal sum-check handoff, including large-tensor
  coverage beyond the old reference cap.
- [x] Typed immediate residual CE opening using the existing CE opening
  verifier.
- [x] Library `NumiSealProver`/`NumiSealVerifier` for current
  immediate-residual multi-lane/multi-aggregate envelopes.
- [x] Checked immediate-residual vectors:
  `numiseal-terminal-single-aggregate-v1.json`,
  `numiseal-terminal-two-aggregate-v1.json`, and
  `numiseal-terminal-two-lane-v1.json`.
- [x] `superneo inspect` and default strict `superneo verify` for
  checked NumiSeal artifacts.
- [x] Product verifier facade hooks for expected context, authorization,
  provenance, replay, byte limits, and audit events.
- [x] Lean hook for the NumiSeal dense sum-check transcript frame order.
- [x] NumiSealZK proof kind `5`, masked residual proof syntax, randomness reuse
  guard, and exact rejection-sampled field mask distribution evidence.
- [x] Typed carry statement, consumer relation, and producer API for accepted
  parent NumiSeal proof envelopes.
- [x] Public `NumiSealProductAPI` for prepared R1CS, one-hot vectors, and
  binary addition workloads, plus `SuperNeoR1CSProgram.proveNumiSealProduct`.
- [x] `superneo prove --seal numiseal` uses the supported product API and emits
  trusted-context, trace/extractor, CTCO, and QROM evidence metadata.
- [x] Product artifacts bind supported frontend outputs through
  `NumiSealProductTrustedContext` instead of vector-only metadata.
- [x] ZK product artifacts emit a simulator-coupling evidence digest in addition
  to the exact field-mask distribution evidence.
- [x] Checked Swift trace/extractor, ZK simulator-coupling, and CTCO/QROM
  instantiation evidence manifests with validators and production-gate coverage.
- [x] Local product controls accept recursive carry chains when each recursive
  parent has prior replay-ledger acceptance and matching signed provenance.

## Not Done

- [ ] Hosted product recursive carry promotion.
  Parent-child product carry now uses `typed-required` when a verified recursive
  parent is supplied, and local product controls bind the carry replay
  roots into SQLite replay identity and audit records while requiring signed
  parent provenance, prior parent replay acceptance, and single-use local carry
  replay binding. Local chains can continue through previously accepted
  recursive parents. Done when that checked handoff is deployed as the selected
  hosted production-depth replay policy with loss accounting.

- [ ] `NumiSealZK` production privacy promotion.
  Product proving now defaults to masked NumiSealZK. Done when product-sized
  hardware benchmark evidence and side-channel evidence are recorded for a
  stronger production privacy claim. The proof-level simulator coupling
  evidence is now recorded with `epsilon_zk_sim = 0` under declared leakage.

- [ ] Deployed product operations.
  Done when hosted trusted context storage, key distribution/rotation rollout,
  tenant authz, hosted audit retention, revocation distribution, incident
  response, signed releases, and publication protection exist. Local signed
  context/provenance/revocation feed, SQLite replay, hash-chained audit export, and
  product-ops readiness status are implemented.

- [ ] NumiSeal-specific end-to-end product formalization promotion.
  Done when release review accepts the pinned Swift trace/extractor evidence,
  hosted selected-depth typed carry evidence, CTCO/QROM evidence, and numeric
  selected total-loss budget. The proof-level simulator-coupling evidence is
  already pinned under the declared leakage model.

- [ ] Self-owned cryptographic and implementation review.
  Done when review evidence is recorded in the repository and findings are
  resolved or explicitly accepted.

- [ ] Side-channel certification.
  Done when the relevant Swift/LLVM/CPU/allocation/Metal behavior is reviewed
  or the deployment threat model explicitly excludes those observations.

## Safe Product Wording

Use:

> NumiSeal generates and verifies checked immediate-residual product artifacts
> through explicit kind `4`/kind `5` policy paths. Recursive-by-default carry,
> deployed product operations, selected-depth theorem promotion, and self-owned
> review closure remain.

Do not say:

> NumiSeal is a production zero-knowledge product.
