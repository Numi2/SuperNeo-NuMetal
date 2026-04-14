#!/usr/bin/env python3
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
VALIDATOR = ROOT / "Scripts" / "validate-formal-ce-byte-serialization.py"


REQUIRED_FILES = [
    "Formal/SuperNeoFormal.lean",
    "Formal/SuperNeoFormal/CEByteSerialization.lean",
    "SuperNeo-NuMetal/Protocols/SuperNeoProtocols.swift",
    "SuperNeo-NuMetal/SuperNeoSerialization.swift",
    "SuperNeo-NuMetalTests/SuperNeoNuMetalTests.swift",
]


def run_validator(root: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(VALIDATOR), "--root", str(root)],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )


def copy_required_files(destination: Path) -> None:
    for rel in REQUIRED_FILES:
        source = ROOT / rel
        target = destination / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)


def require_success(result: subprocess.CompletedProcess[str]) -> None:
    if result.returncode != 0:
        raise AssertionError(
            f"expected success, got {result.returncode}\nstdout={result.stdout}\nstderr={result.stderr}"
        )


def require_failure_contains(result: subprocess.CompletedProcess[str], needle: str) -> None:
    if result.returncode == 0:
        raise AssertionError(f"expected failure containing {needle!r}, got success\nstdout={result.stdout}")
    combined = result.stdout + result.stderr
    if needle not in combined:
        raise AssertionError(
            f"expected failure containing {needle!r}\nstdout={result.stdout}\nstderr={result.stderr}"
        )


def mutate(path: Path, old: str, new: str) -> None:
    text = path.read_text(encoding="utf-8")
    if old not in text:
        raise AssertionError(f"mutation source text not found in {path}: {old!r}")
    path.write_text(text.replace(old, new, 1), encoding="utf-8")


def run_mutation(rel_path: str, old: str, new: str, expected_failure: str) -> None:
    with tempfile.TemporaryDirectory(prefix="superneo-formal-ce-byte-") as tmp:
        temp_root = Path(tmp)
        copy_required_files(temp_root)
        mutate(temp_root / rel_path, old, new)
        require_failure_contains(run_validator(temp_root), expected_failure)


def main() -> None:
    require_success(run_validator(ROOT))

    run_mutation(
        "Formal/SuperNeoFormal.lean",
        "import SuperNeoFormal.CEByteSerialization",
        "import SuperNeoFormal.Serialization",
        "top-level Lean CE byte serialization import",
    )
    run_mutation(
        "Formal/SuperNeoFormal/CEByteSerialization.lean",
        "def ceOpeningProofRoundCount : Nat :=\n  219",
        "def ceOpeningProofRoundCount : Nat :=\n  218",
        "Lean CE proof round count must be 219",
    )
    run_mutation(
        "Formal/SuperNeoFormal/CEByteSerialization.lean",
        "| .permutedWitness => byteOfNat 2",
        "| .permutedWitness => byteOfNat 3",
        "Lean CE response tag encoder must map mask/masked/permuted to 0/1/2",
    )
    run_mutation(
        "SuperNeo-NuMetal/Protocols/SuperNeoProtocols.swift",
        "public static let roundCount = 219",
        "public static let roundCount = 218",
        "Swift CEOpeningProof roundCount must be 219",
    )
    run_mutation(
        "SuperNeo-NuMetal/SuperNeoSerialization.swift",
        "return encodeCEOpeningResponse(tag: 2, openings: openings)",
        "return encodeCEOpeningResponse(tag: 3, openings: openings)",
        "Swift CE response encoder must map mask/masked/permuted to 0/1/2",
    )
    run_mutation(
        "SuperNeo-NuMetal/SuperNeoSerialization.swift",
        "case 2:\n            return .permutedWitness",
        "case 3:\n            return .permutedWitness",
        "Swift CE response parser must enforce count equality and 0/1/2 tag mapping",
    )
    run_mutation(
        "SuperNeo-NuMetalTests/SuperNeoNuMetalTests.swift",
        "XCTAssertEqual(bytes[responseTagOffset(round: 2)], 2)",
        "XCTAssertEqual(bytes[responseTagOffset(round: 2)], 3)",
        "permuted-witness tag byte fixture",
    )

    print("formal CE byte serialization validation regression tests passed")


if __name__ == "__main__":
    main()
