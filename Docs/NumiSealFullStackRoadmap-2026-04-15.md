# NumiSeal Full Stack Roadmap - 2026-04-15

Keep this file short. Completed implementation details belong in code, tests,
and byte-format docs. Future agents should update the unchecked items when the
work is actually merged and validated.

## Current Status

NumiSeal has a production-facing inspection and verification surface for checked
immediate-residual artifacts. It is not a complete production NumiSeal product.

Formal wording: the corrected SuperNeo formal protocol theorem label is
completed. NumiSeal-specific product claims remain scoped to the checklist
below.

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
- [x] `superneo inspect` and opt-in `superneo verify --require-numiseal` for
  checked NumiSeal artifacts.
- [x] Product verifier facade hooks for expected context, authorization,
  provenance, replay, byte limits, and audit events.
- [x] Lean hook for the NumiSeal dense sum-check transcript frame order.
- [x] NumiSealZK proof kind `5`, masked residual proof syntax, randomness reuse
  guard, and exact rejection-sampled field mask distribution evidence.
- [x] Typed carry statement, consumer relation, and producer API for accepted
  parent NumiSeal proof envelopes.

## Not Done

- [ ] Public NumiSeal proving/product exposure.
  Done when `superneo prove --seal numiseal` or equivalent product API emits
  schema-valid randomized NumiSeal artifacts, has negative tests, and is
  documented as non-ZK/non-recursive unless those modes are explicitly selected.

- [ ] General statement/frontend integration.
  Done when hand-authored R1CS or the next frontend can create NumiSeal
  obligations and trusted context packs for more than checked identity-style
  fixtures.

- [ ] Product recursive carry promotion.
  Done when typed carry producer/consumer semantics are wired into product
  replay policy, product vectors, and default product carry modes.

- [ ] `NumiSealZK` production privacy promotion.
  Done when simulator coupling evidence beyond the exact field-mask
  distribution lemma, product-sized hardware benchmark evidence, and
  side-channel evidence are recorded before product defaults change.

- [ ] Deployed product operations.
  Done when hosted trusted context storage, key distribution/rotation rollout,
  tenant authz, hosted audit retention, revocation distribution, incident
  response, signed releases, and hosted branch protection exist. Local signed
  context/provenance/revocation feed, SQLite replay, hash-chained audit export, and
  product-ops readiness status are implemented.

- [ ] NumiSeal-specific end-to-end product formalization promotion.
  Done when the checked end-to-end theorem scope has concrete Swift extractor,
  typed carry vector, simulator, and QROM evidence sufficient for production
  theorem language.

- [ ] Self-owned cryptographic and implementation review.
  Done when review evidence is recorded in the repository and findings are
  resolved or explicitly accepted.

- [ ] Side-channel certification.
  Done when the relevant Swift/LLVM/CPU/allocation/Metal behavior is reviewed
  or the deployment threat model explicitly excludes those observations.

## Safe Product Wording

Use:

> NumiSeal verifies checked immediate-residual artifacts through an explicit
> kind `4` policy path. Public proving, recursive-by-default carry,
> zero-knowledge-by-default privacy, deployed product operations,
> NumiSeal-specific product formalization promotion, and self-owned review
> closure remain.

Do not say:

> NumiSeal is a production zero-knowledge product.
