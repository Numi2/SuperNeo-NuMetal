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


def mutate_manifest(
    manifest: Dict[str, Any],
    mutation: Callable[[Dict[str, Any]], None],
) -> Dict[str, Any]:
    copy = json.loads(json.dumps(manifest))
    mutation(copy)
    return copy


def main() -> None:
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    result = run_validator(manifest)
    if result.returncode != 0:
        raise AssertionError(f"baseline manifest failed validation: {result.stderr}")

    expect_failure(
        "missing certified declaration",
        mutate_group(
            manifest,
            "concrete-ajtai-certified-binding",
            lambda group: group["declarations"].append("SuperNeoFormal.missingBindingTheorem"),
        ),
        "references missing declaration",
    )

    expect_failure(
        "planned group with declaration",
        mutate_group(
            manifest,
            "superneo-full-probability-composition",
            lambda group: group["declarations"].append(
                "SuperNeoFormal.superneo_end_to_end_from_ce_soundness"
            ),
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

    expect_failure(
        "question mark declaration names checked",
        mutate_group(
            manifest,
            "swift-wire-serialization",
            lambda group: group["declarations"].append("SuperNeoFormal.uintLEDecode?_missing"),
        ),
        "references missing declaration",
    )

    expect_failure(
        "duplicate declaration across theorem groups blocked",
        mutate_group(
            manifest,
            "terminal-ce-local-batch",
            lambda group: group["declarations"].append(
                "SuperNeoFormal.CELocalOpeningRelation"
            ),
        ),
        "appears in multiple theorem groups",
    )

    expect_failure(
        "inactive label unknown group blocked",
        mutate_manifest(
            manifest,
            lambda copy: copy["labels"]["completed formal protocol theorem"][
                "required_theorem_groups"
            ].append("missing-future-theorem-group"),
        ),
        "depends on unknown theorem group",
    )

    expect_failure(
        "inactive label unsupported accepted status blocked",
        mutate_manifest(
            manifest,
            lambda copy: copy["labels"]["completed formal protocol theorem"][
                "accepted_statuses"
            ].append("closed_under_magic"),
        ),
        "accepted_statuses contains unsupported status",
    )

    expect_failure(
        "label duplicate required group blocked",
        mutate_manifest(
            manifest,
            lambda copy: copy["labels"]["conditional protocol formalization"][
                "required_theorem_groups"
            ].append("profile-constants"),
        ),
        "required_theorem_groups contains duplicates",
    )

    expect_failure(
        "documentation duplicate path blocked",
        mutate_manifest(
            manifest,
            lambda copy: copy["documentation_claims"].append(
                dict(copy["documentation_claims"][0])
            ),
        ),
        "duplicate documentation claim path",
    )

    expect_failure(
        "status-bearing docs must be claimed",
        mutate_manifest(
            manifest,
            lambda copy: copy["documentation_claims"].pop(),
        ),
        "status-bearing docs missing documentation_claims entries",
    )

    expect_failure(
        "boundary group cannot be marked closed",
        mutate_group(
            manifest,
            "terminal-ce-finite-bad-seed-soundness",
            lambda group: group.update({"id": "terminal-ce-synthetic-boundary"}),
        ),
        "boundary theorem group",
    )

    expect_failure(
        "completed label closed-only guard",
        mutate_manifest(
            manifest,
            lambda copy: copy["labels"]["completed formal protocol theorem"][
                "accepted_statuses"
            ].append("closed_under_msis_assumption"),
        ),
        "may only accept closed status",
    )

    expect_failure(
        "completed label preserves conditional blockers",
        mutate_manifest(
            manifest,
            lambda copy: copy["labels"]["completed formal protocol theorem"][
                "required_theorem_groups"
            ].remove("ce-opening-certified-binding"),
        ),
        "must include every conditional theorem group",
    )

    expect_failure(
        "completed label blocked by planned completion blockers",
        mutate_manifest(
            manifest,
            lambda copy: copy.update({"current_label": "completed formal protocol theorem"}),
        ),
        "requires theorem group",
    )

    expect_failure(
        "documentation overclaim blocked",
        mutate_manifest(
            manifest,
            lambda copy: copy["documentation_claims"][0].update(
                {"label": "completed formal protocol theorem"}
            ),
        ),
        "stronger than current label",
    )

    expect_failure(
        "completion blocker required by completed label",
        mutate_manifest(
            manifest,
            lambda copy: copy["labels"]["completed formal protocol theorem"][
                "required_theorem_groups"
            ].remove("superneo-full-probability-composition"),
        ),
        "must include completion blocker",
    )

    expect_failure(
        "completion blocker cannot be silently closed",
        mutate_group(
            manifest,
            "superneo-full-probability-composition",
            lambda group: group.update({
                "status": "closed",
                "declarations": ["SuperNeoFormal.superneo_end_to_end_from_ce_soundness"],
            }),
        ),
        "must remain planned until mechanized",
    )

    print("formal status validation regression tests passed")


if __name__ == "__main__":
    main()
