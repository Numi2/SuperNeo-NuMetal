#!/usr/bin/env python3
"""Validate finite-protocol selected-budget obstruction evidence."""

from __future__ import annotations

import json
import math
import sys
from fractions import Fraction
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "TestVectors" / "product-finite-protocol-loss-obstruction-v1.json"

EXPECTED_TOP_LEVEL_KEYS = {
    "schemaVersion",
    "evidenceID",
    "claimStatus",
    "relatedManifests",
    "formalSurface",
    "selectedProfile",
    "selectedBudget",
    "pirlcNumericGap",
    "piccsNumericGap",
    "terminalCENumericGap",
    "ledgerDecision",
}

EXPECTED_MANIFESTS = {
    "productCryptoSecurityDossier": "TestVectors/product-crypto-security-dossier-v1.json",
    "selectedDepthLossAccounting": "TestVectors/product-selected-depth-loss-accounting-v1.json",
    "productTotalLossBudget": "TestVectors/product-total-loss-budget-v1.json",
    "productQROMInteractiveReduction": "TestVectors/product-qrom-interactive-reduction-v1.json",
    "productSharedBadEventDedup": "TestVectors/product-shared-bad-event-dedup-v1.json",
}

EXPECTED_FORMAL_DECLARATIONS = {
    "ProductFiniteProtocolNumericLossObstruction",
    "ProductFiniteProtocolNumericLossObstructionAccepted",
    "ProductFixedKindCTCORepeatedTapePlan",
    "ProductFixedKindCTCORepeatedTapePlanAccepted",
    "ProductDepthOneDispatcherCorollary",
    "ProductDepthOneDispatcherCorollaryAccepted",
    "productSecurityTheorem_requires_finite_protocol_numeric_loss_instantiation",
    "productSecurityTheorem_requires_fixed_kind_repeated_tape_plan",
    "productSecurityTheorem_dispatcher_reduces_to_fixed_kind",
}
EXPECTED_CTCO_DECLARATIONS = {
    "CTCORepeatedTapeBindingEvidence",
    "CTCORepeatedTapeBadSet",
    "ctcoRepeatedTapeBadSet_card_le_bad_pow",
    "ctcoRepeatedTapeBadSet_card_le_budget_pow",
    "ctcoRepeatedTapeBadSet_uniformProbability_le_budgetRatio",
    "pirlcOneShotEqualityCounterexampleBadSeeds_card_eq",
    "pirlcOneShotEqualityCounterexampleLowerBound_exceeds_selected128",
    "piccsOneShotFirstChallengeZeroBadSet_card_eq",
    "piccsOneShotFirstChallengeZeroCounterexampleLowerBound_exceeds_selected128",
    "piccsTwoTapeLooseRepeatedBound_lt_selected128",
    "piccsTwoTapeFirstMismatchRepeatedBound_lt_selected128",
    "sourceFoldRepeatedTapeFiniteBound_lt_selected128",
    "pirlcThreeTapeCRTComponentRepeatedBound_lt_selected128",
    "pirlcTwoTapeUnitPivotRepeatedBound_lt_selected128",
    "terminalCESwift226RepeatedChallengeWithSharedCoreBudget_lt_selected128",
}

