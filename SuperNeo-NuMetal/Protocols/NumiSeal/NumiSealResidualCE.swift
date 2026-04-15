import Foundation

public struct NumiSealResidualCEShape: Equatable, Sendable, SuperNeoByteEncodable {
    public static let domain = Digest256.hash("SuperNeo-NuMetal.numiseal.residual-ce-shape.v1")
    public static let version: UInt16 = 10

    public let version: UInt16
    public let profileID: UInt16
    public let laneKey: NumiSealLaneKey
    public let aggregateIndex: Int
    public let openingCount: Int
    public let publicInputCount: Int
    public let matrixEvaluationCount: Int
    public let evalPointDigest: Digest256
    public let residualShapeDigest: Digest256

    public init(
        laneKey: NumiSealLaneKey,
        aggregateIndex: Int,
        terminalStatement: TerminalCEStatement
    ) throws {
        try Self.validateScope(
            laneKey: laneKey,
            aggregateIndex: aggregateIndex,
            terminalStatement: terminalStatement
        )
        let firstInstance = terminalStatement.openings[0].instance
        let openingCount = terminalStatement.openings.count
        let publicInputCount = firstInstance.publicInput.count
        let matrixEvaluationCount = firstInstance.matrixEvals.count
        let evalPointDigest = NumiSealCanonicalization.evalPointDigest(firstInstance.evalPoint)
        try Self.validate(
            profileID: terminalStatement.profileID,
            laneKey: laneKey,
            aggregateIndex: aggregateIndex,
            openingCount: openingCount,
            publicInputCount: publicInputCount,
            matrixEvaluationCount: matrixEvaluationCount,
            evalPointDigest: evalPointDigest
        )

        self.version = Self.version
        self.profileID = terminalStatement.profileID
        self.laneKey = laneKey
        self.aggregateIndex = aggregateIndex
        self.openingCount = openingCount
        self.publicInputCount = publicInputCount
        self.matrixEvaluationCount = matrixEvaluationCount
        self.evalPointDigest = evalPointDigest
        self.residualShapeDigest = Self.computeResidualShapeDigest(
            profileID: terminalStatement.profileID,
            laneKey: laneKey,
            aggregateIndex: aggregateIndex,
            openingCount: openingCount,
            publicInputCount: publicInputCount,
            matrixEvaluationCount: matrixEvaluationCount,
            evalPointDigest: evalPointDigest
        )
    }

    public init(bytes: [UInt8]) throws {
        var reader = ByteReader(bytes)
        let domain = try Digest256(reader.readData(count: Digest256.byteCount))
        guard domain == Self.domain else {
            throw SuperNeoError.invalidEncoding("NumiSeal residual CE shape domain mismatch")
        }
        let version = try reader.readUInt16()
        guard version == Self.version else {
            throw SuperNeoError.invalidEncoding("unsupported NumiSeal residual CE shape version")
        }
        let profileID = try reader.readUInt16()
        let laneKey = try reader.readNumiSealLaneKey()
        let aggregateIndex = try reader.readCount(
            maximum: NumiSealWireLimits.maximumAggregateCount,
            name: "NumiSeal residual CE shape aggregate index"
        )
        let openingCount = try reader.readCount(
            maximum: NumiSealWireLimits.maximumObligationCount,
            name: "NumiSeal residual CE opening"
        )
        let publicInputCount = try reader.readCount(
            maximum: NumiSealWireLimits.maximumProofComponentByteCount,
            name: "NumiSeal residual CE public input"
        )
        let matrixEvaluationCount = try reader.readCount(
            maximum: NumiSealWireLimits.maximumProofComponentByteCount,
            name: "NumiSeal residual CE matrix evaluation"
        )
        let evalPointDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        let residualShapeDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        try reader.finish()

        try Self.validate(
            profileID: profileID,
            laneKey: laneKey,
            aggregateIndex: aggregateIndex,
            openingCount: openingCount,
            publicInputCount: publicInputCount,
            matrixEvaluationCount: matrixEvaluationCount,
            evalPointDigest: evalPointDigest
        )
        let expectedDigest = Self.computeResidualShapeDigest(
            profileID: profileID,
            laneKey: laneKey,
            aggregateIndex: aggregateIndex,
            openingCount: openingCount,
            publicInputCount: publicInputCount,
            matrixEvaluationCount: matrixEvaluationCount,
            evalPointDigest: evalPointDigest
        )
        guard residualShapeDigest == expectedDigest else {
            throw SuperNeoError.invalidEncoding("NumiSeal residual CE shape digest mismatch")
        }

        self.version = version
        self.profileID = profileID
        self.laneKey = laneKey
        self.aggregateIndex = aggregateIndex
        self.openingCount = openingCount
        self.publicInputCount = publicInputCount
        self.matrixEvaluationCount = matrixEvaluationCount
        self.evalPointDigest = evalPointDigest
        self.residualShapeDigest = residualShapeDigest
    }

