import Mathlib
import Mathlib.NumberTheory.LucasPrimality
import SuperNeoFormal.Profile

/-!
Concrete Goldilocks field profile.

The Swift implementation uses the prime

`p = 0xFFFF_FFFF_0000_0001 = 2^64 - 2^32 + 1`.

This module fixes the Lean field to `ZMod p` and proves primality with a compact
Lucas certificate instead of relying on trial-division based `norm_num`
primality search.
-/

namespace SuperNeoFormal

abbrev Goldilocks := ZMod goldilocksModulus

theorem goldilocksModulus_hex :
    goldilocksModulus = 0xFFFF_FFFF_0000_0001 := by
  native_decide

theorem goldilocksModulus_shape :
    goldilocksModulus = 2 ^ 64 - 2 ^ 32 + 1 := by
  native_decide

theorem goldilocksModulus_minus_one_factorization :
    goldilocksModulus - 1 = 2 ^ 32 * 3 * 5 * 17 * 257 * 65537 := by
  native_decide

theorem goldilocksModulus_minus_one_primeFactors :
    (goldilocksModulus - 1).primeFactors =
      ({2, 3, 5, 17, 257, 65537} : Finset Nat) := by
  native_decide

theorem goldilocksLucasWitness_pow_full :
    (7 : ZMod goldilocksModulus) ^ (goldilocksModulus - 1) = 1 := by
  native_decide

theorem goldilocksLucasWitness_pow_div_two :
    (7 : ZMod goldilocksModulus) ^ ((goldilocksModulus - 1) / 2) ≠ 1 := by
  native_decide

theorem goldilocksLucasWitness_pow_div_three :
    (7 : ZMod goldilocksModulus) ^ ((goldilocksModulus - 1) / 3) ≠ 1 := by
  native_decide

theorem goldilocksLucasWitness_pow_div_five :
    (7 : ZMod goldilocksModulus) ^ ((goldilocksModulus - 1) / 5) ≠ 1 := by
  native_decide

theorem goldilocksLucasWitness_pow_div_seventeen :
    (7 : ZMod goldilocksModulus) ^ ((goldilocksModulus - 1) / 17) ≠ 1 := by
  native_decide

theorem goldilocksLucasWitness_pow_div_257 :
    (7 : ZMod goldilocksModulus) ^ ((goldilocksModulus - 1) / 257) ≠ 1 := by
  native_decide

theorem goldilocksLucasWitness_pow_div_65537 :
    (7 : ZMod goldilocksModulus) ^ ((goldilocksModulus - 1) / 65537) ≠ 1 := by
  native_decide

theorem goldilocksModulus_prime : Nat.Prime goldilocksModulus := by
  apply lucas_primality goldilocksModulus (7 : ZMod goldilocksModulus)
  · exact goldilocksLucasWitness_pow_full
  · intro q hq hqDiv
    have hMinusOneNonzero : goldilocksModulus - 1 ≠ 0 := by
      native_decide
    have hqMem : q ∈ (goldilocksModulus - 1).primeFactors := by
      exact Nat.mem_primeFactors.mpr ⟨hq, hqDiv, hMinusOneNonzero⟩
    rw [goldilocksModulus_minus_one_primeFactors] at hqMem
    have hqCases :
        q = 2 ∨ q = 3 ∨ q = 5 ∨ q = 17 ∨ q = 257 ∨ q = 65537 := by
      simpa using hqMem
    rcases hqCases with rfl | rfl | rfl | rfl | rfl | rfl
    · exact goldilocksLucasWitness_pow_div_two
    · exact goldilocksLucasWitness_pow_div_three
    · exact goldilocksLucasWitness_pow_div_five
    · exact goldilocksLucasWitness_pow_div_seventeen
    · exact goldilocksLucasWitness_pow_div_257
    · exact goldilocksLucasWitness_pow_div_65537

instance goldilocksPrimeFact : Fact (Nat.Prime goldilocksModulus) :=
  ⟨goldilocksModulus_prime⟩

example : Field Goldilocks := inferInstance

theorem goldilocks_char :
    ringChar Goldilocks = goldilocksModulus := by
  exact ZMod.ringChar_zmod_n goldilocksModulus

def goldilocksCanonicalValue (x : Goldilocks) : Nat :=
  x.val

def goldilocksCenteredNorm (x : Goldilocks) : Nat :=
  min x.val (goldilocksModulus - x.val)

theorem goldilocksCanonicalValue_lt_modulus (x : Goldilocks) :
    goldilocksCanonicalValue x < goldilocksModulus := by
  exact x.2

theorem goldilocksCenteredNorm_le_halfish (x : Goldilocks) :
    goldilocksCenteredNorm x ≤ goldilocksModulus - x.val := by
  exact Nat.min_le_right _ _

theorem goldilocksCenteredNorm_le_value (x : Goldilocks) :
    goldilocksCenteredNorm x ≤ x.val := by
  exact Nat.min_le_left _ _

end SuperNeoFormal
