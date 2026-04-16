#!/usr/bin/env python3
import json
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SCHEMA_PATH = ROOT / "TestVectors" / "numiseal-artifact.schema.json"

NUMISEAL_ARTIFACT_TOP_LEVEL_KEYS = {
    "aggregateDigestsHex",
    "artifactVersion",
    "ceRandomSeedsUTF8",
    "componentDigestRootHex",
    "foldTranscriptSeedUTF8",
    "keyColumnCount",
    "keySeedUTF8",
    "laneIDsUTF8",
    "laneSummaryRootHex",
    "maximumAggregatesPerLane",
    "maximumLaneCount",
    "maximumObligationsPerAggregate",
    "obligationRootHex",
    "privateWitnessCount",
    "profile",
    "proofEnvelopeBase64",
    "proofKind",
    "proofTranscriptDigestHex",
    "publicInputCount",
    "publicInputs",
    "publicStatementDigestHex",
    "residualMode",
    "shapeDigestHex",
    "sourceFoldDigestSeedsUTF8",
    "statementDigestHex",
    "transcriptDomainHex",
    "verifierKeyDigestHex",
    "workload",
}

NUMISEAL_DIGEST_PROPERTIES = {
    "componentDigestRootHex",
    "laneSummaryRootHex",
    "obligationRootHex",
    "proofTranscriptDigestHex",
    "publicStatementDigestHex",
    "shapeDigestHex",
    "statementDigestHex",
    "transcriptDomainHex",
    "verifierKeyDigestHex",
}

NUMISEAL_VECTOR_WORKLOADS = [
    "numiseal-terminal-single-aggregate-v1",
    "numiseal-terminal-two-aggregate-v1",
    "numiseal-terminal-two-lane-v1",
]


def fail(message: str) -> None:
    print(f"error: {message}", file=sys.stderr)
    raise SystemExit(1)


def expect(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def properties(schema: dict[str, Any]) -> dict[str, Any]:
    value = schema.get("properties")
    expect(isinstance(value, dict), "NumiSeal artifact schema properties must be an object")
    return value


def require_const(schema: dict[str, Any], key: str, expected: Any) -> None:
    actual = properties(schema).get(key, {}).get("const")
    expect(actual == expected, f"NumiSeal {key} const must be {expected}")


def require_digest_property(schema: dict[str, Any], key: str) -> None:
    field = properties(schema).get(key, {})
    expect(field.get("type") == "string", f"NumiSeal {key} must be a string")
    expect(field.get("pattern") == "^[0-9a-f]{64}$", f"NumiSeal {key} must require lowercase 64-byte hex")


def main() -> None:
    schema_path = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_SCHEMA_PATH
    with schema_path.open("r", encoding="utf-8") as handle:
        schema = json.load(handle)

    root_properties = properties(schema)
    expect(schema.get("type") == "object", "NumiSeal artifact root must be an object")
    expect(schema.get("additionalProperties") is False, "NumiSeal artifact root must reject additional properties")
    expect(
        set(root_properties.keys()) == NUMISEAL_ARTIFACT_TOP_LEVEL_KEYS,
        "NumiSeal artifact property keys must match shared artifact core",
    )
    expect(
        set(schema.get("required", [])) == NUMISEAL_ARTIFACT_TOP_LEVEL_KEYS,
        "NumiSeal artifact required keys must match shared artifact core",
    )

    expect(
        root_properties.get("workload", {}).get("enum") == NUMISEAL_VECTOR_WORKLOADS,
        "NumiSeal workload enum must match deterministic vector workloads",
    )
    require_const(schema, "artifactVersion", 1)
    require_const(schema, "profile", "Goldilocks/Phi81(d=54)")
    require_const(schema, "proofKind", "numiseal-terminal")
    require_const(schema, "residualMode", "immediate")
    require_const(schema, "keyColumnCount", 2)
    require_const(schema, "maximumObligationsPerAggregate", 1)
    require_const(schema, "publicInputCount", 54)
    require_const(schema, "privateWitnessCount", 10)

    public_inputs = root_properties.get("publicInputs", {})
    expect(public_inputs.get("type") == "array", "NumiSeal publicInputs must be an array")
    expect(public_inputs.get("minItems") == 54, "NumiSeal publicInputs minItems must be 54")
    expect(public_inputs.get("maxItems") == 54, "NumiSeal publicInputs maxItems must be 54")
    expect(public_inputs.get("items", {}).get("const") == 0, "NumiSeal publicInputs items must be zero")

    for key in sorted(NUMISEAL_DIGEST_PROPERTIES):
        require_digest_property(schema, key)

    aggregate_digests = root_properties.get("aggregateDigestsHex", {})
    expect(aggregate_digests.get("type") == "array", "NumiSeal aggregateDigestsHex must be an array")
    expect(aggregate_digests.get("minItems") == 1, "NumiSeal aggregateDigestsHex minItems must be 1")
    expect(aggregate_digests.get("maxItems") == 2, "NumiSeal aggregateDigestsHex maxItems must be 2")
    aggregate_item = aggregate_digests.get("items", {})
    expect(aggregate_item.get("type") == "string", "NumiSeal aggregateDigestsHex items must be strings")
    expect(
        aggregate_item.get("pattern") == "^[0-9a-f]{64}$",
        "NumiSeal aggregateDigestsHex items must require lowercase 64-byte hex",
    )

    proof_envelope = root_properties.get("proofEnvelopeBase64", {})
    expect(proof_envelope.get("type") == "string", "NumiSeal proofEnvelopeBase64 must be a string")
    expect(
        proof_envelope.get("contentEncoding") == "base64",
        "NumiSeal proofEnvelopeBase64 must declare base64 contentEncoding",
    )

    print(f"validated {schema_path}")


if __name__ == "__main__":
    main()
