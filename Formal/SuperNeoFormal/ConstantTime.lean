import Mathlib

/-!
Constant-trace model for the implementation side-channel track.

This module does not claim that Swift, LLVM, Metal, a GPU driver, or a CPU
microarchitecture preserves these traces.  It gives the repository a checked
proof object for the part that can be stated inside Lean today: fixed operation
schedules have traces independent of secret values, and fixed schedules remain
independent under sequential composition.
-/

namespace SuperNeoFormal

inductive ConstantTimeStep where
  | load64
  | store64
  | add64
  | sub64
  | mul64
  | shift64
  | compare64
  | bitwise64
  | mask
  | select64
  | call
  | fixedLoop
  deriving DecidableEq, Repr

abbrev ConstantTimeTrace :=
  List ConstantTimeStep

def TraceIndependent {α : Type} (traceOf : α → ConstantTimeTrace) : Prop :=
  ∀ left right, traceOf left = traceOf right

structure ConstantTimeSchedule where
  steps : ConstantTimeTrace

def fixedScheduleTrace {α : Type} (schedule : ConstantTimeSchedule) (_secret : α) :
    ConstantTimeTrace :=
  schedule.steps

theorem fixedSchedule_traceIndependent {α : Type} (schedule : ConstantTimeSchedule) :
    TraceIndependent (fixedScheduleTrace (α := α) schedule) := by
  intro left right
  rfl

def seqTrace {α : Type} (lhs rhs : α → ConstantTimeTrace) (secret : α) :
    ConstantTimeTrace :=
  lhs secret ++ rhs secret

theorem seqTrace_independent {α : Type} {lhs rhs : α → ConstantTimeTrace}
    (hLhs : TraceIndependent lhs)
    (hRhs : TraceIndependent rhs) :
    TraceIndependent (seqTrace lhs rhs) := by
  intro left right
  simp [seqTrace, hLhs left right, hRhs left right]

def repeatedScheduleTrace {α : Type} (count : Nat) (body : ConstantTimeSchedule) (_secret : α) :
    ConstantTimeTrace :=
  List.flatten (List.replicate count body.steps)

theorem repeatedSchedule_traceIndependent {α : Type}
    (count : Nat)
    (body : ConstantTimeSchedule) :
    TraceIndependent (repeatedScheduleTrace (α := α) count body) := by
  intro left right
  rfl

def swiftGoldilocksAddSchedule : ConstantTimeSchedule where
  steps := [
    .load64, .load64, .add64, .compare64, .mask, .bitwise64,
    .add64, .compare64, .mask, .add64, .compare64, .mask,
    .sub64, .compare64, .mask, .select64, .store64
  ]

def swiftGoldilocksSubSchedule : ConstantTimeSchedule where
  steps := [
    .load64, .load64, .sub64, .compare64, .mask, .bitwise64,
    .add64, .store64
  ]

def swiftGoldilocksMulReductionSchedule : ConstantTimeSchedule where
  steps := [
    .load64, .load64, .mul64, .shift64, .bitwise64, .sub64,
    .compare64, .mask, .bitwise64, .sub64, .mul64, .add64,
    .compare64, .mask, .call, .sub64, .compare64, .mask,
    .select64, .store64
  ]

def swiftGoldilocksPow64Schedule : ConstantTimeSchedule where
  steps := .fixedLoop :: List.flatten (List.replicate 64 (
    swiftGoldilocksMulReductionSchedule.steps
      ++ swiftGoldilocksMulReductionSchedule.steps
      ++ [.compare64, .mask, .select64]
  ))

def metalGoldilocksCommonArithmeticSchedule : ConstantTimeSchedule where
  steps := [
    .load64, .load64, .add64, .sub64, .mul64, .shift64,
    .compare64, .mask, .select64, .bitwise64, .store64
  ]

def numiSealZKMaskKernelElementSchedule : ConstantTimeSchedule where
  steps := [
    .load64, .load64, .add64, .compare64, .mask, .select64,
    .mul64, .add64, .store64
  ]

abbrev WordPair :=
  Nat × Nat

theorem swiftGoldilocksAdd_traceIndependent :
    TraceIndependent (fixedScheduleTrace (α := WordPair) swiftGoldilocksAddSchedule) :=
  fixedSchedule_traceIndependent swiftGoldilocksAddSchedule

theorem swiftGoldilocksSub_traceIndependent :
    TraceIndependent (fixedScheduleTrace (α := WordPair) swiftGoldilocksSubSchedule) :=
  fixedSchedule_traceIndependent swiftGoldilocksSubSchedule

theorem swiftGoldilocksMulReduction_traceIndependent :
    TraceIndependent (fixedScheduleTrace (α := WordPair) swiftGoldilocksMulReductionSchedule) :=
  fixedSchedule_traceIndependent swiftGoldilocksMulReductionSchedule

theorem swiftGoldilocksPow64_traceIndependent :
    TraceIndependent (fixedScheduleTrace (α := WordPair) swiftGoldilocksPow64Schedule) :=
  fixedSchedule_traceIndependent swiftGoldilocksPow64Schedule

theorem metalGoldilocksCommonArithmetic_traceIndependent :
    TraceIndependent (fixedScheduleTrace (α := WordPair) metalGoldilocksCommonArithmeticSchedule) :=
  fixedSchedule_traceIndependent metalGoldilocksCommonArithmeticSchedule

theorem numiSealZKMaskKernelElement_traceIndependent :
    TraceIndependent (fixedScheduleTrace (α := WordPair) numiSealZKMaskKernelElementSchedule) :=
  fixedSchedule_traceIndependent numiSealZKMaskKernelElementSchedule

structure ConstantTimeSourceEvidence where
  sourceBranchFree : Prop
  publicScheduleFixed : Prop
  loweringPreservesTrace : Prop

def SourceRegionConstantTrace {α : Type}
    (evidence : ConstantTimeSourceEvidence)
    (schedule : ConstantTimeSchedule) : Prop :=
  evidence.sourceBranchFree
    ∧ evidence.publicScheduleFixed
    ∧ evidence.loweringPreservesTrace
    ∧ TraceIndependent (fixedScheduleTrace (α := α) schedule)

theorem sourceRegion_constantTrace_from_evidence {α : Type}
    (evidence : ConstantTimeSourceEvidence)
    (schedule : ConstantTimeSchedule)
    (hSource : evidence.sourceBranchFree)
    (hSchedule : evidence.publicScheduleFixed)
    (hLowering : evidence.loweringPreservesTrace) :
    SourceRegionConstantTrace (α := α) evidence schedule := by
  exact ⟨hSource, hSchedule, hLowering, fixedSchedule_traceIndependent schedule⟩

end SuperNeoFormal
