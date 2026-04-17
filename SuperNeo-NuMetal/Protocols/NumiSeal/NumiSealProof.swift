import Foundation

extension NumiSealWireLimits {
    static let maximumProofComponentByteCount = 1 << 24
    static let maximumProofLaneByteCount = 1 << 24
    static let maximumPublicStatementByteCount = 1 << 24
}

public enum NumiSealComponentDigestKind: UInt16, CaseIterable, Sendable {
    case publicStatement = 1
    case laneAggregate = 2
    case decomposition = 3
    case scalarization = 4
    case sumcheck = 5
    case residualOpening = 6
    case carry = 7

    public var label: String {
        switch self {
        case .publicStatement:
            return "numiseal.public-statement.v1"
        case .laneAggregate:
            return "numiseal.lane-aggregate.v1"
        case .decomposition:
            return "numiseal.decomposition.v1"
        case .scalarization:
            return "numiseal.scalarization.v1"
        case .sumcheck:
            return "numiseal.sumcheck.v1"
        case .residualOpening:
            return "numiseal.residual-opening.v1"
        case .carry:
            return "numiseal.carry.v1"
        }
    }
}

public struct NumiSealComponentDigest: Equatable, Sendable, SuperNeoByteEncodable {
    public let kind: NumiSealComponentDigestKind
    public let isAbsent: Bool
    public let laneKey: NumiSealLaneKey?
    public let aggregateIndex: Int?
    public let payloadDigest: Digest256

    public init(
        kind: NumiSealComponentDigestKind,
        isAbsent: Bool,
        laneKey: NumiSealLaneKey?,
        aggregateIndex: Int?,
        payloadDigest: Digest256
    ) throws {
        if kind == .publicStatement {
            guard laneKey == nil, aggregateIndex == nil else {
                throw SuperNeoError.invalidParameter("NumiSeal public statement component must be unscoped")
            }
        } else {
            guard laneKey != nil, aggregateIndex != nil else {
                throw SuperNeoError.invalidParameter("NumiSeal aggregate component must be scoped")
            }
        }
        if let aggregateIndex {
            guard aggregateIndex >= 0 else {
                throw SuperNeoError.invalidParameter("NumiSeal component aggregate index must be non-negative")
            }
        }

        self.kind = kind
        self.isAbsent = isAbsent
        self.laneKey = laneKey
        self.aggregateIndex = aggregateIndex
        self.payloadDigest = payloadDigest
    }

    public static func present(
        kind: NumiSealComponentDigestKind,
        laneKey: NumiSealLaneKey? = nil,
        aggregateIndex: Int? = nil,
        payloadBytes: [UInt8]
    ) -> Self {
        Self(
            uncheckedKind: kind,
            isAbsent: false,
            laneKey: laneKey,
            aggregateIndex: aggregateIndex,
            payloadDigest: NumiSealEncoding.digest(label: kind.label, bytes: payloadBytes)
        )
    }

    public static func absent(
        kind: NumiSealComponentDigestKind,
        laneKey: NumiSealLaneKey,
        aggregateIndex: Int
    ) -> Self {
        let scope = scopedBytes(laneKey: laneKey, aggregateIndex: aggregateIndex)
        return Self(
            uncheckedKind: kind,
            isAbsent: true,
            laneKey: laneKey,
            aggregateIndex: aggregateIndex,
            payloadDigest: NumiSealEncoding.digest(
                label: "numiseal.absent-component.v1",
                bytes: numiSealEncodeString(kind.label) + scope
            )
        )
    }

    public var leafDigest: Digest256 {
        NumiSealEncoding.digest(label: "numiseal.component-digest.v1", bytes: digestMaterial)
    }

    public var superNeoBytes: [UInt8] {
        digestMaterial + leafDigest.superNeoBytes
    }

    private var digestMaterial: [UInt8] {
        numiSealEncodeUInt16(kind.rawValue)
            + [isAbsent ? 0 : 1]
            + Self.scopeBytes(laneKey: laneKey, aggregateIndex: aggregateIndex)
            + payloadDigest.superNeoBytes
    }

    private init(
        uncheckedKind kind: NumiSealComponentDigestKind,
        isAbsent: Bool,
        laneKey: NumiSealLaneKey?,
        aggregateIndex: Int?,
        payloadDigest: Digest256
    ) {
        self.kind = kind
        self.isAbsent = isAbsent
        self.laneKey = laneKey
        self.aggregateIndex = aggregateIndex
        self.payloadDigest = payloadDigest
    }

    private static func scopeBytes(laneKey: NumiSealLaneKey?, aggregateIndex: Int?) -> [UInt8] {
        guard let laneKey, let aggregateIndex else {
            return [0]
        }
        return scopedBytes(laneKey: laneKey, aggregateIndex: aggregateIndex)
    }

    private static func scopedBytes(laneKey: NumiSealLaneKey, aggregateIndex: Int) -> [UInt8] {
        [1] + laneKey.superNeoBytes + numiSealEncodeCount(aggregateIndex)
    }
}

public enum NumiSealComponentDigestTree {
    public static func root(_ components: [NumiSealComponentDigest]) -> Digest256 {
        NumiSealEncoding.root(
            label: "numiseal.component-digest-root.v1",
            leaves: components.map(\.leafDigest)
        )
    }
}

public struct NumiSealResidualOpening: Equatable, Sendable, SuperNeoByteEncodable {
    public static let domain = Digest256.hash("SuperNeo-NuMetal.numiseal.residual-opening.v1")
    public static let version: UInt16 = 11

    public let version: UInt16
    public let laneKey: NumiSealLaneKey
    public let aggregateIndex: Int
    public let residualShapeDigest: Digest256
    public let decompositionKeyDerivation: NumiSealDecompositionKeyDerivation
    public let decompositionKeyDigest: Digest256
    public let decompositionCommitmentDigest: Digest256
    public let digitTensorDigest: Digest256
    public let scalarizationStatementDigest: Digest256
    public let linearResidualDigest: Digest256
    public let sumcheckProofDigest: Digest256
    public let residualStatement: NumiSealResidualCEStatement
    public let residualStatementDigest: Digest256
    public let digitOpeningStatement: TerminalCEStatement
    public let digitOpeningStatementDigest: Digest256
    public let ceOpeningProof: CEOpeningProof
    public let ceOpeningProofDigest: Digest256
    public let openingDigest: Digest256

