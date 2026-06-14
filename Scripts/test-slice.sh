#!/usr/bin/env bash
set -euo pipefail

# This package uses XCTest only. Disabling Swift Testing avoids SwiftPM spinning up
# the second harness. Override by passing --enable-swift-testing after the slice name.
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
  attack      verifier-negative/product mutation checks
  ce-opening  heavyweight CE opening relation/proof checks
  metal       Metal-vs-CPU differential kernel checks
  fast        algebra + shape; default inner-loop suite
  all         supported completion suite; excludes long proof/product gates
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
  attack|negative)
    filter='SuperNeo_NuMetalTests\.VerifierNegativeTests'
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
    filter='SuperNeo_NuMetalTests\.(AjtaiModuleSISBindingTests|AlgebraCoreTests|EvaluationCoreTests|PayPerBitProfileEvaluationTests|ProductCarryChainRootTests|ProtocolShapeTests)'
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
