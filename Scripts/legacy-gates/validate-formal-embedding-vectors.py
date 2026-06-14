#!/usr/bin/env python3
import argparse
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]

REQUIRED_LABELS = [
    "embedding_input_length",
    "embedding_padded_length",
    "embedding_packed_column_count",
    "embedding_input_raw_values",
    "embedding_first_column_coefficients",
    "embedding_second_column_coefficients",
    "embedding_unpacked_prefix",
    "embedding_padding_suffix_zero",
    "embedding_preserves_norm_exact_block",
    "embedding_inner_product_row_coefficients",
    "embedding_inner_product_transform_coefficients",
    "embedding_inner_product_constant_term",
    "embedding_inner_product_expected",
    "embedding_sparse_matrix_field_product",
    "embedding_transformed_dense_constants",
    "embedding_transformed_sparse_constants",
]


def fail(message: str) -> None:
    print(f"error: {message}", file=sys.stderr)
    raise SystemExit(1)


def run_command(command: list[str], cwd: Path) -> str:
    result = subprocess.run(
        command,
        cwd=cwd,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if result.returncode != 0:
        fail(
            "command failed with exit code "
            f"{result.returncode}: {' '.join(command)}\n{result.stderr}"
        )
    return result.stdout


def parse_output(output: str) -> dict[str, str]:
    parsed: dict[str, str] = {}
    for line_number, raw_line in enumerate(output.splitlines(), start=1):
        line = raw_line.strip()
        if not line:
            continue
        if "=" not in line:
            fail(f"line {line_number} is not label=value: {raw_line!r}")
        label, value = line.split("=", 1)
        if label in parsed:
            fail(f"duplicate label {label!r}")
        parsed[label] = value

    missing = [label for label in REQUIRED_LABELS if label not in parsed]
    if missing:
        fail(f"missing required labels: {', '.join(missing)}")
    extra = sorted(set(parsed).difference(REQUIRED_LABELS))
    if extra:
        fail(f"unsupported labels: {', '.join(extra)}")
    return parsed


def parse_csv_ints(value: str) -> list[int]:
    if value == "":
        return []
    try:
        return [int(part) for part in value.split(",")]
    except ValueError as error:
        fail(f"invalid integer list {value!r}: {error}")


def require_equal(actual: object, expected: object, label: str) -> None:
    if actual != expected:
        fail(f"{label} mismatch: expected {expected!r}, got {actual!r}")


def validate(vectors: dict[str, str]) -> None:
    input_length = int(vectors["embedding_input_length"])
    padded_length = int(vectors["embedding_padded_length"])
    packed_column_count = int(vectors["embedding_packed_column_count"])
    require_equal(input_length, 60, "input length")
    require_equal(padded_length, 108, "padded length")
    require_equal(packed_column_count, 2, "packed column count")

    input_values = parse_csv_ints(vectors["embedding_input_raw_values"])
    unpacked_prefix = parse_csv_ints(vectors["embedding_unpacked_prefix"])
    first_column = parse_csv_ints(vectors["embedding_first_column_coefficients"])
    second_column = parse_csv_ints(vectors["embedding_second_column_coefficients"])
    require_equal(unpacked_prefix, input_values, "unpacked prefix")
    require_equal(first_column, input_values[:54], "first packed column")
    require_equal(second_column[:6], input_values[54:], "second packed column prefix")
    require_equal(second_column[6:], [0] * 48, "second packed column padding")
    require_equal(vectors["embedding_padding_suffix_zero"], "true", "padding flag")
    require_equal(vectors["embedding_preserves_norm_exact_block"], "true", "norm preservation flag")

    require_equal(
        vectors["embedding_inner_product_constant_term"],
        vectors["embedding_inner_product_expected"],
        "inner-product constant term",
    )
    field_product = parse_csv_ints(vectors["embedding_sparse_matrix_field_product"])
    dense_constants = parse_csv_ints(vectors["embedding_transformed_dense_constants"])
    sparse_constants = parse_csv_ints(vectors["embedding_transformed_sparse_constants"])
    require_equal(dense_constants, field_product, "dense transformed constants")
    require_equal(sparse_constants, field_product, "sparse transformed constants")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Validate Swift embedding/homomorphism formal-vector output."
    )
    parser.add_argument("--root", default=str(ROOT), help="repository root")
    parser.add_argument("--swift-output-file", help="read Swift vector output from a file")
    args = parser.parse_args()

    root = Path(args.root).resolve()
    if args.swift_output_file:
        output = Path(args.swift_output_file).read_text(encoding="utf-8")
    else:
        output = run_command(
            ["swift", "run", "-c", "release", "--package-path", str(root), "superneo-formal-vectors", "embedding"],
            root,
        )
    validate(parse_output(output))
    print("Swift embedding and transform vectors are internally consistent")


if __name__ == "__main__":
    main()