    public init(
        laneKey: NumiSealLaneKey,
        aggregateIndex: Int,
        linearResidual: NumiSealLinearResidual,
        sumcheckProof: SumcheckProof,
        decomposition: NumiSealDecompositionCommitment,
        digitTensor: NumiSealDigitTensor,
        claimedDigitEvaluation: GoldilocksExt2,
        digitOpeningStatement: TerminalCEStatement,
        ceOpeningProof: CEOpeningProof
    ) throws {
        guard linearResidual.statement.laneKey == laneKey else {
            throw SuperNeoError.invalidParameter("NumiSeal residual opening linear residual lane mismatch")
        }
        guard linearResidual.statement.aggregateIndex == aggregateIndex else {
            throw SuperNeoError.invalidParameter("NumiSeal residual opening linear residual aggregate mismatch")
        }
        guard sumcheckProof.claimedSum == linearResidual.residualValue else {
            throw SuperNeoError.invalidParameter("NumiSeal residual opening sum-check claimed sum mismatch")
        }
        guard decomposition.keyDerivation.laneKey == laneKey else {
            throw SuperNeoError.invalidParameter("NumiSeal residual opening decomposition lane mismatch")
        }
        guard decomposition.keyDerivation.aggregateIndex == aggregateIndex else {
            throw SuperNeoError.invalidParameter("NumiSeal residual opening decomposition aggregate mismatch")
        }
        guard decomposition.digitTensorDigest == digitTensor.digest else {
            throw SuperNeoError.invalidParameter("NumiSeal residual opening digit tensor digest mismatch")
        }
        guard digitTensor.laneKey == laneKey else {
            throw SuperNeoError.invalidParameter("NumiSeal residual opening digit tensor lane mismatch")
        }
        guard digitTensor.aggregateIndex == aggregateIndex else {
            throw SuperNeoError.invalidParameter("NumiSeal residual opening digit tensor aggregate mismatch")
        }

        let residualStatement = try NumiSealResidualCEStatement(
            linearResidual: linearResidual,
            sumcheckProof: sumcheckProof,
            decomposition: decomposition,
            digitTensor: digitTensor,
            claimedDigitEvaluation: claimedDigitEvaluation,
            digitOpeningStatement: digitOpeningStatement
        )
        try Self.validateDigitOpeningStatement(
            digitOpeningStatement,
            residualShape: residualStatement.residualShape,
            decomposition: decomposition,
            claimedDigitEvaluation: claimedDigitEvaluation
        )
        try Self.validateCEProof(ceOpeningProof, digitOpeningStatement: digitOpeningStatement)
        let residualShapeDigest = residualStatement.residualShape.residualShapeDigest
        let residualStatementDigest = residualStatement.statementDigest
        let decompositionKeyDigest = decomposition.decompositionKeyDigest
        let decompositionCommitmentDigest = decomposition.commitmentDigest
        let digitTensorDigest = digitTensor.digest
        let scalarizationStatementDigest = linearResidual.statement.statementDigest
        let digitOpeningStatementDigest = digitOpeningStatement.statementDigest
        let sumcheckProofDigest = Self.sumcheckProofDigest(sumcheckProof)
        let ceOpeningProofDigest = Self.ceOpeningProofDigest(ceOpeningProof)
        self.version = Self.version
        self.laneKey = laneKey
        self.aggregateIndex = aggregateIndex
        self.residualShapeDigest = residualShapeDigest
        self.decompositionKeyDerivation = decomposition.keyDerivation
        self.decompositionKeyDigest = decompositionKeyDigest
        self.decompositionCommitmentDigest = decompositionCommitmentDigest
        self.digitTensorDigest = digitTensorDigest
        self.scalarizationStatementDigest = scalarizationStatementDigest
        self.linearResidualDigest = linearResidual.residualDigest
        self.sumcheckProofDigest = sumcheckProofDigest
        self.residualStatement = residualStatement
        self.residualStatementDigest = residualStatementDigest
        self.digitOpeningStatement = digitOpeningStatement
        self.digitOpeningStatementDigest = digitOpeningStatementDigest
        self.ceOpeningProof = ceOpeningProof
        self.ceOpeningProofDigest = ceOpeningProofDigest
        self.openingDigest = Self.computeOpeningDigest(
            laneKey: laneKey,
            aggregateIndex: aggregateIndex,
            residualShapeDigest: residualShapeDigest,
            decompositionKeyDigest: decompositionKeyDigest,
            decompositionCommitmentDigest: decompositionCommitmentDigest,
            digitTensorDigest: digitTensorDigest,
            scalarizationStatementDigest: scalarizationStatementDigest,
            linearResidualDigest: linearResidual.residualDigest,
            sumcheckProofDigest: sumcheckProofDigest,
            residualStatementDigest: residualStatementDigest,
            digitOpeningStatementDigest: digitOpeningStatementDigest,
            ceOpeningProofDigest: ceOpeningProofDigest,
            decompositionKeyDerivationBytes: decomposition.keyDerivation.superNeoBytes,
            residualStatementBytes: residualStatement.superNeoBytes,
            digitOpeningStatementBytes: digitOpeningStatement.superNeoBytes,
            ceOpeningProofBytes: ceOpeningProof.superNeoBytes
        )
    }

    public init(_ bytes: [UInt8], parameters: SuperNeoParameters = .goldilocks) throws {
        try self.init(bytes: bytes, parameters: parameters)
    }

    public init(bytes: [UInt8], parameters: SuperNeoParameters = .goldilocks) throws {
        var reader = ByteReader(bytes)
        let domain = try Digest256(reader.readData(count: Digest256.byteCount))
        guard domain == Self.domain else {
            throw SuperNeoError.invalidEncoding("NumiSeal residual opening domain mismatch")
        }
        let version = try reader.readUInt16()
        guard version == Self.version else {
            throw SuperNeoError.invalidEncoding("unsupported NumiSeal residual opening version")
        }
        let laneKey = try reader.readNumiSealLaneKey()
        let aggregateIndex = try reader.readCount(
            maximum: NumiSealWireLimits.maximumAggregateCount,
            name: "NumiSeal residual opening aggregate index"
        )
        let residualShapeDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        let decompositionKeyDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        let decompositionCommitmentDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        let digitTensorDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        let scalarizationStatementDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        let linearResidualDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        let sumcheckProofDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        let residualStatementDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        let digitOpeningStatementDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        let ceOpeningProofDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        let decompositionKeyDerivationBytes = try reader.readNumiSealProofComponentBytes(
            name: "NumiSeal decomposition key derivation"
        )
        let residualStatementBytes = try reader.readNumiSealProofComponentBytes(
            name: "NumiSeal residual CE statement"
        )
        let digitOpeningStatementBytes = try reader.readNumiSealProofComponentBytes(
            name: "NumiSeal residual digit CE statement"
        )
        let ceOpeningProofBytes = try reader.readNumiSealProofComponentBytes(
            name: "NumiSeal residual CE opening proof"
        )
        let openingDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        try reader.finish()

        let decompositionKeyDerivation = try NumiSealDecompositionKeyDerivation(
            bytes: decompositionKeyDerivationBytes
        )
        let residualStatement = try NumiSealResidualCEStatement(bytes: residualStatementBytes)
        let digitOpeningStatement = try TerminalCEStatement(bytes: digitOpeningStatementBytes, parameters: parameters)
        let ceOpeningProof = try CEOpeningProof(bytes: ceOpeningProofBytes, parameters: parameters)
        try residualStatement.validate(digitOpeningStatement: digitOpeningStatement)
        try Self.validateParsedScope(
            laneKey: laneKey,
            aggregateIndex: aggregateIndex,
            residualShapeDigest: residualShapeDigest,
            decompositionKeyDerivation: decompositionKeyDerivation,
            decompositionKeyDigest: decompositionKeyDigest,
            decompositionCommitmentDigest: decompositionCommitmentDigest,
            digitTensorDigest: digitTensorDigest,
            scalarizationStatementDigest: scalarizationStatementDigest,
            linearResidualDigest: linearResidualDigest,
            sumcheckProofDigest: sumcheckProofDigest,
            residualStatement: residualStatement,
            digitOpeningStatement: digitOpeningStatement
        )
        try Self.validateCEProof(ceOpeningProof, digitOpeningStatement: digitOpeningStatement)
        guard residualStatementDigest == residualStatement.statementDigest else {
            throw SuperNeoError.invalidEncoding("NumiSeal residual CE statement digest mismatch")
        }
        guard decompositionKeyDigest == decompositionKeyDerivation.derivationDigest else {
            throw SuperNeoError.invalidEncoding("NumiSeal residual decomposition key digest mismatch")
        }
        guard digitOpeningStatementDigest == digitOpeningStatement.statementDigest else {
            throw SuperNeoError.invalidEncoding("NumiSeal residual digit statement digest mismatch")
        }
        guard ceOpeningProofDigest == Self.ceOpeningProofDigest(ceOpeningProof) else {
            throw SuperNeoError.invalidEncoding("NumiSeal residual CE proof digest mismatch")
        }
        let expectedDigest = Self.computeOpeningDigest(
            laneKey: laneKey,
            aggregateIndex: aggregateIndex,
            residualShapeDigest: residualShapeDigest,
            decompositionKeyDigest: decompositionKeyDigest,
            decompositionCommitmentDigest: decompositionCommitmentDigest,
            digitTensorDigest: digitTensorDigest,
            scalarizationStatementDigest: scalarizationStatementDigest,
            linearResidualDigest: linearResidualDigest,
            sumcheckProofDigest: sumcheckProofDigest,
            residualStatementDigest: residualStatementDigest,
            digitOpeningStatementDigest: digitOpeningStatementDigest,
            ceOpeningProofDigest: ceOpeningProofDigest,
            decompositionKeyDerivationBytes: decompositionKeyDerivationBytes,
            residualStatementBytes: residualStatementBytes,
            digitOpeningStatementBytes: digitOpeningStatementBytes,
            ceOpeningProofBytes: ceOpeningProofBytes
        )
        guard openingDigest == expectedDigest else {
            throw SuperNeoError.invalidEncoding("NumiSeal residual opening digest mismatch")
        }

        self.version = version
        self.laneKey = laneKey
        self.aggregateIndex = aggregateIndex
        self.residualShapeDigest = residualShapeDigest
        self.decompositionKeyDerivation = decompositionKeyDerivation
        self.decompositionKeyDigest = decompositionKeyDigest
        self.decompositionCommitmentDigest = decompositionCommitmentDigest
        self.digitTensorDigest = digitTensorDigest
        self.scalarizationStatementDigest = scalarizationStatementDigest
        self.linearResidualDigest = linearResidualDigest
        self.sumcheckProofDigest = sumcheckProofDigest
        self.residualStatement = residualStatement
        self.residualStatementDigest = residualStatementDigest
        self.digitOpeningStatement = digitOpeningStatement
        self.digitOpeningStatementDigest = digitOpeningStatementDigest
        self.ceOpeningProof = ceOpeningProof
        self.ceOpeningProofDigest = ceOpeningProofDigest
        self.openingDigest = openingDigest
    }

