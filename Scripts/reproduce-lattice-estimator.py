#!/usr/bin/env python3
import argparse
import json
import math
import os
import platform
import re
import subprocess
import sys
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional


PROFILE = {
    "profile": "Goldilocks/Phi81(d=54)",
    "profileID": 1,
    "source": "SuperNeo_NuMetal.docc/superneopaper.md Appendix B.2 and Appendix D.8, GL profile",
    "claimedSecurityBits": 129,
    "q": (2**64) - (2**32) + 1,
    "b": 2,
    "kappa": 18,
    "cyclotomicIndex": 81,
    "cyclotomicPolynomial": "X^54 + X^27 + 1",
    "cyclotomicDegree": 54,
    "decompositionLength": 14,
    "freshBatchCount": 61,
    "challengeExpansionFactor": 216,
    "moduleColumnsFormula": "2^30 / d",
}

DEFAULT_ESTIMATOR_REPO = "https://github.com/malb/lattice-estimator.git"
DEFAULT_ESTIMATOR_COMMIT = "8d38f52c0bcc46f23d697c9c592bad50df0b124b"
THRESHOLD_BITS = PROFILE["claimedSecurityBits"]


def derived_parameters() -> Dict[str, Any]:
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


def module_sis_translation(params: Dict[str, Any]) -> Dict[str, Any]:
    return {
        "source_protocol_instance": "Ajtai commitments over Goldilocks/Phi81(d=54)",
        "estimator_object": "estimator.SIS.Parameters",
        "parameter_mapping": {
            "n": {
                "value": params["n_sis"],
                "formula": "kappa * d",
                "meaning": "module rank times Phi81 coefficient dimension",
            },
            "q": {
                "value": PROFILE["q"],
                "formula": "2^64 - 2^32 + 1",
                "meaning": "Goldilocks base-field modulus used as estimator modulus",
            },
            "m": {
                "value": params["m_sis"],
                "formula": "(2^30 / d) * d = 2^30",
                "meaning": "paper Appendix D.8 SIS dimension after coefficient expansion",
            },
            "length_bound": {
                "value": params["length_bound_l2"],
                "formula": "sqrt(m_sis) * (8 * T * b^k)",
                "meaning": "L2 bound corresponding to MSIS infinity bound 8*T*B",
            },
            "norm": {
                "value": params["norm"],
                "formula": "2",
                "meaning": "lattice-estimator norm selector used by the paper script",
            },
        },
        "interpretation": (
            "This is a coefficient-expanded SIS estimator encoding of the "
            "Module-SIS claim used by the paper. It is not a native formal "
            "statement about the quotient ring or a production certification."
        ),
    }


def convert_estimate(value: Any) -> Any:
    if isinstance(value, dict):
        return {str(k): convert_estimate(v) for k, v in value.items()}
    if isinstance(value, (list, tuple)):
        return [convert_estimate(v) for v in value]
    if isinstance(value, (str, int, float, bool)) or value is None:
        return value
    return repr(value)


def rop_bits_from_text(text: str) -> List[float]:
    candidates: List[float] = []
    patterns = [
        r"rop['\"]?\s*:\s*['\"]?2\^([0-9]+(?:\.[0-9]+)?)",
        r"rop['\"]?\s*:\s*['\"]?([0-9]+(?:\.[0-9]+)?)",
        r"rop\s*=\s*2\^([0-9]+(?:\.[0-9]+)?)",
        r"≈2\^([0-9]+(?:\.[0-9]+)?)",
        r"2\^([0-9]+(?:\.[0-9]+)?)",
    ]
    for pattern in patterns:
        for match in re.finditer(pattern, text):
            try:
                candidates.append(float(match.group(1)))
            except ValueError:
                pass
    return candidates


def extract_security_bits(estimate: Any) -> Optional[float]:
    bits = rop_bits_from_text(json.dumps(convert_estimate(estimate), sort_keys=True))
    return min(bits) if bits else None


def normalize_attack_rows(estimate: Any) -> List[Dict[str, Any]]:
    converted = convert_estimate(estimate)
    rows: List[Dict[str, Any]] = []
    if isinstance(converted, dict):
        items = converted.items()
    else:
        items = [("estimate", converted)]

    for attack, result in items:
        text = json.dumps(result, sort_keys=True)
        row_bits = rop_bits_from_text(text)
        if not row_bits:
            continue
        rows.append(
            {
                "attack": str(attack),
                "rop_bits": min(row_bits),
                "raw": result,
            }
        )
    return rows


def sage_version_from_runtime() -> Optional[str]:
    for command in (["sage", "--version"],):
        try:
            completed = subprocess.run(
                command,
                check=False,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
            )
        except OSError:
            continue
        output = completed.stdout.strip()
        if completed.returncode == 0 and output:
            return output.splitlines()[0]
    try:
        import sage.all  # type: ignore  # noqa: F401

        return "SageMath Python runtime"
    except Exception:
        return None


