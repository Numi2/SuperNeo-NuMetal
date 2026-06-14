# High-Assurance Hardening

High-assurance mode is the conservative repository path for product-oriented
proof handling. It favors stable control flow, explicit context binding, and
signed product-control inputs over raw performance.

## Current Boundary

High-assurance acceptance is built from:

- NumiSealZK product artifacts rather than raw non-ZK fold artifacts,
- caller-supplied signed QRO challenge packs,
- signed trusted context and provenance,
- replay-ledger and audit-log checks,
- CPU reference execution for the default high-assurance lane,
- optional side-channel certificates for stricter trusted contexts.

Primary references:

- [QROProductArchitecture-2026-04-25.md](QROProductArchitecture-2026-04-25.md)
- [LocalProductControls-2026-04-16.md](LocalProductControls-2026-04-16.md)
- [CryptographicSideChannelAudit-2026-04-25.md](CryptographicSideChannelAudit-2026-04-25.md)
- [ThreatModel.md](ThreatModel.md)
- [Archive/compliance](Archive/compliance)

## Remaining Boundaries

The repository still does not claim:

- production QROM security for a deployed concrete hash service,
- broad post-quantum security beyond the selected evidence-parametric profile,
- whole-stack constant-time certification,
- hosted operations security,
- release distribution assurance,
- or independent cryptographic and implementation review.

Those boundaries are deliberate. They keep the paper-inspired implementation
claim separate from production deployment claims.
