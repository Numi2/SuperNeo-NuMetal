#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
  cat <<'USAGE'
Usage: Scripts/check-release-candidate.sh

Runs the repository release-candidate gate:
  - package build
  - CLI smoke prove/verify
  - malformed-artifact fuzzing
  - verifier-negative attack slice
  - supported completion slice
  - product-control, side-channel, replay, and revenue regression tests

This is a local release-candidate gate. It does not replace independent
cryptographic review, hosted replay/QRO service validation, or production
distribution signing review.
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
run_step Scripts/test-slice.sh all
run_step swift test --disable-swift-testing --filter 'SuperNeo_NuMetalTests\.NumiSealCanonicalizationTests/test(LocalProductControlsVerifySignedNumiSealZKContextProvenanceReplayAndAudit|NumiSealZKSideChannelCertificateIsOptionalAndBindingChecked|ProductOperationsStatusBlocksNumiSealZKWithoutDefaultProductionCertificate|RevenueLogicEmitsBillableEventOnlyForAcceptedNumiSealZKProductAudit|RevocationFeedRejectsZeroLengthValidityWindow|TrustedProductContextRejectsNonNumiSealZKProofKinds)'

echo
echo "Release-candidate gate passed."
