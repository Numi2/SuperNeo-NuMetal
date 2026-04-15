import Foundation

public struct NumiSealScalarizationStatement: Equatable, Sendable, SuperNeoByteEncodable {
    public static let domain = Digest256.hash("SuperNeo-NuMetal.numiseal.scalarization-statement.v1")
    public static let version: UInt16 = 10

    public let version: UInt16
    public let publicStatementDigest: Digest256
    public let laneKey: NumiSealLaneKey
    public let aggregateIndex: Int
    public let aggregateDigest: Digest256
    public let decompositionKeyDigest: Digest256
    public let decompositionCommitmentDigest: Digest256
    public let aggregateCommitmentDigest: Digest256
    public let aggregatePublicInputDigest: Digest256
    public let aggregateMatrixEvaluationDigest: Digest256
    public let statementDigest: Digest256

    public init(
        publicStatement: NumiSealPublicStatement,
        aggregate: NumiSealLaneAggregate,
        decomposition: NumiSealDecompositionCommitment
    ) throws {
        try Self.validate(publicStatement: publicStatement, aggregate: aggregate, decomposition: decomposition)
        let aggregateCommitmentDigest = Self.aggregateCommitmentDigest(aggregate.aggregateCommitment)
        let aggregatePublicInputDigest = Self.aggregatePublicInputDigest(aggregate.aggregatePublicInputEncoding)
        let aggregateMatrixEvaluationDigest = Self.aggregateMatrixEvaluationDigest(aggregate.aggregateMatrixEvaluations)
        self.version = Self.version
        self.publicStatementDigest = publicStatement.digest
        self.laneKey = aggregate.laneKey
        self.aggregateIndex = aggregate.aggregateIndex
        self.aggregateDigest = aggregate.aggregateDigest
        self.decompositionKeyDigest = decomposition.decompositionKeyDigest
        self.decompositionCommitmentDigest = decomposition.commitmentDigest
        self.aggregateCommitmentDigest = aggregateCommitmentDigest
        self.aggregatePublicInputDigest = aggregatePublicInputDigest
        self.aggregateMatrixEvaluationDigest = aggregateMatrixEvaluationDigest
        self.statementDigest = Self.computeStatementDigest(
            publicStatementDigest: publicStatement.digest,
            laneKey: aggregate.laneKey,
            aggregateIndex: aggregate.aggregateIndex,
            aggregateDigest: aggregate.aggregateDigest,
            decompositionKeyDigest: decomposition.decompositionKeyDigest,
            decompositionCommitmentDigest: decomposition.commitmentDigest,
            aggregateCommitmentDigest: aggregateCommitmentDigest,
            aggregatePublicInputDigest: aggregatePublicInputDigest,
            aggregateMatrixEvaluationDigest: aggregateMatrixEvaluationDigest
        )
    }

    public init(bytes: [UInt8]) throws {
        var reader = ByteReader(bytes)
        let domain = try Digest256(reader.readData(count: Digest256.byteCount))
        guard domain == Self.domain else {
            throw SuperNeoError.invalidEncoding("NumiSeal scalarization statement domain mismatch")
        }
        let version = try reader.readUInt16()
        guard version == Self.version else {
            throw SuperNeoError.invalidEncoding("unsupported NumiSeal scalarization statement version")
        }
        let publicStatementDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        let laneKey = try reader.readNumiSealLaneKey()
        let aggregateIndex = try reader.readCount(
            maximum: NumiSealWireLimits.maximumAggregateCount,
            name: "NumiSeal scalarization aggregate index"
        )
        let aggregateDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        let decompositionKeyDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        let decompositionCommitmentDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        let aggregateCommitmentDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        let aggregatePublicInputDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        let aggregateMatrixEvaluationDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        let statementDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        try reader.finish()

        let expectedDigest = Self.computeStatementDigest(
            publicStatementDigest: publicStatementDigest,
            laneKey: laneKey,
            aggregateIndex: aggregateIndex,
            aggregateDigest: aggregateDigest,
            decompositionKeyDigest: decompositionKeyDigest,
            decompositionCommitmentDigest: decompositionCommitmentDigest,
            aggregateCommitmentDigest: aggregateCommitmentDigest,
            aggregatePublicInputDigest: aggregatePublicInputDigest,
            aggregateMatrixEvaluationDigest: aggregateMatrixEvaluationDigest
        )
        guard statementDigest == expectedDigest else {
            throw SuperNeoError.invalidEncoding("NumiSeal scalarization statement digest mismatch")
        }

        self.version = version
        self.publicStatementDigest = publicStatementDigest
        self.laneKey = laneKey
        self.aggregateIndex = aggregateIndex
        self.aggregateDigest = aggregateDigest
        self.decompositionKeyDigest = decompositionKeyDigest
        self.decompositionCommitmentDigest = decompositionCommitmentDigest
        self.aggregateCommitmentDigest = aggregateCommitmentDigest
        self.aggregatePublicInputDigest = aggregatePublicInputDigest
        self.aggregateMatrixEvaluationDigest = aggregateMatrixEvaluationDigest
        self.statementDigest = statementDigest
    }

