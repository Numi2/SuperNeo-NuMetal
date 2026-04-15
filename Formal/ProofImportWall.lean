import Lean.Elab.ParseImportsFast
import Lean.Util.Path

/-!
Executable import wall for theorem-facing formal modules.

This gate keeps generated evidence, regression fixtures, and executable vector
checks out of the proof library.  The check is intentionally filesystem-based:
it scans the current package sources and fails if any protected module imports a
blocked evidence/check module.
-/

open Lean System System.FilePath

namespace ProofImportWall

private def blockedPrefixes : List Name := [
  `SuperNeoFormal.VectorChecks,
  `SuperNeoFormal.VectorFixtures,
  `SuperNeoFormal.Generated,
  `SuperNeoFormal.Golden,
  `SuperNeoFormal.Regression,
  `SuperNeoFormal.ExecutableChecks
]

private def nameStartsWith (pref name : Name) : Bool :=
  let prefixString := pref.toString
  let nameString := name.toString
  nameString == prefixString || (prefixString ++ ".").isPrefixOf nameString

private def isBlockedImport (moduleName : Name) : Bool :=
  blockedPrefixes.any fun pref => nameStartsWith pref moduleName

private def isProtectedModule (moduleName : Name) : Bool :=
  !isBlockedImport moduleName

private structure Violation where
  file : FilePath
  moduleName : Name
  imported : Name

private def scanFile (path : FilePath) : IO (List Violation) := do
  let moduleName ← moduleNameOfFileName path none
  if !isProtectedModule moduleName then
    return []
  let parsed ← Lean.parseImports' (← IO.FS.readFile path) path.toString
  let mut violations := []
  for imported in parsed.imports do
    if isBlockedImport imported.module then
      violations := {
        file := path
        moduleName := moduleName
        imported := imported.module
      } :: violations
  return violations.reverse

private def leanSourceFiles : IO (Array FilePath) := do
  let moduleFiles ← walkDir "SuperNeoFormal"
  return #[("SuperNeoFormal.lean" : FilePath)] ++
    moduleFiles.filter (fun path => path.extension == some "lean")

private def printViolation (violation : Violation) : IO Unit := do
  IO.eprintln
    s!"{violation.file}: module {violation.moduleName} imports blocked evidence/check module {violation.imported}"

end ProofImportWall

def main : IO Unit := do
  let files ← ProofImportWall.leanSourceFiles
  let mut violations := []
  for path in files do
    violations := violations ++ (← ProofImportWall.scanFile path)
  if violations.isEmpty then
    IO.println
      s!"proof_import_wall: scanned {files.size} Lean files; no protected module imports vector/check evidence"
  else
    for violation in violations do
      ProofImportWall.printViolation violation
    throw <| IO.userError
      s!"proof_import_wall failed with {violations.length} blocked import(s)"
