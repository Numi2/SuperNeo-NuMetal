#!/usr/bin/env python3
"""Regression tests for guarded production-security promotion tooling."""

from __future__ import annotations

import json
import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
COLLECT = ROOT / "Scripts" / "collect-production-security-promotion-status.py"
PROMOTE = ROOT / "Scripts" / "promote-production-security-claims.py"


def run(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        args,
        cwd=ROOT,
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def main() -> None:
    status = run(str(COLLECT))
    if status.returncode != 0:
        raise AssertionError(status.stderr or status.stdout)
    payload = json.loads(status.stdout)
    if payload.get("productionSecurityClaimsPromotable") is not False:
        raise AssertionError("current checked-in evidence must not be promotable")
    blockers = payload.get("blockers")
    if not isinstance(blockers, list) or not blockers:
        raise AssertionError("collector must report concrete blockers")
    if not any("total-loss term not instantiated" in blocker for blocker in blockers):
        raise AssertionError("collector must report missing total-loss terms")

    required = run(str(COLLECT), "--require-promotable")
    if required.returncode == 0:
        raise AssertionError("--require-promotable must fail on current evidence")
    if "production-security promotion is blocked" not in required.stderr:
        raise AssertionError(required.stderr)

    with tempfile.TemporaryDirectory(prefix=".prod-promotion-test-", dir=ROOT) as raw_tmp:
        status_path = Path(raw_tmp) / "status.json"
        status_path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        promoted = run(str(PROMOTE), "--status", str(status_path), "--dry-run")
        if promoted.returncode == 0:
            raise AssertionError("guarded promotion must reject non-promotable evidence")
        if "evidence is not promotable" not in promoted.stderr:
            raise AssertionError(promoted.stderr)

    print("production security promotion tooling tests passed")


if __name__ == "__main__":
    main()