    public func validate(
        linearResidual: NumiSealLinearResidual,
        sumcheckProof: SumcheckProof,
        decomposition: NumiSealDecompositionCommitment,
        digitTensor: NumiSealDigitTensor,
        claimedDigitEvaluation: GoldilocksExt2
    ) throws {
        guard laneKey == linearResidual.statement.laneKey else {
            throw SuperNeoError.verificationFailed("NumiSeal residual opening linear residual lane mismatch")
        }
        guard aggregateIndex == linearResidual.statement.aggregateIndex else {
            throw SuperNeoError.verificationFailed("NumiSeal residual opening linear residual aggregate mismatch")
        }
        guard linearResidualDigest == linearResidual.residualDigest else {
            throw SuperNeoError.verificationFailed("NumiSeal residual opening linear residual digest mismatch")
        }
        guard sumcheckProof.claimedSum == linearResidual.residualValue else {
            throw SuperNeoError.verificationFailed("NumiSeal residual opening sum-check claimed sum mismatch")
        }
        guard sumcheckProofDigest == Self.sumcheckProofDigest(sumcheckProof) else {
            throw SuperNeoError.verificationFailed("NumiSeal residual opening sum-check proof digest mismatch")
        }
        try residualStatement.validate(
            linearResidual: linearResidual,
            sumcheckProof: sumcheckProof,
            decomposition: decomposition,
            digitTensor: digitTensor,
            claimedDigitEvaluation: claimedDigitEvaluation,
            digitOpeningStatement: digitOpeningStatement
        )
    }

    public func validate(laneProof: NumiSealLaneProof) throws {
        guard laneKey == laneProof.laneKey else {
            throw SuperNeoError.verificationFailed("NumiSeal residual opening lane mismatch")
        }
        guard aggregateIndex == laneProof.aggregateIndex else {
            throw SuperNeoError.verificationFailed("NumiSeal residual opening aggregate mismatch")
        }
        guard linearResidualDigest == laneProof.scalarizationDigest else {
            throw SuperNeoError.verificationFailed("NumiSeal residual opening scalarization digest mismatch")
        }
        guard sumcheckProofDigest == Self.sumcheckProofDigest(laneProof.sumcheckProof) else {
            throw SuperNeoError.verificationFailed("NumiSeal residual opening sum-check proof digest mismatch")
        }
        try Self.validateParsedScope(
            laneKey: laneKey,
            aggregateIndex: aggregateIndex,
            residualShapeDigest: residualShapeDigest,
            decompositionKeyDerivation: decompositionKeyDerivation,
            decompositionKeyDigest: decompositionKeyDigest,
            decompositionCommitmentDigest: decompositionCommitmentDigest,
            digitTensorDigest: digitTensorDigest,
            scalarizationStatementDigest: scalarizationStatementDigest,
            linearResidualDigest: linearResidualDigest,
            sumcheckProofDigest: sumcheckProofDigest,
            residualStatement: residualStatement,
            digitOpeningStatement: digitOpeningStatement
        )
        guard residualStatement.aggregateDigest == laneProof.aggregateDigest else {
            throw SuperNeoError.verificationFailed("NumiSeal residual CE statement aggregate digest mismatch")
        }
        guard residualStatement.decompositionKeyDigest == laneProof.decompositionKeyDigest else {
            throw SuperNeoError.verificationFailed("NumiSeal residual CE statement decomposition key mismatch")
        }
        guard residualStatement.linearResidualDigest == laneProof.scalarizationDigest else {
            throw SuperNeoError.verificationFailed("NumiSeal residual CE statement scalarization digest mismatch")
        }
        guard residualStatement.sumcheckProofDigest == Self.sumcheckProofDigest(laneProof.sumcheckProof) else {
            throw SuperNeoError.verificationFailed("NumiSeal residual CE statement sum-check digest mismatch")
        }
        let publicDecomposition = try NumiSealDecompositionCommitment(
            keyDerivation: decompositionKeyDerivation,
            digitTensorDigest: digitTensorDigest,
            commitment: laneProof.decompositionCommitment
        )
        guard publicDecomposition.commitmentDigest == decompositionCommitmentDigest else {
            throw SuperNeoError.verificationFailed("NumiSeal residual decomposition commitment digest mismatch")
        }
        guard digitOpeningStatement.openings[0].instance.commitment == laneProof.decompositionCommitment else {
            throw SuperNeoError.verificationFailed("NumiSeal residual digit opening commitment mismatch")
        }
        guard try NumiSealSumcheckOracle.verifyFinalOpening(
            proof: laneProof.sumcheckProof,
            linearResidualDigest: linearResidualDigest,
            scalarizationStatementDigest: scalarizationStatementDigest,
            digitTensorDigest: digitTensorDigest,
            laneKey: laneKey,
            aggregateIndex: aggregateIndex,
            columnCount: residualStatement.residualShape.columnCount,
            activeDigitCount: residualStatement.residualShape.activeDigitCount,
            claimedDigitEvaluation: residualStatement.claimedDigitEvaluation
        ) else {
            throw SuperNeoError.verificationFailed("NumiSeal residual sum-check final opening failed")
        }
        try residualStatement.validate(digitOpeningStatement: digitOpeningStatement)
    }

