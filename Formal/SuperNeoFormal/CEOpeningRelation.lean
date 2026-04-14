import SuperNeoFormal.ConcreteAjtai
import SuperNeoFormal.TerminalCE

/-!
Local CE opening relation.

Swift's `CEOpeningRelation.verifyLocal` checks a public CE opening statement
against a witness by binding the profile, shape digest, verifier-key digest,
Ajtai commitment, public input, evaluation point, and matrix evaluations.  This
module formalizes that local relation algebraically.  It also connects terminal
CE statements to batches of local openings and proves witness uniqueness under
the same no-short-kernel assumption used for Ajtai binding.
-/

namespace SuperNeoFormal

variable {RF : Type} [CommRing RF]

structure CEOpeningPublicContext where
  profileID : Nat
  shapeDigest : Nat
  verifierKeyDigest : Nat
  deriving DecidableEq

structure CEOpeningShape where
  rows : Nat
  columns : Nat
  publicCount : Nat
  evalCount : Nat
  pointVars : Nat
  deriving DecidableEq

def CEOpeningShapeCompatible
    (shape : CEOpeningShape)
    (rows columns publicCount evalCount pointVars : Nat) : Prop :=
  shape.rows = rows ∧
    shape.columns = columns ∧
      shape.publicCount = publicCount ∧
        shape.evalCount = evalCount ∧
          shape.pointVars = pointVars

structure CELocalStatement
    (RF : Type) [CommRing RF]
    (rows publicCount evalCount pointVars : Nat) where
  context : CEOpeningPublicContext
  claim : EvaluationClaim RF rows publicCount evalCount pointVars

def CEPublicInputBounded {rows publicCount evalCount pointVars : Nat}
    (publicBound : RF → Prop)
    (statement : CELocalStatement RF rows publicCount evalCount pointVars) : Prop :=
  ∀ index, publicBound (statement.claim.publicInput index)

def CELocalOpeningRelation
    {rows columns publicCount evalCount pointVars : Nat}
    (shape : CEOpeningShape)
    (context : CEOpeningPublicContext)
    (A : AjtaiMatrix RF rows columns)
    (bounded : Message RF columns → Prop)
    (publicBound : RF → Prop)
    (evaluationRelation :
      Message RF columns →
        ProtocolVector RF pointVars →
        ProtocolVector RF evalCount →
        Prop)
    (statement : CELocalStatement RF rows publicCount evalCount pointVars)
    (witness : Message RF columns) : Prop :=
  CEOpeningShapeCompatible shape rows columns publicCount evalCount pointVars ∧
    statement.context = context ∧
      CEPublicInputBounded publicBound statement ∧
        ClaimOpening A bounded evaluationRelation statement.claim witness

theorem ceLocalOpening_shape_compatible
    {rows columns publicCount evalCount pointVars : Nat}
    {shape : CEOpeningShape}
    {context : CEOpeningPublicContext}
    {A : AjtaiMatrix RF rows columns}
    {bounded : Message RF columns → Prop}
    {publicBound : RF → Prop}
    {evaluationRelation :
      Message RF columns →
        ProtocolVector RF pointVars →
        ProtocolVector RF evalCount →
        Prop}
    {statement : CELocalStatement RF rows publicCount evalCount pointVars}
    {witness : Message RF columns}
    (hOpening :
      CELocalOpeningRelation
        shape context A bounded publicBound evaluationRelation statement witness) :
    CEOpeningShapeCompatible shape rows columns publicCount evalCount pointVars :=
  hOpening.1

theorem ceLocalOpening_context_eq
    {rows columns publicCount evalCount pointVars : Nat}
    {shape : CEOpeningShape}
    {context : CEOpeningPublicContext}
    {A : AjtaiMatrix RF rows columns}
    {bounded : Message RF columns → Prop}
    {publicBound : RF → Prop}
    {evaluationRelation :
      Message RF columns →
        ProtocolVector RF pointVars →
        ProtocolVector RF evalCount →
        Prop}
    {statement : CELocalStatement RF rows publicCount evalCount pointVars}
    {witness : Message RF columns}
    (hOpening :
      CELocalOpeningRelation
        shape context A bounded publicBound evaluationRelation statement witness) :
    statement.context = context :=
  hOpening.2.1

theorem ceLocalOpening_publicInput_bounded
    {rows columns publicCount evalCount pointVars : Nat}
    {shape : CEOpeningShape}
    {context : CEOpeningPublicContext}
    {A : AjtaiMatrix RF rows columns}
    {bounded : Message RF columns → Prop}
    {publicBound : RF → Prop}
    {evaluationRelation :
      Message RF columns →
        ProtocolVector RF pointVars →
        ProtocolVector RF evalCount →
        Prop}
    {statement : CELocalStatement RF rows publicCount evalCount pointVars}
    {witness : Message RF columns}
    (hOpening :
      CELocalOpeningRelation
        shape context A bounded publicBound evaluationRelation statement witness) :
    CEPublicInputBounded publicBound statement :=
  hOpening.2.2.1

