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
  - Lean formal build, executable gates, and formal-status validation
  - Lean/Swift profile-constant conformance validation
  - constant-time source/formal scope validation
  - E2E proof-size metrics and generated product smoke budget validation
  - product operations readiness surface validation
  - checked-in test vector validation
  - checked-in NumiSeal schema and vector validation
  - NumiSeal product/carry/ZK conformance-scope validation
  - production NumiSeal CLI adversarial matrix
  - optional signed NumiSealZK side-channel certificate binding tests
  - release policy, schema compatibility, and CI gate drift validation
  - release-candidate evidence tooling validation
  - release CLI fold, terminal, compressed-terminal, and NumiSeal prove/verify smoke

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
NUMISEAL_VECTOR_CLI="${ROOT_DIR}/.build/release/superneo-numiseal-vectors"

ONE_HOT_KEY_SEED="SuperNeoCLI.one-hot-vector.v1"
ONE_HOT_SHAPE_DIGEST="84d903373ff54785a9b7d99bd048e1527deedd1173309c272992a8a87b61a765"
ONE_HOT_STATEMENT_DIGEST="786532c3daee5d41f54b619bde8b6bcc432f7ae1f40017e14953cc8ce38992e0"
ONE_HOT_VERIFIER_KEY_DIGEST="7e6c4fc3ec5bee0e1872cde17322830a37fc0a2d17ed79a208f6113fd0186a86"

BINARY_ADD_KEY_SEED="SuperNeoCLI.binary-addition.u8.v1"
BINARY_ADD_SHAPE_DIGEST="8ff5c76dd2bad49eb2b4de4272f3c7ce3d27e28c21f3a5c4d39083a884fb3089"
BINARY_ADD_STATEMENT_DIGEST="109b394b315f9b846e13ceb1f00ee0b374ff459334425a5b1063a8db554551a9"
BINARY_ADD_VERIFIER_KEY_DIGEST="199bec9fea21d192f741e81896029d07743b9a8b793543751ea1605fe2a8e973"
BINARY_ADD_PUBLIC_INPUTS="1,0,1,0,1,0,1,0,0,0"

NUMISEAL_ZERO_PUBLIC_INPUTS="$(python3 - <<'PY'
print(",".join(["0"] * 54))
PY
)"
NUMISEAL_SINGLE_VECTOR="TestVectors/numiseal-terminal-single-aggregate-v1.json"
NUMISEAL_SINGLE_KEY_SEED="SuperNeoNumiSeal.vector.single-aggregate.key.v1"
NUMISEAL_SINGLE_SHAPE_DIGEST="31c29845341f90a02918b6693f671751b0d5416e05412d4d7b6ff1eab687fb9e"
NUMISEAL_SINGLE_STATEMENT_DIGEST="9a8a92e65a81372c4be1b6a853c4fb6417011de99fa1167fae0948e0d20e451e"
NUMISEAL_SINGLE_VERIFIER_KEY_DIGEST="fd2605390a4f450fdfdcde6259aa8bb06c51bf66d1def285fbe9cabc5eb09a73"
NUMISEAL_SINGLE_TRANSCRIPT_DOMAIN_DIGEST="018865fb07dbefdbbf9764906781d45b20b36d72ed36c2a13c827e585c7be9de"
NUMISEAL_SINGLE_PUBLIC_STATEMENT_DIGEST="b38d814282d7273508a1ce56ac98bfca87018250080c26b7ad98b9fa6b8b9070"
NUMISEAL_SINGLE_OBLIGATION_ROOT="f2885132eb7e2354904f2171e7fb1a7f8764a8a96a1dab2fa059c8923bce6f13"
NUMISEAL_SINGLE_LANE_SUMMARY_ROOT="53141d23dc57cbf7bba102aa3c92de94997139d416f007b69cf50e3b57953147"
NUMISEAL_SINGLE_AGGREGATE_DIGESTS="6bd43ca109ddc7578de000d6a0983a878e3a7d76df4ccb60d74b08f9fbfd25ae"
NUMISEAL_SINGLE_COMPONENT_DIGEST_ROOT="5320b1bf387199838f8f1ebd9fbfa2efec054555af3a4d07cea001e17ec510ad"
NUMISEAL_SINGLE_PROOF_TRANSCRIPT_DIGEST="f4315994c550045181389647af20533bfee3a2383b6a23072d1715f854c8c7b4"

