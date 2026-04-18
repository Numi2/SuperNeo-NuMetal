#!/usr/bin/env python3
import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any, Dict, Set


ROOT = Path(__file__).resolve().parents[1]
VALID_STATUSES = {
    "closed",
    "closed_under_msis_assumption",
    "closed_under_random_linear_combination_assumption",
    "closed_under_sumcheck_assumption",
    "closed_under_ce_opening_assumption",
    "closed_under_stage_assumptions",
    "planned",
}
DEFAULT_ACCEPTED_STATUSES = sorted(VALID_STATUSES - {"planned"})
FORMAL_STATUS_RE = re.compile(
    r"Formal status:\s*("
    r"bounded formalization|"
    r"partial formalization|"
    r"conditional protocol formalization|"
    r"corrected finite-model core with open theorem-critical integrations|"
    r"completed formal protocol theorem"
    r")",
    re.IGNORECASE,
)
LEAN_DECL_RE = re.compile(
    r"^\s*(?:noncomputable\s+)?(?:protected\s+|private\s+)?"
    r"(?:theorem|lemma|def|abbrev|structure|inductive|class)\s+([A-Za-z_][A-Za-z0-9_'?]*)(?![A-Za-z0-9_'?])",
    re.MULTILINE,
)
ASSUMPTION_DECL_RE = re.compile(r"(?:Assumption|Boundary)$")
COMPLETED_LABEL = "completed formal protocol theorem"
CONDITIONAL_LABEL = "conditional protocol formalization"
CURRENT_CORE_LABEL = "corrected finite-model core with open theorem-critical integrations"
REQUIRED_OPEN_INTEGRATIONS = {
    "terminal-ce-localization-instantiation",
    "pirlc-crt-finite-soundness-completion",
}


def fail(message: str) -> None:
    print(f"error: {message}", file=sys.stderr)
    raise SystemExit(1)


def module_to_path(module: str) -> Path:
    if module != "SuperNeoFormal" and not module.startswith("SuperNeoFormal."):
        fail(f"Lean module {module!r} must be under SuperNeoFormal")
    parts = module.split(".")
    if parts == ["SuperNeoFormal"]:
        return ROOT / "Formal" / "SuperNeoFormal.lean"
    return ROOT / "Formal" / "SuperNeoFormal" / Path(*parts[1:]).with_suffix(".lean")


def declared_names(module: str) -> Set[str]:
    path = module_to_path(module)
    if not path.exists():
        fail(f"Lean module {module!r} resolves to missing file {path.relative_to(ROOT)}")
    text = path.read_text(encoding="utf-8")
    namespace_match = re.search(r"^\s*namespace\s+SuperNeoFormal\b", text, re.MULTILINE)
    names = {match.group(1) for match in LEAN_DECL_RE.finditer(text)}
    if namespace_match:
        names.update(f"SuperNeoFormal.{name}" for name in list(names))
    return names


def validate_theorem_groups(manifest: Dict[str, Any]) -> Dict[str, str]:
    groups = manifest.get("theorem_groups")
    if not isinstance(groups, list):
        fail("theorem_groups must be an array")
    statuses: Dict[str, str] = {}
    modules: Dict[str, Set[str]] = {}
    declaration_groups: Dict[str, str] = {}

    for index, group in enumerate(groups):
        if not isinstance(group, dict):
            fail(f"theorem_groups[{index}] must be an object")
        group_id = group.get("id")
        status = group.get("status")
        module = group.get("lean_module")
        declarations = group.get("declarations")
        if not isinstance(group_id, str) or not group_id:
            fail(f"theorem_groups[{index}].id must be a non-empty string")
        if status not in VALID_STATUSES:
            fail(f"theorem_groups[{index}].status has unsupported value {status!r}")
        if group_id in statuses:
            fail(f"duplicate theorem group id {group_id!r}")
        if not isinstance(module, str) or not module:
            fail(f"theorem_groups[{index}].lean_module must be a non-empty string")
        if not isinstance(declarations, list) or not all(isinstance(item, str) for item in declarations):
            fail(f"theorem_groups[{index}].declarations must be an array of strings")
        if len(set(declarations)) != len(declarations):
            fail(f"theorem_groups[{index}].declarations contains duplicates")
        if status == "planned" and declarations:
            fail(f"planned theorem group {group_id!r} must not list closed declarations")
        if status != "planned" and not declarations:
            fail(f"closed theorem group {group_id!r} must list at least one declaration")
        if status == "closed":
            if group_id.endswith("-boundary"):
                fail(f"boundary theorem group {group_id!r} must not be marked closed")
            for declaration in declarations:
                short_name = declaration.rsplit(".", 1)[-1]
                if ASSUMPTION_DECL_RE.search(short_name):
                    fail(
                        f"closed theorem group {group_id!r} must not list assumption "
                        f"or boundary declaration {declaration!r}"
                    )

        names = modules.setdefault(module, declared_names(module))
        for declaration in declarations:
            if declaration not in names:
                fail(
                    f"theorem group {group_id!r} references missing declaration "
                    f"{declaration!r} in module {module!r}"
                )
            previous_group = declaration_groups.get(declaration)
            if previous_group is not None:
                fail(
                    f"declaration {declaration!r} appears in multiple theorem groups: "
                    f"{previous_group!r} and {group_id!r}"
                )
            declaration_groups[declaration] = group_id
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