def run_estimator(estimator_dir: str, params: Dict[str, Any]) -> Dict[str, Any]:
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
    normalized_rows = normalize_attack_rows(estimate)
    minimum_bits = (
        min(row["rop_bits"] for row in normalized_rows)
        if normalized_rows
        else extract_security_bits(estimate)
    )
    return {
        "parameters_repr": repr(sis_params),
        "estimate": convert_estimate(estimate),
        "normalized_attack_rows": normalized_rows,
        "minimum_extracted_rop_bits": minimum_bits,
        "threshold_bits": THRESHOLD_BITS,
        "threshold_cleared": minimum_bits is not None and minimum_bits >= THRESHOLD_BITS,
    }


def not_run_lane(reason: str, repo: str, commit: Optional[str] = None) -> Dict[str, Any]:
    lane: Dict[str, Any] = {
        "status": "not_run",
        "reason": reason,
        "source_repo": repo,
    }
    if commit is not None:
        lane["commit"] = commit
    return lane


def ran_lane(
    lane_name: str,
    estimator_dir: str,
    repo: str,
    commit: str,
    params: Dict[str, Any],
    sage_version: Optional[str],
) -> Dict[str, Any]:
    result = run_estimator(estimator_dir, params)
    return {
        "status": "ran",
        "lane": lane_name,
        "source_repo": repo,
        "commit": commit,
        "estimator_dir": os.path.abspath(estimator_dir),
        "sage_version": sage_version,
        **result,
    }


def drift_summary(
    pinned: Dict[str, Any],
    latest: Optional[Dict[str, Any]],
) -> Optional[Dict[str, Any]]:
    if latest is None:
        return None
    if pinned.get("status") != "ran":
        return {"status": "pinned_not_run"}
    if latest.get("status") != "ran":
        return {"status": "latest_not_run"}
    pinned_bits = pinned.get("minimum_extracted_rop_bits")
    latest_bits = latest.get("minimum_extracted_rop_bits")
    if not isinstance(pinned_bits, (int, float)) or not isinstance(latest_bits, (int, float)):
        return {"status": "missing_security_bits"}
    return {
        "status": "computed",
        "pinned_commit": pinned.get("commit"),
        "latest_commit": latest.get("commit"),
        "same_commit": pinned.get("commit") == latest.get("commit"),
        "minimum_rop_bits_delta": latest_bits - pinned_bits,
        "latest_threshold_cleared": latest_bits >= THRESHOLD_BITS,
    }


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Reproduce SuperNeo Goldilocks/Phi81 Module-SIS estimator parameters."
    )
    parser.add_argument("--estimator-repo", default=DEFAULT_ESTIMATOR_REPO)
    parser.add_argument("--pinned-commit", default=DEFAULT_ESTIMATOR_COMMIT)
    parser.add_argument("--pinned-estimator-dir")
    parser.add_argument("--latest-commit")
    parser.add_argument("--latest-estimator-dir")
    parser.add_argument("--run-pinned", action="store_true")
    parser.add_argument("--run-latest", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--sage-version")
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    params = derived_parameters()
    sage_version = args.sage_version or sage_version_from_runtime()
    pinned_lane = not_run_lane(
        "dry-run requested" if args.dry_run else "pinned lane was not selected",
        args.estimator_repo,
        args.pinned_commit,
    )
    latest_lane: Optional[Dict[str, Any]] = None

    if args.run_pinned:
        if not args.pinned_estimator_dir:
            raise SystemExit("--pinned-estimator-dir is required with --run-pinned")
        pinned_lane = ran_lane(
            "pinned_reproduction",
            args.pinned_estimator_dir,
            args.estimator_repo,
            args.pinned_commit,
            params,
            sage_version,
        )

    if args.run_latest:
        if not args.latest_estimator_dir or not args.latest_commit:
            raise SystemExit("--latest-estimator-dir and --latest-commit are required with --run-latest")
        latest_lane = ran_lane(
            "latest_monitoring",
            args.latest_estimator_dir,
            args.estimator_repo,
            args.latest_commit,
            params,
            sage_version,
        )

    drift = drift_summary(pinned_lane, latest_lane)
    if latest_lane is not None:
        latest_lane["drift_vs_pinned"] = drift

    artifact = {
        "artifact_schema": "superneo.lattice-estimator.v2",
        "generated_at_utc": datetime.now(timezone.utc).isoformat(),
        "generator": {
            "script": "Scripts/reproduce-lattice-estimator.py",
            "python_version": platform.python_version(),
        },
        "profile": PROFILE,
        "module_sis_parameters": params,
        "module_sis_translation": module_sis_translation(params),
        "paper_claim_threshold_bits": THRESHOLD_BITS,
        "pinned_reproduction": pinned_lane,
        "latest_monitoring": latest_lane,
        "claimed_security_reproduced_under_pinned_toolchain": (
            pinned_lane.get("status") == "ran" and bool(pinned_lane.get("threshold_cleared"))
        ),
        "latest_upstream_still_clears_threshold": (
            None
            if latest_lane is None or latest_lane.get("status") != "ran"
            else bool(latest_lane.get("threshold_cleared"))
        ),
    }

    os.makedirs(os.path.dirname(os.path.abspath(args.output)), exist_ok=True)
    with open(args.output, "w", encoding="utf-8") as handle:
        json.dump(artifact, handle, indent=2, sort_keys=True)
        handle.write("\n")


if __name__ == "__main__":
    main()
