#!/usr/bin/env python3
"""Validate local Markdown evidence links used by the audit-facing docs."""

from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DOCS = [ROOT / "README.md", *sorted((ROOT / "Docs").glob("*.md"))]

MARKDOWN_LINK_RE = re.compile(r"(?<!!)\[[^\]]+\]\(([^)]+)\)")
CODE_DOC_PATH_RE = re.compile(
    r"`((?:Docs|SuperNeo-NuMetal|Formal|Scripts|TestVectors|Evidence|\.github)/[^`\s]+?\.md)`"
)


def fail(message: str) -> None:
    print(f"doc link validation failed: {message}", file=sys.stderr)
    raise SystemExit(1)


def clean_target(raw_target: str) -> str | None:
    target = raw_target.strip()
    if not target or target.startswith("#"):
        return None
    if target.startswith(("http://", "https://", "mailto:")):
        return None
    if " " in target and not target.startswith("<"):
        target = target.split(" ", 1)[0]
    target = target.removeprefix("<").removesuffix(">")
    target = target.split("#", 1)[0].split("?", 1)[0]
    return target or None


def resolve_target(source: Path, target: str) -> Path:
    if target.startswith(
        (
            "Docs/",
            "SuperNeo-NuMetal/",
            "Formal/",
            "Scripts/",
            "TestVectors/",
            "Evidence/",
            ".github/",
        )
    ):
        return ROOT / target
    return source.parent / target


def main() -> None:
    missing: list[str] = []
    for source in DOCS:
        text = source.read_text(encoding="utf-8")
        targets = [match.group(1) for match in MARKDOWN_LINK_RE.finditer(text)]
        targets.extend(match.group(1) for match in CODE_DOC_PATH_RE.finditer(text))
        for raw_target in targets:
            target = clean_target(raw_target)
            if target is None:
                continue
            resolved = resolve_target(source, target)
            if not resolved.exists():
                missing.append(f"{source.relative_to(ROOT)} -> {target}")

    if missing:
        fail("missing local Markdown targets:\n" + "\n".join(sorted(set(missing))))


if __name__ == "__main__":
    main()
