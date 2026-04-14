# Binary Addition Terminal Vector, 2026-04-14

This pass closes the remaining terminal-vector coverage gap for the bundled
binary-addition workload. It does not change the SuperNeo relation,
Fiat-Shamir transcript, proof-envelope format, Ajtai parameters, workload
semantics, or verifier acceptance rules.

## Finding

The repository had checked-in fold vectors for one-hot and binary-addition
workloads, plus a checked-in terminal vector for one-hot. Binary addition still
relied on release-gate smoke coverage for terminal proofs, so
cross-implementation consumers did not have a stable complete-proof artifact for
the second workload.

## Work

- Added `TestVectors/binary-addition-u8-terminal-v1.json`, generated through the
  real CLI terminal path:

```sh
swift run superneo prove \
  --workload binary-add \
  --kind terminal \
  --operand-bits 8 \
  --lhs 13 \
  --rhs 29 \
  --key-seed SuperNeoCLI.binary-addition.u8.v1 \
  --output TestVectors/binary-addition-u8-terminal-v1.json
```

- Added the vector to `TestVectors/manifest.json` with SHA-256 hash, byte count,
  workload, proof kind, trusted public inputs, key seed, shape digest, statement
  digest, verifier-key digest, and strict verification command.
- Updated test-vector, CLI, roadmap, README, and reproduction-harness docs so the
  binary-addition terminal vector is part of the public compatibility surface.
- Extended the production gate with a positive binary-addition terminal
  prove/verify smoke under `--require-terminal`.

## Vector Boundary

The generated artifact has:

- SHA-256:
  `0aba7ce02e01c7cfaa2b234bf9da5a8ed0623a923b64834fc085bd75c9ae085c`
- byte count: `8302264`
- proof envelope bytes: `6165078`
- proof envelope kind: `terminalLocal`

Terminal vectors are intentionally large. The manifest hash and byte count are
the compatibility boundary; digest changes should be treated as a serialization,
transcript, normalization, or parameter compatibility event.

## Validation

Run after this pass:

```sh
swift run superneo verify --key-seed SuperNeoCLI.binary-addition.u8.v1 --expected-verifier-key-digest 199bec9fea21d192f741e81896029d07743b9a8b793543751ea1605fe2a8e973 --expected-shape-digest 8ff5c76dd2bad49eb2b4de4272f3c7ce3d27e28c21f3a5c4d39083a884fb3089 --expected-statement-digest 109b394b315f9b846e13ceb1f00ee0b374ff459334425a5b1063a8db554551a9 --expected-public-inputs 1,0,1,0,1,0,1,0,0,0 --require-terminal TestVectors/binary-addition-u8-terminal-v1.json
swift Scripts/validate-test-vectors.swift
Scripts/test-slice.sh fast
Scripts/production-gate.sh --skip-formal
```
