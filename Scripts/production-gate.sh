#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUN_BENCHMARKS=0

usage() {
  cat <<'USAGE'
Usage: Scripts/production-gate.sh [--with-benchmarks]

Runs the release-readiness gate for SuperNeo NuMetal:
  - release build
  - debug and release XCTest suites
  - checked-in test vector validation
  - release CLI prove/verify smoke for bundled workloads

Pass --with-benchmarks to include Scripts/run-benchmarks.sh quick.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --with-benchmarks)
      RUN_BENCHMARKS=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 64
      ;;
  esac
done

cleanup_paths=()
cleanup() {
  if [[ ${#cleanup_paths[@]} -gt 0 ]]; then
    rm -f "${cleanup_paths[@]}"
  fi
}
trap cleanup EXIT

make_temp_json() {
  mktemp "${TMPDIR:-/tmp}/superneo-gate.XXXXXX"
}

run_step() {
  echo
  echo "==> $*"
  "$@"
}

run_expect_failure() {
  echo
  echo "==> expect failure: $*"
  if "$@"; then
    echo "expected command to fail, but it succeeded" >&2
    exit 1
  fi
}

cd "${ROOT_DIR}"

SUPERNEO_CLI="${ROOT_DIR}/.build/release/superneo"

ONE_HOT_KEY_SEED="SuperNeoCLI.one-hot-vector.v1"
ONE_HOT_SHAPE_DIGEST="84d903373ff54785a9b7d99bd048e1527deedd1173309c272992a8a87b61a765"
ONE_HOT_STATEMENT_DIGEST="786532c3daee5d41f54b619bde8b6bcc432f7ae1f40017e14953cc8ce38992e0"
ONE_HOT_VERIFIER_KEY_DIGEST="7e6c4fc3ec5bee0e1872cde17322830a37fc0a2d17ed79a208f6113fd0186a86"

BINARY_ADD_KEY_SEED="SuperNeoCLI.binary-addition.u8.v1"
BINARY_ADD_SHAPE_DIGEST="8ff5c76dd2bad49eb2b4de4272f3c7ce3d27e28c21f3a5c4d39083a884fb3089"
BINARY_ADD_STATEMENT_DIGEST="109b394b315f9b846e13ceb1f00ee0b374ff459334425a5b1063a8db554551a9"
BINARY_ADD_VERIFIER_KEY_DIGEST="199bec9fea21d192f741e81896029d07743b9a8b793543751ea1605fe2a8e973"
BINARY_ADD_PUBLIC_INPUTS="1,0,1,0,1,0,1,0,0,0"

run_step swift build -c release
run_step swift test --disable-swift-testing
run_step swift test -c release --disable-swift-testing
run_step swift Scripts/validate-test-vectors.swift

one_hot_path="$(make_temp_json)"
binary_add_path="$(make_temp_json)"
cleanup_paths+=("${one_hot_path}" "${binary_add_path}")

run_step "${SUPERNEO_CLI}" prove \
  --bits 0,0,1,0,0,0,0,0 \
  --output "${one_hot_path}"
run_step "${SUPERNEO_CLI}" verify \
  --key-seed "${ONE_HOT_KEY_SEED}" \
  --expected-verifier-key-digest "${ONE_HOT_VERIFIER_KEY_DIGEST}" \
  --expected-shape-digest "${ONE_HOT_SHAPE_DIGEST}" \
  --expected-statement-digest "${ONE_HOT_STATEMENT_DIGEST}" \
  --expected-public-inputs 1 \
  "${one_hot_path}"
run_expect_failure "${SUPERNEO_CLI}" verify \
  --key-seed "${ONE_HOT_KEY_SEED}" \
  --expected-verifier-key-digest "${ONE_HOT_VERIFIER_KEY_DIGEST}" \
  --expected-shape-digest "${ONE_HOT_SHAPE_DIGEST}" \
  --expected-statement-digest "${ONE_HOT_STATEMENT_DIGEST}" \
  --expected-public-inputs 0 \
  "${one_hot_path}"
run_expect_failure "${SUPERNEO_CLI}" verify \
  --key-seed "${ONE_HOT_KEY_SEED}" \
  --expected-verifier-key-digest "${ONE_HOT_VERIFIER_KEY_DIGEST}" \
  --expected-shape-digest "${ONE_HOT_SHAPE_DIGEST}" \
  --expected-statement-digest "${ONE_HOT_STATEMENT_DIGEST}" \
  --expected-public-inputs 1 \
  --require-terminal \
  "${one_hot_path}"
run_step "${SUPERNEO_CLI}" inspect "${one_hot_path}"

run_step "${SUPERNEO_CLI}" prove \
  --workload binary-add \
  --operand-bits 8 \
  --lhs 13 \
  --rhs 29 \
  --output "${binary_add_path}"
run_step "${SUPERNEO_CLI}" verify \
  --key-seed "${BINARY_ADD_KEY_SEED}" \
  --expected-verifier-key-digest "${BINARY_ADD_VERIFIER_KEY_DIGEST}" \
  --expected-shape-digest "${BINARY_ADD_SHAPE_DIGEST}" \
  --expected-statement-digest "${BINARY_ADD_STATEMENT_DIGEST}" \
  --expected-public-inputs "${BINARY_ADD_PUBLIC_INPUTS}" \
  "${binary_add_path}"

if [[ "${RUN_BENCHMARKS}" -eq 1 ]]; then
  run_step Scripts/run-benchmarks.sh quick
fi

echo
echo "Production gate passed."
