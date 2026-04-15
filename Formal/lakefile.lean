import Lake
open Lake DSL

package «superneo-formal» where
  version := v!"0.1.0"

require mathlib from git
  "https://github.com/leanprover-community/mathlib4.git" @ "v4.26.0"

@[default_target]
lean_lib SuperNeoFormal where
  roots := #[`SuperNeoFormal]

lean_exe proof_import_wall where
  root := `ProofImportWall

target vector_check pkg : Unit := do
  let lean ← getLean
  let env ← getAugmentedEnv
  Job.async do
    proc {
      cmd := lean.toString
      args := #["--run", "SuperNeoFormalVectorCheck.lean"]
      cwd := some pkg.dir
      env
    }
