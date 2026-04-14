#!/usr/bin/env python3
import subprocess
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
COMPARATOR = ROOT / "Scripts" / "compare-formal-ce-vectors.py"
LABELS = [
    "ce_response_mask_encode",
    "ce_response_masked_witness_encode",
    "ce_response_permuted_witness_encode",
    "ce_round_mask_encode",
    "ce_round_masked_witness_encode",
    "ce_round_permuted_witness_encode",
    "ce_round_width",
    "ce_first_response_tag_offset",
    "ce_proof_encode",
    "ce_proof_decode_valid",
    "ce_proof_decode_wrong_round_count",
    "ce_proof_decode_invalid_tag",
    "ce_proof_decode_wrong_response_count",
]


def fixture(label_value: str = "ok") -> str:
    return "".join(f"{label}={label_value}\n" for label in LABELS)


def run_compare(swift_text: str, lean_text: str) -> subprocess.CompletedProcess[str]:
    with tempfile.TemporaryDirectory(prefix="superneo-ce-bridge-") as tmp:
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

    missing_label = good.replace("ce_proof_encode=ok\n", "")
    require_failure_contains(run_compare(missing_label, good), "missing required labels")

    duplicate_label = good + "ce_proof_encode=ok\n"
    require_failure_contains(run_compare(duplicate_label, good), "duplicate label")

    extra_label = good + "unsupported=ok\n"
    require_failure_contains(run_compare(extra_label, good), "unsupported labels")

    changed = good.replace(
        "ce_proof_decode_valid=ok\n",
        "ce_proof_decode_valid=drift\n",
    )
    require_failure_contains(run_compare(changed, good), "Swift/Lean CE vector mismatch")

    print("formal CE vector bridge validation regression tests passed")


if __name__ == "__main__":
    main()
