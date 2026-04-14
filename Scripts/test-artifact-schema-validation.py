#!/usr/bin/env python3
import copy
import json
import subprocess
import tempfile
from pathlib import Path
from typing import Any, Callable


ROOT = Path(__file__).resolve().parents[1]
VALIDATOR = ROOT / "Scripts" / "validate-artifact-schema.py"
SCHEMA = ROOT / "TestVectors" / "artifact.schema.json"


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


def mutate_conditional(
    schema: dict[str, Any],
    workload: str,
    mutation: Callable[[dict[str, Any]], None],
) -> dict[str, Any]:
    mutated = copy.deepcopy(schema)
    for entry in mutated["allOf"]:
        if entry["if"]["properties"]["workload"].get("const") == workload:
            mutation(entry["then"])
            return mutated
    raise AssertionError(f"missing workload conditional for {workload}")


def workload_parameters(then_schema: dict[str, Any]) -> dict[str, Any]:
    return then_schema["properties"]["workloadParameters"]


def main() -> None:
    schema = json.loads(SCHEMA.read_text(encoding="utf-8"))
    result = run_validator(schema)
    if result.returncode != 0:
        raise AssertionError(f"baseline artifact schema failed validation: {result.stderr}")

    root_allows_extra = copy.deepcopy(schema)
    root_allows_extra["additionalProperties"] = True
    expect_failure(
        "root additional properties",
        root_allows_extra,
        "artifact root must reject additional properties",
    )

    root_declares_extra_property = copy.deepcopy(schema)
    root_declares_extra_property["properties"]["unexpectedTrustAnchor"] = {"type": "string"}
    expect_failure(
        "root declares extra property",
        root_declares_extra_property,
        "artifact root property keys must match the CLI artifact allowlist",
    )

    missing_root_key = copy.deepcopy(schema)
    missing_root_key["required"].remove("statementDigestHex")
    expect_failure(
        "missing root required digest",
        missing_root_key,
        "artifact root missing required key statementDigestHex",
    )

    missing_compressed_kind = copy.deepcopy(schema)
    missing_compressed_kind["properties"]["proofKind"]["enum"].remove("compressed-terminal")
    expect_failure(
        "missing compressed proof kind",
        missing_compressed_kind,
        "artifact proofKind enum must match the CLI proof kinds",
    )

    one_hot_missing_workload_parameters = mutate_conditional(
        schema,
        "one-hot-vector-v1",
        lambda then: then["required"].remove("workloadParameters"),
    )
    expect_failure(
        "one-hot missing workloadParameters requirement",
        one_hot_missing_workload_parameters,
        "one-hot-vector-v1 must require workloadParameters",
    )

    one_hot_allows_extra_parameters = mutate_conditional(
        schema,
        "one-hot-vector-v1",
        lambda then: workload_parameters(then).update({"additionalProperties": True}),
    )
    expect_failure(
        "one-hot allows extra parameters",
        one_hot_allows_extra_parameters,
        "one-hot-vector-v1 workloadParameters must reject additional properties",
    )

    binary_missing_left_bit_count = mutate_conditional(
        schema,
        "binary-addition-v1",
        lambda then: workload_parameters(then)["required"].remove("leftBitCount"),
    )
    expect_failure(
        "binary missing leftBitCount",
        binary_missing_left_bit_count,
        "binary-addition-v1 workloadParameters required keys mismatch",
    )

    binary_bad_public_sum_pattern = mutate_conditional(
        schema,
        "binary-addition-v1",
        lambda then: workload_parameters(then)["properties"]["publicSum"].update({"pattern": "^[0-9]+$"}),
    )
    expect_failure(
        "binary weak publicSum pattern",
        binary_bad_public_sum_pattern,
        "binary-addition publicSum must require canonical unsigned decimal",
    )

    print("artifact schema validation regression tests passed")


if __name__ == "__main__":
    main()
