import SuperNeoFormal.ModuleSIS

/-!
Ajtai commitments specialized to the concrete Phi81 module.

The generic `Ajtai.lean` lemmas remain the algebraic engine.  This file fixes
the implemented ring and row count, and ties field-witness packing to the
concrete commitment shape used by Swift.
-/

noncomputable section

namespace SuperNeoFormal

open Finset

abbrev ConcreteAjtaiMessage (columns : Nat) :=
  Message Phi81 columns

abbrev ConcreteAjtaiMatrix (columns : Nat) :=
  AjtaiMatrix Phi81 kappa columns

abbrev ConcreteAjtaiCommitment :=
  Commitment Phi81 kappa

abbrev ConcreteFieldWitness (columns : Nat) :=
  FieldVector (columns * phi81Degree)

def concretePackedWitness {columns : Nat}
    (fieldWitness : ConcreteFieldWitness columns) : ConcreteAjtaiMessage columns :=
  packExactPhi81 fieldWitness

def concreteCommit {columns : Nat}
    (A : ConcreteAjtaiMatrix columns)
    (message : ConcreteAjtaiMessage columns) : ConcreteAjtaiCommitment :=
  commit A message

def concreteCommitPackedFieldWitness {columns : Nat}
    (A : ConcreteAjtaiMatrix columns)
    (fieldWitness : ConcreteFieldWitness columns) : ConcreteAjtaiCommitment :=
  concreteCommit A (concretePackedWitness fieldWitness)

def ConcreteOpening {columns : Nat}
    (A : ConcreteAjtaiMatrix columns)
    (c : ConcreteAjtaiCommitment)
    (bounded : ConcreteAjtaiMessage columns → Prop)
    (z : ConcreteAjtaiMessage columns) : Prop :=
  Opening A c bounded z

def ConcreteBindingSecure {columns : Nat}
    (A : ConcreteAjtaiMatrix columns)
    (bounded : ConcreteAjtaiMessage columns → Prop) : Prop :=
  BindingSecure A bounded

theorem concreteOpening_iff_opening {columns : Nat}
    (A : ConcreteAjtaiMatrix columns)
    (c : ConcreteAjtaiCommitment)
    (bounded : ConcreteAjtaiMessage columns → Prop)
    (z : ConcreteAjtaiMessage columns) :
    ConcreteOpening A c bounded z ↔ Opening A c bounded z :=
  Iff.rfl

theorem concreteBindingSecure_iff_bindingSecure {columns : Nat}
    (A : ConcreteAjtaiMatrix columns)
    (bounded : ConcreteAjtaiMessage columns → Prop) :
    ConcreteBindingSecure A bounded ↔ BindingSecure A bounded :=
  Iff.rfl

theorem moduleSISNoShortKernel_iff_concreteBindingSecure {columns : Nat}
    (A : ConcreteAjtaiMatrix columns)
    (bounded : ConcreteAjtaiMessage columns → Prop) :
    ModuleSISNoShortKernel A bounded ↔ ConcreteBindingSecure A bounded := by
  rw [moduleSISNoShortKernel_is_concrete_noShortKernel,
    concreteBindingSecure_iff_bindingSecure]
  exact noShortKernel_iff_bindingSecure

theorem concreteAjtai_row_count :
    kappa = 18 := by
  native_decide

theorem concreteAjtai_ring_degree :
    phi81Degree = 54 := by
  native_decide

theorem concreteAjtai_coefficient_dimension :
    kappa * phi81Degree = 972 := by
  native_decide

theorem concreteAjtai_phi81_relation :
    phi81X ^ 54 + phi81X ^ 27 + 1 = 0 :=
  phi81_relation

theorem concreteAjtai_phi81_swiftMul_toQuotient
    (lhs rhs : Phi81Coefficients) :
    phi81CoeffsToQuotient (phi81SwiftMulCoeffs lhs rhs) =
      phi81CoeffsToQuotient lhs * phi81CoeffsToQuotient rhs :=
  phi81SwiftMulCoeffs_toQuotient_mul lhs rhs

theorem concretePackedWitness_shape {columns : Nat}
    (fieldWitness : ConcreteFieldWitness columns) :
    concretePackedWitness fieldWitness = packExactPhi81 fieldWitness := rfl

theorem concretePackedWitness_column_eq {columns : Nat}
    (fieldWitness : ConcreteFieldWitness columns)
    (column : Fin columns) :
    concretePackedWitness fieldWitness column = packExactPhi81 fieldWitness column := rfl

theorem concreteCommit_eq_abstract {columns : Nat}
    (A : ConcreteAjtaiMatrix columns)
    (message : ConcreteAjtaiMessage columns) :
    concreteCommit A message = commit A message := rfl

theorem concreteCommit_row_eq_sum {columns : Nat}
    (A : ConcreteAjtaiMatrix columns)
    (message : ConcreteAjtaiMessage columns)
    (row : Fin kappa) :
    concreteCommit A message row =
      ∑ column : Fin columns, A row column * message column := rfl

theorem concreteCommit_zero {columns : Nat}
    (A : ConcreteAjtaiMatrix columns) :
    concreteCommit A (0 : ConcreteAjtaiMessage columns) = 0 := by
  exact commit_zero A

theorem concreteCommit_add {columns : Nat}
    (A : ConcreteAjtaiMatrix columns)
    (lhs rhs : ConcreteAjtaiMessage columns) :
    concreteCommit A (lhs + rhs) = concreteCommit A lhs + concreteCommit A rhs := by
  exact commit_add A lhs rhs

theorem concreteCommit_sub {columns : Nat}
    (A : ConcreteAjtaiMatrix columns)
    (lhs rhs : ConcreteAjtaiMessage columns) :
    concreteCommit A (lhs - rhs) = concreteCommit A lhs - concreteCommit A rhs := by
  exact commit_sub A lhs rhs

theorem concreteBinding_from_moduleSISNoShortKernel {columns : Nat}
    {A : ConcreteAjtaiMatrix columns}
    {bounded : ConcreteAjtaiMessage columns → Prop}
    {lhs rhs : ConcreteAjtaiMessage columns}
    (hKernel : ModuleSISNoShortKernel A bounded)
    (hlhs : bounded lhs)
    (hrhs : bounded rhs)
    (hCommit : concreteCommit A lhs = concreteCommit A rhs) :
    lhs = rhs := by
  exact binding_from_noShortKernel hKernel hlhs hrhs hCommit

theorem concreteBindingSecure_from_moduleSISNoShortKernel {columns : Nat}
    {A : ConcreteAjtaiMatrix columns}
    {bounded : ConcreteAjtaiMessage columns → Prop}
    (hKernel : ModuleSISNoShortKernel A bounded) :
    ConcreteBindingSecure A bounded := by
  exact bindingSecure_from_noShortKernel hKernel

theorem concreteCommitPackedFieldWitness_eq {columns : Nat}
    (A : ConcreteAjtaiMatrix columns)
    (fieldWitness : ConcreteFieldWitness columns) :
    concreteCommitPackedFieldWitness A fieldWitness =
      commit A (packExactPhi81 fieldWitness) := rfl

theorem concreteCommitPackedFieldWitness_row_eq_sum {columns : Nat}
    (A : ConcreteAjtaiMatrix columns)
    (fieldWitness : ConcreteFieldWitness columns)
    (row : Fin kappa) :
    concreteCommitPackedFieldWitness A fieldWitness row =
      ∑ column : Fin columns, A row column * packExactPhi81 fieldWitness column := rfl

end SuperNeoFormal
