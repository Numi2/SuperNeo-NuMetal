import Foundation
import Security

public struct CommitmentKeyPair<ProverKey: Sendable, VerifierKey: Sendable>: Sendable {
    public let proverKey: ProverKey
    public let verifierKey: VerifierKey

    public init(proverKey: ProverKey, verifierKey: VerifierKey) {
        self.proverKey = proverKey
        self.verifierKey = verifierKey
    }
}

extension CommitmentKeyPair: Equatable where ProverKey: Equatable, VerifierKey: Equatable {}

public protocol CommitmentScheme {
    associatedtype Parameters: Sendable
    associatedtype Shape: Sendable
    associatedtype ProverKey: Sendable
    associatedtype VerifierKey: Sendable
    associatedtype Message: Sendable
    associatedtype Commitment: Sendable

    static func setup(
        params: Parameters,
        shape: Shape,
        seed: [UInt8]
    ) throws -> CommitmentKeyPair<ProverKey, VerifierKey>

    static func setup(
        params: Parameters,
        shape: Shape
    ) throws -> CommitmentKeyPair<ProverKey, VerifierKey>

    static func commit(
        proverKey: ProverKey,
        message: Message
    ) throws -> Commitment

    static func verifyOpening(
        verifierKey: VerifierKey,
        message: Message,
        commitment: Commitment
    ) throws -> Bool

    static func batchCommit(
        proverKey: ProverKey,
        messages: [Message]
    ) throws -> [Commitment]

    static func digest(_ verifierKey: VerifierKey) -> Digest256
}

public enum AjtaiSuperNeoCommitment: CommitmentScheme {
    public static let minimumModuleSISBindingSecurityBits = ModuleSISBindingSecurityProfile.defaultMinimumSecurityBits

    public typealias Parameters = SuperNeoParameters
    public typealias Shape = CCSShape
    public typealias ProverKey = AjtaiCommitmentKey
    public typealias VerifierKey = AjtaiCommitmentKey
    public typealias Message = [GoldilocksField]
    public typealias Commitment = AjtaiCommitment

    public static func setup(
        params: SuperNeoParameters = .goldilocks,
        shape: CCSShape,
        seed: [UInt8]
    ) throws -> CommitmentKeyPair<AjtaiCommitmentKey, AjtaiCommitmentKey> {
        try validateParameters(params, match: shape)
        let key = try AjtaiCommitmentKey(parameters: params, columns: shape.nRing, seed: seed)
        return CommitmentKeyPair(proverKey: key, verifierKey: key)
    }

    public static func setup(
        params: SuperNeoParameters = .goldilocks,
        shape: CCSShape
    ) throws -> CommitmentKeyPair<AjtaiCommitmentKey, AjtaiCommitmentKey> {
        try setup(params: params, shape: shape, seed: systemRandomKeySeed(shape: shape, params: params))
    }

    public static func commit(
        proverKey: AjtaiCommitmentKey,
        message: [GoldilocksField]
    ) throws -> AjtaiCommitment {
        try commit(proverKey: proverKey, message: message, executionPolicy: .default)
    }

    public static func commit(
        proverKey: AjtaiCommitmentKey,
        shape: CCSShape,
        message: [GoldilocksField],
        context: MetalExecutionContext? = nil,
        schedule: AjtaiMatvecSchedule = .default,
        executionPolicy: SuperNeoExecutionPolicy = .default
    ) throws -> AjtaiCommitment {
        try validateKey(proverKey, matches: shape, role: "prover")
        guard message.count == shape.nField else {
            throw SuperNeoError.invalidParameter("Ajtai prover opening length must match shape.nField")
        }
        return try commit(
            proverKey: proverKey,
            message: message,
            context: context,
            schedule: schedule,
            executionPolicy: executionPolicy
        )
    }

    public static func commit(
        proverKey: AjtaiCommitmentKey,
        message: [GoldilocksField],
        context: MetalExecutionContext? = nil,
        schedule: AjtaiMatvecSchedule = .default,
        executionPolicy: SuperNeoExecutionPolicy = .default
    ) throws -> AjtaiCommitment {
        try validateBindingOpening(message, key: proverKey)
        if executionPolicy.usesConstantWorkCPU {
            return try AjtaiCommitter.commitConstantWorkReference(key: proverKey, fieldWitness: message)
        }
        let commitment = try AjtaiCommitter.commit(
            key: proverKey,
            fieldWitness: message,
            context: context,
            schedule: schedule
        )
        if context != nil, executionPolicy.requiresMetalCPUCheck {
            let expected = try AjtaiCommitter.commitReference(key: proverKey, fieldWitness: message)
            guard commitment == expected else {
                throw SuperNeoError.verificationFailed("Metal Ajtai commitment mismatch")
            }
        }
        return commitment
    }

    public static func verifyOpening(
        verifierKey: AjtaiCommitmentKey,
        message: [GoldilocksField],
        commitment: AjtaiCommitment
    ) throws -> Bool {
        try verifyOpening(
            verifierKey: verifierKey,
            message: message,
            commitment: commitment,
            executionPolicy: .default
        )
    }