    public func verifyCEOpening(
        shape: CCSShape,
        key: AjtaiCommitmentKey,
        parameters: SuperNeoParameters = .goldilocks,
        metalWorkspace: SuperNeoMetalWorkspace? = nil,
        executionPolicy: SuperNeoExecutionPolicy = .default
    ) throws -> Bool {
        guard shape.shapeDigest == laneKey.shapeDigest else {
            throw SuperNeoError.verificationFailed("NumiSeal residual CE opening shape mismatch")
        }
        guard key.verifierKeyDigest == laneKey.verifierKeyDigest else {
            throw SuperNeoError.verificationFailed("NumiSeal residual CE opening verifier key mismatch")
        }
        guard key.parameters == parameters else {
            throw SuperNeoError.verificationFailed("NumiSeal residual CE opening key parameters mismatch")
        }
        guard key.matrix.columns == shape.nRing else {
            throw SuperNeoError.verificationFailed("NumiSeal residual CE opening key shape mismatch")
        }
        let digitOpeningShape = try NumiSealResidualCEShape.digitOpeningShape(
            columnCount: residualStatement.residualShape.columnCount,
            paddedSlotCount: residualStatement.residualShape.paddedSlotCount
        )
        let digitOpeningKey = try decompositionKeyDerivation.deriveKey(parameters: parameters)
        try Self.validateDigitOpeningStatement(
            digitOpeningStatement,
            residualShape: residualStatement.residualShape,
            decompositionKeyDerivation: decompositionKeyDerivation,
            decompositionKeyDigest: decompositionKeyDigest,
            decompositionCommitmentDigest: decompositionCommitmentDigest,
            digitTensorDigest: digitTensorDigest,
            decompositionCommitment: digitOpeningStatement.openings[0].instance.commitment,
            key: digitOpeningKey,
            claimedDigitEvaluation: residualStatement.claimedDigitEvaluation
        )
        try Self.validateCEProof(ceOpeningProof, digitOpeningStatement: digitOpeningStatement)
        guard residualStatementDigest == residualStatement.statementDigest else {
            throw SuperNeoError.verificationFailed("NumiSeal residual CE statement digest mismatch")
        }
        guard digitOpeningStatementDigest == digitOpeningStatement.statementDigest else {
            throw SuperNeoError.verificationFailed("NumiSeal residual digit statement digest mismatch")
        }
        guard ceOpeningProofDigest == Self.ceOpeningProofDigest(ceOpeningProof) else {
            throw SuperNeoError.verificationFailed("NumiSeal residual CE proof digest mismatch")
        }
        return try CEOpeningRelation.verify(
            proof: ceOpeningProof,
            statement: digitOpeningStatement,
            shape: digitOpeningShape,
            key: digitOpeningKey,
            parameters: parameters,
            metalWorkspace: metalWorkspace,
            executionPolicy: executionPolicy
        )
    }

    public var superNeoBytes: [UInt8] {
        let residualStatementBytes = residualStatement.superNeoBytes
        let decompositionKeyDerivationBytes = decompositionKeyDerivation.superNeoBytes
        let digitOpeningStatementBytes = digitOpeningStatement.superNeoBytes
        let ceOpeningProofBytes = ceOpeningProof.superNeoBytes
        return Self.domain.superNeoBytes
            + numiSealEncodeUInt16(version)
            + laneKey.superNeoBytes
            + numiSealEncodeCount(aggregateIndex)
            + residualShapeDigest.superNeoBytes
            + decompositionKeyDigest.superNeoBytes
            + decompositionCommitmentDigest.superNeoBytes
            + digitTensorDigest.superNeoBytes
            + scalarizationStatementDigest.superNeoBytes
            + linearResidualDigest.superNeoBytes
            + sumcheckProofDigest.superNeoBytes
            + residualStatementDigest.superNeoBytes
            + digitOpeningStatementDigest.superNeoBytes
            + ceOpeningProofDigest.superNeoBytes
            + numiSealFrame(decompositionKeyDerivationBytes)
            + numiSealFrame(residualStatementBytes)
            + numiSealFrame(digitOpeningStatementBytes)
            + numiSealFrame(ceOpeningProofBytes)
            + openingDigest.superNeoBytes
    }

    public static func sumcheckProofDigest(_ proof: SumcheckProof) -> Digest256 {
        NumiSealEncoding.digest(
            label: NumiSealComponentDigestKind.sumcheck.label,
            bytes: proof.superNeoBytes
        )
    }

    public static func ceOpeningProofDigest(_ proof: CEOpeningProof) -> Digest256 {
        NumiSealEncoding.digest(
            label: "numiseal.residual-opening.ce-proof.v1",
            bytes: proof.superNeoBytes
        )
    }

    private static func validateCEProof(
        _ proof: CEOpeningProof,
        digitOpeningStatement: TerminalCEStatement
    ) throws {
        let openingCount = digitOpeningStatement.openings.count
        guard proof.rounds.allSatisfy({ $0.commitments.count == openingCount }) else {
            throw SuperNeoError.invalidParameter("NumiSeal residual CE proof opening count mismatch")
        }
    }

    private static func validateParsedScope(
        laneKey: NumiSealLaneKey,
        aggregateIndex: Int,
        residualShapeDigest: Digest256,
        decompositionKeyDerivation: NumiSealDecompositionKeyDerivation,
        decompositionKeyDigest: Digest256,
        decompositionCommitmentDigest: Digest256,
        digitTensorDigest: Digest256,
        scalarizationStatementDigest: Digest256,
        linearResidualDigest: Digest256,
        sumcheckProofDigest: Digest256,
        residualStatement: NumiSealResidualCEStatement,
        digitOpeningStatement: TerminalCEStatement
    ) throws {
        guard residualStatement.residualShape.laneKey == laneKey else {
            throw SuperNeoError.verificationFailed("NumiSeal residual CE statement lane mismatch")
        }
        guard residualStatement.residualShape.aggregateIndex == aggregateIndex else {
            throw SuperNeoError.verificationFailed("NumiSeal residual CE statement aggregate mismatch")
        }
        guard residualStatement.residualShape.residualShapeDigest == residualShapeDigest else {
            throw SuperNeoError.verificationFailed("NumiSeal residual CE shape digest mismatch")
        }
        guard decompositionKeyDerivation.laneKey == laneKey else {
            throw SuperNeoError.verificationFailed("NumiSeal residual decomposition key lane mismatch")
        }
        guard decompositionKeyDerivation.aggregateIndex == aggregateIndex else {
            throw SuperNeoError.verificationFailed("NumiSeal residual decomposition key aggregate mismatch")
        }
        guard decompositionKeyDerivation.requiredColumnCount == residualStatement.residualShape.columnCount else {
            throw SuperNeoError.verificationFailed("NumiSeal residual decomposition key column mismatch")
        }
        guard decompositionKeyDerivation.derivationDigest == decompositionKeyDigest else {
            throw SuperNeoError.verificationFailed("NumiSeal residual decomposition key digest mismatch")
        }
        let digitOpeningKey = try decompositionKeyDerivation.deriveKey()
        guard digitOpeningStatement.verifierKeyDigest == digitOpeningKey.verifierKeyDigest else {
            throw SuperNeoError.verificationFailed("NumiSeal residual digit opening verifier key mismatch")
        }
        guard residualStatement.decompositionKeyDigest == decompositionKeyDigest else {
            throw SuperNeoError.verificationFailed("NumiSeal residual CE statement decomposition key mismatch")
        }
        guard residualStatement.decompositionCommitmentDigest == decompositionCommitmentDigest else {
            throw SuperNeoError.verificationFailed("NumiSeal residual CE statement decomposition commitment mismatch")
        }
        guard residualStatement.digitTensorDigest == digitTensorDigest else {
            throw SuperNeoError.verificationFailed("NumiSeal residual CE statement digit tensor mismatch")
        }
        guard residualStatement.scalarizationStatementDigest == scalarizationStatementDigest else {
            throw SuperNeoError.verificationFailed("NumiSeal residual CE statement scalarization statement mismatch")
        }
        guard residualStatement.linearResidualDigest == linearResidualDigest else {
            throw SuperNeoError.verificationFailed("NumiSeal residual CE statement linear residual mismatch")
        }
        guard residualStatement.sumcheckProofDigest == sumcheckProofDigest else {
            throw SuperNeoError.verificationFailed("NumiSeal residual CE statement sum-check mismatch")
        }
        guard residualStatement.digitOpeningStatementDigest == digitOpeningStatement.statementDigest else {
            throw SuperNeoError.verificationFailed("NumiSeal residual CE statement digit opening mismatch")
        }
        try residualStatement.validate(digitOpeningStatement: digitOpeningStatement)
    }

    private static func validateDigitOpeningStatement(
        _ digitOpeningStatement: TerminalCEStatement,
        residualShape: NumiSealResidualCEShape,
        decomposition: NumiSealDecompositionCommitment,
        claimedDigitEvaluation: GoldilocksExt2
    ) throws {
        try validateDigitOpeningStatement(
            digitOpeningStatement,
            residualShape: residualShape,
            decompositionKeyDerivation: decomposition.keyDerivation,
            decompositionKeyDigest: decomposition.decompositionKeyDigest,
            decompositionCommitmentDigest: decomposition.commitmentDigest,
            digitTensorDigest: decomposition.digitTensorDigest,
            decompositionCommitment: decomposition.commitment,
            key: decomposition.keyDerivation.deriveKey(parameters: .goldilocks),
            claimedDigitEvaluation: claimedDigitEvaluation
        )
    }