    public var superNeoBytes: [UInt8] {
        Self.domain.superNeoBytes
            + Self.bodyBytes(
                publicStatementDigest: publicStatementDigest,
                laneKey: laneKey,
                aggregateIndex: aggregateIndex,
                aggregateDigest: aggregateDigest,
                decompositionKeyDigest: decompositionKeyDigest,
                decompositionCommitmentDigest: decompositionCommitmentDigest,
                aggregateCommitmentDigest: aggregateCommitmentDigest,
                aggregatePublicInputDigest: aggregatePublicInputDigest,
                aggregateMatrixEvaluationDigest: aggregateMatrixEvaluationDigest
            )
            + statementDigest.superNeoBytes
    }

    private static func validate(
        publicStatement: NumiSealPublicStatement,
        aggregate: NumiSealLaneAggregate,
        decomposition: NumiSealDecompositionCommitment
    ) throws {
        guard publicStatement.laneSummaries.contains(where: { $0.laneKey == aggregate.laneKey }) else {
            throw SuperNeoError.invalidParameter("NumiSeal scalarization aggregate lane is not covered by public statement")
        }
        guard aggregate.laneKey.profileID == publicStatement.profileID else {
            throw SuperNeoError.invalidParameter("NumiSeal scalarization profile mismatch")
        }
        guard aggregate.laneKey.shapeDigest == publicStatement.shapeDigest else {
            throw SuperNeoError.invalidParameter("NumiSeal scalarization shape mismatch")
        }
        guard aggregate.laneKey.verifierKeyDigest == publicStatement.verifierKeyDigest else {
            throw SuperNeoError.invalidParameter("NumiSeal scalarization verifier key mismatch")
        }
        guard decomposition.keyDerivation.verifierKeyDigest == publicStatement.verifierKeyDigest else {
            throw SuperNeoError.invalidParameter("NumiSeal scalarization decomposition verifier key mismatch")
        }
        guard decomposition.keyDerivation.laneKey == aggregate.laneKey else {
            throw SuperNeoError.invalidParameter("NumiSeal scalarization decomposition lane mismatch")
        }
        guard decomposition.keyDerivation.aggregateIndex == aggregate.aggregateIndex else {
            throw SuperNeoError.invalidParameter("NumiSeal scalarization decomposition aggregate mismatch")
        }
    }

    private static func computeStatementDigest(
        publicStatementDigest: Digest256,
        laneKey: NumiSealLaneKey,
        aggregateIndex: Int,
        aggregateDigest: Digest256,
        decompositionKeyDigest: Digest256,
        decompositionCommitmentDigest: Digest256,
        aggregateCommitmentDigest: Digest256,
        aggregatePublicInputDigest: Digest256,
        aggregateMatrixEvaluationDigest: Digest256
    ) -> Digest256 {
        NumiSealEncoding.digest(
            label: "numiseal.scalarization-statement.v1",
            bytes: bodyBytes(
                publicStatementDigest: publicStatementDigest,
                laneKey: laneKey,
                aggregateIndex: aggregateIndex,
                aggregateDigest: aggregateDigest,
                decompositionKeyDigest: decompositionKeyDigest,
                decompositionCommitmentDigest: decompositionCommitmentDigest,
                aggregateCommitmentDigest: aggregateCommitmentDigest,
                aggregatePublicInputDigest: aggregatePublicInputDigest,
                aggregateMatrixEvaluationDigest: aggregateMatrixEvaluationDigest
            )
        )
    }

