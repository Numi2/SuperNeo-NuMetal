#!/usr/bin/env python3
import copy
import json
import subprocess
import tempfile
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
VALIDATOR = ROOT / "Scripts" / "validate-numiseal-product-artifact-schema.py"
SCHEMA = ROOT / "TestVectors" / "numiseal-product-artifact-v2.schema.json"


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
        raise AssertionError(f"baseline NumiSeal product artifact schema failed validation: {result.stderr}")

    missing_terminal_carry_policy = copy.deepcopy(schema)
    missing_terminal_carry_policy["properties"]["executionPolicyMetadata"]["required"] = []
    expect_failure(
        "missing terminalCarryPolicy requirement",
        missing_terminal_carry_policy,
        "NumiSeal product metadata must require terminalCarryPolicy",
    )

    weak_terminal_carry_policy_enum = copy.deepcopy(schema)
    weak_terminal_carry_policy_enum["properties"]["executionPolicyMetadata"]["properties"]["terminalCarryPolicy"]["enum"] = [
        "none",
        "optional",
        "required",
    ]
    expect_failure(
        "weak terminalCarryPolicy enum",
        weak_terminal_carry_policy_enum,
        "NumiSeal product metadata terminalCarryPolicy enum must match carryMode",
    )

    print("NumiSeal product artifact schema validation regression tests passed")


if __name__ == "__main__":
    main()
