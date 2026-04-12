#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: Scripts/reproduce-superneo-paper.sh <mode> [output-dir]

Modes:
  plan      Generate claim-map, pinned commands, and report skeleton only.
  snapshot  Render the current benchmark-results/ directory without rerunning benchmarks.
  quick     Run quick benchmark profile and render a reproduction artifact.
  scaling   Run scaling benchmark profile and render a reproduction artifact.
  full      Run full benchmark profile and render a reproduction artifact.

Outputs are written under paper-reproduction/ by default.
USAGE
}

MODE="${1:-plan}"
if [[ $# -gt 0 ]]; then
  shift
fi

case "${MODE}" in
  plan|snapshot|quick|scaling|full)
    ;;
  -h|--help|help)
    usage
    exit 0
    ;;
  *)
    usage >&2
    exit 64
    ;;
esac

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUTPUT_DIR="${1:-${ROOT_DIR}/paper-reproduction/${TIMESTAMP}-${MODE}}"
LOG_DIR="${OUTPUT_DIR}/logs"
BENCHMARK_OUT="${OUTPUT_DIR}/benchmark-results"
VECTOR_OUT="${OUTPUT_DIR}/test-vectors"

mkdir -p "${LOG_DIR}" "${BENCHMARK_OUT}" "${VECTOR_OUT}"

run_and_log() {
  local name="$1"
  shift
  printf '+ %q' "$@" > "${LOG_DIR}/${name}.txt"
  printf '\n' >> "${LOG_DIR}/${name}.txt"
  (cd "${ROOT_DIR}" && "$@") 2>&1 | tee -a "${LOG_DIR}/${name}.txt"
}

capture_environment() {
  {
    echo "# Environment"
    echo
    echo "Generated: ${TIMESTAMP}"
    echo "Mode: ${MODE}"
    echo "Root: ${ROOT_DIR}"
    echo
    echo "## Git"
    git -C "${ROOT_DIR}" rev-parse HEAD || true
    git -C "${ROOT_DIR}" status --short || true
    echo
    echo "## Swift"
    swift --version || true
    echo
    echo "## macOS"
    sw_vers || true
    echo
    echo "## Hardware"
    system_profiler SPHardwareDataType SPDisplaysDataType || true
  } > "${OUTPUT_DIR}/environment.txt" 2>&1
}

copy_vectors() {
  cp "${ROOT_DIR}/TestVectors/README.md" "${VECTOR_OUT}/README.md"
  cp "${ROOT_DIR}/TestVectors/manifest.json" "${VECTOR_OUT}/manifest.json"
  cp "${ROOT_DIR}/TestVectors/artifact.schema.json" "${VECTOR_OUT}/artifact.schema.json"
  cp "${ROOT_DIR}"/TestVectors/*-v1.json "${VECTOR_OUT}/"
}

copy_benchmark_results() {
  if [[ -f "${ROOT_DIR}/benchmark-results/results.json" ]]; then
    cp "${ROOT_DIR}/benchmark-results/results.json" "${BENCHMARK_OUT}/results.json"
  fi
  if [[ -f "${ROOT_DIR}/benchmark-results/metadata.json" ]]; then
    cp "${ROOT_DIR}/benchmark-results/metadata.json" "${BENCHMARK_OUT}/metadata.json"
  fi
  if [[ -f "${ROOT_DIR}/benchmark-results/report.md" ]]; then
    cp "${ROOT_DIR}/benchmark-results/report.md" "${BENCHMARK_OUT}/report.md"
  fi
}

capture_environment
copy_vectors

case "${MODE}" in
  plan)
    ;;
  snapshot)
    copy_benchmark_results
    ;;
  quick|scaling|full)
    run_and_log parameter-profile swift test --disable-swift-testing --filter ProtocolShapeTests/testGoldilocksParameterProfileMatchesPaperProfile
    run_and_log usability swift test --disable-swift-testing --filter UsabilitySurfaceTests
    run_and_log golden-vector-verify swift run superneo verify TestVectors/one-hot-vector-fold-v1.json
    run_and_log binary-addition-vector-verify swift run superneo verify TestVectors/binary-addition-u8-fold-v1.json
    run_and_log golden-vector-inspect swift run superneo inspect TestVectors/one-hot-vector-fold-v1.json
    run_and_log binary-addition-vector-inspect swift run superneo inspect TestVectors/binary-addition-u8-fold-v1.json
    run_and_log test-vector-validation swift Scripts/validate-test-vectors.swift
    run_and_log fast Scripts/test-slice.sh fast
    run_and_log protocol Scripts/test-slice.sh protocol
    run_and_log metal Scripts/test-slice.sh metal
    run_and_log benchmark Scripts/run-benchmarks.sh "${MODE}"
    copy_benchmark_results
    ;;
esac

if ! swift "${ROOT_DIR}/Scripts/render-paper-reproduction.swift" "${OUTPUT_DIR}" "${MODE}" > "${LOG_DIR}/render.txt" 2>&1; then
  cat "${LOG_DIR}/render.txt" >&2
  exit 1
fi

echo "wrote ${OUTPUT_DIR}"