    private static func bodyBytes(
        publicStatementDigest: Digest256,
        laneKey: NumiSealLaneKey,
        aggregateIndex: Int,
        aggregateDigest: Digest256,
        decompositionKeyDigest: Digest256,
        decompositionCommitmentDigest: Digest256,
        aggregateCommitmentDigest: Digest256,
        aggregatePublicInputDigest: Digest256,
        aggregateMatrixEvaluationDigest: Digest256
    ) -> [UInt8] {
        numiSealEncodeUInt16(Self.version)
            + publicStatementDigest.superNeoBytes
            + laneKey.superNeoBytes
            + numiSealEncodeCount(aggregateIndex)
            + aggregateDigest.superNeoBytes
            + decompositionKeyDigest.superNeoBytes
            + decompositionCommitmentDigest.superNeoBytes
            + aggregateCommitmentDigest.superNeoBytes
            + aggregatePublicInputDigest.superNeoBytes
            + aggregateMatrixEvaluationDigest.superNeoBytes
    }

    static func aggregateCommitmentDigest(_ commitment: AjtaiCommitment) -> Digest256 {
        NumiSealEncoding.digest(
            label: "numiseal.scalarization.aggregate-commitment.v1",
            bytes: commitment.superNeoBytes
        )
    }

    static func aggregatePublicInputDigest(_ publicInputEncoding: PublicInputEncoding) -> Digest256 {
        NumiSealEncoding.digest(
            label: "numiseal.scalarization.public-input.v1",
            bytes: publicInputEncoding.superNeoBytes
        )
    }

    static func aggregateMatrixEvaluationDigest(_ evaluations: [CyclotomicExt2Ring54]) -> Digest256 {
        NumiSealEncoding.digest(
            label: "numiseal.scalarization.matrix-evaluations.v1",
            bytes: numiSealEncodeCount(evaluations.count) + evaluations.flatMap(\.superNeoBytes)
        )
    }
}

public struct NumiSealScalarizationWeights: Equatable, Sendable, SuperNeoByteEncodable {
    public let statementDigest: Digest256
    public let aggregateCommitmentWeights: [GoldilocksExt2]
    public let decompositionCommitmentWeights: [GoldilocksExt2]
    public let publicInputWeights: [GoldilocksExt2]
    public let matrixEvaluationWeights: [GoldilocksExt2]
    public let weightDigest: Digest256

    public init(
        statement: NumiSealScalarizationStatement,
        aggregate: NumiSealLaneAggregate,
        decomposition: NumiSealDecompositionCommitment
    ) throws {
        try Self.validate(statement: statement, aggregate: aggregate, decomposition: decomposition)
        let aggregateCommitmentCount = aggregate.aggregateCommitment.elements.count * CyclotomicRing54.degree
        let decompositionCommitmentCount = decomposition.commitment.elements.count * CyclotomicRing54.degree
        let publicInputCount = aggregate.aggregatePublicInputEncoding.field.count
        let matrixEvaluationCount = aggregate.aggregateMatrixEvaluations.count * CyclotomicRing54.degree

        var transcript = SumCheckTranscript(domainSeparator: "SuperNeo-NuMetal.numiseal.scalarization.v1")
        transcript.absorb(statement.statementDigest.superNeoBytes)
        transcript.absorb(statement.publicStatementDigest.superNeoBytes)
        transcript.absorb(aggregate.aggregateDigest.superNeoBytes)
        transcript.absorb(decomposition.commitmentDigest.superNeoBytes)
        transcript.absorb(statement.laneKey.superNeoBytes)
        transcript.absorb(numiSealEncodeCount(statement.aggregateIndex))
        transcript.absorb(numiSealEncodeCount(aggregateCommitmentCount))
        transcript.absorb(numiSealEncodeCount(decompositionCommitmentCount))
        transcript.absorb(numiSealEncodeCount(publicInputCount))
        transcript.absorb(numiSealEncodeCount(matrixEvaluationCount))

        self.statementDigest = statement.statementDigest
        self.aggregateCommitmentWeights = Self.nextWeights(count: aggregateCommitmentCount, transcript: &transcript)
        self.decompositionCommitmentWeights = Self.nextWeights(count: decompositionCommitmentCount, transcript: &transcript)
        self.publicInputWeights = Self.nextWeights(count: publicInputCount, transcript: &transcript)
        self.matrixEvaluationWeights = Self.nextWeights(count: matrixEvaluationCount, transcript: &transcript)
        self.weightDigest = Self.computeWeightDigest(
            statementDigest: statement.statementDigest,
            aggregateCommitmentWeights: aggregateCommitmentWeights,
            decompositionCommitmentWeights: decompositionCommitmentWeights,
            publicInputWeights: publicInputWeights,
            matrixEvaluationWeights: matrixEvaluationWeights
        )
    }