GOLDILOCKS_MODULUS = 18_446_744_069_414_584_321
PHI81_DEGREE = 54
CRT_FIBER_DEGREE = 27
SELECTED_SECURITY_BITS = 128
PICCS_MAX_DEGREE = 4
PICCS_MAX_VARS = 18
TERMINAL_CE_ROUNDS = 226
TERMINAL_CE_SYMBOLS = 3
PROOF_ENVELOPE_VERSION = 5
PICCS_REPEATED_TAPE_COUNT = 2
PIRLC_REPEATED_BRANCH_COUNT = 3
REPEATED_TAPE_LABEL_VERSION = "selected-repeated-tape-v1"
PICCS_REPEATED_TAPE_LABELS = [
    "selected-repeated-tape-v1/piccs-tape-0",
    "selected-repeated-tape-v1/piccs-tape-1",
]
PIRLC_REPEATED_BRANCH_LABELS = [
    "selected-repeated-tape-v1/pirlc-branch-0",
    "selected-repeated-tape-v1/pirlc-branch-1",
    "selected-repeated-tape-v1/pirlc-branch-2",
]
PIRLC_NUMERIC_OBSTRUCTION_DECLARATIONS = {
    "pirlcCRTComponentSingleObservationBound_exceeds_selected128",
    "pirlcFullRingUnitPivotSingleObservationBound_exceeds_selected128",
    "pirlcOneShotEqualityCounterexampleBadSeeds_card_eq",
    "pirlcOneShotEqualityCounterexampleLowerBound_exceeds_selected128",
    "pirlcThreeTapeCRTComponentRepeatedBound_lt_selected128",
    "pirlcTwoTapeUnitPivotRepeatedBound_lt_selected128",
}
PICCS_NUMERIC_OBSTRUCTION_DECLARATIONS = {
    "piccsGoldilocksExt2ChallengeSupport_below_selected128",
    "piccsSelectedBadChallengeBudget_exceeds_selected128",
    "piccsOneShotFirstChallengeZeroBadSet_card_eq",
    "piccsOneShotFirstChallengeZeroCounterexampleLowerBound_exceeds_selected128",
    "piccsTwoTapeLooseRepeatedBound_lt_selected128",
    "piccsTwoTapeFirstMismatchRepeatedBound_lt_selected128",
}
TERMINAL_CE_REPEATED_DECLARATIONS = {
    "TerminalCEPointwiseTwoBranchEvidence",
    "terminalCEPointwiseBadChallengeTapes_card_le_two_pow",
    "terminalCESwiftRepeatedChallengeBound_lt_selected128",
    "terminalCESwift226RepeatedChallengeWithSharedCoreBudget_lt_selected128",
}


def fail(message: str) -> None:
    print(f"product finite-protocol loss obstruction validation failed: {message}", file=sys.stderr)
    raise SystemExit(1)


