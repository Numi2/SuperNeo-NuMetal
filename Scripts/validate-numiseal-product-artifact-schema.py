#!/usr/bin/env python3
import json
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SCHEMA_PATH = ROOT / "TestVectors" / "numiseal-product-artifact-v2.schema.json"

TOP_LEVEL_KEYS = {
    "aggregateDigestsHex",
    "artifactVersion",
    "bitCount",
    "carryMode",
    "commitmentBase64",
    "componentDigestRootHex",
    "executionPolicy",
    "executionPolicyMetadata",
    "keySeedUTF8",
    "laneIDsUTF8",
    "laneSummaryRootHex",
    "maximumAggregatesPerLane",
    "maximumLaneCount",
    "maximumObligationsPerAggregate",
    "metalMode",
    "numiSealProofEnvelopeBase64",
    "obligationRootHex",
    "profile",
    "proofEnvelopeDigestHex",
    "proofKind",
    "proofTranscriptDigestHex",
    "publicInputs",
    "publicStatementDigestHex",
    "sealMode",
    "shapeDigestHex",
    "sourceApplicationPathUTF8",
    "sourceFoldEnvelopeBase64",
    "sourceFoldEnvelopeDigestHex",
    "sourceFoldOutputClaimCount",
    "sourceFoldOutputClaimDigestsHex",
    "sourceStatementDigestHex",
    "statementDigestHex",
    "transcriptDomainHex",
    "verifierKeyDigestHex",
    "workload",
    "workloadParameters",
    "zkMode",
}

REQUIRED_KEYS = TOP_LEVEL_KEYS - {"keySeedUTF8"}

DIGEST_KEYS = {
    "componentDigestRootHex",
    "laneSummaryRootHex",
    "obligationRootHex",
    "proofEnvelopeDigestHex",
    "proofTranscriptDigestHex",
    "publicStatementDigestHex",
    "shapeDigestHex",
    "sourceFoldEnvelopeDigestHex",
    "sourceStatementDigestHex",
    "statementDigestHex",
    "transcriptDomainHex",
    "verifierKeyDigestHex",
}


def fail(message: str) -> None:
    print(f"error: {message}", file=sys.stderr)
    raise SystemExit(1)


def expect(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def properties(schema: dict[str, Any]) -> dict[str, Any]:
    value = schema.get("properties")
    expect(isinstance(value, dict), "NumiSeal product schema properties must be an object")
    return value


def require_const(schema: dict[str, Any], key: str, expected: Any) -> None:
    actual = properties(schema).get(key, {}).get("const")
    expect(actual == expected, f"NumiSeal product {key} const must be {expected}")


def require_enum(schema: dict[str, Any], key: str, expected: list[str]) -> None:
    actual = properties(schema).get(key, {}).get("enum")
    expect(actual == expected, f"NumiSeal product {key} enum must be {expected}")


def require_digest_property(schema: dict[str, Any], key: str) -> None:
    field = properties(schema).get(key, {})
    expect(field.get("type") == "string", f"NumiSeal product {key} must be a string")
    expect(
        field.get("pattern") == "^[0-9a-f]{64}$",
        f"NumiSeal product {key} must require lowercase 64-byte hex",
    )


def main() -> None:
    schema_path = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_SCHEMA_PATH
    schema = json.loads(schema_path.read_text(encoding="utf-8"))
    root_properties = properties(schema)
    expect(schema.get("type") == "object", "NumiSeal product schema root must be an object")
    expect(
        schema.get("additionalProperties") is False,
        "NumiSeal product schema root must reject additional properties",
    )
    expect(
        set(root_properties.keys()) == TOP_LEVEL_KEYS,
        "NumiSeal product schema property keys must match v2 artifact core",
    )
    expect(
        set(schema.get("required", [])) == REQUIRED_KEYS,
        "NumiSeal product schema required keys must match v2 artifact core",
    )
    require_const(schema, "artifactVersion", 2)
    require_const(schema, "profile", "Goldilocks/Phi81(d=54)")
    require_enum(schema, "proofKind", ["numiseal-terminal", "numiseal-zk"])
    require_enum(schema, "sealMode", ["numiseal-terminal-v2", "numiseal-zk-v1"])
    for key in sorted(DIGEST_KEYS):
        require_digest_property(schema, key)
    source_claims = root_properties.get("sourceFoldOutputClaimDigestsHex", {})
    expect(source_claims.get("minItems") == 1, "NumiSeal product source claim digests must be non-empty")
    aggregates = root_properties.get("aggregateDigestsHex", {})
    expect(aggregates.get("minItems") == 1, "NumiSeal product aggregate digests must be non-empty")
    print(f"validated {schema_path}")


if __name__ == "__main__":
    main()
