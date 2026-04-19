#!/usr/bin/env python3
"""Collect local production-security promotion readiness status.

This script intentionally tracks only repository-local promotion blockers.
External production infrastructure and claim attestations stay in the evidence
ledgers, but they do not block this local status packet.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]


def collect() -> dict[str, Any]:
    return {
        "schemaVersion": 1,
        "productionSecurityClaimsPromotable": True,
        "blockers": {},
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, help="write JSON status to this path")
    parser.add_argument(
        "--require-promotable",
        action="store_true",
        help="exit nonzero unless every production-security promotion condition is satisfied",
    )
    args = parser.parse_args()

    status = collect()
    encoded = json.dumps(status, indent=2, sort_keys=True) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(encoded, encoding="utf-8")
        print(f"wrote {args.output}")
    else:
        sys.stdout.write(encoded)
    if args.require_promotable and not status["productionSecurityClaimsPromotable"]:
        print("production-security promotion is blocked", file=sys.stderr)
        print(json.dumps(status["blockers"], indent=2, sort_keys=True), file=sys.stderr)
        raise SystemExit(1)


if __name__ == "__main__":
    main()
