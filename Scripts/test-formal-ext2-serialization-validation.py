#!/usr/bin/env python3
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
VALIDATOR = ROOT / "Scripts" / "validate-formal-ext2-serialization.py"


REQUIRED_FILES = [
    "Formal/SuperNeoFormal.lean",
    "Formal/SuperNeoFormal/Serialization.lean",
    "Formal/SuperNeoFormal/Ext2CallerSerialization.lean",
    "SuperNeo-NuMetal/Fields/GoldilocksField.swift",
    "SuperNeo-NuMetal/Rings/CyclotomicRing54.swift",
    "SuperNeo-NuMetal/SuperNeoSerialization.swift",
    "SuperNeo-NuMetal/CCS/CCS.swift",
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
    with tempfile.TemporaryDirectory(prefix="superneo-formal-ext2-") as tmp:
        temp_root = Path(tmp)
        copy_required_files(temp_root)
        mutate(temp_root / rel_path, old, new)
        require_failure_contains(run_validator(temp_root), expected_failure)


def main() -> None:
    require_success(run_validator(ROOT))

    run_mutation(
        "Formal/SuperNeoFormal/Serialization.lean",
        "goldilocksElementEncode value.1 ++ goldilocksElementEncode value.2",
        "goldilocksElementEncode value.2 ++ goldilocksElementEncode value.1",
        "Lean GoldilocksExt2 wire encoder must be c0 then c1",
    )
    run_mutation(
        "Formal/SuperNeoFormal/Serialization.lean",
        "goldilocksElementDecode? (bytes.take 8)",
        "goldilocksElementDecode? (bytes.drop 8)",
        "Lean GoldilocksExt2 wire decoder must split exact 16 bytes as c0 then c1",
    )
    run_mutation(
        "Formal/SuperNeoFormal/Serialization.lean",
        "(phi81Ext2CoefficientsWireEncode coefficients).length = phi81Degree * 16",
        "(phi81Ext2CoefficientsWireEncode coefficients).length = phi81Degree * 8",
        "Lean Phi81 Ext2 coefficient encoder must have degree * 16 byte length",
    )
    run_mutation(
        "Formal/SuperNeoFormal/Serialization.lean",
        "finVectorDecode? goldilocksExt2ElementDecode? 16 (n := phi81Degree) bytes",
        "finVectorDecode? goldilocksExt2ElementDecode? 8 (n := phi81Degree) bytes",
        "Lean Phi81 Ext2 coefficient decoder must use fixed 16-byte Ext2 chunks",
    )
    run_mutation(
        "Formal/SuperNeoFormal.lean",
        "import SuperNeoFormal.Ext2CallerSerialization",
        "import SuperNeoFormal.Serialization",
        "Top-level Lean target must import Ext2 caller serialization surface",
    )
    run_mutation(
        "Formal/SuperNeoFormal/Ext2CallerSerialization.lean",
        "countedFixedListParse? goldilocksExt2ElementDecode? 16 bytes",
        "countedFixedListParse? goldilocksExt2ElementDecode? 8 bytes",
        "Lean Swift Ext2 vector parser must use counted 16-byte Ext2 chunks",
    )
    run_mutation(
        "Formal/SuperNeoFormal/Ext2CallerSerialization.lean",
        "countedListEncode goldilocksExt2ElementEncode surface.pointCount surface.point",
        "countedListEncode goldilocksExt2ElementEncode surface.pointCount []",
        "Lean Swift point/evaluation caller grammar must cover Ext2 points",
    )
    run_mutation(
        "SuperNeo-NuMetal/Fields/GoldilocksField.swift",
        "c0.littleEndianBytes + c1.littleEndianBytes",
        "c1.littleEndianBytes + c0.littleEndianBytes",
        "Swift GoldilocksExt2 encoder must be c0 then c1",
    )
    run_mutation(
        "SuperNeo-NuMetal/Fields/GoldilocksField.swift",
        "self.c0 = try GoldilocksField(littleEndianBytes: bytes.prefix(8))",
        "self.c0 = try GoldilocksField(littleEndianBytes: bytes.suffix(8))",
        "Swift GoldilocksExt2 decoder must parse c0 from prefix(8)",
    )
    run_mutation(
        "SuperNeo-NuMetal/SuperNeoSerialization.swift",
        "try GoldilocksExt2(littleEndianBytes: readData(count: 16)[...])",
        "try GoldilocksExt2(littleEndianBytes: readData(count: 8)[...])",
        "Swift proof ByteReader must read exact 16-byte Ext2 chunks",
    )
    run_mutation(
        "SuperNeo-NuMetalTests/SuperNeoNuMetalTests.swift",
        "let expected = leBytes(c0Raw) + leBytes(c1Raw)",
        "let expected = leBytes(c1Raw) + leBytes(c0Raw)",
        "fixture c0 then c1 order",
    )
    run_mutation(
        "SuperNeo-NuMetalTests/SuperNeoNuMetalTests.swift",
        "let claimEvaluationCountOffset = claimPointCountOffset + encodedCountByteWidth + 16",
        "let claimEvaluationCountOffset = claimPointCountOffset + encodedCountByteWidth + 8",
        "CCS evaluation-claim Ext2 evaluation offset fixture",
    )
    run_mutation(
        "SuperNeo-NuMetalTests/SuperNeoNuMetalTests.swift",
        "let ceMatrixEvalCountOffset = cePointCountOffset + encodedCountByteWidth + 16",
        "let ceMatrixEvalCountOffset = cePointCountOffset + encodedCountByteWidth + 8",
        "CE instance Ext2 matrix-evaluation offset fixture",
    )

    print("formal Ext2 serialization validation regression tests passed")


if __name__ == "__main__":
    main()
