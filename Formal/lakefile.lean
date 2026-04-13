import Lake
open Lake DSL

package «superneo-formal» where
  version := v!"0.1.0"

require mathlib from git
  "https://github.com/leanprover-community/mathlib4.git" @ "v4.26.0"

@[default_target]
lean_lib SuperNeoFormal where
  roots := #[`SuperNeoFormal]
