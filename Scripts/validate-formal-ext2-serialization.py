#!/usr/bin/env python3
import argparse
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def fail(message: str) -> None:
    print(f"error: {message}", file=sys.stderr)
    raise SystemExit(1)


def read(path: Path) -> str:
    if not path.exists():
        fail(f"missing required file {path}")
    return path.read_text(encoding="utf-8")


def require_contains(text: str, needle: str, description: str) -> None:
    if needle not in text:
        fail(f"{description} missing expected source fragment: {needle!r}")


def require_regex(text: str, pattern: str, description: str) -> None:
    if not re.search(pattern, text, re.MULTILINE | re.DOTALL):
        fail(f"{description} did not match expected source shape")


def require_lean_declaration(text: str, kind: str, name: str) -> None:
    pattern = rf"^\s*{kind}\s+{re.escape(name)}(?![A-Za-z0-9_'?])"
    require_regex(text, pattern, f"Lean declaration {name}")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Validate the Lean/Swift GoldilocksExt2 serialization conformance surface."
    )
    parser.add_argument("--root", default=str(ROOT), help="repository root")
    args = parser.parse_args()

    root = Path(args.root).resolve()
    top_level_formal = read(root / "Formal" / "SuperNeoFormal.lean")
    lean_serialization = read(root / "Formal" / "SuperNeoFormal" / "Serialization.lean")
    lean_ext2_callers = read(root / "Formal" / "SuperNeoFormal" / "Ext2CallerSerialization.lean")
    swift_field = read(root / "SuperNeo-NuMetal" / "Fields" / "GoldilocksField.swift")
    swift_ring = read(root / "SuperNeo-NuMetal" / "Rings" / "CyclotomicRing54.swift")
    swift_serialization = read(root / "SuperNeo-NuMetal" / "SuperNeoSerialization.swift")
    swift_ccs = read(root / "SuperNeo-NuMetal" / "CCS" / "CCS.swift")
    swift_tests = read(root / "SuperNeo-NuMetalTests" / "SuperNeoNuMetalTests.swift")

    require_contains(
        top_level_formal,
        "import SuperNeoFormal.Ext2CallerSerialization",
        "Top-level Lean target must import Ext2 caller serialization surface",
    )

    for kind, name in [
        ("def", "goldilocksWireDecode?"),
        ("theorem", "goldilocksWireDecode?_encode"),
        ("theorem", "goldilocksWireDecode?_none_of_length_ne"),
        ("theorem", "goldilocksWireDecode?_uint64Encode_of_ge_modulus"),
        ("def", "goldilocksElementDecode?"),
        ("theorem", "goldilocksElementDecode?_encode"),
        ("theorem", "goldilocksElementDecode?_none_of_length_ne"),
        ("theorem", "goldilocksElementDecode?_length_of_some"),
        ("def", "goldilocksExt2WireDecode?"),
        ("theorem", "goldilocksExt2WireDecode?_encode"),
        ("theorem", "goldilocksExt2WireDecode?_none_of_length_ne"),
        ("theorem", "goldilocksExt2WireDecode?_length_of_some"),
        ("def", "goldilocksExt2ElementDecode?"),
        ("theorem", "goldilocksExt2ElementDecode?_encode"),
        ("theorem", "goldilocksExt2ElementDecode?_none_of_length_ne"),
        ("theorem", "goldilocksExt2ElementDecode?_length_of_some"),
        ("def", "finVectorDecode?"),
        ("theorem", "finVectorDecode?_encode"),
        ("theorem", "finVectorDecode?_none_of_length_ne"),
        ("theorem", "finVectorDecode?_length_of_some"),
        ("abbrev", "Phi81Ext2Coefficients"),
        ("def", "phi81Ext2CoefficientsWireEncode"),
        ("theorem", "phi81Ext2CoefficientsWireEncode_length"),
        ("theorem", "phi81Ext2CoefficientsWireEncode_injective"),
        ("def", "phi81Ext2CoefficientsWireDecode?"),
        ("theorem", "phi81Ext2CoefficientsWireDecode?_encode"),
        ("theorem", "phi81Ext2CoefficientsWireDecode?_none_of_length_ne"),
        ("theorem", "phi81Ext2CoefficientsWireDecode?_length_of_some"),
    ]:
        require_lean_declaration(lean_serialization, kind, name)

    require_regex(
        lean_serialization,
        r"def\s+goldilocksExt2WireEncode\s*\([^)]*\)\s*:\s*List\s+Byte\s*:=\s*"
        r"goldilocksElementEncode\s+value\.1\s*\+\+\s*goldilocksElementEncode\s+value\.2",
        "Lean GoldilocksExt2 wire encoder must be c0 then c1",
    )
    require_regex(
        lean_serialization,
        r"def\s+goldilocksExt2WireDecode\?\s*\([^)]*\)\s*:\s*Option\s+GoldilocksExt2Wire\s*:=\s*"
        r"if\s+bytes\.length\s*=\s*16\s+then.*goldilocksElementDecode\?\s*\(bytes\.take\s+8\).*"
        r"goldilocksElementDecode\?\s*\(bytes\.drop\s+8\).*some\s+c0,\s*some\s+c1\s*=>\s*some\s*\(c0,\s*c1\)",
        "Lean GoldilocksExt2 wire decoder must split exact 16 bytes as c0 then c1",
    )
    require_regex(
        lean_serialization,
        r"def\s+goldilocksWireDecode\?.*if\s+hValue\s*:\s*value\.val\s*<\s*goldilocksModulus\s+then\s*"
        r"some\s*⟨value\.val,\s*hValue⟩\s*else\s*none",
        "Lean Goldilocks decoder must reject non-canonical UInt64 values",
    )
    require_regex(
        lean_serialization,
        r"def\s+phi81Ext2CoefficientsWireEncode\s*\([^)]*\)\s*:\s*List\s+Byte\s*:=\s*"
        r"finVectorEncode\s+goldilocksExt2ElementEncode\s+coefficients",
        "Lean Phi81 Ext2 coefficient encoder must use fixed Ext2 element chunks",
    )
    require_regex(
        lean_serialization,
        r"\(phi81Ext2CoefficientsWireEncode\s+coefficients\)\.length\s*=\s*phi81Degree\s*\*\s*16",
        "Lean Phi81 Ext2 coefficient encoder must have degree * 16 byte length",
    )
    require_regex(
        lean_serialization,
        r"def\s+phi81Ext2CoefficientsWireDecode\?\s*\([^)]*\)\s*:\s*Option\s+Phi81Ext2Coefficients\s*:=\s*"
        r"finVectorDecode\?\s+goldilocksExt2ElementDecode\?\s+16\s+\(n\s*:=\s*phi81Degree\)\s+bytes",
        "Lean Phi81 Ext2 coefficient decoder must use fixed 16-byte Ext2 chunks",
    )

    for kind, name in [
        ("def", "opaqueBytesDecode?"),
        ("theorem", "opaqueBytesDecode?_encode"),
        ("theorem", "parseOpaqueBytes?_encode_append"),
        ("def", "parseList?"),
        ("theorem", "parseList?_encode_append"),
        ("theorem", "parseList?_encode_append_of_mem"),
        ("def", "countedListEncode"),
        ("def", "countedFixedListParse?"),
        ("theorem", "countedFixedListParse?_encode_append"),
        ("def", "countedDynamicListParse?"),
        ("theorem", "countedDynamicListParse?_encode_append"),
        ("structure", "SwiftGoldilocksExt2VectorWire"),
        ("def", "swiftGoldilocksExt2VectorWireEncode"),
        ("def", "swiftGoldilocksExt2VectorWireParse?"),
        ("theorem", "swiftGoldilocksExt2VectorWireParse?_encode_append"),
        ("structure", "SwiftCyclotomicExt2Ring54VectorWire"),
        ("def", "swiftCyclotomicExt2Ring54WireEncode"),
        ("def", "swiftCyclotomicExt2Ring54WireDecode?"),
        ("theorem", "swiftCyclotomicExt2Ring54WireDecode?_encode"),
        ("def", "swiftCyclotomicExt2Ring54VectorWireEncode"),
        ("def", "swiftCyclotomicExt2Ring54VectorWireParse?"),
        ("theorem", "swiftCyclotomicExt2Ring54VectorWireParse?_encode_append"),
        ("structure", "SwiftSumcheckRoundExt2Wire"),
        ("def", "swiftSumcheckRoundExt2WireEncode"),
        ("def", "swiftSumcheckRoundExt2WireParse?"),
        ("theorem", "swiftSumcheckRoundExt2WireParse?_encode_append"),
        ("structure", "SwiftSumcheckProofExt2Wire"),
        ("def", "swiftSumcheckProofExt2WireEncode"),
        ("def", "swiftSumcheckProofExt2WireParse?"),
        ("structure", "SwiftExt2PointEvaluationSurfaceWire"),
        ("def", "swiftExt2PointEvaluationSurfaceWireEncode"),
        ("def", "swiftExt2PointEvaluationSurfaceWireParse?"),
        ("abbrev", "SwiftCCSEvaluationClaimExt2SurfaceWire"),
        ("def", "swiftCCSEvaluationClaimExt2SurfaceWireEncode"),
        ("def", "swiftCCSEvaluationClaimExt2SurfaceWireParse?"),
        ("abbrev", "SwiftCEInstanceExt2SurfaceWire"),
        ("def", "swiftCEInstanceExt2SurfaceWireEncode"),
        ("def", "swiftCEInstanceExt2SurfaceWireParse?"),
    ]:
        require_lean_declaration(lean_ext2_callers, kind, name)

    require_regex(
        lean_ext2_callers,
        r"def\s+swiftGoldilocksExt2VectorWireParse\?.*"
        r"countedFixedListParse\?\s+goldilocksExt2ElementDecode\?\s+16\s+bytes",
        "Lean Swift Ext2 vector parser must use counted 16-byte Ext2 chunks",
    )
    require_regex(
        lean_ext2_callers,
        r"def\s+swiftCyclotomicExt2Ring54VectorWireParse\?.*"
        r"countedFixedListParse\?.*swiftCyclotomicExt2Ring54WireDecode\?.*\(phi81Degree\s*\*\s*16\)",
        "Lean Swift Ext2 ring-vector parser must use counted Phi81 Ext2 ring chunks",
    )
    require_regex(
        lean_ext2_callers,
        r"def\s+swiftSumcheckProofExt2WireEncode.*"
        r"goldilocksExt2ElementEncode\s+proof\.claimedSum.*"
        r"countedListEncode\s+swiftSumcheckRoundExt2WireEncode\s+proof\.roundCount\s+proof\.rounds.*"
        r"countedListEncode\s+goldilocksExt2ElementEncode\s+proof\.finalPointCount\s+proof\.finalPoint.*"
        r"goldilocksExt2ElementEncode\s+proof\.finalValue",
        "Lean Swift sum-check Ext2 caller grammar must cover claimed sum, rounds, final point, and final value",
    )
    require_regex(
        lean_ext2_callers,
        r"def\s+swiftExt2PointEvaluationSurfaceWireEncode.*"
        r"surface\.prefixBytes.*"
        r"countedListEncode\s+goldilocksExt2ElementEncode\s+surface\.pointCount\s+surface\.point.*"
        r"countedListEncode\s+swiftCyclotomicExt2Ring54WireEncode\s+surface\.evaluationCount\s+surface\.evaluations",
        "Lean Swift point/evaluation caller grammar must cover Ext2 points and Ext2 ring evaluations after an opaque prefix",
    )

    require_regex(
        swift_field,
        r"public\s+var\s+littleEndianBytes\s*:\s*\[UInt8\]\s*\{\s*"
        r"c0\.littleEndianBytes\s*\+\s*c1\.littleEndianBytes\s*\}",
        "Swift GoldilocksExt2 encoder must be c0 then c1",
    )
    require_regex(
        swift_field,
        r"public\s+init\s*\(littleEndianBytes\s+bytes:\s*ArraySlice<UInt8>\)\s+throws\s*\{\s*"
        r"guard\s+bytes\.count\s*==\s*16\b.*"
        r"self\.c0\s*=\s*try\s+GoldilocksField\s*\(littleEndianBytes:\s*bytes\.prefix\(8\)\).*"
        r"self\.c1\s*=\s*try\s+GoldilocksField\s*\(littleEndianBytes:\s*bytes\.suffix\(8\)\)",
        "Swift GoldilocksExt2 decoder must parse c0 from prefix(8) and c1 from suffix(8)",
    )
    require_regex(
        swift_field,
        r"public\s+init\s*\(littleEndianBytes\s+bytes:\s*ArraySlice<UInt8>\)\s+throws\s*\{\s*"
        r"guard\s+bytes\.count\s*==\s*8\b.*guard\s+value\s*<\s*Self\.modulus",
        "Swift Goldilocks decoder must require 8 canonical bytes",
    )

    require_regex(
        swift_serialization,
        r"extension\s+GoldilocksExt2:\s+SuperNeoByteEncodable\s*\{\s*"
        r"public\s+var\s+superNeoBytes:\s*\[UInt8\]\s*\{\s*littleEndianBytes\s*\}",
        "Swift SuperNeoByteEncodable GoldilocksExt2 bridge",
    )
    require_regex(
        swift_serialization,
        r"fileprivate\s+mutating\s+func\s+readGoldilocksExt2\(\)\s+throws\s+->\s+GoldilocksExt2\s*\{\s*"
        r"try\s+GoldilocksExt2\s*\(littleEndianBytes:\s*readData\(count:\s*16\)\[\.\.\.\]\)",
        "Swift proof ByteReader must read exact 16-byte Ext2 chunks",
    )
    require_regex(
        swift_ccs,
        r"private\s+mutating\s+func\s+readGoldilocksExt2Public\(\)\s+throws\s+->\s+GoldilocksExt2\s*\{\s*"
        r"try\s+GoldilocksExt2\s*\(littleEndianBytes:\s*readData\(count:\s*16\)\[\.\.\.\]\)",
        "Swift public CCS reader must read exact 16-byte Ext2 chunks",
    )
    require_regex(
        swift_serialization,
        r"extension\s+CCSEvaluationClaim:\s+SuperNeoByteEncodable\s*\{.*"
        r"bytes\.append\(contentsOf:\s*encodeCount\(point\.count\)\).*"
        r"for\s+coordinate\s+in\s+point\s*\{\s*bytes\.append\(contentsOf:\s*coordinate\.superNeoBytes\).*"
        r"bytes\.append\(contentsOf:\s*encodeCount\(evaluations\.count\)\).*"
        r"for\s+evaluation\s+in\s+evaluations\s*\{\s*bytes\.append\(contentsOf:\s*evaluation\.superNeoBytes\)",
        "Swift CCSEvaluationClaim must encode Ext2 point coordinates before Ext2 matrix evaluations",
    )
    require_regex(
        swift_ccs,
        r"public\s+var\s+superNeoBytes:\s+\[UInt8\]\s*\{.*"
        r"\+\s*ccsEncodeCount\(evalPoint\.count\).*"
        r"\+\s*evalPoint\.flatMap\(\\\.superNeoBytes\).*"
        r"\+\s*ccsEncodeCount\(matrixEvals\.count\).*"
        r"\+\s*matrixEvals\.flatMap\(\\\.superNeoBytes\)",
        "Swift CEInstance must encode Ext2 eval point before Ext2 matrix evaluations",
    )
    require_regex(
        swift_ring,
        r"public\s+var\s+littleEndianBytes\s*:\s*\[UInt8\]\s*\{\s*"
        r"coefficients\.flatMap\(\\\.littleEndianBytes\)\s*\}.*"
        r"guard\s+bytes\.count\s*==\s*Self\.degree\s*\*\s*16.*"
        r"stride\(from:\s*0,\s*to:\s*bytes\.count,\s*by:\s*16\).*"
        r"GoldilocksExt2\s*\(littleEndianBytes:\s*bytes\[offset..<offset\s*\+\s*16\]\)",
        "Swift CyclotomicExt2Ring54 must encode/decode contiguous 16-byte Ext2 coefficients",
    )

    require_contains(
        swift_tests,
        "func testTier0GoldilocksExt2SerializationUsesCanonicalC0ThenC1Order() throws",
        "Swift Ext2 conformance test",
    )
    for fragment, description in [
        ("let c0Raw: UInt64 = 0x0102_0304_0506_0708", "independent c0 fixture"),
        ("let c1Raw: UInt64 = 0x1110_0F0E_0D0C_0B0A", "independent c1 fixture"),
        ("let expected = leBytes(c0Raw) + leBytes(c1Raw)", "fixture c0 then c1 order"),
        ("let swapped = leBytes(c1Raw) + leBytes(c0Raw)", "fixture swapped-order guard"),
        ("nonCanonicalC0.replaceSubrange(0..<8, with: modulusBytes)", "non-canonical c0 guard"),
        ("nonCanonicalC1.replaceSubrange(8..<16, with: modulusBytes)", "non-canonical c1 guard"),
        ("try CyclotomicExt2Ring54(littleEndianBytes: ring.littleEndianBytes)", "Ext2 ring caller round trip"),
        ("XCTAssertEqual(Array(sumcheck.superNeoBytes.dropFirst(32).prefix(16)), swapped)", "sum-check coefficient caller order"),
        ("XCTAssertEqual(Array(sumcheck.superNeoBytes.dropFirst(88).prefix(16)), swapped)", "sum-check final value caller order"),
        ("let claimPointCountOffset = commitment.superNeoBytes.count", "CCS evaluation-claim Ext2 point offset fixture"),
        ("let claimEvaluationCountOffset = claimPointCountOffset + encodedCountByteWidth + 16", "CCS evaluation-claim Ext2 evaluation offset fixture"),
        ("let cePointCountOffset = commitment.superNeoBytes.count", "CE instance Ext2 point offset fixture"),
        ("let ceMatrixEvalCountOffset = cePointCountOffset + encodedCountByteWidth + 16", "CE instance Ext2 matrix-evaluation offset fixture"),
        ("XCTAssertEqual(try CEInstance(bytes: ceInstance.superNeoBytes), ceInstance)", "CE instance byte parser round trip fixture"),
    ]:
        require_contains(swift_tests, fragment, description)

    print(f"validated GoldilocksExt2 serialization conformance under {root}")


if __name__ == "__main__":
    main()
