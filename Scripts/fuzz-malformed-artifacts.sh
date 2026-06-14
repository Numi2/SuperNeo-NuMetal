#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CASES="${SUPERNEO_FUZZ_CASES:-24}"

usage() {
  cat <<'USAGE'
Usage: Scripts/fuzz-malformed-artifacts.sh [case-count]

Generate a tiny valid fold artifact, mutate its JSON and embedded proof envelope,
and require every mutant to be rejected by `superneo verify`.

This is attack tooling, not a release gate.
USAGE
}

if [[ $# -gt 0 ]]; then
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    *)
      CASES="$1"
      ;;
  esac
fi

case "${CASES}" in
  ''|*[!0-9]*)
    usage >&2
    exit 64
    ;;
esac

cd "${ROOT_DIR}"

work_dir="$(mktemp -d "${TMPDIR:-/tmp}/superneo-fuzz.XXXXXX")"
cleanup() {
  rm -rf "${work_dir}"
}
trap cleanup EXIT

seed="${work_dir}/seed.json"

echo "==> generating seed artifact"
swift run superneo prove \
  --workload one-hot \
  --bits 0,1 \
  --output "${seed}" >/dev/null

echo "==> verifying seed artifact"
swift run superneo verify "${seed}" >/dev/null

echo "==> mutating ${CASES} artifacts"
python3 - "${seed}" "${work_dir}" "${CASES}" <<'PY'
import base64
import json
import pathlib
import sys

seed_path = pathlib.Path(sys.argv[1])
out_dir = pathlib.Path(sys.argv[2])
case_count = int(sys.argv[3])

artifact = json.loads(seed_path.read_text(encoding="utf-8"))

def write_case(index, label, value):
    path = out_dir / f"mutant-{index:03d}-{label}.json"
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return path

def clone():
    return json.loads(json.dumps(artifact))

mutants = []

case = clone()
case["publicInputs"] = [0]
mutants.append(("public-input", case))

case = clone()
case["expectedSelectedCount"] = 0
mutants.append(("selected-count", case))

case = clone()
case["shapeDigestHex"] = "00" * 32
mutants.append(("shape-digest", case))

case = clone()
case["statementDigestHex"] = "11" * 32
mutants.append(("statement-digest", case))

case = clone()
case["verifierKeyDigestHex"] = "22" * 32
mutants.append(("verifier-key-digest", case))

case = clone()
case["proofKind"] = "compressed-terminal"
mutants.append(("proof-kind", case))

case = clone()
case["profile"] = "Goldilocks/Phi81(d=53)"
mutants.append(("profile", case))

case = clone()
case["decompositionProfile"] = "legacy-fixed"
mutants.append(("decomposition-profile", case))

case = clone()
case["proofEnvelopeBase64"] = case["proofEnvelopeBase64"][:-1] + "!"
mutants.append(("bad-base64", case))

envelope = bytearray(base64.b64decode(artifact["proofEnvelopeBase64"]))
if len(envelope) < 32:
    raise SystemExit("seed proof envelope unexpectedly short")

for offset in [0, 4, 5, 7, 12, 31, len(envelope) // 2, len(envelope) - 1]:
    case = clone()
    mutated = bytearray(envelope)
    mutated[offset] ^= 0x01
    case["proofEnvelopeBase64"] = base64.b64encode(mutated).decode("ascii")
    mutants.append((f"envelope-byte-{offset}", case))

for length in [0, 1, 8, 32, len(envelope) - 1]:
    case = clone()
    case["proofEnvelopeBase64"] = base64.b64encode(envelope[:length]).decode("ascii")
    mutants.append((f"envelope-truncate-{length}", case))

case = clone()
case["proofEnvelopeBase64"] = base64.b64encode(envelope + b"\x00").decode("ascii")
mutants.append(("envelope-trailing-byte", case))

case = clone()
case["workloadParameters"] = {"selectedCount": "2"}
mutants.append(("workload-parameters", case))

case = clone()
case.pop("proofEnvelopeBase64")
mutants.append(("missing-envelope", case))

written = []
for index, (label, value) in enumerate(mutants[:case_count]):
    written.append(str(write_case(index, label, value)))

manifest = out_dir / "mutants.txt"
manifest.write_text("\n".join(written) + "\n", encoding="utf-8")
print(manifest)
PY

manifest="${work_dir}/mutants.txt"
accepted=0
rejected=0

while IFS= read -r mutant; do
  if swift run superneo verify "${mutant}" >"${mutant}.out" 2>&1; then
    echo "ACCEPTED MUTANT: ${mutant}" >&2
    cat "${mutant}.out" >&2
    accepted=$((accepted + 1))
  else
    rejected=$((rejected + 1))
  fi
done <"${manifest}"

if [[ "${accepted}" -ne 0 ]]; then
  echo "Malformed artifact fuzzing failed: ${accepted} mutant(s) accepted, ${rejected} rejected." >&2
  exit 1
fi

echo "Malformed artifact fuzzing passed: ${rejected} mutant(s) rejected."
