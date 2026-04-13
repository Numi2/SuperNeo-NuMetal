#!/usr/bin/env python3
import argparse
import json
import math
import os
import re
import sys
from datetime import datetime, timezone


PROFILE = {
    "profile": "Goldilocks/Phi81(d=54)",
    "profileID": 1,
    "source": "SuperNeo_NuMetal.docc/superneopaper.md Appendix D.8, GL profile",
    "claimedSecurityBits": 129,
    "q": (2**64) - (2**32) + 1,
    "b": 2,
    "kappa": 18,
    "cyclotomicDegree": 54,
    "decompositionLength": 14,
    "freshBatchCount": 61,
    "challengeExpansionFactor": 216,
    "moduleColumnsFormula": "2^30 / d",
}

DEFAULT_ESTIMATOR_REPO = "https://github.com/malb/lattice-estimator.git"
DEFAULT_ESTIMATOR_COMMIT = "8d38f52c0bcc46f23d697c9c592bad50df0b124b"


def derived_parameters():
    b = PROFILE["b"]
    k = PROFILE["decompositionLength"]
    d = PROFILE["cyclotomicDegree"]
    m_sis = 2**30
    sqrt_md = math.isqrt(m_sis)
    if sqrt_md * sqrt_md != m_sis:
        raise RuntimeError("Appendix D.8 GL m*d is expected to be a perfect square")
    B = b**k
    sis_bound = sqrt_md * (8 * PROFILE["challengeExpansionFactor"] * B)
    strong_sampling_left = (
        (PROFILE["freshBatchCount"] + k)
        * PROFILE["challengeExpansionFactor"]
        * (b - 1)
    )
    return {
        "n_sis": PROFILE["kappa"] * d,
        "m_sis": m_sis,
        "length_bound_l2": sis_bound,
        "norm": 2,
        "decomposition_radix_bound": B,
        "strong_sampling_left": strong_sampling_left,
        "strong_sampling_holds": strong_sampling_left < B,
        "formulae": {
            "n_sis": "kappa * d",
            "m_sis": "(2^30 / d) * d = 2^30",
            "length_bound_l2": "sqrt(m_sis) * (8 * T * b^k)",
            "strong_sampling": "(K + k) * T * (b - 1) < b^k",
        },
    }


def convert_estimate(value):
    if isinstance(value, dict):
        return {str(k): convert_estimate(v) for k, v in value.items()}
    if isinstance(value, (list, tuple)):
        return [convert_estimate(v) for v in value]
    if isinstance(value, (str, int, float, bool)) or value is None:
        return value
    return repr(value)


def extract_security_bits(estimate):
    candidates = []
    text = json.dumps(convert_estimate(estimate), sort_keys=True)
    for pattern in [
        r"rop['\"]?\s*:\s*['\"]?2\^([0-9]+(?:\.[0-9]+)?)",
        r"rop['\"]?\s*:\s*['\"]?([0-9]+(?:\.[0-9]+)?)",
        r"≈2\^([0-9]+(?:\.[0-9]+)?)",
        r"2\^([0-9]+(?:\.[0-9]+)?)",
    ]:
        for match in re.finditer(pattern, text):
            try:
                candidates.append(float(match.group(1)))
            except ValueError:
                pass
    return min(candidates) if candidates else None


def run_estimator(estimator_dir, params):
    sys.path.insert(0, estimator_dir)
    try:
        from estimator import Logging, SIS  # type: ignore
    except Exception as error:
        raise RuntimeError(
            "failed to import lattice-estimator; run this script with Sage's Python "
            "and a checked-out estimator directory"
        ) from error

    Logging.set_level(Logging.LEVEL0)
    sis_params = SIS.Parameters(
        n=params["n_sis"],
        q=PROFILE["q"],
        m=params["m_sis"],
        length_bound=params["length_bound_l2"],
        norm=params["norm"],
    )
    estimate = SIS.estimate(sis_params)
    return {
        "parameters_repr": repr(sis_params),
        "estimate": convert_estimate(estimate),
        "minimum_extracted_rop_bits": extract_security_bits(estimate),
    }


def main():
    parser = argparse.ArgumentParser(
        description="Reproduce SuperNeo Goldilocks/Phi81 Module-SIS estimator parameters."
    )
    parser.add_argument("--estimator-dir", default=os.environ.get("LATTICE_ESTIMATOR_DIR"))
    parser.add_argument("--estimator-repo", default=DEFAULT_ESTIMATOR_REPO)
    parser.add_argument("--estimator-commit", default=DEFAULT_ESTIMATOR_COMMIT)
    parser.add_argument("--output", required=True)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    params = derived_parameters()
    artifact = {
        "artifact_schema": "superneo.lattice-estimator.v1",
        "generated_at_utc": datetime.now(timezone.utc).isoformat(),
        "profile": PROFILE,
        "module_sis_parameters": params,
        "estimator": {
            "status": "not_run",
            "reason": "dry-run requested",
            "source_repo": args.estimator_repo,
            "pinned_commit": args.estimator_commit,
        },
    }

    if not args.dry_run:
        if not args.estimator_dir:
            raise SystemExit("--estimator-dir is required unless --dry-run is used")
        estimator_result = run_estimator(args.estimator_dir, params)
        artifact["estimator"] = {
            "status": "ran",
            "source_repo": args.estimator_repo,
            "pinned_commit": args.estimator_commit,
            "estimator_dir": os.path.abspath(args.estimator_dir),
            **estimator_result,
        }
        bits = estimator_result["minimum_extracted_rop_bits"]
        artifact["claimed_security_reproduced"] = (
            bits is not None and bits >= PROFILE["claimedSecurityBits"]
        )
    else:
        artifact["claimed_security_reproduced"] = False

    os.makedirs(os.path.dirname(os.path.abspath(args.output)), exist_ok=True)
    with open(args.output, "w", encoding="utf-8") as handle:
        json.dump(artifact, handle, indent=2, sort_keys=True)
        handle.write("\n")


if __name__ == "__main__":
    main()
