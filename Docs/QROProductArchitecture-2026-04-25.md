# QRO Product Architecture

Date: 2026-04-25

This is the selected cryptographic architecture for NumiSeal product proofs.
Product proving and verification are built around an explicit verifier public
coin in the quantum-random-oracle abstraction. Artifact-selected transcript
seeds and artifact-selected transcript context are not a product security
boundary.

## Chosen Path

The product path is:

1. The verifier or product-control layer supplies `SuperNeoQROChallenge`.
   Product controls require a signed `SuperNeoSignedQROChallengePack` binding
   the challenge to the trusted context, frontend-context digest, statement,
   verifier key, public inputs, transcript domain, issue window, and single-use
   replay policy.
2. `SuperNeoQROChallenge` requires a non-empty domain separator, a non-empty
   session ID, and at least 32 bytes of verifier public coin.
3. Product proving derives a source-fold QRO challenge with label
   `numiseal-product-source-fold` and the fold envelope context bytes.
4. Product proving emits the source fold under the `pay-per-bit-v1`
   decomposition/opening profile, records it as a top-level artifact field, and
   mirrors it in product execution metadata.
5. Product proving derives the NumiSeal terminal transcript domain with label
   `numiseal-product-terminal`.
6. Product artifacts record QRO challenge metadata, source-fold QRO digest,
   QRO-derived terminal transcript domain, CTCO roots, QROM evidence digest,
   trace evidence digest, and concrete-extractor digest.
7. Product verification recomputes the same QRO challenge digests from trusted
   caller input, requires `sourceDecompositionProfile = pay-per-bit-v1`, and
   rejects mismatches before accepting the source fold or NumiSeal proof.
8. When a signed issued-QRO pack is present, product replay identity binds the
   issued pack digest and SQLite enforces single-use acceptance of that issued
   public coin even under a different artifact/provenance pair.

This is implemented through:

- `SuperNeoQROChallenge`
- `SuperNeoProver.foldWithOutput(..., qroChallenge:)`
- `SuperNeoVerifier.reduceFold(..., qroChallenge:)`
- `SuperNeoVerifier.reduceFoldEnvelope(..., qroChallenge:)`
- `NumiSealProvingRequest.qroChallenge`
- `NumiSealProvingRequest.sourceDecompositionProfile`
- `NumiSealProductAPI.provePreparedR1CS(..., qroChallenge:)`
- `NumiSealProductVerifier.verify(..., qroChallenge:)`
- `NumiSealProductQROMEvidence.qroChallengeDigest`
- `SuperNeoIssuedQROChallengePayload`
- `SuperNeoSignedQROChallengePack`
- `SuperNeoProductProofIdentity.issuedQROChallengeDigest`

The product CLI follows the same rule. `superneo prove --seal numiseal` and
non-product `superneo verify` for `NumiSealProductArtifact` accept a local
public-coin smoke path:

- `--qro-session-id`
- `--qro-public-coin-hex`
- optional `--qro-domain`

For pre-proof product issuance, `superneo product-issue-qro` creates a signed
issued-QRO pack from the planned workload, source application path, verifier key,
shape, statement, public inputs, frontend-context digest, validity window, and
verifier public coin. `superneo prove --seal numiseal` can then consume
`--qro-challenge-pack` plus either `--trusted-qro-issuer-key-digest` or an
operator profile. That path verifies the signed pack before proving and rejects
packs whose context ID, validity window, frontend-context digest, verifier key,
shape, statement, transcript domain, public inputs, QRO digest, signature, or
issuer trust root do not match the generated proof context.

In product-control mode, `superneo verify --product` requires
`--qro-challenge-pack` or an operator-profile `qroChallengePackPath` for
NumiSealZK product artifacts. Non-ZK NumiSeal artifacts and raw QRO CLI fields
are rejected in product mode; they are only a non-product local verification
surface.

## Removed Product Path

The old product path allowed self-described NumiSeal JSON to carry
`foldTranscriptSeedUTF8` and transcript material. That path has been removed
from the product tree: there is no product CLI route, no vector executable, no
product-control policy route, and no verifier facade that accepts it.

The active product wrapper is `NumiSealProductArtifact.artifactVersion == 2`.
It carries both the source fold envelope and the terminal NumiSeal or NumiSealZK
envelope, but verifier public randomness is not read from the artifact.

## QROM Position

The repository architecture follows the QROM public-coin literature by treating
classical random-oracle proofs as insufficient unless the protocol-specific
preconditions and loss accounting are explicit. The selected implementation uses
split roles:

- `H_chal`: 256-bit challenge seeds and deterministic challenge-tape expansion.
- `H_bind`: 384-bit theorem-critical binding digests.
- CTCO as the preferred product compiler family.
- Merkle-straightline as the fallback compiler family.
- Interactive soundness charged outside the QROM transform term.
- Shared bad events charged once through the product ledger.

The primary references for this design direction are:

- Dominique Unruh, `Non-interactive zero-knowledge proofs in the quantum random
  oracle model`, https://eprint.iacr.org/2014/587.
- Jelle Don, Serge Fehr, Christian Majenz, and Christian Schaffner, `Security of
  the Fiat-Shamir Transformation in the Quantum Random-Oracle Model`,
  https://eprint.iacr.org/2019/190.
- Qipeng Liu and Mark Zhandry, `Revisiting Post-Quantum Fiat-Shamir`,
  https://eprint.iacr.org/2019/262.

## Verifier Breakage Requirements

The verifier must reject:

- missing or too-short QRO verifier public coin;
- expired, not-yet-valid, unsigned, swapped, or non-single-use issued QRO pack;
- swapped QRO challenge;
- mismatched QRO transcript domain;
- mismatched source-fold QRO challenge digest;
- mismatched CTCO root or challenge tape seed;
- mismatched frontend context digest;
- wrong public inputs;
- swapped verifier key;
- proof-kind confusion;
- malformed or duplicate JSON keys;
- malformed envelope lengths;
- replayed product identity;
- replayed issued QRO public coin under a different product identity;
- recursive carry context swaps;
- aggregate, lane, or proof transcript mutation;
- random bit flips in source or product proof envelopes.

Passing honest proofs is not enough evidence. Product acceptance requires the
negative verifier path to stay fail-closed.