run_step swift build -c release
run_step swift test --disable-swift-testing
run_step swift test -c release --disable-swift-testing
run_step Scripts/validate-artifact-schema.py
run_step Scripts/test-artifact-schema-validation.py
run_step Scripts/validate-numiseal-artifact-schema.py
run_step Scripts/validate-numiseal-product-artifact-schema.py
run_step Scripts/test-numiseal-artifact-schema-validation.py
run_step Scripts/validate-numiseal-conformance-scope.py
run_step Scripts/validate-constant-time-scope.py
run_step Scripts/test-constant-time-scope-validation.py
run_step Scripts/validate-e2e-proof-metrics.py
run_step Scripts/test-e2e-proof-metrics-validation.py
run_step Scripts/validate-product-ops-surface.py
run_step Scripts/test-product-ops-surface-validation.py
run_step Scripts/validate-release-readiness-policy.py
run_step Scripts/test-release-candidate-evidence-validation.py
run_step Scripts/test-benchmark-tooling-validation.py
run_step swift Scripts/validate-test-vectors.swift
run_step "${NUMISEAL_VECTOR_CLI}" validate
run_step python3 Scripts/test-numiseal-vector-validation.py --cli "${NUMISEAL_VECTOR_CLI}"
run_step python3 Scripts/test-numiseal-superneo-cli-validation.py --cli "${SUPERNEO_CLI}"
run_step "${SUPERNEO_CLI}" inspect "${NUMISEAL_SINGLE_VECTOR}"
run_expect_failure "${SUPERNEO_CLI}" verify "${NUMISEAL_SINGLE_VECTOR}"
run_expect_failure "${SUPERNEO_CLI}" verify --require-terminal "${NUMISEAL_SINGLE_VECTOR}"
run_step "${SUPERNEO_CLI}" verify \
  --require-numiseal \
  --key-seed "${NUMISEAL_SINGLE_KEY_SEED}" \
  --expected-verifier-key-digest "${NUMISEAL_SINGLE_VERIFIER_KEY_DIGEST}" \
  --expected-shape-digest "${NUMISEAL_SINGLE_SHAPE_DIGEST}" \
  --expected-statement-digest "${NUMISEAL_SINGLE_STATEMENT_DIGEST}" \
  --expected-transcript-domain-digest "${NUMISEAL_SINGLE_TRANSCRIPT_DOMAIN_DIGEST}" \
  --expected-public-statement-digest "${NUMISEAL_SINGLE_PUBLIC_STATEMENT_DIGEST}" \
  --expected-obligation-root "${NUMISEAL_SINGLE_OBLIGATION_ROOT}" \
  --expected-lane-summary-root "${NUMISEAL_SINGLE_LANE_SUMMARY_ROOT}" \
  --expected-aggregate-digests "${NUMISEAL_SINGLE_AGGREGATE_DIGESTS}" \
  --expected-component-digest-root "${NUMISEAL_SINGLE_COMPONENT_DIGEST_ROOT}" \
  --expected-proof-transcript-digest "${NUMISEAL_SINGLE_PROOF_TRANSCRIPT_DIGEST}" \
  --expected-public-inputs "${NUMISEAL_ZERO_PUBLIC_INPUTS}" \
  "${NUMISEAL_SINGLE_VECTOR}"
run_expect_failure "${SUPERNEO_CLI}" verify \
  --require-numiseal \
  --expected-public-statement-digest "0000000000000000000000000000000000000000000000000000000000000000" \
  "${NUMISEAL_SINGLE_VECTOR}"
run_step "${SUPERNEO_CLI}" verify --require-numiseal TestVectors/numiseal-terminal-two-aggregate-v1.json
run_step "${SUPERNEO_CLI}" verify --require-numiseal TestVectors/numiseal-terminal-two-lane-v1.json
run_step Scripts/test-vector-manifest-validation.py