    public var superNeoBytes: [UInt8] {
        Self.bodyBytes(
            statementDigest: statementDigest,
            aggregateCommitmentWeights: aggregateCommitmentWeights,
            decompositionCommitmentWeights: decompositionCommitmentWeights,
            publicInputWeights: publicInputWeights,
            matrixEvaluationWeights: matrixEvaluationWeights
        ) + weightDigest.superNeoBytes
    }

    private static func nextWeights(
        count: Int,
        transcript: inout SumCheckTranscript
    ) -> [GoldilocksExt2] {
        (0..<count).map { _ in transcript.challengeExt2() }
    }

    private static func validate(
        statement: NumiSealScalarizationStatement,
        aggregate: NumiSealLaneAggregate,
        decomposition: NumiSealDecompositionCommitment
    ) throws {
        guard statement.laneKey == aggregate.laneKey else {
            throw SuperNeoError.invalidParameter("NumiSeal scalarization aggregate lane mismatch")
        }
        guard statement.aggregateIndex == aggregate.aggregateIndex else {
            throw SuperNeoError.invalidParameter("NumiSeal scalarization aggregate index mismatch")
        }
        guard statement.aggregateDigest == aggregate.aggregateDigest else {
            throw SuperNeoError.invalidParameter("NumiSeal scalarization aggregate digest mismatch")
        }
        guard statement.decompositionKeyDigest == decomposition.decompositionKeyDigest else {
            throw SuperNeoError.invalidParameter("NumiSeal scalarization decomposition key digest mismatch")
        }
        guard statement.decompositionCommitmentDigest == decomposition.commitmentDigest else {
            throw SuperNeoError.invalidParameter("NumiSeal scalarization decomposition digest mismatch")
        }
        guard statement.aggregateCommitmentDigest == NumiSealScalarizationStatement.aggregateCommitmentDigest(
            aggregate.aggregateCommitment
        ) else {
            throw SuperNeoError.invalidParameter("NumiSeal scalarization aggregate commitment digest mismatch")
        }
        guard statement.aggregatePublicInputDigest == NumiSealScalarizationStatement.aggregatePublicInputDigest(
            aggregate.aggregatePublicInputEncoding
        ) else {
            throw SuperNeoError.invalidParameter("NumiSeal scalarization public input digest mismatch")
        }
        guard statement.aggregateMatrixEvaluationDigest == NumiSealScalarizationStatement.aggregateMatrixEvaluationDigest(
            aggregate.aggregateMatrixEvaluations
        ) else {
            throw SuperNeoError.invalidParameter("NumiSeal scalarization matrix evaluation digest mismatch")
        }
    }

