#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUN_BENCHMARKS=0
RUN_FORMAL=1

usage() {
  cat <<'USAGE'
Usage: Scripts/production-gate.sh [--with-benchmarks] [--skip-formal]

Runs the release-readiness gate for SuperNeo NuMetal:
  - release build
  - debug and release XCTest suites
  - Lean formal build and formal-status validation
  - Lean/Swift profile-constant conformance validation
  - checked-in test vector validation
  - release CLI fold and terminal prove/verify smoke for bundled workloads

Pass --with-benchmarks to include Scripts/run-benchmarks.sh quick.
Pass --skip-formal when a separate CI job is already running the Lean/formal gate.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --with-benchmarks)
      RUN_BENCHMARKS=1
      shift
      ;;
    --skip-formal)
      RUN_FORMAL=0
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

run_step_in_dir() {
  local dir="$1"
  shift
  echo
  echo "==> (${dir}) $*"
  (cd "${dir}" && "$@")
}

run_expect_failure() {
  echo
  echo "==> expect failure: $*"
  if "$@"; then
    echo "expected command to fail, but it succeeded" >&2
    exit 1
  fi
}

require_lake() {
  if ! command -v lake >/dev/null 2>&1; then
    cat >&2 <<'ERROR'
missing required command: lake
Install elan and ensure its bin directory is on PATH before running the production gate.
The Lean toolchain is pinned by Formal/lean-toolchain.
ERROR
    exit 127
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
run_step Scripts/validate-artifact-schema.py
run_step Scripts/test-artifact-schema-validation.py
run_step swift Scripts/validate-test-vectors.swift

lattice_path="$(make_temp_json)"
one_hot_path="$(make_temp_json)"
one_hot_unknown_field_path="$(make_temp_json)"
one_hot_duplicate_top_level_key_path="$(make_temp_json)"
one_hot_missing_selected_count_path="$(make_temp_json)"
one_hot_terminal_path="$(make_temp_json)"
binary_add_path="$(make_temp_json)"
binary_add_missing_sum_path="$(make_temp_json)"
binary_add_noncanonical_sum_path="$(make_temp_json)"
binary_add_bad_left_bit_count_path="$(make_temp_json)"
binary_add_duplicate_workload_key_path="$(make_temp_json)"
cleanup_paths+=("${lattice_path}" "${one_hot_path}" "${one_hot_unknown_field_path}" "${one_hot_duplicate_top_level_key_path}" "${one_hot_missing_selected_count_path}" "${one_hot_terminal_path}" "${binary_add_path}" "${binary_add_missing_sum_path}" "${binary_add_noncanonical_sum_path}" "${binary_add_bad_left_bit_count_path}" "${binary_add_duplicate_workload_key_path}")

run_step Scripts/reproduce-lattice-estimator.sh --dry-run "${lattice_path}"
run_step Scripts/validate-lattice-estimator-artifact.py --expect-status not_run --expect-latest-status absent "${lattice_path}"
run_step Scripts/test-lattice-estimator-artifact-validation.py
if [[ "${RUN_FORMAL}" -eq 1 ]]; then
  require_lake
  run_step_in_dir Formal lake build
  run_step Scripts/validate-formal-status.py
  run_step Scripts/test-formal-status-validation.py
  run_step Scripts/validate-formal-profile-constants.py
  run_step Scripts/test-formal-profile-constants-validation.py
fi

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
run_step python3 - "${one_hot_path}" "${one_hot_unknown_field_path}" <<'PY'
import json
import sys
source, destination = sys.argv[1], sys.argv[2]
with open(source, "r", encoding="utf-8") as handle:
    artifact = json.load(handle)
artifact["unexpectedTrustAnchor"] = "ignored-by-default-json-decoders"
with open(destination, "w", encoding="utf-8") as handle:
    json.dump(artifact, handle, indent=2, sort_keys=True)
PY
run_expect_failure "${SUPERNEO_CLI}" verify \
  --key-seed "${ONE_HOT_KEY_SEED}" \
  --expected-verifier-key-digest "${ONE_HOT_VERIFIER_KEY_DIGEST}" \
  --expected-shape-digest "${ONE_HOT_SHAPE_DIGEST}" \
  --expected-statement-digest "${ONE_HOT_STATEMENT_DIGEST}" \
  --expected-public-inputs 1 \
  "${one_hot_unknown_field_path}"
run_step python3 - "${one_hot_path}" "${one_hot_duplicate_top_level_key_path}" <<'PY'
import sys
source, destination = sys.argv[1], sys.argv[2]
with open(source, "r", encoding="utf-8") as handle:
    text = handle.read()
needle = '  "profile" : "Goldilocks\\/Phi81(d=54)",'
replacement = needle + '\n  "profile" : "duplicate-profile",'
if needle not in text:
    raise SystemExit("profile field not found")
with open(destination, "w", encoding="utf-8") as handle:
    handle.write(text.replace(needle, replacement, 1))
PY
run_expect_failure "${SUPERNEO_CLI}" verify \
  --key-seed "${ONE_HOT_KEY_SEED}" \
  --expected-verifier-key-digest "${ONE_HOT_VERIFIER_KEY_DIGEST}" \
  --expected-shape-digest "${ONE_HOT_SHAPE_DIGEST}" \
  --expected-statement-digest "${ONE_HOT_STATEMENT_DIGEST}" \
  --expected-public-inputs 1 \
  "${one_hot_duplicate_top_level_key_path}"
run_step python3 - "${one_hot_path}" "${one_hot_missing_selected_count_path}" <<'PY'
import json
import sys
source, destination = sys.argv[1], sys.argv[2]
with open(source, "r", encoding="utf-8") as handle:
    artifact = json.load(handle)
artifact["workloadParameters"].pop("selectedCount", None)
with open(destination, "w", encoding="utf-8") as handle:
    json.dump(artifact, handle, indent=2, sort_keys=True)
PY
run_expect_failure "${SUPERNEO_CLI}" verify \
  --key-seed "${ONE_HOT_KEY_SEED}" \
  --expected-verifier-key-digest "${ONE_HOT_VERIFIER_KEY_DIGEST}" \
  --expected-shape-digest "${ONE_HOT_SHAPE_DIGEST}" \
  --expected-statement-digest "${ONE_HOT_STATEMENT_DIGEST}" \
  --expected-public-inputs 1 \
  "${one_hot_missing_selected_count_path}"
run_step "${SUPERNEO_CLI}" inspect "${one_hot_path}"

run_step "${SUPERNEO_CLI}" prove \
  --kind terminal \
  --bits 0,0,1,0,0,0,0,0 \
  --output "${one_hot_terminal_path}"
run_step "${SUPERNEO_CLI}" verify \
  --key-seed "${ONE_HOT_KEY_SEED}" \
  --expected-verifier-key-digest "${ONE_HOT_VERIFIER_KEY_DIGEST}" \
  --expected-shape-digest "${ONE_HOT_SHAPE_DIGEST}" \
  --expected-statement-digest "${ONE_HOT_STATEMENT_DIGEST}" \
  --expected-public-inputs 1 \
  --require-terminal \
  "${one_hot_terminal_path}"

run_step "${SUPERNEO_CLI}" prove \
  --workload binary-add \
  --operand-bits 8 \
  --lhs 13 \
  --rhs 29 \
  --output "${binary_add_path}"
run_step python3 - "${binary_add_path}" "${binary_add_missing_sum_path}" <<'PY'
import json
import sys
source, destination = sys.argv[1], sys.argv[2]
with open(source, "r", encoding="utf-8") as handle:
    artifact = json.load(handle)
artifact["workloadParameters"].pop("publicSum", None)
with open(destination, "w", encoding="utf-8") as handle:
    json.dump(artifact, handle, indent=2, sort_keys=True)
PY
run_expect_failure "${SUPERNEO_CLI}" verify \
  --key-seed "${BINARY_ADD_KEY_SEED}" \
  --expected-verifier-key-digest "${BINARY_ADD_VERIFIER_KEY_DIGEST}" \
  --expected-shape-digest "${BINARY_ADD_SHAPE_DIGEST}" \
  --expected-statement-digest "${BINARY_ADD_STATEMENT_DIGEST}" \
  --expected-public-inputs "${BINARY_ADD_PUBLIC_INPUTS}" \
  "${binary_add_missing_sum_path}"
run_step python3 - "${binary_add_path}" "${binary_add_noncanonical_sum_path}" <<'PY'
import json
import sys
source, destination = sys.argv[1], sys.argv[2]
with open(source, "r", encoding="utf-8") as handle:
    artifact = json.load(handle)
artifact["workloadParameters"]["publicSum"] = "042"
with open(destination, "w", encoding="utf-8") as handle:
    json.dump(artifact, handle, indent=2, sort_keys=True)
PY
run_expect_failure "${SUPERNEO_CLI}" verify \
  --key-seed "${BINARY_ADD_KEY_SEED}" \
  --expected-verifier-key-digest "${BINARY_ADD_VERIFIER_KEY_DIGEST}" \
  --expected-shape-digest "${BINARY_ADD_SHAPE_DIGEST}" \
  --expected-statement-digest "${BINARY_ADD_STATEMENT_DIGEST}" \
  --expected-public-inputs "${BINARY_ADD_PUBLIC_INPUTS}" \
  "${binary_add_noncanonical_sum_path}"
run_step python3 - "${binary_add_path}" "${binary_add_bad_left_bit_count_path}" <<'PY'
import json
import sys
source, destination = sys.argv[1], sys.argv[2]
with open(source, "r", encoding="utf-8") as handle:
    artifact = json.load(handle)
artifact["workloadParameters"]["leftBitCount"] = "9"
with open(destination, "w", encoding="utf-8") as handle:
    json.dump(artifact, handle, indent=2, sort_keys=True)
PY
run_expect_failure "${SUPERNEO_CLI}" verify \
  --key-seed "${BINARY_ADD_KEY_SEED}" \
  --expected-verifier-key-digest "${BINARY_ADD_VERIFIER_KEY_DIGEST}" \
  --expected-shape-digest "${BINARY_ADD_SHAPE_DIGEST}" \
  --expected-statement-digest "${BINARY_ADD_STATEMENT_DIGEST}" \
  --expected-public-inputs "${BINARY_ADD_PUBLIC_INPUTS}" \
  "${binary_add_bad_left_bit_count_path}"
run_step python3 - "${binary_add_path}" "${binary_add_duplicate_workload_key_path}" <<'PY'
import sys
source, destination = sys.argv[1], sys.argv[2]
with open(source, "r", encoding="utf-8") as handle:
    text = handle.read()
needle = '    "publicSum" : "42"'
replacement = needle + ',\n    "publicSum" : "42"'
if needle not in text:
    raise SystemExit("publicSum field not found")
with open(destination, "w", encoding="utf-8") as handle:
    handle.write(text.replace(needle, replacement, 1))
PY
run_expect_failure "${SUPERNEO_CLI}" verify \
  --key-seed "${BINARY_ADD_KEY_SEED}" \
  --expected-verifier-key-digest "${BINARY_ADD_VERIFIER_KEY_DIGEST}" \
  --expected-shape-digest "${BINARY_ADD_SHAPE_DIGEST}" \
  --expected-statement-digest "${BINARY_ADD_STATEMENT_DIGEST}" \
  --expected-public-inputs "${BINARY_ADD_PUBLIC_INPUTS}" \
  "${binary_add_duplicate_workload_key_path}"
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