lattice_path="$(make_temp_json)"
one_hot_path="$(make_temp_json)"
one_hot_unknown_field_path="$(make_temp_json)"
one_hot_duplicate_top_level_key_path="$(make_temp_json)"
one_hot_missing_selected_count_path="$(make_temp_json)"
one_hot_terminal_path="$(make_temp_json)"
one_hot_compressed_terminal_path="$(make_temp_json)"
one_hot_compressed_terminal_as_terminal_path="$(make_temp_json)"
one_hot_compressed_terminal_as_fold_path="$(make_temp_json)"
numiseal_product_path="$(make_temp_json)"
numiseal_zk_product_path="$(make_temp_json)"
binary_add_path="$(make_temp_json)"
binary_add_terminal_path="$(make_temp_json)"
binary_add_missing_sum_path="$(make_temp_json)"
binary_add_noncanonical_sum_path="$(make_temp_json)"
binary_add_bad_left_bit_count_path="$(make_temp_json)"
binary_add_duplicate_workload_key_path="$(make_temp_json)"
cleanup_paths+=("${lattice_path}" "${one_hot_path}" "${one_hot_unknown_field_path}" "${one_hot_duplicate_top_level_key_path}" "${one_hot_missing_selected_count_path}" "${one_hot_terminal_path}" "${one_hot_compressed_terminal_path}" "${one_hot_compressed_terminal_as_terminal_path}" "${one_hot_compressed_terminal_as_fold_path}" "${numiseal_product_path}" "${numiseal_zk_product_path}" "${binary_add_path}" "${binary_add_terminal_path}" "${binary_add_missing_sum_path}" "${binary_add_noncanonical_sum_path}" "${binary_add_bad_left_bit_count_path}" "${binary_add_duplicate_workload_key_path}")

run_step Scripts/reproduce-lattice-estimator.sh --dry-run "${lattice_path}"
run_step Scripts/validate-lattice-estimator-artifact.py --expect-status not_run --expect-latest-status absent "${lattice_path}"
run_step Scripts/test-lattice-estimator-artifact-validation.py
if [[ "${RUN_FORMAL}" -eq 1 ]]; then
  require_lake
  run_step_in_dir Formal lake build
  run_step_in_dir Formal lake build SuperNeoFormal.VectorChecks
  run_step_in_dir Formal lake env lean --run ProofImportWall.lean
  run_step_in_dir Formal lake env lean --run SuperNeoFormalVectorCheck.lean
  run_step Scripts/validate-formal-status.py
  run_step Scripts/test-formal-status-validation.py
  run_step Scripts/validate-formal-profile-constants.py
  run_step Scripts/test-formal-profile-constants-validation.py
  run_step Scripts/validate-formal-ext2-serialization.py
  run_step Scripts/test-formal-ext2-serialization-validation.py
  run_step Scripts/compare-formal-ext2-vectors.py
  run_step Scripts/test-formal-ext2-vector-bridge.py
  run_step Scripts/validate-formal-ce-byte-serialization.py
  run_step Scripts/test-formal-ce-byte-serialization-validation.py
  run_step Scripts/compare-formal-ce-vectors.py
  run_step Scripts/test-formal-ce-vector-bridge.py
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
  --kind compressed-terminal \
  --bits 0,0,1,0,0,0,0,0 \
  --output "${one_hot_compressed_terminal_path}"
run_step "${SUPERNEO_CLI}" verify \
  --key-seed "${ONE_HOT_KEY_SEED}" \
  --expected-verifier-key-digest "${ONE_HOT_VERIFIER_KEY_DIGEST}" \
  --expected-shape-digest "${ONE_HOT_SHAPE_DIGEST}" \
  --expected-statement-digest "${ONE_HOT_STATEMENT_DIGEST}" \
  --expected-public-inputs 1 \
  --require-terminal \
  "${one_hot_compressed_terminal_path}"
run_step python3 - "${one_hot_compressed_terminal_path}" "${one_hot_compressed_terminal_as_terminal_path}" terminal <<'PY'
import json
import sys
source, destination, proof_kind = sys.argv[1], sys.argv[2], sys.argv[3]
with open(source, "r", encoding="utf-8") as handle:
    artifact = json.load(handle)
artifact["proofKind"] = proof_kind
with open(destination, "w", encoding="utf-8") as handle:
    json.dump(artifact, handle, indent=2, sort_keys=True)
PY
run_expect_failure "${SUPERNEO_CLI}" verify \
  --key-seed "${ONE_HOT_KEY_SEED}" \
  --expected-verifier-key-digest "${ONE_HOT_VERIFIER_KEY_DIGEST}" \
  --expected-shape-digest "${ONE_HOT_SHAPE_DIGEST}" \
  --expected-statement-digest "${ONE_HOT_STATEMENT_DIGEST}" \
  --expected-public-inputs 1 \
  --require-terminal \
  "${one_hot_compressed_terminal_as_terminal_path}"
run_step python3 - "${one_hot_compressed_terminal_path}" "${one_hot_compressed_terminal_as_fold_path}" fold <<'PY'
import json
import sys
source, destination, proof_kind = sys.argv[1], sys.argv[2], sys.argv[3]
with open(source, "r", encoding="utf-8") as handle:
    artifact = json.load(handle)
