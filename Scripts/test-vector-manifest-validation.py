#!/usr/bin/env python3
import copy
import hashlib
import json
import os
import shutil
import subprocess
import tempfile
from pathlib import Path
from typing import Any, Callable


ROOT = Path(__file__).resolve().parents[1]
VALIDATOR = ROOT / "Scripts" / "validate-test-vectors.swift"
VECTORS = ROOT / "TestVectors"
MANIFEST = VECTORS / "manifest.json"


def load_manifest() -> dict[str, Any]:
    return json.loads(MANIFEST.read_text(encoding="utf-8"))


def write_manifest(path: Path, manifest: dict[str, Any]) -> None:
    path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def replace_once(text: str, old: str, new: str) -> str:
    if old not in text:
        raise AssertionError(f"mutation marker missing: {old!r}")
    return text.replace(old, new, 1)


def run_mutated_validator(
    mutation: Callable[[dict[str, Any], Path], None],
) -> subprocess.CompletedProcess[str]:
    manifest = load_manifest()
    with tempfile.TemporaryDirectory(prefix="superneo-vector-manifest-") as raw_tmp:
        temp_root = Path(raw_tmp)
        scripts_dir = temp_root / "Scripts"
        vectors_dir = temp_root / "TestVectors"
        scripts_dir.mkdir()
        vectors_dir.mkdir()
        shutil.copy2(VALIDATOR, scripts_dir / "validate-test-vectors.swift")
        shutil.copy2(VECTORS / manifest["schema"], vectors_dir / manifest["schema"])
        for vector in manifest["vectors"]:
            os.symlink((VECTORS / vector["file"]).resolve(), vectors_dir / vector["file"])

        mutation(manifest, vectors_dir)
        manifest_path = vectors_dir / "manifest.json"
        if not manifest_path.exists():
            write_manifest(manifest_path, manifest)

        return subprocess.run(
            ["swift", str(scripts_dir / "validate-test-vectors.swift"), str(temp_root)],
            cwd=ROOT,
            check=False,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )


def expect_failure(
    name: str,
    mutation: Callable[[dict[str, Any], Path], None],
    expected_output: str,
) -> None:
    result = run_mutated_validator(mutation)
    combined_output = result.stdout + result.stderr
    if result.returncode == 0:
        raise AssertionError(f"{name}: validator succeeded unexpectedly")
    if expected_output not in combined_output:
        raise AssertionError(
            f"{name}: expected output to contain {expected_output!r}, got {combined_output!r}"
        )


def duplicate_manifest_entry(manifest: dict[str, Any], _: Path) -> None:
    manifest["vectors"].append(copy.deepcopy(manifest["vectors"][0]))


def duplicate_manifest_json_key(manifest: dict[str, Any], vectors_dir: Path) -> None:
    text = json.dumps(manifest, indent=2, sort_keys=True) + "\n"
    profile_line = f'  "profile": {json.dumps(manifest["profile"])},\n'
    replacement = profile_line + f'  "profile": {json.dumps(manifest["profile"])},\n'
    (vectors_dir / "manifest.json").write_text(
        replace_once(text, profile_line, replacement),
        encoding="utf-8",
    )


def unknown_manifest_top_level_key(manifest: dict[str, Any], _: Path) -> None:
    manifest["unexpectedTrustAnchor"] = "ignored-by-default-decoder"


def unknown_manifest_vector_key(manifest: dict[str, Any], _: Path) -> None:
    manifest["vectors"][0]["unexpectedTrustAnchor"] = "ignored-by-default-decoder"


def duplicate_verify_command(manifest: dict[str, Any], _: Path) -> None:
    manifest["vectors"][1]["verifyCommand"] = manifest["vectors"][0]["verifyCommand"]


def unsupported_proof_kind(manifest: dict[str, Any], _: Path) -> None:
    manifest["vectors"][0]["proofKind"] = "compressed"


def missing_compressed_coverage(manifest: dict[str, Any], vectors_dir: Path) -> None:
    manifest["vectors"] = [
        vector
        for vector in manifest["vectors"]
        if vector["file"] != "one-hot-vector-compressed-terminal-v1.json"
    ]
    (vectors_dir / "one-hot-vector-compressed-terminal-v1.json").unlink()


def unmanifested_checked_vector(_: dict[str, Any], vectors_dir: Path) -> None:
    os.symlink(
        (VECTORS / "one-hot-vector-fold-v1.json").resolve(),
        vectors_dir / "unmanifested-extra-v1.json",
    )


def duplicate_artifact_json_key(manifest: dict[str, Any], vectors_dir: Path) -> None:
    file_name = "one-hot-vector-fold-v1.json"
    vector_path = vectors_dir / file_name
    vector_path.unlink()
    text = (VECTORS / file_name).read_text(encoding="utf-8")
    marker = '    "selectedCount": "1"\n'
    vector_path.write_text(
        replace_once(text, marker, '    "selectedCount": "1",\n' + marker),
        encoding="utf-8",
    )
    data = vector_path.read_bytes()
    for vector in manifest["vectors"]:
        if vector["file"] == file_name:
            vector["byteCount"] = len(data)
            vector["sha256"] = hashlib.sha256(data).hexdigest()
            return
    raise AssertionError(f"{file_name} missing from manifest")


def main() -> None:
    expect_failure(
        "duplicate manifest entry",
        duplicate_manifest_entry,
        "appears more than once in manifest",
    )
    expect_failure(
        "duplicate manifest JSON key",
        duplicate_manifest_json_key,
        "manifest.json contains duplicate JSON object key 'profile' at $",
    )
    expect_failure(
        "unknown manifest top-level key",
        unknown_manifest_top_level_key,
        "manifest.json contains unknown top-level fields: unexpectedTrustAnchor",
    )
    expect_failure(
        "unknown manifest vector key",
        unknown_manifest_vector_key,
        "manifest.json vectors[0] contains unknown fields: unexpectedTrustAnchor",
    )
    expect_failure(
        "duplicate verify command",
        duplicate_verify_command,
        "verify command duplicates another vector",
    )
    expect_failure(
        "unsupported proof kind",
        unsupported_proof_kind,
        "unsupported proof kind",
    )
    expect_failure(
        "missing compressed-terminal coverage",
        missing_compressed_coverage,
        "manifest missing required vector coverage",
    )
    expect_failure(
        "unmanifested checked vector",
        unmanifested_checked_vector,
        "checked vector file(s) missing from manifest",
    )
    expect_failure(
        "duplicate artifact JSON key",
        duplicate_artifact_json_key,
        "one-hot-vector-fold-v1.json contains duplicate JSON object key 'selectedCount' at $.workloadParameters",
    )
    print("vector manifest validation regression tests passed")


if __name__ == "__main__":
    main()
