# Threat Model

This is the paper-facing threat-model summary for the current repository.

## Assets

- Soundness of accepted fold, terminal, compressed-terminal, NumiSeal, and
  NumiSealZK artifacts.
- Transcript-domain separation and product challenge binding.
- Integrity of signed trusted context, provenance, issued-QRO, replay, and audit
  records.
- Privacy properties claimed for NumiSealZK masking and simulator-coupling
  evidence.
- Parameter and estimator evidence for the selected Goldilocks/Phi81 profile.

## Adversary Model

The checked repository surface considers malformed artifacts, replayed issued
QRO challenges, mismatched product contexts, noncanonical encodings, transcript
confusion, invalid terminal relation acceptance, and evidence-manifest drift.

The product path expects callers to supply valid signed context/provenance/QRO
inputs and to configure any stricter side-channel certificate requirements in
the trusted context.

## Out Of Scope

The repository does not model or certify:

- a hostile production QRO service,
- malicious host operations or key custody,
- distribution-channel compromise,
- broad hardware leakage,
- malicious GPU execution without CPU-redundant acceptance,
- general PQ security outside the selected Module-SIS profile,
- or an independently audited SNARK compression stack.

## Sources

- [WhatThisProves.md](WhatThisProves.md)
- [QROProductArchitecture-2026-04-25.md](QROProductArchitecture-2026-04-25.md)
- [ProductOperationsReadiness-2026-04-16.md](ProductOperationsReadiness-2026-04-16.md)
- [CryptographicSecurityDossier-2026-04-16.md](CryptographicSecurityDossier-2026-04-16.md)