artifact["proofKind"] = proof_kind
with open(destination, "w", encoding="utf-8") as handle:
    json.dump(artifact, handle, indent=2, sort_keys=True)
PY
run_expect_failure "${SUPERNEO_CLI}" verify \
  --key-seed "${ONE_HOT_KEY_SEED}" \
  --expected-verifier-key-digest "${ONE_HOT_VERIFIER_KEY_DIGEST}" \
  --expected-shape-digest "${ONE_HOT_SHAPE_DIGEST}" \
  --expected-statement-digest "${ONE_HOT_STATEMENT_DIGEST}" \
  --expected-public-inputs 1 \
  --require-terminal \
  "${one_hot_compressed_terminal_as_fold_path}"

run_step "${SUPERNEO_CLI}" prove \
  --seal numiseal \
  --numiseal-execution-policy zk-high-assurance-cpu \
  --bits 0,1 \
  --max-obligations-per-aggregate 32 \
  --output "${numiseal_product_path}"
run_step Scripts/validate-e2e-proof-metrics.py --generated-product-artifact "numiseal-product-smoke:${numiseal_product_path}"
run_step "${SUPERNEO_CLI}" inspect "${numiseal_product_path}"
run_expect_failure "${SUPERNEO_CLI}" verify "${numiseal_product_path}"
run_expect_failure "${SUPERNEO_CLI}" verify --require-terminal "${numiseal_product_path}"
run_step "${SUPERNEO_CLI}" verify --require-numiseal "${numiseal_product_path}"
run_expect_failure "${SUPERNEO_CLI}" verify \
  --require-numiseal \
  --expected-public-inputs 0 \
  "${numiseal_product_path}"

run_step "${SUPERNEO_CLI}" prove \
  --seal numiseal \
  --numiseal-zk-mode masked-digit-tensor-v1 \
  --numiseal-execution-policy zk-high-assurance-cpu \
  --bits 0,1 \
  --max-obligations-per-aggregate 32 \
  --output "${numiseal_zk_product_path}"
run_step Scripts/validate-e2e-proof-metrics.py --generated-product-artifact "numiseal-zk-product-smoke:${numiseal_zk_product_path}"
run_step "${SUPERNEO_CLI}" inspect "${numiseal_zk_product_path}"
run_step python3 - "${numiseal_zk_product_path}" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    artifact = json.load(handle)

assert artifact["proofKind"] == "numiseal-zk"
assert artifact["sealMode"] == "numiseal-zk-v1"
assert artifact["zkMode"] == "masked-digit-tensor-v1"
metadata = artifact["executionPolicyMetadata"]
assert metadata["numiSealProofKind"] == "numiseal-zk"
assert metadata["zkProofBodyVersion"] == "13"
assert metadata["zkMaskedResidualStatementVersion"] == "2"
assert metadata["zkMaskedResidualStatementCount"] == "1"
assert len(metadata["zkRandomnessSessionDigest"]) == 64
assert len(metadata["zkLeakageDigest"]) == 64
PY
run_expect_failure "${SUPERNEO_CLI}" verify "${numiseal_zk_product_path}"
run_expect_failure "${SUPERNEO_CLI}" verify --require-terminal "${numiseal_zk_product_path}"
run_step "${SUPERNEO_CLI}" verify --require-numiseal "${numiseal_zk_product_path}"
run_expect_failure "${SUPERNEO_CLI}" verify \
  --require-numiseal \
  --expected-public-inputs 0 \
  "${numiseal_zk_product_path}"

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

run_step "${SUPERNEO_CLI}" prove \
  --workload binary-add \
  --kind terminal \
  --operand-bits 8 \
  --lhs 13 \
  --rhs 29 \
  --output "${binary_add_terminal_path}"
run_step "${SUPERNEO_CLI}" verify \
  --key-seed "${BINARY_ADD_KEY_SEED}" \
  --expected-verifier-key-digest "${BINARY_ADD_VERIFIER_KEY_DIGEST}" \
  --expected-shape-digest "${BINARY_ADD_SHAPE_DIGEST}" \
  --expected-statement-digest "${BINARY_ADD_STATEMENT_DIGEST}" \
  --expected-public-inputs "${BINARY_ADD_PUBLIC_INPUTS}" \
  --require-terminal \
  "${binary_add_terminal_path}"

if [[ "${RUN_BENCHMARKS}" -eq 1 ]]; then
  run_step Scripts/run-benchmarks.sh quick
fi

echo
echo "Production gate passed."
