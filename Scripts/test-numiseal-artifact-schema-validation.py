#!/usr/bin/env python3
import copy
import json
import subprocess
import tempfile
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
VALIDATOR = ROOT / "Scripts" / "validate-numiseal-artifact-schema.py"
SCHEMA = ROOT / "TestVectors" / "numiseal-artifact.schema.json"


def run_validator(schema: dict[str, Any]) -> subprocess.CompletedProcess[str]:
    with tempfile.NamedTemporaryFile("w", encoding="utf-8", suffix=".json", delete=False) as handle:
        json.dump(schema, handle)
        path = Path(handle.name)
    try:
        return subprocess.run(
            [str(VALIDATOR), str(path)],
            cwd=ROOT,
            check=False,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
    finally:
        path.unlink(missing_ok=True)


def expect_failure(name: str, schema: dict[str, Any], expected_stderr: str) -> None:
    result = run_validator(schema)
    if result.returncode == 0:
        raise AssertionError(f"{name}: validator succeeded unexpectedly")
    if expected_stderr not in result.stderr:
        raise AssertionError(
            f"{name}: expected stderr to contain {expected_stderr!r}, got {result.stderr!r}"
        )


def main() -> None:
    schema = json.loads(SCHEMA.read_text(encoding="utf-8"))
    result = run_validator(schema)
    if result.returncode != 0:
        raise AssertionError(f"baseline NumiSeal artifact schema failed validation: {result.stderr}")

    root_allows_extra = copy.deepcopy(schema)
    root_allows_extra["additionalProperties"] = True
    expect_failure(
        "root additional properties",
        root_allows_extra,
        "NumiSeal artifact root must reject additional properties",
    )

    root_declares_extra_property = copy.deepcopy(schema)
    root_declares_extra_property["properties"]["unexpectedTrustAnchor"] = {"type": "string"}
    expect_failure(
        "root declares extra property",
        root_declares_extra_property,
        "NumiSeal artifact property keys must match shared artifact core",
    )

    missing_obligation_root = copy.deepcopy(schema)
    missing_obligation_root["required"].remove("obligationRootHex")
    expect_failure(
        "missing obligation root requirement",
        missing_obligation_root,
        "NumiSeal artifact required keys must match shared artifact core",
    )

    wrong_proof_kind = copy.deepcopy(schema)
    wrong_proof_kind["properties"]["proofKind"]["const"] = "terminal"
    expect_failure(
        "wrong proof kind",
        wrong_proof_kind,
        "NumiSeal proofKind const must be numiseal-terminal",
    )

    wrong_public_input_count = copy.deepcopy(schema)
    wrong_public_input_count["properties"]["publicInputCount"]["const"] = 55
    expect_failure(
        "wrong public input count",
        wrong_public_input_count,
        "NumiSeal publicInputCount const must be 54",
    )

    weak_obligation_root_pattern = copy.deepcopy(schema)
    weak_obligation_root_pattern["properties"]["obligationRootHex"]["pattern"] = "^[0-9a-f]+$"
    expect_failure(
        "weak obligation root pattern",
        weak_obligation_root_pattern,
        "NumiSeal obligationRootHex must require lowercase 64-byte hex",
    )

    weak_aggregate_pattern = copy.deepcopy(schema)
    weak_aggregate_pattern["properties"]["aggregateDigestsHex"]["items"]["pattern"] = "^[0-9a-f]+$"
    expect_failure(
        "weak aggregate pattern",
        weak_aggregate_pattern,
        "NumiSeal aggregateDigestsHex items must require lowercase 64-byte hex",
    )

    public_inputs_not_fixed_width = copy.deepcopy(schema)
    public_inputs_not_fixed_width["properties"]["publicInputs"]["maxItems"] = 55
    expect_failure(
        "public inputs not fixed width",
        public_inputs_not_fixed_width,
        "NumiSeal publicInputs maxItems must be 54",
    )

    print("NumiSeal artifact schema validation regression tests passed")


if __name__ == "__main__":
    main()
