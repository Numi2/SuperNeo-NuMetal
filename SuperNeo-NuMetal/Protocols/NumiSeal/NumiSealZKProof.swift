import CryptoKit
import Foundation

public struct NumiSealZKRandomnessSession: Equatable, Sendable, SuperNeoByteEncodable {
    public static let domain = Digest256.hash("SuperNeo-NuMetal.numiseal.zk.randomness-session.v1")

    public let sessionIDDigest: Digest256
    public let sessionMaterialDigest: Digest256

    public init(sessionMaterial: [UInt8], label: String = "product") throws {
        guard !sessionMaterial.isEmpty else {
            throw SuperNeoError.invalidParameter("NumiSealZK randomness session material cannot be empty")
        }
        self.sessionMaterialDigest = NumiSealEncoding.digest(
            label: "numiseal.zk.randomness-session.material.v1",
            bytes: sessionMaterial
        )
        self.sessionIDDigest = NumiSealEncoding.digest(
            label: "numiseal.zk.randomness-session.id.v1",
            bytes: Array(label.utf8) + sessionMaterialDigest.superNeoBytes
        )
    }

    public static func fresh(label: String = "product") throws -> (session: Self, material: [UInt8]) {
        let key = SymmetricKey(size: .bits256)
        let material = key.withUnsafeBytes { Array($0) }
        return (try Self(sessionMaterial: material, label: label), material)
    }

    public var superNeoBytes: [UInt8] {
        Self.domain.superNeoBytes
            + sessionIDDigest.superNeoBytes
            + sessionMaterialDigest.superNeoBytes
    }
}

public final class NumiSealZKRandomnessReuseGuard: @unchecked Sendable {
    private let lock = NSLock()
    private var consumedSessionIDs: Set<Digest256>

    public init(consumedSessionIDs: Set<Digest256> = []) {
        self.consumedSessionIDs = consumedSessionIDs
    }

    public func consume(_ session: NumiSealZKRandomnessSession) throws {
        lock.lock()
        defer { lock.unlock() }
        guard !consumedSessionIDs.contains(session.sessionIDDigest) else {
            throw SuperNeoError.verificationFailed("NumiSealZK randomness session reuse detected")
        }
        consumedSessionIDs.insert(session.sessionIDDigest)
    }
}

public struct NumiSealZKMaskStatement: Equatable, Sendable, SuperNeoByteEncodable {
    public static let domain = Digest256.hash("SuperNeo-NuMetal.numiseal.zk.mask-statement.v1")
    public static let version: UInt16 = 1

    public let version: UInt16
    public let zkMode: String
    public let laneKey: NumiSealLaneKey
    public let aggregateIndex: Int
    public let columnCount: Int
    public let activeDigitCount: Int
    public let digitTensorDigest: Digest256
    public let maskDigest: Digest256
    public let maskedTensorDigest: Digest256
    public let randomnessSessionDigest: Digest256
    public let statementDigest: Digest256

    public init(
        zkMode: String = NumiSealZK.maskedDigitTensorMode,
        laneKey: NumiSealLaneKey,
        aggregateIndex: Int,
        columnCount: Int,
        activeDigitCount: Int,
        digitTensorDigest: Digest256,
        maskDigest: Digest256,
        maskedTensorDigest: Digest256,
        randomnessSessionDigest: Digest256
    ) throws {
        try Self.validate(
            zkMode: zkMode,
            aggregateIndex: aggregateIndex,
            columnCount: columnCount,
            activeDigitCount: activeDigitCount
        )
        self.version = Self.version
        self.zkMode = zkMode
        self.laneKey = laneKey
        self.aggregateIndex = aggregateIndex
        self.columnCount = columnCount
        self.activeDigitCount = activeDigitCount
        self.digitTensorDigest = digitTensorDigest
        self.maskDigest = maskDigest
        self.maskedTensorDigest = maskedTensorDigest
        self.randomnessSessionDigest = randomnessSessionDigest
        self.statementDigest = Self.computeStatementDigest(
            zkMode: zkMode,
            laneKey: laneKey,
            aggregateIndex: aggregateIndex,
            columnCount: columnCount,
            activeDigitCount: activeDigitCount,
            digitTensorDigest: digitTensorDigest,
            maskDigest: maskDigest,
            maskedTensorDigest: maskedTensorDigest,
            randomnessSessionDigest: randomnessSessionDigest
        )
    }

    public init(bytes: [UInt8]) throws {
        var reader = ByteReader(bytes)
        let domain = try Digest256(reader.readData(count: Digest256.byteCount))
        guard domain == Self.domain else {
            throw SuperNeoError.invalidEncoding("NumiSealZK mask statement domain mismatch")
        }
        let version = try reader.readUInt16()
        guard version == Self.version else {
            throw SuperNeoError.invalidEncoding("unsupported NumiSealZK mask statement version")
        }
        let zkMode = try readZKString(&reader, name: "NumiSealZK mask mode")
        let laneKey = try reader.readNumiSealLaneKey()
        let aggregateIndex = try reader.readCount(
            maximum: NumiSealWireLimits.maximumAggregateCount,
            name: "NumiSealZK mask aggregate index"
        )
        let columnCount = try reader.readCount(
            maximum: NumiSealWireLimits.maximumDigitTensorColumnCount,
            name: "NumiSealZK mask column"
        )
        let activeDigitCount = try reader.readCount(
            maximum: columnCount * CyclotomicRing54.degree,
            name: "NumiSealZK active digit"
        )
        let digitTensorDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        let maskDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        let maskedTensorDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        let randomnessSessionDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        let statementDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        try reader.finish()
        try Self.validate(
            zkMode: zkMode,
            aggregateIndex: aggregateIndex,
            columnCount: columnCount,
            activeDigitCount: activeDigitCount
        )
        let expectedDigest = Self.computeStatementDigest(
            zkMode: zkMode,
            laneKey: laneKey,
            aggregateIndex: aggregateIndex,
            columnCount: columnCount,
            activeDigitCount: activeDigitCount,
            digitTensorDigest: digitTensorDigest,
            maskDigest: maskDigest,
            maskedTensorDigest: maskedTensorDigest,
            randomnessSessionDigest: randomnessSessionDigest
        )
        guard statementDigest == expectedDigest else {
            throw SuperNeoError.invalidEncoding("NumiSealZK mask statement digest mismatch")
        }
        self.version = version
        self.zkMode = zkMode
        self.laneKey = laneKey
        self.aggregateIndex = aggregateIndex
        self.columnCount = columnCount
        self.activeDigitCount = activeDigitCount
        self.digitTensorDigest = digitTensorDigest
        self.maskDigest = maskDigest
        self.maskedTensorDigest = maskedTensorDigest
        self.randomnessSessionDigest = randomnessSessionDigest
        self.statementDigest = statementDigest
    }

    public var superNeoBytes: [UInt8] {
        Self.domain.superNeoBytes
            + numiSealEncodeUInt16(version)
            + numiSealZKEncodeString(zkMode)
            + laneKey.superNeoBytes
            + numiSealEncodeCount(aggregateIndex)
            + numiSealEncodeCount(columnCount)
            + numiSealEncodeCount(activeDigitCount)
            + digitTensorDigest.superNeoBytes
            + maskDigest.superNeoBytes
            + maskedTensorDigest.superNeoBytes
            + randomnessSessionDigest.superNeoBytes
            + statementDigest.superNeoBytes
    }

