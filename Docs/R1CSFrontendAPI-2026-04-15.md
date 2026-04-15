# R1CS Frontend API - 2026-04-15

This pass adds a small public frontend boundary for hand-authored R1CS
programs.

## Implemented

- `SuperNeoR1CSAssignment` carries public input and private witness vectors as a
  single generated assignment.
- `SuperNeoR1CSWitnessGenerator<Input>` provides a reusable witness-generation
  interface for application inputs.
- `SuperNeoR1CSProgram<Input>` binds a hand-authored `SuperNeoR1CSBuilder` to a
  witness generator.
- `SuperNeoR1CSProvingStack.prove` runs:

  ```text
  R1CS assignment -> witness validation -> CCS structure -> normalization
  -> Ajtai commitment key/commitments -> fold/terminal envelope
  ```

- The proof facade supports explicit `foldReduction`, `terminalLocal`, and
  `compressedPublic` envelope kinds.
- `verifyTerminalProof` verifies terminal or compressed-terminal proof bytes
  through `SuperNeoTerminalProofAcceptancePolicy`.
- `reduceFoldProof` exposes the non-product fold-reduction path separately and
  preserves the rule that reductions still require terminal CE verification.

## Non-Claims

- This is not a compiler from general programs to R1CS/CCS.
- The witness generator is an application hook, not a trusted runtime or
  side-channel boundary.
- Fold-reduction envelopes remain non-terminal. The high-level terminal verifier
  rejects them before reduction verification.

## Validation

Targeted validation:

```sh
swift test --filter UsabilitySurfaceTests
```

The new tests cover terminal proof generation and policy verification, explicit
fold-reduction handling, terminal rejection of fold-only envelopes, and
fail-closed rejection of unsatisfied generated witnesses.
