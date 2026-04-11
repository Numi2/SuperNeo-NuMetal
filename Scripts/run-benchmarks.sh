#!/usr/bin/env bash
set -euo pipefail

PROFILE="${1:-quick}"
RESULT_DIR="benchmark-results"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULT_PATH="${ROOT_DIR}/${RESULT_DIR}"

mkdir -p "${RESULT_PATH}"

# XCTest-only package; skip Swift Testing harness (see Scripts/test-slice.sh).
swift test --disable-swift-testing

SUPERNEO_BENCHMARK_PROFILE="${PROFILE}" \
(cd "${ROOT_DIR}/Benchmarks" && \
  swift package --disable-sandbox --allow-writing-to-package-directory benchmark \
    --target SuperNeoBenchmarks \
    run \
    --benchmark-build-configuration release \
    --metric wallClock \
    --metric mallocCountTotal \
    --metric memoryLeaked \
    --format jsonSmallerIsBetter \
    --path "${RESULT_PATH}" \
    --no-progress)

if [[ -f "${RESULT_PATH}/Current_run.json" ]]; then
  mv "${RESULT_PATH}/Current_run.json" "${RESULT_PATH}/results.json"
fi

swift "${ROOT_DIR}/Scripts/render-benchmark-report.swift" "${RESULT_PATH}/results.json" "${RESULT_PATH}/report.md"