    private static func validate(
        zkMode: String,
        aggregateIndex: Int,
        columnCount: Int,
        activeDigitCount: Int
    ) throws {
        guard zkMode == NumiSealZK.maskedDigitTensorMode else {
            throw SuperNeoError.invalidParameter("unsupported NumiSealZK mask mode")
        }
        guard aggregateIndex >= 0 else {
            throw SuperNeoError.invalidParameter("NumiSealZK mask aggregate index must be non-negative")
        }
        guard columnCount > 0, columnCount <= NumiSealWireLimits.maximumDigitTensorColumnCount else {
            throw SuperNeoError.invalidParameter("NumiSealZK mask column count is invalid")
        }
        guard activeDigitCount >= 0, activeDigitCount <= columnCount * CyclotomicRing54.degree else {
            throw SuperNeoError.invalidParameter("NumiSealZK active digit count exceeds tensor size")
        }
    }

    private static func computeStatementDigest(
        zkMode: String,
        laneKey: NumiSealLaneKey,
        aggregateIndex: Int,
        columnCount: Int,
        activeDigitCount: Int,
        digitTensorDigest: Digest256,
        maskDigest: Digest256,
        maskedTensorDigest: Digest256,
        randomnessSessionDigest: Digest256
    ) -> Digest256 {
        NumiSealEncoding.digest(
            label: "numiseal.zk.mask-statement.v1",
            bytes: numiSealZKEncodeString(zkMode)
                + laneKey.superNeoBytes
                + numiSealEncodeCount(aggregateIndex)
                + numiSealEncodeCount(columnCount)
                + numiSealEncodeCount(activeDigitCount)
                + digitTensorDigest.superNeoBytes
                + maskDigest.superNeoBytes
                + maskedTensorDigest.superNeoBytes
                + randomnessSessionDigest.superNeoBytes
        )
    }
}

public struct NumiSealZKMaskMaterial: Equatable, Sendable {
    public let statement: NumiSealZKMaskStatement
    public let mask: [CyclotomicRing54]
    public let maskedTensor: [CyclotomicRing54]

    public static func build(
        digitTensor: NumiSealDigitTensor,
        sessionMaterial: [UInt8],
        session: NumiSealZKRandomnessSession,
        provingWorkspace: NumiSealMetalProvingWorkspace? = nil
    ) throws -> Self {
        let mask = try maskVector(
            columnCount: digitTensor.columnCount,
            sessionMaterial: sessionMaterial,
            laneKey: digitTensor.laneKey,
            aggregateIndex: digitTensor.aggregateIndex
        )
        let maskedTensor = try provingWorkspace?.applyMask(
            digitTensor: digitTensor.message,
            mask: mask
        ) ?? SuperNeoMetalBackend.numiSealApplyMaskReference(
            digitTensor: digitTensor.message,
            mask: mask
        )
        let maskDigest = tensorDigest(label: "numiseal.zk.mask.v1", tensor: mask)
        let maskedTensorDigest = tensorDigest(label: "numiseal.zk.masked-tensor.v1", tensor: maskedTensor)
        let statement = try NumiSealZKMaskStatement(
            laneKey: digitTensor.laneKey,
            aggregateIndex: digitTensor.aggregateIndex,
            columnCount: digitTensor.columnCount,
            activeDigitCount: digitTensor.activeDigitCount,
            digitTensorDigest: digitTensor.digest,
            maskDigest: maskDigest,
            maskedTensorDigest: maskedTensorDigest,
            randomnessSessionDigest: session.sessionIDDigest
        )
        return Self(statement: statement, mask: mask, maskedTensor: maskedTensor)
    }

    public static func tensorDigest(label: String, tensor: [CyclotomicRing54]) -> Digest256 {
        NumiSealEncoding.digest(
            label: label,
            bytes: numiSealEncodeCount(tensor.count) + tensor.flatMap(\.superNeoBytes)
        )
    }

    private static func maskVector(
        columnCount: Int,
        sessionMaterial: [UInt8],
        laneKey: NumiSealLaneKey,
        aggregateIndex: Int
    ) throws -> [CyclotomicRing54] {
        guard columnCount > 0 else {
            throw SuperNeoError.invalidParameter("NumiSealZK mask column count must be positive")
        }
        var rings: [CyclotomicRing54] = []
        rings.reserveCapacity(columnCount)
        var counter = 0
        for column in 0..<columnCount {
            var coefficients: [GoldilocksField] = []
            coefficients.reserveCapacity(CyclotomicRing54.degree)
            for coefficient in 0..<CyclotomicRing54.degree {
                coefficients.append(
                    NumiSealZKMaskSampler.sampleFieldElement(
                        sessionMaterial: sessionMaterial,
                        laneKey: laneKey,
                        aggregateIndex: aggregateIndex,
                        column: column,
                        coefficient: coefficient,
                        counter: &counter
                    )
                )
            }
            rings.append(CyclotomicRing54(coefficients))
        }
        return rings
    }
}

public enum NumiSealZKMaskSampler {
    public static let domainLabel = "SuperNeo-NuMetal.numiseal.zk.mask-expand.v2"
    public static let candidateBitWidth = 64
    public static let rejectedCandidateCount = UInt64.max - GoldilocksField.modulus + 1

    public static func accepts(candidate: UInt64) -> Bool {
        candidate < GoldilocksField.modulus
    }

    static func sampleFieldElement(
        sessionMaterial: [UInt8],
        laneKey: NumiSealLaneKey,
        aggregateIndex: Int,
        column: Int,
        coefficient: Int,
        counter: inout Int
    ) -> GoldilocksField {
        while true {
            let digest = Digest256.hash(
                Array(domainLabel.utf8)
                    + sessionMaterial
                    + laneKey.superNeoBytes
                    + numiSealEncodeCount(aggregateIndex)
                    + numiSealEncodeCount(column)
                    + numiSealEncodeCount(coefficient)
                    + numiSealEncodeCount(counter)
            )
            counter += 1
            let candidate = UInt64(littleEndianBytes: Array(digest.bytes.prefix(8)))
            if accepts(candidate: candidate) {
                return GoldilocksField(candidate)
            }
        }
    }
}

public struct NumiSealZKMaskedResidualStatement: Equatable, Sendable, SuperNeoByteEncodable {
    public static let domain = Digest256.hash("SuperNeo-NuMetal.numiseal.zk.masked-residual-statement.v2")
    public static let version: UInt16 = 2

    public let version: UInt16
    public let zkMode: String
    public let laneKey: NumiSealLaneKey
    public let aggregateIndex: Int
    public let residualOpeningDigest: Digest256
    public let linearResidualDigest: Digest256
    public let sumcheckProofDigest: Digest256
    public let finalPointDigest: Digest256
    public let digitTensorDigest: Digest256
    public let maskDigest: Digest256
    public let maskedTensorDigest: Digest256
    public let decompositionCommitmentDigest: Digest256
    public let claimedDigitEvaluation: GoldilocksExt2
    public let maskEvaluation: GoldilocksExt2
    public let maskedDigitEvaluation: GoldilocksExt2
    public let accumulationChallengeDigest: Digest256
    public let denseFoldDigest: Digest256
    public let equalityWeightDigest: Digest256
    public let sumcheckAccumulationDigest: Digest256
    public let statementDigest: Digest256

