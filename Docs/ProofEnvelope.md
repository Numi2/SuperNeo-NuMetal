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

The serialized header is 141 bytes. Legacy non-product transcript binding uses
the 137-byte prefix ending at `transcriptDomain`; `bodyLength` is enforced by
the parser before proof verification but is not part of that transcript seed
payload.

Product NumiSeal acceptance does not trust artifact-selected transcript seeds.
The product route derives the source-fold challenge and terminal transcript
domain from the caller-supplied `SuperNeoQROChallenge`, records the QRO
challenge digest in artifact v2 metadata, and accepts only the product v2
artifact family through the product CLI.

## Proof Kinds

The current envelope kinds are:

- `1`: fold reduction.
- `2`: terminal local proof.
- `3`: compressed public terminal proof.
- `4`: NumiSeal terminal artifact.
- `5`: NumiSeal ZK artifact.

## Status

The envelope policy prevents context confusion for parser and transcript
binding. It is not a production cryptographic security claim by itself. QRO,
QROM, and product-security claims remain governed by the product evidence
manifests, `Docs/QROProductArchitecture-2026-04-25.md`, and the formal status
manifest.

## Experimental Compression

`SuperNeoSNARKStyleCompressionProof` is an experimental recursive-verifier
compression surface. It only accepts terminal proof sources after local
verification and emits a smaller proof object binding the source proof digest,
terminal context, compression-circuit digest, and recursive-verifier trace
digest. This is a development hook for the paper's SNARK-compression path, not
yet a production Spartan/FRI proof.
