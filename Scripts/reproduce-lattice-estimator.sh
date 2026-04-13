#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: Scripts/reproduce-lattice-estimator.sh [--dry-run] [output-json]

Runs the SuperNeo Goldilocks/Phi81 Module-SIS profile through a pinned checkout
of the upstream lattice-estimator. A full run requires SageMath because the
estimator package depends on Sage.

Options:
  --dry-run  Write the exact derived parameters and formulas without importing
             or running lattice-estimator.

Environment:
  LATTICE_ESTIMATOR_COMMIT  Override pinned estimator commit.
  LATTICE_ESTIMATOR_DIR     Use an existing checkout instead of cloning.
  SUPERNEO_ESTIMATOR_CACHE  Directory for cloned estimator sources.
USAGE
}

DRY_RUN=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      break
      ;;
  esac
done

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PINNED_COMMIT="${LATTICE_ESTIMATOR_COMMIT:-8d38f52c0bcc46f23d697c9c592bad50df0b124b}"
OUTPUT="${1:-${ROOT_DIR}/lattice-estimator-results/superneo-goldilocks-phi81.json}"
ESTIMATOR_REPO="https://github.com/malb/lattice-estimator.git"
CACHE_ROOT="${SUPERNEO_ESTIMATOR_CACHE:-${ROOT_DIR}/.external/lattice-estimator}"
ESTIMATOR_DIR="${LATTICE_ESTIMATOR_DIR:-${CACHE_ROOT}/${PINNED_COMMIT}}"

if [[ "${DRY_RUN}" -eq 1 ]]; then
  python3 "${ROOT_DIR}/Scripts/reproduce-lattice-estimator.py" \
    --dry-run \
    --estimator-repo "${ESTIMATOR_REPO}" \
    --estimator-commit "${PINNED_COMMIT}" \
    --output "${OUTPUT}"
  echo "wrote ${OUTPUT}"
  exit 0
fi

if ! command -v sage >/dev/null 2>&1; then
  cat >&2 <<'ERROR'
SageMath is required for a full lattice-estimator reproduction.
Install SageMath, or run with --dry-run to emit the exact parameter artifact
without claiming that the estimator was executed.
ERROR
  exit 69
fi

if [[ -n "${LATTICE_ESTIMATOR_DIR:-}" ]]; then
  if [[ ! -d "${ESTIMATOR_DIR}/.git" ]]; then
    echo "LATTICE_ESTIMATOR_DIR must point at a lattice-estimator git checkout" >&2
    exit 65
  fi
else
  if [[ ! -d "${ESTIMATOR_DIR}/.git" ]]; then
    mkdir -p "${CACHE_ROOT}"
    git clone "${ESTIMATOR_REPO}" "${ESTIMATOR_DIR}"
  fi
  git -C "${ESTIMATOR_DIR}" fetch --quiet origin "${PINNED_COMMIT}"
  git -C "${ESTIMATOR_DIR}" checkout --quiet --detach "${PINNED_COMMIT}"
fi

ACTUAL_COMMIT="$(git -C "${ESTIMATOR_DIR}" rev-parse HEAD)"
if [[ "${ACTUAL_COMMIT}" != "${PINNED_COMMIT}" ]]; then
  echo "lattice-estimator checkout is ${ACTUAL_COMMIT}, expected ${PINNED_COMMIT}" >&2
  exit 65
fi

sage -python "${ROOT_DIR}/Scripts/reproduce-lattice-estimator.py" \
  --estimator-dir "${ESTIMATOR_DIR}" \
  --estimator-repo "${ESTIMATOR_REPO}" \
  --estimator-commit "${PINNED_COMMIT}" \
  --output "${OUTPUT}"

echo "wrote ${OUTPUT}"
