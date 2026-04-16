#!/usr/bin/env python3
import argparse
import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any, Dict, List


ROOT = Path(__file__).resolve().parents[1]
VECTORS_DIR = ROOT / "TestVectors"
MANIFEST_FILE = "numiseal-manifest.json"
SCHEMA_FILE = "numiseal-artifact.schema.json"
REQUIRED_VECTOR_FILES = {
    "numiseal-terminal-single-aggregate-v1.json",
    "numiseal-terminal-two-aggregate-v1.json",
    "numiseal-terminal-two-lane-v1.json",
}
ZERO_DIGEST = "0" * 64


def fail(message: str) -> None:
    print(f"error: {message}", file=sys.stderr)
    raise SystemExit(1)


def load_json(path: Path) -> Dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        value = json.load(handle)
    if not isinstance(value, dict):
        fail(f"{path} did not decode to a JSON object")
    return value


def write_json(path: Path, value: Dict[str, Any]) -> None:
    with path.open("w", encoding="utf-8") as handle:
        json.dump(value, handle, indent=2, sort_keys=True)
        handle.write("\n")


def run_expect_failure(command: List[str], expected: str) -> None:
    result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True)
    combined = result.stdout + result.stderr
    if result.returncode == 0:
        fail(f"expected command to fail but it succeeded: {' '.join(command)}")
    if expected not in combined:
        fail(
            f"expected failure output to contain {expected!r}\n"
            f"command: {' '.join(command)}\n"
            f"stdout:\n{result.stdout}\n"
            f"stderr:\n{result.stderr}"
        )


def copy_numiseal_vectors(destination_root: Path) -> Path:
    destination = destination_root / "TestVectors"
    destination.mkdir(parents=True)
    shutil.copy2(VECTORS_DIR / SCHEMA_FILE, destination / SCHEMA_FILE)
    shutil.copy2(VECTORS_DIR / MANIFEST_FILE, destination / MANIFEST_FILE)
    for file in REQUIRED_VECTOR_FILES:
        shutil.copy2(VECTORS_DIR / file, destination / file)
    return destination


def manifest_vectors(manifest: Dict[str, Any]) -> List[Dict[str, Any]]:
    vectors = manifest.get("vectors")
    if not isinstance(vectors, list) or not all(isinstance(item, dict) for item in vectors):
        fail("NumiSeal manifest vectors must be an array of objects")
    files = {item.get("file") for item in vectors}
    missing = sorted(REQUIRED_VECTOR_FILES - files)
    if missing:
        fail(f"baseline NumiSeal manifest is missing required vectors: {','.join(missing)}")
    return vectors


def test_manifest_metadata_negative(cli: Path, vector: Dict[str, Any]) -> None:
    file = vector["file"]
    with tempfile.TemporaryDirectory(prefix="superneo-numiseal-manifest-") as tmp:
        temp_root = Path(tmp)
        temp_vectors = copy_numiseal_vectors(temp_root)
        manifest = load_json(temp_vectors / MANIFEST_FILE)
        for item in manifest_vectors(manifest):
            if item["file"] == file:
                item["workload"] = f"{item['workload']}-tampered"
                break
        write_json(temp_vectors / MANIFEST_FILE, manifest)
        run_expect_failure(
            [str(cli), "validate", str(temp_root)],
            f"{file} unsupported NumiSeal workload",
        )


def test_artifact_metadata_negative(cli: Path, vector: Dict[str, Any]) -> None:
    file = vector["file"]
    artifact = load_json(VECTORS_DIR / file)
    artifact["proofKind"] = "terminal"
    with tempfile.TemporaryDirectory(prefix="superneo-numiseal-artifact-") as tmp:
        temp_artifact = Path(tmp) / file
        write_json(temp_artifact, artifact)
        run_expect_failure(
            [str(cli), "validate", str(temp_artifact), str(ROOT)],
            f"{file} unsupported proof kind",
        )


