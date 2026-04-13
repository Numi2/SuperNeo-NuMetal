import SuperNeoFormal.Ajtai

/-!
Abstract PiDEC recomposition layer.

The Swift verifier checks PiDEC by recomposing each public surface from
`decompositionLength` output claims with scalar powers of the norm bound:
commitments, packed public inputs, and evaluations must match the folded claim.

This module captures the commitment side of that recomposition over the same
abstract commutative ring model used by `Ajtai.lean`. By itself it does not claim
PiRLC, PiCCS, terminal CE, or full SuperNeo composition soundness.
-/

namespace SuperNeoFormal

open Finset

variable {RF : Type} [CommRing RF]

def pidecScalarPower {count : Nat} (base : RF) (index : Fin count) : RF :=
  base ^ index.val

def pidecWeightedSum {count : Nat} (base : RF) (parts : Fin count → RF) : RF :=
  ∑ index : Fin count, pidecScalarPower base index * parts index

def pidecWeightedMessage {count columns : Nat}
    (base : RF)
    (parts : Fin count → Message RF columns) : Message RF columns :=
  fun col => pidecWeightedSum base (fun index => parts index col)

def pidecWeightedCommitment {count rows : Nat}
    (base : RF)
    (parts : Fin count → Commitment RF rows) : Commitment RF rows :=
  fun row => pidecWeightedSum base (fun index => parts index row)

theorem pidecWeightedSum_eq_sum {count : Nat}
    (base : RF)
    (parts : Fin count → RF) :
    pidecWeightedSum base parts =
      ∑ index : Fin count, (base ^ index.val) * parts index := by
  rfl

theorem commit_pidecWeightedMessage {rows columns count : Nat}
    (A : AjtaiMatrix RF rows columns)
    (base : RF)
    (parts : Fin count → Message RF columns) :
    commit A (pidecWeightedMessage base parts) =
      pidecWeightedCommitment base (fun index => commit A (parts index)) := by
  funext row
  have hInner : ∀ index : Fin count,
      (∑ col : Fin columns,
        A row col * (pidecScalarPower base index * parts index col)) =
        pidecScalarPower base index * (∑ col : Fin columns, A row col * parts index col) := by
    intro index
    rw [Finset.mul_sum]
    apply Finset.sum_congr rfl
    intro col _
    ring
  calc
    commit A (pidecWeightedMessage base parts) row
        = ∑ col : Fin columns, ∑ index : Fin count,
            A row col * (pidecScalarPower base index * parts index col) := by
          simp [commit, pidecWeightedMessage, pidecWeightedSum, Finset.mul_sum]
    _ = ∑ index : Fin count, ∑ col : Fin columns,
            A row col * (pidecScalarPower base index * parts index col) := by
          rw [Finset.sum_comm]
    _ = pidecWeightedCommitment base (fun index => commit A (parts index)) row := by
          simp [commit, pidecWeightedCommitment, pidecWeightedSum, hInner]

theorem pidec_commitment_recomposition {rows columns count : Nat}
    {A : AjtaiMatrix RF rows columns}
    {base : RF}
    {limbs : Fin count → Message RF columns}
    {folded : Message RF columns}
    (hFolded : folded = pidecWeightedMessage base limbs) :
    commit A folded =
      pidecWeightedCommitment base (fun index => commit A (limbs index)) := by
  subst folded
  exact commit_pidecWeightedMessage A base limbs

theorem pidec_opening_recomposition {rows columns count : Nat}
    {A : AjtaiMatrix RF rows columns}
    {base : RF}
    {limbs : Fin count → Message RF columns}
    {folded : Message RF columns}
    {c : Commitment RF rows}
    {bounded : Message RF columns → Prop}
    (hFolded : folded = pidecWeightedMessage base limbs)
    (hBounded : bounded folded)
    (hCommitment : c = pidecWeightedCommitment base (fun index => commit A (limbs index))) :
    Opening A c bounded folded := by
  constructor
  · exact hBounded
  · rw [hCommitment, pidec_commitment_recomposition hFolded]

end SuperNeoFormal