theorem ceLocalOpening_claimOpening
    {rows columns publicCount evalCount pointVars : Nat}
    {shape : CEOpeningShape}
    {context : CEOpeningPublicContext}
    {A : AjtaiMatrix RF rows columns}
    {bounded : Message RF columns → Prop}
    {publicBound : RF → Prop}
    {evaluationRelation :
      Message RF columns →
        ProtocolVector RF pointVars →
        ProtocolVector RF evalCount →
        Prop}
    {statement : CELocalStatement RF rows publicCount evalCount pointVars}
    {witness : Message RF columns}
    (hOpening :
      CELocalOpeningRelation
        shape context A bounded publicBound evaluationRelation statement witness) :
    ClaimOpening A bounded evaluationRelation statement.claim witness :=
  hOpening.2.2.2

theorem ceLocalOpening_commitment
    {rows columns publicCount evalCount pointVars : Nat}
    {shape : CEOpeningShape}
    {context : CEOpeningPublicContext}
    {A : AjtaiMatrix RF rows columns}
    {bounded : Message RF columns → Prop}
    {publicBound : RF → Prop}
    {evaluationRelation :
      Message RF columns →
        ProtocolVector RF pointVars →
        ProtocolVector RF evalCount →
        Prop}
    {statement : CELocalStatement RF rows publicCount evalCount pointVars}
    {witness : Message RF columns}
    (hOpening :
      CELocalOpeningRelation
        shape context A bounded publicBound evaluationRelation statement witness) :
    commit A witness = statement.claim.commitment :=
  (ceLocalOpening_claimOpening hOpening).2.1

theorem ceLocalOpening_evaluation
    {rows columns publicCount evalCount pointVars : Nat}
    {shape : CEOpeningShape}
    {context : CEOpeningPublicContext}
    {A : AjtaiMatrix RF rows columns}
    {bounded : Message RF columns → Prop}
    {publicBound : RF → Prop}
    {evaluationRelation :
      Message RF columns →
        ProtocolVector RF pointVars →
        ProtocolVector RF evalCount →
        Prop}
    {statement : CELocalStatement RF rows publicCount evalCount pointVars}
    {witness : Message RF columns}
    (hOpening :
      CELocalOpeningRelation
        shape context A bounded publicBound evaluationRelation statement witness) :
    evaluationRelation witness statement.claim.point statement.claim.evaluations :=
  (ceLocalOpening_claimOpening hOpening).2.2

theorem ceLocalOpening_witness_unique_from_noShortKernel
    {rows columns publicCount evalCount pointVars : Nat}
    {shape : CEOpeningShape}
    {context : CEOpeningPublicContext}
    {A : AjtaiMatrix RF rows columns}
    {bounded : Message RF columns → Prop}
    {publicBound : RF → Prop}
    {evaluationRelation :
      Message RF columns →
        ProtocolVector RF pointVars →
        ProtocolVector RF evalCount →
        Prop}
    {statement : CELocalStatement RF rows publicCount evalCount pointVars}
    {lhs rhs : Message RF columns}
    (hKernel : NoShortKernel A bounded)
    (hlhs :
      CELocalOpeningRelation
        shape context A bounded publicBound evaluationRelation statement lhs)
    (hrhs :
      CELocalOpeningRelation
        shape context A bounded publicBound evaluationRelation statement rhs) :
    lhs = rhs := by
  apply opening_messages_equal_from_noShortKernel hKernel
  · exact ⟨(ceLocalOpening_claimOpening hlhs).1, (ceLocalOpening_claimOpening hlhs).2.1⟩
  · exact ⟨(ceLocalOpening_claimOpening hrhs).1, (ceLocalOpening_claimOpening hrhs).2.1⟩

abbrev CETerminalStatement
    (RF : Type) [CommRing RF]
    (count rows publicCount evalCount pointVars : Nat) :=
  TerminalCEStatement (CELocalStatement RF rows publicCount evalCount pointVars) count

def ceTerminalOutputClaims
    {count rows publicCount evalCount pointVars : Nat}
    (statement : CETerminalStatement RF count rows publicCount evalCount pointVars) :
    Fin count → EvaluationClaim RF rows publicCount evalCount pointVars :=
  fun index => (statement.outputClaim index).claim

