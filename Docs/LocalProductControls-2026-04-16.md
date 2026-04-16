# Local Product Controls, 2026-04-16

Formal status: product-control implementation with signed NumiSealZK
side-channel certificate gating, not a third-party production certification.

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
  --side-channel-certificate numiseal-zk-side-channel.json \
  proof.json

superneo product-status \
  --operator-profile profile.json \
  --side-channel-certificate numiseal-zk-side-channel.json
```

`--context-pack`, `--artifact-provenance`, and
`--side-channel-certificate` can override the paths embedded in the operator
profile.

## Operator Profile

The operator profile is an OS-user-owned JSON file. It must not be a symlink or
group/world writable. It contains:

- caller ID,
- trusted context issuer key digests,
- optional trusted provenance issuer key digests,
- optional trusted side-channel issuer key digests,
- context-pack path,
- artifact-provenance path,
- optional side-channel certificate path,
- SQLite replay database path,
- JSONL audit log path, and
- release build digest.

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
  versions, masked residual statement versions, required side-channel level,
  optional required side-channel certificate digest, and CPU-oracle policy,
- key-rotation metadata, and
- revocation metadata.

Verification fails closed when the context is expired, unsigned by a trusted
issuer key, outside the advertised rotation metadata, revoked, or mismatched
against the artifact.

## NumiSealZK Side-Channel Certificate

`numiseal-zk` product contexts fail closed unless they include explicit
`numiSealZK` policy. A policy can require a signed side-channel certificate,
either by raising `requiredSideChannelLevel` above `correctness-only`, by
pinning `requiredSideChannelCertificateDigestHex`, or by accepting a
secret-bearing Metal mode.

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

Verification rejects a certificate if its signature is untrusted, file
permissions are unsafe, validity window is wrong, digest is not the one pinned
by the trusted context, certified level is too low, or any proof-policy/leakage
binding differs from the artifact. This lets first-party release engineering
unblock a production NumiSealZK Metal lane only by issuing a reviewed,
release-bound certificate.

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
the last sequence and digest.

## Incident Response

Rollback:

1. Issue a new context pack with the compromised context ID or artifact digest
   listed in revocation metadata.
2. Distribute the context pack and stop using older operator profiles that point
   at the revoked pack.
3. Run `product-status` to confirm the active context and audit chain.
4. Re-run verification only with a fresh provenance manifest and non-revoked
   artifact.

Key rotation:

1. Add the current key to `previousIssuerKeyDigestsHex`.
2. Publish a new current issuer key digest in the operator profile trust list and
   in `keyRotation.currentIssuerKeyDigestHex`.
3. Sign the next context pack with the new Ed25519 key.
4. Remove the old key from operator profiles after the rotation window closes.

## Remaining Blockers

This closes the local product-control substrate for the CLI/offline verifier
model and adds the signed certificate gate needed to promote a reviewed
NumiSealZK side-channel lane. It does not close Apple signing/notarization,
external audits, or the remaining evidence-production work for each production
hardware profile.