    public func validate(terminalStatement: TerminalCEStatement) throws {
        let expected = try Self(
            laneKey: laneKey,
            aggregateIndex: aggregateIndex,
            terminalStatement: terminalStatement
        )
        guard self == expected else {
            throw SuperNeoError.verificationFailed("NumiSeal residual CE shape mismatch")
        }
    }

    public var superNeoBytes: [UInt8] {
        Self.domain.superNeoBytes
            + Self.bodyBytes(
                profileID: profileID,
                laneKey: laneKey,
                aggregateIndex: aggregateIndex,
                openingCount: openingCount,
                publicInputCount: publicInputCount,
                matrixEvaluationCount: matrixEvaluationCount,
                evalPointDigest: evalPointDigest
            )
            + residualShapeDigest.superNeoBytes
    }

    private static func validateScope(
        laneKey: NumiSealLaneKey,
        aggregateIndex: Int,
        terminalStatement: TerminalCEStatement
    ) throws {
        guard terminalStatement.profileID == laneKey.profileID else {
            throw SuperNeoError.invalidParameter("NumiSeal residual CE shape profile mismatch")
        }
        guard terminalStatement.shapeDigest == laneKey.shapeDigest else {
            throw SuperNeoError.invalidParameter("NumiSeal residual CE shape CCS shape mismatch")
        }
        guard terminalStatement.verifierKeyDigest == laneKey.verifierKeyDigest else {
            throw SuperNeoError.invalidParameter("NumiSeal residual CE shape verifier key mismatch")
        }
        guard aggregateIndex >= 0 else {
            throw SuperNeoError.invalidParameter("NumiSeal residual CE shape aggregate index must be non-negative")
        }
        guard !terminalStatement.openings.isEmpty else {
            throw SuperNeoError.invalidParameter("NumiSeal residual CE shape cannot be empty")
        }

        let firstInstance = terminalStatement.openings[0].instance
        let publicInputCount = firstInstance.publicInput.count
        let matrixEvaluationCount = firstInstance.matrixEvals.count
        let evalPointDigest = NumiSealCanonicalization.evalPointDigest(firstInstance.evalPoint)
        guard evalPointDigest == laneKey.evalPointDigest else {
            throw SuperNeoError.invalidParameter("NumiSeal residual CE shape evaluation point mismatch")
        }
        for opening in terminalStatement.openings {
            guard opening.instance.publicInput.count == publicInputCount else {
                throw SuperNeoError.invalidParameter("NumiSeal residual CE shape public input arity mismatch")
            }
            guard opening.instance.matrixEvals.count == matrixEvaluationCount else {
                throw SuperNeoError.invalidParameter("NumiSeal residual CE shape matrix arity mismatch")
            }
            guard NumiSealCanonicalization.evalPointDigest(opening.instance.evalPoint) == evalPointDigest else {
                throw SuperNeoError.invalidParameter("NumiSeal residual CE shape evaluation point mismatch")
            }
        }
    }

    private static func validate(
        profileID: UInt16,
        laneKey: NumiSealLaneKey,
        aggregateIndex: Int,
        openingCount: Int,
        publicInputCount: Int,
        matrixEvaluationCount: Int,
        evalPointDigest: Digest256
    ) throws {
        guard profileID == laneKey.profileID else {
            throw SuperNeoError.invalidEncoding("NumiSeal residual CE shape profile mismatch")
        }
        guard aggregateIndex >= 0 else {
            throw SuperNeoError.invalidEncoding("NumiSeal residual CE shape aggregate index must be non-negative")
        }
        guard openingCount > 0 else {
            throw SuperNeoError.invalidEncoding("NumiSeal residual CE shape cannot be empty")
        }
        guard publicInputCount >= 0 else {
            throw SuperNeoError.invalidEncoding("NumiSeal residual CE shape public input count must be non-negative")
        }
        guard matrixEvaluationCount > 0 else {
            throw SuperNeoError.invalidEncoding("NumiSeal residual CE shape matrix evaluation count must be positive")
        }
        guard evalPointDigest == laneKey.evalPointDigest else {
            throw SuperNeoError.invalidEncoding("NumiSeal residual CE shape evaluation point mismatch")
        }
    }