    public init(
        zkMode: String = NumiSealZK.maskedDigitTensorMode,
        laneKey: NumiSealLaneKey,
        aggregateIndex: Int,
        residualOpeningDigest: Digest256,
        linearResidualDigest: Digest256,
        sumcheckProofDigest: Digest256,
        finalPointDigest: Digest256,
        digitTensorDigest: Digest256,
        maskDigest: Digest256,
        maskedTensorDigest: Digest256,
        decompositionCommitmentDigest: Digest256,
        claimedDigitEvaluation: GoldilocksExt2,
        maskEvaluation: GoldilocksExt2,
        maskedDigitEvaluation: GoldilocksExt2,
        accumulationChallengeDigest: Digest256,
        denseFoldDigest: Digest256,
        equalityWeightDigest: Digest256,
        sumcheckAccumulationDigest: Digest256
    ) throws {
        try Self.validate(
            zkMode: zkMode,
            aggregateIndex: aggregateIndex,
            claimedDigitEvaluation: claimedDigitEvaluation,
            maskEvaluation: maskEvaluation,
            maskedDigitEvaluation: maskedDigitEvaluation
        )
        self.version = Self.version
        self.zkMode = zkMode
        self.laneKey = laneKey
        self.aggregateIndex = aggregateIndex
        self.residualOpeningDigest = residualOpeningDigest
        self.linearResidualDigest = linearResidualDigest
        self.sumcheckProofDigest = sumcheckProofDigest
        self.finalPointDigest = finalPointDigest
        self.digitTensorDigest = digitTensorDigest
        self.maskDigest = maskDigest
        self.maskedTensorDigest = maskedTensorDigest
        self.decompositionCommitmentDigest = decompositionCommitmentDigest
        self.claimedDigitEvaluation = claimedDigitEvaluation
        self.maskEvaluation = maskEvaluation
        self.maskedDigitEvaluation = maskedDigitEvaluation
        self.accumulationChallengeDigest = accumulationChallengeDigest
        self.denseFoldDigest = denseFoldDigest
        self.equalityWeightDigest = equalityWeightDigest
        self.sumcheckAccumulationDigest = sumcheckAccumulationDigest
        self.statementDigest = Self.computeStatementDigest(
            zkMode: zkMode,
            laneKey: laneKey,
            aggregateIndex: aggregateIndex,
            residualOpeningDigest: residualOpeningDigest,
            linearResidualDigest: linearResidualDigest,
            sumcheckProofDigest: sumcheckProofDigest,
            finalPointDigest: finalPointDigest,
            digitTensorDigest: digitTensorDigest,
            maskDigest: maskDigest,
            maskedTensorDigest: maskedTensorDigest,
            decompositionCommitmentDigest: decompositionCommitmentDigest,
            claimedDigitEvaluation: claimedDigitEvaluation,
            maskEvaluation: maskEvaluation,
            maskedDigitEvaluation: maskedDigitEvaluation,
            accumulationChallengeDigest: accumulationChallengeDigest,
            denseFoldDigest: denseFoldDigest,
            equalityWeightDigest: equalityWeightDigest,
            sumcheckAccumulationDigest: sumcheckAccumulationDigest
        )
    }

    public init(bytes: [UInt8]) throws {
        var reader = ByteReader(bytes)
        let domain = try Digest256(reader.readData(count: Digest256.byteCount))
        guard domain == Self.domain else {
            throw SuperNeoError.invalidEncoding("NumiSealZK masked residual statement domain mismatch")
        }
        let version = try reader.readUInt16()
        guard version == Self.version else {
            throw SuperNeoError.invalidEncoding("unsupported NumiSealZK masked residual statement version")
        }
        let zkMode = try readZKString(&reader, name: "NumiSealZK masked residual mode")
        let laneKey = try reader.readNumiSealLaneKey()
        let aggregateIndex = try reader.readCount(
            maximum: NumiSealWireLimits.maximumAggregateCount,
            name: "NumiSealZK masked residual aggregate index"
        )
        let residualOpeningDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        let linearResidualDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        let sumcheckProofDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        let finalPointDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        let digitTensorDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        let maskDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        let maskedTensorDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        let decompositionCommitmentDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        let claimedDigitEvaluation = try reader.readNumiSealExt2()
        let maskEvaluation = try reader.readNumiSealExt2()
        let maskedDigitEvaluation = try reader.readNumiSealExt2()
        let accumulationChallengeDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        let denseFoldDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        let equalityWeightDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        let sumcheckAccumulationDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        let statementDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        try reader.finish()
        try Self.validate(
            zkMode: zkMode,
            aggregateIndex: aggregateIndex,
            claimedDigitEvaluation: claimedDigitEvaluation,
            maskEvaluation: maskEvaluation,
            maskedDigitEvaluation: maskedDigitEvaluation
        )
        let expectedDigest = Self.computeStatementDigest(
            zkMode: zkMode,
            laneKey: laneKey,
            aggregateIndex: aggregateIndex,
            residualOpeningDigest: residualOpeningDigest,
            linearResidualDigest: linearResidualDigest,
            sumcheckProofDigest: sumcheckProofDigest,
            finalPointDigest: finalPointDigest,
            digitTensorDigest: digitTensorDigest,
            maskDigest: maskDigest,
            maskedTensorDigest: maskedTensorDigest,
            decompositionCommitmentDigest: decompositionCommitmentDigest,
            claimedDigitEvaluation: claimedDigitEvaluation,
            maskEvaluation: maskEvaluation,
            maskedDigitEvaluation: maskedDigitEvaluation,
            accumulationChallengeDigest: accumulationChallengeDigest,
            denseFoldDigest: denseFoldDigest,
            equalityWeightDigest: equalityWeightDigest,
            sumcheckAccumulationDigest: sumcheckAccumulationDigest
        )
        guard statementDigest == expectedDigest else {
            throw SuperNeoError.invalidEncoding("NumiSealZK masked residual statement digest mismatch")
        }
        self.version = version
        self.zkMode = zkMode
        self.laneKey = laneKey
        self.aggregateIndex = aggregateIndex
        self.residualOpeningDigest = residualOpeningDigest
        self.linearResidualDigest = linearResidualDigest
        self.sumcheckProofDigest = sumcheckProofDigest
        self.finalPointDigest = finalPointDigest
        self.digitTensorDigest = digitTensorDigest
        self.maskDigest = maskDigest
        self.maskedTensorDigest = maskedTensorDigest
        self.decompositionCommitmentDigest = decompositionCommitmentDigest
        self.claimedDigitEvaluation = claimedDigitEvaluation
        self.maskEvaluation = maskEvaluation
        self.maskedDigitEvaluation = maskedDigitEvaluation
        self.accumulationChallengeDigest = accumulationChallengeDigest
        self.denseFoldDigest = denseFoldDigest
        self.equalityWeightDigest = equalityWeightDigest
        self.sumcheckAccumulationDigest = sumcheckAccumulationDigest
        self.statementDigest = statementDigest
    }

