# What This Proves And What It Does Not Prove

This page is the shortest safe description of SuperNeo NuMetal's proof
semantics. Use it when explaining the project to someone who needs to know what
verifier acceptance means.

## The Relation

SuperNeo NuMetal folds committed CCS instance-witness claims over the
`Goldilocks/Phi81(d=54)` profile. A CCS shape describes sparse matrices and a
relation polynomial. Public inputs and commitments define public instances.
Witness vectors remain prover-side inputs; terminal proof paths verify derived
CE claims rather than making a general application statement automatically true.

The folding protocol reduces many active CCS claims and prior CE claims into a
fixed number of output CE claims. The decomposition length is 14 for the current
profile.

## What `reduceFold` Proves

`reduceFold` verifies the public fold reduction:

- the public CCS shape and instances are well formed,
- the sum-check transcript is bound to the public input and proof messages,
- PiCCS final claims are consistent with the CCS and prior CE checks encoded in
  the sum-check oracle,
- PiRLC challenges are transcript-derived and the folded claim is the claimed
  random linear combination, and
- PiDEC decomposes the folded claim into 14 output CE claims.

An accepted reduction means:

> The verifier accepts the reduction from the supplied public fold input to the
> returned CE output claims.

It does not mean:

> The application statement is fully proven.

The output CE claims still need terminal relation verification.

## What `verifyTerminalFold` Proves

`verifyTerminalFold` verifies the fold reduction and then verifies the terminal
CE opening relation for the fold output claims. This is the local terminal
acceptance path. It is the right API when the verifier has the public fold input,
the terminal proof, and the information needed to check the CE opening relation.

An accepted terminal proof means:

> The fold reduction verified and the terminal CE openings verified for the
> reduction outputs under the supplied shape and verifier key.

This is still a proof about the encoded CCS relation, not an automatic proof
about an external program unless that program has been correctly encoded as CCS.

## What `verifyCompressedTerminalFoldEnvelope` Proves

Compressed public envelopes bind a fold proof and CE opening proof through
digests and a compressed statement. Verification checks:

- envelope context,
- public input digest,
- verifier-key digest,
- compressed terminal statement digest,
- fold proof digest,
- CE opening proof digest,
- compression digest, and
- reconstructed terminal fold verification.

An accepted compressed public envelope means:

> The public compressed artifact verified against the supplied public input,
> shape, statement digest, verifier key, and terminal CE relation.

It does not remove the need for applications to validate they supplied the
intended public input, intended verifier key, and intended CCS shape.

## What The Envelope Adds

A proof envelope prevents context confusion. It binds proof bytes to:

- profile ID,
- proof kind,
- CCS shape digest,
- statement digest,
- verifier-key digest,
- transcript domain, and
- exact body length.

The envelope does not define the application-level meaning of a statement. That
meaning comes from the CCS encoder and the application that chooses the public
inputs.

## What This Repository Does Not Yet Prove

This repository does not yet provide:

- a general-purpose frontend from programs to CCS,
- a production-audited zero-knowledge claim,
- a production SNARK, IVC, or PCD system,
- an independent implementation in another language,
- independent reproduction of the paper's lattice-estimator scripts, or
- side-channel resistance.

Until those pieces exist, the correct public positioning is:

> A research-grade Swift/Metal implementation of the SuperNeo folding protocol
> over `Goldilocks/Phi81(d=54)`, with versioned proof envelopes and CPU/Metal
> verification paths.
