#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: Scripts/reproduce-lattice-estimator.sh [--dry-run | --full] [--pinned] [--latest] [output-json]

Runs the SuperNeo Goldilocks/Phi81 Module-SIS profile through the upstream
lattice-estimator. Dry-run mode is Sage-free and records the exact translated
SIS.Parameters tuple. Full mode requires SageMath.

Lanes:
  --pinned  Run the canonical docs-facing pinned commit lane.
  --latest  Run a latest-upstream monitoring lane. This is drift evidence only.

If --full is used without a lane, --pinned is selected. For compatibility,
omitting both --dry-run and --full also runs --full --pinned.

Options:
  --dry-run  Write the exact derived parameters without importing or running
             lattice-estimator.
  --full     Run selected estimator lane(s) through SageMath.
  --pinned   Select the pinned reproduction lane.
  --latest   Select latest-upstream drift monitoring.

Environment:
  LATTICE_ESTIMATOR_COMMIT  Override pinned estimator commit.
  LATTICE_ESTIMATOR_DIR     Use an existing checkout for the pinned lane.
  SUPERNEO_ESTIMATOR_CACHE  Directory for cloned estimator sources.
USAGE
}

MODE=""
RUN_PINNED=0
RUN_LATEST=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      MODE="dry-run"
      shift
      ;;
    --full)
      MODE="full"
      shift
      ;;
    --pinned)
      RUN_PINNED=1
      shift
      ;;
    --latest)
      RUN_LATEST=1
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
PINNED_DIR="${LATTICE_ESTIMATOR_DIR:-${CACHE_ROOT}/${PINNED_COMMIT}}"

if [[ -z "${MODE}" ]]; then
  MODE="full"
fi
if [[ "${MODE}" == "full" && "${RUN_PINNED}" -eq 0 && "${RUN_LATEST}" -eq 0 ]]; then
  RUN_PINNED=1
fi
if [[ "${MODE}" == "dry-run" && ("${RUN_PINNED}" -eq 1 || "${RUN_LATEST}" -eq 1) ]]; then
  echo "--dry-run cannot be combined with --pinned or --latest" >&2
  exit 64
fi

checkout_estimator() {
  local commit="$1"
  local dir="$2"
  local explicit_dir="${3:-0}"

  if [[ "${explicit_dir}" -eq 1 ]]; then
    if [[ ! -d "${dir}/.git" ]]; then
      echo "LATTICE_ESTIMATOR_DIR must point at a lattice-estimator git checkout" >&2
      exit 65
    fi
  else
    if [[ ! -d "${dir}/.git" ]]; then
      mkdir -p "${CACHE_ROOT}"
      git clone "${ESTIMATOR_REPO}" "${dir}"
    fi
    git -C "${dir}" fetch --quiet origin "${commit}"
    git -C "${dir}" checkout --quiet --detach "${commit}"
  fi

  local actual_commit
  actual_commit="$(git -C "${dir}" rev-parse HEAD)"
  if [[ "${actual_commit}" != "${commit}" ]]; then
    echo "lattice-estimator checkout is ${actual_commit}, expected ${commit}" >&2
    exit 65
  fi
}

if [[ "${MODE}" == "dry-run" ]]; then
  python3 "${ROOT_DIR}/Scripts/reproduce-lattice-estimator.py" \
    --dry-run \
    --estimator-repo "${ESTIMATOR_REPO}" \
    --pinned-commit "${PINNED_COMMIT}" \
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

PY_ARGS=(
  --estimator-repo "${ESTIMATOR_REPO}"
  --pinned-commit "${PINNED_COMMIT}"
  --sage-version "$(sage --version 2>&1 | head -n 1)"
  --output "${OUTPUT}"
)

if [[ "${RUN_PINNED}" -eq 1 ]]; then
  checkout_estimator "${PINNED_COMMIT}" "${PINNED_DIR}" "$([[ -n "${LATTICE_ESTIMATOR_DIR:-}" ]] && echo 1 || echo 0)"
  PY_ARGS+=(--run-pinned --pinned-estimator-dir "${PINNED_DIR}")
fi

if [[ "${RUN_LATEST}" -eq 1 ]]; then
  LATEST_COMMIT="$(git ls-remote "${ESTIMATOR_REPO}" HEAD | awk '{print $1}')"
  if [[ -z "${LATEST_COMMIT}" ]]; then
    echo "failed to resolve latest lattice-estimator HEAD" >&2
    exit 69
  fi
  LATEST_DIR="${CACHE_ROOT}/${LATEST_COMMIT}"
  checkout_estimator "${LATEST_COMMIT}" "${LATEST_DIR}" 0
  PY_ARGS+=(--run-latest --latest-commit "${LATEST_COMMIT}" --latest-estimator-dir "${LATEST_DIR}")
fi

sage -python "${ROOT_DIR}/Scripts/reproduce-lattice-estimator.py" "${PY_ARGS[@]}"

echo "wrote ${OUTPUT}"