    private static func validateDigitOpeningStatement(
        _ digitOpeningStatement: TerminalCEStatement,
        residualShape: NumiSealResidualCEShape,
        decompositionKeyDerivation: NumiSealDecompositionKeyDerivation,
        decompositionKeyDigest: Digest256,
        decompositionCommitmentDigest: Digest256,
        digitTensorDigest: Digest256,
        decompositionCommitment: AjtaiCommitment,
        key: AjtaiCommitmentKey,
        claimedDigitEvaluation: GoldilocksExt2
    ) throws {
        try residualShape.validate(digitOpeningStatement: digitOpeningStatement)
        guard key.verifierKeyDigest == digitOpeningStatement.verifierKeyDigest else {
            throw SuperNeoError.invalidParameter("NumiSeal residual digit opening verifier key mismatch")
        }
        guard digitOpeningStatement.openings[0].instance.commitment == decompositionCommitment else {
            throw SuperNeoError.invalidParameter("NumiSeal residual digit opening commitment mismatch")
        }
        guard digitOpeningStatement.openings[0].instance.matrixEvals[0].constantTerm == claimedDigitEvaluation else {
            throw SuperNeoError.invalidParameter("NumiSeal residual digit opening evaluation mismatch")
        }
        let publicDecomposition = try NumiSealDecompositionCommitment(
            keyDerivation: decompositionKeyDerivation,
            digitTensorDigest: digitTensorDigest,
            commitment: decompositionCommitment
        )
        guard publicDecomposition.decompositionKeyDigest == decompositionKeyDigest else {
            throw SuperNeoError.invalidParameter("NumiSeal residual digit opening decomposition key mismatch")
        }
        guard publicDecomposition.commitmentDigest == decompositionCommitmentDigest else {
            throw SuperNeoError.invalidParameter("NumiSeal residual digit opening decomposition commitment mismatch")
        }
    }

    private static func computeOpeningDigest(
        laneKey: NumiSealLaneKey,
        aggregateIndex: Int,
        residualShapeDigest: Digest256,
        decompositionKeyDigest: Digest256,
        decompositionCommitmentDigest: Digest256,
        digitTensorDigest: Digest256,
        scalarizationStatementDigest: Digest256,
        linearResidualDigest: Digest256,
        sumcheckProofDigest: Digest256,
        residualStatementDigest: Digest256,
        digitOpeningStatementDigest: Digest256,
        ceOpeningProofDigest: Digest256,
        decompositionKeyDerivationBytes: [UInt8],
        residualStatementBytes: [UInt8],
        digitOpeningStatementBytes: [UInt8],
        ceOpeningProofBytes: [UInt8]
    ) -> Digest256 {
        NumiSealEncoding.digest(
            label: "numiseal.residual-opening.v1",
            bytes: numiSealEncodeUInt16(Self.version)
                + laneKey.superNeoBytes
                + numiSealEncodeCount(aggregateIndex)
                + residualShapeDigest.superNeoBytes
                + decompositionKeyDigest.superNeoBytes
                + decompositionCommitmentDigest.superNeoBytes
                + digitTensorDigest.superNeoBytes
                + scalarizationStatementDigest.superNeoBytes
                + linearResidualDigest.superNeoBytes
                + sumcheckProofDigest.superNeoBytes
                + residualStatementDigest.superNeoBytes
                + digitOpeningStatementDigest.superNeoBytes
                + ceOpeningProofDigest.superNeoBytes
                + numiSealFrame(decompositionKeyDerivationBytes)
                + numiSealFrame(residualStatementBytes)
                + numiSealFrame(digitOpeningStatementBytes)
                + numiSealFrame(ceOpeningProofBytes)
        )
    }
}

public struct NumiSealCarryClaim: Equatable, Sendable, SuperNeoByteEncodable {
    public let bytes: [UInt8]

    public init(_ bytes: [UInt8]) throws {
        guard !bytes.isEmpty else {
            throw SuperNeoError.invalidParameter("NumiSeal carry claim cannot be empty")
        }
        guard bytes.count <= NumiSealWireLimits.maximumProofComponentByteCount else {
            throw SuperNeoError.invalidParameter("NumiSeal carry claim is too large")
        }
        self.bytes = bytes
    }

    public var superNeoBytes: [UInt8] { bytes }
}

public struct NumiSealLaneProof: Equatable, Sendable, SuperNeoByteEncodable {
    public let laneKey: NumiSealLaneKey
    public let aggregateIndex: Int
    public let aggregateDigest: Digest256
    public let decompositionKeyDigest: Digest256
    public let decompositionCommitment: AjtaiCommitment
    public let scalarizationDigest: Digest256
    public let sumcheckProof: SumcheckProof
    public let residualOpening: NumiSealResidualOpening
    public let optionalCarryClaim: NumiSealCarryClaim?

    public init(
        laneKey: NumiSealLaneKey,
        aggregateIndex: Int,
        aggregateDigest: Digest256,
        decompositionKeyDigest: Digest256,
        decompositionCommitment: AjtaiCommitment,
        scalarizationDigest: Digest256,
        sumcheckProof: SumcheckProof,
        residualOpening: NumiSealResidualOpening,
        optionalCarryClaim: NumiSealCarryClaim? = nil
    ) throws {
        guard aggregateIndex >= 0 else {
            throw SuperNeoError.invalidParameter("NumiSeal lane proof aggregate index must be non-negative")
        }
        guard decompositionCommitment.elements.count == SuperNeoParameters.goldilocks.kappa else {
            throw SuperNeoError.invalidParameter("NumiSeal decomposition commitment has wrong length")
        }
        guard sumcheckProof.finalPoint.count == sumcheckProof.rounds.count else {
            throw SuperNeoError.invalidParameter("NumiSeal sum-check final point count must match round count")
        }
        guard sumcheckProof.rounds.allSatisfy({ !$0.coeffs.isEmpty }) else {
            throw SuperNeoError.invalidParameter("NumiSeal sum-check rounds cannot be empty")
        }

        self.laneKey = laneKey
        self.aggregateIndex = aggregateIndex
        self.aggregateDigest = aggregateDigest
        self.decompositionKeyDigest = decompositionKeyDigest
        self.decompositionCommitment = decompositionCommitment
        self.scalarizationDigest = scalarizationDigest
        self.sumcheckProof = sumcheckProof
        self.residualOpening = residualOpening
        self.optionalCarryClaim = optionalCarryClaim
    }

    public init(bytes: [UInt8], parameters: SuperNeoParameters = .goldilocks) throws {
        var reader = ByteReader(bytes)
        let laneKey = try reader.readNumiSealLaneKey()
        let aggregateIndex = try reader.readCount(
            maximum: NumiSealWireLimits.maximumAggregateCount,
            name: "NumiSeal lane proof aggregate index"
        )
        let aggregateDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        let decompositionKeyDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        let decompositionCommitment = try reader.readNumiSealCommitment(parameters: parameters)
        let scalarizationDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        let sumcheckBytes = try reader.readNumiSealProofComponentBytes(name: "NumiSeal sum-check proof")
        let sumcheckProof = try NumiSealProofReaders.readSumcheckProof(from: sumcheckBytes)
        let residualOpening = try NumiSealResidualOpening(
            reader.readNumiSealProofComponentBytes(name: "NumiSeal residual opening"),
            parameters: parameters
        )
        let carryTag = try reader.readUInt8()
        let optionalCarryClaim: NumiSealCarryClaim?
        switch carryTag {
        case 0:
            optionalCarryClaim = nil
        case 1:
            optionalCarryClaim = try NumiSealCarryClaim(
                reader.readNumiSealProofComponentBytes(name: "NumiSeal carry claim")
            )
        default:
            throw SuperNeoError.invalidEncoding("unsupported NumiSeal carry claim tag")
        }
        try reader.finish()

        try self.init(
            laneKey: laneKey,
            aggregateIndex: aggregateIndex,
            aggregateDigest: aggregateDigest,
            decompositionKeyDigest: decompositionKeyDigest,
            decompositionCommitment: decompositionCommitment,
            scalarizationDigest: scalarizationDigest,
            sumcheckProof: sumcheckProof,
            residualOpening: residualOpening,
            optionalCarryClaim: optionalCarryClaim
        )
    }