    public var superNeoBytes: [UInt8] {
        Self.domain.superNeoBytes
            + numiSealEncodeUInt16(version)
            + numiSealZKEncodeString(zkMode)
            + laneKey.superNeoBytes
            + numiSealEncodeCount(aggregateIndex)
            + residualOpeningDigest.superNeoBytes
            + linearResidualDigest.superNeoBytes
            + sumcheckProofDigest.superNeoBytes
            + finalPointDigest.superNeoBytes
            + digitTensorDigest.superNeoBytes
            + maskDigest.superNeoBytes
            + maskedTensorDigest.superNeoBytes
            + decompositionCommitmentDigest.superNeoBytes
            + claimedDigitEvaluation.superNeoBytes
            + maskEvaluation.superNeoBytes
            + maskedDigitEvaluation.superNeoBytes
            + accumulationChallengeDigest.superNeoBytes
            + denseFoldDigest.superNeoBytes
            + equalityWeightDigest.superNeoBytes
            + sumcheckAccumulationDigest.superNeoBytes
            + statementDigest.superNeoBytes
    }

    public static func build(
        laneProof: NumiSealLaneProof,
        digitTensor: NumiSealDigitTensor,
        maskMaterial: NumiSealZKMaskMaterial,
        provingWorkspace: NumiSealMetalProvingWorkspace? = nil
    ) throws -> Self {
        guard digitTensor.laneKey == laneProof.laneKey else {
            throw SuperNeoError.invalidParameter("NumiSealZK masked residual digit tensor lane mismatch")
        }
        guard digitTensor.aggregateIndex == laneProof.aggregateIndex else {
            throw SuperNeoError.invalidParameter("NumiSealZK masked residual digit tensor aggregate mismatch")
        }
        guard digitTensor.digest == laneProof.residualOpening.digitTensorDigest,
              digitTensor.digest == maskMaterial.statement.digitTensorDigest else {
            throw SuperNeoError.invalidParameter("NumiSealZK masked residual digit tensor digest mismatch")
        }
        guard maskMaterial.statement.laneKey == laneProof.laneKey,
              maskMaterial.statement.aggregateIndex == laneProof.aggregateIndex else {
            throw SuperNeoError.invalidParameter("NumiSealZK masked residual mask scope mismatch")
        }
        let digitFields = fields(digitTensor.message)
        let maskFields = fields(maskMaterial.mask)
        let maskedFields = fields(maskMaterial.maskedTensor)
        guard digitFields.count == maskFields.count, digitFields.count == maskedFields.count else {
            throw SuperNeoError.invalidParameter("NumiSealZK masked residual tensor length mismatch")
        }
        let accumulationWeights = Self.deriveAccumulationWeights(
            laneProof: laneProof,
            maskStatement: maskMaterial.statement
        )
        let accumulationChallengeDigest = Self.computeAccumulationChallengeDigest(
            laneProof: laneProof,
            maskStatement: maskMaterial.statement,
            weights: accumulationWeights
        )
        let denseFold: [GoldilocksField]
        let accumulation: [GoldilocksField]
        if let provingWorkspace {
            let fused = try provingWorkspace.applyMaskAndAccumulate(
                digitTensor: digitTensor.message,
                mask: maskMaterial.mask,
                weights: accumulationWeights
            )
            guard fused.maskedTensor == maskMaterial.maskedTensor else {
                throw SuperNeoError.verificationFailed("NumiSealZK masked residual fused mask mismatch")
            }
            denseFold = fields(fused.maskedTensor)
            accumulation = fused.accumulation
        } else {
            denseFold = try SuperNeoMetalBackend.numiSealDenseFoldReference(
                lhs: digitFields,
                rhs: maskFields,
                challenge: .one
            )
            accumulation = try SuperNeoMetalBackend.numiSealSumcheckAccumulateReference(
                terms: [digitFields, maskFields, maskedFields],
                weights: accumulationWeights
            )
        }
        guard denseFold == maskedFields else {
            throw SuperNeoError.verificationFailed("NumiSealZK masked residual dense fold mismatch")
        }
        let equalityWeights = try provingWorkspace?.equalityWeights(
            point: laneProof.sumcheckProof.finalPoint.map(\.c0)
        ) ?? SuperNeoMetalBackend.numiSealEqualityWeightsReference(
            point: laneProof.sumcheckProof.finalPoint.map(\.c0)
        )
        let paddedMaskFields = try padded(fields: maskFields, for: laneProof.sumcheckProof.finalPoint)
        let maskEvaluation = try MultilinearEvaluation.evaluate(
            paddedMaskFields,
            at: laneProof.sumcheckProof.finalPoint
        )
        let claimedDigitEvaluation = laneProof.residualOpening.residualStatement.claimedDigitEvaluation
        return try Self(
            laneKey: laneProof.laneKey,
            aggregateIndex: laneProof.aggregateIndex,
            residualOpeningDigest: laneProof.residualOpening.openingDigest,
            linearResidualDigest: laneProof.scalarizationDigest,
            sumcheckProofDigest: NumiSealResidualOpening.sumcheckProofDigest(laneProof.sumcheckProof),
            finalPointDigest: NumiSealCarryStatement.finalPointDigest(laneProof.sumcheckProof.finalPoint),
            digitTensorDigest: digitTensor.digest,
            maskDigest: maskMaterial.statement.maskDigest,
            maskedTensorDigest: maskMaterial.statement.maskedTensorDigest,
            decompositionCommitmentDigest: laneProof.residualOpening.decompositionCommitmentDigest,
            claimedDigitEvaluation: claimedDigitEvaluation,
            maskEvaluation: maskEvaluation,
            maskedDigitEvaluation: claimedDigitEvaluation + maskEvaluation,
            accumulationChallengeDigest: accumulationChallengeDigest,
            denseFoldDigest: fieldVectorDigest(label: "numiseal.zk.masked-residual.dense-fold.v1", fields: denseFold),
            equalityWeightDigest: fieldVectorDigest(label: "numiseal.zk.masked-residual.eq-weights.v1", fields: equalityWeights),
            sumcheckAccumulationDigest: fieldVectorDigest(
                label: "numiseal.zk.masked-residual.sumcheck-accumulation.v1",
                fields: accumulation
            )
        )
    }