    private static func computeResidualShapeDigest(
        profileID: UInt16,
        laneKey: NumiSealLaneKey,
        aggregateIndex: Int,
        openingCount: Int,
        publicInputCount: Int,
        matrixEvaluationCount: Int,
        evalPointDigest: Digest256
    ) -> Digest256 {
        NumiSealEncoding.digest(
            label: "numiseal.residual-ce-shape.v1",
            bytes: bodyBytes(
                profileID: profileID,
                laneKey: laneKey,
                aggregateIndex: aggregateIndex,
                openingCount: openingCount,
                publicInputCount: publicInputCount,
                matrixEvaluationCount: matrixEvaluationCount,
                evalPointDigest: evalPointDigest
            )
        )
    }

    private static func bodyBytes(
        profileID: UInt16,
        laneKey: NumiSealLaneKey,
        aggregateIndex: Int,
        openingCount: Int,
        publicInputCount: Int,
        matrixEvaluationCount: Int,
        evalPointDigest: Digest256
    ) -> [UInt8] {
        numiSealEncodeUInt16(Self.version)
            + numiSealEncodeUInt16(profileID)
            + laneKey.superNeoBytes
            + numiSealEncodeCount(aggregateIndex)
            + numiSealEncodeCount(openingCount)
            + numiSealEncodeCount(publicInputCount)
            + numiSealEncodeCount(matrixEvaluationCount)
            + evalPointDigest.superNeoBytes
    }
}

public struct NumiSealResidualCEStatement: Equatable, Sendable, SuperNeoByteEncodable {
    public static let domain = Digest256.hash("SuperNeo-NuMetal.numiseal.residual-ce-statement.v1")
    public static let version: UInt16 = 10

    public let version: UInt16
    public let residualShape: NumiSealResidualCEShape
    public let publicStatementDigest: Digest256
    public let aggregateDigest: Digest256
    public let decompositionKeyDigest: Digest256
    public let decompositionCommitmentDigest: Digest256
    public let linearResidualDigest: Digest256
    public let sumcheckProofDigest: Digest256
    public let sumcheckFinalPoint: [GoldilocksExt2]
    public let claimedDigitEvaluation: GoldilocksExt2
    public let terminalStatementDigest: Digest256
    public let statementDigest: Digest256

    public init(
        linearResidual: NumiSealLinearResidual,
        sumcheckProof: SumcheckProof,
        terminalStatement: TerminalCEStatement
    ) throws {
        guard sumcheckProof.claimedSum == linearResidual.residualValue else {
            throw SuperNeoError.invalidParameter("NumiSeal residual CE statement sum-check claimed sum mismatch")
        }
        let scalarizationStatement = linearResidual.statement
        let residualShape = try NumiSealResidualCEShape(
            laneKey: scalarizationStatement.laneKey,
            aggregateIndex: scalarizationStatement.aggregateIndex,
            terminalStatement: terminalStatement
        )
        let sumcheckProofDigest = NumiSealResidualOpening.sumcheckProofDigest(sumcheckProof)
        let terminalStatementDigest = terminalStatement.statementDigest
        self.version = Self.version
        self.residualShape = residualShape
        self.publicStatementDigest = scalarizationStatement.publicStatementDigest
        self.aggregateDigest = scalarizationStatement.aggregateDigest
        self.decompositionKeyDigest = scalarizationStatement.decompositionKeyDigest
        self.decompositionCommitmentDigest = scalarizationStatement.decompositionCommitmentDigest
        self.linearResidualDigest = linearResidual.residualDigest
        self.sumcheckProofDigest = sumcheckProofDigest
        self.sumcheckFinalPoint = sumcheckProof.finalPoint
        self.claimedDigitEvaluation = sumcheckProof.finalValue
        self.terminalStatementDigest = terminalStatementDigest
        self.statementDigest = Self.computeStatementDigest(
            residualShape: residualShape,
            publicStatementDigest: publicStatementDigest,
            aggregateDigest: aggregateDigest,
            decompositionKeyDigest: decompositionKeyDigest,
            decompositionCommitmentDigest: decompositionCommitmentDigest,
            linearResidualDigest: linearResidualDigest,
            sumcheckProofDigest: sumcheckProofDigest,
            sumcheckFinalPoint: sumcheckProof.finalPoint,
            claimedDigitEvaluation: sumcheckProof.finalValue,
            terminalStatementDigest: terminalStatementDigest
        )
    }

