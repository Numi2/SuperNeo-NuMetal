# Audit and Blocker Narrowing, 2026-04-16

Formal status: conditional protocol formalization.

This note records the local audit pass covering side-channel posture, product
integration requirements, formal blocker status, and lattice-estimator evidence.
It is a repository-grounded engineering audit, not an independent cryptographic
security audit or production approval.

Update: the repository now includes an executable NumiSeal product-integration
facade recorded in `Docs/ProductIntegrationLayer-2026-04-16.md`. The product
blocker is narrowed from "no local integration contract" to "deployed durable
implementations of the integration protocols still required."

## Commands Run

```sh
Scripts/production-gate.sh
brew install --cask sage
sage --version
Scripts/reproduce-lattice-estimator.sh --full --pinned lattice-estimator-results/superneo-goldilocks-phi81.json
Scripts/validate-lattice-estimator-artifact.py --expect-status ran --expect-latest-status absent --require-claimed-security lattice-estimator-results/superneo-goldilocks-phi81.json
command -v sage
docker --version
```

Results:

- `Scripts/production-gate.sh` passed locally.
- The gate covered release build, debug XCTest, release XCTest, schemas,
  checked vectors, NumiSeal CLI adversarial validation, lattice-estimator
  dry-run validation, Lean build, Lean executable checks, formal manifest
  validation, Swift/Lean Ext2 and CE vector bridges, and release CLI smoke
  tests.
- The Homebrew cask installer requires an interactive sudo password for the
  package step in this shell. The same cask image was fetched, mounted, copied
  to `~/Applications/SageMath-10-8.app`, and exposed through
  `~/.local/bin/sage` plus `/opt/homebrew/bin/sage`.
- `sage --version` reports `SageMath version 10.8, Release Date: 2025-12-18`.
- Full pinned Sage-backed estimator execution ran and wrote
  `lattice-estimator-results/superneo-goldilocks-phi81.json`.
- The generated estimator artifact validated with pinned status `ran`, no
  latest-upstream lane, and the claimed-security threshold required.
- Docker is installed, but Docker server access was not available from this
  shell during the audit.

## Qualification Result

The repository clears its current research/integration gate. It still does not
clear production-security language because several no-go items are external,
formal, or product-specific rather than local test-gate items.

Production-security wording remains blocked by:

1. independent cryptographic and implementation audit,
2. formal constant-time or side-channel certification,
3. deployed product implementations for trusted context, provenance, replay,
   access control, persistence, and audit logging,
4. completion or explicit theorem-scope narrowing for the three remaining
   formal blocker groups,
5. release signing plus hosted branch-protection enforcement, and
6. broader benchmark evidence before cross-generation performance claims.

## Side-Channel Review

The repository has a real high-assurance execution mode, but it is correctly
described as constant-work hardening rather than constant-time certification.

Covered strengths:

- CLI proof generation and checked NumiSeal vector generation request
  `.highAssurance` for secret-bearing prover work.
- `.highAssurance` disables secret-bearing Metal acceleration through
  `SuperNeoExecutionPolicy.usesMetalAcceleration(for:)`.
- Constant-work CPU paths are present for the largest witness-dependent
  commitment and transformed-evaluation loops.
- CPU-redundant Metal policy recomputes covered Metal outputs on CPU before
  accepting them.
- CE opening proof generation uses `SecRandomCopyBytes` when the public API is
  called without deterministic test seeds.

Residual side-channel blockers:

- `GoldilocksField` arithmetic contains data-dependent branches in modular
  addition, subtraction, negation, reduction, exponentiation, and inversion.
  These branches are below the current constant-work loop hardening layer and
  block any formal constant-time claim for Swift, LLVM, or Apple CPUs.
- Swift array allocation, copy-on-write behavior, ARC, and allocator/cache
  behavior are not modeled or constrained. Even fixed loop schedules do not
  prove stable memory-observation behavior.
- Optimized CPU paths intentionally use sparse skips and small-coefficient
  specialization. They are valid for benchmarks and public verification, not
  for co-resident side-channel adversaries observing secret witness work.
- Metal remains a performance accelerator only. `.highAssurance` avoids
  secret-bearing GPU proving work, but GPU timing, cache, driver, and power
  side channels are not certified.
- No dudect-style timing corpus, hardware counter study, or compiler-output
  review is present. Adding those would narrow empirical leakage risk but would
  still not prove constant-time behavior.

Conclusion: the side-channel blocker is narrowed to a precise scope. The
implemented mode removes the most visible witness-dependent zero-skip and GPU
prover hazards, but production side-channel claims require either branchless
field arithmetic plus compiler/hardware review or a narrower deployment threat
model that excludes local observation.

## Product Integration Layer

The repository exposes useful verifier primitives and now has a thin executable
product-integration contract for checked NumiSeal verification. It is not a
complete deployed product layer.

Existing primitives:

- `SuperNeoTerminalProofAcceptancePolicy` binds profile, shape digest,
  statement digest, verifier-key digest, transcript domain, proof kind, and
  optional proof byte size before terminal verification.
- `NumiSealArtifactExpectedContext` lets callers pin NumiSeal key seed,
  verifier key, shape, statement, transcript domain, public-statement root,
  obligation root, lane-summary root, aggregate digests, component root, proof
  transcript digest, and public inputs.
- `superneo verify --require-numiseal` enforces an explicit NumiSeal policy
  gate and rejects legacy terminal policy confusion.
