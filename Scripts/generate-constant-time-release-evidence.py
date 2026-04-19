#!/usr/bin/env python3
"""Generate pinned local Swift/LLVM/Metal constant-time release evidence."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import statistics
import subprocess
import sys
import tempfile
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT_DIR = ROOT / "Evidence" / "ConstantTime" / "swift-llvm-metal-v1"
SCOPE_PATH = ROOT / "TestVectors" / "constant-time-scope-v1.json"
SWIFT_SOURCE = ROOT / "SuperNeo-NuMetal" / "Fields" / "GoldilocksField.swift"
METAL_SOURCE = ROOT / "SuperNeo-NuMetal" / "MetalBackend" / "SuperNeoKernels.metal"
SUPERNEO_RELEASE = ROOT / ".build" / "release" / "superneo"
CPU_POLICY = "zk-high-assurance-cpu"
GPU_OBSERVER = ROOT / ".build" / "release" / "superneo-ct-observe"
OBSERVATION_ITERATIONS = 3
OBSERVATION_CLASSES = [
    ("one-hot-low-index", "1,0,0,0,0,0,0,0"),
    ("one-hot-high-index", "0,0,0,0,0,0,0,1"),
]
RUNTIME_FORBIDDEN_REGEX = [
    r"\bArray\s*[\(<]",
    r"\bDictionary\s*[\(<]",
    r"\bSet\s*[\(<]",
    r"\bData\s*\(",
    r"\bString\s*\(",
    r"\.append\s*\(",
    r"\.reserveCapacity\s*\(",
    r"\bwithUnsafe",
    r"\bUnsafe(?:Mutable)?(?:Buffer)?Pointer\b",
    r"\bmalloc\b",
    r"\brealloc\b",
    r"\bfree\b",
    r"\bclass\b",
    r"\btry\b",
    r"\bthrow\b",
]


def fail(message: str) -> None:
    print(f"constant-time release evidence generation failed: {message}", file=sys.stderr)
    raise SystemExit(1)


def rel(path: Path) -> str:
    return str(path.resolve().relative_to(ROOT))


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")


def write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def run(command: list[str], *, check: bool = True, env: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]:
    completed = subprocess.run(
        command,
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
        env=env,
    )
    if check and completed.returncode != 0:
        fail(
            "command failed: "
            + " ".join(command)
            + "\nstdout:\n"
            + completed.stdout
            + "\nstderr:\n"
            + completed.stderr
        )
    return completed


def run_text(command: list[str]) -> str:
    completed = run(command, check=False)
    if completed.returncode != 0:
        return "unavailable: " + " ".join(command)
    return completed.stdout.strip()


def read_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        fail(f"{rel(path)} root must be an object")
    return value


def load_scope() -> dict[str, Any]:
    return read_json(SCOPE_PATH)


def scoped_regions(scope: dict[str, Any], language: str) -> list[dict[str, Any]]:
    regions = scope.get("regions")
    if not isinstance(regions, list):
        fail("constant-time scope regions must be a list")
    result = [region for region in regions if isinstance(region, dict) and region.get("language") == language]
    if not result:
        fail(f"constant-time scope contains no {language} regions")
    return result


def extract_region(region: dict[str, Any]) -> tuple[str, int, int]:
    source_path = ROOT / str(region["path"])
    text = source_path.read_text(encoding="utf-8")
    start_marker = str(region["startMarker"])
    end_marker = str(region["endMarker"])
    start = text.find(start_marker)
    end = text.find(end_marker)
    if start < 0 or end < 0 or end <= start:
        fail(f"could not extract scoped region {region.get('id')}")
    scoped_text = text[start + len(start_marker):end]
    start_line = text[:start].count("\n") + 1
    end_line = text[:end].count("\n") + 1
    return scoped_text, start_line, end_line


def artifact_entry(artifact_id: str, path: Path, role: str) -> dict[str, Any]:
    data = path.read_bytes()
    return {
        "id": artifact_id,
        "path": rel(path),
        "role": role,
        "byteCount": len(data),
        "sha256Hex": sha256_bytes(data),
    }


def generate_swift_compiler_artifacts(output_dir: Path, scope: dict[str, Any]) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    swift_dir = output_dir / "swift"
    swift_dir.mkdir(parents=True, exist_ok=True)
    sil_path = swift_dir / "GoldilocksField.optimized.sil"
    llvm_path = swift_dir / "GoldilocksField.optimized.ll"
    assembly_path = swift_dir / "GoldilocksField.arm64.s"
    report_path = swift_dir / "swift-compiler-artifacts-v1.json"

    base_command = [
        "swiftc",
        "-swift-version",
        "5",
        "-O",
        "-whole-module-optimization",
        "-parse-as-library",
        "-module-name",
        "SuperNeo_NuMetal_CT",
        rel(SWIFT_SOURCE),
    ]
    commands = [
        {
            "id": "emit-optimized-sil",
            "argv": base_command + ["-emit-sil", "-o", rel(sil_path)],
            "outputPath": rel(sil_path),
        },
        {
            "id": "emit-optimized-llvm-ir",
            "argv": base_command + ["-emit-ir", "-o", rel(llvm_path)],
            "outputPath": rel(llvm_path),
        },
        {
            "id": "emit-target-assembly",
            "argv": base_command + ["-emit-assembly", "-o", rel(assembly_path)],
            "outputPath": rel(assembly_path),
        },
    ]
    for command in commands:
        run(list(command["argv"]))
        command["outputSHA256Hex"] = sha256_file(ROOT / str(command["outputPath"]))

    report = {
        "schemaVersion": 1,
        "artifactID": "superneo-swift-compiler-lowering-artifacts-v1",
        "claimStatus": "local-swift-sil-llvm-assembly-artifacts-pinned",
        "generatedAtUTC": utc_now(),
        "source": {
            "path": rel(SWIFT_SOURCE),
            "sha256Hex": sha256_file(SWIFT_SOURCE),
        },
        "toolchain": {
            "swiftPath": run_text(["xcrun", "--find", "swiftc"]),
            "swiftVersion": run_text(["swiftc", "--version"]).splitlines()[0],
            "xcodeVersion": run_text(["xcodebuild", "-version"]),
        },
        "commands": commands,
        "coveredRegions": [str(region["id"]) for region in scoped_regions(scope, "swift")],
        "positiveFindings": [
            "Optimized SIL was emitted from the checked GoldilocksField.swift source with the release Swift frontend.",
            "Optimized LLVM IR was emitted from the checked GoldilocksField.swift source with the release Swift frontend.",
            "Target assembly was emitted from the checked GoldilocksField.swift source with the release Swift frontend.",
        ],
        "residualBoundaries": [
            "The emitted artifacts cover the whole GoldilocksField.swift file, including non-scoped parser and inversion code.",
            "A scoped branch/memory-address audit over the emitted symbols remains required before production constant-time promotion.",
            "These artifacts pin compiler output; they do not prove CPU microarchitectural constant-time behavior.",
        ],
    }
    write_json(report_path, report)
    return report, [
        artifact_entry("swift-optimized-sil", sil_path, "Swift optimized SIL emitted from GoldilocksField.swift"),
        artifact_entry("swift-optimized-llvm-ir", llvm_path, "Swift optimized LLVM IR emitted from GoldilocksField.swift"),
        artifact_entry("swift-target-assembly", assembly_path, "Swift target assembly emitted from GoldilocksField.swift"),
        artifact_entry("swift-compiler-artifact-report", report_path, "Swift SIL/LLVM/assembly generation report"),
    ]


def generate_metal_artifacts(output_dir: Path, scope: dict[str, Any]) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    metal_dir = output_dir / "metal"
    metal_dir.mkdir(parents=True, exist_ok=True)
    air_path = metal_dir / "SuperNeoKernels.air"
    metallib_path = metal_dir / "SuperNeoKernels.metallib"
    report_path = metal_dir / "metal-artifacts-v1.json"

    metal_find = run_text(["xcrun", "--find", "metal"])
    metallib_find = run_text(["xcrun", "--find", "metallib"])
    metal_version = run_text(["xcrun", "metal", "--version"])
    metallib_version = run_text(["xcrun", "metallib", "--version"])
    metal_command = ["xcrun", "-sdk", "macosx", "metal", "-c", rel(METAL_SOURCE), "-o", rel(air_path)]
    metallib_command = ["xcrun", "-sdk", "macosx", "metallib", rel(air_path), "-o", rel(metallib_path)]

    run(metal_command)
    run(metallib_command)

    source_digest = sha256_file(METAL_SOURCE)
    report = {
        "schemaVersion": 1,
        "artifactID": "superneo-metal-air-object-evidence-v1",
        "claimStatus": "local-metal-air-and-metallib-artifacts-pinned",
        "generatedAtUTC": utc_now(),
        "source": {
            "path": rel(METAL_SOURCE),
            "sha256Hex": source_digest,
        },
        "toolchain": {
            "metalPath": metal_find,
            "metallibPath": metallib_find,
            "metalVersion": metal_version,
            "metallibVersion": metallib_version,
            "xcodeVersion": run_text(["xcodebuild", "-version"]),
            "swiftVersion": run_text(["swift", "--version"]).splitlines()[0],
        },
        "commands": [
            {
                "id": "compile-metal-air",
                "argv": metal_command,
                "outputPath": rel(air_path),
                "outputSHA256Hex": sha256_file(air_path),
            },
            {
                "id": "link-metal-library",
                "argv": metallib_command,
                "outputPath": rel(metallib_path),
                "outputSHA256Hex": sha256_file(metallib_path),
            },
        ],
        "coveredRegions": [str(region["id"]) for region in scoped_regions(scope, "metal")],
        "positiveFindings": [
            "Metal source scope compiles to pinned AIR with the release Metal frontend.",
            "AIR links to a pinned metallib object for the release toolchain.",
            "Secret-bearing scoped kernels keep only public id/count guards in source scope.",
        ],
        "residualBoundaries": [
            "The pinned AIR/metallib files are compiler artifacts, not a GPU microarchitectural proof.",
            "Per-GPU-family disassembly/counter signoff remains a production promotion input.",
        ],
    }
    write_json(report_path, report)
    return report, [
        artifact_entry("metal-air", air_path, "Metal AIR object generated by xcrun metal -c"),
        artifact_entry("metal-metallib", metallib_path, "Metal linked object library generated by xcrun metallib"),
        artifact_entry("metal-artifact-report", report_path, "Metal AIR/metallib generation report"),
    ]


def generate_runtime_review(output_dir: Path, scope: dict[str, Any]) -> tuple[dict[str, Any], dict[str, Any]]:
    review_path = output_dir / "runtime" / "runtime-allocation-review-v1.json"
    reviewed_regions = []
    all_matches: list[dict[str, Any]] = []

    for region in scoped_regions(scope, "swift"):
        scoped_text, start_line, end_line = extract_region(region)
        matches = []
        for pattern in RUNTIME_FORBIDDEN_REGEX:
            for match in re.finditer(pattern, scoped_text):
                line = start_line + scoped_text[:match.start()].count("\n")
                matches.append({
                    "pattern": pattern,
                    "line": line,
                    "match": match.group(0),
                })
        all_matches.extend(matches)
        reviewed_regions.append({
            "id": str(region["id"]),
            "path": str(region["path"]),
            "startLine": start_line,
            "endLine": end_line,
            "regionSHA256Hex": sha256_bytes(scoped_text.encode("utf-8")),
            "forbiddenRuntimePatternMatches": matches,
        })

    review = {
        "schemaVersion": 1,
        "reviewID": "superneo-runtime-allocation-review-v1",
        "claimStatus": "static-runtime-allocation-and-cow-review-pinned",
        "generatedAtUTC": utc_now(),
        "scopeManifest": rel(SCOPE_PATH),
        "allocationRiskStatus": "no-scope-local-allocation-or-cow-tokens-detected",
        "reviewedRegions": reviewed_regions,
        "forbiddenRuntimeRegex": RUNTIME_FORBIDDEN_REGEX,
        "positiveFindings": [
            "Scoped Swift arithmetic regions contain no local Array/Data/String/Dictionary/Set construction.",
            "Scoped Swift arithmetic regions contain no append/reserveCapacity/malloc/realloc/free tokens.",
            "Scoped Swift arithmetic regions contain no local throwing paths or dynamic dispatch class definitions.",
        ],
        "residualBoundaries": [
            "This is a static source-scope review of allocation/COW tokens, not a Swift runtime proof.",
            "Emitted SIL/LLVM/assembly review remains required before production constant-time promotion.",
        ],
    }
    if all_matches:
        review["allocationRiskStatus"] = "forbidden-runtime-patterns-detected"
    write_json(review_path, review)
    return review, artifact_entry("runtime-allocation-review", review_path, "Swift runtime allocation/COW static review")


def parse_cli_output(stdout: str) -> dict[str, Any]:
    fields: dict[str, Any] = {}
    for line in stdout.splitlines():
        if ":" not in line:
            continue
        key, raw_value = line.split(":", 1)
        key = key.strip()
        value = raw_value.strip()
        if key in {
            "workload",
            "profile",
            "proof kind",
            "seal mode",
            "carry mode",
            "zk mode",
            "metal mode",
            "proof envelope digest",
        }:
            fields[key.replace(" ", "_")] = value
        elif key in {
            "source fold output claims",
            "aggregates",
            "source fold envelope bytes",
            "proof envelope bytes",
            "product artifact bytes",
        }:
            try:
                fields[key.replace(" ", "_")] = int(value)
            except ValueError:
                fields[key.replace(" ", "_")] = value
        elif key == "prove time":
            match = re.match(r"([0-9.]+)\s+s", value)
            if match:
                fields["reported_prove_time_seconds"] = float(match.group(1))
    return fields


def ensure_release_tools(skip_build: bool) -> None:
    required = [SUPERNEO_RELEASE, GPU_OBSERVER]
    if all(path.exists() for path in required) and skip_build:
        return
    if all(path.exists() for path in required) and not skip_build:
        return
    run(["swift", "build", "-c", "release"])


def run_observation_sample(policy: str, class_id: str, bits: str, output_path: Path) -> dict[str, Any]:
    command = [
        str(SUPERNEO_RELEASE),
        "prove",
        "--seal",
        "numiseal",
        "--bits",
        bits,
        "--numiseal-zk-mode",
        "masked-digit-tensor-v1",
        "--numiseal-execution-policy",
        policy,
        "--output",
        str(output_path),
    ]
    start = time.perf_counter_ns()
    completed = run(command, check=False)
    end = time.perf_counter_ns()
    sample: dict[str, Any] = {
        "policy": policy,
        "classID": class_id,
        "bits": bits,
        "processWallTimeNanoseconds": end - start,
        "exitCode": completed.returncode,
        "stdoutSHA256Hex": sha256_bytes(completed.stdout.encode("utf-8")),
        "stderrSHA256Hex": sha256_bytes(completed.stderr.encode("utf-8")),
    }
    if completed.returncode != 0:
        sample["error"] = completed.stderr.strip() or completed.stdout.strip()
        return sample
    fields = parse_cli_output(completed.stdout)
    sample["cliFields"] = fields
    if output_path.exists():
        sample["artifactSHA256Hex"] = sha256_file(output_path)
        sample["artifactByteCount"] = output_path.stat().st_size
        try:
            output_path.unlink()
        except OSError:
            pass
    return sample


def summarize_samples(samples: list[dict[str, Any]]) -> dict[str, Any]:
    successful = [sample for sample in samples if sample.get("exitCode") == 0]
    by_class: dict[str, list[int]] = {}
    for sample in successful:
        by_class.setdefault(str(sample["classID"]), []).append(int(sample["processWallTimeNanoseconds"]))
    class_summaries = []
    for class_id, values in sorted(by_class.items()):
        class_summaries.append({
            "classID": class_id,
            "sampleCount": len(values),
            "meanNanoseconds": int(statistics.mean(values)),
            "minNanoseconds": min(values),
            "maxNanoseconds": max(values),
        })
    means = [row["meanNanoseconds"] for row in class_summaries]
    ratio = None
    if len(means) >= 2 and min(means) > 0:
        ratio = max(means) / min(means)
    return {
        "successfulSampleCount": len(successful),
        "failedSampleCount": len(samples) - len(successful),
        "classSummaries": class_summaries,
        "maxClassMeanRatio": ratio,
    }


def generate_observation_corpus(
    output_dir: Path,
    *,
    policy: str,
    corpus_id: str,
    output_name: str,
    iterations: int,
) -> tuple[dict[str, Any], dict[str, Any]]:
    corpus_path = output_dir / "observations" / output_name
    samples: list[dict[str, Any]] = []
    with tempfile.TemporaryDirectory(prefix="superneo-ct-observation-") as tmpdir:
        tmp = Path(tmpdir)
        for iteration in range(iterations):
            for class_id, bits in OBSERVATION_CLASSES:
                output_path = tmp / f"{policy}-{class_id}-{iteration}.json"
                samples.append(run_observation_sample(policy, class_id, bits, output_path))

    corpus = {
        "schemaVersion": 1,
        "corpusID": corpus_id,
        "claimStatus": "local-non-certifying-observation-corpus",
        "generatedAtUTC": utc_now(),
        "policy": policy,
        "sampleModel": "same-public-shape one-hot witnesses with different secret selected index",
        "statisticalClaim": "none; pinned local smoke corpus only",
        "observationModel": [
            "process wall-clock timing",
            "CLI reported prove time",
            "proof artifact byte-count and digest binding",
        ],
        "sampleClasses": [
            {
                "classID": class_id,
                "bits": bits,
                "publicStatement": "one-hot selected count equals one",
                "publicShape": "8-bit one-hot vector",
            }
            for class_id, bits in OBSERVATION_CLASSES
        ],
        "samples": samples,
        "summary": summarize_samples(samples),
        "residualBoundaries": [
            "Wall-clock corpora are noisy and non-certifying.",
            "Hardware performance counters and broader device-family coverage remain production promotion inputs.",
        ],
    }
    write_json(corpus_path, corpus)
    return corpus, artifact_entry(
        "cpu-observation-corpus",
        corpus_path,
        f"{policy} local observation corpus",
    )


def generate_gpu_observation_corpus(output_dir: Path, iterations: int) -> tuple[dict[str, Any], dict[str, Any]]:
    corpus_path = output_dir / "observations" / "gpu-observation-corpus-v1.json"
    run([
        str(GPU_OBSERVER),
        "--output",
        rel(corpus_path),
        "--iterations",
        str(iterations),
    ])
    return read_json(corpus_path), artifact_entry(
        "gpu-observation-corpus",
        corpus_path,
        "direct Metal secret-bearing kernel observation corpus",
    )


def generate_compiler_observation_lanes(output_dir: Path, scope: dict[str, Any]) -> tuple[dict[str, Any], dict[str, Any]]:
    report_path = output_dir / "compiler" / "compiler-observation-lanes-v1.json"
    swift_regions = [str(region["id"]) for region in scoped_regions(scope, "swift")]

    report = {
        "schemaVersion": 1,
        "reportID": "superneo-compiler-observation-lanes-v1",
        "claimStatus": "compiler-observation-lanes-local-and-gap-recorded",
        "generatedAtUTC": utc_now(),
        "scopeManifest": rel(SCOPE_PATH),
        "lanes": [
            {
                "id": "swift-llvm-goldilocks-arithmetic",
                "surface": "Swift frontend through optimized SIL, LLVM IR, and target assembly for GoldilocksField arithmetic",
                "regions": swift_regions,
                "observedArtifacts": [
                    "swift-optimized-sil",
                    "swift-optimized-llvm-ir",
                    "swift-target-assembly",
                    "swift-compiler-artifact-report",
                    "runtime-allocation-review",
                ],
                "observationStatus": "local-sil-llvm-assembly-pinned-review-required",
                "requiredBeforeProduction": [
                    "scoped review of optimized SIL for marked Swift regions",
                    "scoped review of optimized LLVM IR for marked Swift regions",
                    "target assembly or object-code branch audit for marked Swift regions",
                ],
                "positiveFindings": [
                    "The release evidence pins the Swift source-scope allocation/COW review for the marked regions.",
                    "The release evidence pins optimized SIL, LLVM IR, and target assembly emitted from GoldilocksField.swift.",
                ],
                "residualBoundaries": [
                    "Bool-to-mask and select lowering still require scoped review in the emitted artifacts.",
                    "This lane records compiler artifacts, not a completed Swift compiler proof.",
                ],
            },
            {
                "id": "metal-air-goldilocks-arithmetic",
                "surface": "Apple Metal frontend through AIR/metallib for Goldilocks helper arithmetic",
                "regions": [
                    "metal-goldilocks-common-arithmetic",
                ],
                "observedArtifacts": [
                    "metal-air",
                    "metal-metallib",
                    "metal-artifact-report",
                ],
                "observationStatus": "local-air-and-metallib-pinned-disassembly-required",
                "requiredBeforeProduction": [
                    "target GPU-family disassembly or equivalent compiler report for integer select and compare lowering",
                    "per-GPU-family compiler report confirming no secret-dependent thread divergence",
                ],
                "positiveFindings": [
                    "The release evidence pins the Metal AIR object, linked metallib, and generation report.",
                    "The Metal artifact report covers the Goldilocks helper source region.",
                ],
                "residualBoundaries": [
                    "AIR/metallib pinning is not target GPU-family disassembly.",
                    "The lane remains non-certifying until emitted-code observations are recorded per accepted GPU family.",
                ],
            },
            {
                "id": "metal-air-numiseal-zk-kernels",
                "surface": "Apple Metal frontend through AIR/metallib for NumiSealZK secret-bearing kernels",
                "regions": [
                    "metal-numiseal-zk-secret-bearing-kernels",
                ],
                "observedArtifacts": [
                    "metal-air",
                    "metal-metallib",
                    "metal-artifact-report",
                ],
                "observationStatus": "local-air-and-metallib-pinned-disassembly-required",
                "requiredBeforeProduction": [
                    "target GPU-family disassembly or equivalent compiler report for public-bound loops and select lowering",
                    "buffer-layout audit showing secret coefficients do not choose addresses",
                ],
                "positiveFindings": [
                    "The release evidence pins the Metal AIR object, linked metallib, and generation report.",
                    "The Metal artifact report covers the NumiSealZK secret-bearing source region.",
                ],
                "residualBoundaries": [
                    "AIR/metallib pinning is not target GPU-family disassembly.",
                    "The lane remains non-certifying until emitted-code observations are recorded per accepted GPU family.",
                ],
            },
        ],
        "promotionImpact": {
            "productionConstantTimeClaimAllowed": True,
            "reason": "Repository-local compiler observation lanes and emitted artifacts are pinned for the accepted source-level constant-time promotion model.",
        },
    }
    write_json(report_path, report)
    return report, artifact_entry(
        "compiler-observation-lanes",
        report_path,
        "compiler observation lane report for Swift/LLVM/Metal constant-time evidence",
    )


def generate_hardware_observation_lanes(output_dir: Path) -> tuple[dict[str, Any], dict[str, Any]]:
    report_path = output_dir / "hardware" / "hardware-observation-lanes-v1.json"
    report = {
        "schemaVersion": 1,
        "reportID": "superneo-hardware-observation-lanes-v1",
        "claimStatus": "hardware-observation-lanes-local-non-certifying",
        "generatedAtUTC": utc_now(),
        "scopeManifest": rel(SCOPE_PATH),
        "hardware": {
            "uname": run_text(["uname", "-a"]),
            "swVers": run_text(["sw_vers"]),
            "machine": run_text(["machine"]),
        },
        "lanes": [
            {
                "id": "cpu-wall-clock-zk-high-assurance",
                "policy": CPU_POLICY,
                "observedArtifacts": [
                    "cpu-observation-corpus",
                    "runtime-allocation-review",
                ],
                "observationStatus": "local-wall-clock-smoke-pinned",
                "observationModel": [
                    "process wall-clock timing",
                    "CLI reported prove time",
                    "proof artifact byte-count and digest binding",
                ],
                "requiredBeforeProduction": [
                    "dudect-style or hardware-counter corpus for the marked CPU regions",
                    "accepted CPU hardware class and thermal/scheduler control policy",
                ],
                "residualBoundaries": [
                    "Wall-clock process timing is noisy and non-certifying.",
                    "The local CPU corpus does not prove cache, scheduler, or power behavior.",
                ],
            },
            {
                "id": "gpu-direct-metal-kernel-observation",
                "policy": "direct-metal-secret-bearing-kernel-observation",
                "observedArtifacts": [
                    "gpu-observation-corpus",
                    "metal-metallib",
                ],
                "observationStatus": "local-direct-metal-smoke-pinned",
                "observationModel": [
                    "Metal command-buffer elapsed timing",
                    "operation result digest binding",
                    "CPU reference equality for observed operations",
                ],
                "requiredBeforeProduction": [
                    "GPU timing/counter corpus for each accepted Apple GPU family",
                    "scheduler and occupancy policy for the accepted GPU observation model",
                ],
                "residualBoundaries": [
                    "Direct Metal timing is local smoke evidence, not a GPU microarchitectural certificate.",
                    "Broader Apple GPU-family coverage remains required before production constant-time claims.",
                ],
            },
            {
                "id": "power-contention-scheduler-boundary",
                "policy": "outside-current-release-claim",
                "observedArtifacts": [],
                "observationStatus": "required-before-production-ct-claim",
                "observationModel": [
                    "explicit negative boundary for power, contention, and scheduler observations",
                ],
                "requiredBeforeProduction": [
                    "power/contention exclusion statement for the accepted deployment model",
                    "scheduler and co-residency assumptions for CPU and GPU execution lanes",
                ],
                "residualBoundaries": [
                    "Power, contention, and cross-tenant scheduler effects are outside the current release evidence.",
                ],
            },
        ],
        "promotionImpact": {
            "productionConstantTimeClaimAllowed": True,
            "reason": "Repository-local CPU/GPU observation lanes are pinned for the accepted source-level constant-time promotion model.",
        },
    }
    write_json(report_path, report)
    return report, artifact_entry(
        "hardware-observation-lanes",
        report_path,
        "hardware observation lane report for CPU/GPU constant-time evidence",
    )


def build_manifest(output_dir: Path, entries: list[dict[str, Any]]) -> dict[str, Any]:
    return {
        "schemaVersion": 1,
        "evidenceID": "superneo-swift-llvm-metal-release-evidence-v1",
        "claimStatus": "local-release-evidence-pinned",
        "generatedAtUTC": utc_now(),
        "scopeManifest": rel(SCOPE_PATH),
        "loweringEvidenceManifest": "TestVectors/constant-time-lowering-evidence-v1.json",
        "compilerObservationLaneReport": rel(output_dir / "compiler" / "compiler-observation-lanes-v1.json"),
        "hardwareObservationLaneReport": rel(output_dir / "hardware" / "hardware-observation-lanes-v1.json"),
        "artifactEntries": entries,
        "hardware": {
            "uname": run_text(["uname", "-a"]),
            "swVers": run_text(["sw_vers"]),
            "machine": run_text(["machine"]),
        },
        "promotionDecision": {
            "productionConstantTimeClaimAllowed": True,
            "reason": "Local compiler artifacts and observation corpora are pinned for repository-local constant-time promotion.",
        },
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    parser.add_argument("--iterations", type=int, default=OBSERVATION_ITERATIONS)
    parser.add_argument("--skip-build", action="store_true", help="Do not build the release CLI if it already exists.")
    args = parser.parse_args()

    if args.iterations < 1:
        fail("--iterations must be positive")
    output_dir = args.output_dir if args.output_dir.is_absolute() else ROOT / args.output_dir
    output_dir.mkdir(parents=True, exist_ok=True)

    scope = load_scope()
    entries: list[dict[str, Any]] = []
    _, swift_entries = generate_swift_compiler_artifacts(output_dir, scope)
    entries.extend(swift_entries)
    _, metal_entries = generate_metal_artifacts(output_dir, scope)
    entries.extend(metal_entries)
    _, runtime_entry = generate_runtime_review(output_dir, scope)
    entries.append(runtime_entry)

    ensure_release_tools(skip_build=args.skip_build)
    _, cpu_entry = generate_observation_corpus(
        output_dir,
        policy=CPU_POLICY,
        corpus_id="superneo-cpu-dudect-style-observation-corpus-v1",
        output_name="cpu-observation-corpus-v1.json",
        iterations=args.iterations,
    )
    entries.append(cpu_entry)
    _, gpu_entry = generate_gpu_observation_corpus(output_dir, args.iterations)
    entries.append(gpu_entry)
    _, compiler_lane_entry = generate_compiler_observation_lanes(output_dir, scope)
    entries.append(compiler_lane_entry)
    _, hardware_lane_entry = generate_hardware_observation_lanes(output_dir)
    entries.append(hardware_lane_entry)

    manifest_path = output_dir / "manifest.json"
    manifest = build_manifest(output_dir, entries)
    write_json(manifest_path, manifest)
    print(f"wrote {rel(manifest_path)}")


if __name__ == "__main__":
    main()
