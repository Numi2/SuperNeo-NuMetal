#!/usr/bin/env python3
import argparse
import json
import sys
from typing import Any, Dict, Optional


EXPECTED_REPO = "https://github.com/malb/lattice-estimator.git"
EXPECTED_COMMIT = "8d38f52c0bcc46f23d697c9c592bad50df0b124b"
EXPECTED_PROFILE = {
    "profile": "Goldilocks/Phi81(d=54)",
    "profileID": 1,
    "claimedSecurityBits": 129,
    "q": (2**64) - (2**32) + 1,
    "b": 2,
    "kappa": 18,
    "cyclotomicIndex": 81,
    "cyclotomicDegree": 54,
    "cyclotomicPolynomial": "X^54 + X^27 + 1",
    "decompositionLength": 14,
    "freshBatchCount": 61,
    "challengeExpansionFactor": 216,
}
EXPECTED_PARAMS = {
    "n_sis": 972,
    "m_sis": 1073741824,
    "length_bound_l2": 927712935936,
    "norm": 2,
    "decomposition_radix_bound": 16384,
    "strong_sampling_left": 16200,
    "strong_sampling_holds": True,
}
THRESHOLD_BITS = EXPECTED_PROFILE["claimedSecurityBits"]


def fail(message: str) -> None:
    print(f"error: {message}", file=sys.stderr)
    raise SystemExit(1)


def expect_equal(actual: Any, expected: Any, path: str) -> None:
    if actual != expected:
        fail(f"{path} was {actual!r}, expected {expected!r}")


def expect_number(value: Any, path: str) -> float:
    if not isinstance(value, (int, float)):
        fail(f"{path} must be numeric")
    return float(value)


def validate_profile(artifact: Dict[str, Any]) -> None:
    profile = artifact.get("profile")
    if not isinstance(profile, dict):
        fail("profile must be an object")
    for key, value in EXPECTED_PROFILE.items():
        expect_equal(profile.get(key), value, f"profile.{key}")

    params = artifact.get("module_sis_parameters")
    if not isinstance(params, dict):
        fail("module_sis_parameters must be an object")
    for key, value in EXPECTED_PARAMS.items():
        expect_equal(params.get(key), value, f"module_sis_parameters.{key}")

    translation = artifact.get("module_sis_translation")
    if not isinstance(translation, dict):
        fail("module_sis_translation must be an object")
    expect_equal(translation.get("estimator_object"), "estimator.SIS.Parameters", "module_sis_translation.estimator_object")
    mapping = translation.get("parameter_mapping")
    if not isinstance(mapping, dict):
        fail("module_sis_translation.parameter_mapping must be an object")
    for key in ("n", "q", "m", "length_bound", "norm"):
        if key not in mapping:
            fail(f"module_sis_translation.parameter_mapping.{key} is missing")


