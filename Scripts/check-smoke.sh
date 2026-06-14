#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
  cat <<'USAGE'
Usage: Scripts/check-smoke.sh [--skip-tests]

Daily crypto-dev smoke check:
  - package builds
  - focused unit tests pass
  - one tiny prove/verify roundtrip works
  - checked vectors parse as canonical JSON
USAGE
}

RUN_TESTS=1
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
  --bits 0,1 \
  --output "${proof_path}"

run_step swift run superneo verify "${proof_path}"

echo
echo "==> serialization sanity"
python3 - "${ROOT_DIR}" "${proof_path}" <<'PY'
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
proof = pathlib.Path(sys.argv[2])
json.loads(proof.read_text(encoding="utf-8"))
for path in sorted((root / "TestVectors").glob("*.json")):
    json.loads(path.read_text(encoding="utf-8"))
print("parsed proof artifact and checked vector JSON")
PY

echo
echo "Smoke check passed."
