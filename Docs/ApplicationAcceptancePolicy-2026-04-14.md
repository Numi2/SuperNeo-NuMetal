# Application Acceptance Policy, 2026-04-14

This pass adds a reusable terminal-proof acceptance surface for application
integrations. It does not add persistence, replay protection, key distribution,
or a user-facing verification product.

## What changed

- Added `SuperNeoTerminalProofAcceptancePolicy`, which carries the trusted
  profile, shape digest, statement digest, verifier-key digest, and transcript
  domain for a terminal statement.
- Added a direct `publicInput` initializer so applications can derive the exact
  statement digest used by the verifier without manually reconstructing prior CE
  instance metadata.
- Added `ProofKindPolicy`:
  - `.terminalOrCompressed` accepts both complete terminal envelope forms.
  - `.terminalOnly` accepts only local terminal envelopes.
  - `.compressedOnly` accepts only compressed public terminal envelopes.
- Added an optional maximum proof byte count so applications can fail closed on
  oversized proofs before body parsing and terminal verification.
- Added `SuperNeoVerifier.verifyTerminalProofEnvelope(..., policy:)` overloads.
  The verifier parses the envelope header, rejects fold reductions with a
  terminal-required error, validates the trusted context, and dispatches to the
  terminal or compressed-terminal verifier based on the envelope kind.
- Added XCTest coverage that the policy rejects a fold vector, accepts both
  terminal envelope kinds, rejects terminal/compressed proofs under strict
  proof-kind policies, rejects oversized proof bytes, and rejects a terminal
  vector under the wrong trusted statement digest.

## Integration Pattern

Application code should build the policy from trusted state, not from fields
inside an untrusted artifact:

```swift
let policy = SuperNeoTerminalProofAcceptancePolicy(
    publicInput: publicInput,
    verifierKeyDigest: key.verifierKeyDigest,
    proofKindPolicy: .compressedOnly,
    maximumProofByteCount: 4 * 1024 * 1024
)

let result = verifier.verifyTerminalProofEnvelope(
    publicInput: publicInput,
    proofBytes: proofBytes,
    policy: policy
)
```

The proof-kind policy is resource and compatibility policy, not a new protocol
theorem. `terminalLocal` and `compressedPublic` are both terminal acceptance
forms; applications can still reject one form if they need predictable proof
size, public-material handling, or deployment compatibility.

## Boundary

This API removes a common integration footgun: application code no longer needs
to switch on proof-envelope kind and reconstruct terminal contexts manually just
to require terminal acceptance. Callers still own artifact provenance, replay
policy, trusted-key distribution, freshness, storage, UI decisions, proof-byte
transport limits, and any domain-specific statement semantics.

## Validation

Validation for this pass is covered by:

```sh
swift test --disable-swift-testing --filter UsabilitySurfaceTests/testTerminalAcceptancePolicyRejectsFoldAndDispatchesTerminalKinds
Scripts/production-gate.sh
```