def accepted_statuses(manifest: Dict[str, Any], label: str) -> Set[str]:
    labels = manifest["labels"]
    statuses = labels[label].get("accepted_statuses", DEFAULT_ACCEPTED_STATUSES)
    if not isinstance(statuses, list) or not all(isinstance(item, str) for item in statuses):
        fail(f"labels.{label}.accepted_statuses must be an array of strings")
    unknown = set(statuses) - VALID_STATUSES
    if unknown:
        fail(f"labels.{label}.accepted_statuses contains unsupported status {sorted(unknown)!r}")
    return set(statuses)


def validate_labels(manifest: Dict[str, Any], statuses: Dict[str, str]) -> None:
    labels = manifest.get("labels")
    if not isinstance(labels, dict) or not labels:
        fail("labels must be a non-empty object")
    seen_ranks: Dict[int, str] = {}
    for label, item in labels.items():
        if not isinstance(label, str) or not label:
            fail("labels keys must be non-empty strings")
        if not isinstance(item, dict):
            fail(f"labels.{label} must be an object")
        rank = item.get("rank")
        if not isinstance(rank, int):
            fail(f"labels.{label}.rank must be an integer")
        previous_label = seen_ranks.get(rank)
        if previous_label is not None:
            fail(f"labels {previous_label!r} and {label!r} share duplicate rank {rank}")
        seen_ranks[rank] = label
        groups = required_groups(manifest, label)
        if len(set(groups)) != len(groups):
            fail(f"labels.{label}.required_theorem_groups contains duplicates")
        for group in groups:
            if group not in statuses:
                fail(f"label {label!r} depends on unknown theorem group {group!r}")
        accepted_statuses(manifest, label)


def validate_label_dependencies(manifest: Dict[str, Any], label: str, statuses: Dict[str, str]) -> None:
    allowed = accepted_statuses(manifest, label)
    for group in required_groups(manifest, label):
        status = statuses.get(group)
        if status is None:
            fail(f"label {label!r} depends on unknown theorem group {group!r}")
        if status not in allowed:
            fail(
                f"label {label!r} requires theorem group {group!r} to have one of "
                f"{sorted(allowed)!r}, got {status!r}"
            )


def validate_completion_label_guard(manifest: Dict[str, Any]) -> None:
    labels = manifest.get("labels")
    if not isinstance(labels, dict):
        fail("labels must be an object")
    if COMPLETED_LABEL in labels:
        completed_statuses = accepted_statuses(manifest, COMPLETED_LABEL)
        if completed_statuses != {"closed"}:
            fail("completed formal protocol theorem may only accept closed status")
    if COMPLETED_LABEL in labels and CONDITIONAL_LABEL in labels:
        conditional_groups = set(required_groups(manifest, CONDITIONAL_LABEL))
        completed_groups = set(required_groups(manifest, COMPLETED_LABEL))
        missing = sorted(conditional_groups - completed_groups)
        if missing:
            fail(
                "completed formal protocol theorem must include every dependency "
                f"theorem group; missing {missing!r}"
            )


def validate_open_integrations(manifest: Dict[str, Any], statuses: Dict[str, str]) -> None:
    integrations = manifest.get("open_integration_groups")
    if not isinstance(integrations, list) or not all(isinstance(item, str) for item in integrations):
        fail("open_integration_groups must be an array of strings")
    if len(set(integrations)) != len(integrations):
        fail("open_integration_groups contains duplicates")
    missing_required = sorted(REQUIRED_OPEN_INTEGRATIONS - set(integrations))
    if missing_required:
        fail(f"open_integration_groups missing required integration(s): {missing_required!r}")
    unknown_required = sorted(set(integrations) - REQUIRED_OPEN_INTEGRATIONS)
    if unknown_required:
        fail(f"open_integration_groups contains unsupported integration(s): {unknown_required!r}")

    labels = manifest.get("labels")
    if not isinstance(labels, dict):
        fail("labels must be an object")
    completed_groups = set(required_groups(manifest, COMPLETED_LABEL)) if COMPLETED_LABEL in labels else set()
    current_groups = set(required_groups(manifest, CURRENT_CORE_LABEL)) if CURRENT_CORE_LABEL in labels else set()
    current_label = manifest.get("current_label")
    if not isinstance(current_label, str):
        fail("current_label must be a string")
    promoted = current_label == COMPLETED_LABEL

    for integration in integrations:
        status = statuses.get(integration)
        if status is None:
            fail(f"open integration {integration!r} is not a theorem group")
        if promoted:
            if status != "closed":
                fail(f"open integration {integration!r} must be closed at promotion")
        elif status != "planned":
            fail(f"open integration {integration!r} must remain planned before promotion")
        if integration not in current_groups:
            fail(f"current corrected finite-model label must include open integration {integration!r}")
        if integration not in completed_groups:
            fail(f"completed formal protocol theorem must include open integration {integration!r}")


