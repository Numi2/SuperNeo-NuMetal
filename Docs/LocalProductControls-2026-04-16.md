# Local Product Controls, 2026-04-16

Formal status: product-control implementation with optional signed NumiSealZK
side-channel certificate metadata, not a deployment certification.

This pass adds an offline CLI product-control path for terminal,
compressed-terminal, NumiSeal terminal, and NumiSealZK verification. It does not
add a hosted verifier service.

## Commands

Product verification uses signed trust material and durable local state:

```sh
superneo product-init-storage --operator-profile profile.json

superneo verify \
  --product \
  --operator-profile profile.json \
  proof.json

superneo product-status \
  --operator-profile profile.json

superneo product-status \
  --operator-profile profile.json \
  --revocation-feed revocations.json \
  --format json

superneo product-export-audit \
  --operator-profile profile.json \
  --revocation-feed revocations.json \
  --output audit-export.json
```

`--context-pack`, `--artifact-provenance`, `--revocation-feed`, and
`--side-channel-certificate` can override the paths embedded in the operator
profile for a single run. The operator profile still carries the required
context, provenance, side-channel, and revocation trust roots explicitly.

`product-status --format json` emits `SuperNeoProductOperationsStatus`, the
canonical local product-ops readiness document. The text mode includes the same
operations readiness, auditRetentionPolicy, retryPolicy, and per-check
remediation lines for operator use.

## Operator Profile

The operator profile is an OS-user-owned JSON file. It must not be a symlink or
group/world writable. It contains:

- caller ID,
- trusted context issuer key digests,
- trusted provenance issuer key digests,
- trusted side-channel issuer key digests,
- trusted revocation issuer key digests,
- context-pack path,
- artifact-provenance path,
- optional side-channel certificate path,
- signed revocation feed path,
- SQLite replay database path,
- JSONL audit log path, and
- release build digest.

Context, provenance, side-channel, and revocation issuer key digest lists are
explicit profile fields. The loader no longer falls back from one trust root to
another; private operator configs must name every accepted issuer class.

The replay database and audit log must already exist and pass the same ownership
and write-permission checks before verification runs. Use `product-init-storage`
to create the SQLite schema and audit-log file with user-only permissions.

## Trusted Context Pack

The trusted context pack is signed JSON. The signature covers the canonical
sorted-key JSON encoding of the payload and is verified before artifact parsing.
The initial signature algorithm is Ed25519.

The payload binds:

- context ID and issuer,
- validity window,
- expected verifier key, shape, statement, and transcript-domain digests,
- accepted proof kinds,
- artifact and proof-envelope byte limits,
- allowed workloads,
- optional expected public inputs,
- release build digest,
- NumiSeal-specific public roots and transcript digests when the context accepts
  NumiSeal terminal or NumiSealZK proofs,
- NumiSealZK policy when the context accepts `numiseal-zk`: accepted ZK modes,
  seal modes, Metal modes, execution policies, leakage digests, proof body
  versions, and masked residual statement versions,
- key-rotation metadata, and
- embedded revocation metadata.

Verification fails closed when the context is expired, unsigned by a trusted
issuer key, outside the advertised rotation metadata, revoked, or mismatched
against the artifact.

## Signed Revocation Feed

The signed revocation feed is separate from the trusted context pack so urgent
revocations can be distributed without reissuing the full context. The feed is
signed JSON and binds:

- feed ID and issuer,
- context ID,
- release build digest,
- monotonic sequence,
- issue and expiry timestamps,
- revoked context IDs,
- revoked artifact digests,
- revoked proof-envelope digests, and
- revoked provenance digests.

Product controls require a revocation feed path in the operator profile. The
`--revocation-feed` override may select a different signed feed for a run, but
the profile still has to declare the revocation-feed surface and trust root.
The verifier checks feed signature, file
permissions, context binding, release binding, sequence positivity, validity
window, and freshness relative to embedded context revocation metadata.

The effective revocation set is the union of embedded context revocation and the
signed revocation feed. Every product verification checks artifact,
proof-envelope, and provenance digests against that effective set before
acceptance. Audit records include the revocation feed digest used for the
decision.

## NumiSealZK Side-Channel Certificate

`numiseal-zk` product contexts fail closed unless they include explicit
`numiSealZK` policy. Signed side-channel certificates are optional
release-evidence metadata: if supplied, the verifier checks their signature,
validity window, and artifact bindings; if absent, product
verification continues under the normal proof, context, leakage-digest, and
provenance checks.

The side-channel certificate is signed JSON. Its payload binds:

- certificate ID, issuer, context ID, and release build digest,
- certified level: `correctness-only`, `constant-trace-reviewed`, or
  `production-side-channel-cleared`,
- proof kind, seal mode, ZK mode, Metal mode, and execution policy,
- declared leakage digest,
- ZK proof body and masked residual statement versions,
- Metal workspace feature digest,
- reviewed kernel and stage names,
- evidence digests and optional benchmark report digest,
- issue and expiry timestamps.

Verification rejects a supplied certificate if its signature is untrusted, file
permissions are unsafe, validity window is wrong, or any context, release,
proof-policy, leakage, version, or Metal workspace binding differs from the
artifact. Certificates remain out-of-band and do not increase proof size.

## Provenance Manifest

The artifact provenance manifest is also signed JSON. It binds:

- artifact digest,
- proof-envelope digest,
- context ID,
- statement digest,
- release build digest, and
- issuer timestamp.

The replay identity is:

- context ID,
- statement digest,
- proof-envelope digest,
- artifact digest, and
- provenance digest.

Accepted identities are inserted into SQLite only after the algebraic verifier
accepts. The table has a primary identity digest and a unique composite replay
constraint.

## Audit Log

The audit log is append-only JSONL at the CLI layer. Each record has a monotonic
sequence number, previous-record digest, decision, error class, artifact digest,
optional side-channel certificate digest, proof kind, context ID, tool version,
and release build digest. `product-status` validates the hash chain and reports
the last sequence and digest. `product-export-audit` validates that same chain
before writing a sorted-key JSON snapshot with the active context digest,
issuer-key digest, revocation feed digest, accepted replay count, audit-log
digest, chain status, and records. `product-export-audit` also embeds the active
`operationsStatus` so exports preserve the operator lifecycle state that was
current at export time.

## Incident Response

Rollback:

1. Issue a new signed revocation feed with the compromised context ID, artifact
   digest, proof-envelope digest, or provenance digest listed.
2. Distribute the revocation feed and stop using older operator profiles that
   point at stale feed files.
3. Run `product-status` to confirm the active context and audit chain.
4. Run `product-export-audit --output audit-export.json` to preserve the
   hash-chained local audit state before restarting acceptance.
5. Re-run verification only with a fresh provenance manifest and non-revoked
   artifact.

Key rotation:

1. Add the current key to `previousIssuerKeyDigestsHex`.
2. Publish a new current issuer key digest in the operator profile trust list and
   in `keyRotation.currentIssuerKeyDigestHex`.
3. Sign the next context pack with the new Ed25519 key.
4. Remove the old key from operator profiles after the rotation window closes.

## Remaining Blockers

This closes the local product-control substrate for the CLI/offline verifier
model and keeps signed side-channel evidence available as optional release
metadata for a reviewed NumiSealZK side-channel lane. It does not close Apple
signing/notarization or the remaining evidence-production
work for each production hardware profile.
