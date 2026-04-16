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

## Not Done

- [ ] Public NumiSeal proving/product exposure.
  Done when `superneo prove --seal numiseal` or equivalent product API emits
  schema-valid randomized NumiSeal artifacts, has negative tests, and is
  documented as non-ZK/non-recursive unless those modes are explicitly selected.

- [ ] General statement/frontend integration.
  Done when hand-authored R1CS or the next frontend can create NumiSeal
  obligations and trusted context packs for more than checked identity-style
  fixtures.

- [ ] Recursive carry semantics.
  Done when carry is a typed statement, not raw bytes, and binds parent
  statement/proof digest, recursion level, lane/aggregate scope, transcript
  domain, producer, consumer, vectors, tests, and formal relation.

- [ ] `NumiSealZK`.
  Done when `Docs/NumiSealZKDesign.md` defines the privacy claim, leakage list,
  simulator target, masking design, randomness policy, ZK proof kind or policy
  flag, fail-closed randomness-reuse tests, and side-channel review scope.

- [ ] Deployed product operations.
  Done when trusted context storage, key distribution/rotation, signed
  provenance roots, race-safe replay, tenant authz, audit retention, revocation,
  incident response, signed releases, and hosted branch protection exist.

- [ ] NumiSeal-specific end-to-end product formalization.
  Done when the NumiSeal public statement, aggregation, scalarization,
  digit-language, residual-opening, generated-artifact, and carry/ZK relations
  have scoped formal claims and conformance vectors.

- [ ] Self-owned cryptographic and implementation review.
  Done when review evidence is recorded in the repository and findings are
  resolved or explicitly accepted.

- [ ] Side-channel certification.
  Done when the relevant Swift/LLVM/CPU/allocation/Metal behavior is reviewed
  or the deployment threat model explicitly excludes those observations.

## Safe Product Wording

Use:

> NumiSeal verifies checked immediate-residual artifacts through an explicit
> kind `4` policy path. Public proving, recursive carry, zero knowledge,
> deployed product operations, NumiSeal-specific product formalization, and
> self-owned review closure remain.

Do not say:

> NumiSeal is a production zero-knowledge product.
