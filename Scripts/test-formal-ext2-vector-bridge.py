#!/usr/bin/env python3
import subprocess
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
COMPARATOR = ROOT / "Scripts" / "compare-formal-ext2-vectors.py"
LABELS = [
    "goldilocks_c0_encode",
    "goldilocks_c1_encode",
    "goldilocks_ext2_encode",
    "goldilocks_ext2_swapped_encode",
    "goldilocks_ext2_decode_valid",
    "goldilocks_ext2_decode_noncanonical_c0",
    "goldilocks_ext2_decode_noncanonical_c1",
    "goldilocks_ext2_decode_wrong_length",
    "cyclotomic_ext2_ring54_encode",
    "sumcheck_ext2_surface_encode",
    "point_evaluation_ext2_surface_encode",
]


def fixture(label_value: str = "ok") -> str:
    return "".join(f"{label}={label_value}\n" for label in LABELS)


def run_compare(swift_text: str, lean_text: str) -> subprocess.CompletedProcess[str]:
    with tempfile.TemporaryDirectory(prefix="superneo-ext2-bridge-") as tmp:
        temp = Path(tmp)
        swift_path = temp / "swift.txt"
        lean_path = temp / "lean.txt"
        swift_path.write_text(swift_text, encoding="utf-8")
        lean_path.write_text(lean_text, encoding="utf-8")
        return subprocess.run(
            [
                sys.executable,
                str(COMPARATOR),
                "--swift-output-file",
                str(swift_path),
                "--lean-output-file",
                str(lean_path),
            ],
            cwd=ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )


def require_success(result: subprocess.CompletedProcess[str]) -> None:
    if result.returncode != 0:
        raise AssertionError(
            f"expected success, got {result.returncode}\nstdout={result.stdout}\nstderr={result.stderr}"
        )


def require_failure_contains(result: subprocess.CompletedProcess[str], needle: str) -> None:
    if result.returncode == 0:
        raise AssertionError(f"expected failure containing {needle!r}, got success")
    combined = result.stdout + result.stderr
    if needle not in combined:
        raise AssertionError(
            f"expected failure containing {needle!r}\nstdout={result.stdout}\nstderr={result.stderr}"
        )


def main() -> None:
    good = fixture()
    require_success(run_compare(good, good))

    missing_label = good.replace("goldilocks_ext2_encode=ok\n", "")
    require_failure_contains(run_compare(missing_label, good), "missing required labels")

    duplicate_label = good + "goldilocks_ext2_encode=ok\n"
    require_failure_contains(run_compare(duplicate_label, good), "duplicate label")

    extra_label = good + "unsupported=ok\n"
    require_failure_contains(run_compare(extra_label, good), "unsupported labels")

    changed = good.replace(
        "sumcheck_ext2_surface_encode=ok\n",
        "sumcheck_ext2_surface_encode=drift\n",
    )
    require_failure_contains(run_compare(changed, good), "Swift/Lean Ext2 vector mismatch")

    print("formal Ext2 vector bridge validation regression tests passed")


if __name__ == "__main__":
    main()