    public func validate(laneProof: NumiSealLaneProof, maskStatement: NumiSealZKMaskStatement) throws {
        guard zkMode == maskStatement.zkMode else {
            throw SuperNeoError.verificationFailed("NumiSealZK masked residual mode mismatch")
        }
        guard laneKey == laneProof.laneKey, laneKey == maskStatement.laneKey else {
            throw SuperNeoError.verificationFailed("NumiSealZK masked residual lane mismatch")
        }
        guard aggregateIndex == laneProof.aggregateIndex, aggregateIndex == maskStatement.aggregateIndex else {
            throw SuperNeoError.verificationFailed("NumiSealZK masked residual aggregate mismatch")
        }
        guard residualOpeningDigest == laneProof.residualOpening.openingDigest else {
            throw SuperNeoError.verificationFailed("NumiSealZK masked residual opening digest mismatch")
        }
        guard linearResidualDigest == laneProof.scalarizationDigest else {
            throw SuperNeoError.verificationFailed("NumiSealZK masked residual scalarization digest mismatch")
        }
        guard sumcheckProofDigest == NumiSealResidualOpening.sumcheckProofDigest(laneProof.sumcheckProof) else {
            throw SuperNeoError.verificationFailed("NumiSealZK masked residual sum-check digest mismatch")
        }
        guard finalPointDigest == NumiSealCarryStatement.finalPointDigest(laneProof.sumcheckProof.finalPoint) else {
            throw SuperNeoError.verificationFailed("NumiSealZK masked residual final point mismatch")
        }
        guard digitTensorDigest == maskStatement.digitTensorDigest,
              maskDigest == maskStatement.maskDigest,
              maskedTensorDigest == maskStatement.maskedTensorDigest else {
            throw SuperNeoError.verificationFailed("NumiSealZK masked residual mask statement mismatch")
        }
        guard decompositionCommitmentDigest == laneProof.residualOpening.decompositionCommitmentDigest else {
            throw SuperNeoError.verificationFailed("NumiSealZK masked residual decomposition commitment mismatch")
        }
        guard claimedDigitEvaluation == laneProof.residualOpening.residualStatement.claimedDigitEvaluation else {
            throw SuperNeoError.verificationFailed("NumiSealZK masked residual claimed digit mismatch")
        }
        guard maskedDigitEvaluation == claimedDigitEvaluation + maskEvaluation else {
            throw SuperNeoError.verificationFailed("NumiSealZK masked residual evaluation mismatch")
        }
        let accumulationWeights = Self.deriveAccumulationWeights(
            laneProof: laneProof,
            maskStatement: maskStatement
        )
        let expectedAccumulationChallengeDigest = Self.computeAccumulationChallengeDigest(
            laneProof: laneProof,
            maskStatement: maskStatement,
            weights: accumulationWeights
        )
        guard accumulationChallengeDigest == expectedAccumulationChallengeDigest else {
            throw SuperNeoError.verificationFailed("NumiSealZK masked residual accumulation challenge mismatch")
        }
        let expectedEqualityWeights = try SuperNeoMetalBackend.numiSealEqualityWeightsReference(
            point: laneProof.sumcheckProof.finalPoint.map(\.c0)
        )
        let expectedEqualityWeightDigest = Self.fieldVectorDigest(
            label: "numiseal.zk.masked-residual.eq-weights.v1",
            fields: expectedEqualityWeights
        )
        guard equalityWeightDigest == expectedEqualityWeightDigest else {
            throw SuperNeoError.verificationFailed("NumiSealZK masked residual equality weight digest mismatch")
        }
    }

    private static func validate(
        zkMode: String,
        aggregateIndex: Int,
        claimedDigitEvaluation: GoldilocksExt2,
        maskEvaluation: GoldilocksExt2,
        maskedDigitEvaluation: GoldilocksExt2
    ) throws {
        guard zkMode == NumiSealZK.maskedDigitTensorMode else {
            throw SuperNeoError.invalidParameter("unsupported NumiSealZK masked residual mode")
        }
        guard aggregateIndex >= 0 else {
            throw SuperNeoError.invalidParameter("NumiSealZK masked residual aggregate index must be non-negative")
        }
        guard maskedDigitEvaluation == claimedDigitEvaluation + maskEvaluation else {
            throw SuperNeoError.invalidParameter("NumiSealZK masked residual evaluation mismatch")
        }
    }

    private static func computeStatementDigest(
        zkMode: String,
        laneKey: NumiSealLaneKey,
        aggregateIndex: Int,
        residualOpeningDigest: Digest256,
        linearResidualDigest: Digest256,
        sumcheckProofDigest: Digest256,
        finalPointDigest: Digest256,
        digitTensorDigest: Digest256,
        maskDigest: Digest256,
        maskedTensorDigest: Digest256,
        decompositionCommitmentDigest: Digest256,
        claimedDigitEvaluation: GoldilocksExt2,
        maskEvaluation: GoldilocksExt2,
        maskedDigitEvaluation: GoldilocksExt2,
        accumulationChallengeDigest: Digest256,
        denseFoldDigest: Digest256,
        equalityWeightDigest: Digest256,
        sumcheckAccumulationDigest: Digest256
    ) -> Digest256 {
        NumiSealEncoding.digest(
            label: "numiseal.zk.masked-residual-statement.v2",
            bytes: numiSealZKEncodeString(zkMode)
                + laneKey.superNeoBytes
                + numiSealEncodeCount(aggregateIndex)
                + residualOpeningDigest.superNeoBytes
                + linearResidualDigest.superNeoBytes
                + sumcheckProofDigest.superNeoBytes
                + finalPointDigest.superNeoBytes
                + digitTensorDigest.superNeoBytes
                + maskDigest.superNeoBytes
                + maskedTensorDigest.superNeoBytes
                + decompositionCommitmentDigest.superNeoBytes
                + claimedDigitEvaluation.superNeoBytes
                + maskEvaluation.superNeoBytes
                + maskedDigitEvaluation.superNeoBytes
                + accumulationChallengeDigest.superNeoBytes
                + denseFoldDigest.superNeoBytes
                + equalityWeightDigest.superNeoBytes
                + sumcheckAccumulationDigest.superNeoBytes
        )
    }

    private static func fields(_ rings: [CyclotomicRing54]) -> [GoldilocksField] {
        rings.flatMap(\.coefficients)
    }

    private static func padded(
        fields: [GoldilocksField],
        for point: [GoldilocksExt2]
    ) throws -> [GoldilocksField] {
        guard point.count < Int.bitWidth - 1 else {
            throw SuperNeoError.invalidParameter("NumiSealZK masked residual point dimension is too large")
        }
        let paddedCount = 1 << point.count
        guard fields.count <= paddedCount else {
            throw SuperNeoError.invalidParameter("NumiSealZK masked residual tensor exceeds final-point domain")
        }
        return fields + Array(repeating: .zero, count: paddedCount - fields.count)
    }

    private static func fieldVectorDigest(label: String, fields: [GoldilocksField]) -> Digest256 {
        NumiSealEncoding.digest(
            label: label,
            bytes: numiSealEncodeCount(fields.count) + fields.flatMap(\.superNeoBytes)
        )
    }

    private static func deriveAccumulationWeights(
        laneProof: NumiSealLaneProof,
        maskStatement: NumiSealZKMaskStatement
    ) -> [GoldilocksField] {
        var transcript = SumCheckTranscript(
            domainSeparator: "SuperNeo-NuMetal.numiseal.zk.masked-residual-accumulation.v1"
        )
        transcript.absorb(accumulationChallengeBindingBytes(laneProof: laneProof, maskStatement: maskStatement))
        return (0..<3).map { _ in transcript.challengeField() }
    }

    private static func computeAccumulationChallengeDigest(
        laneProof: NumiSealLaneProof,
        maskStatement: NumiSealZKMaskStatement,
        weights: [GoldilocksField]
    ) -> Digest256 {
        NumiSealEncoding.digest(
            label: "numiseal.zk.masked-residual.accumulation-challenge.v1",
            bytes: accumulationChallengeBindingBytes(laneProof: laneProof, maskStatement: maskStatement)
                + numiSealEncodeCount(weights.count)
                + weights.flatMap(\.superNeoBytes)
        )
    }

