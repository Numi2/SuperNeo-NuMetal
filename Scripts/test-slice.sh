#!/usr/bin/env bash
set -euo pipefail

# This package uses XCTest only. Disabling Swift Testing avoids SwiftPM spinning up
# the second harness (and makes `swift test` match what `Scripts/test-slice.sh` runs).
# Override by passing --enable-swift-testing after the slice name.
#
# If a second `swift test` appears stuck: SwiftPM serializes access to `.build` and
# waits for the other process ("Another instance of SwiftPM is already running").
SWIFT_TEST_BASE=(swift test --disable-swift-testing)

usage() {
  cat <<'USAGE'
Usage: Scripts/test-slice.sh <slice> [swift test args...]

Slices:
  algebra     deterministic field, ring, and multilinear checks
  commitment  Ajtai commitment corpus
  evaluation  multilinear evaluation corpus
  shape       transcript, matrix, CCS shape, serialization, digest checks
  protocol    fold verification and adversarial proof checks
  ce-opening  heavyweight CE opening relation/proof checks
  metal       Metal-vs-CPU differential kernel checks
  fast        algebra + shape; default inner-loop suite
  all         full swift test suite
  list        list available XCTest cases
USAGE
}

slice="${1:-fast}"
if [[ $# -gt 0 ]]; then
  shift
fi

case "$slice" in
  algebra)
    filter='SuperNeo_NuMetalTests\.(AlgebraCoreTests|EvaluationCoreTests)'
    ;;
  commitment)
    filter='SuperNeo_NuMetalTests\.CommitmentCoreTests'
    ;;
  evaluation)
    filter='SuperNeo_NuMetalTests\.EvaluationCoreTests'
    ;;
  shape)
    filter='SuperNeo_NuMetalTests\.ProtocolShapeTests'
    ;;
  protocol|e2e)
    filter='SuperNeo_NuMetalTests\.(ProtocolSmokeTests|ProtocolE2ETests)'
    ;;
  ce-opening|opening)
    filter='SuperNeo_NuMetalTests\.CEOpeningProtocolTests'
    ;;
  metal|gpu)
    filter='SuperNeo_NuMetalTests\.MetalDifferentialTests'
    ;;
  fast)
    filter='SuperNeo_NuMetalTests\.(AlgebraCoreTests|EvaluationCoreTests|ProtocolShapeTests)'
    ;;
  all)
    echo "Running full XCTest suite (fold proofs are CPU-heavy; expect on the order of a minute before completion)." >&2
    exec "${SWIFT_TEST_BASE[@]}" "$@"
    ;;
  list)
    exec "${SWIFT_TEST_BASE[@]}" list "$@"
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

exec "${SWIFT_TEST_BASE[@]}" --filter "$filter" "$@"