def test_manifest_obligation_root_negative(cli: Path, vector: Dict[str, Any]) -> None:
    file = vector["file"]
    with tempfile.TemporaryDirectory(prefix="superneo-numiseal-obligation-root-") as tmp:
        temp_root = Path(tmp)
        temp_vectors = copy_numiseal_vectors(temp_root)
        manifest = load_json(temp_vectors / MANIFEST_FILE)
        for item in manifest_vectors(manifest):
            if item["file"] == file:
                original = item["expectedObligationRootHex"]
                item["expectedObligationRootHex"] = ZERO_DIGEST
                item["verifyCommand"] = item["verifyCommand"].replace(original, ZERO_DIGEST)
                break
        write_json(temp_vectors / MANIFEST_FILE, manifest)
        run_expect_failure(
            [str(cli), "validate", str(temp_root)],
            f"{file} obligation root mismatch",
        )


def test_manifest_lane_summary_root_negative(cli: Path, vector: Dict[str, Any]) -> None:
    file = vector["file"]
    with tempfile.TemporaryDirectory(prefix="superneo-numiseal-lane-summary-root-") as tmp:
        temp_root = Path(tmp)
        temp_vectors = copy_numiseal_vectors(temp_root)
        manifest = load_json(temp_vectors / MANIFEST_FILE)
        for item in manifest_vectors(manifest):
            if item["file"] == file:
                original = item["expectedLaneSummaryRootHex"]
                item["expectedLaneSummaryRootHex"] = ZERO_DIGEST
                item["verifyCommand"] = item["verifyCommand"].replace(original, ZERO_DIGEST)
                break
        write_json(temp_vectors / MANIFEST_FILE, manifest)
        run_expect_failure(
            [str(cli), "validate", str(temp_root)],
            f"{file} lane summary root mismatch",
        )


def test_manifest_legacy_verify_command_negative(cli: Path, vector: Dict[str, Any]) -> None:
    file = vector["file"]
    with tempfile.TemporaryDirectory(prefix="superneo-numiseal-legacy-command-") as tmp:
        temp_root = Path(tmp)
        temp_vectors = copy_numiseal_vectors(temp_root)
        manifest = load_json(temp_vectors / MANIFEST_FILE)
        for item in manifest_vectors(manifest):
            if item["file"] == file:
                item["verifyCommand"] = f"swift run superneo-numiseal-vectors validate TestVectors/{file}"
                break
        write_json(temp_vectors / MANIFEST_FILE, manifest)
        run_expect_failure(
            [str(cli), "validate", str(temp_root)],
            f"{file} verify command mismatch",
        )


def test_manifest_verify_command_requires_numiseal_negative(cli: Path, vector: Dict[str, Any]) -> None:
    file = vector["file"]
    with tempfile.TemporaryDirectory(prefix="superneo-numiseal-command-guard-") as tmp:
        temp_root = Path(tmp)
        temp_vectors = copy_numiseal_vectors(temp_root)
        manifest = load_json(temp_vectors / MANIFEST_FILE)
        for item in manifest_vectors(manifest):
            if item["file"] == file:
                item["verifyCommand"] = item["verifyCommand"].replace(" --require-numiseal", "")
                break
        write_json(temp_vectors / MANIFEST_FILE, manifest)
        run_expect_failure(
            [str(cli), "validate", str(temp_root)],
            f"{file} verify command mismatch",
        )


def main() -> None:
    parser = argparse.ArgumentParser(description="Mutation-test NumiSeal vector validation fail-closed behavior.")
    parser.add_argument(
        "--cli",
        default=str(ROOT / ".build" / "release" / "superneo-numiseal-vectors"),
        help="Path to the built superneo-numiseal-vectors executable.",
    )
    args = parser.parse_args()
    cli = Path(args.cli)
    if not cli.exists():
        fail(f"NumiSeal vector CLI does not exist: {cli}")

    manifest = load_json(VECTORS_DIR / MANIFEST_FILE)
    vectors = manifest_vectors(manifest)
    for vector in vectors:
        if vector["file"] in REQUIRED_VECTOR_FILES:
            test_manifest_metadata_negative(cli, vector)
            test_artifact_metadata_negative(cli, vector)
            test_manifest_obligation_root_negative(cli, vector)
            test_manifest_lane_summary_root_negative(cli, vector)
            test_manifest_legacy_verify_command_negative(cli, vector)
            test_manifest_verify_command_requires_numiseal_negative(cli, vector)

    print("NumiSeal vector validation regression tests passed")


if __name__ == "__main__":
    main()
