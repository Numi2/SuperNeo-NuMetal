#!/usr/bin/env python3
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
VALIDATOR = ROOT / "Scripts" / "validate-formal-profile-constants.py"


REQUIRED_FILES = [
    "Formal/SuperNeoFormal/Profile.lean",
    "Formal/SuperNeoFormal/ChallengeSampling.lean",
    "Formal/SuperNeoFormal/Serialization.lean",
    "SuperNeo-NuMetal/Fields/GoldilocksField.swift",
    "SuperNeo-NuMetal/Rings/CyclotomicRing54.swift",
    "SuperNeo-NuMetal/SuperNeoSerialization.swift",
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
        raise AssertionError(f"expected success, got {result.returncode}\nstdout={result.stdout}\nstderr={result.stderr}")


def require_failure_contains(result: subprocess.CompletedProcess[str], needle: str) -> None:
    if result.returncode == 0:
        raise AssertionError(f"expected failure containing {needle!r}, got success\nstdout={result.stdout}")
    combined = result.stdout + result.stderr
    if needle not in combined:
        raise AssertionError(f"expected failure containing {needle!r}\nstdout={result.stdout}\nstderr={result.stderr}")


def mutate(path: Path, old: str, new: str) -> None:
    text = path.read_text(encoding="utf-8")
    if old not in text:
        raise AssertionError(f"mutation source text not found in {path}: {old!r}")
    path.write_text(text.replace(old, new, 1), encoding="utf-8")


def main() -> None:
    require_success(run_validator(ROOT))

    with tempfile.TemporaryDirectory(prefix="superneo-formal-profile-") as tmp:
        temp_root = Path(tmp)
        copy_required_files(temp_root)
        mutate(
            temp_root / "Formal/SuperNeoFormal/Profile.lean",
            "def kappa : Nat := 18",
            "def kappa : Nat := 19",
        )
        require_failure_contains(run_validator(temp_root), "kappa mismatch")

    with tempfile.TemporaryDirectory(prefix="superneo-formal-profile-") as tmp:
        temp_root = Path(tmp)
        copy_required_files(temp_root)
        mutate(
            temp_root / "Formal/SuperNeoFormal/ChallengeSampling.lean",
            "{-2, -1, 0, 1, 2}",
            "{-2, -1, 0, 1, 3}",
        )
        require_failure_contains(run_validator(temp_root), "challengeCoefficientSet mismatch")

    with tempfile.TemporaryDirectory(prefix="superneo-formal-profile-") as tmp:
        temp_root = Path(tmp)
        copy_required_files(temp_root)
        mutate(
            temp_root / "Formal/SuperNeoFormal/Serialization.lean",
            "def proofEnvelopeMagic : UInt32LE :=\n  ⟨0x4E554D51, by native_decide⟩",
            "def proofEnvelopeMagic : UInt32LE :=\n  ⟨0x4E554D52, by native_decide⟩",
        )
        require_failure_contains(run_validator(temp_root), "proofEnvelopeMagic mismatch")

    with tempfile.TemporaryDirectory(prefix="superneo-formal-profile-") as tmp:
        temp_root = Path(tmp)
        copy_required_files(temp_root)
        mutate(
            temp_root / "Formal/SuperNeoFormal/Serialization.lean",
            "(proofEnvelopeTranscriptBindingEncode context).length = 137",
            "(proofEnvelopeTranscriptBindingEncode context).length = 136",
        )
        require_failure_contains(run_validator(temp_root), "proofEnvelopeTranscriptBindingLength mismatch")

    with tempfile.TemporaryDirectory(prefix="superneo-formal-profile-") as tmp:
        temp_root = Path(tmp)
        copy_required_files(temp_root)
        mutate(
            temp_root / "Formal/SuperNeoFormal/Serialization.lean",
            "| .terminalLocal => byteOfNat 2 (by native_decide)",
            "| .terminalLocal => byteOfNat 4 (by native_decide)",
        )
        require_failure_contains(run_validator(temp_root), "proofEnvelopeKind.terminalLocal mismatch")

    print("formal profile constant validation regression tests passed")


if __name__ == "__main__":
    main()
