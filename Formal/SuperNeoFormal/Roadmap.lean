import SuperNeoFormal.Ajtai

/-!
Named placeholders for the formal protocol milestones that are not yet claimed.

The documentation status manifest marks these theorem groups as `planned`, so
repository documentation must remain at "bounded formalization" until the named
groups are replaced by closed theorem statements and proofs.
-/

namespace SuperNeoFormal

structure PiDECMilestone where
  description : String

structure PiRLCMilestone where
  description : String

structure PiCCSMilestone where
  description : String

structure TerminalCEMilestone where
  description : String

structure SuperNeoCompositionMilestone where
  description : String

def pidecRecompositionPlanned : PiDECMilestone :=
  ⟨"PiDEC recomposition theorem for decomposed CE claims"⟩

def pirlcSoundnessPlanned : PiRLCMilestone :=
  ⟨"PiRLC random-linear-combination soundness assumptions"⟩

def piccsSumcheckPlanned : PiCCSMilestone :=
  ⟨"PiCCS and field-native sum-check soundness model"⟩

def terminalCERelationPlanned : TerminalCEMilestone :=
  ⟨"Terminal CE opening relation theorem"⟩

def superNeoCompositionPlanned : SuperNeoCompositionMilestone :=
  ⟨"Final verifier-acceptance composition theorem"⟩

end SuperNeoFormal