    private static func computeWeightDigest(
        statementDigest: Digest256,
        aggregateCommitmentWeights: [GoldilocksExt2],
        decompositionCommitmentWeights: [GoldilocksExt2],
        publicInputWeights: [GoldilocksExt2],
        matrixEvaluationWeights: [GoldilocksExt2]
    ) -> Digest256 {
        NumiSealEncoding.digest(
            label: "numiseal.scalarization-weights.v1",
            bytes: bodyBytes(
                statementDigest: statementDigest,
                aggregateCommitmentWeights: aggregateCommitmentWeights,
                decompositionCommitmentWeights: decompositionCommitmentWeights,
                publicInputWeights: publicInputWeights,
                matrixEvaluationWeights: matrixEvaluationWeights
            )
        )
    }

    private static func bodyBytes(
        statementDigest: Digest256,
        aggregateCommitmentWeights: [GoldilocksExt2],
        decompositionCommitmentWeights: [GoldilocksExt2],
        publicInputWeights: [GoldilocksExt2],
        matrixEvaluationWeights: [GoldilocksExt2]
    ) -> [UInt8] {
        statementDigest.superNeoBytes
            + numiSealEncodeCount(aggregateCommitmentWeights.count)
            + aggregateCommitmentWeights.flatMap(\.superNeoBytes)
            + numiSealEncodeCount(decompositionCommitmentWeights.count)
            + decompositionCommitmentWeights.flatMap(\.superNeoBytes)
            + numiSealEncodeCount(publicInputWeights.count)
            + publicInputWeights.flatMap(\.superNeoBytes)
            + numiSealEncodeCount(matrixEvaluationWeights.count)
            + matrixEvaluationWeights.flatMap(\.superNeoBytes)
    }
}

public struct NumiSealLinearResidual: Equatable, Sendable, SuperNeoByteEncodable {
    public static let domain = Digest256.hash("SuperNeo-NuMetal.numiseal.linear-residual.v1")
    public static let version: UInt16 = 10

    public let version: UInt16
    public let statement: NumiSealScalarizationStatement
    public let weightsDigest: Digest256
    public let residualValue: GoldilocksExt2
    public let residualDigest: Digest256

    public init(
        publicStatement: NumiSealPublicStatement,
        aggregate: NumiSealLaneAggregate,
        decomposition: NumiSealDecompositionCommitment
    ) throws {
        let statement = try NumiSealScalarizationStatement(
            publicStatement: publicStatement,
            aggregate: aggregate,
            decomposition: decomposition
        )
        let weights = try NumiSealScalarizationWeights(
            statement: statement,
            aggregate: aggregate,
            decomposition: decomposition
        )
        let residualValue = try Self.computeResidualValue(
            aggregate: aggregate,
            decomposition: decomposition,
            weights: weights
        )
        self.version = Self.version
        self.statement = statement
        self.weightsDigest = weights.weightDigest
        self.residualValue = residualValue
        self.residualDigest = Self.computeResidualDigest(
            statementDigest: statement.statementDigest,
            weightsDigest: weights.weightDigest,
            residualValue: residualValue
        )
    }

    public init(bytes: [UInt8]) throws {
        var reader = ByteReader(bytes)
        let domain = try Digest256(reader.readData(count: Digest256.byteCount))
        guard domain == Self.domain else {
            throw SuperNeoError.invalidEncoding("NumiSeal linear residual domain mismatch")
        }
        let version = try reader.readUInt16()
        guard version == Self.version else {
            throw SuperNeoError.invalidEncoding("unsupported NumiSeal linear residual version")
        }
        let statementByteCount = try reader.readCount(
            maximum: NumiSealWireLimits.maximumProofComponentByteCount,
            name: "NumiSeal scalarization statement byte",
            elementByteWidth: 1
        )
        guard statementByteCount > 0 else {
            throw SuperNeoError.invalidEncoding("NumiSeal scalarization statement cannot be empty")
        }
        let statement = try NumiSealScalarizationStatement(
            bytes: reader.readData(count: statementByteCount)
        )
        let weightsDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        let residualValue = try reader.readNumiSealExt2()
        let residualDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        try reader.finish()

        let expectedDigest = Self.computeResidualDigest(
            statementDigest: statement.statementDigest,
            weightsDigest: weightsDigest,
            residualValue: residualValue
        )
        guard residualDigest == expectedDigest else {
            throw SuperNeoError.invalidEncoding("NumiSeal linear residual digest mismatch")
        }

        self.version = version
        self.statement = statement
        self.weightsDigest = weightsDigest
        self.residualValue = residualValue
        self.residualDigest = residualDigest
    }

