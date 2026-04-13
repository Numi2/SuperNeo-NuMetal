#!/usr/bin/env python3
import argparse
import json
import sys


EXPECTED_REPO = "https://github.com/malb/lattice-estimator.git"
EXPECTED_COMMIT = "8d38f52c0bcc46f23d697c9c592bad50df0b124b"
EXPECTED_PROFILE = {
    "profile": "Goldilocks/Phi81(d=54)",
    "profileID": 1,
    "claimedSecurityBits": 129,
    "q": (2**64) - (2**32) + 1,
    "b": 2,
    "kappa": 18,
    "cyclotomicDegree": 54,
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


def fail(message):
    print(f"error: {message}", file=sys.stderr)
    raise SystemExit(1)


def expect_equal(actual, expected, path):
    if actual != expected:
        fail(f"{path} was {actual!r}, expected {expected!r}")


def main():
    parser = argparse.ArgumentParser(
        description="Validate a SuperNeo lattice-estimator reproduction artifact."
    )
    parser.add_argument("artifact")
    parser.add_argument("--expect-status", choices=["not_run", "ran"])
    parser.add_argument("--expected-commit", default=EXPECTED_COMMIT)
    parser.add_argument("--require-claimed-security", action="store_true")
    args = parser.parse_args()

    with open(args.artifact, "r", encoding="utf-8") as handle:
        artifact = json.load(handle)

    expect_equal(artifact.get("artifact_schema"), "superneo.lattice-estimator.v1", "artifact_schema")

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

    estimator = artifact.get("estimator")
    if not isinstance(estimator, dict):
        fail("estimator must be an object")
    status = estimator.get("status")
    if args.expect_status is not None:
        expect_equal(status, args.expect_status, "estimator.status")
    if status not in {"not_run", "ran"}:
        fail("estimator.status must be 'not_run' or 'ran'")

    expect_equal(estimator.get("source_repo"), EXPECTED_REPO, "estimator.source_repo")
    expect_equal(estimator.get("pinned_commit"), args.expected_commit, "estimator.pinned_commit")

    if status == "not_run":
        expect_equal(artifact.get("claimed_security_reproduced"), False, "claimed_security_reproduced")
    else:
        bits = estimator.get("minimum_extracted_rop_bits")
        if not isinstance(bits, (int, float)):
            fail("estimator.minimum_extracted_rop_bits must be numeric when estimator.status is ran")
        if args.require_claimed_security and bits < EXPECTED_PROFILE["claimedSecurityBits"]:
            fail(
                "estimator minimum extracted rop bits "
                f"{bits} is below claimed {EXPECTED_PROFILE['claimedSecurityBits']}"
            )
        if args.require_claimed_security:
            expect_equal(artifact.get("claimed_security_reproduced"), True, "claimed_security_reproduced")

    print(f"validated {args.artifact}")


if __name__ == "__main__":
    main()