def require(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def require_dict(value: Any, label: str) -> dict[str, Any]:
    require(isinstance(value, dict), f"{label} must be an object")
    return value


def require_string(value: Any, label: str) -> str:
    require(isinstance(value, str) and value, f"{label} must be a non-empty string")
    return value


def require_string_list(value: Any, label: str) -> list[str]:
    require(isinstance(value, list) and value, f"{label} must be a non-empty list")
    result: list[str] = []
    for index, item in enumerate(value):
        result.append(require_string(item, f"{label}[{index}]"))
    return result


def require_number(value: Any, label: str) -> float:
    require(isinstance(value, (int, float)) and not isinstance(value, bool), f"{label} must be numeric")
    return float(value)


def format_fraction(value: Fraction) -> str:
    if value.denominator == 1:
        return str(value.numerator)
    return f"{value.numerator}/{value.denominator}"


def require_false(value: Any, label: str) -> None:
    require(value is False, f"{label} must be false")


def read_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        fail(f"{path.relative_to(ROOT)} is not valid JSON: {error}")
    require(isinstance(value, dict), f"{path.relative_to(ROOT)} root must be an object")
    return value


def require_relative_path(value: Any, label: str) -> Path:
    relative = Path(require_string(value, label))
    require(not relative.is_absolute(), f"{label} must be repository-relative")
    require(".." not in relative.parts, f"{label} must not escape the repository")
    absolute = ROOT / relative
    require(absolute.exists(), f"{label} does not exist: {relative}")
    return absolute


def validate_related_manifests(manifest: dict[str, Any]) -> None:
    related = require_dict(manifest.get("relatedManifests"), "relatedManifests")
    require(related == EXPECTED_MANIFESTS, "relatedManifests must pin the finite-loss evidence set exactly")
    for key, relative in EXPECTED_MANIFESTS.items():
        require_relative_path(relative, f"relatedManifests.{key}")

    for manifest_key, nested_key in [
        ("productCryptoSecurityDossier", "productFiniteProtocolLossObstruction"),
        ("selectedDepthLossAccounting", "productFiniteProtocolLossObstruction"),
        ("productTotalLossBudget", "productFiniteProtocolLossObstruction"),
    ]:
        linked = read_json(ROOT / EXPECTED_MANIFESTS[manifest_key])
        linked_related = require_dict(linked.get("relatedManifests"), f"{manifest_key}.relatedManifests")
        require(
            linked_related.get(nested_key) == "TestVectors/product-finite-protocol-loss-obstruction-v1.json",
            f"{manifest_key} must link product-finite-protocol-loss-obstruction-v1.json",
        )


def validate_formal_surface(manifest: dict[str, Any]) -> None:
    formal = require_dict(manifest.get("formalSurface"), "formalSurface")
    module_path = require_relative_path(formal.get("module"), "formalSurface.module")
    declarations = set(require_string_list(formal.get("declarations"), "formalSurface.declarations"))
    require(declarations == EXPECTED_FORMAL_DECLARATIONS, "formalSurface.declarations mismatch")
    source = module_path.read_text(encoding="utf-8")
    for declaration in EXPECTED_FORMAL_DECLARATIONS:
        require(declaration in source, f"formal theorem source missing {declaration}")

    supporting = formal.get("supportingModules")
    require(isinstance(supporting, list) and len(supporting) == 1, "formalSurface.supportingModules must pin the CTCO module")
    ctco = require_dict(supporting[0], "formalSurface.supportingModules[0]")
    ctco_path = require_relative_path(ctco.get("module"), "formalSurface.supportingModules[0].module")
    require(
        ctco_path == ROOT / "Formal/SuperNeoFormal/CTCORepeatedTapeSoundness.lean",
        "formalSurface.supportingModules[0].module must be CTCORepeatedTapeSoundness.lean",
    )
    ctco_declarations = set(
        require_string_list(
            ctco.get("declarations"),
            "formalSurface.supportingModules[0].declarations",
        )
    )
    require(ctco_declarations == EXPECTED_CTCO_DECLARATIONS, "CTCO supporting declarations mismatch")
    ctco_source = ctco_path.read_text(encoding="utf-8")
    for declaration in EXPECTED_CTCO_DECLARATIONS:
        require(declaration in ctco_source, f"CTCO Lean source missing {declaration}")


def validate_selected_profile(manifest: dict[str, Any]) -> None:
    profile = require_dict(manifest.get("selectedProfile"), "selectedProfile")
    require(profile.get("profile") == "Goldilocks/Phi81(d=54)", "selectedProfile.profile mismatch")
    require(profile.get("selectedDepth") == 1, "selectedDepth must be 1")
    require(profile.get("selectedSecurityBudgetBits") == SELECTED_SECURITY_BITS, "selected security bits mismatch")
    require(profile.get("goldilocksModulusDecimal") == str(GOLDILOCKS_MODULUS), "Goldilocks modulus mismatch")
    require(profile.get("phi81Degree") == PHI81_DEGREE, "phi81 degree mismatch")
    require(profile.get("pirlcCoefficientSupportSize") == 5, "PiRLC coefficient support mismatch")
    require(profile.get("pirlcCRTFiberDegree") == CRT_FIBER_DEGREE, "PiRLC CRT fiber degree mismatch")
    require(profile.get("piccsMaxDegreePerRound") == PICCS_MAX_DEGREE, "PiCCS degree mismatch")
    require(profile.get("piccsMaximumSumcheckVariableCount") == PICCS_MAX_VARS, "PiCCS variable count mismatch")
    require(profile.get("terminalCERoundCount") == TERMINAL_CE_ROUNDS, "terminal CE round count mismatch")
    require(profile.get("terminalCEChallengeSymbolCount") == TERMINAL_CE_SYMBOLS, "terminal CE symbol count mismatch")
    require(profile.get("proofEnvelopeHeaderVersion") == PROOF_ENVELOPE_VERSION, "proof envelope version mismatch")
    require(profile.get("piccsRepeatedTapeCount") == PICCS_REPEATED_TAPE_COUNT, "PiCCS repeated tape count mismatch")
    require(profile.get("pirlcRepeatedBranchCount") == PIRLC_REPEATED_BRANCH_COUNT, "PiRLC repeated branch count mismatch")
    require(profile.get("pirlcSelectedRoute") == "generic-crt-component-three-branch", "PiRLC selected route mismatch")
    require(profile.get("pirlcUnitPivotRouteSelected") is False, "PiRLC unit-pivot route must remain unselected")
    require(profile.get("repeatedTapeLabelVersion") == REPEATED_TAPE_LABEL_VERSION, "repeated tape label version mismatch")
    require(profile.get("piccsTapeLabels") == PICCS_REPEATED_TAPE_LABELS, "PiCCS tape labels mismatch")
    require(profile.get("pirlcBranchLabels") == PIRLC_REPEATED_BRANCH_LABELS, "PiRLC branch labels mismatch")
    expansion = require_string(profile.get("challengeExpansionMode"), "selectedProfile.challengeExpansionMode")
    require("H_chal" in expansion and "seed-bit slicing" in expansion and "not" in expansion.lower(), "challenge expansion mode must reject seed-bit slicing")
    source = (ROOT / "SuperNeo-NuMetal/Protocols/SuperNeoProtocols.swift").read_text(encoding="utf-8")
    for needle in [
        "public static let selectedPiCCSTapeCount = 2",
        "public static let selectedPiRLCBranchCount = 3",
        'static let version = "selected-repeated-tape-v1"',
        '"\\(version)/piccs-tape-\\(index)"',
        '"\\(version)/pirlc-branch-\\(index)"',
        "repeatedTapeSeed(",
    ]:
        require(needle in source, f"Swift repeated-tape source missing {needle}")
    serialization = (ROOT / "SuperNeo-NuMetal/SuperNeoSerialization.swift").read_text(encoding="utf-8")
    require("static let version: UInt16 = 5" in serialization, "Swift proof-envelope version must be 5")


def validate_selected_budget(manifest: dict[str, Any]) -> None:
    budget = require_dict(manifest.get("selectedBudget"), "selectedBudget")
    require(budget.get("maximumAllowedTotalLoss") == "2^-128", "selected budget threshold mismatch")
    require(budget.get("sharedCoreAlreadyCharged") == "1/2^129", "shared core exact bound mismatch")
    require(budget.get("hbindCollisionAlreadyCharged") == "9/2^254", "H_bind collision exact bound mismatch")
    q = GOLDILOCKS_MODULUS
    source_fold = Fraction(16, q**4) + Fraction(1, 5 ** (CRT_FIBER_DEGREE * PIRLC_REPEATED_BRANCH_COUNT))
    terminal_ce = Fraction(2**TERMINAL_CE_ROUNDS, 3**TERMINAL_CE_ROUNDS)
    partial = Fraction(1, 1 << 129) + source_fold + terminal_ce + Fraction(9, 1 << 254)
    require(
        budget.get("instantiatedRequiredTermPartialSum") == format_fraction(partial),
        "instantiated required-term partial sum mismatch",
    )
    require(
        budget.get("remainingBudgetRequiresEveryPositiveResidualTermToFitBelowTheSelected128BitLedger") is True,
        "remaining budget policy must be explicit",
    )
    require_false(budget.get("productionLossInstantiationAllowed"), "selectedBudget.productionLossInstantiationAllowed")


def validate_pirlc_gap(manifest: dict[str, Any]) -> None:
    pirlc = require_dict(manifest.get("pirlcNumericGap"), "pirlcNumericGap")
    support = 5**PHI81_DEGREE
    selected_denominator = 1 << SELECTED_SECURITY_BITS
    require(
        pirlc.get("challengeSupportExact") == f"5^54 = {support}",
        "PiRLC challenge support exact value mismatch",
    )
    require(
        pirlc.get("selectedBudgetDenominatorExact") == f"2^128 = {selected_denominator}",
        "selected denominator exact value mismatch",
    )
    require(support < selected_denominator, "PiRLC support must be below selected 2^128 denominator")
    require(pirlc.get("challengeSupportBelowSelectedBudgetDenominator") is True, "PiRLC support comparison flag mismatch")
    require(pirlc.get("conservativeCRTComponentSingleObservationBound") == "1/5^27", "CRT component bound mismatch")
    require(pirlc.get("fullRingUnitPivotSingleObservationBound") == "1/5^54", "full-ring unit-pivot bound mismatch")
    require(
        math.isclose(require_number(pirlc.get("conservativeCRTComponentBoundLog2Approx"), "conservative log2"), -math.log2(5**CRT_FIBER_DEGREE), rel_tol=0, abs_tol=1e-12),
        "conservative CRT log2 approximation mismatch",
    )
    require(
        math.isclose(require_number(pirlc.get("fullRingUnitPivotBoundLog2Approx"), "full-ring log2"), -math.log2(support), rel_tol=0, abs_tol=1e-12),
        "full-ring log2 approximation mismatch",
    )
    require(pirlc.get("oneShotEqualityCounterexampleBadSeedCount") == "5^54", "PiRLC equality counterexample count mismatch")
    require(pirlc.get("oneShotEqualityCounterexampleProbability") == "1/5^54", "PiRLC equality counterexample probability mismatch")
    counterexample = require_string(
        pirlc.get("oneShotEqualityCounterexampleConclusion"),
        "pirlcNumericGap.oneShotEqualityCounterexampleConclusion",
    )
    for needle in ["rho_0 = rho_1", "1/5^54", "larger than 2^-128"]:
        require(needle in counterexample, f"PiRLC counterexample conclusion must mention {needle}")
    require(
        pirlc.get("genericRepeatedTapeRoute") == "three independent internal PiRLC tapes using the justified CRT-component 1/5^27 one-tape bound",
        "PiRLC generic repeated-tape route mismatch",
    )
    require(pirlc.get("genericRepeatedTapeBound") == "1/5^81", "PiRLC generic repeated-tape bound mismatch")
    require(
        math.isclose(
            require_number(pirlc.get("genericRepeatedTapeBoundLog2Approx"), "PiRLC repeated log2"),
            -math.log2(5 ** (CRT_FIBER_DEGREE * 3)),
            rel_tol=0,
            abs_tol=1e-12,
        ),
        "PiRLC generic repeated log2 mismatch",
    )
    require(
        pirlc.get("optionalUnitPivotRepeatedTapeRoute")
        == "two internal PiRLC tapes are allowed only after a separate semantic unit-pivot theorem for the concrete relation",
        "PiRLC optional unit-pivot route mismatch",
    )
    require(pirlc.get("optionalUnitPivotRepeatedTapeBound") == "1/5^108", "PiRLC optional unit-pivot repeated bound mismatch")
    require(
        math.isclose(
            require_number(pirlc.get("optionalUnitPivotRepeatedTapeBoundLog2Approx"), "PiRLC unit-pivot repeated log2"),
            -math.log2(5 ** (PHI81_DEGREE * 2)),
            rel_tol=0,
            abs_tol=1e-12,
        ),
        "PiRLC optional unit-pivot repeated log2 mismatch",
    )
    require(1 << SELECTED_SECURITY_BITS < 5 ** (CRT_FIBER_DEGREE * 3), "PiRLC three-tape CRT route must clear 2^-128")
    require(1 << SELECTED_SECURITY_BITS < 5 ** (PHI81_DEGREE * 2), "PiRLC two-tape unit-pivot route must clear 2^-128")
    comparison = require_string(pirlc.get("comparisonToSelectedBudget"), "pirlcNumericGap.comparisonToSelectedBudget")
    for needle in ["5^54 < 2^128", "1/5^54", "2^-128", "1/5^27"]:
        require(needle in comparison, f"PiRLC comparison must mention {needle}")
    require(pirlc.get("selectedPublicFieldFamilyMultiplierPinned") is True, "PiRLC family multiplier must be pinned")
    declarations = set(require_string_list(pirlc.get("leanDeclarations"), "pirlcNumericGap.leanDeclarations"))
    require(declarations == PIRLC_NUMERIC_OBSTRUCTION_DECLARATIONS, "PiRLC numeric obstruction Lean declarations mismatch")
    source = (
        (ROOT / "Formal/SuperNeoFormal/PiRLCFiniteSoundness.lean").read_text(encoding="utf-8")
        + "\n"
        + (ROOT / "Formal/SuperNeoFormal/CTCORepeatedTapeSoundness.lean").read_text(encoding="utf-8")
    )
    for declaration in PIRLC_NUMERIC_OBSTRUCTION_DECLARATIONS:
        require(declaration in source, f"PiRLC Lean source missing {declaration}")
    for key in ["sourceFoldBudgetConclusion", "terminalBudgetConclusion"]:
        conclusion = require_string(pirlc.get(key), f"pirlcNumericGap.{key}")
        require("one-shot" in conclusion and ("instantiates" in conclusion or "inherits" in conclusion), f"{key} must separate one-shot blockers from the repeated-tape selected route")


def validate_piccs_gap(manifest: dict[str, Any]) -> None:
    piccs = require_dict(manifest.get("piccsNumericGap"), "piccsNumericGap")
    q_squared = GOLDILOCKS_MODULUS * GOLDILOCKS_MODULUS
    require(piccs.get("ext2ChallengeSupportExact") == f"q^2 = {q_squared}", "Ext2 support exact value mismatch")
    require(q_squared < (1 << SELECTED_SECURITY_BITS), "Ext2 support must be below selected 2^128 denominator")
    require(piccs.get("ext2ChallengeSupportBelowSelectedBudgetDenominator") is True, "Ext2 support comparison flag mismatch")
    require(
        piccs.get("selectedPiCCSBadChallengeBudget") == "18 * 4 / q^2 = 72/q^2",
        "PiCCS selected bad-challenge budget mismatch",
    )
    require(
        math.isclose(require_number(piccs.get("selectedPiCCSBoundLog2Approx"), "PiCCS log2"), math.log2((PICCS_MAX_VARS * PICCS_MAX_DEGREE) / q_squared), rel_tol=0, abs_tol=1e-12),
        "PiCCS log2 approximation mismatch",
    )
    require(piccs.get("oneShotFirstChallengeZeroCounterexampleBadSetSize") == 1, "PiCCS zero counterexample size mismatch")
    require(piccs.get("oneShotFirstChallengeZeroCounterexampleProbability") == "1/q^2", "PiCCS zero counterexample probability mismatch")
    zero_counterexample = require_string(
        piccs.get("oneShotFirstChallengeZeroCounterexampleConclusion"),
        "piccsNumericGap.oneShotFirstChallengeZeroCounterexampleConclusion",
    )
    for needle in ["first Ext2 challenge is zero", "1/q^2", "q^2 < 2^128"]:
        require(needle in zero_counterexample, f"PiCCS zero counterexample must mention {needle}")
    require(piccs.get("twoTapeLooseRepeatedBound") == "(72/q^2)^2", "PiCCS loose two-tape bound mismatch")
    require(
        math.isclose(
            require_number(piccs.get("twoTapeLooseRepeatedBoundLog2Approx"), "PiCCS loose two-tape log2"),
            math.log2(((PICCS_MAX_VARS * PICCS_MAX_DEGREE) ** 2) / (q_squared**2)),
            rel_tol=0,
            abs_tol=1e-12,
        ),
        "PiCCS loose two-tape log2 mismatch",
    )
    require(piccs.get("twoTapeFirstMismatchRepeatedBound") == "16/q^4", "PiCCS first-mismatch two-tape bound mismatch")
    require(
        math.isclose(
            require_number(piccs.get("twoTapeFirstMismatchRepeatedBoundLog2Approx"), "PiCCS first-mismatch two-tape log2"),
            math.log2((PICCS_MAX_DEGREE**2) / (q_squared**2)),
            rel_tol=0,
            abs_tol=1e-12,
        ),
        "PiCCS first-mismatch two-tape log2 mismatch",
    )
    require((PICCS_MAX_VARS * PICCS_MAX_DEGREE) ** 2 * (1 << SELECTED_SECURITY_BITS) < q_squared**2, "PiCCS loose two-tape route must clear 2^-128")
    require(PICCS_MAX_DEGREE**2 * (1 << SELECTED_SECURITY_BITS) < q_squared**2, "PiCCS first-mismatch two-tape route must clear 2^-128")
    comparison = require_string(piccs.get("minimalSingleChallengeComparison"), "piccsNumericGap.minimalSingleChallengeComparison")
    for needle in ["q^2 < 2^128", "2^-128", "72/q^2"]:
        require(needle in comparison, f"PiCCS comparison must mention {needle}")
    require(q_squared < (PICCS_MAX_VARS * PICCS_MAX_DEGREE) * (1 << SELECTED_SECURITY_BITS), "PiCCS selected budget must exceed 2^-128")
    declarations = set(require_string_list(piccs.get("leanDeclarations"), "piccsNumericGap.leanDeclarations"))
    require(declarations == PICCS_NUMERIC_OBSTRUCTION_DECLARATIONS, "PiCCS numeric obstruction Lean declarations mismatch")
    source = (
        (ROOT / "Formal/SuperNeoFormal/PiCCSConstructiveFiniteSoundness.lean").read_text(encoding="utf-8")
        + "\n"
        + (ROOT / "Formal/SuperNeoFormal/CTCORepeatedTapeSoundness.lean").read_text(encoding="utf-8")
    )
    for declaration in PICCS_NUMERIC_OBSTRUCTION_DECLARATIONS:
        require(declaration in source, f"PiCCS Lean source missing {declaration}")
    conclusion = require_string(piccs.get("selectedBudgetConclusion"), "piccsNumericGap.selectedBudgetConclusion")
    require("not a standalone 128-bit" in conclusion, "PiCCS conclusion must remain fail-closed")


def validate_terminal_ce_gap(manifest: dict[str, Any]) -> None:
    terminal = require_dict(manifest.get("terminalCENumericGap"), "terminalCENumericGap")
    require(terminal.get("slotBadSeedBudget") == TERMINAL_CE_ROUNDS * TERMINAL_CE_SYMBOLS, "terminal CE slot budget mismatch")
    require(terminal.get("fullTapeLiftFiberFactor") == "3^225", "terminal CE fiber factor mismatch")
    require(
        terminal.get("fullTapeUnionBoundRatio") == "678 * 3^225 / 3^226 = 226",
        "terminal CE full-tape ratio mismatch",
    )
    lift_conclusion = require_string(terminal.get("fullTapeLiftConclusion"), "terminalCENumericGap.fullTapeLiftConclusion")
    require("not a usable selected-depth probability bound" in lift_conclusion, "terminal CE lift conclusion must stay fail-closed")
    bad_tapes = 2**TERMINAL_CE_ROUNDS
    support = 3**TERMINAL_CE_ROUNDS
    require(
        terminal.get("repeatedChallengeBadTapeBudget") == f"2^226 = {bad_tapes}",
        "terminal CE repeated bad-tape budget mismatch",
    )
    require(
        terminal.get("repeatedChallengeTapeSupport") == f"3^226 = {support}",
        "terminal CE repeated tape support mismatch",
    )
    require(terminal.get("repeatedChallengeBound") == "(2/3)^226", "terminal CE repeated bound mismatch")
    require(
        math.isclose(
            require_number(terminal.get("repeatedChallengeBoundLog2Approx"), "terminal CE repeated log2"),
            TERMINAL_CE_ROUNDS * math.log2(Fraction(2, 3)),
            rel_tol=0,
            abs_tol=1e-12,
        ),
        "terminal CE repeated log2 approximation mismatch",
    )
    require(bad_tapes * (1 << SELECTED_SECURITY_BITS) < support, "terminal CE repeated bound must be below 2^-128")
    require(
        terminal.get("repeatedChallengeBoundWithinSelectedBudget") is True,
        "terminal CE repeated bound comparison flag mismatch",
    )
    require(terminal.get("pinnedRoundCountForProductLedger") == 226, "terminal CE pinned product round count mismatch")
    slack = require_string(terminal.get("withSharedCoreSlackBound"), "terminalCENumericGap.withSharedCoreSlackBound")
    for needle in ["(2/3)^226 < 2^-129", "epsilon_core_shared <= 2^-129", "below 2^-128"]:
        require(needle in slack, f"terminal CE slack bound must mention {needle}")
    require(bad_tapes * (1 << 129) < support, "terminal CE 226 rounds must clear shared-core slack")
    declarations = set(require_string_list(terminal.get("leanDeclarations"), "terminalCENumericGap.leanDeclarations"))
    require(declarations == TERMINAL_CE_REPEATED_DECLARATIONS, "terminal CE repeated Lean declarations mismatch")
    source = (
        (ROOT / "Formal/SuperNeoFormal/TerminalCEConstructiveFiniteSoundness.lean").read_text(encoding="utf-8")
        + "\n"
        + (ROOT / "Formal/SuperNeoFormal/CTCORepeatedTapeSoundness.lean").read_text(encoding="utf-8")
    )
    for declaration in TERMINAL_CE_REPEATED_DECLARATIONS:
        require(declaration in source, f"terminal CE Lean source missing {declaration}")
    conclusion = require_string(terminal.get("selectedBudgetConclusion"), "terminalCENumericGap.selectedBudgetConclusion")
    for needle in ["226", "within the selected 2^-128", "epsilon_terminal", "PiRLC/PiCCS"]:
        require(needle in conclusion, f"terminal CE conclusion must mention {needle}")


def validate_ledger_decision(manifest: dict[str, Any]) -> None:
    decision = require_dict(manifest.get("ledgerDecision"), "ledgerDecision")
    require(decision.get("oneShotSourceFoldProfile128BitClaimAllowed") is False, "one-shot source fold claim must be blocked")
    require(decision.get("sourceFoldLossInstantiated") is True, "source fold finite loss must be instantiated by repeated tapes")
    require(decision.get("terminalSealLossInstantiated") is True, "terminal CE finite loss must be instantiated at 226 rounds")
    require_false(decision.get("extractorLossInstantiated"), "ledgerDecision.extractorLossInstantiated")
    require_false(decision.get("selectedTotalLossBudgetPromotionAllowed"), "ledgerDecision.selectedTotalLossBudgetPromotionAllowed")
    require(decision.get("fixedKindRepeatedTapeRouteRequired") is True, "fixed-kind repeated-tape route must be required")
    require(decision.get("dispatcherCorollaryOnlyAfterFixedKindPlans") is True, "dispatcher corollary gating mismatch")
    require(decision.get("terminalCEPinnedRoundCount") == 226, "terminal CE ledger decision must pin 226 rounds")
    q = GOLDILOCKS_MODULUS
    source_fold = Fraction(16, q**4) + Fraction(1, 5 ** (CRT_FIBER_DEGREE * PIRLC_REPEATED_BRANCH_COUNT))
    terminal_ce = Fraction(2**TERMINAL_CE_ROUNDS, 3**TERMINAL_CE_ROUNDS)
    require(
        decision.get("sourceFoldSelectedRepeatedTapeExactUpperBound") == format_fraction(source_fold),
        "source fold repeated-tape exact upper bound mismatch",
    )
    require(
        decision.get("terminalCESelectedExactUpperBound") == format_fraction(terminal_ce),
        "terminal CE exact upper bound mismatch",
    )
    require(source_fold < Fraction(1, 1 << SELECTED_SECURITY_BITS), "source fold repeated-tape bound must be below 2^-128")
    require(terminal_ce < Fraction(1, 1 << SELECTED_SECURITY_BITS), "terminal CE bound must be below 2^-128")
    accounting = require_string(decision.get("fixedKindLedgerAccounting"), "ledgerDecision.fixedKindLedgerAccounting")
    for needle in ["fixed expected proof kind", "H_bind", "does not flat-sum unrelated proof-kind finite terms"]:
        require(needle in accounting, f"fixed-kind ledger accounting must mention {needle}")
    options = require_string_list(decision.get("nextMathematicalOptions"), "ledgerDecision.nextMathematicalOptions")
    joined = " ".join(options).lower()
    for needle in ["fixed-kind", "repeated-tape", "226", "extractor"]:
        require(needle in joined, f"next mathematical options must mention {needle}")

    total_budget = read_json(ROOT / "TestVectors/product-total-loss-budget-v1.json")
    components = require_dict({"rows": total_budget.get("componentBounds")}, "component wrapper")["rows"]
    require(isinstance(components, list), "total-loss componentBounds must be a list")
    by_id = {require_dict(row, "component row").get("id"): row for row in components}
    for component_id in ["source-fold-knowledge", "terminal-numiseal-seal"]:
        component = require_dict(by_id.get(component_id), f"total-loss {component_id}")
        require(component.get("lossInstantiated") is True, f"total-loss {component_id}.lossInstantiated must be true")
    for component_id in ["extractor-instantiation"]:
        component = require_dict(by_id.get(component_id), f"total-loss {component_id}")
        require_false(component.get("lossInstantiated"), f"total-loss {component_id}.lossInstantiated")


def validate_manifest(path: Path) -> None:
    manifest = read_json(path)
    text = json.dumps(manifest, sort_keys=True).lower()
    require("external" + " audit" not in text, "manifest must not encode outsourced review as a product gate")
    require(set(manifest) == EXPECTED_TOP_LEVEL_KEYS, "top-level keys mismatch")
    require(manifest.get("schemaVersion") == 1, "schemaVersion must be 1")
    require(
        manifest.get("evidenceID") == "superneo-product-finite-protocol-loss-obstruction-v1",
        "evidenceID mismatch",
    )
    require(
        manifest.get("claimStatus") == "finite-protocol-one-shot-obstruction-repeated-tape-selected-not-production-claim",
        "claimStatus mismatch",
    )
    validate_related_manifests(manifest)
    validate_formal_surface(manifest)
    validate_selected_profile(manifest)
    validate_selected_budget(manifest)
    validate_pirlc_gap(manifest)
    validate_piccs_gap(manifest)
    validate_terminal_ce_gap(manifest)
    validate_ledger_decision(manifest)


def main() -> None:
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else MANIFEST
    if not path.is_absolute():
        path = ROOT / path
    validate_manifest(path)
    print("product finite-protocol loss obstruction validation passed")


if __name__ == "__main__":
    main()
