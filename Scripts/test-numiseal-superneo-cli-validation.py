#!/usr/bin/env python3
import argparse
import base64
import json
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any, Callable, Dict, List


ROOT = Path(__file__).resolve().parents[1]
VECTOR = ROOT / "TestVectors" / "numiseal-terminal-single-aggregate-v1.json"
ZERO_DIGEST = "0" * 64


def fail(message: str) -> None:
    print(f"error: {message}", file=sys.stderr)
    raise SystemExit(1)


def load_json(path: Path) -> Dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        value = json.load(handle)
    if not isinstance(value, dict):
        fail(f"{path} did not decode to a JSON object")
    return value


def write_json(path: Path, value: Dict[str, Any]) -> None:
    with path.open("w", encoding="utf-8") as handle:
        json.dump(value, handle, indent=2, sort_keys=True)
        handle.write("\n")


def run_expect_failure(command: List[str], expected: str) -> None:
    result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True)
    combined = result.stdout + result.stderr
    if result.returncode == 0:
        fail(f"expected command to fail but it succeeded: {' '.join(command)}")
    if expected not in combined:
        fail(
            f"expected failure output to contain {expected!r}\n"
            f"command: {' '.join(command)}\n"
            f"stdout:\n{result.stdout}\n"
            f"stderr:\n{result.stderr}"
        )


def strict_command(cli: Path, artifact: Dict[str, Any], path: Path) -> List[str]:
    return [
        str(cli),
        "verify",
        "--require-numiseal",
        "--key-seed",
        artifact["keySeedUTF8"],
        "--expected-verifier-key-digest",
        artifact["verifierKeyDigestHex"],
        "--expected-shape-digest",
        artifact["shapeDigestHex"],
        "--expected-statement-digest",
        artifact["statementDigestHex"],
        "--expected-transcript-domain-digest",
        artifact["transcriptDomainHex"],
        "--expected-public-statement-digest",
        artifact["publicStatementDigestHex"],
        "--expected-obligation-root",
        artifact["obligationRootHex"],
        "--expected-lane-summary-root",
        artifact["laneSummaryRootHex"],
        "--expected-aggregate-digests",
        ",".join(artifact["aggregateDigestsHex"]),
        "--expected-component-digest-root",
        artifact["componentDigestRootHex"],
        "--expected-proof-transcript-digest",
        artifact["proofTranscriptDigestHex"],
        "--expected-public-inputs",
        ",".join(str(value) for value in artifact["publicInputs"]),
        str(path),
    ]


def run_mutated_artifact(
    cli: Path,
    name: str,
    artifact: Dict[str, Any],
    mutate: Callable[[Dict[str, Any]], None],
    expected: str,
) -> None:
    mutated = dict(artifact)
    mutate(mutated)
    with tempfile.TemporaryDirectory(prefix=f"superneo-numiseal-{name}-") as tmp:
        path = Path(tmp) / VECTOR.name
        write_json(path, mutated)
        run_expect_failure([str(cli), "verify", "--require-numiseal", str(path)], expected)


