#!/usr/bin/env python3
import json
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SCHEMA_PATH = ROOT / "TestVectors" / "artifact.schema.json"
ARTIFACT_TOP_LEVEL_KEYS = {
    "artifactVersion",
    "workload",
    "profile",
    "proofKind",
    "bitCount",
    "expectedSelectedCount",
    "keySeedUTF8",
    "workloadParameters",
    "publicInputs",
    "commitmentBase64",
    "proofEnvelopeBase64",
    "shapeDigestHex",
    "statementDigestHex",
    "verifierKeyDigestHex",
}


def fail(message: str) -> None:
    print(f"error: {message}", file=sys.stderr)
    raise SystemExit(1)


def expect(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def conditional_for(schema: dict, workload: str) -> dict:
    matches = [
        entry
        for entry in schema.get("allOf", [])
        if entry.get("if", {})
        .get("properties", {})
        .get("workload", {})
        .get("const")
        == workload
    ]
    expect(len(matches) == 1, f"expected exactly one conditional schema for {workload}")
    return matches[0].get("then", {})


def require_exact_workload_parameters(
    schema: dict,
    workload: str,
    expected_keys: set[str],
) -> None:
    then_schema = conditional_for(schema, workload)
    required = set(then_schema.get("required", []))
    expect("workloadParameters" in required, f"{workload} must require workloadParameters")

    parameter_schema = then_schema.get("properties", {}).get("workloadParameters", {})
    expect(parameter_schema.get("type") == "object", f"{workload} workloadParameters must be an object")
    expect(
        parameter_schema.get("additionalProperties") is False,
        f"{workload} workloadParameters must reject additional properties",
    )
    expect(
        set(parameter_schema.get("required", [])) == expected_keys,
        f"{workload} workloadParameters required keys mismatch",
    )
    expect(
        set(parameter_schema.get("properties", {}).keys()) == expected_keys,
        f"{workload} workloadParameters property keys mismatch",
    )


def main() -> None:
    schema_path = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_SCHEMA_PATH
    with schema_path.open("r", encoding="utf-8") as handle:
        schema = json.load(handle)

    expect(schema.get("additionalProperties") is False, "artifact root must reject additional properties")
    expect(
        set(schema.get("properties", {}).keys()) == ARTIFACT_TOP_LEVEL_KEYS,
        "artifact root property keys must match the CLI artifact allowlist",
    )
    root_required = set(schema.get("required", []))
    for key in {
        "artifactVersion",
        "workload",
        "profile",
        "proofKind",
        "bitCount",
        "keySeedUTF8",
        "publicInputs",
        "commitmentBase64",
        "proofEnvelopeBase64",
        "shapeDigestHex",
        "statementDigestHex",
        "verifierKeyDigestHex",
    }:
        expect(key in root_required, f"artifact root missing required key {key}")
    expect(
        schema.get("properties", {}).get("proofKind", {}).get("enum") == [
            "fold",
            "terminal",
            "compressed-terminal",
        ],
        "artifact proofKind enum must match the CLI proof kinds",
    )

    require_exact_workload_parameters(schema, "one-hot-vector-v1", {"selectedCount"})
    require_exact_workload_parameters(
        schema,
        "binary-addition-v1",
        {"leftBitCount", "publicSum"},
    )

    one_hot_parameters = (
        conditional_for(schema, "one-hot-vector-v1")
        .get("properties", {})
        .get("workloadParameters", {})
        .get("properties", {})
    )
    expect(
        one_hot_parameters.get("selectedCount", {}).get("const") == "1",
        "one-hot selectedCount must be const string 1",
    )

    binary_parameters = (
        conditional_for(schema, "binary-addition-v1")
        .get("properties", {})
        .get("workloadParameters", {})
        .get("properties", {})
    )
    expect(
        binary_parameters.get("leftBitCount", {}).get("pattern") == "^[1-9][0-9]*$",
        "binary-addition leftBitCount must require canonical positive decimal",
    )
    expect(
        binary_parameters.get("publicSum", {}).get("pattern") == "^(0|[1-9][0-9]*)$",
        "binary-addition publicSum must require canonical unsigned decimal",
    )
    print(f"validated {schema_path}")


if __name__ == "__main__":
    main()
