import Foundation

public enum NumiSealProductTheoremLimits {
    public static let theoremID = "numiseal-product-qrom-selected-depth-1-v1"
    public static let selectedDepth = 1
    public static let maximumLaneCount = 1
    public static let maximumSourceFoldOutputClaimCount =
        SuperNeoParameters.goldilocks.decompositionLength
    public static let maximumObligationsPerAggregate =
        SuperNeoParameters.goldilocks.maxFreshBatchCount + SuperNeoParameters.goldilocks.maxPriorClaimCount
    public static let maximumAggregatesPerLane = maximumObligationsPerAggregate
    public static let maximumPublicInputCount = 1024
    public static let maximumMatrixEvaluationCount = 1024
    public static let maximumDigitTensorColumnCount = 4096
    public static let maximumSumcheckVariableCount = 18
    public static let scalarizationCommitmentWeightCount =
        SuperNeoParameters.goldilocks.kappa * CyclotomicRing54.degree
    public static let scalarizationDecompositionCommitmentWeightCount =
        SuperNeoParameters.goldilocks.kappa * CyclotomicRing54.degree
    public static let maximumMatrixEvaluationWeightCount =
        maximumMatrixEvaluationCount * CyclotomicRing54.degree
    public static let maximumChallengesPerAggregate =
        maximumObligationsPerAggregate
        + scalarizationCommitmentWeightCount
        + scalarizationDecompositionCommitmentWeightCount
        + maximumPublicInputCount
        + maximumMatrixEvaluationWeightCount
        + 2
        + maximumSumcheckVariableCount
    public static let maximumNumiSealTerminalChallengeCount =
        maximumLaneCount * maximumAggregatesPerLane * maximumChallengesPerAggregate
    public static let maximumNumiSealZKProductChallengeCount =
        maximumNumiSealTerminalChallengeCount + (3 * maximumLaneCount * maximumAggregatesPerLane)

    public static func validate(request: NumiSealProvingRequest) throws {
        guard request.parameters == .goldilocks else {
            throw SuperNeoError.invalidParameter("NumiSeal product theorem currently supports Goldilocks parameters")
        }
        guard request.aggregationLimits.maximumObligationsPerAggregate <= maximumObligationsPerAggregate else {
            throw SuperNeoError.invalidParameter("NumiSeal product aggregate limit exceeds theorem maximum")
        }
        guard request.publicInputs.count <= maximumPublicInputCount else {
            throw SuperNeoError.invalidParameter("NumiSeal product public input count exceeds theorem maximum")
        }
        guard request.sourceDecompositionProfile == .payPerBit else {
            throw SuperNeoError.invalidParameter("NumiSeal product source decomposition profile must be pay-per-bit-v1")
        }
    }

    public static func validateSourceFoldOutputClaimCount(_ count: Int) throws {
        guard count > 0 else {
            throw SuperNeoError.invalidParameter("NumiSeal product source claim count must be positive")
        }
        guard count <= maximumSourceFoldOutputClaimCount else {
            throw SuperNeoError.invalidParameter("NumiSeal product source claim count exceeds theorem maximum")
        }
    }

    public static func validate(plan: NumiSealProvingPlan) throws {
        guard plan.publicStatement.laneSummaries.count <= maximumLaneCount else {
            throw SuperNeoError.invalidParameter("NumiSeal product lane count exceeds theorem maximum")
        }
        guard plan.aggregates.count <= maximumLaneCount * maximumAggregatesPerLane else {
            throw SuperNeoError.invalidParameter("NumiSeal product aggregate count exceeds theorem maximum")
        }
        for aggregate in plan.aggregates {
            guard aggregate.obligationDigests.count <= maximumObligationsPerAggregate else {
                throw SuperNeoError.invalidParameter("NumiSeal product aggregate obligation count exceeds theorem maximum")
            }
            guard aggregate.aggregateCommitment.elements.count <= SuperNeoParameters.goldilocks.kappa else {
                throw SuperNeoError.invalidParameter("NumiSeal product commitment width exceeds theorem maximum")
            }
            guard aggregate.aggregatePublicInputEncoding.field.count <= maximumPublicInputCount else {
                throw SuperNeoError.invalidParameter("NumiSeal product aggregate public input count exceeds theorem maximum")
            }
            guard aggregate.aggregateMatrixEvaluations.count <= maximumMatrixEvaluationCount else {
                throw SuperNeoError.invalidParameter("NumiSeal product matrix evaluation count exceeds theorem maximum")
            }
        }
    }

    public static func validate(artifact: NumiSealProductArtifact) throws {
        guard artifact.profile == SuperNeoParameterProfile.goldilocksPhi81.name else {
            throw SuperNeoError.invalidEncoding("unsupported NumiSeal product profile")
        }
        guard artifact.publicInputs.count <= maximumPublicInputCount else {
            throw SuperNeoError.invalidEncoding("NumiSeal product public input count exceeds theorem maximum")
        }
        guard artifact.sourceFoldOutputClaimCount > 0 else {
            throw SuperNeoError.invalidEncoding("NumiSeal product source claim count must be positive")
        }
        guard artifact.sourceFoldOutputClaimCount <= maximumSourceFoldOutputClaimCount else {
            throw SuperNeoError.invalidEncoding("NumiSeal product source claim count exceeds theorem maximum")
        }
        guard artifact.maximumObligationsPerAggregate <= maximumObligationsPerAggregate else {
            throw SuperNeoError.invalidEncoding("NumiSeal product aggregate limit exceeds theorem maximum")
        }
        guard artifact.maximumLaneCount <= maximumLaneCount else {
            throw SuperNeoError.invalidEncoding("NumiSeal product lane count exceeds theorem maximum")
        }
        guard artifact.maximumAggregatesPerLane <= maximumAggregatesPerLane else {
            throw SuperNeoError.invalidEncoding("NumiSeal product aggregate count exceeds theorem maximum")
        }
        guard artifact.aggregateDigestsHex.count <= maximumLaneCount * maximumAggregatesPerLane else {
            throw SuperNeoError.invalidEncoding("NumiSeal product aggregate digest count exceeds theorem maximum")
        }
    }
}
