# NumiSeal CLI Exposure - 2026-04-16

Scope: production `superneo` inspection and verification for checked NumiSeal
terminal vector artifacts.

## What Changed

- `superneo inspect` recognizes kind `4` NumiSeal terminal vector artifacts,
  parses the envelope, and reports the NumiSeal public statement digest,
  obligation root, lane-summary root, aggregate digests, component digest root,
  proof transcript digest, policy limits, and header transcript domain.
- `superneo verify` now delegates NumiSeal artifacts to the shared
  `NumiSealArtifactVerifier` core, which reconstructs the public obligations and
  aggregate plan from artifact metadata, checks the NumiSeal public statement and
  proof-body digest bindings, compares caller-owned trust pins, and dispatches
  through `NumiSealVerifier` with the immediate residual CE opening policy.
- `--require-numiseal` remains accepted as a compatibility no-op, and
  `--require-terminal` remains limited to legacy terminal-local and
  compressed-public envelopes.
- Strict NumiSeal verifier context can be pinned with transcript-domain,
  public-statement, obligation-root, lane-summary-root, aggregate,
  component-root, proof-transcript, public-input, shape, statement, and
  verifier-key digest options.
- `Scripts/production-gate.sh` now exercises `superneo inspect`, default strict
  single-aggregate verification, broad two-aggregate/two-lane verification, and
  a direct production CLI negative matrix for legacy terminal policy, wrong
  pins, wrong public input, and proof-kind/header mismatch.
- `superneo prove --seal numiseal` now routes through
  `NumiSealProductAPI.provePreparedR1CS`, so CLI product artifacts and Swift API
  product artifacts share the same trusted-context, trace-extractor, and CTCO
  evidence metadata path.

## Security Boundary

This is verifier and local proving exposure for the checked immediate-residual
artifact family. `superneo-numiseal-vectors` remains test-vector tooling, while
`superneo prove --seal numiseal` and `NumiSealProductAPI` are the supported
local product artifact-generation surfaces. Product proving defaults to
`masked-digit-tensor-v1`; pass `--numiseal-zk-mode none` for a non-ZK terminal
artifact.
External callers still need policy-owned expected context outside the artifact
before treating CLI acceptance as an authorization decision, and production
security language still requires the remaining product/QROM, ZK, operations,
review, and side-channel evidence.
