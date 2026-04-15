import SuperNeoFormal.VectorChecks

open SuperNeoFormal.VectorChecks

private def printCheck (check : CheckCase) (ok : Bool) : IO Unit := do
  let status := if ok then "ok" else "FAIL"
  IO.println s!"{check.label}={status}"

def main : IO Unit := do
  let mut failures := []
  for check in checks do
    let ok := check.run ()
    printCheck check ok
    if !ok then
      failures := check.label :: failures
  if failures.isEmpty then
    IO.println s!"vector_check: {checks.length} checks passed"
  else
    for label in failures.reverse do
      IO.eprintln s!"vector_check failure: {label}"
    throw <| IO.userError s!"vector_check failed with {failures.length} failure(s)"