    public var componentDigests: [NumiSealComponentDigest] {
        [
            .present(
                kind: .laneAggregate,
                laneKey: laneKey,
                aggregateIndex: aggregateIndex,
                payloadBytes: aggregateDigest.superNeoBytes
            ),
            .present(
                kind: .decomposition,
                laneKey: laneKey,
                aggregateIndex: aggregateIndex,
                payloadBytes: decompositionKeyDigest.superNeoBytes + decompositionCommitment.superNeoBytes
            ),
            .present(
                kind: .scalarization,
                laneKey: laneKey,
                aggregateIndex: aggregateIndex,
                payloadBytes: scalarizationDigest.superNeoBytes
            ),
            .present(
                kind: .sumcheck,
                laneKey: laneKey,
                aggregateIndex: aggregateIndex,
                payloadBytes: sumcheckProof.superNeoBytes
            ),
            .present(
                kind: .residualOpening,
                laneKey: laneKey,
                aggregateIndex: aggregateIndex,
                payloadBytes: residualOpening.superNeoBytes
            ),
            carryComponentDigest
        ]
    }

    public var proofDigest: Digest256 {
        NumiSealEncoding.digest(label: "numiseal.lane-proof.v1", bytes: superNeoBytes)
    }

    public var superNeoBytes: [UInt8] {
        laneKey.superNeoBytes
            + numiSealEncodeCount(aggregateIndex)
            + aggregateDigest.superNeoBytes
            + decompositionKeyDigest.superNeoBytes
            + decompositionCommitment.superNeoBytes
            + scalarizationDigest.superNeoBytes
            + numiSealFrame(sumcheckProof.superNeoBytes)
            + numiSealFrame(residualOpening.superNeoBytes)
            + (optionalCarryClaim.map { [UInt8(1)] + numiSealFrame($0.superNeoBytes) } ?? [UInt8(0)])
    }

    private var carryComponentDigest: NumiSealComponentDigest {
        if let optionalCarryClaim {
            return .present(
                kind: .carry,
                laneKey: laneKey,
                aggregateIndex: aggregateIndex,
                payloadBytes: optionalCarryClaim.superNeoBytes
            )
        }
        return .absent(kind: .carry, laneKey: laneKey, aggregateIndex: aggregateIndex)
    }
}

public struct NumiSealProof: Equatable, Sendable, SuperNeoByteEncodable {
    public static let bodyVersion: UInt16 = 11

    public let bodyVersion: UInt16
    public let publicStatement: NumiSealPublicStatement
    public let aggregateCount: Int
    public let laneProofs: [NumiSealLaneProof]
    public let componentDigestRoot: Digest256
    public let transcriptDigest: Digest256

    public init(
        publicStatement: NumiSealPublicStatement,
        laneProofs: [NumiSealLaneProof]
    ) throws {
        guard !laneProofs.isEmpty else {
            throw SuperNeoError.invalidParameter("NumiSeal proof requires lane proofs")
        }
        try Self.validateLaneProofOrdering(laneProofs)
        let componentDigestRoot = Self.computeComponentDigestRoot(
            publicStatement: publicStatement,
            laneProofs: laneProofs
        )
        self.bodyVersion = Self.bodyVersion
        self.publicStatement = publicStatement
        self.aggregateCount = laneProofs.count
        self.laneProofs = laneProofs
        self.componentDigestRoot = componentDigestRoot
        self.transcriptDigest = Self.computeTranscriptDigest(
            bodyVersion: Self.bodyVersion,
            publicStatement: publicStatement,
            aggregateCount: laneProofs.count,
            laneProofs: laneProofs,
            componentDigestRoot: componentDigestRoot
        )
    }

    public init(bytes: [UInt8], parameters: SuperNeoParameters = .goldilocks) throws {
        var reader = ByteReader(bytes)
        let bodyVersion = try reader.readUInt16()
        guard bodyVersion == Self.bodyVersion else {
            throw SuperNeoError.invalidEncoding("unsupported NumiSeal proof body version")
        }
        let publicStatementBytes = try reader.readNumiSealProofComponentBytes(
            maximum: NumiSealWireLimits.maximumPublicStatementByteCount,
            name: "NumiSeal public statement"
        )
        let publicStatement = try NumiSealPublicStatement(bytes: publicStatementBytes)
        let aggregateCount = try reader.readCount(
            maximum: NumiSealWireLimits.maximumAggregateCount,
            name: "NumiSeal aggregate"
        )
        let laneProofCount = try reader.readCount(
            maximum: NumiSealWireLimits.maximumAggregateCount,
            name: "NumiSeal lane proof",
            elementByteWidth: 8
        )
        guard aggregateCount == laneProofCount else {
            throw SuperNeoError.invalidEncoding("NumiSeal aggregate count must match lane proof count")
        }
        guard laneProofCount > 0 else {
            throw SuperNeoError.invalidEncoding("NumiSeal proof requires lane proofs")
        }
        let laneProofs = try (0..<laneProofCount).map { _ in
            try NumiSealLaneProof(
                bytes: reader.readNumiSealProofComponentBytes(
                    maximum: NumiSealWireLimits.maximumProofLaneByteCount,
                    name: "NumiSeal lane proof"
                ),
                parameters: parameters
            )
        }
        let componentDigestRoot = try Digest256(reader.readData(count: Digest256.byteCount))
        let transcriptDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        try reader.finish()
        try Self.validateLaneProofOrdering(laneProofs)

        let expectedComponentDigestRoot = Self.computeComponentDigestRoot(
            publicStatement: publicStatement,
            laneProofs: laneProofs
        )
        guard componentDigestRoot == expectedComponentDigestRoot else {
            throw SuperNeoError.invalidEncoding("NumiSeal component digest root mismatch")
        }
        let expectedTranscriptDigest = Self.computeTranscriptDigest(
            bodyVersion: bodyVersion,
            publicStatement: publicStatement,
            aggregateCount: aggregateCount,
            laneProofs: laneProofs,
            componentDigestRoot: componentDigestRoot
        )
        guard transcriptDigest == expectedTranscriptDigest else {
            throw SuperNeoError.invalidEncoding("NumiSeal transcript digest mismatch")
        }

        self.bodyVersion = bodyVersion
        self.publicStatement = publicStatement
        self.aggregateCount = aggregateCount
        self.laneProofs = laneProofs
        self.componentDigestRoot = componentDigestRoot
        self.transcriptDigest = transcriptDigest
    }

    public var componentDigests: [NumiSealComponentDigest] {
        [
            .present(kind: .publicStatement, payloadBytes: publicStatement.superNeoBytes)
        ] + laneProofs.flatMap(\.componentDigests)
    }

    public var superNeoBytes: [UInt8] {
        numiSealEncodeUInt16(bodyVersion)
            + numiSealFrame(publicStatement.superNeoBytes)
            + numiSealEncodeCount(aggregateCount)
            + numiSealEncodeCount(laneProofs.count)
            + laneProofs.flatMap { numiSealFrame($0.superNeoBytes) }
            + componentDigestRoot.superNeoBytes
            + transcriptDigest.superNeoBytes
    }

    private static func computeComponentDigestRoot(
        publicStatement: NumiSealPublicStatement,
        laneProofs: [NumiSealLaneProof]
    ) -> Digest256 {
        NumiSealComponentDigestTree.root(
            [.present(kind: .publicStatement, payloadBytes: publicStatement.superNeoBytes)]
                + laneProofs.flatMap(\.componentDigests)
        )
    }

