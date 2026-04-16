#!/usr/bin/env python3
"""Regression tests for E2E proof metrics validation."""

from __future__ import annotations

import base64
import copy
import hashlib
import json
import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "TestVectors" / "e2e-proof-metrics-v1.json"
VALIDATE = ROOT / "Scripts" / "validate-e2e-proof-metrics.py"


def run_ok(*args: str) -> None:
    subprocess.run(args, cwd=ROOT, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)


def run_fail(*args: str) -> None:
    completed = subprocess.run(args, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if completed.returncode == 0:
        raise AssertionError(f"expected failure: {' '.join(args)}")


def write_json(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def product_fixture(path: Path, *, proof_kind: str = "numiseal-terminal") -> None:
    source_bytes = b"source fold envelope"
    proof_bytes = b"numiseal proof envelope"
    write_json(
        path,
        {
            "artifactVersion": 2,
            "proofKind": proof_kind,
            "sealMode": "numiseal-terminal-v2",
            "carryMode": "none",
            "zkMode": "none",
            "metalMode": "cpu-reference",
            "executionPolicy": "zk-high-assurance-cpu",
            "sourceFoldOutputClaimCount": 14,
            "sourceFoldEnvelopeBase64": base64.b64encode(source_bytes).decode("ascii"),
            "numiSealProofEnvelopeBase64": base64.b64encode(proof_bytes).decode("ascii"),
            "sourceFoldEnvelopeDigestHex": hashlib.sha256(source_bytes).hexdigest(),
            "proofEnvelopeDigestHex": hashlib.sha256(proof_bytes).hexdigest(),
        },
    )


def main() -> None:
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    with tempfile.TemporaryDirectory(prefix="superneo-e2e-metrics-") as tmpdir:
        tmp = Path(tmpdir)
        valid = tmp / "valid.json"
        write_json(valid, manifest)
        run_ok(str(VALIDATE), str(valid))

        generated = tmp / "generated-product.json"
        product_fixture(generated)
        run_ok(str(VALIDATE), str(valid), "--generated-product-artifact", f"numiseal-product-smoke:{generated}")

        wrong_schema = copy.deepcopy(manifest)
        wrong_schema["schemaVersion"] = 2
        path = tmp / "wrong-schema.json"
        write_json(path, wrong_schema)
        run_fail(str(VALIDATE), str(path))

        missing_vector = copy.deepcopy(manifest)
        missing_vector["trackedArtifacts"] = missing_vector["trackedArtifacts"][:-1]
        path = tmp / "missing-vector.json"
        write_json(path, missing_vector)
        run_fail(str(VALIDATE), str(path))

        changed_recorded_bytes = copy.deepcopy(manifest)
        changed_recorded_bytes["trackedArtifacts"][0]["proofEnvelopeBytes"] -= 1
        path = tmp / "changed-recorded-bytes.json"
        write_json(path, changed_recorded_bytes)
        run_fail(str(VALIDATE), str(path))

        budget_too_small = copy.deepcopy(manifest)
        budget_too_small["trackedArtifacts"][0]["maximumProofEnvelopeBytes"] -= 1
        path = tmp / "budget-too-small.json"
        write_json(path, budget_too_small)
        run_fail(str(VALIDATE), str(path))

        missing_artifact = copy.deepcopy(manifest)
        missing_artifact["trackedArtifacts"][0]["file"] = "TestVectors/missing-proof.json"
        path = tmp / "missing-artifact.json"
        write_json(path, missing_artifact)
        run_fail(str(VALIDATE), str(path))

        vague_latency = copy.deepcopy(manifest)
        vague_latency["latencyEvidencePolicy"]["productionReleaseRequiresFreshBenchmarkReport"] = False
        path = tmp / "vague-latency.json"
        write_json(path, vague_latency)
        run_fail(str(VALIDATE), str(path))

        outsourced_review = copy.deepcopy(manifest)
        outsourced_review["openBoundaries"].append("External" + " audit required.")
        path = tmp / "outsourced-review.json"
        write_json(path, outsourced_review)
        run_fail(str(VALIDATE), str(path))

        wrong_generated_kind = tmp / "wrong-generated-kind.json"
        product_fixture(wrong_generated_kind, proof_kind="numiseal-zk")
        run_fail(str(VALIDATE), str(valid), "--generated-product-artifact", f"numiseal-product-smoke:{wrong_generated_kind}")

    print("e2e proof metrics validation regression tests passed")


if __name__ == "__main__":
    main()
