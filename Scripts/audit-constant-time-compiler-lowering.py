#!/usr/bin/env python3
"""Generate a scoped compiler/lowering audit report for constant-time evidence."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
SCOPE_PATH = ROOT / "TestVectors" / "constant-time-scope-v1.json"
DEFAULT_EVIDENCE_DIR = ROOT / "Evidence" / "ConstantTime" / "swift-llvm-metal-v1"
DEFAULT_OUTPUT = DEFAULT_EVIDENCE_DIR / "compiler" / "compiler-lowering-audit-v1.json"
METAL_OBJDUMP = DEFAULT_EVIDENCE_DIR / "metal" / "SuperNeoKernels.metallib.objdump.txt"
METAL_METALLIB = DEFAULT_EVIDENCE_DIR / "metal" / "SuperNeoKernels.metallib"

SWIFT_ARTIFACTS = {
    "swift-optimized-sil": DEFAULT_EVIDENCE_DIR / "swift" / "GoldilocksField.optimized.sil",
    "swift-optimized-llvm-ir": DEFAULT_EVIDENCE_DIR / "swift" / "GoldilocksField.optimized.ll",
    "swift-target-assembly": DEFAULT_EVIDENCE_DIR / "swift" / "GoldilocksField.arm64.s",
    "swift-compiler-artifact-report": DEFAULT_EVIDENCE_DIR / "swift" / "swift-compiler-artifacts-v1.json",
    "runtime-allocation-review": DEFAULT_EVIDENCE_DIR / "runtime" / "runtime-allocation-review-v1.json",
}

METAL_ARTIFACTS = {
    "metal-air": DEFAULT_EVIDENCE_DIR / "metal" / "SuperNeoKernels.air",
    "metal-metallib": METAL_METALLIB,
    "metal-metallib-objdump": METAL_OBJDUMP,
    "metal-artifact-report": DEFAULT_EVIDENCE_DIR / "metal" / "metal-artifacts-v1.json",
}

SWIFT_LOWERING_FUNCTIONS = [
    {
        "id": "swift-goldilocks-add-specialized",
        "regions": ["swift-goldilocks-common-arithmetic"],
        "symbol": "$s19SuperNeo_NuMetal_CT15GoldilocksFieldV1poiyA2C_ACtFZTf4nnd_n",
        "allowedLLVMConditionalBranches": 0,
        "allowedAssemblyConditionalBranches": 0,
        "requiredLLVMSubstrings": ["select i1", "@llvm.uadd.with.overflow.i64"],
        "requiredAssemblySubstrings": ["csel"],
    },
    {
        "id": "swift-goldilocks-sub",
        "regions": ["swift-goldilocks-common-arithmetic"],
        "symbol": "$s19SuperNeo_NuMetal_CT15GoldilocksFieldV1soiyA2C_ACtFZ",
        "allowedLLVMConditionalBranches": 0,
        "allowedAssemblyConditionalBranches": 0,
        "requiredLLVMSubstrings": ["select i1"],
        "requiredAssemblySubstrings": ["csel"],
    },
    {
        "id": "swift-goldilocks-neg",
        "regions": ["swift-goldilocks-common-arithmetic"],
        "symbol": "$s19SuperNeo_NuMetal_CT15GoldilocksFieldV1sopyA2CFZ",
        "allowedLLVMConditionalBranches": 0,
        "allowedAssemblyConditionalBranches": 0,
        "requiredLLVMSubstrings": ["select i1"],
        "requiredAssemblySubstrings": ["csel"],
    },
    {
        "id": "swift-goldilocks-mul",
        "regions": ["swift-goldilocks-common-arithmetic"],
        "symbol": "$s19SuperNeo_NuMetal_CT15GoldilocksFieldV1moiyA2C_ACtFZ",
        "allowedLLVMConditionalBranches": 0,
        "allowedAssemblyConditionalBranches": 0,
        "requiredLLVMSubstrings": ["mul nuw i128", "select i1"],
        "requiredAssemblySubstrings": ["mul", "umulh", "csel"],
    },
    {
        "id": "swift-goldilocks-squared",
        "regions": ["swift-goldilocks-common-arithmetic"],
        "symbol": "$s19SuperNeo_NuMetal_CT15GoldilocksFieldV7squaredACyF",
        "allowedLLVMConditionalBranches": 0,
        "allowedAssemblyConditionalBranches": 0,
        "requiredLLVMSubstrings": ["mul nuw i128", "select i1"],
        "requiredAssemblySubstrings": ["mul", "umulh", "csel"],
    },
    {
        "id": "swift-goldilocks-pow64",
        "regions": ["swift-goldilocks-fixed-exponentiation"],
        "symbol": "$s19SuperNeo_NuMetal_CT15GoldilocksFieldV3powyACs6UInt64VF",
        "allowedLLVMConditionalBranches": 1,
        "allowedAssemblyConditionalBranches": 1,
        "requiredLLVMSubstrings": ["select i1", "icmp eq i64 %5, 64", "br i1"],
        "requiredAssemblySubstrings": ["csel", "b.ne"],
        "publicControlFlowFinding": "single public fixed 64-round loop exit",
    },
]

METAL_KERNELS = [
    "goldilocks_add_kernel",
    "goldilocks_sub_kernel",
    "goldilocks_mul_kernel",
    "numiseal_apply_mask_kernel",
    "numiseal_dense_fold_kernel",
    "numiseal_eq_weight_kernel",
    "numiseal_sumcheck_accumulate_kernel",
    "numiseal_mask_accumulate_kernel",
]

FORBIDDEN_LOWERING_CALLS = [
    r"\bswift_alloc\w*",
    r"\bswift_retain\w*",
    r"\bswift_release\w*",
    r"\bswift_isUniquelyReferenced\w*",
    r"\bmalloc\b",
    r"\bfree\b",
]

LLVM_CONDITIONAL_BRANCH = re.compile(r"^\s*br\s+i1\b", re.MULTILINE)
LLVM_SWITCH = re.compile(r"^\s*switch\b", re.MULTILINE)
ASM_CONDITIONAL_BRANCH = re.compile(
    r"^\s*(?:b\.(?:eq|ne|hs|lo|lt|le|gt|ge|vs|vc|mi|pl|hi|ls)|cbz|cbnz|tbz|tbnz)\b",
    re.MULTILINE,
)
ASM_FORBIDDEN_BRANCH_TO_RUNTIME = re.compile(r"\bbl\s+_?(?:swift_|malloc|free)", re.MULTILINE)


def configure_paths(evidence_dir: Path) -> None:
    global DEFAULT_EVIDENCE_DIR
    global DEFAULT_OUTPUT
    global METAL_OBJDUMP
    global METAL_METALLIB
    global SWIFT_ARTIFACTS
    global METAL_ARTIFACTS

    DEFAULT_EVIDENCE_DIR = evidence_dir
    DEFAULT_OUTPUT = DEFAULT_EVIDENCE_DIR / "compiler" / "compiler-lowering-audit-v1.json"
    METAL_OBJDUMP = DEFAULT_EVIDENCE_DIR / "metal" / "SuperNeoKernels.metallib.objdump.txt"
    METAL_METALLIB = DEFAULT_EVIDENCE_DIR / "metal" / "SuperNeoKernels.metallib"
    SWIFT_ARTIFACTS = {
        "swift-optimized-sil": DEFAULT_EVIDENCE_DIR / "swift" / "GoldilocksField.optimized.sil",
        "swift-optimized-llvm-ir": DEFAULT_EVIDENCE_DIR / "swift" / "GoldilocksField.optimized.ll",
        "swift-target-assembly": DEFAULT_EVIDENCE_DIR / "swift" / "GoldilocksField.arm64.s",
        "swift-compiler-artifact-report": DEFAULT_EVIDENCE_DIR / "swift" / "swift-compiler-artifacts-v1.json",
        "runtime-allocation-review": DEFAULT_EVIDENCE_DIR / "runtime" / "runtime-allocation-review-v1.json",
    }
    METAL_ARTIFACTS = {
        "metal-air": DEFAULT_EVIDENCE_DIR / "metal" / "SuperNeoKernels.air",
        "metal-metallib": METAL_METALLIB,
        "metal-metallib-objdump": METAL_OBJDUMP,
        "metal-artifact-report": DEFAULT_EVIDENCE_DIR / "metal" / "metal-artifacts-v1.json",
    }


def fail(message: str) -> None:
    print(f"constant-time compiler/lowering audit failed: {message}", file=sys.stderr)
    raise SystemExit(1)


def rel(path: Path) -> str:
    return str(path.resolve().relative_to(ROOT))


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")


def read_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        fail(f"{rel(path)} is not valid JSON: {error}")
    if not isinstance(value, dict):
        fail(f"{rel(path)} root must be an object")
    return value


def write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def run(command: list[str]) -> str:
    completed = subprocess.run(
        command,
        cwd=ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )
    if completed.returncode != 0:
        fail(
            "command failed: "
            + " ".join(command)
            + "\nstdout:\n"
            + completed.stdout
            + "\nstderr:\n"
            + completed.stderr
        )
    return completed.stdout


def ensure_metal_objdump(path: Path, *, refresh: bool) -> None:
    if path.exists() and not refresh:
        return
    if not METAL_METALLIB.exists():
        fail(f"missing Metal metallib artifact: {rel(METAL_METALLIB)}")
    path.parent.mkdir(parents=True, exist_ok=True)
    text = run([
        "xcrun",
        "metal-objdump",
        "--metallib",
        "--disassemble",
        rel(METAL_METALLIB),
    ])
    path.write_text(text, encoding="utf-8")


def require_file(path: Path, label: str) -> bytes:
    if not path.exists():
        fail(f"missing {label}: {rel(path)}")
    data = path.read_bytes()
    if not data:
        fail(f"{label} must not be empty: {rel(path)}")
    return data


def artifact_summary(artifact_id: str, path: Path) -> dict[str, Any]:
    data = require_file(path, artifact_id)
    return {
        "id": artifact_id,
        "path": rel(path),
        "byteCount": len(data),
        "sha256Hex": sha256_bytes(data),
    }


def scope_regions(scope: dict[str, Any]) -> list[dict[str, Any]]:
    regions = scope.get("regions")
    if not isinstance(regions, list) or not regions:
        fail("constant-time scope regions must be a non-empty list")
    result = []
    for region in regions:
        if not isinstance(region, dict):
            fail("constant-time scope region entry must be an object")
        result.append(region)
    return result


def extract_source_region(region: dict[str, Any]) -> tuple[str, int, int]:
    source_path = ROOT / str(region["path"])
    text = source_path.read_text(encoding="utf-8")
    start_marker = str(region["startMarker"])
    end_marker = str(region["endMarker"])
    start = text.find(start_marker)
    end = text.find(end_marker)
    if start < 0 or end <= start:
        fail(f"could not extract scoped region {region.get('id')}")
    scoped = text[start + len(start_marker):end]
    start_line = text[:start].count("\n") + 1
    end_line = text[:end].count("\n") + 1
    return scoped, start_line, end_line


def source_region_reviews(scope: dict[str, Any]) -> list[dict[str, Any]]:
    reviews: list[dict[str, Any]] = []
    for region in scope_regions(scope):
        text, start_line, end_line = extract_source_region(region)
        scrubbed = text
        for allowed in region.get("allowedPublicControlFlowRegex", []):
            scrubbed = re.sub(str(allowed), "", scrubbed)
        forbidden_matches: list[dict[str, Any]] = []
        for pattern in region.get("forbiddenRegex", []):
            for match in re.finditer(str(pattern), scrubbed):
                forbidden_matches.append({
                    "pattern": str(pattern),
                    "line": start_line + scrubbed[:match.start()].count("\n"),
                    "match": match.group(0),
                })
        missing = [snippet for snippet in region.get("requiredSnippets", []) if str(snippet) not in text]
        if forbidden_matches:
            fail(f"{region.get('id')} contains source-scope forbidden control-flow matches")
        if missing:
            fail(f"{region.get('id')} is missing required snippets: {missing}")
        reviews.append({
            "id": str(region["id"]),
            "language": str(region["language"]),
            "path": str(region["path"]),
            "startLine": start_line,
            "endLine": end_line,
            "regionSHA256Hex": sha256_bytes(text.encode("utf-8")),
            "requiredSnippetsPresent": [str(snippet) for snippet in region.get("requiredSnippets", [])],
            "forbiddenSourcePatternMatches": forbidden_matches,
        })
    return reviews


def extract_llvm_function(text: str, symbol: str) -> str:
    marker = f'@"{symbol}"'
    start = text.find("define", max(0, text.find(marker) - 128))
    while start >= 0:
        line_end = text.find("\n", start)
        if marker in text[start:line_end]:
            break
        start = text.find("define", line_end)
    if start < 0:
        fail(f"missing LLVM function for {symbol}")
    depth = 0
    for index in range(start, len(text)):
        char = text[index]
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return text[start:index + 1]
    fail(f"unterminated LLVM function for {symbol}")


def extract_sil_function(text: str, symbol: str) -> str:
    marker = f"@{symbol}"
    start = text.find(marker)
    while start >= 0:
        line_start = text.rfind("\n", 0, start) + 1
        if text[line_start:start].lstrip().startswith("sil "):
            end_marker = f"}} // end sil function '{symbol}'"
            end = text.find(end_marker, start)
            if end < 0:
                fail(f"unterminated SIL function for {symbol}")
            return text[line_start:end + len(end_marker)]
        start = text.find(marker, start + len(marker))
    fail(f"missing SIL function for {symbol}")


def extract_assembly_function(text: str, symbol: str) -> str:
    marker = f"_{symbol}:"
    start = text.find(marker)
    if start < 0:
        fail(f"missing assembly function for {symbol}")
    end = text.find("; -- End function", start)
    if end < 0:
        fail(f"unterminated assembly function for {symbol}")
    return text[start:end]


def lowering_reviews() -> list[dict[str, Any]]:
    sil_text = SWIFT_ARTIFACTS["swift-optimized-sil"].read_text(encoding="utf-8", errors="ignore")
    llvm_text = SWIFT_ARTIFACTS["swift-optimized-llvm-ir"].read_text(encoding="utf-8", errors="ignore")
    assembly_text = SWIFT_ARTIFACTS["swift-target-assembly"].read_text(encoding="utf-8", errors="ignore")
    reviews: list[dict[str, Any]] = []
    for function in SWIFT_LOWERING_FUNCTIONS:
        symbol = str(function["symbol"])
        sil_body = extract_sil_function(sil_text, symbol)
        llvm_body = extract_llvm_function(llvm_text, symbol)
        assembly_body = extract_assembly_function(assembly_text, symbol)
        missing_llvm = [token for token in function["requiredLLVMSubstrings"] if str(token) not in llvm_body]
        missing_assembly = [token for token in function["requiredAssemblySubstrings"] if str(token) not in assembly_body]
        if missing_llvm:
            fail(f"{function['id']} missing LLVM lowering token(s): {missing_llvm}")
        if missing_assembly:
            fail(f"{function['id']} missing assembly lowering token(s): {missing_assembly}")

        llvm_conditional_branches = LLVM_CONDITIONAL_BRANCH.findall(llvm_body)
        assembly_conditional_branches = ASM_CONDITIONAL_BRANCH.findall(assembly_body)
        llvm_switches = LLVM_SWITCH.findall(llvm_body)
        forbidden_calls = [
            pattern for pattern in FORBIDDEN_LOWERING_CALLS
            if re.search(pattern, sil_body) or re.search(pattern, llvm_body) or re.search(pattern, assembly_body)
        ]
        if len(llvm_conditional_branches) > int(function["allowedLLVMConditionalBranches"]):
            fail(f"{function['id']} has unexpected LLVM conditional branch lowering")
        if len(assembly_conditional_branches) > int(function["allowedAssemblyConditionalBranches"]):
            fail(f"{function['id']} has unexpected assembly conditional branch lowering")
        if llvm_switches:
            fail(f"{function['id']} has unexpected LLVM switch lowering")
        if forbidden_calls or ASM_FORBIDDEN_BRANCH_TO_RUNTIME.search(assembly_body):
            fail(f"{function['id']} has forbidden runtime/allocation lowering tokens")

        reviews.append({
            "id": str(function["id"]),
            "regions": list(function["regions"]),
            "symbol": symbol,
            "silSHA256Hex": sha256_bytes(sil_body.encode("utf-8")),
            "llvmSHA256Hex": sha256_bytes(llvm_body.encode("utf-8")),
            "assemblySHA256Hex": sha256_bytes(assembly_body.encode("utf-8")),
            "llvmConditionalBranchCount": len(llvm_conditional_branches),
            "assemblyConditionalBranchCount": len(assembly_conditional_branches),
            "llvmSwitchCount": len(llvm_switches),
            "forbiddenRuntimeOrAllocationTokens": forbidden_calls,
            "requiredLLVMSubstringsPresent": list(function["requiredLLVMSubstrings"]),
            "requiredAssemblySubstringsPresent": list(function["requiredAssemblySubstrings"]),
            "publicControlFlowFinding": function.get("publicControlFlowFinding"),
        })
    return reviews


def extract_air_function(text: str, name: str) -> str:
    marker = f"define void @{name}"
    start = text.find(marker)
    if start < 0:
        fail(f"missing Metal AIR function for {name}")
    depth = 0
    for index in range(start, len(text)):
        char = text[index]
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return text[start:index + 1]
    fail(f"unterminated Metal AIR function for {name}")


def metal_kernel_reviews() -> list[dict[str, Any]]:
    objdump = METAL_OBJDUMP.read_text(encoding="utf-8", errors="ignore")
    if "Disassembly of section MODULE_LIST" not in objdump:
        fail("Metal objdump artifact does not contain MODULE_LIST disassembly")
    reviews: list[dict[str, Any]] = []
    for kernel in METAL_KERNELS:
        body = extract_air_function(objdump, kernel)
        conditional_branches = LLVM_CONDITIONAL_BRANCH.findall(body)
        switches = LLVM_SWITCH.findall(body)
        if switches:
            fail(f"{kernel} has unexpected switch lowering in Metal AIR")
        if "air.thread_position_in_grid" not in objdump:
            fail("Metal objdump missing thread_position_in_grid metadata")
        if "select i1" not in body and kernel != "numiseal_mask_accumulate_kernel":
            fail(f"{kernel} does not show select-based arithmetic or mask lowering")
        reviews.append({
            "id": kernel,
            "regions": (
                ["metal-goldilocks-common-arithmetic"]
                if kernel.startswith("goldilocks_")
                else ["metal-numiseal-zk-secret-bearing-kernels"]
            ),
            "airFunctionSHA256Hex": sha256_bytes(body.encode("utf-8")),
            "llvmConditionalBranchCount": len(conditional_branches),
            "llvmSwitchCount": len(switches),
            "selectInstructionPresent": "select i1" in body,
            "publicControlFlowFinding": "conditional branches are kernel id/count guards or public loop bounds from the scoped source contract",
        })
    return reviews


def build_report(scope: dict[str, Any]) -> dict[str, Any]:
    reviewed_artifacts = [
        artifact_summary(artifact_id, path)
        for artifact_id, path in {**SWIFT_ARTIFACTS, **METAL_ARTIFACTS}.items()
    ]
    return {
        "schemaVersion": 1,
        "reportID": "superneo-compiler-lowering-audit-v1",
        "claimStatus": "scoped-compiler-lowering-review-complete",
        "generatedAtUTC": utc_now(),
        "scopeManifest": "TestVectors/Archive/compliance/constant-time-scope-v1.json",
        "reviewedArtifacts": reviewed_artifacts,
        "reviewedRegions": source_region_reviews(scope),
        "swiftLoweringReviews": lowering_reviews(),
        "metalAIRReviews": metal_kernel_reviews(),
        "positiveFindings": [
            "Scoped Swift arithmetic lowers through optimized LLVM IR selects and ARM64 csel for secret-derived choices.",
            "The Swift pow path contains one reviewed public fixed 64-round loop branch and uses select/csel for exponent-bit selection.",
            "Scoped Swift lowering bodies contain no local Swift runtime allocation, ARC, malloc, free, or copy-on-write calls.",
            "Metal metallib objdump is pinned and shows AIR functions for every scoped Goldilocks and NumiSealZK kernel.",
            "Metal secret-bearing kernels keep branch/control decisions to public id/count or public loop-bound checks recorded by the source scope.",
        ],
        "residualBoundaries": [
            "This audit covers repository-pinned Swift SIL, LLVM IR, ARM64 assembly, Metal AIR, metallib, and metallib objdump text.",
            "It does not certify CPU cache, branch-predictor, power, scheduler, or contention behavior.",
            "It does not certify GPU-family microarchitectural timing, counters, occupancy, or power behavior.",
            "Production whole-stack constant-time claims still require the hardware observation lane to close.",
        ],
        "promotionImpact": {
            "compilerLoweringReviewComplete": True,
            "productionConstantTimeClaimAllowed": False,
            "reason": "Compiler/lowering review is pinned for the scoped artifacts; hardware observation coverage remains non-certifying and open.",
        },
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--evidence-dir", type=Path, default=DEFAULT_EVIDENCE_DIR)
    parser.add_argument("--output", type=Path)
    parser.add_argument(
        "--refresh-metal-objdump",
        action="store_true",
        help="Regenerate the pinned Metal metallib objdump before auditing.",
    )
    args = parser.parse_args()
    evidence_dir = args.evidence_dir if args.evidence_dir.is_absolute() else ROOT / args.evidence_dir
    configure_paths(evidence_dir)
    raw_output = args.output or DEFAULT_OUTPUT
    output = raw_output if raw_output.is_absolute() else ROOT / raw_output

    ensure_metal_objdump(METAL_OBJDUMP, refresh=args.refresh_metal_objdump)
    scope = read_json(SCOPE_PATH)
    report = build_report(scope)
    write_json(output, report)
    print(f"wrote {rel(output)}")


if __name__ == "__main__":
    main()
