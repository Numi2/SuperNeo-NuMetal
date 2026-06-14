#!/usr/bin/env python3
import copy
import json
import subprocess
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REPRODUCE = ROOT / "Scripts" / "reproduce-lattice-estimator.sh"
VALIDATE = ROOT / "Scripts" / "validate-lattice-estimator-artifact.py"


def run_ok(*args: str) -> None:
    subprocess.run(args, cwd=ROOT, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)


def run_fail(*args: str) -> None:
    completed = subprocess.run(args, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if completed.returncode == 0:
        raise AssertionError(f"expected failure: {' '.join(args)}")


def write_json(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def with_pinned_run(base: dict) -> dict:
    artifact = copy.deepcopy(base)
    artifact["pinned_reproduction"] = {
        "status": "ran",
        "lane": "pinned_reproduction",
        "source_repo": "https://github.com/malb/lattice-estimator.git",
        "commit": "8d38f52c0bcc46f23d697c9c592bad50df0b124b",
        "sage_version": "fixture",
        "parameters_repr": "SIS.Parameters(...)",
        "estimate": {"fixture": "2^130"},
        "normalized_attack_rows": [
            {"attack": "fixture", "rop_bits": 130.0, "raw": {"rop": "2^130"}}
        ],
        "minimum_extracted_rop_bits": 130.0,
        "threshold_bits": 129,
        "threshold_cleared": True,
    }
    artifact["claimed_security_reproduced_under_pinned_toolchain"] = True
    return artifact


def main() -> None:
    with tempfile.TemporaryDirectory() as tmpdir:
        tmp = Path(tmpdir)
        dry_run = tmp / "dry-run.json"
        run_ok(str(REPRODUCE), "--dry-run", str(dry_run))
        run_ok(str(VALIDATE), "--expect-status", "not_run", "--expect-latest-status", "absent", str(dry_run))
        run_fail(str(VALIDATE), "--expect-latest-status", "ran", str(dry_run))
        base = json.loads(dry_run.read_text(encoding="utf-8"))

        valid_ran = tmp / "valid-ran.json"
        write_json(valid_ran, with_pinned_run(base))
        run_ok(str(VALIDATE), "--expect-status", "ran", "--require-claimed-security", str(valid_ran))

        changed_profile = copy.deepcopy(base)
        changed_profile["profile"]["q"] = 17
        path = tmp / "changed-profile.json"
        write_json(path, changed_profile)
        run_fail(str(VALIDATE), str(path))

        missing_rows = with_pinned_run(base)
        missing_rows["pinned_reproduction"]["normalized_attack_rows"] = []
        path = tmp / "missing-rows.json"
        write_json(path, missing_rows)
        run_fail(str(VALIDATE), "--expect-status", "ran", str(path))

        nonnumeric_bits = with_pinned_run(base)
        nonnumeric_bits["pinned_reproduction"]["minimum_extracted_rop_bits"] = "130"
        path = tmp / "nonnumeric-bits.json"
        write_json(path, nonnumeric_bits)
        run_fail(str(VALIDATE), "--expect-status", "ran", str(path))

        subthreshold = with_pinned_run(base)
        subthreshold["pinned_reproduction"]["minimum_extracted_rop_bits"] = 120.0
        subthreshold["pinned_reproduction"]["threshold_cleared"] = False
        subthreshold["claimed_security_reproduced_under_pinned_toolchain"] = False
        path = tmp / "subthreshold.json"
        write_json(path, subthreshold)
        run_fail(str(VALIDATE), "--expect-status", "ran", "--require-claimed-security", str(path))

        mismatched_commit = with_pinned_run(base)
        mismatched_commit["pinned_reproduction"]["commit"] = "0" * 40
        path = tmp / "mismatched-commit.json"
        write_json(path, mismatched_commit)
        run_fail(str(VALIDATE), "--expect-status", "ran", str(path))

        ambiguous = with_pinned_run(base)
        ambiguous["claimed_security_reproduced"] = True
        path = tmp / "ambiguous.json"
        write_json(path, ambiguous)
        run_fail(str(VALIDATE), "--expect-status", "ran", str(path))

    print("lattice estimator artifact validation tests passed")


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(f"error: {error}", file=sys.stderr)
        raise
