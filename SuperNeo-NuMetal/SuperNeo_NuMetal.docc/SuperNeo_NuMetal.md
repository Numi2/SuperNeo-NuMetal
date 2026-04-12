# ``SuperNeo_NuMetal``

Research-grade Swift and Metal implementation of the SuperNeo folding protocol
over the `Goldilocks/Phi81(d=54)` parameter profile.

## Overview

SuperNeo NuMetal implements the algebra, commitment, transcript, proof-envelope,
CPU verifier/prover, and optional Metal acceleration paths needed to fold
committed CCS instance-witness claims over the Goldilocks field.

The implemented profile is `Goldilocks/Phi81(d=54)`:

- base field `q = 2^64 - 2^32 + 1`,
- degree-2 extension field for sum-check challenges,
- cyclotomic ring `F[X] / (X^54 + X^27 + 1)`,
- Ajtai commitments with `kappa = 18`,
- decomposition length `14`,
- challenge coefficient set `[-2, -1, 0, 1, 2]`, and
- claimed profile security of `129` bits under the paper's Module-SIS analysis.

The protocol surface separates fold reduction from terminal acceptance. A fold
reduction checks PiCCS, PiRLC, and PiDEC and returns output CE claims. It is not
a complete application proof until terminal CE relation verification succeeds.

Read the repository trust documents before using proof acceptance as a security
claim:

- `Docs/Parameters.md`
- `Docs/ThreatModel.md`
- `Docs/ProofEnvelope.md`
- `Docs/WhatThisProves.md`
- `Docs/GPUDeterminism.md`
- `Docs/CLI.md`
- `Docs/PaperReproduction.md`
- `Docs/RoadmapStatus.md`

## Topics

### Package

- ``SuperNeoNuMetal``

### Parameters And Fields

- ``SuperNeoParameters``
- ``SuperNeoParameterProfile``
- ``GoldilocksField``
- ``GoldilocksExt2``
- ``CyclotomicRing54``
- ``CyclotomicExt2Ring54``
- ``SuperNeoEmbedding``

### CCS

- ``SuperNeoR1CSBuilder``
- ``SuperNeoR1CSVariable``
- ``SuperNeoR1CSLinearCombination``
- ``SuperNeoR1CSConstraint``
- ``SuperNeoOneHotVectorWorkload``
- ``SuperNeoBinaryAdditionWorkload``
- ``CCSShape``
- ``CCSStructure``
- ``CCSInstance``
- ``CCSWitness``
- ``CCSEvaluationClaim``
- ``SuperNeoFoldInput``
- ``SuperNeoPublicFoldInput``

### Commitments

- ``AjtaiCommitmentKey``
- ``AjtaiCommitment``
- ``AjtaiCommitter``

### Proving And Verification

- ``SuperNeoProver``
- ``SuperNeoVerifier``
- ``FoldProof``
- ``TerminalFoldProof``
- ``FoldReductionResult``
- ``VerificationResult``

### Proof Envelopes

- ``ProofEnvelopeKind``
- ``ProofEnvelopeHeader``
- ``ProofEnvelopeContext``
- ``FoldProofEnvelope``
- ``TerminalFoldProofEnvelope``
- ``CompressedTerminalProofEnvelope``
- ``CompressedTerminalProof``
- ``CompressedTerminalStatement``

### CE Opening Proofs

- ``CEOpeningStatement``
- ``TerminalCEStatement``
- ``CEOpeningProof``
- ``CEOpeningRelation``
