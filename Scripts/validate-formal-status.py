#!/usr/bin/env python3
import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any, Dict


ROOT = Path(__file__).resolve().parents[1]
VALID_STATUSES = {"closed", "closed_under_msis_assumption", "planned"}
FORMAL_STATUS_RE = re.compile(
    r"Formal status:\s*(bounded formalization|partial formalization|completed formal protocol theorem)",
    re.IGNORECASE,
)


def fail(message: str) -> None:
    print(f"error: {message}", file=sys.stderr)
    raise SystemExit(1)


def group_statuses(manifest: Dict[str, Any]) -> Dict[str, str]:
    groups = manifest.get("theorem_groups")
    if not isinstance(groups, list):
        fail("theorem_groups must be an array")
    statuses: Dict[str, str] = {}
    for index, group in enumerate(groups):
        if not isinstance(group, dict):
            fail(f"theorem_groups[{index}] must be an object")
        group_id = group.get("id")
        status = group.get("status")
        if not isinstance(group_id, str) or not group_id:
            fail(f"theorem_groups[{index}].id must be a non-empty string")
        if status not in VALID_STATUSES:
            fail(f"theorem_groups[{index}].status has unsupported value {status!r}")
        statuses[group_id] = status
    return statuses


def label_rank(manifest: Dict[str, Any], label: str) -> int:
    labels = manifest.get("labels")
    if not isinstance(labels, dict):
        fail("labels must be an object")
    item = labels.get(label)
    if not isinstance(item, dict):
        fail(f"unknown formal label {label!r}")
    rank = item.get("rank")
    if not isinstance(rank, int):
        fail(f"labels.{label}.rank must be an integer")
    return rank


def required_groups(manifest: Dict[str, Any], label: str) -> list:
    labels = manifest["labels"]
    groups = labels[label].get("required_theorem_groups")
    if not isinstance(groups, list) or not all(isinstance(item, str) for item in groups):
        fail(f"labels.{label}.required_theorem_groups must be an array of strings")
    return groups


def validate_label_dependencies(manifest: Dict[str, Any], label: str, statuses: Dict[str, str]) -> None:
    for group in required_groups(manifest, label):
        status = statuses.get(group)
        if status is None:
            fail(f"label {label!r} depends on unknown theorem group {group!r}")
        if status == "planned":
            fail(f"label {label!r} depends on planned theorem group {group!r}")


def validate_docs(manifest: Dict[str, Any]) -> None:
    current_label = manifest.get("current_label")
    if not isinstance(current_label, str):
        fail("current_label must be a string")
    current_rank = label_rank(manifest, current_label)
    claims = manifest.get("documentation_claims")
    if not isinstance(claims, list):
        fail("documentation_claims must be an array")

    for index, claim in enumerate(claims):
        if not isinstance(claim, dict):
            fail(f"documentation_claims[{index}] must be an object")
        rel_path = claim.get("path")
        expected_label = claim.get("label")
        if not isinstance(rel_path, str) or not isinstance(expected_label, str):
            fail(f"documentation_claims[{index}] requires path and label strings")
        if label_rank(manifest, expected_label) > current_rank:
            fail(f"{rel_path} claims {expected_label!r}, which is stronger than current label {current_label!r}")
        path = ROOT / rel_path
        if not path.exists():
            fail(f"{rel_path} does not exist")
        text = path.read_text(encoding="utf-8")
        matches = {match.group(1).lower() for match in FORMAL_STATUS_RE.finditer(text)}
        if expected_label.lower() not in matches:
            fail(f"{rel_path} must contain 'Formal status: {expected_label}'")
        for found in matches:
            if label_rank(manifest, found) > current_rank:
                fail(f"{rel_path} contains stronger formal status {found!r} than manifest current label {current_label!r}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Validate SuperNeo formal-status manifest and docs labels.")
    parser.add_argument("manifest", nargs="?", default=str(ROOT / "Docs" / "FormalStatus.json"))
    args = parser.parse_args()

    manifest_path = Path(args.manifest)
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    if manifest.get("schema") != "superneo.formal-status.v1":
        fail("unexpected formal status schema")
    statuses = group_statuses(manifest)
    current_label = manifest.get("current_label")
    if not isinstance(current_label, str):
        fail("current_label must be a string")
    validate_label_dependencies(manifest, current_label, statuses)
    validate_docs(manifest)
    print(f"validated {manifest_path}")


if __name__ == "__main__":
    main()
