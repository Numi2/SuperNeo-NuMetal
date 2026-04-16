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
- [x] `NumiSealProver`/`NumiSealVerifier` library APIs exist for the current
  immediate-residual path.

## Remaining Work

- [ ] Public proving/product API: expose NumiSeal artifact generation outside
  deterministic vector tooling.
- [ ] General frontend: create NumiSeal obligations from real supported
  frontend outputs and trusted context packs.
- [ ] Recursive carry: replace raw optional carry bytes with typed carry
  statement, producer/consumer, replay rules, vectors, tests, and formal claim.
- [ ] ZK: create `NumiSealZK` design, proof kind/policy, masking, simulator
  story, randomness policy, tests, and side-channel review.
- [ ] Product operations: durable context storage, key rotation, signed
  provenance, race-safe replay, tenant authz, audit retention, revocation, and
  signed releases.
- [ ] NumiSeal-specific formalization: immediate-residual product theorem first,
  then separate carry and ZK theorem scope.
- [ ] Self-owned review: cryptographic review, implementation review, and
  side-channel assessment recorded in repository evidence.

## Safe Wording

Use:

> NumiSeal currently verifies checked immediate-residual artifacts. It is not
> yet a public proving, recursive, zero-knowledge-by-default, or deployed
> production product.