    public init(bytes: [UInt8]) throws {
        var reader = ByteReader(bytes)
        let domain = try Digest256(reader.readData(count: Digest256.byteCount))
        guard domain == Self.domain else {
            throw SuperNeoError.invalidEncoding("NumiSeal residual CE statement domain mismatch")
        }
        let version = try reader.readUInt16()
        guard version == Self.version else {
            throw SuperNeoError.invalidEncoding("unsupported NumiSeal residual CE statement version")
        }
        let residualShapeByteCount = try reader.readCount(
            maximum: NumiSealWireLimits.maximumProofComponentByteCount,
            name: "NumiSeal residual CE shape byte",
            elementByteWidth: 1
        )
        guard residualShapeByteCount > 0 else {
            throw SuperNeoError.invalidEncoding("NumiSeal residual CE shape cannot be empty")
        }
        let residualShape = try NumiSealResidualCEShape(
            bytes: reader.readData(count: residualShapeByteCount)
        )
        let publicStatementDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        let aggregateDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        let decompositionKeyDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        let decompositionCommitmentDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        let linearResidualDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        let sumcheckProofDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        let sumcheckFinalPoint = try reader.readNumiSealEvaluationPoint()
        let claimedDigitEvaluation = try reader.readNumiSealExt2()
        let terminalStatementDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        let statementDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        try reader.finish()

        let expectedDigest = Self.computeStatementDigest(
            residualShape: residualShape,
            publicStatementDigest: publicStatementDigest,
            aggregateDigest: aggregateDigest,
            decompositionKeyDigest: decompositionKeyDigest,
            decompositionCommitmentDigest: decompositionCommitmentDigest,
            linearResidualDigest: linearResidualDigest,
            sumcheckProofDigest: sumcheckProofDigest,
            sumcheckFinalPoint: sumcheckFinalPoint,
            claimedDigitEvaluation: claimedDigitEvaluation,
            terminalStatementDigest: terminalStatementDigest
        )
        guard statementDigest == expectedDigest else {
            throw SuperNeoError.invalidEncoding("NumiSeal residual CE statement digest mismatch")
        }

        self.version = version
        self.residualShape = residualShape
        self.publicStatementDigest = publicStatementDigest
        self.aggregateDigest = aggregateDigest
        self.decompositionKeyDigest = decompositionKeyDigest
        self.decompositionCommitmentDigest = decompositionCommitmentDigest
        self.linearResidualDigest = linearResidualDigest
        self.sumcheckProofDigest = sumcheckProofDigest
        self.sumcheckFinalPoint = sumcheckFinalPoint
        self.claimedDigitEvaluation = claimedDigitEvaluation
        self.terminalStatementDigest = terminalStatementDigest
        self.statementDigest = statementDigest
    }

    public func validate(
        linearResidual: NumiSealLinearResidual,
        sumcheckProof: SumcheckProof,
        terminalStatement: TerminalCEStatement
    ) throws {
        let expected = try Self(
            linearResidual: linearResidual,
            sumcheckProof: sumcheckProof,
            terminalStatement: terminalStatement
        )
        guard self == expected else {
            throw SuperNeoError.verificationFailed("NumiSeal residual CE statement mismatch")
        }
    }

    public func validate(terminalStatement: TerminalCEStatement) throws {
        try residualShape.validate(terminalStatement: terminalStatement)
        guard terminalStatementDigest == terminalStatement.statementDigest else {
            throw SuperNeoError.verificationFailed("NumiSeal residual CE statement terminal digest mismatch")
        }
    }

