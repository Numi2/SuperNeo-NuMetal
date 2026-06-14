#!/usr/bin/env python3
"""Validate the same-hardware competitive performance comparison artifact."""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "TestVectors" / "competitive-performance-comparison-v1.json"
DOSSIER = ROOT / "TestVectors" / "product-crypto-security-dossier-v1.json"

EXPECTED_COLUMNS = {
    "proof bytes",
    "prover time",
    "verifier time",
    "peak memory",
    "recursion overhead",
    "Metal vs CPU cost",
    "ZK overhead",
    "parameter-security level",
}
EXPECTED_SYSTEM_IDS = {
    "superneo-numiseal-terminal",
    "latticefold-e2e",
    "winterfell-lamport-a-64",
}


def fail(message: str) -> None:
    print(f"competitive performance comparison validation failed: {message}", file=sys.stderr)
    raise SystemExit(1)


def require(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def require_dict(value: Any, label: str) -> dict[str, Any]:
    require(isinstance(value, dict), f"{label} must be an object")
    return value


def require_list(value: Any, label: str) -> list[Any]:
    require(isinstance(value, list), f"{label} must be a list")
    return value


def require_string(value: Any, label: str) -> str:
    require(isinstance(value, str) and value, f"{label} must be a non-empty string")
    return value


def require_float(value: Any, label: str) -> float:
    require(isinstance(value, (int, float)), f"{label} must be numeric")
    return float(value)


def require_int(value: Any, label: str) -> int:
    require(isinstance(value, int), f"{label} must be an integer")
    return value


def approx_equal(left: float, right: float, *, tolerance: float = 1e-4) -> bool:
    return abs(left - right) <= tolerance


def read_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        fail(f"{path} is not valid JSON: {error}")
    return require_dict(value, str(path))


def parse_duration_ms(cell: str) -> float:
    value = require_string(cell.strip(), "benchmark duration")
    number_text, unit = value.split(" ", 1)
    number = float(number_text)
    unit = unit.strip()
    factors = {
        "ns": 1e-6,
        "us": 1e-3,
        "ms": 1.0,
        "s": 1000.0,
        "μs": 1e-3,
        "µs": 1e-3,
    }
    require(unit in factors, f"unsupported benchmark duration unit: {unit}")
    return number * factors[unit]


def parse_benchmark_rows(path: Path) -> dict[str, float]:
    rows: dict[str, float] = {}
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line.startswith("| `"):
            continue
        cells = [cell.strip() for cell in line.split("|")[1:-1]]
        if len(cells) < 2:
            continue
        label = cells[0].strip("`")
        duration = cells[1]
        if duration:
            rows[label] = parse_duration_ms(duration)
    return rows


def validate_superneo(system: dict[str, Any], rows: dict[str, float], dossier: dict[str, Any]) -> None:
    proof = require_dict(system.get("proofBytes"), "superneo.proofBytes")
    proof_envelope = require_int(proof.get("proofEnvelopeBytes"), "superneo.proofBytes.proofEnvelopeBytes")
    artifact_bytes = require_int(proof.get("artifactBytes"), "superneo.proofBytes.artifactBytes")
    source_fold_bytes = require_int(
        proof.get("sourceFoldEnvelopeBytes"),
        "superneo.proofBytes.sourceFoldEnvelopeBytes",
    )
    require(proof_envelope > 0 and artifact_bytes > proof_envelope and source_fold_bytes > proof_envelope, "superneo proof-byte ordering is invalid")

    prover = require_dict(system.get("proverTime"), "superneo.proverTime")
    prover_row = require_string(prover.get("benchmarkRow"), "superneo.proverTime.benchmarkRow")
    prover_ms = require_float(prover.get("milliseconds"), "superneo.proverTime.milliseconds")
    require(prover_row in rows, f"missing benchmark row: {prover_row}")
    require(approx_equal(prover_ms, rows[prover_row]), "superneo prover time must match the benchmark report")

    verifier = require_dict(system.get("verifierTime"), "superneo.verifierTime")
    verifier_row = require_string(verifier.get("benchmarkRow"), "superneo.verifierTime.benchmarkRow")
    verifier_ms = require_float(verifier.get("milliseconds"), "superneo.verifierTime.milliseconds")
    require(verifier_row in rows, f"missing benchmark row: {verifier_row}")
    require(approx_equal(verifier_ms, rows[verifier_row]), "superneo verifier time must match the benchmark report")

    memory = require_dict(system.get("peakMemory"), "superneo.peakMemory")
    require_int(memory.get("proveMaxResidentSetBytes"), "superneo.peakMemory.proveMaxResidentSetBytes")
    require_int(memory.get("verifyMaxResidentSetBytes"), "superneo.peakMemory.verifyMaxResidentSetBytes")

    recursion = require_dict(system.get("recursionOverhead"), "superneo.recursionOverhead")
    child_prove_row = require_string(recursion.get("proverBenchmarkRow"), "superneo.recursionOverhead.proverBenchmarkRow")
    child_verify_row = require_string(recursion.get("verifierBenchmarkRow"), "superneo.recursionOverhead.verifierBenchmarkRow")
    child_prove_ms = require_float(recursion.get("childProverMilliseconds"), "superneo.recursionOverhead.childProverMilliseconds")
    child_verify_ms = require_float(recursion.get("childVerifierMilliseconds"), "superneo.recursionOverhead.childVerifierMilliseconds")
    require(approx_equal(child_prove_ms, rows[child_prove_row]), "recursive child prover time must match the benchmark report")
    require(approx_equal(child_verify_ms, rows[child_verify_row]), "recursive child verifier time must match the benchmark report")
    require(
        approx_equal(
            require_float(recursion.get("proverDeltaMilliseconds"), "superneo.recursionOverhead.proverDeltaMilliseconds"),
            child_prove_ms - prover_ms,
        ),
        "recursive prover delta is inconsistent",
    )
    require(
        approx_equal(
            require_float(recursion.get("verifierDeltaMilliseconds"), "superneo.recursionOverhead.verifierDeltaMilliseconds"),
            child_verify_ms - verifier_ms,
        ),
        "recursive verifier delta is inconsistent",
    )
    require(
        approx_equal(
            require_float(recursion.get("proverDeltaPercent"), "superneo.recursionOverhead.proverDeltaPercent"),
            (child_prove_ms - prover_ms) / prover_ms * 100.0,
        ),
        "recursive prover percentage is inconsistent",
    )
    require(
        approx_equal(
            require_float(recursion.get("verifierDeltaPercent"), "superneo.recursionOverhead.verifierDeltaPercent"),
            (child_verify_ms - verifier_ms) / verifier_ms * 100.0,
        ),
        "recursive verifier percentage is inconsistent",
    )

    metal = require_dict(system.get("metalVsCpuCost"), "superneo.metalVsCpuCost")
    cpu_row = require_string(metal.get("cpuBenchmarkRow"), "superneo.metalVsCpuCost.cpuBenchmarkRow")
    metal_row = require_string(metal.get("metalBenchmarkRow"), "superneo.metalVsCpuCost.metalBenchmarkRow")
    cpu_ms = require_float(metal.get("cpuMilliseconds"), "superneo.metalVsCpuCost.cpuMilliseconds")
    metal_ms = require_float(metal.get("metalMilliseconds"), "superneo.metalVsCpuCost.metalMilliseconds")
    require(approx_equal(cpu_ms, rows[cpu_row]), "CPU proxy time must match the benchmark report")
    require(approx_equal(metal_ms, rows[metal_row]), "Metal proxy time must match the benchmark report")
    require(
        approx_equal(
            require_float(metal.get("deltaMilliseconds"), "superneo.metalVsCpuCost.deltaMilliseconds"),
            metal_ms - cpu_ms,
        ),
        "Metal-vs-CPU delta is inconsistent",
    )
    require(
        approx_equal(
            require_float(metal.get("metalToCpuRatio"), "superneo.metalVsCpuCost.metalToCpuRatio"),
            metal_ms / cpu_ms,
        ),
        "Metal-vs-CPU ratio is inconsistent",
    )

    zk = require_dict(system.get("zkOverhead"), "superneo.zkOverhead")
    zk_prover_row = require_string(zk.get("proverBenchmarkRow"), "superneo.zkOverhead.proverBenchmarkRow")
    zk_verifier_row = require_string(zk.get("verifierBenchmarkRow"), "superneo.zkOverhead.verifierBenchmarkRow")
    zk_prover_ms = require_float(zk.get("zkProverMilliseconds"), "superneo.zkOverhead.zkProverMilliseconds")
    zk_verifier_ms = require_float(zk.get("zkVerifierMilliseconds"), "superneo.zkOverhead.zkVerifierMilliseconds")
    zk_proof_bytes = require_int(zk.get("zkProofEnvelopeBytes"), "superneo.zkOverhead.zkProofEnvelopeBytes")
    zk_artifact_bytes = require_int(zk.get("zkArtifactBytes"), "superneo.zkOverhead.zkArtifactBytes")
    require(approx_equal(zk_prover_ms, rows[zk_prover_row]), "ZK prover time must match the benchmark report")
    require(approx_equal(zk_verifier_ms, rows[zk_verifier_row]), "ZK verifier time must match the benchmark report")
    require(
        approx_equal(
            require_float(zk.get("proverDeltaMilliseconds"), "superneo.zkOverhead.proverDeltaMilliseconds"),
            zk_prover_ms - prover_ms,
        ),
        "ZK prover delta is inconsistent",
    )
    require(
        approx_equal(
            require_float(zk.get("verifierDeltaMilliseconds"), "superneo.zkOverhead.verifierDeltaMilliseconds"),
            zk_verifier_ms - verifier_ms,
        ),
        "ZK verifier delta is inconsistent",
    )
    require(
        approx_equal(
            require_float(zk.get("proverDeltaPercent"), "superneo.zkOverhead.proverDeltaPercent"),
            (zk_prover_ms - prover_ms) / prover_ms * 100.0,
        ),
        "ZK prover percentage is inconsistent",
    )
    require(
        approx_equal(
            require_float(zk.get("verifierDeltaPercent"), "superneo.zkOverhead.verifierDeltaPercent"),
            (zk_verifier_ms - verifier_ms) / verifier_ms * 100.0,
        ),
        "ZK verifier percentage is inconsistent",
    )
    require(
        require_int(zk.get("proofEnvelopeDeltaBytes"), "superneo.zkOverhead.proofEnvelopeDeltaBytes")
        == zk_proof_bytes - proof_envelope,
        "ZK proof-byte delta is inconsistent",
    )
    require(
        approx_equal(
            require_float(zk.get("proofEnvelopeDeltaPercent"), "superneo.zkOverhead.proofEnvelopeDeltaPercent"),
            (zk_proof_bytes - proof_envelope) / proof_envelope * 100.0,
        ),
        "ZK proof-byte percentage is inconsistent",
    )
    require(
        require_int(zk.get("artifactDeltaBytes"), "superneo.zkOverhead.artifactDeltaBytes")
        == zk_artifact_bytes - artifact_bytes,
        "ZK artifact-byte delta is inconsistent",
    )
    require(
        approx_equal(
            require_float(zk.get("artifactDeltaPercent"), "superneo.zkOverhead.artifactDeltaPercent"),
            (zk_artifact_bytes - artifact_bytes) / artifact_bytes * 100.0,
        ),
        "ZK artifact-byte percentage is inconsistent",
    )

    security = require_dict(system.get("parameterSecurityLevel"), "superneo.parameterSecurityLevel")
    lattice = require_dict(dossier.get("latticeAssumptionDossier"), "latticeAssumptionDossier")
    require(
        require_int(security.get("kappa"), "superneo.parameterSecurityLevel.kappa")
        == require_int(lattice.get("kappa"), "latticeAssumptionDossier.kappa"),
        "superneo kappa must match the cryptographic security dossier",
    )
    require(
        approx_equal(
            require_float(security.get("defaultEstimatorRopBits"), "superneo.parameterSecurityLevel.defaultEstimatorRopBits"),
            require_float(lattice.get("pinnedEstimatorMinimumROPBits"), "latticeAssumptionDossier.pinnedEstimatorMinimumROPBits"),
        ),
        "superneo estimator bits must match the cryptographic security dossier",
    )


def validate_competitor(system: dict[str, Any], *, expect_kappa: bool = False, expect_winterfell_security: bool = False) -> None:
    require_string(system.get("label"), "competitor.label")
    require_string(system.get("family"), "competitor.family")
    require_string(system.get("workload"), "competitor.workload")
    commands = require_list(system.get("measurementCommands"), "competitor.measurementCommands")
    require(commands, "competitor.measurementCommands must not be empty")
    require_string(system.get("upstreamRepository"), "competitor.upstreamRepository")
    require_string(system.get("upstreamCommit"), "competitor.upstreamCommit")
    require_string(system.get("examplePath"), "competitor.examplePath")
    require_string(require_dict(system.get("proofBytes"), "competitor.proofBytes").get("reported"), "competitor.proofBytes.reported")
    require(require_float(require_dict(system.get("proverTime"), "competitor.proverTime").get("milliseconds"), "competitor.proverTime.milliseconds") > 0.0, "competitor prover time must be positive")
    require(require_float(require_dict(system.get("verifierTime"), "competitor.verifierTime").get("milliseconds"), "competitor.verifierTime.milliseconds") > 0.0, "competitor verifier time must be positive")
    require(require_int(require_dict(system.get("peakMemory"), "competitor.peakMemory").get("maxResidentSetBytes"), "competitor.peakMemory.maxResidentSetBytes") > 0, "competitor peak memory must be positive")
    for label in ["recursionOverhead", "metalVsCpuCost", "zkOverhead"]:
        reported = require_string(require_dict(system.get(label), f"competitor.{label}").get("reported"), f"competitor.{label}.reported").lower()
        require(reported.startswith("n/a"), f"competitor {label} must be marked n/a for this selected example")
    security = require_dict(system.get("parameterSecurityLevel"), "competitor.parameterSecurityLevel")
    require_string(security.get("reported"), "competitor.parameterSecurityLevel.reported")
    if expect_kappa:
        require_int(security.get("kappa"), "competitor.parameterSecurityLevel.kappa")
    if expect_winterfell_security:
        require_int(security.get("conjecturedBits"), "competitor.parameterSecurityLevel.conjecturedBits")
        require_int(security.get("provenListDecodingBits"), "competitor.parameterSecurityLevel.provenListDecodingBits")
        require_int(security.get("provenUniqueDecodingBits"), "competitor.parameterSecurityLevel.provenUniqueDecodingBits")


def validate(path: Path) -> None:
    manifest = read_json(path)
    require(manifest.get("schemaVersion") == 1, "schemaVersion must be 1")
    require(
        manifest.get("scopeID") == "superneo-competitive-performance-comparison-v1",
        "scopeID mismatch",
    )
    require(
        manifest.get("claimStatus") == "same-hardware-competitive-performance-evidence",
        "claimStatus mismatch",
    )
    require_string(manifest.get("capturedAtUTC"), "capturedAtUTC")

    columns = set(require_list(manifest.get("requiredColumns"), "requiredColumns"))
    require(columns == EXPECTED_COLUMNS, "requiredColumns mismatch")

    boundaries = " ".join(require_list(manifest.get("claimBoundaries"), "claimBoundaries")).lower()
    for needle in ["same hardware", "same arithmetic relation", "promotion gate", "competitor-comparison"]:
        require(needle in boundaries, f"claimBoundaries must mention {needle}")

    benchmark = require_dict(manifest.get("localBenchmarkEvidence"), "localBenchmarkEvidence")
    metadata_path = ROOT / require_string(benchmark.get("metadata"), "localBenchmarkEvidence.metadata")
    report_path = ROOT / require_string(benchmark.get("report"), "localBenchmarkEvidence.report")
    require(metadata_path.exists(), f"missing benchmark metadata: {metadata_path}")
    require(report_path.exists(), f"missing benchmark report: {report_path}")

    metadata = read_json(metadata_path)
    require(
        require_string(benchmark.get("generatedAtUTC"), "localBenchmarkEvidence.generatedAtUTC")
        == require_string(metadata.get("generatedAt"), "benchmark metadata generatedAt"),
        "benchmark generatedAtUTC mismatch",
    )

    environment = require_dict(manifest.get("sameHardwareEnvironment"), "sameHardwareEnvironment")
    require(
        require_string(environment.get("model"), "sameHardwareEnvironment.model")
        == require_string(metadata.get("modelName"), "benchmark metadata modelName"),
        "hardware model mismatch",
    )
    require(
        require_string(environment.get("chip"), "sameHardwareEnvironment.chip")
        == require_string(metadata.get("chip"), "benchmark metadata chip"),
        "hardware chip mismatch",
    )
    require(
        require_int(environment.get("memoryGB"), "sameHardwareEnvironment.memoryGB") == int(require_string(metadata.get("memory"), "benchmark metadata memory").split(" ", 1)[0]),
        "hardware memory mismatch",
    )
    require(
        require_string(environment.get("metalDevice"), "sameHardwareEnvironment.metalDevice")
        == require_string(metadata.get("metalDevice"), "benchmark metadata metalDevice"),
        "hardware metal device mismatch",
    )
    require(
        require_string(environment.get("osVersion"), "sameHardwareEnvironment.osVersion")
        == require_string(metadata.get("osVersion"), "benchmark metadata osVersion"),
        "hardware osVersion mismatch",
    )

    systems = require_list(manifest.get("systems"), "systems")
    require(len(systems) == len(EXPECTED_SYSTEM_IDS), "systems length mismatch")
    system_map = {}
    for value in systems:
        system = require_dict(value, "systems item")
        system_id = require_string(system.get("id"), "systems.id")
        require(system_id not in system_map, f"duplicate system id: {system_id}")
        system_map[system_id] = system
    require(set(system_map) == EXPECTED_SYSTEM_IDS, "system id set mismatch")

    rows = parse_benchmark_rows(report_path)
    dossier = read_json(DOSSIER)
    validate_superneo(system_map["superneo-numiseal-terminal"], rows, dossier)
    validate_competitor(system_map["latticefold-e2e"], expect_kappa=True)
    validate_competitor(system_map["winterfell-lamport-a-64"], expect_winterfell_security=True)


def main() -> None:
    path = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else MANIFEST
    validate(path)


if __name__ == "__main__":
    main()