    private static func accumulationChallengeBindingBytes(
        laneProof: NumiSealLaneProof,
        maskStatement: NumiSealZKMaskStatement
    ) -> [UInt8] {
        laneProof.laneKey.superNeoBytes
            + numiSealEncodeCount(laneProof.aggregateIndex)
            + laneProof.residualOpening.openingDigest.superNeoBytes
            + laneProof.residualOpening.decompositionCommitmentDigest.superNeoBytes
            + laneProof.residualOpening.digitTensorDigest.superNeoBytes
            + laneProof.scalarizationDigest.superNeoBytes
            + NumiSealResidualOpening.sumcheckProofDigest(laneProof.sumcheckProof).superNeoBytes
            + NumiSealCarryStatement.finalPointDigest(laneProof.sumcheckProof.finalPoint).superNeoBytes
            + maskStatement.statementDigest.superNeoBytes
    }
}

public struct NumiSealZKProof: Equatable, Sendable, SuperNeoByteEncodable {
    public static let bodyVersion: UInt16 = 13

    public let bodyVersion: UInt16
    public let zkMode: String
    public let randomnessSessionDigest: Digest256
    public let leakageDigest: Digest256
    public let baseProof: NumiSealProof
    public let maskStatements: [NumiSealZKMaskStatement]
    public let maskedResidualStatements: [NumiSealZKMaskedResidualStatement]
    public let componentDigestRoot: Digest256
    public let transcriptDigest: Digest256

    public init(
        zkMode: String = NumiSealZK.maskedDigitTensorMode,
        randomnessSessionDigest: Digest256,
        baseProof: NumiSealProof,
        maskStatements: [NumiSealZKMaskStatement],
        maskedResidualStatements: [NumiSealZKMaskedResidualStatement]
    ) throws {
        try Self.validate(
            zkMode: zkMode,
            baseProof: baseProof,
            maskStatements: maskStatements,
            maskedResidualStatements: maskedResidualStatements
        )
        try Self.validateSessionBinding(
            randomnessSessionDigest: randomnessSessionDigest,
            maskStatements: maskStatements
        )
        let leakageDigest = Self.computeLeakageDigest(
            zkMode: zkMode,
            baseProof: baseProof,
            maskStatements: maskStatements
        )
        let componentDigestRoot = Self.computeComponentDigestRoot(
            baseProof: baseProof,
            maskStatements: maskStatements,
            maskedResidualStatements: maskedResidualStatements,
            leakageDigest: leakageDigest
        )
        self.bodyVersion = Self.bodyVersion
        self.zkMode = zkMode
        self.randomnessSessionDigest = randomnessSessionDigest
        self.leakageDigest = leakageDigest
        self.baseProof = baseProof
        self.maskStatements = maskStatements
        self.maskedResidualStatements = maskedResidualStatements
        self.componentDigestRoot = componentDigestRoot
        self.transcriptDigest = Self.computeTranscriptDigest(
            bodyVersion: Self.bodyVersion,
            zkMode: zkMode,
            randomnessSessionDigest: randomnessSessionDigest,
            leakageDigest: leakageDigest,
            baseProof: baseProof,
            maskStatements: maskStatements,
            maskedResidualStatements: maskedResidualStatements,
            componentDigestRoot: componentDigestRoot
        )
    }

    public init(bytes: [UInt8], parameters: SuperNeoParameters = .goldilocks) throws {
        var reader = ByteReader(bytes)
        let bodyVersion = try reader.readUInt16()
        guard bodyVersion == Self.bodyVersion else {
            throw SuperNeoError.invalidEncoding("unsupported NumiSealZK proof body version")
        }
        let zkMode = try readZKString(&reader, name: "NumiSealZK mode")
        let randomnessSessionDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        let leakageDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        let baseProof = try NumiSealProof(
            bytes: readZKFrame(&reader, maximum: NumiSealWireLimits.maximumProofComponentByteCount, name: "NumiSealZK base proof"),
            parameters: parameters
        )
        let maskStatementCount = try reader.readCount(
            maximum: NumiSealWireLimits.maximumAggregateCount,
            name: "NumiSealZK mask statement",
            elementByteWidth: 8
        )
        let maskStatements = try (0..<maskStatementCount).map { _ in
            try NumiSealZKMaskStatement(bytes: readZKFrame(&reader, name: "NumiSealZK mask statement"))
        }
        let maskedResidualStatementCount = try reader.readCount(
            maximum: NumiSealWireLimits.maximumAggregateCount,
            name: "NumiSealZK masked residual statement",
            elementByteWidth: 8
        )
        let maskedResidualStatements = try (0..<maskedResidualStatementCount).map { _ in
            try NumiSealZKMaskedResidualStatement(
                bytes: readZKFrame(&reader, name: "NumiSealZK masked residual statement")
            )
        }
        let componentDigestRoot = try Digest256(reader.readData(count: Digest256.byteCount))
        let transcriptDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        try reader.finish()
        try Self.validate(
            zkMode: zkMode,
            baseProof: baseProof,
            maskStatements: maskStatements,
            maskedResidualStatements: maskedResidualStatements
        )
        try Self.validateSessionBinding(
            randomnessSessionDigest: randomnessSessionDigest,
            maskStatements: maskStatements
        )
        let expectedLeakageDigest = Self.computeLeakageDigest(
            zkMode: zkMode,
            baseProof: baseProof,
            maskStatements: maskStatements
        )
        guard leakageDigest == expectedLeakageDigest else {
            throw SuperNeoError.invalidEncoding("NumiSealZK leakage digest mismatch")
        }
        let expectedComponentDigestRoot = Self.computeComponentDigestRoot(
            baseProof: baseProof,
            maskStatements: maskStatements,
            maskedResidualStatements: maskedResidualStatements,
            leakageDigest: leakageDigest
        )
        guard componentDigestRoot == expectedComponentDigestRoot else {
            throw SuperNeoError.invalidEncoding("NumiSealZK component digest root mismatch")
        }
        let expectedTranscriptDigest = Self.computeTranscriptDigest(
            bodyVersion: bodyVersion,
            zkMode: zkMode,
            randomnessSessionDigest: randomnessSessionDigest,
            leakageDigest: leakageDigest,
            baseProof: baseProof,
            maskStatements: maskStatements,
            maskedResidualStatements: maskedResidualStatements,
            componentDigestRoot: componentDigestRoot
        )
        guard transcriptDigest == expectedTranscriptDigest else {
            throw SuperNeoError.invalidEncoding("NumiSealZK transcript digest mismatch")
        }
        self.bodyVersion = bodyVersion
        self.zkMode = zkMode
        self.randomnessSessionDigest = randomnessSessionDigest
        self.leakageDigest = leakageDigest
        self.baseProof = baseProof
        self.maskStatements = maskStatements
        self.maskedResidualStatements = maskedResidualStatements
        self.componentDigestRoot = componentDigestRoot
        self.transcriptDigest = transcriptDigest
    }