    private static func computeTranscriptDigest(
        bodyVersion: UInt16,
        publicStatement: NumiSealPublicStatement,
        aggregateCount: Int,
        laneProofs: [NumiSealLaneProof],
        componentDigestRoot: Digest256
    ) -> Digest256 {
        NumiSealEncoding.digest(
            label: "numiseal.proof-transcript.v1",
            bytes: numiSealEncodeUInt16(bodyVersion)
                + publicStatement.digest.superNeoBytes
                + numiSealEncodeCount(aggregateCount)
                + numiSealEncodeCount(laneProofs.count)
                + laneProofs.flatMap { $0.proofDigest.superNeoBytes }
                + componentDigestRoot.superNeoBytes
        )
    }

    private static func validateLaneProofOrdering(_ laneProofs: [NumiSealLaneProof]) throws {
        var previousLaneKeyBytes: [UInt8]?
        var previousAggregateIndex: Int?
        for laneProof in laneProofs {
            let laneKeyBytes = laneProof.laneKey.superNeoBytes
            if let previousLaneKeyBytes, let previousAggregateIndex {
                if laneKeyBytes == previousLaneKeyBytes {
                    guard previousAggregateIndex < laneProof.aggregateIndex else {
                        throw SuperNeoError.invalidEncoding("NumiSeal lane proofs must be lane-major and aggregate-index sorted")
                    }
                } else {
                    guard previousLaneKeyBytes.lexicographicallyPrecedes(laneKeyBytes) else {
                        throw SuperNeoError.invalidEncoding("NumiSeal lane proofs must be lane-major and aggregate-index sorted")
                    }
                }
            }
            previousLaneKeyBytes = laneKeyBytes
            previousAggregateIndex = laneProof.aggregateIndex
        }
    }
}

public enum NumiSealResidualMode: UInt8, Equatable, Sendable {
    case immediate = 1
}

public enum NumiSealCarryMode: UInt8, Equatable, Sendable {
    case none = 0
    case optional = 1
    case required = 2
    case typedOptional = 3
    case typedRequired = 4
}

public struct NumiSealTerminalProofAcceptancePolicy: Equatable, Sendable {
    public let profileID: UInt16
    public let shapeDigest: Digest256
    public let statementDigest: Digest256
    public let verifierKeyDigest: Digest256
    public let transcriptDomain: Digest256
    public let acceptedLaneIDs: Set<NumiSealLaneID>
    public let maximumProofByteCount: Int?
    public let maximumLaneCount: Int?
    public let maximumAggregatesPerLane: Int?
    public let acceptedResidualMode: NumiSealResidualMode
    public let acceptedCarryMode: NumiSealCarryMode

    public init(
        profileID: UInt16 = SuperNeoParameterProfile.goldilocksPhi81.profileID,
        shapeDigest: Digest256,
        statementDigest: Digest256,
        verifierKeyDigest: Digest256,
        transcriptDomain: Digest256 = Digest256.hash("SuperNeo-NuMetal.numiseal.v1"),
        acceptedLaneIDs: Set<NumiSealLaneID>,
        maximumProofByteCount: Int? = nil,
        maximumLaneCount: Int? = nil,
        maximumAggregatesPerLane: Int? = nil,
        acceptedResidualMode: NumiSealResidualMode = .immediate,
        acceptedCarryMode: NumiSealCarryMode = .none
    ) {
        self.profileID = profileID
        self.shapeDigest = shapeDigest
        self.statementDigest = statementDigest
        self.verifierKeyDigest = verifierKeyDigest
        self.transcriptDomain = transcriptDomain
        self.acceptedLaneIDs = acceptedLaneIDs
        self.maximumProofByteCount = maximumProofByteCount
        self.maximumLaneCount = maximumLaneCount
        self.maximumAggregatesPerLane = maximumAggregatesPerLane
        self.acceptedResidualMode = acceptedResidualMode
        self.acceptedCarryMode = acceptedCarryMode
    }

    public func preflight(
        proofBytes: [UInt8],
        parameters: SuperNeoParameters = .goldilocks
    ) throws -> NumiSealProofEnvelope {
        let header = try ProofEnvelopeHeader.parsePrefix(from: proofBytes)
        _ = try context(for: header, totalByteCount: proofBytes.count)
        let envelope = try NumiSealProofEnvelope(bytes: proofBytes, parameters: parameters)
        try validate(proof: envelope.proof)
        return envelope
    }

    public func verify(
        proofBytes: [UInt8],
        shape: CCSShape,
        key: AjtaiCommitmentKey,
        parameters: SuperNeoParameters = .goldilocks,
        metalWorkspace: SuperNeoMetalWorkspace? = nil,
        executionPolicy: SuperNeoExecutionPolicy = .default
    ) throws -> NumiSealProofEnvelope {
        let envelope = try preflight(proofBytes: proofBytes, parameters: parameters)
        try verify(
            proof: envelope.proof,
            shape: shape,
            key: key,
            parameters: parameters,
            metalWorkspace: metalWorkspace,
            executionPolicy: executionPolicy
        )
        return envelope
    }

    public func verify(
        proof: NumiSealProof,
        shape: CCSShape,
        key: AjtaiCommitmentKey,
        parameters: SuperNeoParameters = .goldilocks,
        metalWorkspace: SuperNeoMetalWorkspace? = nil,
        executionPolicy: SuperNeoExecutionPolicy = .default
    ) throws {
        try validate(proof: proof)
        guard shape.shapeDigest == shapeDigest else {
            throw SuperNeoError.verificationFailed("NumiSeal verification shape mismatch")
        }
        guard key.verifierKeyDigest == verifierKeyDigest else {
            throw SuperNeoError.verificationFailed("NumiSeal verification verifier key mismatch")
        }
        guard key.parameters == parameters else {
            throw SuperNeoError.verificationFailed("NumiSeal verification key parameters mismatch")
        }
        guard key.matrix.columns == shape.nRing else {
            throw SuperNeoError.verificationFailed("NumiSeal verification key shape mismatch")
        }
        for laneProof in proof.laneProofs {
            switch acceptedResidualMode {
            case .immediate:
                guard try laneProof.residualOpening.verifyCEOpening(
                    shape: shape,
                    key: key,
                    parameters: parameters,
                    metalWorkspace: metalWorkspace,
                    executionPolicy: executionPolicy
                ) else {
                    throw SuperNeoError.verificationFailed("NumiSeal residual CE opening proof verification failed")
                }
            }
        }
    }

    public func context(for header: ProofEnvelopeHeader, totalByteCount: Int) throws -> ProofEnvelopeContext {
        try validateLimits(totalByteCount: totalByteCount)
        try header.validateEnvelopeLength(totalByteCount: totalByteCount)
        guard header.kind == .numiSealTerminal else {
            throw SuperNeoError.verificationFailed("NumiSeal terminal proof required")
        }
        let expectedContext = ProofEnvelopeContext(
            profileID: profileID,
            kind: .numiSealTerminal,
            shapeDigest: shapeDigest,
            statementDigest: statementDigest,
            verifierKeyDigest: verifierKeyDigest,
            transcriptDomain: transcriptDomain
        )
        guard header.ctcoContextBinder == expectedContext.ctcoContextBinder else {
            throw SuperNeoError.verificationFailed("NumiSeal CTCO context binder mismatch")
        }
        return expectedContext
    }