def CETerminalLocalBatchRelation
    {count rows columns publicCount evalCount pointVars : Nat}
    (shape : CEOpeningShape)
    (context : CEOpeningPublicContext)
    (A : AjtaiMatrix RF rows columns)
    (bounded : Message RF columns → Prop)
    (publicBound : RF → Prop)
    (evaluationRelation :
      Message RF columns →
        ProtocolVector RF pointVars →
        ProtocolVector RF evalCount →
        Prop)
    (statement : CETerminalStatement RF count rows publicCount evalCount pointVars)
    (witnesses : Fin count → Message RF columns) : Prop :=
  ∀ index,
    CELocalOpeningRelation
      shape context A bounded publicBound evaluationRelation
      (statement.outputClaim index)
      (witnesses index)

theorem ceTerminalLocalBatch_iff_terminalLocalBatchRelation
    {count rows columns publicCount evalCount pointVars : Nat}
    {shape : CEOpeningShape}
    {context : CEOpeningPublicContext}
    {A : AjtaiMatrix RF rows columns}
    {bounded : Message RF columns → Prop}
    {publicBound : RF → Prop}
    {evaluationRelation :
      Message RF columns →
        ProtocolVector RF pointVars →
        ProtocolVector RF evalCount →
        Prop}
    {statement : CETerminalStatement RF count rows publicCount evalCount pointVars}
    {witnesses : Fin count → Message RF columns} :
    CETerminalLocalBatchRelation
      shape context A bounded publicBound evaluationRelation statement witnesses ↔
      TerminalLocalBatchRelation statement witnesses
        (CELocalOpeningRelation
          shape context A bounded publicBound evaluationRelation) := by
  rfl

theorem ceTerminalLocalBatch_claimOpening
    {count rows columns publicCount evalCount pointVars : Nat}
    {shape : CEOpeningShape}
    {context : CEOpeningPublicContext}
    {A : AjtaiMatrix RF rows columns}
    {bounded : Message RF columns → Prop}
    {publicBound : RF → Prop}
    {evaluationRelation :
      Message RF columns →
        ProtocolVector RF pointVars →
        ProtocolVector RF evalCount →
        Prop}
    {statement : CETerminalStatement RF count rows publicCount evalCount pointVars}
    {witnesses : Fin count → Message RF columns}
    (hBatch :
      CETerminalLocalBatchRelation
        shape context A bounded publicBound evaluationRelation statement witnesses)
    (index : Fin count) :
    ClaimOpening
      A bounded evaluationRelation
      ((ceTerminalOutputClaims statement) index)
      (witnesses index) :=
  ceLocalOpening_claimOpening (hBatch index)

theorem ceTerminalLocalBatch_shape_compatible
    {count rows columns publicCount evalCount pointVars : Nat}
    {shape : CEOpeningShape}
    {context : CEOpeningPublicContext}
    {A : AjtaiMatrix RF rows columns}
    {bounded : Message RF columns → Prop}
    {publicBound : RF → Prop}
    {evaluationRelation :
      Message RF columns →
        ProtocolVector RF pointVars →
        ProtocolVector RF evalCount →
        Prop}
    {statement : CETerminalStatement RF count rows publicCount evalCount pointVars}
    {witnesses : Fin count → Message RF columns}
    (hBatch :
      CETerminalLocalBatchRelation
        shape context A bounded publicBound evaluationRelation statement witnesses)
    (index : Fin count) :
    CEOpeningShapeCompatible shape rows columns publicCount evalCount pointVars :=
  ceLocalOpening_shape_compatible (hBatch index)

theorem ceTerminalLocalBatch_context_eq
    {count rows columns publicCount evalCount pointVars : Nat}
    {shape : CEOpeningShape}
    {context : CEOpeningPublicContext}
    {A : AjtaiMatrix RF rows columns}
    {bounded : Message RF columns → Prop}
    {publicBound : RF → Prop}
    {evaluationRelation :
      Message RF columns →
        ProtocolVector RF pointVars →
        ProtocolVector RF evalCount →
        Prop}
    {statement : CETerminalStatement RF count rows publicCount evalCount pointVars}
    {witnesses : Fin count → Message RF columns}
    (hBatch :
      CETerminalLocalBatchRelation
        shape context A bounded publicBound evaluationRelation statement witnesses)
    (index : Fin count) :
    (statement.outputClaim index).context = context :=
  ceLocalOpening_context_eq (hBatch index)

