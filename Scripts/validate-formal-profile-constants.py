#!/usr/bin/env python3
import argparse
import re
import sys
from pathlib import Path
from typing import Dict, List


ROOT = Path(__file__).resolve().parents[1]


def fail(message: str) -> None:
    print(f"error: {message}", file=sys.stderr)
    raise SystemExit(1)


def read(path: Path) -> str:
    if not path.exists():
        fail(f"missing required file {path}")
    return path.read_text(encoding="utf-8")


def parse_int_literal(value: str) -> int:
    value = value.strip().replace("_", "")
    return int(value, 0)


def parse_lean_nat_defs(text: str) -> Dict[str, int]:
    constants: Dict[str, int] = {}
    pattern = re.compile(r"^\s*def\s+([A-Za-z_][A-Za-z0-9_']*)\s*:\s*Nat\s*:=\s*([0-9][0-9_]*)\s*$", re.MULTILINE)
    for match in pattern.finditer(text):
        constants[match.group(1)] = parse_int_literal(match.group(2))
    return constants


def parse_lean_challenge_set(text: str) -> List[int]:
    match = re.search(
        r"def\s+challengeCoefficientSet\s*:\s*Finset\s+Int\s*:=\s*\{([^}]*)\}",
        text,
        re.MULTILINE,
    )
    if not match:
        fail("could not find Lean challengeCoefficientSet")
    return [int(part.strip()) for part in match.group(1).split(",") if part.strip()]


def parse_swift_int(text: str, name: str) -> int:
    pattern = re.compile(rf"\b(?:public\s+)?let\s+{re.escape(name)}(?:\s*:\s*[^=]+)?\s*=\s*([0-9][0-9_]*)")
    match = pattern.search(text)
    if not match:
        fail(f"could not find Swift integer constant {name}")
    return parse_int_literal(match.group(1))


def parse_swift_static_int(text: str, name: str) -> int:
    pattern = re.compile(
        rf"\bpublic\s+static\s+let\s+{re.escape(name)}(?:\s*:\s*[^=]+)?\s*=\s*(0x[0-9A-Fa-f_]+|[0-9][0-9_]*)"
    )
    match = pattern.search(text)
    if not match:
        fail(f"could not find Swift static integer constant {name}")
    return parse_int_literal(match.group(1))


def parse_swift_profile_argument(text: str, name: str) -> int:
    pattern = re.compile(rf"\b{re.escape(name)}\s*:\s*([0-9][0-9_]*)")
    match = pattern.search(text)
    if not match:
        fail(f"could not find Swift profile argument {name}")
    return parse_int_literal(match.group(1))


def parse_swift_int_array(text: str, name: str) -> List[int]:
    pattern = re.compile(
        rf"\b(?:public\s+)?let\s+{re.escape(name)}(?:\s*:\s*[^=]+)?\s*=\s*\[([^]]*)\]"
    )
    match = pattern.search(text)
    if not match:
        fail(f"could not find Swift integer array {name}")
    return [int(part.strip()) for part in match.group(1).split(",") if part.strip()]


def require_equal(name: str, lean_value: int, swift_value: int) -> None:
    if lean_value != swift_value:
        fail(f"{name} mismatch: Lean has {lean_value}, Swift has {swift_value}")


def require_array_equal(name: str, lean_value: List[int], swift_value: List[int]) -> None:
    if lean_value != swift_value:
        fail(f"{name} mismatch: Lean has {lean_value}, Swift has {swift_value}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Validate Lean formal profile constants against Swift.")
    parser.add_argument("--root", default=str(ROOT), help="repository root")
    args = parser.parse_args()

    root = Path(args.root).resolve()
    lean_profile = read(root / "Formal" / "SuperNeoFormal" / "Profile.lean")
    lean_challenges = read(root / "Formal" / "SuperNeoFormal" / "ChallengeSampling.lean")
    swift_field = read(root / "SuperNeo-NuMetal" / "Fields" / "GoldilocksField.swift")
    swift_ring = read(root / "SuperNeo-NuMetal" / "Rings" / "CyclotomicRing54.swift")

    lean_constants = parse_lean_nat_defs(lean_profile)
    required_lean = [
        "goldilocksModulus",
        "phi81Index",
        "phi81Degree",
        "kappa",
        "decompositionLength",
        "normBound",
        "challengeExpansionFactor",
        "freshBatchCount",
        "paperClaimThresholdBits",
    ]
    for name in required_lean:
        if name not in lean_constants:
            fail(f"could not find Lean Nat constant {name}")

    require_equal("goldilocksModulus", lean_constants["goldilocksModulus"], parse_swift_static_int(swift_field, "modulus"))
    require_equal("phi81Degree", lean_constants["phi81Degree"], parse_swift_static_int(swift_ring, "degree"))
    require_equal("phi81Index", lean_constants["phi81Index"], parse_swift_profile_argument(swift_ring, "cyclotomicIndex"))
    require_equal("ringDegree", lean_constants["phi81Degree"], parse_swift_int(swift_ring, "ringDegree"))
    require_equal("kappa", lean_constants["kappa"], parse_swift_int(swift_ring, "kappa"))
    require_equal("normBound", lean_constants["normBound"], parse_swift_int(swift_ring, "normBound"))
    require_equal(
        "decompositionLength",
        lean_constants["decompositionLength"],
        parse_swift_int(swift_ring, "decompositionLength"),
    )
    require_equal(
        "maxPriorClaimCount",
        lean_constants["decompositionLength"],
        parse_swift_int(swift_ring, "maxPriorClaimCount"),
    )
    require_equal(
        "challengeExpansionFactor",
        lean_constants["challengeExpansionFactor"],
        parse_swift_int(swift_ring, "challengeExpansionFactor"),
    )
    require_equal(
        "freshBatchCount",
        lean_constants["freshBatchCount"],
        parse_swift_int(swift_ring, "maxFreshBatchCount"),
    )
    require_equal(
        "paperClaimThresholdBits",
        lean_constants["paperClaimThresholdBits"],
        parse_swift_int(swift_ring, "claimedSecurityBits"),
    )
    require_array_equal(
        "challengeCoefficientSet",
        parse_lean_challenge_set(lean_challenges),
        parse_swift_int_array(swift_ring, "challengeCoefficients"),
    )

    print(f"validated formal profile constants under {root}")


if __name__ == "__main__":
    main()