    public func validate(proof: NumiSealProof) throws {
        try validateLimits(totalByteCount: nil)
        guard !acceptedLaneIDs.isEmpty else {
            throw SuperNeoError.invalidParameter("NumiSeal policy must accept at least one lane ID")
        }
        try proof.publicStatement.validate(
            against: NumiSealAcceptancePolicy(
                profileID: profileID,
                shapeDigest: shapeDigest,
                statementDigest: statementDigest,
                verifierKeyDigest: verifierKeyDigest,
                transcriptDomain: transcriptDomain,
                acceptedLaneIDs: acceptedLaneIDs,
                maximumProofByteCount: maximumProofByteCount
            )
        )
        if let maximumLaneCount {
            guard proof.publicStatement.laneSummaries.count <= maximumLaneCount else {
                throw SuperNeoError.verificationFailed("NumiSeal lane count exceeds policy maximum")
            }
        }
        let publicStatementLaneKeys = Set(proof.publicStatement.laneSummaries.map(\.laneKey))
        var aggregatesByLane: [NumiSealLaneKey: Int] = [:]
        for laneProof in proof.laneProofs {
            guard acceptedLaneIDs.contains(laneProof.laneKey.laneID) else {
                throw SuperNeoError.verificationFailed("NumiSeal lane proof lane is not accepted by policy")
            }
            guard publicStatementLaneKeys.contains(laneProof.laneKey) else {
                throw SuperNeoError.verificationFailed("NumiSeal lane proof is not covered by public statement")
            }
            let expectedAggregateIndex = aggregatesByLane[laneProof.laneKey, default: 0]
            guard laneProof.aggregateIndex == expectedAggregateIndex else {
                throw SuperNeoError.verificationFailed("NumiSeal lane proof aggregate indices must be contiguous")
            }
            switch acceptedResidualMode {
            case .immediate:
                try laneProof.residualOpening.validate(laneProof: laneProof)
            }
            aggregatesByLane[laneProof.laneKey] = expectedAggregateIndex + 1
            switch acceptedCarryMode {
            case .none:
                guard laneProof.optionalCarryClaim == nil else {
                    throw SuperNeoError.verificationFailed("NumiSeal carry claims are not accepted by policy")
                }
            case .optional:
                break
            case .required:
                guard laneProof.optionalCarryClaim != nil else {
                    throw SuperNeoError.verificationFailed("NumiSeal carry claim required by policy")
                }
            case .typedOptional:
                if let claim = laneProof.optionalCarryClaim {
                    guard claim.typedStatement != nil else {
                        throw SuperNeoError.verificationFailed("NumiSeal typed carry claim is malformed")
                    }
                }
            case .typedRequired:
                guard let claim = laneProof.optionalCarryClaim else {
                    throw SuperNeoError.verificationFailed("NumiSeal typed carry claim required by policy")
                }
                guard claim.typedStatement != nil else {
                    throw SuperNeoError.verificationFailed("NumiSeal typed carry claim is malformed")
                }
            }
        }
        for summary in proof.publicStatement.laneSummaries {
            guard let aggregateCount = aggregatesByLane[summary.laneKey] else {
                throw SuperNeoError.verificationFailed("NumiSeal lane summary has no lane proof")
            }
            guard aggregateCount <= summary.obligationCount else {
                throw SuperNeoError.verificationFailed("NumiSeal aggregate count exceeds lane obligation count")
            }
        }
        if let maximumAggregatesPerLane {
            for count in aggregatesByLane.values {
                guard count <= maximumAggregatesPerLane else {
                    throw SuperNeoError.verificationFailed("NumiSeal aggregate count exceeds policy maximum")
                }
            }
        }
    }

    private func validateLimits(totalByteCount: Int?) throws {
        if let maximumProofByteCount {
            guard maximumProofByteCount > 0 else {
                throw SuperNeoError.invalidParameter("NumiSeal maximum proof byte count must be positive")
            }
            if let totalByteCount {
                guard totalByteCount <= maximumProofByteCount else {
                    throw SuperNeoError.verificationFailed("NumiSeal proof byte count exceeds policy maximum")
                }
            }
        }
        if let maximumLaneCount {
            guard maximumLaneCount > 0 else {
                throw SuperNeoError.invalidParameter("NumiSeal maximum lane count must be positive")
            }
        }
        if let maximumAggregatesPerLane {
            guard maximumAggregatesPerLane > 0 else {
                throw SuperNeoError.invalidParameter("NumiSeal maximum aggregates per lane must be positive")
            }
        }
        switch acceptedResidualMode {
        case .immediate:
            break
        }
    }
}

public struct NumiSealProofEnvelope: Equatable, Sendable, SuperNeoByteEncodable {
    public let header: ProofEnvelopeHeader
    public let proof: NumiSealProof

    public init(context: ProofEnvelopeContext, proof: NumiSealProof) throws {
        guard context.kind == .numiSealTerminal else {
            throw SuperNeoError.invalidParameter("NumiSealProofEnvelope only supports numiSealTerminal kind")
        }
        let body = proof.superNeoBytes
        guard body.count <= Int(UInt32.max) else {
            throw SuperNeoError.invalidEncoding("NumiSeal proof body too large")
        }
        self.header = ProofEnvelopeHeader(
            profileID: context.profileID,
            kind: context.kind,
            shapeDigest: context.shapeDigest,
            statementDigest: context.statementDigest,
            verifierKeyDigest: context.verifierKeyDigest,
            transcriptDomain: context.transcriptDomain,
            bodyLength: UInt32(body.count)
        )
        self.proof = proof
    }

    public init(bytes: [UInt8], parameters: SuperNeoParameters = .goldilocks) throws {
        var reader = ByteReader(bytes)
        let header = try ProofEnvelopeHeader.parsePrefix(from: bytes)
        try header.validateEnvelopeLength(totalByteCount: bytes.count)
        guard header.kind == .numiSealTerminal else {
            throw SuperNeoError.invalidEncoding("NumiSeal proof envelope kind mismatch")
        }
        _ = try reader.readData(count: ProofEnvelopeHeader.byteCount)
        let body = try reader.readData(count: Int(header.bodyLength))
        try reader.finish()
        self.header = header
        self.proof = try NumiSealProof(bytes: body, parameters: parameters)
    }

    public var superNeoBytes: [UInt8] {
        header.superNeoBytes + proof.superNeoBytes
    }
}

private enum NumiSealProofReaders {
    static func readSumcheckProof(from bytes: [UInt8]) throws -> SumcheckProof {
        var reader = ByteReader(bytes)
        let proof = try reader.readNumiSealSumcheckProof()
        try reader.finish()
        guard proof.superNeoBytes == bytes else {
            throw SuperNeoError.invalidEncoding("NumiSeal sum-check proof is not canonical")
        }
        return proof
    }
}

private extension ByteReader {
    mutating func readNumiSealProofComponentBytes(
        maximum: Int = NumiSealWireLimits.maximumProofComponentByteCount,
        name: String
    ) throws -> [UInt8] {
        let byteCount = try readCount(
            maximum: maximum,
            name: "\(name) byte",
            elementByteWidth: 1
        )
        guard byteCount > 0 else {
            throw SuperNeoError.invalidEncoding("\(name) cannot be empty")
        }
        return try readData(count: byteCount)
    }

    mutating func readNumiSealSumcheckProof() throws -> SumcheckProof {
        let claimedSum = try readNumiSealExt2()
        let roundCount = try readCount(maximum: 64, name: "NumiSeal sum-check round", elementByteWidth: 8)
        let rounds = try (0..<roundCount).map { _ -> SumcheckRound in
            let coeffCount = try readCount(
                maximum: 4096,
                name: "NumiSeal sum-check coefficient",
                elementByteWidth: 16
            )
            guard coeffCount > 0 else {
                throw SuperNeoError.invalidEncoding("NumiSeal sum-check round polynomial cannot be empty")
            }
            return SumcheckRound(coeffs: try (0..<coeffCount).map { _ in try readNumiSealExt2() })
        }
        let finalPointCount = try readCount(
            maximum: 64,
            name: "NumiSeal sum-check final point",
            elementByteWidth: 16
        )
        guard finalPointCount == roundCount else {
            throw SuperNeoError.invalidEncoding("NumiSeal sum-check final point count must match round count")
        }
        let finalPoint = try (0..<finalPointCount).map { _ in try readNumiSealExt2() }
        let finalValue = try readNumiSealExt2()
        return SumcheckProof(
            claimedSum: claimedSum,
            rounds: rounds,
            finalPoint: finalPoint,
            finalValue: finalValue
        )
    }
}

private func numiSealFrame(_ bytes: [UInt8]) -> [UInt8] {
    numiSealEncodeCount(bytes.count) + bytes
}
