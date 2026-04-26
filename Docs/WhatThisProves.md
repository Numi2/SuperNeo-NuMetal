# What This Proves

Formal status: completed formal protocol theorem.

This is the compact proof-semantics page. Use it when explaining what verifier
acceptance means.

## Relation

SuperNeo NuMetal folds committed CCS instance-witness claims over the
`Goldilocks/Phi81(d=54)` profile. A CCS shape defines sparse matrices and a
relation polynomial. Public inputs and commitments define the public instance.
Witness vectors remain prover-side inputs.

The selected source-fold profile is `pay-per-bit-v1`. The verifier must treat
source-fold decomposition/output CE obligations as adaptive artifact-bound
claims, not as a fixed 14-claim rule. Recomposition and matching
decomposition/output counts are mandatory.

## `reduceFold`

`reduceFold` verifies the public fold reduction:

- the public CCS shape and instances are well formed;
- sum-check, PiCCS, PiRLC, and PiDEC checks are transcript-bound;
- the folded claim is the claimed random linear combination; and
- decomposition output CE obligations match the selected profile.

Accepted `reduceFold` output means the reduction verified. It is not terminal
acceptance; returned CE obligations still need terminal verification.

## Terminal Verification

`verifyTerminalFold` verifies the fold reduction and then verifies the terminal
CE opening relation for the fold output obligations.

Accepted terminal output means the reduction and terminal CE openings verified
under the supplied shape, public input, transcript domain, and verifier key. It
is a proof about the encoded CCS relation, not about an external program unless
that program was correctly encoded as CCS.

`verifyCompressedTerminalFoldEnvelope` adds compressed public-input,
statement-digest, verifier-key, fold-proof, CE-proof, and compression-digest
binding before reconstructing terminal verification.

## NumiSeal Product Verification

The selected product path is the QRO public-coin path in
`Docs/QROProductArchitecture-2026-04-25.md`.

Product NumiSeal verification means:

- the caller supplied the trusted `SuperNeoQROChallenge`;
- the product artifact is version 2;
- the source fold is bound to `pay-per-bit-v1`;
- source-fold and terminal transcript material are derived from QRO public
  coins, not from artifact-selected transcript seeds;
- envelope kind, public statement, verifier key, CTCO roots, lane summaries,
  aggregate digests, carry context, and proof transcript digests match; and
- the NumiSeal or NumiSealZK proof verifies under the reconstructed public
  statement and policy.

Product mode rejects legacy self-described NumiSeal JSON and artifact-selected
transcript seeds.

## Proof Envelopes

Proof envelopes bind proof bytes to profile ID, proof kind, CCS shape digest,
statement digest, verifier-key digest, transcript domain, and exact body
length. The envelope prevents proof-kind, key, shape, transcript-domain, and
length confusion. It does not define application-level semantics; the CCS
encoder and public-input policy do that.

## Formal Status

The Lean track contains a completed finite-model formal protocol theorem for
the repository model. Its theorem-facing surfaces include well-formed
transcript injectivity, 384-bit theorem-critical proof-envelope binding,
typed digest domains, Phi81 CRT decomposition, PiRLC/PiCCS finite-soundness
surfaces, terminal CE finite-seed accounting, and selected-depth product
ledger wiring.

The formal track does not by itself certify hosted operations, side-channel
behavior, release distribution, or arbitrary external program encodings.

## Do Not Claim

Do not describe this repository as:

- a production-secure SNARK;
- production QROM-secure for every surface;
- a whole-stack constant-time implementation;
- a general program compiler to CCS; or
- an independently audited cryptographic product.