    public var superNeoBytes: [UInt8] {
        let residualShapeBytes = residualShape.superNeoBytes
        var bytes = Self.domain.superNeoBytes
        bytes += numiSealEncodeUInt16(version)
        bytes += numiSealResidualFrame(residualShapeBytes)
        bytes += publicStatementDigest.superNeoBytes
        bytes += aggregateDigest.superNeoBytes
        bytes += decompositionKeyDigest.superNeoBytes
        bytes += decompositionCommitmentDigest.superNeoBytes
        bytes += linearResidualDigest.superNeoBytes
        bytes += sumcheckProofDigest.superNeoBytes
        bytes += numiSealEncodeCount(sumcheckFinalPoint.count)
        bytes += sumcheckFinalPoint.flatMap(\.superNeoBytes)
        bytes += claimedDigitEvaluation.superNeoBytes
        bytes += terminalStatementDigest.superNeoBytes
        bytes += statementDigest.superNeoBytes
        return bytes
    }

    private static func computeStatementDigest(
        residualShape: NumiSealResidualCEShape,
        publicStatementDigest: Digest256,
        aggregateDigest: Digest256,
        decompositionKeyDigest: Digest256,
        decompositionCommitmentDigest: Digest256,
        linearResidualDigest: Digest256,
        sumcheckProofDigest: Digest256,
        sumcheckFinalPoint: [GoldilocksExt2],
        claimedDigitEvaluation: GoldilocksExt2,
        terminalStatementDigest: Digest256
    ) -> Digest256 {
        NumiSealEncoding.digest(
            label: "numiseal.residual-ce-statement.v1",
            bytes: numiSealEncodeUInt16(Self.version)
                + residualShape.residualShapeDigest.superNeoBytes
                + publicStatementDigest.superNeoBytes
                + aggregateDigest.superNeoBytes
                + decompositionKeyDigest.superNeoBytes
                + decompositionCommitmentDigest.superNeoBytes
                + linearResidualDigest.superNeoBytes
                + sumcheckProofDigest.superNeoBytes
                + numiSealEncodeCount(sumcheckFinalPoint.count)
                + sumcheckFinalPoint.flatMap(\.superNeoBytes)
                + claimedDigitEvaluation.superNeoBytes
                + terminalStatementDigest.superNeoBytes
        )
    }
}

public struct NumiSealResidualCEBuildResult: Equatable, Sendable {
    public let terminalStatement: TerminalCEStatement
    public let ceOpeningProof: CEOpeningProof
    public let residualOpening: NumiSealResidualOpening

    public init(
        terminalStatement: TerminalCEStatement,
        ceOpeningProof: CEOpeningProof,
        residualOpening: NumiSealResidualOpening
    ) {
        self.terminalStatement = terminalStatement
        self.ceOpeningProof = ceOpeningProof
        self.residualOpening = residualOpening
    }
}

public enum NumiSealResidualCEBuilder {
    public static func proveImmediateOpening(
        publicStatement: NumiSealPublicStatement,
        aggregate: NumiSealLaneAggregate,
        decomposition: NumiSealDecompositionCommitment,
        digitTensor: NumiSealDigitTensor,
        linearResidual: NumiSealLinearResidual,
        sumcheckProof: SumcheckProof,
        aggregateClaim: CCSEvaluationClaim,
        shape: CCSShape,
        key: AjtaiCommitmentKey,
        parameters: SuperNeoParameters = .goldilocks,
        metalWorkspace: SuperNeoMetalWorkspace? = nil,
        executionPolicy: SuperNeoExecutionPolicy = .default
    ) throws -> NumiSealResidualCEBuildResult {
        let material = try buildMaterial(
            publicStatement: publicStatement,
            aggregate: aggregate,
            decomposition: decomposition,
            digitTensor: digitTensor,
            linearResidual: linearResidual,
            sumcheckProof: sumcheckProof,
            aggregateClaim: aggregateClaim,
            shape: shape,
            key: key,
            parameters: parameters,
            executionPolicy: executionPolicy
        )
        let proof = try CEOpeningRelation.proveLocalBatch(
            statement: material.terminalStatement,
            witnesses: [material.witness],
            shape: shape,
            key: key,
            parameters: parameters,
            metalWorkspace: metalWorkspace,
            executionPolicy: executionPolicy
        )
        return try buildResult(
            terminalStatement: material.terminalStatement,
            ceOpeningProof: proof,
            aggregate: aggregate,
            linearResidual: linearResidual,
            sumcheckProof: sumcheckProof
        )
    }

