# Audit and Blocker Narrowing, 2026-04-16

Formal status: completed formal protocol theorem.

This note records the local audit pass covering side-channel posture, product
integration requirements, formal blocker status, and lattice-estimator evidence.
It is a repository-grounded engineering review record, not production approval.

Update: the repository now includes an executable NumiSeal product-integration
facade recorded in `Docs/ProductIntegrationLayer-2026-04-16.md`. The product
blocker is narrowed from "no local integration contract" to "deployed durable
implementations of the integration protocols still required."

## Commands Run

```sh
Scripts/production-gate.sh
Scripts/generate-constant-time-release-evidence.py --skip-build
brew install --cask sage
sage --version
Scripts/reproduce-lattice-estimator.sh --full --pinned lattice-estimator-results/superneo-goldilocks-phi81.json
Scripts/validate-lattice-estimator-artifact.py --expect-status ran --expect-latest-status absent --require-claimed-security lattice-estimator-results/superneo-goldilocks-phi81.json
command -v sage
docker --version
```

Results:

- `Scripts/production-gate.sh` passed locally.
- `Scripts/generate-constant-time-release-evidence.py --skip-build` generated
  and pinned `Evidence/ConstantTime/swift-llvm-metal-v1/manifest.json`, including
  Metal AIR/metallib artifacts, a runtime allocation/COW static review, and
  CPU/GPU local observation corpora.
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

The repository clears its current repository-local production-security
promotion gate for the bounded selected-depth theorem surface. External
deployment language remains separate because hosted review, broader
hardware/profile coverage, and public distribution choices are not
repository-local test-gate items.

External deployment wording remains conditioned on:

1. self-owned cryptographic and implementation review record,
2. formal constant-time or side-channel certification,
3. deployed product implementations for trusted context, provenance, replay,
   access control, persistence, and audit logging,
4. instantiated product/QROM evidence records for the selected split-oracle
   CTCO or Merkle-straightline compiler family, plus release-grade Swift
   trace/extractor equivalence evidence,
5. release signing plus publication-protection enforcement, and
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

- `Formal/SuperNeoFormal/ConstantTime.lean`,
  `TestVectors/constant-time-scope-v1.json`, and
  `Scripts/validate-constant-time-scope.py` now provide a conditional
  source/formal trace model for checked Swift Goldilocks common arithmetic,
  Metal Goldilocks common arithmetic, and the secret-bearing NumiSealZK Metal
  kernel slice.
- `TestVectors/constant-time-lowering-evidence-v1.json` and
  `Scripts/validate-constant-time-lowering-evidence.py` now provide the
  Swift/LLVM/Metal lowering proof contract: every checked source region is tied
  to required compiler, runtime, and hardware-observation evidence before
  production constant-time language can be enabled.
- `Evidence/ConstantTime/swift-llvm-metal-v1/manifest.json` now pins the local
  release evidence for this contract: Metal AIR, linked metallib, a Metal
  generation report, Swift runtime allocation/COW static review, NumiSealZK CPU
  smoke timing, and direct Metal NumiSeal kernel observation with CPU reference
  equality for every observed operation.
- `GoldilocksField` now uses mask-based canonicalization for initialization,
  addition, subtraction, negation, multiplication reduction, and fixed-width
  exponentiation selection, removing the most common source-level arithmetic
  branches. Inversion still retains a zero check before the fixed exponent path,
  and the Swift optimized SIL/LLVM/assembly lowering evidence has not yet been
  recorded as a release artifact.
- Swift array allocation, copy-on-write behavior, ARC, and allocator/cache
  behavior are modeled as explicit proof obligations in the lowering evidence
  contract. The local scoped allocation/COW source review is pinned; runtime and
  hardware counter evidence remains broader production-promotion work.
- Optimized CPU paths intentionally use sparse skips and small-coefficient
  specialization. They are valid for benchmarks and public verification, not
  for co-resident side-channel adversaries observing secret witness work.
- Metal remains a performance accelerator only. `.highAssurance` avoids
  secret-bearing GPU proving work, but GPU timing, cache, driver, and power
  side channels are not certified.
- Local CPU/GPU observation corpora are now pinned, but no hardware counter
  study, power/contention study, broader Apple GPU-family corpus, or Swift
  emitted SIL/LLVM/assembly review artifact is present yet. The required
  artifact classes are machine-checked by the lowering evidence manifest.

