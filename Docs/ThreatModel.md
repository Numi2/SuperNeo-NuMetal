# Threat Model

SuperNeo NuMetal is a research implementation of the SuperNeo folding protocol
over the `Goldilocks/Phi81(d=54)` profile. The trust model is intentionally
narrow: it describes when verifier acceptance is meaningful for this codebase,
not when an external product should be considered production secure.

## Security Claims In Scope

The implementation is designed to check the following claims:

- A malicious prover cannot make `reduceFold` accept a malformed fold reduction
  without satisfying the verifier checks implemented for PiCCS, PiRLC, and
  PiDEC.
- A fold reduction is not a terminal proof. Accepted fold reductions produce
  output CE claims that still require terminal relation verification.
- A terminal local envelope is accepted only when the fold reduction verifies and
  the CE opening relation verifies for the output claims.
- A compressed public envelope is accepted only when its public statement
  digests, fold proof digest, CE opening proof digest, compression digest, and
  reconstructed terminal CE statement all verify.
- A NumiSeal terminal envelope is accepted only by the NumiSeal-specific policy
  path. The CLI requires `--require-numiseal`, rejects kind `4` under legacy
  terminal policy, reconstructs public NumiSeal obligations and aggregate order
  from checked vector metadata, checks public-statement/aggregate/component
  digest bindings, and dispatches residual openings through `NumiSealVerifier`.
- Public proof bytes are bound to a profile ID, proof kind, CCS shape digest,
  statement digest, verifier-key digest, and transcript domain through the
  envelope header and transcript seed.

These are implementation-level acceptance claims. The underlying cryptographic
argument is the Neo/SuperNeo paper's analysis of SuperNeo as the composition
`PiDEC(PiRLC(PiCCS(...)))`, using interactive reductions and Ajtai
commitments under Module-SIS.

## Assumptions

The trust story depends on the following assumptions:

- **Module-SIS hardness:** Ajtai commitments are binding for the norm-bounded
  openings under the paper's concrete `Goldilocks/Phi81(d=54)` parameter
  analysis.
- **Random-oracle heuristic:** Fiat-Shamir challenges are modeled as random
  oracle outputs. The implementation derives transcript challenges from SHA-256
  over length-framed absorbed data.
- **Canonical serialization:** Verifiers reject non-canonical Goldilocks field
  encodings, unsupported proof kinds, unsupported proof versions, count
  overflows, length mismatches, and trailing bytes.
- **Trusted verifier key material:** The verifier uses the intended Ajtai matrix.
  The code binds the verifier key through `AjtaiCommitmentKey.verifierKeyDigest`;
  applications must still distribute and pin the correct key.
- **Correct verifier implementation:** The verifier executes trusted CPU code
  from this repository and validates the full result before accepting. Metal is
  only an accelerator; callers that treat GPU output as untrusted should use
  `SuperNeoExecutionPolicy.cpuRedundantMetal` or `.highAssurance`.

## Adversaries

The main adversary is a malicious prover that can choose witnesses, public
inputs, prior CE claims, proof bytes, proof envelope headers, verifier-key
digests in untrusted metadata, and transcript-domain metadata supplied outside
the verifier.

The verifier must defend against:

- proof mutation after generation,
- replay against a different CCS shape or statement,
- replay against a different verifier key,
- proof-kind confusion between reduction and terminal verification,
- profile mismatch,
- malformed serialization that tries to trigger over-allocation or trailing-data
  ambiguity,
- stale Metal workspaces tied to a different compiled shape, and
- NumiSeal-specific proof-body mutation, including malformed dense sum-check
  frames, lane/aggregate-policy confusion, public-statement root substitution,
  aggregate digest substitution, component-root substitution, and accidental
  acceptance without the `--require-numiseal` gate.

The tests include adversarial envelope mutation, digest mismatch, profile
mismatch, proof-kind mismatch, non-canonical field encoding, malformed
decomposition output, malformed NumiSeal large-tensor proof-body mutation,
per-shape NumiSeal vector manifest/artifact negatives, and CPU/Metal
differential checks.

## Explicit Non-Goals

The current default optimized repository mode does not claim:

- a production-ready audited cryptographic library,
- formal constant-time execution,
- resistance to a compromised host process or operating system,
- a stable long-term proof format beyond `ProofEnvelopeHeader.version`,
- zero-knowledge for arbitrary application statements,
- a complete SNARK, IVC, or PCD product by itself, or
- a production cryptographic certification of the paper's lattice-estimator
  security numbers.

The `.highAssurance` execution policy removes the largest witness-dependent
zero-skip branches from covered local normalization, commitment, and evaluation
paths, and disables secret-bearing Metal prover work. This is constant-work
hardening, not a formal side-channel proof for Swift, LLVM, CPU
microarchitecture, allocation, timing, or power leakage.

The CE opening proof machinery may hide selected witness data by protocol
construction, but this repository should not be presented as a general
zero-knowledge system until that privacy claim is separately specified, tested,
and reviewed.

The NumiSeal CLI exposure is a verifier/inspection surface for the checked
immediate-residual artifact family. `superneo-numiseal-vectors` remains a
deterministic vector generator and validator, not a production proving product,
and `superneo verify --require-numiseal` is not a claim of recursive, zero
knowledge, or deployment-ready NumiSeal security.

## Randomness Notes

Protocol transcript challenges are deterministic Fiat-Shamir challenges derived
from public transcript state. Ajtai keys can be generated deterministically from
a caller-provided seed, which is useful for reproducible test vectors and
benchmarks.

CE opening proof masking uses a 32-byte system-random seed when the public API is
called without an explicit deterministic seed. This is sufficient for research
experiments on supported platforms, but production use should replace or wrap
that path with an explicitly documented CSPRNG policy and seed provenance.

Checked NumiSeal vectors carry deterministic fold/source/CE seed metadata for
reproducibility. That metadata is a test-vector reproducibility mechanism. A
deployment that accepts third-party NumiSeal artifacts must pin expected key,
shape, statement, transcript-domain, public-statement, obligation-root,
lane-summary-root, aggregate, component-root, proof-transcript, and public-input
context outside the artifact. The shared `NumiSealArtifactVerifier` core is the
library boundary that compares those pins to reconstructed public obligations
and the kind `4` envelope.

## GPU And Metal Boundary

Metal is an accelerator, not a new trust assumption for proof semantics. The
same algebraic objects must verify against the same public transcript. CPU and
Metal paths are differentially tested, and benchmark gates compare outputs where
both paths exist.

A verifier running with `SuperNeoExecutionPolicy.cpuRedundantMetal` recomputes
covered Metal commitment and transformed-evaluation outputs on CPU before using
them. This catches faulty or malicious GPU results in those paths. A compromised
host that can alter CPU execution, inputs, policies, or control flow remains
outside this repository's threat model.
Direct `SuperNeoMetalWorkspace` users should pass `.cpuRedundantMetal` or
`.highAssurance` to get the same boundary checks at the workspace API.

## Responsible Language

Acceptable public wording:

> SuperNeo NuMetal implements the `Goldilocks/Phi81(d=54)` SuperNeo profile and
> is plausibly post-quantum under the Neo/SuperNeo paper's Module-SIS analysis.

Do not say:

> This is a production-secure post-quantum SNARK.

The current artifact is a serious research implementation of a folding engine.
It is not yet a security-audited product.