    public static func verifyOpening(
        verifierKey: AjtaiCommitmentKey,
        shape: CCSShape,
        message: [GoldilocksField],
        commitment: AjtaiCommitment,
        context: MetalExecutionContext? = nil,
        schedule: AjtaiMatvecSchedule = .default,
        executionPolicy: SuperNeoExecutionPolicy = .default
    ) throws -> Bool {
        try validateKey(verifierKey, matches: shape, role: "verifier")
        guard message.count == shape.nField else { return false }
        return try verifyOpening(
            verifierKey: verifierKey,
            message: message,
            commitment: commitment,
            context: context,
            schedule: schedule,
            executionPolicy: executionPolicy
        )
    }

    public static func verifyOpening(
        verifierKey: AjtaiCommitmentKey,
        message: [GoldilocksField],
        commitment: AjtaiCommitment,
        context: MetalExecutionContext? = nil,
        schedule: AjtaiMatvecSchedule = .default,
        executionPolicy: SuperNeoExecutionPolicy = .default
    ) throws -> Bool {
        guard commitment.elements.count == verifierKey.matrix.rows else { return false }
        let expected: AjtaiCommitment
        do {
            expected = try self.commit(
                proverKey: verifierKey,
                message: message,
                context: context,
                schedule: schedule,
                executionPolicy: executionPolicy
            )
        } catch let error as SuperNeoError {
            if case .invalidParameter = error {
                return false
            }
            throw error
        }
        return expected == commitment
    }

    public static func batchCommit(
        proverKey: AjtaiCommitmentKey,
        messages: [[GoldilocksField]]
    ) throws -> [AjtaiCommitment] {
        try batchCommit(proverKey: proverKey, messages: messages, executionPolicy: .default)
    }

    public static func batchCommit(
        proverKey: AjtaiCommitmentKey,
        shape: CCSShape,
        messages: [[GoldilocksField]],
        context: MetalExecutionContext? = nil,
        schedule: AjtaiMatvecSchedule = .default,
        executionPolicy: SuperNeoExecutionPolicy = .default
    ) throws -> [AjtaiCommitment] {
        try validateKey(proverKey, matches: shape, role: "prover")
        guard messages.allSatisfy({ $0.count == shape.nField }) else {
            throw SuperNeoError.invalidParameter("Ajtai prover opening length must match shape.nField")
        }
        return try batchCommit(
            proverKey: proverKey,
            messages: messages,
            context: context,
            schedule: schedule,
            executionPolicy: executionPolicy
        )
    }

    public static func batchCommit(
        proverKey: AjtaiCommitmentKey,
        messages: [[GoldilocksField]],
        context: MetalExecutionContext? = nil,
        schedule: AjtaiMatvecSchedule = .default,
        executionPolicy: SuperNeoExecutionPolicy = .default
    ) throws -> [AjtaiCommitment] {
        for message in messages {
            try validateBindingOpening(message, key: proverKey)
        }
        if executionPolicy.usesConstantWorkCPU {
            return try messages.map {
                try AjtaiCommitter.commitConstantWorkReference(key: proverKey, fieldWitness: $0)
            }
        }
        let commitments: [AjtaiCommitment]
        if let context {
            commitments = try AjtaiMatvecScheduler.commitBatch(
                key: proverKey,
                fieldWitnesses: messages,
                context: context,
                schedule: schedule
            )
        } else {
            commitments = try messages.map {
                try AjtaiCommitter.commitReference(key: proverKey, fieldWitness: $0)
            }
        }
        if context != nil, executionPolicy.requiresMetalCPUCheck {
            let expected = try messages.map {
                try AjtaiCommitter.commitReference(key: proverKey, fieldWitness: $0)
            }
            guard commitments == expected else {
                throw SuperNeoError.verificationFailed("Metal Ajtai batch commitment mismatch")
            }
        }
        return commitments
    }

    public static func digest(_ verifierKey: AjtaiCommitmentKey) -> Digest256 {
        verifierKey.verifierKeyDigest
    }

    public static func validateKey(
        _ key: AjtaiCommitmentKey,
        matches shape: CCSShape,
        role: String
    ) throws {
        try validateParameters(key.parameters, match: shape)
        guard key.matrix.columns == shape.nRing else {
            throw SuperNeoError.invalidParameter("Ajtai \(role) key column count must match shape.nRing")
        }
    }

    private static func validateParameters(_ params: SuperNeoParameters, match shape: CCSShape) throws {
        guard params == .goldilocks else {
            throw SuperNeoError.invalidParameter("unsupported Ajtai commitment parameter profile")
        }
        _ = try ModuleSISBindingSecurityProfile(
            parameters: params,
            matrixColumns: shape.nRing,
            minimumSecurityBits: minimumModuleSISBindingSecurityBits
        )
        guard shape.ajtai == .goldilocks else {
            throw SuperNeoError.invalidParameter("CCS shape Ajtai descriptor must match Goldilocks profile")
        }
        guard shape.cyclotomic == .cyclotomicPhi81 else {
            throw SuperNeoError.invalidParameter("CCS shape cyclotomic descriptor must match Phi_81 with degree 54")
        }
    }