    public var superNeoBytes: [UInt8] {
        numiSealEncodeUInt16(bodyVersion)
            + numiSealZKEncodeString(zkMode)
            + randomnessSessionDigest.superNeoBytes
            + leakageDigest.superNeoBytes
            + numiSealZKFrame(baseProof.superNeoBytes)
            + numiSealEncodeCount(maskStatements.count)
            + maskStatements.flatMap { numiSealZKFrame($0.superNeoBytes) }
            + numiSealEncodeCount(maskedResidualStatements.count)
            + maskedResidualStatements.flatMap { numiSealZKFrame($0.superNeoBytes) }
            + componentDigestRoot.superNeoBytes
            + transcriptDigest.superNeoBytes
    }

    private static func validate(
        zkMode: String,
        baseProof: NumiSealProof,
        maskStatements: [NumiSealZKMaskStatement],
        maskedResidualStatements: [NumiSealZKMaskedResidualStatement]
    ) throws {
        guard zkMode == NumiSealZK.maskedDigitTensorMode else {
            throw SuperNeoError.invalidParameter("unsupported NumiSealZK proof mode")
        }
        guard maskStatements.count == baseProof.laneProofs.count else {
            throw SuperNeoError.invalidParameter("NumiSealZK mask statement count must match base lane proof count")
        }
        guard maskedResidualStatements.count == baseProof.laneProofs.count else {
            throw SuperNeoError.invalidParameter("NumiSealZK masked residual statement count must match base lane proof count")
        }
        for ((mask, maskedResidual), laneProof) in zip(zip(maskStatements, maskedResidualStatements), baseProof.laneProofs) {
            guard mask.zkMode == zkMode else {
                throw SuperNeoError.invalidParameter("NumiSealZK mask mode mismatch")
            }
            guard mask.laneKey == laneProof.laneKey else {
                throw SuperNeoError.invalidParameter("NumiSealZK mask lane mismatch")
            }
            guard mask.aggregateIndex == laneProof.aggregateIndex else {
                throw SuperNeoError.invalidParameter("NumiSealZK mask aggregate mismatch")
            }
            guard mask.digitTensorDigest == laneProof.residualOpening.digitTensorDigest else {
                throw SuperNeoError.invalidParameter("NumiSealZK mask digit tensor digest mismatch")
            }
            try maskedResidual.validate(laneProof: laneProof, maskStatement: mask)
        }
    }

    private static func validateSessionBinding(
        randomnessSessionDigest: Digest256,
        maskStatements: [NumiSealZKMaskStatement]
    ) throws {
        guard maskStatements.allSatisfy({ $0.randomnessSessionDigest == randomnessSessionDigest }) else {
            throw SuperNeoError.invalidParameter("NumiSealZK mask randomness session mismatch")
        }
    }

    private static func computeLeakageDigest(
        zkMode: String,
        baseProof: NumiSealProof,
        maskStatements: [NumiSealZKMaskStatement]
    ) -> Digest256 {
        NumiSealEncoding.digest(
            label: "numiseal.zk.declared-leakage.v1",
            bytes: numiSealZKEncodeString(zkMode)
                + baseProof.publicStatement.digest.superNeoBytes
                + baseProof.publicStatement.obligationRoot.superNeoBytes
                + baseProof.publicStatement.laneSummaryRoot.superNeoBytes
                + numiSealEncodeCount(maskStatements.count)
                + maskStatements.flatMap {
                    $0.laneKey.superNeoBytes
                        + numiSealEncodeCount($0.aggregateIndex)
                        + numiSealEncodeCount($0.columnCount)
                        + numiSealEncodeCount($0.activeDigitCount)
                        + $0.randomnessSessionDigest.superNeoBytes
                }
        )
    }

    private static func computeComponentDigestRoot(
        baseProof: NumiSealProof,
        maskStatements: [NumiSealZKMaskStatement],
        maskedResidualStatements: [NumiSealZKMaskedResidualStatement],
        leakageDigest: Digest256
    ) -> Digest256 {
        NumiSealEncoding.root(
            label: "numiseal.zk.component-root.v1",
            leaves: [baseProof.transcriptDigest, leakageDigest]
                + maskStatements.map(\.statementDigest)
                + maskedResidualStatements.map(\.statementDigest)
        )
    }

    private static func computeTranscriptDigest(
        bodyVersion: UInt16,
        zkMode: String,
        randomnessSessionDigest: Digest256,
        leakageDigest: Digest256,
        baseProof: NumiSealProof,
        maskStatements: [NumiSealZKMaskStatement],
        maskedResidualStatements: [NumiSealZKMaskedResidualStatement],
        componentDigestRoot: Digest256
    ) -> Digest256 {
        NumiSealEncoding.digest(
            label: "numiseal.zk.proof-transcript.v1",
            bytes: numiSealEncodeUInt16(bodyVersion)
                + numiSealZKEncodeString(zkMode)
                + randomnessSessionDigest.superNeoBytes
                + leakageDigest.superNeoBytes
                + baseProof.transcriptDigest.superNeoBytes
                + numiSealEncodeCount(maskStatements.count)
                + maskStatements.flatMap(\.statementDigest.superNeoBytes)
                + numiSealEncodeCount(maskedResidualStatements.count)
                + maskedResidualStatements.flatMap(\.statementDigest.superNeoBytes)
                + componentDigestRoot.superNeoBytes
        )
    }
}

public struct NumiSealZKProofEnvelope: Equatable, Sendable, SuperNeoByteEncodable {
    public let header: ProofEnvelopeHeader
    public let proof: NumiSealZKProof

    public init(context: ProofEnvelopeContext, proof: NumiSealZKProof) throws {
        guard context.kind == .numiSealZK else {
            throw SuperNeoError.invalidParameter("NumiSealZKProofEnvelope only supports numiSealZK kind")
        }
        let body = proof.superNeoBytes
        guard body.count <= Int(UInt32.max) else {
            throw SuperNeoError.invalidEncoding("NumiSealZK proof body too large")
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
        guard header.kind == .numiSealZK else {
            throw SuperNeoError.invalidEncoding("NumiSealZK proof envelope kind mismatch")
        }
        _ = try reader.readData(count: ProofEnvelopeHeader.byteCount)
        let body = try reader.readData(count: Int(header.bodyLength))
        try reader.finish()
        self.header = header
        self.proof = try NumiSealZKProof(bytes: body, parameters: parameters)
    }

    public var superNeoBytes: [UInt8] {
        header.superNeoBytes + proof.superNeoBytes
    }
}

public final class NumiSealZKProver: @unchecked Sendable {
    private let randomnessReuseGuard: NumiSealZKRandomnessReuseGuard

    public init(randomnessReuseGuard: NumiSealZKRandomnessReuseGuard = NumiSealZKRandomnessReuseGuard()) {
        self.randomnessReuseGuard = randomnessReuseGuard
    }

