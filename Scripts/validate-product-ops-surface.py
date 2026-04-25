#!/usr/bin/env python3
"""Validate product-operations readiness surface wiring."""

from __future__ import annotations

import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def fail(message: str) -> None:
    print(f"product ops surface validation failed: {message}", file=sys.stderr)
    raise SystemExit(1)


def require(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def read(relative_path: str) -> str:
    path = ROOT / relative_path
    require(path.exists(), f"missing required file: {relative_path}")
    return path.read_text(encoding="utf-8")


def require_contains(relative_path: str, needles: list[str]) -> None:
    text = read(relative_path)
    for needle in needles:
        require(needle in text, f"{relative_path} missing required text: {needle}")


def validate_library_surface() -> None:
    local_controls = read("SuperNeo-NuMetal/ProductIntegration/LocalProductControls.swift")
    side_channel = read("SuperNeo-NuMetal/ProductIntegration/NumiSealZKSideChannelCertification.swift")
    require_contains(
        "SuperNeo-NuMetal/ProductIntegration/LocalProductControls.swift",
        [
            "public struct SuperNeoProductOperationsStatus",
            "public enum SuperNeoProductOperationsReadiness",
            "public struct SuperNeoRevocationFeedPayload",
            "public struct SuperNeoSignedRevocationFeed",
            "public struct SuperNeoVerifiedRevocationFeed",
            "public struct SuperNeoIssuedQROChallengePayload",
            "public struct SuperNeoSignedQROChallengePack",
            "public struct SuperNeoVerifiedQROChallengePack",
            "public struct SuperNeoIssuedQROChallengeExpectedContext",
            "trustedRevocationIssuerKeyDigestsHex",
            "trustedQROChallengeIssuerKeyDigestsHex",
            "qroChallengePackPath",
            "accepted_issued_qro_challenges",
            "issuedQROChallengeDigestHex",
            "revocationFeedPath",
            "revocationFeedDigestHex",
            "canonicalDigestSet",
            "validateEntries(namePrefix",
            "public static let formatVersion = 2",
            "attention-required",
            "auditRetentionPolicy",
            "retryPolicy",
            "public func statusSnapshot()",
            "SuperNeoAuditLogStatusSnapshot",
            "contextExpiryWarningSeconds",
            "auditExportRecommendedRecordCount",
            "not-attached-optional",
            "missing-required",
            "attached-below-minimum",
            "attached",
        ],
    )
    require_contains(
        "SuperNeo-NuMetal/ProductIntegration/NumiSealZKSideChannelCertification.swift",
        [
            "minimumSideChannelCertificationLevel",
            "correctnessOnly",
            "certificate is required by trusted context",
            "certificate level is below trusted context minimum",
        ],
    )
    require(
        "?? trustedContextIssuerKeyDigestsHex" not in local_controls
        and "?? trustedProvenanceIssuerKeyDigestsHex" not in local_controls,
        "operator profile trust roots must not silently fall back between issuer classes",
    )


def validate_cli_surface() -> None:
    require_contains(
        "SuperNeoCLI/main.swift",
        [
            "product-status --operator-profile profile.json",
            "product-issue-qro",
            "[--revocation-feed revocations.json]",
            "[--format text|json]",
            "--revocation-feed",
            "operations readiness:",
            "revocation feed digest:",
            "operationsStatus",
            "writePrettyJSON(operationsStatus",
            "audit retention policy:",
            "retry policy:",
            "numiseal zk minimum side-channel level:",
            "--trusted-qro-issuer-key-digest",
            "--qro-challenge-pack requires --trusted-qro-issuer-key-digest or --operator-profile",
            "product verification must take QRO public coins only from a signed --qro-challenge-pack",
        ],
    )


def validate_docs() -> None:
    require_contains(
        "Docs/ProductOperationsReadiness-2026-04-16.md",
        [
            "SuperNeoProductOperationsStatus",
            "SuperNeoSignedRevocationFeed",
            "product-status --format json",
            "revocationFeedDigestHex",
            "readiness",
            "auditRetentionPolicy",
            "retryPolicy",
            "operationsStatus",
            "local product-ops surface",
            "accepted_issued_qro_challenges",
            "product-issue-qro",
            "--trusted-qro-issuer-key-digest",
            "sideChannelCertificateStatus",
        ],
    )
    require_contains(
        "Docs/LocalProductControls-2026-04-16.md",
        [
            "product-status --format json",
            "operations readiness",
            "signed revocation feed",
            "operationsStatus",
            "auditRetentionPolicy",
            "retryPolicy",
            "SuperNeoSignedQROChallengePack",
            "accepted_issued_qro_challenges",
            "Certificates remain optional release metadata",
        ],
    )
    require_contains(
        "Docs/ProductionReadinessAuditPacket-2026-04-16.md",
        [
            "Docs/ProductOperationsReadiness-2026-04-16.md",
            "Scripts/validate-product-ops-surface.py",
            "Scripts/test-product-ops-surface-validation.py",
            "local product-ops readiness",
            "signed revocation feed",
        ],
    )
    require_contains(
        "Docs/ReleaseEngineering-2026-04-16.md",
        [
            "Scripts/validate-product-ops-surface.py",
            "product operations readiness",
        ],
    )
    require_contains(
        "Docs/ReleaseCandidateRunbook-2026-04-16.md",
        [
            "product operations readiness status",
            "signed revocation feed",
            "Docs/ProductOperationsReadiness-2026-04-16.md",
        ],
    )
    require("external" + " audit" not in read("Docs/ProductOperationsReadiness-2026-04-16.md").lower(),
            "product operations doc must not encode outsourced review as a dependency")


def validate_gate_wiring() -> None:
    require_contains(
        "Scripts/production-gate.sh",
        [
            "product operations readiness surface validation",
            "run_step Scripts/validate-product-ops-surface.py",
            "run_step Scripts/test-product-ops-surface-validation.py",
        ],
    )
    require_contains(
        "Scripts/validate-release-readiness-policy.py",
        [
            "Docs/ProductOperationsReadiness-2026-04-16.md",
            "Scripts/validate-product-ops-surface.py",
            "Scripts/test-product-ops-surface-validation.py",
        ],
    )


def main() -> None:
    validate_library_surface()
    validate_cli_surface()
    validate_docs()
    validate_gate_wiring()
    print("product ops surface validation passed")


if __name__ == "__main__":
    main()
