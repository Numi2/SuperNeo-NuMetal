import Foundation

public struct NumiSealResidualCEShape: Equatable, Sendable, SuperNeoByteEncodable {
    public static let domain = Digest256.hash("SuperNeo-NuMetal.numiseal.residual-ce-shape.v1")
    public static let version: UInt16 = 11

    public let version: UInt16
    public let profileID: UInt16
    public let laneKey: NumiSealLaneKey
    public let aggregateIndex: Int
    public let columnCount: Int
    public let activeDigitCount: Int
    public let slotCount: Int
    public let paddedSlotCount: Int
    public let variableCount: Int
    public let sumcheckFinalPointDigest: Digest256
    public let digitOpeningShapeDigest: Digest256
    public let residualShapeDigest: Digest256

    public init(
        laneKey: NumiSealLaneKey,
        aggregateIndex: Int,
        digitTensor: NumiSealDigitTensor,
        sumcheckFinalPoint: [GoldilocksExt2]
    ) throws {
        guard digitTensor.laneKey == laneKey else {
            throw SuperNeoError.invalidParameter("NumiSeal residual CE shape digit tensor lane mismatch")
        }
        guard digitTensor.aggregateIndex == aggregateIndex else {
            throw SuperNeoError.invalidParameter("NumiSeal residual CE shape digit tensor aggregate mismatch")
        }
        let slotCount = try Self.checkedSlotCount(columnCount: digitTensor.columnCount)
        let paddedSlotCount = Self.nextPowerOfTwo(slotCount)
        let variableCount = try Self.log2Exact(paddedSlotCount)
        let sumcheckFinalPointDigest = NumiSealCanonicalization.evalPointDigest(sumcheckFinalPoint)
        let digitOpeningShapeDigest = try Self.digitOpeningShape(
            columnCount: digitTensor.columnCount,
            paddedSlotCount: paddedSlotCount
        ).shapeDigest
        try Self.validate(
            profileID: laneKey.profileID,
            laneKey: laneKey,
            aggregateIndex: aggregateIndex,
            columnCount: digitTensor.columnCount,
            activeDigitCount: digitTensor.activeDigitCount,
            slotCount: slotCount,
            paddedSlotCount: paddedSlotCount,
            variableCount: variableCount,
            sumcheckFinalPointDigest: sumcheckFinalPointDigest,
            digitOpeningShapeDigest: digitOpeningShapeDigest
        )
        guard sumcheckFinalPoint.count == variableCount else {
            throw SuperNeoError.invalidParameter("NumiSeal residual CE shape final point length mismatch")
        }

        self.version = Self.version
        self.profileID = laneKey.profileID
        self.laneKey = laneKey
        self.aggregateIndex = aggregateIndex
        self.columnCount = digitTensor.columnCount
        self.activeDigitCount = digitTensor.activeDigitCount
        self.slotCount = slotCount
        self.paddedSlotCount = paddedSlotCount
        self.variableCount = variableCount
        self.sumcheckFinalPointDigest = sumcheckFinalPointDigest
        self.digitOpeningShapeDigest = digitOpeningShapeDigest
        self.residualShapeDigest = Self.computeResidualShapeDigest(
            profileID: laneKey.profileID,
            laneKey: laneKey,
            aggregateIndex: aggregateIndex,
            columnCount: digitTensor.columnCount,
            activeDigitCount: digitTensor.activeDigitCount,
            slotCount: slotCount,
            paddedSlotCount: paddedSlotCount,
            variableCount: variableCount,
            sumcheckFinalPointDigest: sumcheckFinalPointDigest,
            digitOpeningShapeDigest: digitOpeningShapeDigest
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
        let columnCount = try reader.readCount(
            maximum: NumiSealWireLimits.maximumDigitTensorColumnCount,
            name: "NumiSeal residual CE digit column"
        )
        let activeDigitCount = try reader.readCount(
            maximum: try Self.checkedSlotCount(columnCount: columnCount),
            name: "NumiSeal residual CE active digit"
        )
        let slotCount = try reader.readCount(
            maximum: NumiSealWireLimits.maximumDigitTensorColumnCount * CyclotomicRing54.degree,
            name: "NumiSeal residual CE digit slot"
        )
        let paddedSlotCount = try reader.readCount(
            maximum: 1 << NumiSealSumcheckOracle.maximumReferenceVariableCount,
            name: "NumiSeal residual CE padded digit slot"
        )
        let variableCount = try reader.readCount(
            maximum: NumiSealSumcheckOracle.maximumReferenceVariableCount,
            name: "NumiSeal residual CE variable"
        )
        let sumcheckFinalPointDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        let digitOpeningShapeDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        let residualShapeDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        try reader.finish()

        try Self.validate(
            profileID: profileID,
            laneKey: laneKey,
            aggregateIndex: aggregateIndex,
            columnCount: columnCount,
            activeDigitCount: activeDigitCount,
            slotCount: slotCount,
            paddedSlotCount: paddedSlotCount,
            variableCount: variableCount,
            sumcheckFinalPointDigest: sumcheckFinalPointDigest,
            digitOpeningShapeDigest: digitOpeningShapeDigest
        )
        let expectedDigest = Self.computeResidualShapeDigest(
            profileID: profileID,
            laneKey: laneKey,
            aggregateIndex: aggregateIndex,
            columnCount: columnCount,
            activeDigitCount: activeDigitCount,
            slotCount: slotCount,
            paddedSlotCount: paddedSlotCount,
            variableCount: variableCount,
            sumcheckFinalPointDigest: sumcheckFinalPointDigest,
            digitOpeningShapeDigest: digitOpeningShapeDigest
        )
        guard residualShapeDigest == expectedDigest else {
            throw SuperNeoError.invalidEncoding("NumiSeal residual CE shape digest mismatch")
        }

        self.version = version
        self.profileID = profileID
        self.laneKey = laneKey
        self.aggregateIndex = aggregateIndex
        self.columnCount = columnCount
        self.activeDigitCount = activeDigitCount
        self.slotCount = slotCount
        self.paddedSlotCount = paddedSlotCount
        self.variableCount = variableCount
        self.sumcheckFinalPointDigest = sumcheckFinalPointDigest
        self.digitOpeningShapeDigest = digitOpeningShapeDigest
        self.residualShapeDigest = residualShapeDigest
    }

    public func validate(digitOpeningStatement: TerminalCEStatement) throws {
        guard digitOpeningStatement.profileID == profileID else {
            throw SuperNeoError.verificationFailed("NumiSeal residual CE digit statement profile mismatch")
        }
        guard digitOpeningStatement.shapeDigest == digitOpeningShapeDigest else {
            throw SuperNeoError.verificationFailed("NumiSeal residual CE digit statement shape mismatch")
        }
        guard digitOpeningStatement.openings.count == 1 else {
            throw SuperNeoError.verificationFailed("NumiSeal residual CE digit statement opening count mismatch")
        }
        let opening = digitOpeningStatement.openings[0]
        guard opening.instance.publicInput.isEmpty else {
            throw SuperNeoError.verificationFailed("NumiSeal residual CE digit statement public input mismatch")
        }
        guard opening.instance.evalPoint.count == variableCount else {
            throw SuperNeoError.verificationFailed("NumiSeal residual CE digit statement final point mismatch")
        }
        guard NumiSealCanonicalization.evalPointDigest(opening.instance.evalPoint) == sumcheckFinalPointDigest else {
            throw SuperNeoError.verificationFailed("NumiSeal residual CE digit statement final point digest mismatch")
        }
        guard opening.instance.matrixEvals.count == 1 else {
            throw SuperNeoError.verificationFailed("NumiSeal residual CE digit statement matrix arity mismatch")
        }
    }

    public var superNeoBytes: [UInt8] {
        Self.domain.superNeoBytes
            + Self.bodyBytes(
                profileID: profileID,
                laneKey: laneKey,
                aggregateIndex: aggregateIndex,
                columnCount: columnCount,
                activeDigitCount: activeDigitCount,
                slotCount: slotCount,
                paddedSlotCount: paddedSlotCount,
                variableCount: variableCount,
                sumcheckFinalPointDigest: sumcheckFinalPointDigest,
                digitOpeningShapeDigest: digitOpeningShapeDigest
            )
            + residualShapeDigest.superNeoBytes
    }

    private static func validate(
        profileID: UInt16,
        laneKey: NumiSealLaneKey,
        aggregateIndex: Int,
        columnCount: Int,
        activeDigitCount: Int,
        slotCount: Int,
        paddedSlotCount: Int,
        variableCount: Int,
        sumcheckFinalPointDigest: Digest256,
        digitOpeningShapeDigest: Digest256
    ) throws {
        guard profileID == laneKey.profileID else {
            throw SuperNeoError.invalidEncoding("NumiSeal residual CE shape profile mismatch")
        }
        guard aggregateIndex >= 0 else {
            throw SuperNeoError.invalidEncoding("NumiSeal residual CE shape aggregate index must be non-negative")
        }
        let expectedSlotCount = try checkedSlotCount(columnCount: columnCount)
        guard slotCount == expectedSlotCount else {
            throw SuperNeoError.invalidEncoding("NumiSeal residual CE shape slot count mismatch")
        }
        guard activeDigitCount >= 0, activeDigitCount <= slotCount else {
            throw SuperNeoError.invalidEncoding("NumiSeal residual CE active digit count exceeds tensor size")
        }
        let expectedPaddedSlotCount = nextPowerOfTwo(slotCount)
        guard paddedSlotCount == expectedPaddedSlotCount else {
            throw SuperNeoError.invalidEncoding("NumiSeal residual CE padded slot count mismatch")
        }
        let expectedVariableCount = try log2Exact(paddedSlotCount)
        guard variableCount == expectedVariableCount else {
            throw SuperNeoError.invalidEncoding("NumiSeal residual CE variable count mismatch")
        }
        guard variableCount <= NumiSealSumcheckOracle.maximumReferenceVariableCount else {
            throw SuperNeoError.invalidEncoding("NumiSeal residual CE variable count is too large")
        }
        let expectedShapeDigest = try digitOpeningShape(
            columnCount: columnCount,
            paddedSlotCount: paddedSlotCount
        ).shapeDigest
        guard digitOpeningShapeDigest == expectedShapeDigest else {
            throw SuperNeoError.invalidEncoding("NumiSeal residual CE digit opening shape mismatch")
        }
    }

    private static func computeResidualShapeDigest(
        profileID: UInt16,
        laneKey: NumiSealLaneKey,
        aggregateIndex: Int,
        columnCount: Int,
        activeDigitCount: Int,
        slotCount: Int,
        paddedSlotCount: Int,
        variableCount: Int,
        sumcheckFinalPointDigest: Digest256,
        digitOpeningShapeDigest: Digest256
    ) -> Digest256 {
        NumiSealEncoding.digest(
            label: "numiseal.residual-ce-shape.v1",
            bytes: bodyBytes(
                profileID: profileID,
                laneKey: laneKey,
                aggregateIndex: aggregateIndex,
                columnCount: columnCount,
                activeDigitCount: activeDigitCount,
                slotCount: slotCount,
                paddedSlotCount: paddedSlotCount,
                variableCount: variableCount,
                sumcheckFinalPointDigest: sumcheckFinalPointDigest,
                digitOpeningShapeDigest: digitOpeningShapeDigest
            )
        )
    }

    private static func bodyBytes(
        profileID: UInt16,
        laneKey: NumiSealLaneKey,
        aggregateIndex: Int,
        columnCount: Int,
        activeDigitCount: Int,
        slotCount: Int,
        paddedSlotCount: Int,
        variableCount: Int,
        sumcheckFinalPointDigest: Digest256,
        digitOpeningShapeDigest: Digest256
    ) -> [UInt8] {
        numiSealEncodeUInt16(Self.version)
            + numiSealEncodeUInt16(profileID)
            + laneKey.superNeoBytes
            + numiSealEncodeCount(aggregateIndex)
            + numiSealEncodeCount(columnCount)
            + numiSealEncodeCount(activeDigitCount)
            + numiSealEncodeCount(slotCount)
            + numiSealEncodeCount(paddedSlotCount)
            + numiSealEncodeCount(variableCount)
            + sumcheckFinalPointDigest.superNeoBytes
            + digitOpeningShapeDigest.superNeoBytes
    }

    public static func digitOpeningShape(
        columnCount: Int,
        paddedSlotCount: Int
    ) throws -> CCSShape {
        let slotCount = try checkedSlotCount(columnCount: columnCount)
        guard paddedSlotCount >= slotCount, (paddedSlotCount & (paddedSlotCount - 1)) == 0 else {
            throw SuperNeoError.invalidParameter("NumiSeal residual CE padded slot count mismatch")
        }
        let entries = (0..<slotCount).map {
            SparseFieldMatrix.Entry(row: $0, column: $0, value: .one)
        }
        let matrix = try SparseFieldMatrix(
            rows: paddedSlotCount,
            columns: slotCount,
            entries: entries
        )
        return try CCSShape(
            m: paddedSlotCount,
            nField: slotCount,
            nRing: columnCount,
            nPublicField: 0,
            matrices: [try SparseMatrixCSR(matrix)],
            relationPolynomial: try RelationPolynomial.hadamardProduct(variableCount: 1),
            hasIdentityFirstMatrix: false
        )
    }

    static func checkedSlotCount(columnCount: Int) throws -> Int {
        guard columnCount > 0 else {
            throw SuperNeoError.invalidParameter("NumiSeal digit tensor column count must be positive")
        }
        guard columnCount <= NumiSealWireLimits.maximumDigitTensorColumnCount else {
            throw SuperNeoError.invalidParameter("NumiSeal digit tensor column count is too large")
        }
        let product = columnCount.multipliedReportingOverflow(by: CyclotomicRing54.degree)
        guard !product.overflow else {
            throw SuperNeoError.invalidParameter("NumiSeal digit tensor dimensions overflow")
        }
        return product.partialValue
    }

    static func nextPowerOfTwo(_ value: Int) -> Int {
        var power = 1
        while power < value {
            power <<= 1
        }
        return power
    }

    static func log2Exact(_ value: Int) throws -> Int {
        guard value > 0, (value & (value - 1)) == 0 else {
            throw SuperNeoError.invalidParameter("NumiSeal residual CE slot count must be a positive power of two")
        }
        var exponent = 0
        var remaining = value
        while remaining > 1 {
            remaining >>= 1
            exponent += 1
        }
        return exponent
    }
}

public struct NumiSealResidualCEStatement: Equatable, Sendable, SuperNeoByteEncodable {
    public static let domain = Digest256.hash("SuperNeo-NuMetal.numiseal.residual-ce-statement.v1")
    public static let version: UInt16 = 11

