#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="generate"

usage() {
  cat <<'USAGE'
Usage: Scripts/regenerate-test-vectors.sh [--check|--write] [output-dir]

Regenerate the small proof artifacts used as stable verifier test vectors.

Modes:
  default   write regenerated vectors to a temporary directory and verify them
  --check   regenerate, verify, and byte-compare against TestVectors/
  --write   regenerate directly into TestVectors/

This is crypto-dev tooling: it catches proof generation, verifier, and
serialization drift. It is not a wording or release gate.
USAGE
}

if [[ $# -gt 0 ]]; then
  case "$1" in
    --check)
      MODE="check"
      shift
      ;;
    --write)
      MODE="write"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
  esac
fi

if [[ $# -gt 1 ]]; then
  usage >&2
  exit 64
fi

cd "${ROOT_DIR}"

case "${MODE}" in
  generate|check)
    output_dir="${1:-$(mktemp -d "${TMPDIR:-/tmp}/superneo-vectors.XXXXXX")}"
    ;;
  write)
    output_dir="${1:-${ROOT_DIR}/TestVectors}"
    ;;
  *)
    usage >&2
    exit 64
    ;;
esac

mkdir -p "${output_dir}"

run_step() {
  echo
  echo "==> $*"
  "$@"
}

generate() {
  local name="$1"
  shift
  run_step swift run superneo prove "$@" --output "${output_dir}/${name}"
  run_step swift run superneo verify "${output_dir}/${name}"
}

generate_terminal() {
  local name="$1"
  shift
  run_step swift run superneo prove "$@" --output "${output_dir}/${name}"
  run_step swift run superneo verify --require-terminal "${output_dir}/${name}"
}

generate \
  one-hot-vector-fold-v1.json \
  --workload one-hot \
  --bits 0,0,1,0

generate_terminal \
  one-hot-vector-terminal-v1.json \
  --workload one-hot \
  --kind terminal \
  --bits 0,0,1,0

generate_terminal \
  one-hot-vector-compressed-terminal-v1.json \
  --workload one-hot \
  --kind compressed-terminal \
  --bits 0,0,1,0

generate \
  binary-addition-u8-fold-v1.json \
  --workload binary-add \
  --operand-bits 8 \
  --lhs 13 \
  --rhs 29

generate_terminal \
  binary-addition-u8-terminal-v1.json \
  --workload binary-add \
  --kind terminal \
  --operand-bits 8 \
  --lhs 13 \
  --rhs 29

if [[ "${MODE}" == "check" ]]; then
  echo
  echo "==> comparing against TestVectors"
  mismatch=0
  for name in \
    one-hot-vector-fold-v1.json \
    one-hot-vector-terminal-v1.json \
    one-hot-vector-compressed-terminal-v1.json \
    binary-addition-u8-fold-v1.json \
    binary-addition-u8-terminal-v1.json
  do
    if ! cmp -s "${output_dir}/${name}" "${ROOT_DIR}/TestVectors/${name}"; then
      echo "vector drift: ${name}" >&2
      mismatch=1
    fi
  done
  if [[ "${mismatch}" -ne 0 ]]; then
    echo "Regenerated vectors differ from checked fixtures." >&2
    echo "Inspect the generated files in ${output_dir}; use --write only for intentional vector refresh." >&2
    exit 1
  fi
fi

echo
echo "Regenerated vectors in ${output_dir}"
