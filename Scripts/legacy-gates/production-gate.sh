#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUN_TESTS=1

usage() {
  cat <<'USAGE'
Usage: Scripts/production-gate.sh [--skip-tests]

Runs the default completion gate:
  - debug build of the package
  - focused Swift smoke tests through Scripts/test-slice.sh fast
  - CLI prove/verify smoke for a one-hot fold artifact

Research evidence validation, Lean builds, lattice-estimator reproduction, and
benchmark suites are intentionally not part of this default gate.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-tests)
      RUN_TESTS=0
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

run_step() {
  echo
  echo "==> $*"
  "$@"
}

cd "${ROOT_DIR}"

proof_path="$(mktemp "${TMPDIR:-/tmp}/superneo-smoke-proof.XXXXXX.json")"
cleanup() {
  rm -f "${proof_path}"
}
trap cleanup EXIT

run_step swift build

if [[ "${RUN_TESTS}" -eq 1 ]]; then
  run_step Scripts/test-slice.sh fast
fi

run_step swift run superneo prove \
  --workload one-hot \
  --bits 0,0,1,0 \
  --output "${proof_path}"

run_step swift run superneo verify "${proof_path}"

echo
echo "Default completion gate passed."
