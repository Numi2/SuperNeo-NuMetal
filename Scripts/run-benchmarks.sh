#!/usr/bin/env bash
set -euo pipefail

PROFILE="${1:-quick}"
RESULT_DIR="benchmark-results"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULT_PATH="${ROOT_DIR}/${RESULT_DIR}"
BENCHMARK_RESULT_PATH="${ROOT_DIR}/Benchmarks/benchmark-results"
CURRENT_RUN="${RESULT_PATH}/Current_run.json"

mkdir -p "${RESULT_PATH}" "${BENCHMARK_RESULT_PATH}"
rm -f \
  "${CURRENT_RUN}" \
  "${RESULT_PATH}/results.json" \
  "${RESULT_PATH}/metadata.json" \
  "${RESULT_PATH}/report.md" \
  "${BENCHMARK_RESULT_PATH}/metadata.json" \
  "${BENCHMARK_RESULT_PATH}/report.md"

# XCTest-only package; skip Swift Testing harness (see Scripts/test-slice.sh).
swift test --disable-swift-testing

(cd "${ROOT_DIR}/Benchmarks" && \
  SUPERNEO_BENCHMARK_PROFILE="${PROFILE}" \
  swift package --disable-sandbox --allow-writing-to-package-directory benchmark \
    --target SuperNeoBenchmarks \
    run \
    --benchmark-build-configuration release \
    --metric wallClock \
    --metric mallocCountTotal \
    --metric memoryLeaked \
    --metric "GPU command buffer time" \
    --metric "Metal encode wall time" \
    --metric "Metal commit wall time" \
    --metric "Metal wait wall time" \
    --format jsonSmallerIsBetter \
    --path "${RESULT_PATH}" \
    --no-progress)

if [[ ! -s "${CURRENT_RUN}" ]]; then
  echo "benchmark run did not produce ${CURRENT_RUN}; refusing to render stale results" >&2
  exit 1
fi

mv "${CURRENT_RUN}" "${RESULT_PATH}/results.json"

for artifact in metadata.json report.md; do
  if [[ ! -s "${BENCHMARK_RESULT_PATH}/${artifact}" ]]; then
    echo "benchmark run did not produce Benchmarks/benchmark-results/${artifact}" >&2
    exit 1
  fi
  cp "${BENCHMARK_RESULT_PATH}/${artifact}" "${RESULT_PATH}/${artifact}"
done

swift "${ROOT_DIR}/Scripts/render-benchmark-report.swift" "${RESULT_PATH}/results.json" "${RESULT_PATH}/report.md"

if [[ -n "${SUPERNEO_BENCHMARK_BASELINE:-}" ]]; then
  COMPARE_ARGS=()
  BASELINE_METADATA="${SUPERNEO_BENCHMARK_BASELINE_METADATA:-}"
  if [[ -z "${BASELINE_METADATA}" ]]; then
    INFERRED_BASELINE_METADATA="$(cd "$(dirname "${SUPERNEO_BENCHMARK_BASELINE}")" && pwd)/metadata.json"
    if [[ -s "${INFERRED_BASELINE_METADATA}" ]]; then
      BASELINE_METADATA="${INFERRED_BASELINE_METADATA}"
    fi
  fi
  if [[ -n "${BASELINE_METADATA}" ]]; then
    COMPARE_ARGS+=(--baseline-metadata "${BASELINE_METADATA}" --candidate-metadata "${RESULT_PATH}/metadata.json")
  fi
  if [[ "${SUPERNEO_BENCHMARK_REQUIRE_METADATA:-}" == "1" ]]; then
    COMPARE_ARGS+=(--require-metadata)
  fi
  if [[ "${SUPERNEO_BENCHMARK_REQUIRE_CLEAN_METADATA:-}" == "1" ]]; then
    COMPARE_ARGS+=(--require-clean-metadata)
  fi
  if [[ -n "${SUPERNEO_BENCHMARK_KERNEL_THRESHOLD:-}" ]]; then
    COMPARE_ARGS+=(--kernel-threshold "${SUPERNEO_BENCHMARK_KERNEL_THRESHOLD}")
  fi
  if [[ -n "${SUPERNEO_BENCHMARK_PROTOCOL_THRESHOLD:-}" ]]; then
    COMPARE_ARGS+=(--protocol-threshold "${SUPERNEO_BENCHMARK_PROTOCOL_THRESHOLD}")
  fi
  if [[ "${SUPERNEO_BENCHMARK_COMPARE_WARN_ONLY:-}" == "1" ]]; then
    COMPARE_ARGS+=(--warn-only)
  fi
  if [[ "${SUPERNEO_BENCHMARK_COMPARE_ALLOW_MISSING:-}" == "1" ]]; then
    COMPARE_ARGS+=(--allow-missing)
  fi
  swift "${ROOT_DIR}/Scripts/compare-benchmark-results.swift" \
    "${SUPERNEO_BENCHMARK_BASELINE}" \
    "${RESULT_PATH}/results.json" \
    --output "${RESULT_PATH}/comparison.md" \
    "${COMPARE_ARGS[@]}"
fi
