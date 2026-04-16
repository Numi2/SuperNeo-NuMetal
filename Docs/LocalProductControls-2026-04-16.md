# Local Product Controls, 2026-04-16

Formal status: product-control implementation, not a complete production
certification.

This pass adds an offline CLI product-control path for terminal,
compressed-terminal, and NumiSeal terminal verification. It does not add a
hosted verifier service.

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
```

`--context-pack` and `--artifact-provenance` can override the paths embedded in
the operator profile.

## Operator Profile

The operator profile is an OS-user-owned JSON file. It must not be a symlink or
group/world writable. It contains:

- caller ID,
- trusted context issuer key digests,
- optional trusted provenance issuer key digests,
- context-pack path,
- artifact-provenance path,
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
- NumiSeal-specific digests when the context accepts NumiSeal terminal proofs,
- key-rotation metadata, and
- revocation metadata.

Verification fails closed when the context is expired, unsigned by a trusted
issuer key, outside the advertised rotation metadata, revoked, or mismatched
against the artifact.

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
proof kind, context ID, tool version, and release build digest. `product-status`
validates the hash chain and reports the last sequence and digest.

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
model. It does not close Apple signing/notarization, external audits, the formal
promotion blockers, or the dedicated branchless side-channel certification path.
