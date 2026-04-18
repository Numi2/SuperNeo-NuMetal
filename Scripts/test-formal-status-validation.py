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
            "typed-digest-width-parameterization",
            lambda group: group["declarations"].append("SuperNeoFormal.missingBindingTheorem"),
        ),
        "references missing declaration",
    )

    expect_failure(
        "closed group without declaration",
        mutate_group(
            manifest,
            "well-formed-transcript-injectivity",
            lambda group: group.update({"declarations": []}),
        ),
        "must list at least one declaration",
    )

    expect_failure(
        "question mark declaration names checked",
        mutate_group(
            manifest,
            "digest384-serialization",
            lambda group: group["declarations"].append("SuperNeoFormal.uintLEDecode?_missing"),
        ),
        "references missing declaration",
    )

    expect_failure(
        "duplicate declaration across theorem groups blocked",
        mutate_group(
            manifest,
            "digest384-serialization",
            lambda group: group.update({
                "lean_module": "SuperNeoFormal.WellFormedTranscript",
                "declarations": ["transcriptBytes_injective_of_wellFormed"],
            }),
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
            ].append("well-formed-transcript-injectivity"),
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
            "well-formed-transcript-injectivity",
            lambda group: group.update({"id": "synthetic-boundary"}),
        ),
        "boundary theorem group",
    )

    expect_failure(
        "completion theorem group cannot list assumption declaration",
        mutate_group(
            manifest,
            "well-formed-transcript-injectivity",
            lambda group: group["declarations"].append(
                "SuperNeoFormal.SyntheticAssumption"
            ),
        ),
        "assumption or boundary declaration",
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
            ].remove("well-formed-transcript-injectivity"),
        ),
        "must include every dependency theorem group",
    )

    expect_failure(
        "completed label blocked by non-closed open integrations",
        mutate_manifest(
            manifest,
            lambda copy: copy.update({"current_label": "completed formal protocol theorem"}),
        ),
        "must be closed at promotion",
    )

    expect_failure(
        "documentation overclaim blocked",
        mutate_manifest(
            manifest,
            lambda copy: (
                copy.update({"current_label": "conditional protocol formalization"}),
                [
                    group.update({"status": "planned", "declarations": []})
                    for group in copy["theorem_groups"]
                    if group["id"] in copy["open_integration_groups"]
                ],
            ),
        ),
        "which is stronger than current label",
    )

    expect_failure(
        "open integration required by current label",
        mutate_manifest(
            manifest,
            lambda copy: copy["labels"][
                "corrected finite-model core with open theorem-critical integrations"
            ][
                "required_theorem_groups"
            ].remove("terminal-ce-localization-instantiation"),
        ),
        "current corrected finite-model label must include open integration",
    )

    expect_failure(
        "missing open integration blocked",
        mutate_manifest(
            manifest,
            lambda copy: copy["open_integration_groups"].remove(
                "terminal-ce-localization-instantiation"
            ),
        ),
        "missing required integration",
    )

    expect_failure(
        "open integration must remain planned before promotion",
        mutate_group(
            manifest,
            "pirlc-crt-finite-soundness-completion",
            lambda group: group.update({
                "status": "closed",
                "declarations": ["pirlc_allInputsSound_of_seed_not_bad"],
            }),
        ),
        "must remain planned before promotion",
    )

    print("formal status validation regression tests passed")


if __name__ == "__main__":
    main()