def validate_lane(
    lane: Any,
    *,
    path: str,
    expected_status: Optional[str],
    expected_commit: Optional[str],
    require_security: bool,
) -> None:
    if not isinstance(lane, dict):
        fail(f"{path} must be an object")
    status = lane.get("status")
    if expected_status is not None:
        expect_equal(status, expected_status, f"{path}.status")
    if status not in {"not_run", "ran"}:
        fail(f"{path}.status must be 'not_run' or 'ran'")

    expect_equal(lane.get("source_repo"), EXPECTED_REPO, f"{path}.source_repo")
    if expected_commit is not None:
        expect_equal(lane.get("commit"), expected_commit, f"{path}.commit")

    if status == "not_run":
        return

    rows = lane.get("normalized_attack_rows")
    if not isinstance(rows, list) or not rows:
        fail(f"{path}.normalized_attack_rows must be a non-empty array when status is ran")
    for index, row in enumerate(rows):
        if not isinstance(row, dict):
            fail(f"{path}.normalized_attack_rows[{index}] must be an object")
        if not isinstance(row.get("attack"), str) or not row.get("attack"):
            fail(f"{path}.normalized_attack_rows[{index}].attack must be a non-empty string")
        expect_number(row.get("rop_bits"), f"{path}.normalized_attack_rows[{index}].rop_bits")

    bits = expect_number(lane.get("minimum_extracted_rop_bits"), f"{path}.minimum_extracted_rop_bits")
    threshold = expect_number(lane.get("threshold_bits"), f"{path}.threshold_bits")
    expect_equal(threshold, THRESHOLD_BITS, f"{path}.threshold_bits")
    expect_equal(lane.get("threshold_cleared"), bits >= THRESHOLD_BITS, f"{path}.threshold_cleared")
    if require_security and bits < THRESHOLD_BITS:
        fail(f"{path}.minimum_extracted_rop_bits {bits} is below claimed {THRESHOLD_BITS}")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Validate a SuperNeo lattice-estimator reproduction artifact."
    )
    parser.add_argument("artifact")
    parser.add_argument("--expect-status", choices=["not_run", "ran"])
    parser.add_argument("--expect-latest-status", choices=["not_run", "ran", "absent"])
    parser.add_argument("--expected-commit", default=EXPECTED_COMMIT)
    parser.add_argument("--require-claimed-security", action="store_true")
    parser.add_argument("--require-latest-threshold", action="store_true")
    args = parser.parse_args()

    with open(args.artifact, "r", encoding="utf-8") as handle:
        artifact = json.load(handle)

    expect_equal(artifact.get("artifact_schema"), "superneo.lattice-estimator.v2", "artifact_schema")
    if "claimed_security_reproduced" in artifact:
        fail("legacy claimed_security_reproduced field is ambiguous in v2 artifacts")
    expect_equal(artifact.get("paper_claim_threshold_bits"), THRESHOLD_BITS, "paper_claim_threshold_bits")
    validate_profile(artifact)

    validate_lane(
        artifact.get("pinned_reproduction"),
        path="pinned_reproduction",
        expected_status=args.expect_status,
        expected_commit=args.expected_commit,
        require_security=args.require_claimed_security,
    )

    pinned = artifact.get("pinned_reproduction")
    pinned_ran_and_clear = (
        isinstance(pinned, dict)
        and pinned.get("status") == "ran"
        and pinned.get("threshold_cleared") is True
    )
    expect_equal(
        artifact.get("claimed_security_reproduced_under_pinned_toolchain"),
        pinned_ran_and_clear,
        "claimed_security_reproduced_under_pinned_toolchain",
    )
    if args.require_claimed_security:
        expect_equal(
            artifact.get("claimed_security_reproduced_under_pinned_toolchain"),
            True,
            "claimed_security_reproduced_under_pinned_toolchain",
        )

    latest = artifact.get("latest_monitoring")
    if args.expect_latest_status == "absent":
        expect_equal(latest, None, "latest_monitoring")
    elif latest is not None:
        validate_lane(
            latest,
            path="latest_monitoring",
            expected_status=args.expect_latest_status,
            expected_commit=None,
            require_security=args.require_latest_threshold,
        )
        if latest.get("status") == "ran":
            expect_equal(
                artifact.get("latest_upstream_still_clears_threshold"),
                latest.get("threshold_cleared"),
                "latest_upstream_still_clears_threshold",
            )
        if args.require_latest_threshold:
            expect_equal(artifact.get("latest_upstream_still_clears_threshold"), True, "latest_upstream_still_clears_threshold")
    else:
        if args.expect_latest_status in {"not_run", "ran"}:
            fail(f"latest_monitoring was absent, expected status {args.expect_latest_status!r}")
        if args.require_latest_threshold:
            fail("latest_monitoring is required when --require-latest-threshold is passed")
        expect_equal(artifact.get("latest_upstream_still_clears_threshold"), None, "latest_upstream_still_clears_threshold")

    print(f"validated {args.artifact}")


if __name__ == "__main__":
    main()