def validate_completion_group_declarations(manifest: Dict[str, Any]) -> None:
    labels = manifest.get("labels")
    if not isinstance(labels, dict) or COMPLETED_LABEL not in labels:
        return
    completion_groups = set(required_groups(manifest, COMPLETED_LABEL))
    groups = manifest.get("theorem_groups")
    if not isinstance(groups, list):
        fail("theorem_groups must be an array")
    by_id = {
        group.get("id"): group
        for group in groups
        if isinstance(group, dict) and isinstance(group.get("id"), str)
    }
    for group_id in sorted(completion_groups):
        group = by_id.get(group_id)
        if group is None:
            fail(f"completed formal protocol theorem depends on unknown theorem group {group_id!r}")
        declarations = group.get("declarations")
        if not isinstance(declarations, list):
            fail(f"theorem group {group_id!r}.declarations must be an array")
        for declaration in declarations:
            if not isinstance(declaration, str):
                fail(f"theorem group {group_id!r}.declarations must be an array of strings")
            short_name = declaration.rsplit(".", 1)[-1]
            if ASSUMPTION_DECL_RE.search(short_name):
                fail(
                    f"completion theorem group {group_id!r} must not list assumption "
                    f"or boundary declaration {declaration!r}"
                )


def validate_docs(manifest: Dict[str, Any]) -> None:
    current_label = manifest.get("current_label")
    if not isinstance(current_label, str):
        fail("current_label must be a string")
    current_rank = label_rank(manifest, current_label)
    claims = manifest.get("documentation_claims")
    if not isinstance(claims, list):
        fail("documentation_claims must be an array")
    seen_paths: Set[str] = set()

    for index, claim in enumerate(claims):
        if not isinstance(claim, dict):
            fail(f"documentation_claims[{index}] must be an object")
        rel_path = claim.get("path")
        expected_label = claim.get("label")
        if not isinstance(rel_path, str) or not isinstance(expected_label, str):
            fail(f"documentation_claims[{index}] requires path and label strings")
        if rel_path in seen_paths:
            fail(f"duplicate documentation claim path {rel_path!r}")
        seen_paths.add(rel_path)
        if expected_label == COMPLETED_LABEL and current_label != COMPLETED_LABEL:
            fail(f"{rel_path} claims completed formal protocol theorem before promotion")
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
            if found == COMPLETED_LABEL and current_label != COMPLETED_LABEL:
                fail(f"{rel_path} contains completed formal protocol theorem before promotion")
            if label_rank(manifest, found) > current_rank:
                fail(f"{rel_path} contains stronger formal status {found!r} than manifest current label {current_label!r}")

    status_docs = set()
    for path in (ROOT / "Docs").glob("*.md"):
        rel_path = path.relative_to(ROOT).as_posix()
        text = path.read_text(encoding="utf-8")
        if FORMAL_STATUS_RE.search(text):
            status_docs.add(rel_path)
    unclaimed = sorted(status_docs - seen_paths)
    if unclaimed:
        fail(f"status-bearing docs missing documentation_claims entries: {unclaimed!r}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Validate SuperNeo formal-status manifest and docs labels.")
    parser.add_argument("manifest", nargs="?", default=str(ROOT / "Docs" / "FormalStatus.json"))
    args = parser.parse_args()

    manifest_path = Path(args.manifest)
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    if manifest.get("schema") != "superneo.formal-status.v1":
        fail("unexpected formal status schema")
    statuses = validate_theorem_groups(manifest)
    validate_labels(manifest, statuses)
    validate_completion_label_guard(manifest)
    validate_open_integrations(manifest, statuses)
    validate_completion_group_declarations(manifest)
    current_label = manifest.get("current_label")
    if not isinstance(current_label, str):
        fail("current_label must be a string")
    validate_label_dependencies(manifest, current_label, statuses)
    validate_docs(manifest)
    print(f"validated {manifest_path}")


if __name__ == "__main__":
    main()
