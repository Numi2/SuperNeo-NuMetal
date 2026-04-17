import Mathlib.Data.Finset.Card
import Mathlib.Tactic

/-!
Tagged product bad-event ledger.

The product theorem layer has several routes to the same underlying failure
event.  This module records those events by a shared tag and charges the union
of tags, not the flat sum of every place the event was mentioned.
-/

namespace SuperNeoFormal

open Finset

inductive ProductBadEventSource where
  | fold
  | terminal
  | product
  | carry
  | zk
  | transcript
  deriving DecidableEq, Fintype

structure ProductBadEventLedger (Tag : Type) [DecidableEq Tag] where
  fold : Finset Tag
  terminal : Finset Tag
  product : Finset Tag
  carry : Finset Tag
  zk : Finset Tag
  transcript : Finset Tag

namespace ProductBadEventLedger

variable {Tag : Type} [DecidableEq Tag]

def tagsForSource
    (ledger : ProductBadEventLedger Tag) :
    ProductBadEventSource → Finset Tag
  | .fold => ledger.fold
  | .terminal => ledger.terminal
  | .product => ledger.product
  | .carry => ledger.carry
  | .zk => ledger.zk
  | .transcript => ledger.transcript

def aggregate (ledger : ProductBadEventLedger Tag) : Finset Tag :=
  (((((ledger.fold ∪ ledger.terminal) ∪ ledger.product) ∪ ledger.carry) ∪
    ledger.zk) ∪ ledger.transcript)

def flatCharge (ledger : ProductBadEventLedger Tag) : Nat :=
  ledger.fold.card +
    ledger.terminal.card +
    ledger.product.card +
    ledger.carry.card +
    ledger.zk.card +
    ledger.transcript.card

theorem mem_aggregate_iff
    (ledger : ProductBadEventLedger Tag)
    (tag : Tag) :
    tag ∈ ledger.aggregate ↔
      tag ∈ ledger.fold ∨
        tag ∈ ledger.terminal ∨
        tag ∈ ledger.product ∨
        tag ∈ ledger.carry ∨
        tag ∈ ledger.zk ∨
        tag ∈ ledger.transcript := by
  constructor
  · intro hTag
    simp [aggregate] at hTag
    tauto
  · intro hTag
    simp [aggregate]
    tauto

theorem sum_sources_eq_flatCharge
    (ledger : ProductBadEventLedger Tag) :
    (∑ source : ProductBadEventSource, (ledger.tagsForSource source).card) =
      ledger.flatCharge := by
  rw [show (univ : Finset ProductBadEventSource) =
      { ProductBadEventSource.fold,
        ProductBadEventSource.terminal,
        ProductBadEventSource.product,
        ProductBadEventSource.carry,
        ProductBadEventSource.zk,
        ProductBadEventSource.transcript } by
    ext source
    cases source <;> simp]
  simp [flatCharge, tagsForSource]
  omega

theorem aggregate_card_le_flatCharge
    (ledger : ProductBadEventLedger Tag) :
    ledger.aggregate.card ≤ ledger.flatCharge := by
  let foldTags := ledger.fold
  let terminalTags := ledger.terminal
  let productTags := ledger.product
  let carryTags := ledger.carry
  let zkTags := ledger.zk
  let transcriptTags := ledger.transcript
  have hAB := card_union_le foldTags terminalTags
  have hABC := card_union_le (foldTags ∪ terminalTags) productTags
  have hABCD := card_union_le ((foldTags ∪ terminalTags) ∪ productTags) carryTags
  have hABCDE :=
    card_union_le (((foldTags ∪ terminalTags) ∪ productTags) ∪ carryTags) zkTags
  have hABCDEF :=
    card_union_le
      ((((foldTags ∪ terminalTags) ∪ productTags) ∪ carryTags) ∪ zkTags)
      transcriptTags
  rw [aggregate, flatCharge]
  change
    (((((foldTags ∪ terminalTags) ∪ productTags) ∪ carryTags) ∪ zkTags) ∪
      transcriptTags).card ≤
        foldTags.card +
          terminalTags.card +
          productTags.card +
          carryTags.card +
          zkTags.card +
          transcriptTags.card
  omega

theorem aggregate_card_le_sum_sources
    (ledger : ProductBadEventLedger Tag) :
    ledger.aggregate.card ≤
      ∑ source : ProductBadEventSource, (ledger.tagsForSource source).card := by
  have hFlat := aggregate_card_le_flatCharge ledger
  simpa [sum_sources_eq_flatCharge] using hFlat

theorem source_subset_aggregate
    (ledger : ProductBadEventLedger Tag)
    (source : ProductBadEventSource) :
    ledger.tagsForSource source ⊆ ledger.aggregate := by
  intro tag hTag
  rw [mem_aggregate_iff]
  cases source <;> simp [tagsForSource] at hTag ⊢ <;> tauto

theorem shared_tag_charged_once
    (ledger : ProductBadEventLedger Tag)
    {tag : Tag}
    (hFold : tag ∈ ledger.fold)
    (_hCarry : tag ∈ ledger.carry) :
    tag ∈ ledger.aggregate ∧
      ({tag} : Finset Tag).card = 1 := by
  exact ⟨
    (source_subset_aggregate ledger .fold) hFold,
    by simp
  ⟩

end ProductBadEventLedger

end SuperNeoFormal