    public let version: UInt16
    public let residualShape: NumiSealResidualCEShape
    public let publicStatementDigest: Digest256
    public let aggregateDigest: Digest256
    public let decompositionKeyDigest: Digest256
    public let decompositionCommitmentDigest: Digest256
    public let digitTensorDigest: Digest256
    public let scalarizationStatementDigest: Digest256
    public let linearResidualDigest: Digest256
    public let sumcheckProofDigest: Digest256
    public let sumcheckFinalPoint: [GoldilocksExt2]
    public let claimedDigitEvaluation: GoldilocksExt2
    public let digitOpeningStatementDigest: Digest256
    public let statementDigest: Digest256

    public init(
        linearResidual: NumiSealLinearResidual,
        sumcheckProof: SumcheckProof,
        decomposition: NumiSealDecompositionCommitment,
        digitTensor: NumiSealDigitTensor,
        claimedDigitEvaluation: GoldilocksExt2,
        digitOpeningStatement: TerminalCEStatement
    ) throws {
        guard sumcheckProof.claimedSum == linearResidual.residualValue else {
            throw SuperNeoError.invalidParameter("NumiSeal residual CE statement sum-check claimed sum mismatch")
        }
        let scalarizationStatement = linearResidual.statement
        guard digitTensor.laneKey == scalarizationStatement.laneKey else {
            throw SuperNeoError.invalidParameter("NumiSeal residual CE statement digit tensor lane mismatch")
        }
        guard digitTensor.aggregateIndex == scalarizationStatement.aggregateIndex else {
            throw SuperNeoError.invalidParameter("NumiSeal residual CE statement digit tensor aggregate mismatch")
        }
        guard decomposition.keyDerivation.laneKey == scalarizationStatement.laneKey else {
            throw SuperNeoError.invalidParameter("NumiSeal residual CE statement decomposition lane mismatch")
        }
        guard decomposition.keyDerivation.aggregateIndex == scalarizationStatement.aggregateIndex else {
            throw SuperNeoError.invalidParameter("NumiSeal residual CE statement decomposition aggregate mismatch")
        }
        guard decomposition.digitTensorDigest == digitTensor.digest else {
            throw SuperNeoError.invalidParameter("NumiSeal residual CE statement digit tensor digest mismatch")
        }
        let residualShape = try NumiSealResidualCEShape(
            laneKey: scalarizationStatement.laneKey,
            aggregateIndex: scalarizationStatement.aggregateIndex,
            digitTensor: digitTensor,
            sumcheckFinalPoint: sumcheckProof.finalPoint
        )
        let sumcheckProofDigest = NumiSealResidualOpening.sumcheckProofDigest(sumcheckProof)
        try residualShape.validate(digitOpeningStatement: digitOpeningStatement)
        guard digitOpeningStatement.openings[0].instance.matrixEvals[0].constantTerm == claimedDigitEvaluation else {
            throw SuperNeoError.invalidParameter("NumiSeal residual CE statement digit evaluation mismatch")
        }
        guard try NumiSealSumcheckOracle.verifyFinalOpening(
            proof: sumcheckProof,
            linearResidualDigest: linearResidual.residualDigest,
            scalarizationStatementDigest: scalarizationStatement.statementDigest,
            digitTensorDigest: digitTensor.digest,
            laneKey: scalarizationStatement.laneKey,
            aggregateIndex: scalarizationStatement.aggregateIndex,
            columnCount: digitTensor.columnCount,
            activeDigitCount: digitTensor.activeDigitCount,
            claimedDigitEvaluation: claimedDigitEvaluation
        ) else {
            throw SuperNeoError.verificationFailed("NumiSeal residual sum-check final opening failed")
        }
        let digitOpeningStatementDigest = digitOpeningStatement.statementDigest
        self.version = Self.version
        self.residualShape = residualShape
        self.publicStatementDigest = scalarizationStatement.publicStatementDigest
        self.aggregateDigest = scalarizationStatement.aggregateDigest
        self.decompositionKeyDigest = scalarizationStatement.decompositionKeyDigest
        self.decompositionCommitmentDigest = scalarizationStatement.decompositionCommitmentDigest
        self.digitTensorDigest = digitTensor.digest
        self.scalarizationStatementDigest = scalarizationStatement.statementDigest
        self.linearResidualDigest = linearResidual.residualDigest
        self.sumcheckProofDigest = sumcheckProofDigest
        self.sumcheckFinalPoint = sumcheckProof.finalPoint
        self.claimedDigitEvaluation = claimedDigitEvaluation
        self.digitOpeningStatementDigest = digitOpeningStatementDigest
        self.statementDigest = Self.computeStatementDigest(
            residualShape: residualShape,
            publicStatementDigest: publicStatementDigest,
            aggregateDigest: aggregateDigest,
            decompositionKeyDigest: decompositionKeyDigest,
            decompositionCommitmentDigest: decompositionCommitmentDigest,
            digitTensorDigest: digitTensor.digest,
            scalarizationStatementDigest: scalarizationStatement.statementDigest,
            linearResidualDigest: linearResidualDigest,
            sumcheckProofDigest: sumcheckProofDigest,
            sumcheckFinalPoint: sumcheckProof.finalPoint,
            claimedDigitEvaluation: claimedDigitEvaluation,
            digitOpeningStatementDigest: digitOpeningStatementDigest
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
        let digitTensorDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        let scalarizationStatementDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        let linearResidualDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        let sumcheckProofDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        let sumcheckFinalPoint = try reader.readNumiSealEvaluationPoint()
        let claimedDigitEvaluation = try reader.readNumiSealExt2()
        let digitOpeningStatementDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        let statementDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        try reader.finish()

        let expectedDigest = Self.computeStatementDigest(
            residualShape: residualShape,
            publicStatementDigest: publicStatementDigest,
            aggregateDigest: aggregateDigest,
            decompositionKeyDigest: decompositionKeyDigest,
            decompositionCommitmentDigest: decompositionCommitmentDigest,
            digitTensorDigest: digitTensorDigest,
            scalarizationStatementDigest: scalarizationStatementDigest,
            linearResidualDigest: linearResidualDigest,
            sumcheckProofDigest: sumcheckProofDigest,
            sumcheckFinalPoint: sumcheckFinalPoint,
            claimedDigitEvaluation: claimedDigitEvaluation,
            digitOpeningStatementDigest: digitOpeningStatementDigest
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
        self.digitTensorDigest = digitTensorDigest
        self.scalarizationStatementDigest = scalarizationStatementDigest
        self.linearResidualDigest = linearResidualDigest
        self.sumcheckProofDigest = sumcheckProofDigest
        self.sumcheckFinalPoint = sumcheckFinalPoint
        self.claimedDigitEvaluation = claimedDigitEvaluation
        self.digitOpeningStatementDigest = digitOpeningStatementDigest
        self.statementDigest = statementDigest
    }

    public func validate(
        linearResidual: NumiSealLinearResidual,
        sumcheckProof: SumcheckProof,
        decomposition: NumiSealDecompositionCommitment,
        digitTensor: NumiSealDigitTensor,
        claimedDigitEvaluation: GoldilocksExt2,
        digitOpeningStatement: TerminalCEStatement
    ) throws {
        let expected = try Self(
            linearResidual: linearResidual,
            sumcheckProof: sumcheckProof,
            decomposition: decomposition,
            digitTensor: digitTensor,
            claimedDigitEvaluation: claimedDigitEvaluation,
            digitOpeningStatement: digitOpeningStatement
        )
        guard self == expected else {
            throw SuperNeoError.verificationFailed("NumiSeal residual CE statement mismatch")
        }
    }

    public func validate(digitOpeningStatement: TerminalCEStatement) throws {
        try residualShape.validate(digitOpeningStatement: digitOpeningStatement)
        guard digitOpeningStatementDigest == digitOpeningStatement.statementDigest else {
            throw SuperNeoError.verificationFailed("NumiSeal residual CE statement digit opening digest mismatch")
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
        bytes += digitTensorDigest.superNeoBytes
        bytes += scalarizationStatementDigest.superNeoBytes
        bytes += linearResidualDigest.superNeoBytes
        bytes += sumcheckProofDigest.superNeoBytes
        bytes += numiSealEncodeCount(sumcheckFinalPoint.count)
        bytes += sumcheckFinalPoint.flatMap(\.superNeoBytes)
        bytes += claimedDigitEvaluation.superNeoBytes
        bytes += digitOpeningStatementDigest.superNeoBytes
        bytes += statementDigest.superNeoBytes
        return bytes
    }

    private static func computeStatementDigest(
        residualShape: NumiSealResidualCEShape,
        publicStatementDigest: Digest256,
        aggregateDigest: Digest256,
        decompositionKeyDigest: Digest256,
        decompositionCommitmentDigest: Digest256,
        digitTensorDigest: Digest256,
        scalarizationStatementDigest: Digest256,
        linearResidualDigest: Digest256,
        sumcheckProofDigest: Digest256,
        sumcheckFinalPoint: [GoldilocksExt2],
        claimedDigitEvaluation: GoldilocksExt2,
        digitOpeningStatementDigest: Digest256
    ) -> Digest256 {
        NumiSealEncoding.digest(
            label: "numiseal.residual-ce-statement.v1",
            bytes: numiSealEncodeUInt16(Self.version)
                + residualShape.residualShapeDigest.superNeoBytes
                + publicStatementDigest.superNeoBytes
                + aggregateDigest.superNeoBytes
                + decompositionKeyDigest.superNeoBytes
                + decompositionCommitmentDigest.superNeoBytes
                + digitTensorDigest.superNeoBytes
                + scalarizationStatementDigest.superNeoBytes
                + linearResidualDigest.superNeoBytes
                + sumcheckProofDigest.superNeoBytes
                + numiSealEncodeCount(sumcheckFinalPoint.count)
                + sumcheckFinalPoint.flatMap(\.superNeoBytes)
                + claimedDigitEvaluation.superNeoBytes
                + digitOpeningStatementDigest.superNeoBytes
        )
    }
}

public struct NumiSealResidualCEBuildResult: Equatable, Sendable {
    public let digitOpeningStatement: TerminalCEStatement
    public let ceOpeningProof: CEOpeningProof
    public let residualOpening: NumiSealResidualOpening

    public init(
        digitOpeningStatement: TerminalCEStatement,
        ceOpeningProof: CEOpeningProof,
        residualOpening: NumiSealResidualOpening
    ) {
        self.digitOpeningStatement = digitOpeningStatement
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
            statement: material.digitOpeningStatement,
            witnesses: [material.witness],
            shape: material.digitOpeningShape,
            key: material.digitOpeningKey,
            parameters: parameters,
            metalWorkspace: metalWorkspace,
            executionPolicy: executionPolicy
        )
        return try buildResult(
            digitOpeningStatement: material.digitOpeningStatement,
            ceOpeningProof: proof,
            aggregate: aggregate,
            decomposition: decomposition,
            digitTensor: digitTensor,
            linearResidual: linearResidual,
            sumcheckProof: sumcheckProof,
            claimedDigitEvaluation: material.claimedDigitEvaluation
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
            statement: material.digitOpeningStatement,
            witnesses: [material.witness],
            shape: material.digitOpeningShape,
            key: material.digitOpeningKey,
            parameters: parameters,
            randomSeed: randomSeed,
            metalWorkspace: metalWorkspace,
            executionPolicy: executionPolicy
        )
        return try buildResult(
            digitOpeningStatement: material.digitOpeningStatement,
            ceOpeningProof: proof,
            aggregate: aggregate,
            decomposition: decomposition,
            digitTensor: digitTensor,
            linearResidual: linearResidual,
            sumcheckProof: sumcheckProof,
            claimedDigitEvaluation: material.claimedDigitEvaluation
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
        let digitOpeningShape: CCSShape
        let digitOpeningKey: AjtaiCommitmentKey
        let digitOpeningStatement: TerminalCEStatement
        let witness: CEOpeningWitness
        let claimedDigitEvaluation: GoldilocksExt2
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
        let claimedDigitEvaluation = try digitEvaluation(
            digitTensor: digitTensor,
            at: sumcheckProof.finalPoint
        )
        guard try NumiSealSumcheckOracle.verifyFinalOpening(
            proof: sumcheckProof,
            linearResidualDigest: linearResidual.residualDigest,
            scalarizationStatementDigest: linearResidual.statement.statementDigest,
            digitTensorDigest: digitTensor.digest,
            laneKey: digitTensor.laneKey,
            aggregateIndex: digitTensor.aggregateIndex,
            columnCount: digitTensor.columnCount,
            activeDigitCount: digitTensor.activeDigitCount,
            claimedDigitEvaluation: claimedDigitEvaluation
        ) else {
            throw SuperNeoError.verificationFailed("NumiSeal residual sum-check final opening failed")
        }
        let digitOpeningShape = try NumiSealResidualCEShape.digitOpeningShape(
            columnCount: digitTensor.columnCount,
            paddedSlotCount: NumiSealResidualCEShape.nextPowerOfTwo(digitTensor.digits.count)
        )
        let digitOpeningKey = try decomposition.keyDerivation.deriveKey(parameters: parameters)
        let digitOpeningEvaluation = try digitCommitmentEvaluation(
            digitTensor: digitTensor,
            point: sumcheckProof.finalPoint,
            shape: digitOpeningShape,
            executionPolicy: executionPolicy
        )
        guard digitOpeningEvaluation.constantTerm == claimedDigitEvaluation else {
            throw SuperNeoError.verificationFailed("NumiSeal residual digit opening evaluation mismatch")
        }
        let digitOpeningClaim = CCSEvaluationClaim(
            commitment: decomposition.commitment,
            publicInput: [],
            point: sumcheckProof.finalPoint,
            evaluations: [digitOpeningEvaluation],
            witness: digitTensor.digits.map(\.fieldElement)
        )
        let digitOpeningStatement = try TerminalCEStatement(
            profileID: publicStatement.profileID,
            shape: digitOpeningShape,
            key: digitOpeningKey,
            claims: [digitOpeningClaim]
        )
        guard let digitOpeningWitness = CEOpeningWitness(claim: digitOpeningClaim) else {
            throw SuperNeoError.invalidParameter("NumiSeal residual digit opening claim is missing witness")
        }
        return BuildMaterial(
            digitOpeningShape: digitOpeningShape,
            digitOpeningKey: digitOpeningKey,
            digitOpeningStatement: digitOpeningStatement,
            witness: digitOpeningWitness,
            claimedDigitEvaluation: claimedDigitEvaluation
        )
    }

    private static func buildResult(
        digitOpeningStatement: TerminalCEStatement,
        ceOpeningProof: CEOpeningProof,
        aggregate: NumiSealLaneAggregate,
        decomposition: NumiSealDecompositionCommitment,
        digitTensor: NumiSealDigitTensor,
        linearResidual: NumiSealLinearResidual,
        sumcheckProof: SumcheckProof,
        claimedDigitEvaluation: GoldilocksExt2
    ) throws -> NumiSealResidualCEBuildResult {
        let residualOpening = try NumiSealResidualOpening(
            laneKey: aggregate.laneKey,
            aggregateIndex: aggregate.aggregateIndex,
            linearResidual: linearResidual,
            sumcheckProof: sumcheckProof,
            decomposition: decomposition,
            digitTensor: digitTensor,
            claimedDigitEvaluation: claimedDigitEvaluation,
            digitOpeningStatement: digitOpeningStatement,
            ceOpeningProof: ceOpeningProof
        )
        return NumiSealResidualCEBuildResult(
            digitOpeningStatement: digitOpeningStatement,
            ceOpeningProof: ceOpeningProof,
            residualOpening: residualOpening
        )
    }

    private static func digitEvaluation(
        digitTensor: NumiSealDigitTensor,
        at point: [GoldilocksExt2]
    ) throws -> GoldilocksExt2 {
        let paddedSlotCount = NumiSealResidualCEShape.nextPowerOfTwo(digitTensor.digits.count)
        guard point.count == (try NumiSealResidualCEShape.log2Exact(paddedSlotCount)) else {
            throw SuperNeoError.invalidParameter("NumiSeal residual digit evaluation point length mismatch")
        }
        var digits = digitTensor.digits.map(\.fieldElement)
        digits += Array(repeating: .zero, count: paddedSlotCount - digits.count)
        return try MultilinearEvaluation.evaluate(digits, at: point)
    }

    private static func digitCommitmentEvaluation(
        digitTensor: NumiSealDigitTensor,
        point: [GoldilocksExt2],
        shape: CCSShape,
        executionPolicy: SuperNeoExecutionPolicy
    ) throws -> CyclotomicExt2Ring54 {
        guard shape.nRing == digitTensor.columnCount else {
            throw SuperNeoError.invalidParameter("NumiSeal residual digit opening shape column mismatch")
        }
        guard shape.numMatrices == 1 else {
            throw SuperNeoError.invalidParameter("NumiSeal residual digit opening shape matrix mismatch")
        }
        let transformed = try shape.compiledSparseForSuperNeo().transformedSparseMatrices[0]
        if executionPolicy.usesConstantWorkCPU {
            return try transformed.evaluatedProductConstantWork(
                by: digitTensor.message,
                rHat: MultilinearEvaluation.checkedBasis(at: point)
            )
        }
        return try transformed.evaluatedProduct(
            by: digitTensor.message,
            rHat: MultilinearEvaluation.checkedBasis(at: point)
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