def set_envelope_header_kind(artifact: Dict[str, Any], kind: int) -> None:
    envelope = bytearray(base64.b64decode(artifact["proofEnvelopeBase64"]))
    envelope[8] = kind
    artifact["proofEnvelopeBase64"] = base64.b64encode(envelope).decode("ascii")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Mutation-test production superneo NumiSeal verification fail-closed behavior."
    )
    parser.add_argument(
        "--cli",
        default=str(ROOT / ".build" / "release" / "superneo"),
        help="Path to the built superneo executable.",
    )
    args = parser.parse_args()
    cli = Path(args.cli)
    if not cli.exists():
        fail(f"superneo CLI does not exist: {cli}")

    artifact = load_json(VECTOR)

    run_expect_failure(
        [str(cli), "verify", str(VECTOR)],
        "NumiSeal terminal proof requires --require-numiseal",
    )
    run_expect_failure(
        [str(cli), "verify", "--require-terminal", str(VECTOR)],
        "legacy terminal proof required",
    )

    wrong_key = strict_command(cli, artifact, VECTOR)
    wrong_key[wrong_key.index("--key-seed") + 1] = "SuperNeoNumiSeal.vector.wrong.key.v1"
    run_expect_failure(wrong_key, "verifier key digest")

    wrong_transcript_pin = strict_command(cli, artifact, VECTOR)
    wrong_transcript_pin[wrong_transcript_pin.index("--expected-transcript-domain-digest") + 1] = ZERO_DIGEST
    run_expect_failure(wrong_transcript_pin, "expected transcript domain")

    wrong_public_statement_pin = strict_command(cli, artifact, VECTOR)
    wrong_public_statement_pin[wrong_public_statement_pin.index("--expected-public-statement-digest") + 1] = ZERO_DIGEST
    run_expect_failure(wrong_public_statement_pin, "expected public statement digest")

    wrong_obligation_pin = strict_command(cli, artifact, VECTOR)
    wrong_obligation_pin[wrong_obligation_pin.index("--expected-obligation-root") + 1] = ZERO_DIGEST
    run_expect_failure(wrong_obligation_pin, "expected obligation root")

    wrong_aggregate_pin = strict_command(cli, artifact, VECTOR)
    wrong_aggregate_pin[wrong_aggregate_pin.index("--expected-aggregate-digests") + 1] = ZERO_DIGEST
    run_expect_failure(wrong_aggregate_pin, "expected aggregate digests")

    wrong_component_pin = strict_command(cli, artifact, VECTOR)
    wrong_component_pin[wrong_component_pin.index("--expected-component-digest-root") + 1] = ZERO_DIGEST
    run_expect_failure(wrong_component_pin, "expected component digest root")

    wrong_transcript_digest_pin = strict_command(cli, artifact, VECTOR)
    wrong_transcript_digest_pin[wrong_transcript_digest_pin.index("--expected-proof-transcript-digest") + 1] = ZERO_DIGEST
    run_expect_failure(wrong_transcript_digest_pin, "expected proof transcript digest")

    wrong_public_input_pin = strict_command(cli, artifact, VECTOR)
    public_inputs = list(artifact["publicInputs"])
    public_inputs[0] = 1
    wrong_public_input_pin[wrong_public_input_pin.index("--expected-public-inputs") + 1] = ",".join(
        str(value) for value in public_inputs
    )
    run_expect_failure(wrong_public_input_pin, "expected public inputs")

    run_mutated_artifact(
        cli,
        "transcript-domain",
        artifact,
        lambda item: item.__setitem__("transcriptDomainHex", ZERO_DIGEST),
        "transcript domain",
    )
    run_mutated_artifact(
        cli,
        "public-statement",
        artifact,
        lambda item: item.__setitem__("publicStatementDigestHex", ZERO_DIGEST),
        "public statement",
    )
    run_mutated_artifact(
        cli,
        "obligation-root",
        artifact,
        lambda item: item.__setitem__("obligationRootHex", ZERO_DIGEST),
        "obligation root",
    )
    run_mutated_artifact(
        cli,
        "aggregate-digest",
        artifact,
        lambda item: item.__setitem__("aggregateDigestsHex", [ZERO_DIGEST]),
        "aggregate",
    )
    run_mutated_artifact(
        cli,
        "component-root",
        artifact,
        lambda item: item.__setitem__("componentDigestRootHex", ZERO_DIGEST),
        "component digest root",
    )
    run_mutated_artifact(
        cli,
        "proof-transcript",
        artifact,
        lambda item: item.__setitem__("proofTranscriptDigestHex", ZERO_DIGEST),
        "proof transcript",
    )
    run_mutated_artifact(
        cli,
        "public-input",
        artifact,
        lambda item: item.__setitem__("publicInputs", public_inputs),
        "sum-check oracle",
    )
    run_mutated_artifact(
        cli,
        "proof-kind",
        artifact,
        lambda item: item.__setitem__("proofKind", "terminal"),
        "unknown top-level fields",
    )
    run_mutated_artifact(
        cli,
        "header-kind",
        artifact,
        lambda item: set_envelope_header_kind(item, 2),
        "kind mismatch",
    )

    print("NumiSeal production superneo CLI validation regression tests passed")


if __name__ == "__main__":
    main()
