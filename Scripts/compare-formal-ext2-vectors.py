#!/usr/bin/env python3
import argparse
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]

REQUIRED_LABELS = [
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


def fail(message: str) -> None:
    print(f"error: {message}", file=sys.stderr)
    raise SystemExit(1)


def run_command(command: list[str], cwd: Path) -> str:
    result = subprocess.run(
        command,
        cwd=cwd,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if result.returncode != 0:
        fail(
            "command failed with exit code "
            f"{result.returncode}: {' '.join(command)}\n{result.stderr}"
        )
    return result.stdout


def parse_output(name: str, output: str) -> dict[str, str]:
    parsed: dict[str, str] = {}
    for line_number, raw_line in enumerate(output.splitlines(), start=1):
        line = raw_line.strip()
        if not line:
            continue
        if "=" not in line:
            fail(f"{name} line {line_number} is not label=value: {raw_line!r}")
        label, value = line.split("=", 1)
        if not label:
            fail(f"{name} line {line_number} has an empty label")
        if label in parsed:
            fail(f"{name} emitted duplicate label {label!r}")
        parsed[label] = value

    missing = [label for label in REQUIRED_LABELS if label not in parsed]
    if missing:
        fail(f"{name} missing required labels: {', '.join(missing)}")
    extra = sorted(set(parsed).difference(REQUIRED_LABELS))
    if extra:
        fail(f"{name} emitted unsupported labels: {', '.join(extra)}")
    return parsed


def load_or_run(path: str | None, command: list[str], cwd: Path, name: str) -> dict[str, str]:
    if path:
        output = Path(path).read_text(encoding="utf-8")
    else:
        output = run_command(command, cwd)
    return parse_output(name, output)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Compare executable Swift GoldilocksExt2 vectors against Lean grammar vectors."
    )
    parser.add_argument("--root", default=str(ROOT), help="repository root")
    parser.add_argument("--swift-output-file", help="read Swift vector output from a file")
    parser.add_argument("--lean-output-file", help="read Lean vector output from a file")
    args = parser.parse_args()

    root = Path(args.root).resolve()
    swift_vectors = load_or_run(
        args.swift_output_file,
        ["swift", "run", "-c", "release", "--package-path", str(root), "superneo-formal-vectors", "ext2"],
        root,
        "Swift vector emitter",
    )
    lean_vectors = load_or_run(
        args.lean_output_file,
        ["lake", "env", "lean", "--run", "../Scripts/emit-formal-ext2-vectors.lean"],
        root / "Formal",
        "Lean vector emitter",
    )

    mismatches: list[str] = []
    for label in REQUIRED_LABELS:
        swift_value = swift_vectors[label]
        lean_value = lean_vectors[label]
        if swift_value != lean_value:
            mismatches.append(
                f"{label}: Swift={swift_value!r} Lean={lean_value!r}"
            )

    if mismatches:
        fail("Swift/Lean Ext2 vector mismatch:\n" + "\n".join(mismatches))

    print("Swift/Lean GoldilocksExt2 serialization vectors match")


if __name__ == "__main__":
    main()