    private static func validateBindingOpening(_ message: [GoldilocksField], key: AjtaiCommitmentKey) throws {
        let profile = try key.moduleSISBindingSecurityProfile(
            minimumSecurityBits: minimumModuleSISBindingSecurityBits
        )
        try profile.validateLowNormFieldOpening(message)
    }

    private static func systemRandomKeySeed(shape: CCSShape, params: SuperNeoParameters) throws -> [UInt8] {
        var randomBytes = [UInt8](repeating: 0, count: 32)
        let status = randomBytes.withUnsafeMutableBytes { buffer in
            SecRandomCopyBytes(kSecRandomDefault, buffer.count, buffer.baseAddress!)
        }
        guard status == errSecSuccess else {
            throw SuperNeoError.invalidParameter("system random key seed generation failed")
        }
        return Array("SuperNeo-NuMetal.ajtai-system-keygen.v1".utf8)
            + ajtaiKeyEncodeUInt16(params.profileID)
            + shape.shapeDigest.bytes
            + randomBytes
    }
}

private enum AjtaiCommitmentKeyWire {
    static let magic: UInt32 = 0x31_54_4A_41
    static let version: UInt16 = 1
    static let maxColumns = 1 << 30
}

extension AjtaiCommitmentKey: SuperNeoByteEncodable {
    public init(bytes: [UInt8]) throws {
        var reader = ByteReader(bytes)
        let magic = try reader.readUInt32()
        guard magic == AjtaiCommitmentKeyWire.magic else {
            throw SuperNeoError.invalidEncoding("Ajtai key magic mismatch")
        }
        let version = try reader.readUInt16()
        guard version == AjtaiCommitmentKeyWire.version else {
            throw SuperNeoError.invalidEncoding("unsupported Ajtai key version")
        }
        let profileID = try reader.readUInt16()
        guard profileID == SuperNeoParameters.goldilocks.profileID else {
            throw SuperNeoError.invalidEncoding("unsupported Ajtai key profile")
        }
        let parameters = SuperNeoParameters.goldilocks
        guard try reader.readUInt32() == UInt32(parameters.kappa),
              try reader.readUInt32() == UInt32(parameters.ringDegree),
              try reader.readUInt32() == UInt32(parameters.normBound),
              try reader.readUInt32() == UInt32(parameters.decompositionLength) else {
            throw SuperNeoError.invalidEncoding("Ajtai key parameter descriptor mismatch")
        }
        let rows = try reader.readCount(maximum: parameters.kappa, name: "Ajtai key row")
        let columns = try reader.readCount(maximum: AjtaiCommitmentKeyWire.maxColumns, name: "Ajtai key column")
        guard rows == parameters.kappa else {
            throw SuperNeoError.invalidEncoding("Ajtai key row count must equal kappa")
        }
        let (elementCount, overflow) = rows.multipliedReportingOverflow(by: columns)
        guard !overflow else {
            throw SuperNeoError.invalidEncoding("Ajtai key dimensions overflow")
        }
        let elementByteCount = CyclotomicRing54.degree * 8
        guard elementCount <= reader.remainingByteCount / elementByteCount else {
            throw SuperNeoError.invalidEncoding("Ajtai key element count exceeds remaining byte capacity")
        }
        let elements = try (0..<elementCount).map { _ in
            try CyclotomicRing54(littleEndianBytes: reader.readData(count: elementByteCount))
        }
        try reader.finish()
        self = try AjtaiCommitmentKey(
            parameters: parameters,
            matrix: RingMatrix(rows: rows, columns: columns, elements: elements)
        )
    }

    public var superNeoBytes: [UInt8] {
        ajtaiKeyEncodeUInt32(AjtaiCommitmentKeyWire.magic)
            + ajtaiKeyEncodeUInt16(AjtaiCommitmentKeyWire.version)
            + ajtaiKeyEncodeUInt16(parameters.profileID)
            + ajtaiKeyEncodeUInt32(UInt32(parameters.kappa))
            + ajtaiKeyEncodeUInt32(UInt32(parameters.ringDegree))
            + ajtaiKeyEncodeUInt32(UInt32(parameters.normBound))
            + ajtaiKeyEncodeUInt32(UInt32(parameters.decompositionLength))
            + ajtaiKeyEncodeCount(matrix.rows)
            + ajtaiKeyEncodeCount(matrix.columns)
            + matrix.elements.flatMap(\.littleEndianBytes)
    }
}

private func ajtaiKeyEncodeUInt16(_ value: UInt16) -> [UInt8] {
    withUnsafeBytes(of: value.littleEndian, Array.init)
}

private func ajtaiKeyEncodeUInt32(_ value: UInt32) -> [UInt8] {
    withUnsafeBytes(of: value.littleEndian, Array.init)
}

private func ajtaiKeyEncodeCount(_ value: Int) -> [UInt8] {
    withUnsafeBytes(of: UInt64(value).littleEndian, Array.init)
}