theorem ceTerminalLocalBatch_publicInput_bounded
    {count rows columns publicCount evalCount pointVars : Nat}
    {shape : CEOpeningShape}
    {context : CEOpeningPublicContext}
    {A : AjtaiMatrix RF rows columns}
    {bounded : Message RF columns → Prop}
    {publicBound : RF → Prop}
    {evaluationRelation :
      Message RF columns →
        ProtocolVector RF pointVars →
        ProtocolVector RF evalCount →
        Prop}
    {statement : CETerminalStatement RF count rows publicCount evalCount pointVars}
    {witnesses : Fin count → Message RF columns}
    (hBatch :
      CETerminalLocalBatchRelation
        shape context A bounded publicBound evaluationRelation statement witnesses)
    (index : Fin count) :
    CEPublicInputBounded publicBound (statement.outputClaim index) :=
  ceLocalOpening_publicInput_bounded (hBatch index)

theorem ceTerminalLocalBatch_commitment
    {count rows columns publicCount evalCount pointVars : Nat}
    {shape : CEOpeningShape}
    {context : CEOpeningPublicContext}
    {A : AjtaiMatrix RF rows columns}
    {bounded : Message RF columns → Prop}
    {publicBound : RF → Prop}
    {evaluationRelation :
      Message RF columns →
        ProtocolVector RF pointVars →
        ProtocolVector RF evalCount →
        Prop}
    {statement : CETerminalStatement RF count rows publicCount evalCount pointVars}
    {witnesses : Fin count → Message RF columns}
    (hBatch :
      CETerminalLocalBatchRelation
        shape context A bounded publicBound evaluationRelation statement witnesses)
    (index : Fin count) :
    commit A (witnesses index) =
      ((ceTerminalOutputClaims statement) index).commitment :=
  (ceTerminalLocalBatch_claimOpening hBatch index).2.1

theorem ceTerminalLocalBatch_evaluation
    {count rows columns publicCount evalCount pointVars : Nat}
    {shape : CEOpeningShape}
    {context : CEOpeningPublicContext}
    {A : AjtaiMatrix RF rows columns}
    {bounded : Message RF columns → Prop}
    {publicBound : RF → Prop}
    {evaluationRelation :
      Message RF columns →
        ProtocolVector RF pointVars →
        ProtocolVector RF evalCount →
        Prop}
    {statement : CETerminalStatement RF count rows publicCount evalCount pointVars}
    {witnesses : Fin count → Message RF columns}
    (hBatch :
      CETerminalLocalBatchRelation
        shape context A bounded publicBound evaluationRelation statement witnesses)
    (index : Fin count) :
    evaluationRelation
      (witnesses index)
      ((ceTerminalOutputClaims statement) index).point
      ((ceTerminalOutputClaims statement) index).evaluations :=
  (ceTerminalLocalBatch_claimOpening hBatch index).2.2

theorem ceTerminalLocalBatch_witnesses_unique_from_noShortKernel
    {count rows columns publicCount evalCount pointVars : Nat}
    {shape : CEOpeningShape}
    {context : CEOpeningPublicContext}
    {A : AjtaiMatrix RF rows columns}
    {bounded : Message RF columns → Prop}
    {publicBound : RF → Prop}
    {evaluationRelation :
      Message RF columns →
        ProtocolVector RF pointVars →
        ProtocolVector RF evalCount →
        Prop}
    {statement : CETerminalStatement RF count rows publicCount evalCount pointVars}
    {lhs rhs : Fin count → Message RF columns}
    (hKernel : NoShortKernel A bounded)
    (hlhs :
      CETerminalLocalBatchRelation
        shape context A bounded publicBound evaluationRelation statement lhs)
    (hrhs :
      CETerminalLocalBatchRelation
        shape context A bounded publicBound evaluationRelation statement rhs) :
    lhs = rhs := by
  funext index
  exact ceLocalOpening_witness_unique_from_noShortKernel
    hKernel (hlhs index) (hrhs index)

def CETerminalDecompositionCount (count : Nat) : Prop :=
  count = decompositionLength

theorem ceTerminalDecompositionCount_profile :
    CETerminalDecompositionCount decompositionLength := by
  rfl

abbrev ConcreteCEOpeningShape :=
  CEOpeningShape

def concreteCEOpeningShape
    (columns publicCount evalCount pointVars : Nat) :
    ConcreteCEOpeningShape where
  rows := kappa
  columns := columns
  publicCount := publicCount
  evalCount := evalCount
  pointVars := pointVars

theorem concreteCEOpeningShape_rows
    (columns publicCount evalCount pointVars : Nat) :
    (concreteCEOpeningShape columns publicCount evalCount pointVars).rows = kappa :=
  rfl

theorem concreteCEOpeningShape_compatible
    (columns publicCount evalCount pointVars : Nat) :
    CEOpeningShapeCompatible
      (concreteCEOpeningShape columns publicCount evalCount pointVars)
      kappa columns publicCount evalCount pointVars := by
  simp [CEOpeningShapeCompatible, concreteCEOpeningShape]

end SuperNeoFormal
