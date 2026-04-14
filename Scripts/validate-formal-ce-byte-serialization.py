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
        description="Validate the Lean/Swift CE opening proof byte grammar conformance surface."
    )
    parser.add_argument("--root", default=str(ROOT), help="repository root")
    args = parser.parse_args()

    root = Path(args.root).resolve()
    lean_top = read(root / "Formal" / "SuperNeoFormal.lean")
    lean_ce = read(root / "Formal" / "SuperNeoFormal" / "CEByteSerialization.lean")
    swift_protocols = read(root / "SuperNeo-NuMetal" / "Protocols" / "SuperNeoProtocols.swift")
    swift_serialization = read(root / "SuperNeo-NuMetal" / "SuperNeoSerialization.swift")
    swift_tests = read(root / "SuperNeo-NuMetalTests" / "SuperNeoNuMetalTests.swift")
    swift_vector_tool = read(root / "Tools" / "FormalVectorCLI" / "main.swift")
    lean_vector_tool = read(root / "Scripts" / "emit-formal-ce-vectors.lean")
    vector_comparator = read(root / "Scripts" / "compare-formal-ce-vectors.py")
    vector_comparator_tests = read(root / "Scripts" / "test-formal-ce-vector-bridge.py")
    production_gate = read(root / "Scripts" / "production-gate.sh")

    require_contains(
        lean_top,
        "import SuperNeoFormal.CEByteSerialization",
        "top-level Lean CE byte serialization import",
    )

    for kind, name in [
        ("def", "ceOpeningProofRoundCount"),
        ("theorem", "ceOpeningProofRoundCount_eq"),
        ("def", "natCount64Encode"),
        ("def", "natCount64DecodeEq?"),
        ("theorem", "natCount64DecodeEq?_encode"),
        ("def", "parseFixed?"),
        ("theorem", "parseFixed?_encode_append"),
        ("def", "parseVector?"),
        ("theorem", "parseVector?_encode_append"),
        ("inductive", "CEOpeningResponseTagWire"),
        ("def", "ceOpeningResponseTagEncode"),
        ("def", "ceOpeningResponseTagDecode?"),
        ("theorem", "ceOpeningResponseTagDecode?_encode"),
        ("def", "ceOpeningResponseTagChallenge"),
        ("theorem", "ceOpeningResponseTagChallenge_cases"),
        ("theorem", "ceOpeningResponseTagChallenge_mem_domain"),
        ("abbrev", "CESwiftIntWire"),
        ("def", "ceSwiftIntWireDecode?"),
        ("theorem", "ceSwiftIntWireDecode?_encode"),
        ("theorem", "ceSwiftIntWireDecode?_uint64Encode_of_ge_intMax"),
        ("structure", "CEOpeningProofCommitmentsWire"),
        ("def", "ceOpeningProofCommitmentsWireEncode"),
        ("theorem", "ceOpeningProofCommitmentsWireEncode_length"),
        ("def", "ceOpeningProofCommitmentsWireDecode?"),
        ("theorem", "ceOpeningProofCommitmentsWireDecode?_encode"),
        ("structure", "CEOpeningLinearResponseWire"),
        ("def", "ceOpeningLinearResponseWireEncode"),
        ("theorem", "ceOpeningLinearResponseWireDecode?_encode"),
        ("structure", "CEOpeningNormResponseWire"),
        ("def", "ceOpeningNormResponseWireEncode"),
        ("theorem", "ceOpeningNormResponseWireDecode?_encode"),
        ("inductive", "CEOpeningProofResponseWire"),
        ("def", "ceOpeningProofResponseWireEncode"),
        ("def", "ceOpeningProofResponseWireDecode?"),
        ("theorem", "ceOpeningProofResponseWireDecode?_encode"),
        ("structure", "CEOpeningProofRoundWire"),
        ("def", "ceOpeningProofRoundWireEncode"),
        ("def", "ceOpeningProofRoundWireDecode?"),
        ("theorem", "ceOpeningProofRoundWireDecode?_encode"),
        ("structure", "CEOpeningProofWire"),
        ("def", "ceOpeningProofWireEncode"),
        ("def", "ceOpeningProofWireDecode?"),
        ("theorem", "ceOpeningProofWireDecode?_encode"),
    ]:
        require_lean_declaration(lean_ce, kind, name)

    require_regex(
        lean_ce,
        r"def\s+ceOpeningProofRoundCount\s*:\s*Nat\s*:=\s*219",
        "Lean CE proof round count must be 219",
    )
    require_regex(
        lean_ce,
        r"def\s+ceOpeningResponseTagEncode\s*:\s*CEOpeningResponseTagWire\s*→\s*Byte\s*"
        r"\| \.mask\s*=>\s*byteOfNat\s+0.*"
        r"\| \.maskedWitness\s*=>\s*byteOfNat\s+1.*"
        r"\| \.permutedWitness\s*=>\s*byteOfNat\s+2",
        "Lean CE response tag encoder must map mask/masked/permuted to 0/1/2",
    )
    require_regex(
        lean_ce,
        r"ceOpeningResponseTagChallenge\s+\.mask\s*=\s*CEOpeningVerifierChallenge\.mask.*"
        r"ceOpeningResponseTagChallenge\s+\.maskedWitness\s*=\s*"
        r"CEOpeningVerifierChallenge\.maskedWitness.*"
        r"ceOpeningResponseTagChallenge\s+\.permutedWitness\s*=\s*"
        r"CEOpeningVerifierChallenge\.permutedWitness",
        "Lean CE response tags must map onto terminal CE challenge branches",
    )
    require_regex(
        lean_ce,
        r"def\s+ceSwiftIntWireDecode\?.*if\s+hValue\s*:\s*value\.val\s*<\s*2\s*\^\s*63\s+then\s*"
        r"some\s*⟨value\.val,\s*hValue⟩\s*else\s*none",
        "Lean CE Swift Int parser must reject UInt64 values above Int.max",
    )
    require_regex(
        lean_ce,
        r"def\s+ceOpeningProofCommitmentsWireEncode.*"
        r"digest256Encode\s+commitments\.maskLinearDigest\s*\+\+\s*"
        r"digest256Encode\s+commitments\.permutedMaskDigest\s*\+\+\s*"
        r"digest256Encode\s+commitments\.permutedMaskedWitnessDigest",
        "Lean CE commitment encoder must serialize the three digests in Swift order",
    )
    require_regex(
        lean_ce,
        r"\(ceOpeningProofCommitmentsWireEncode\s+commitments\)\.length\s*=\s*96",
        "Lean CE commitment wire length must be three SHA-256 digests",
    )
    require_regex(
        lean_ce,
        r"def\s+ceOpeningProofWireEncode.*"
        r"natCount64Encode\s+ceOpeningProofRoundCount\s+\(by native_decide\)\s*\+\+\s*"
        r"finVectorEncode\s*\n\s*\(ceOpeningProofRoundWireEncode",
        "Lean CE proof encoder must prefix the exact 219-round count before rounds",
    )

    require_regex(
        swift_protocols,
        r"public\s+static\s+let\s+roundCount\s*=\s*219",
        "Swift CEOpeningProof roundCount must be 219",
    )
    require_regex(
        swift_serialization,
        r"case\s+\.mask\(let\s+openings\):\s*return\s+encodeCEOpeningResponse\(tag:\s*0,\s*openings:\s*openings\).*"
        r"case\s+\.maskedWitness\(let\s+openings\):\s*return\s+encodeCEOpeningResponse\(tag:\s*1,\s*openings:\s*openings\).*"
        r"case\s+\.permutedWitness\(let\s+openings\):\s*return\s+encodeCEOpeningResponse\(tag:\s*2,\s*openings:\s*openings\)",
        "Swift CE response encoder must map mask/masked/permuted to 0/1/2",
    )
    require_regex(
        swift_serialization,
        r"private\s+func\s+encodeCEOpeningResponse<T:\s*SuperNeoByteEncodable>\(tag:\s*UInt8,\s*openings:\s*\[T\]\)\s*->\s*\[UInt8\]\s*\{\s*"
        r"var\s+bytes\s*=\s*encodeUInt8\(tag\)\s*"
        r"bytes\.append\(contentsOf:\s*encodeCount\(openings\.count\)\).*"
        r"for\s+opening\s+in\s+openings\s*\{\s*bytes\.append\(contentsOf:\s*opening\.superNeoBytes\)",
        "Swift CE response encoder must be tag, count, payload vector",
    )
    require_regex(
        swift_serialization,
        r"fileprivate\s+mutating\s+func\s+readCEOpeningProof\(parameters:\s*SuperNeoParameters\)\s+throws\s+->\s+CEOpeningProof\s*\{\s*"
        r"let\s+roundCount\s*=\s*try\s+readCount\(.*maximum:\s*CEOpeningProof\.roundCount.*"
        r"guard\s+roundCount\s*==\s*CEOpeningProof\.roundCount",
        "Swift CE proof parser must enforce exact CEOpeningProof.roundCount",
    )
    require_regex(
        swift_serialization,
        r"private\s+mutating\s+func\s+readCEOpeningProofRound\(parameters:\s*SuperNeoParameters\)\s+throws\s+->\s+CEOpeningProofRound\s*\{\s*"
        r"let\s+commitmentCount\s*=\s*try\s+readCount\(.*"
        r"guard\s+commitmentCount\s*>\s*0.*"
        r"maskLinearDigest:\s*try\s+Digest256\(readData\(count:\s*Digest256\.byteCount\)\).*"
        r"permutedMaskDigest:\s*try\s+Digest256\(readData\(count:\s*Digest256\.byteCount\)\).*"
        r"permutedMaskedWitnessDigest:\s*try\s+Digest256\(readData\(count:\s*Digest256\.byteCount\)\).*"
        r"readCEOpeningProofResponse\(expectedCount:\s*commitmentCount\)",
        "Swift CE round parser must read positive digest triples and pass expected response count",
    )
    require_regex(
        swift_serialization,
        r"private\s+mutating\s+func\s+readCEOpeningProofResponse\(expectedCount:\s*Int\)\s+throws\s+->\s+CEOpeningProofResponse\s*\{\s*"
        r"let\s+tag\s*=\s*try\s+readUInt8\(\).*"
        r"guard\s+count\s*==\s*expectedCount.*"
        r"case\s+0:\s*return\s+\.mask.*"
        r"case\s+1:\s*return\s+\.maskedWitness.*"
        r"case\s+2:\s*return\s+\.permutedWitness.*"
        r"default:\s*throw\s+SuperNeoError\.invalidEncoding\(\"unsupported CE opening response challenge\"\)",
        "Swift CE response parser must enforce count equality and 0/1/2 tag mapping",
    )

    require_contains(
        swift_tests,
        "func testCEOpeningProofSerializationCoversAllResponseTagsAndParserFailures() throws",
        "Swift CE byte grammar fixture test",
    )
    for fragment, description in [
        ("XCTAssertEqual(bytes[responseTagOffset(round: 0)], 0)", "mask tag byte fixture"),
        ("XCTAssertEqual(bytes[responseTagOffset(round: 1)], 1)", "masked-witness tag byte fixture"),
        ("XCTAssertEqual(bytes[responseTagOffset(round: 2)], 2)", "permuted-witness tag byte fixture"),
        (".invalidEncoding(\"wrong CE opening proof round count\")", "wrong round count rejection"),
        (".invalidEncoding(\"unsupported CE opening response challenge\")", "invalid tag rejection"),
        (".invalidEncoding(\"CE opening response count mismatch\")", "response count mismatch rejection"),
        (".invalidEncoding(\"trailing proof bytes\")", "trailing byte rejection"),
    ]:
        require_contains(swift_tests, fragment, description)

    for fragment, description in [
        ("superneo-formal-vectors ext2|ce", "Swift vector tool usage must include CE mode"),
        ("CEOpeningProof(bytes: bytes)", "Swift CE vector tool decode path"),
        ("CEOpeningProof.roundCount", "Swift CE vector tool exact round-count fixture"),
        ("CEOpeningProofResponse.mask", "Swift CE vector tool mask branch fixture"),
        ("CEOpeningProofResponse.maskedWitness", "Swift CE vector tool masked-witness branch fixture"),
        ("CEOpeningProofResponse.permutedWitness", "Swift CE vector tool permuted-witness branch fixture"),
        ("ce_proof_decode_invalid_tag", "Swift CE vector tool invalid-tag fixture"),
        ("ce_proof_decode_wrong_response_count", "Swift CE vector tool response-count fixture"),
    ]:
        require_contains(swift_vector_tool, fragment, description)

    for fragment, description in [
        ("import SuperNeoFormal.CEByteSerialization", "Lean CE vector tool grammar import"),
        ("ceOpeningProofResponseWireEncode hCount2 hVector2 maskResponse", "Lean CE vector tool mask branch fixture"),
        ("ceOpeningProofResponseWireEncode hCount2 hVector2 maskedWitnessResponse", "Lean CE vector tool masked-witness branch fixture"),
        ("ceOpeningProofResponseWireEncode hCount2 hVector2 permutedWitnessResponse", "Lean CE vector tool permuted-witness branch fixture"),
        ("ceOpeningProofWireEncode hCount2 hVector2 fixtureProof", "Lean CE vector tool full proof fixture"),
        ("ceOpeningProofWireDecode? hOpeningPositive2 hCount2 hVector2", "Lean CE vector tool decode fixture"),
        ("ce_proof_decode_wrong_response_count", "Lean CE vector tool response-count fixture"),
    ]:
        require_contains(lean_vector_tool, fragment, description)

    for fragment, description in [
        ('"swift", "run"', "CE vector comparator must execute Swift emitter"),
        ("superneo-formal-vectors", "CE vector comparator must call formal vector executable"),
        ("emit-formal-ce-vectors.lean", "CE vector comparator must call Lean vector script"),
        ("Swift/Lean CE vector mismatch", "CE vector comparator must fail on value drift"),
    ]:
        require_contains(vector_comparator, fragment, description)

    require_contains(
        vector_comparator_tests,
        "formal CE vector bridge validation regression tests passed",
        "CE vector comparator regression harness",
    )
    require_contains(
        production_gate,
        "Scripts/compare-formal-ce-vectors.py",
        "Production gate must run the Swift/Lean CE vector comparison",
    )
    require_contains(
        production_gate,
        "Scripts/test-formal-ce-vector-bridge.py",
        "Production gate must run the CE vector comparison regression harness",
    )

    print(f"validated CE opening byte serialization conformance under {root}")


if __name__ == "__main__":
    main()