- The production gate tests wrong public inputs, wrong expected pins, proof-kind
  confusion, unknown artifact fields, duplicate JSON keys, schema drift, and
  malformed vector metadata.
- `SuperNeoNumiSealProductVerifier` composes expected-context lookup,
  authorization, provenance verification, replay checking, product byte limits,
  and audit-event recording around `NumiSealArtifactVerifier.verify`.
- The new product facade binds replay identity to expected context, statement
  digest, proof-envelope digest, raw artifact digest, and provenance digest.
- Focused XCTest coverage checks acceptance, audit recording, fail-closed
  authorization, replay rejection, and product byte-limit rejection.

Missing product responsibilities:

- deployed durable expected-context storage,
- trusted key distribution and rotation policy,
- signed artifact provenance roots,
- race-safe replay ledger semantics,
- request authentication, authorization, and tenant isolation,
- persistent verification records,
- structured audit-log transport and retention,
- user-facing error and retry policy,
- incident response and revocation hooks.

Recommended integration contract:

1. Load trusted context from product storage, never from the artifact being
   verified.
2. Authenticate the caller and authorize access to that expected context before
   parsing proof bytes.
3. Check artifact provenance and signature before algebraic verification.
4. Reject proofs exceeding the product byte limit before body parsing.
5. Verify using `SuperNeoTerminalProofAcceptancePolicy` or
   `NumiSealArtifactExpectedContext` with all available pins set.
6. Record replay state only after successful verification and fail closed on
   duplicate product replay keys.
7. Persist a structured audit event with decision, digest pins, proof kind,
   artifact hash, toolchain/release version, and error class.

Conclusion: the product integration blocker is narrowed but not closed for
production. The repository now supplies protocol interfaces and tested in-memory
test doubles for replay/provenance/audit behavior, but production readiness
still requires deployed durable implementations and operational review.

## Formal Blockers

`Docs/FormalStatus.json` still names three completion blockers:

- `superneo-full-probability-composition`
- `swift-goldilocks-ext2-serialization-equivalence`
- `swift-ce-verifier-byte-equivalence`

The production gate validated that those blockers remain planned and that the
current label stays at conditional protocol formalization. Supporting work is
substantial: Goldilocks/Phi81 algebra, Ext2 wire grammar, CE byte grammar,
Swift/Lean Ext2 vectors, Swift/Lean CE vectors, tagged bad-event bookkeeping,
and finite transcript-seed accounting all build and validate.

Remaining closure obligations:

- mechanize executable Swift `GoldilocksExt2` encode/decode behavior rather
  than relying on source-shape validation plus fixtures,
- connect Swift CE proof byte parsing and verifier branches to the Lean
  `TerminalCEVerifierTraceAccepts` predicate, and
- connect the Fiat-Shamir/random-oracle transcript schedule and stage-event
  projections into the final end-to-end probability ledger.

Conclusion: no formal status promotion is justified. The blockers are narrowed
and well specified, but they remain planned until the executable equivalence
and probability-composition theorems exist.

## Lattice Estimator

The dry-run parameter artifact path is healthy and was validated by the
production gate. It records the exact translated SIS tuple and must be treated
as parameter-lock evidence only.

The requested full Sage estimator run completed locally through the installed
SageMath 10.8 command:

```sh
Scripts/reproduce-lattice-estimator.sh --full --pinned lattice-estimator-results/superneo-goldilocks-phi81.json
Scripts/validate-lattice-estimator-artifact.py --expect-status ran --expect-latest-status absent --require-claimed-security lattice-estimator-results/superneo-goldilocks-phi81.json
```

Result:

```text
lattice  :: rop: approx 2^129.1, red: approx 2^129.1, delta: 1.004408, beta: 345, d: 3129, tag: euclidean
```

The artifact records pinned `malb/lattice-estimator` commit
`8d38f52c0bcc46f23d697c9c592bad50df0b124b`, SageMath 10.8, extracted
`minimum_extracted_rop_bits = 129.1`, threshold `129`, and
`threshold_cleared = true`. The latest-upstream monitoring lane was not run and
remains drift-monitoring evidence only.

Conclusion: the full pinned Sage-backed estimator blocker is closed for this
local audit pass. The generated JSON lives under the repository's ignored
`lattice-estimator-results/` scratch-output directory; this tracked note is the
durable audit record unless a release process chooses to archive that generated
artifact separately.

## Blocker Disposition

| Blocker | Disposition |
| --- | --- |
| Independent cryptographic audit | Still open; requires external review. |
| Side-channel review | Narrowed; high-assurance mode is meaningful, constant-time certification remains open. |
| Product integration layer | Executable NumiSeal integration contract added; deployed storage/provenance/replay/access/logging implementations remain open. |
| Formal blocker completion | Not closed; three planned groups remain correctly blocked. |
| Full Sage estimator | Closed for the pinned local lane; SageMath 10.8 ran and the generated artifact validated. |
| Broader benchmarks | Not run in this pass; no new cross-generation performance claim. |
| Release signing and branch protection | Not locally provable; remains hosting/release-infrastructure work. |

## Next Closure Slice

The next local engineering slice with the best risk reduction is to extend the
product-integration facade beyond checked NumiSeal fixtures:

- terminal and compressed-terminal product verifier facade,
- optional signed-artifact provenance format,
- replay-ledger race semantics documented as a store contract, and
- CLI or example wiring that demonstrates loading trusted context from product
  storage rather than from artifacts.

That still would not make the repository production-ready by itself, but it
would reduce the amount of product-specific glue needed around the existing
policy APIs.
