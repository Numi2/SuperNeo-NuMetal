#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
  cat <<'USAGE'
Usage: Scripts/check-crypto-dev.sh

Run the active crypto-development checks:
  - focused build/prove/verify smoke
  - malformed proof artifact fuzzing
  - verifier-negative attack slice

This catches broken proofs, verifier acceptance bugs, bad encodings, and
transcript/serialization drift. It is not a release or documentation gate.
USAGE
}

if [[ $# -gt 0 ]]; then
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 64
      ;;
  esac
fi

run_step() {
  echo
  echo "==> $*"
  "$@"
}

cd "${ROOT_DIR}"

run_step Scripts/check-smoke.sh
run_step Scripts/fuzz-malformed-artifacts.sh
run_step Scripts/test-slice.sh attack

echo
echo "Crypto-dev checks passed."