    @_spi(Benchmarking) public static func proveImmediateOpeningDeterministic(
        publicStatement: NumiSealPublicStatement,
        aggregate: NumiSealLaneAggregate,
        decomposition: NumiSealDecompositionCommitment,
        digitTensor: NumiSealDigitTensor,
        linearResidual: NumiSealLinearResidual,
        sumcheckProof: SumcheckProof,
        aggregateClaim: CCSEvaluationClaim,
        shape: CCSShape,
        key: AjtaiCommitmentKey,
        parameters: SuperNeoParameters = .goldilocks,
        randomSeed: [UInt8],
        metalWorkspace: SuperNeoMetalWorkspace? = nil,
        executionPolicy: SuperNeoExecutionPolicy = .default
    ) throws -> NumiSealResidualCEBuildResult {
        let material = try buildMaterial(
            publicStatement: publicStatement,
            aggregate: aggregate,
            decomposition: decomposition,
            digitTensor: digitTensor,
            linearResidual: linearResidual,
            sumcheckProof: sumcheckProof,
            aggregateClaim: aggregateClaim,
            shape: shape,
            key: key,
            parameters: parameters,
            executionPolicy: executionPolicy
        )
        let proof = try CEOpeningRelation.proveLocalBatchDeterministic(
            statement: material.terminalStatement,
            witnesses: [material.witness],
            shape: shape,
            key: key,
            parameters: parameters,
            randomSeed: randomSeed,
            metalWorkspace: metalWorkspace,
            executionPolicy: executionPolicy
        )
        return try buildResult(
            terminalStatement: material.terminalStatement,
            ceOpeningProof: proof,
            aggregate: aggregate,
            linearResidual: linearResidual,
            sumcheckProof: sumcheckProof
        )
    }

    static func proveImmediateOpeningForTesting(
        publicStatement: NumiSealPublicStatement,
        aggregate: NumiSealLaneAggregate,
        decomposition: NumiSealDecompositionCommitment,
        digitTensor: NumiSealDigitTensor,
        linearResidual: NumiSealLinearResidual,
        sumcheckProof: SumcheckProof,
        aggregateClaim: CCSEvaluationClaim,
        shape: CCSShape,
        key: AjtaiCommitmentKey,
        parameters: SuperNeoParameters = .goldilocks,
        randomSeed: [UInt8],
        metalWorkspace: SuperNeoMetalWorkspace? = nil,
        executionPolicy: SuperNeoExecutionPolicy = .default
    ) throws -> NumiSealResidualCEBuildResult {
        try proveImmediateOpeningDeterministic(
            publicStatement: publicStatement,
            aggregate: aggregate,
            decomposition: decomposition,
            digitTensor: digitTensor,
            linearResidual: linearResidual,
            sumcheckProof: sumcheckProof,
            aggregateClaim: aggregateClaim,
            shape: shape,
            key: key,
            parameters: parameters,
            randomSeed: randomSeed,
            metalWorkspace: metalWorkspace,
            executionPolicy: executionPolicy
        )
    }

    private struct BuildMaterial {
        let terminalStatement: TerminalCEStatement
        let witness: CEOpeningWitness
    }

