# What This Proves And What It Does Not Prove

This page is the shortest safe description of SuperNeo NuMetal's proof
semantics. Use it when explaining the project to someone who needs to know what
verifier acceptance means.

Formal status: conditional protocol formalization.

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

## What `verify --require-numiseal` Proves

`superneo verify --require-numiseal` accepts checked NumiSeal terminal artifacts
with proof envelope kind `4`. Verification reconstructs the public NumiSeal
obligations, accepted lane set, aggregate plan, and terminal policy from the
artifact's public vector metadata, checks the envelope header, public statement,
obligation root, lane-summary root, aggregate digests, component digest root, and
proof-transcript digest, then calls `NumiSealVerifier` to verify immediate
residual CE openings through the existing CE opening relation.

An accepted NumiSeal terminal artifact means:

> The supplied kind `4` envelope verified against the reconstructed public
> NumiSeal statement, aggregate policy, shape, verifier key, transcript domain,
> and immediate residual CE openings.

This is not a zero-knowledge claim, not a recursive NumiSeal product claim, and
not a general `superneo prove --seal numiseal` interface. The deterministic
NumiSeal vector generator remains test-vector tooling. External callers must
pin expected NumiSeal context outside the artifact before treating CLI
acceptance as a policy decision.

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

## What The Formal Status Proves

This repository does not yet provide:

- a general-purpose frontend from programs to CCS,
- a production-audited zero-knowledge claim,
- a production SNARK, IVC, or PCD system,
- an independent implementation in another language,
- a formal proof of the paper's lattice-estimator analysis, or
- formal side-channel resistance.

The repository does include a pinned lattice-estimator reproduction harness and
opt-in high-assurance execution policies. Those are hardening artifacts; they do
not change the meaning of proof acceptance by themselves.

The repository also includes a Lean 4 formalization track. The current formal
status is a conditional protocol formalization for the corrected model:

- Ajtai binding is certified-key binding, not arbitrary-matrix binding.
- PiRLC, PiCCS/sum-check, and terminal CE proof soundness are finite
  bad-challenge/bad-seed statements, not zero-error deterministic statements.
- End-to-end terminal composition is proved outside the certified CE bad-seed
  set.

Historical assumption-boundary IDs remain documented for auditability, but they
are not active manifest groups. The full theorem label is blocked until the
remaining planned groups mechanize full cryptographic probability composition,
complete Swift serialization equivalence, and a byte-for-byte Swift CE verifier
equivalence proof. The Lean `GoldilocksExt2` field instance is closed
separately by the `goldilocks-ext2-field-instance` theorem group.

The correct public positioning remains:

> A research-grade Swift/Metal implementation of the SuperNeo folding protocol
> over `Goldilocks/Phi81(d=54)`, with versioned proof envelopes and CPU/Metal
> verification paths.
