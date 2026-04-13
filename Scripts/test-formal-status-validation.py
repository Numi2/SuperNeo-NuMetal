#!/usr/bin/env python3
import json
import subprocess
import tempfile
from pathlib import Path
from typing import Any, Callable, Dict


ROOT = Path(__file__).resolve().parents[1]
VALIDATOR = ROOT / "Scripts" / "validate-formal-status.py"
MANIFEST = ROOT / "Docs" / "FormalStatus.json"


def run_validator(manifest: Dict[str, Any]) -> subprocess.CompletedProcess[str]:
    with tempfile.NamedTemporaryFile("w", encoding="utf-8", suffix=".json", delete=False) as handle:
        json.dump(manifest, handle)
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


def expect_failure(
    name: str,
    manifest: Dict[str, Any],
    expected_stderr: str,
) -> None:
    result = run_validator(manifest)
    if result.returncode == 0:
        raise AssertionError(f"{name}: validator succeeded unexpectedly")
    if expected_stderr not in result.stderr:
        raise AssertionError(
            f"{name}: expected stderr to contain {expected_stderr!r}, got {result.stderr!r}"
        )


def mutate_group(
    manifest: Dict[str, Any],
    group_id: str,
    mutation: Callable[[Dict[str, Any]], None],
) -> Dict[str, Any]:
    copy = json.loads(json.dumps(manifest))
    for group in copy["theorem_groups"]:
        if group["id"] == group_id:
            mutation(group)
            return copy
    raise AssertionError(f"missing theorem group {group_id}")


def main() -> None:
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    result = run_validator(manifest)
    if result.returncode != 0:
        raise AssertionError(f"baseline manifest failed validation: {result.stderr}")

    expect_failure(
        "missing closed declaration",
        mutate_group(
            manifest,
            "ajtai-binding-reduction",
            lambda group: group["declarations"].append("SuperNeoFormal.missingBindingTheorem"),
        ),
        "references missing declaration",
    )

    expect_failure(
        "planned group with declaration",
        mutate_group(
            manifest,
            "superneo-composition-theorem",
            lambda group: group["declarations"].append("SuperNeoFormal.superNeoCompositionPlanned"),
        ),
        "planned theorem group",
    )

    expect_failure(
        "closed group without declaration",
        mutate_group(
            manifest,
            "ajtai-opening-linearity",
            lambda group: group.update({"declarations": []}),
        ),
        "must list at least one declaration",
    )

    print("formal status validation regression tests passed")


if __name__ == "__main__":
    main()