    public func prove(
        terminalContext: ProofEnvelopeContext,
        baseProof: NumiSealProof,
        digitTensors: [NumiSealDigitTensor],
        randomnessSessionMaterial: [UInt8],
        randomnessSessionLabel: String = "product",
        provingWorkspace: NumiSealMetalProvingWorkspace? = nil
    ) throws -> NumiSealZKProofEnvelope {
        guard terminalContext.kind == .numiSealTerminal else {
            throw SuperNeoError.invalidParameter("NumiSealZK prover requires a terminal NumiSeal base context")
        }
        guard digitTensors.count == baseProof.laneProofs.count else {
            throw SuperNeoError.invalidParameter("NumiSealZK digit tensor count must match base lane proof count")
        }
        for (digitTensor, laneProof) in zip(digitTensors, baseProof.laneProofs) {
            guard digitTensor.laneKey == laneProof.laneKey else {
                throw SuperNeoError.invalidParameter("NumiSealZK digit tensor lane mismatch")
            }
            guard digitTensor.aggregateIndex == laneProof.aggregateIndex else {
                throw SuperNeoError.invalidParameter("NumiSealZK digit tensor aggregate mismatch")
            }
            guard digitTensor.digest == laneProof.residualOpening.digitTensorDigest else {
                throw SuperNeoError.invalidParameter("NumiSealZK digit tensor digest mismatch")
            }
        }
        let session = try NumiSealZKRandomnessSession(
            sessionMaterial: randomnessSessionMaterial,
            label: randomnessSessionLabel
        )
        try randomnessReuseGuard.consume(session)
        let maskMaterials = try digitTensors.map {
            try NumiSealZKMaskMaterial.build(
                digitTensor: $0,
                sessionMaterial: randomnessSessionMaterial,
                session: session,
                provingWorkspace: provingWorkspace
            )
        }
        let maskedResidualStatements = try zip(zip(baseProof.laneProofs, digitTensors), maskMaterials).map {
            try NumiSealZKMaskedResidualStatement.build(
                laneProof: $0.0.0,
                digitTensor: $0.0.1,
                maskMaterial: $0.1,
                provingWorkspace: provingWorkspace
            )
        }
        let proof = try NumiSealZKProof(
            randomnessSessionDigest: session.sessionIDDigest,
            baseProof: baseProof,
            maskStatements: maskMaterials.map(\.statement),
            maskedResidualStatements: maskedResidualStatements
        )
        return try NumiSealZKProofEnvelope(
            context: Self.zkContext(from: terminalContext),
            proof: proof
        )
    }

    public func prove(
        terminalEnvelope: NumiSealProofEnvelope,
        digitTensors: [NumiSealDigitTensor],
        randomnessSessionMaterial: [UInt8],
        randomnessSessionLabel: String = "product",
        provingWorkspace: NumiSealMetalProvingWorkspace? = nil
    ) throws -> NumiSealZKProofEnvelope {
        let context = ProofEnvelopeContext(
            profileID: terminalEnvelope.header.profileID,
            kind: terminalEnvelope.header.kind,
            shapeDigest: terminalEnvelope.header.shapeDigest,
            statementDigest: terminalEnvelope.header.statementDigest,
            verifierKeyDigest: terminalEnvelope.header.verifierKeyDigest,
            transcriptDomain: terminalEnvelope.header.transcriptDomain
        )
        return try prove(
            terminalContext: context,
            baseProof: terminalEnvelope.proof,
            digitTensors: digitTensors,
            randomnessSessionMaterial: randomnessSessionMaterial,
            randomnessSessionLabel: randomnessSessionLabel,
            provingWorkspace: provingWorkspace
        )
    }

    private static func zkContext(from terminalContext: ProofEnvelopeContext) -> ProofEnvelopeContext {
        ProofEnvelopeContext(
            profileID: terminalContext.profileID,
            kind: .numiSealZK,
            shapeDigest: terminalContext.shapeDigest,
            statementDigest: terminalContext.statementDigest,
            verifierKeyDigest: terminalContext.verifierKeyDigest,
            transcriptDomain: terminalContext.transcriptDomain
        )
    }
}

public struct NumiSealZKVerificationResult: Equatable, Sendable {
    public let isValid: Bool
    public let reason: String?
    public let envelope: NumiSealZKProofEnvelope?
    public let baseResult: NumiSealVerificationResult?

    public static func valid(
        envelope: NumiSealZKProofEnvelope,
        baseResult: NumiSealVerificationResult
    ) -> Self {
        Self(isValid: true, reason: nil, envelope: envelope, baseResult: baseResult)
    }

    public static func invalid(_ reason: String) -> Self {
        Self(isValid: false, reason: reason, envelope: nil, baseResult: nil)
    }
}

public final class NumiSealZKVerifier: @unchecked Sendable {
    public let terminalVerifier: NumiSealVerifier

    public init(terminalVerifier: NumiSealVerifier) {
        self.terminalVerifier = terminalVerifier
    }

    public func verify(
        proofBytes: [UInt8],
        obligations: [NumiSealObligation],
        policy: NumiSealTerminalProofAcceptancePolicy,
        aggregationLimits: NumiSealAggregationLimits = .defaultLimits(),
        parameters: SuperNeoParameters = .goldilocks
    ) -> NumiSealZKVerificationResult {
        do {
            let envelope = try NumiSealZKProofEnvelope(bytes: proofBytes, parameters: parameters)
            let terminalContext = ProofEnvelopeContext(
                profileID: envelope.header.profileID,
                kind: .numiSealTerminal,
                shapeDigest: envelope.header.shapeDigest,
                statementDigest: envelope.header.statementDigest,
                verifierKeyDigest: envelope.header.verifierKeyDigest,
                transcriptDomain: envelope.header.transcriptDomain
            )
            let baseEnvelope = try NumiSealProofEnvelope(
                context: terminalContext,
                proof: envelope.proof.baseProof
            )
            let baseResult = terminalVerifier.verify(
                proofBytes: baseEnvelope.superNeoBytes,
                obligations: obligations,
                policy: policy,
                aggregationLimits: aggregationLimits
            )
            guard baseResult.isValid else {
                return .invalid("NumiSealZK base proof rejected: \(baseResult.reason ?? "unknown reason")")
            }
            return .valid(envelope: envelope, baseResult: baseResult)
        } catch {
            return .invalid("\(error)")
        }
    }
}

private func numiSealZKEncodeString(_ value: String) -> [UInt8] {
    let bytes = Array(value.utf8)
    return numiSealEncodeCount(bytes.count) + bytes
}

private func readZKString(_ reader: inout ByteReader, name: String) throws -> String {
    let count = try reader.readCount(maximum: 1024, name: "\(name) byte", elementByteWidth: 1)
    let bytes = try reader.readData(count: count)
    guard let value = String(bytes: bytes, encoding: .utf8) else {
        throw SuperNeoError.invalidEncoding("\(name) must be UTF-8")
    }
    return value
}

private func numiSealZKFrame(_ bytes: [UInt8]) -> [UInt8] {
    numiSealEncodeCount(bytes.count) + bytes
}

private func readZKFrame(
    _ reader: inout ByteReader,
    maximum: Int = NumiSealWireLimits.maximumProofComponentByteCount,
    name: String
) throws -> [UInt8] {
    let count = try reader.readCount(maximum: maximum, name: "\(name) byte", elementByteWidth: 1)
    guard count > 0 else {
        throw SuperNeoError.invalidEncoding("\(name) cannot be empty")
    }
    return try reader.readData(count: count)
}

private extension UInt64 {
    init(littleEndianBytes bytes: [UInt8]) {
        self = bytes.enumerated().reduce(UInt64(0)) { acc, pair in
            acc | (UInt64(pair.element) << UInt64(pair.offset * 8))
        }
    }
}
