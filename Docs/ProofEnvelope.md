# Proof Envelope Policy

This note records the repository-facing proof-envelope policy for checked
SuperNeo and NumiSeal artifacts.

## Version

The current public proof envelope header version is `4`.

The header binds:

- magic bytes,
- version,
- profile identifier,
- proof-envelope kind,
- shape digest,
- statement digest,
- verifier-key digest,
- transcript-domain digest, and
- body length.

The serialized header is 141 bytes. The Fiat-Shamir transcript-binding prefix
is the 137-byte prefix ending at `transcriptDomain`; `bodyLength` is enforced by
the parser before proof verification but is not part of the transcript seed
payload.

## Proof Kinds

The current envelope kinds are:

- `1`: fold reduction.
- `2`: terminal local proof.
- `3`: compressed public terminal proof.
- `4`: NumiSeal terminal artifact.
- `5`: NumiSeal ZK artifact.

## Status

The envelope policy prevents context confusion for parser and transcript
binding. It is not a production cryptographic security claim by itself. QROM and
product-security claims remain governed by the product evidence manifests and
the formal status manifest.