Conclusion: the side-channel blocker is narrowed to a precise scope. The
implemented mode removes the most visible witness-dependent zero-skip and GPU
prover hazards and narrows common field arithmetic, but production side-channel
claims require inversion-entry treatment plus compiler and hardware review, or a
narrower deployment threat model that excludes local observation.

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
- `superneo verify` enforces strict NumiSeal handling by artifact kind and
  rejects legacy terminal policy confusion.
- The production gate tests wrong public inputs, wrong expected pins, proof-kind
  confusion, unknown artifact fields, duplicate JSON keys, schema drift, and
  malformed vector metadata.
- `SuperNeoNumiSealProductVerifier` composes expected-context lookup,
  authorization, provenance verification, replay checking, product byte limits,
  and audit-event recording around `NumiSealArtifactVerifier.verify`.
- The new product facade binds replay identity to expected context, statement
  digest, proof-envelope digest, raw artifact digest, and provenance digest.
- Local product controls now require explicit issuer trust roots and a signed
  revocation feed; audit events bind the revocation feed digest used for the
  decision.
- Focused XCTest coverage checks acceptance, audit recording, fail-closed
  authorization, replay rejection, and product byte-limit rejection.

Missing product responsibilities:

- deployed durable expected-context storage,
- trusted key distribution and rotation policy,
- signed artifact provenance roots,
- race-safe replay ledger semantics,
- request authentication, authorization, and tenant isolation,
- persistent verification records,
- structured hosted audit-log transport and retention,
- hosted user-facing error and retry policy,
- hosted incident response and revocation feed distribution.

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

`Docs/FormalStatus.json` now records the completed formal protocol theorem and
keeps the former theorem-critical integration IDs as closed promotion gates:

- `terminal-ce-localization-instantiation`
- `pirlc-crt-finite-soundness-completion`

The formal-status validator rejects documentation that claims a completed
theorem label unless those integrations are closed. Supporting work includes
Goldilocks/Phi81 algebra, Ext2 wire grammar, CE byte grammar, Swift/Lean Ext2
vectors, Swift/Lean CE vectors, tagged bad-event bookkeeping, finite
transcript-seed accounting, Swift-facing byte equivalence declarations, and CE
verifier-trace bridging. The terminal CE and PiRLC hard-math surfaces now have
checked evidence-package constructors: terminal slot-seed evidence yields the
Swift-round bad-seed budget and now lifts to the full ternary challenge-tape
seed model with the exact `3^(roundCount - 1)` per-slot fiber factor; the Swift
response-tag trace supplies the full tape and verifier-branch match. PiRLC CRT
component evidence yields the conservative delta-collision
certificate with the `5^27` concrete upper-half coefficient fiber factor, and
the checked linear-defect route derives that evidence from accepted folded
claims. Concrete folded-claim observations cover commitment, public-input, and
evaluation coordinates, and finite observation-family accounting now unions the
selected-coordinate bad seeds with an explicit family-cardinality multiplier.
The full public-field family is instantiated with the concrete
`(rows + publicCount + evalCount)` multiplier, and the selected
public-fields-zero relation now has a direct finite-soundness certificate.

Conclusion: the formal status is now narrower and validated by checked Lean
declarations plus fail-closed validator mutation tests. This does not close the
separate independent-audit, side-channel, product-integration, benchmark, or
release infrastructure blockers.

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
| Cryptographic and implementation review record | Still open; owned in-repo as release evidence. |
| Side-channel review | Narrowed; high-assurance mode is meaningful, source/formal plus Swift/LLVM/Metal lowering proof contracts exist, local Metal/runtime/CPU/GPU release evidence is pinned, and broader compiler/hardware evidence remains required before production CT language. |
| Product integration layer | Executable NumiSeal integration contract added; deployed storage/provenance/replay/access/logging implementations remain open. |
| Formal blocker completion | Promoted to completed formal protocol theorem for the finite model; external deployment operations remain separate. |
| Full Sage estimator | Closed for the pinned local lane; SageMath 10.8 ran and the generated artifact validated. |
| Broader benchmarks | Not run in this pass; no new cross-generation performance claim. |
| Release signing and publication protection | Not locally provable; remains release-infrastructure work. |

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
