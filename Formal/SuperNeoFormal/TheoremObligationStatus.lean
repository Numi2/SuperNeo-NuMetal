/-!
Explicit status markers for theorem-surface obligations.

Upper security files are allowed to remain evidence-parametric, but every
imported obligation should expose whether it is instantiated by lower Lean
mathematics or still an external/interface assumption.
-/

namespace SuperNeoFormal

inductive TheoremObligationStatus where
  | instantiated
  | notInstantiated
  deriving DecidableEq, Repr

def TheoremObligationStatus.Accepted
    (status : TheoremObligationStatus) : Prop :=
  status = TheoremObligationStatus.instantiated

def TheoremObligationStatus.Pending
    (status : TheoremObligationStatus) : Prop :=
  status = TheoremObligationStatus.notInstantiated

end SuperNeoFormal
