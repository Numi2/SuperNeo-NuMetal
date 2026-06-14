#!/usr/bin/env python3
"""Guarded production-security claim promotion entrypoint.

The script intentionally refuses to edit claim fields unless a promotion status
packet proves every required evidence lane is closed.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]


def fail(message: str) -> None:
    print(f"production-security promotion failed: {message}", file=sys.stderr)
    raise SystemExit(1)


def read_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        fail(f"{path} is not valid JSON: {error}")
    if not isinstance(value, dict):
        fail(f"{path} root must be an object")
    return value


def require_promotable(status: dict[str, Any]) -> None:
    if status.get("productionSecurityClaimsPromotable") is not True:
        blockers = status.get("blockers", [])
        if isinstance(blockers, dict):
            detail = json.dumps(blockers, indent=2, sort_keys=True)
        elif isinstance(blockers, list):
            detail = "\n".join(f"- {item}" for item in blockers)
        else:
            detail = "status packet did not include blockers"
        fail(f"evidence is not promotable:\n{detail}")

    blockers = status.get("blockers")
    if not isinstance(blockers, dict) or any(blockers.values()):
        fail("status packet is promotable but still contains blockers")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--status", required=True, type=Path, help="promotion status JSON from collect-production-security-promotion-status.py")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="verify the status packet without editing repository evidence files",
    )
    args = parser.parse_args()

    status_path = args.status if args.status.is_absolute() else ROOT / args.status
    status = read_json(status_path)
    require_promotable(status)
    if args.dry_run:
        print("production-security promotion evidence is complete")
        return

    fail(
        "automatic file promotion is intentionally not implemented until a completed status packet "
        "is checked in and reviewed; rerun with --dry-run to verify evidence closure first"
    )


if __name__ == "__main__":
    main()
