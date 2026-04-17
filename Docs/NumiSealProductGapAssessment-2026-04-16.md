# NumiSeal Product Gap Assessment, 2026-04-16

Keep this note short. It exists so future agents can see what remains without
loading older long-form roadmap notes.

## Verdict

Mostly true: NumiSeal has production-facing inspection and verification for
checked immediate-residual artifacts. It is not a complete production NumiSeal
product.

Correction: repository-level SuperNeo formal status is completed for the
corrected model. What remains is NumiSeal-specific product formalization.

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

## Remaining Work

- [ ] Public proving/product API: expose NumiSeal artifact generation outside
  deterministic vector tooling.
- [ ] General frontend: create NumiSeal obligations from real supported
  frontend outputs and trusted context packs.
- [ ] Recursive carry: local product controls now verify a depth-1 parent edge,
  require signed parent provenance and prior parent replay acceptance, and bind
  recursive carry replay roots into SQLite/audit with single-use local carry
  consumption; extend this to the selected production depth with hosted replay
  policy and formal loss accounting.
- [ ] ZK: add simulator coupling evidence beyond the exact field-mask
  distribution lemma, product-sized hardware benchmark evidence, and
  side-channel review before changing product defaults.
- [ ] Product operations: hosted context storage, deployed key distribution,
  tenant authz, hosted audit retention, hosted revocation feed distribution, and
  signed releases.
- [ ] NumiSeal-specific formalization: promote the checked end-to-end theorem
  scope with concrete Swift extractor, typed carry vector, simulator, and QROM
  evidence.
- [ ] Self-owned review: cryptographic review, implementation review, and
  side-channel assessment recorded in repository evidence.

## Safe Wording

Use:

> NumiSeal currently verifies checked immediate-residual artifacts. It is not
> yet a public proving, recursive-by-default, zero-knowledge-by-default, or
> deployed production product.