    public func validate(
        publicStatement: NumiSealPublicStatement,
        aggregate: NumiSealLaneAggregate,
        decomposition: NumiSealDecompositionCommitment
    ) throws {
        let expected = try Self(
            publicStatement: publicStatement,
            aggregate: aggregate,
            decomposition: decomposition
        )
        guard self == expected else {
            throw SuperNeoError.verificationFailed("NumiSeal linear residual mismatch")
        }
    }

    public var superNeoBytes: [UInt8] {
        let statementBytes = statement.superNeoBytes
        var bytes = Self.domain.superNeoBytes
        bytes += numiSealEncodeUInt16(version)
        bytes += numiSealEncodeCount(statementBytes.count)
        bytes += statementBytes
        bytes += weightsDigest.superNeoBytes
        bytes += residualValue.superNeoBytes
        bytes += residualDigest.superNeoBytes
        return bytes
    }

    static func computeResidualValue(
        aggregate: NumiSealLaneAggregate,
        decomposition: NumiSealDecompositionCommitment,
        weights: NumiSealScalarizationWeights
    ) throws -> GoldilocksExt2 {
        var accumulator = GoldilocksExt2.zero
        try addRingVector(
            aggregate.aggregateCommitment.elements,
            weights: weights.aggregateCommitmentWeights,
            into: &accumulator,
            name: "NumiSeal aggregate commitment scalarization"
        )
        try addRingVector(
            decomposition.commitment.elements,
            weights: weights.decompositionCommitmentWeights,
            into: &accumulator,
            name: "NumiSeal decomposition commitment scalarization"
        )
        guard aggregate.aggregatePublicInputEncoding.field.count == weights.publicInputWeights.count else {
            throw SuperNeoError.invalidParameter("NumiSeal public input scalarization weight mismatch")
        }
        for (value, weight) in zip(aggregate.aggregatePublicInputEncoding.field, weights.publicInputWeights) {
            accumulator = accumulator + weight.scaled(by: value)
        }
        try addExt2RingVector(
            aggregate.aggregateMatrixEvaluations,
            weights: weights.matrixEvaluationWeights,
            into: &accumulator,
            name: "NumiSeal matrix evaluation scalarization"
        )
        return accumulator
    }

    private static func addRingVector(
        _ rings: [CyclotomicRing54],
        weights: [GoldilocksExt2],
        into accumulator: inout GoldilocksExt2,
        name: String
    ) throws {
        guard weights.count == rings.count * CyclotomicRing54.degree else {
            throw SuperNeoError.invalidParameter("\(name) weight mismatch")
        }
        var weightIndex = 0
        for ring in rings {
            for coefficient in ring.coefficients {
                accumulator = accumulator + weights[weightIndex].scaled(by: coefficient)
                weightIndex += 1
            }
        }
    }

    private static func addExt2RingVector(
        _ rings: [CyclotomicExt2Ring54],
        weights: [GoldilocksExt2],
        into accumulator: inout GoldilocksExt2,
        name: String
    ) throws {
        guard weights.count == rings.count * CyclotomicRing54.degree else {
            throw SuperNeoError.invalidParameter("\(name) weight mismatch")
        }
        var weightIndex = 0
        for ring in rings {
            for coefficient in ring.coefficients {
                accumulator = accumulator + weights[weightIndex] * coefficient
                weightIndex += 1
            }
        }
    }

    private static func computeResidualDigest(
        statementDigest: Digest256,
        weightsDigest: Digest256,
        residualValue: GoldilocksExt2
    ) -> Digest256 {
        NumiSealEncoding.digest(
            label: "numiseal.linear-residual.v1",
            bytes: numiSealEncodeUInt16(Self.version)
                + statementDigest.superNeoBytes
                + weightsDigest.superNeoBytes
                + residualValue.superNeoBytes
        )
    }
}