    private static func buildMaterial(
        publicStatement: NumiSealPublicStatement,
        aggregate: NumiSealLaneAggregate,
        decomposition: NumiSealDecompositionCommitment,
        digitTensor: NumiSealDigitTensor,
        linearResidual: NumiSealLinearResidual,
        sumcheckProof: SumcheckProof,
        aggregateClaim: CCSEvaluationClaim,
        shape: CCSShape,
        key: AjtaiCommitmentKey,
        parameters: SuperNeoParameters,
        executionPolicy: SuperNeoExecutionPolicy
    ) throws -> BuildMaterial {
        try validatePublicContext(
            publicStatement: publicStatement,
            aggregate: aggregate,
            shape: shape,
            key: key,
            parameters: parameters
        )
        try linearResidual.validate(
            publicStatement: publicStatement,
            aggregate: aggregate,
            decomposition: decomposition
        )
        guard try NumiSealSumcheckOracle.verify(
            proof: sumcheckProof,
            linearResidual: linearResidual,
            digitTensor: digitTensor
        ) else {
            throw SuperNeoError.verificationFailed("NumiSeal residual sum-check verification failed")
        }
        guard try decomposition.verifiesOpening(
            digitTensor: digitTensor,
            parameters: parameters,
            executionPolicy: executionPolicy
        ) else {
            throw SuperNeoError.verificationFailed("NumiSeal residual decomposition opening failed")
        }
        guard CEInstance(aggregateClaim) == aggregate.aggregateInstance else {
            throw SuperNeoError.invalidParameter("NumiSeal residual aggregate claim does not match aggregate")
        }
        guard let witness = CEOpeningWitness(claim: aggregateClaim) else {
            throw SuperNeoError.invalidParameter("NumiSeal residual aggregate claim is missing witness")
        }
        guard try NumiSealAggregateEvaluationOracle.verifyAggregateOpening(
            aggregate: aggregate,
            witness: witness.witness,
            shape: shape,
            key: key,
            parameters: parameters,
            executionPolicy: executionPolicy
        ) else {
            throw SuperNeoError.verificationFailed("NumiSeal residual aggregate witness opening failed")
        }
        let terminalStatement = try TerminalCEStatement(
            profileID: publicStatement.profileID,
            shape: shape,
            key: key,
            claims: [aggregateClaim]
        )
        return BuildMaterial(terminalStatement: terminalStatement, witness: witness)
    }

    private static func buildResult(
        terminalStatement: TerminalCEStatement,
        ceOpeningProof: CEOpeningProof,
        aggregate: NumiSealLaneAggregate,
        linearResidual: NumiSealLinearResidual,
        sumcheckProof: SumcheckProof
    ) throws -> NumiSealResidualCEBuildResult {
        let residualOpening = try NumiSealResidualOpening(
            laneKey: aggregate.laneKey,
            aggregateIndex: aggregate.aggregateIndex,
            linearResidual: linearResidual,
            sumcheckProof: sumcheckProof,
            terminalStatement: terminalStatement,
            ceOpeningProof: ceOpeningProof
        )
        return NumiSealResidualCEBuildResult(
            terminalStatement: terminalStatement,
            ceOpeningProof: ceOpeningProof,
            residualOpening: residualOpening
        )
    }

    private static func validatePublicContext(
        publicStatement: NumiSealPublicStatement,
        aggregate: NumiSealLaneAggregate,
        shape: CCSShape,
        key: AjtaiCommitmentKey,
        parameters: SuperNeoParameters
    ) throws {
        guard publicStatement.profileID == parameters.profileID else {
            throw SuperNeoError.invalidParameter("NumiSeal residual public statement profile mismatch")
        }
        guard publicStatement.shapeDigest == shape.shapeDigest else {
            throw SuperNeoError.invalidParameter("NumiSeal residual public statement shape mismatch")
        }
        guard publicStatement.verifierKeyDigest == key.verifierKeyDigest else {
            throw SuperNeoError.invalidParameter("NumiSeal residual public statement verifier key mismatch")
        }
        guard key.parameters == parameters else {
            throw SuperNeoError.invalidParameter("NumiSeal residual key parameters mismatch")
        }
        guard key.matrix.columns == shape.nRing else {
            throw SuperNeoError.invalidParameter("NumiSeal residual key shape mismatch")
        }
        guard aggregate.laneKey.profileID == publicStatement.profileID else {
            throw SuperNeoError.invalidParameter("NumiSeal residual aggregate profile mismatch")
        }
        guard aggregate.laneKey.shapeDigest == publicStatement.shapeDigest else {
            throw SuperNeoError.invalidParameter("NumiSeal residual aggregate shape mismatch")
        }
        guard aggregate.laneKey.verifierKeyDigest == publicStatement.verifierKeyDigest else {
            throw SuperNeoError.invalidParameter("NumiSeal residual aggregate verifier key mismatch")
        }
        guard publicStatement.laneSummaries.contains(where: { $0.laneKey == aggregate.laneKey }) else {
            throw SuperNeoError.invalidParameter("NumiSeal residual aggregate lane is not covered by public statement")
        }
    }
}

private func numiSealResidualFrame(_ bytes: [UInt8]) -> [UInt8] {
    numiSealEncodeCount(bytes.count) + bytes
}
