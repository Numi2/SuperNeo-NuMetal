import Foundation

public enum NumiSealTernaryDigit: UInt8, Equatable, Sendable {
    case zero = 0
    case one = 1
    case minusOne = 0xFF

    public init(fieldElement: GoldilocksField) throws {
        switch fieldElement {
        case .zero:
            self = .zero
        case .one:
            self = .one
        case -GoldilocksField.one:
            self = .minusOne
        default:
            throw SuperNeoError.invalidParameter("NumiSeal digit tensor contains a non-ternary coefficient")
        }
    }

    public var fieldElement: GoldilocksField {
        switch self {
        case .zero:
            return .zero
        case .one:
            return .one
        case .minusOne:
            return -GoldilocksField.one
        }
    }
}

public struct NumiSealDecompositionKeyDerivation: Equatable, Sendable, SuperNeoByteEncodable {
    public static let domain = Digest256.hash("SuperNeo-NuMetal.numiseal.decomposition-key.v1")
    public static let version: UInt16 = 10

    public let version: UInt16
    public let verifierKeyDigest: Digest256
    public let laneKey: NumiSealLaneKey
    public let aggregateIndex: Int
    public let requiredColumnCount: Int
    public let derivationDigest: Digest256

    public init(
        verifierKeyDigest: Digest256,
        laneKey: NumiSealLaneKey,
        aggregateIndex: Int,
        requiredColumnCount: Int
    ) throws {
        try Self.validate(aggregateIndex: aggregateIndex, requiredColumnCount: requiredColumnCount)
        self.version = Self.version
        self.verifierKeyDigest = verifierKeyDigest
        self.laneKey = laneKey
        self.aggregateIndex = aggregateIndex
        self.requiredColumnCount = requiredColumnCount
        self.derivationDigest = Self.computeDerivationDigest(
            verifierKeyDigest: verifierKeyDigest,
            laneKey: laneKey,
            aggregateIndex: aggregateIndex,
            requiredColumnCount: requiredColumnCount
        )
    }

    public init(bytes: [UInt8]) throws {
        var reader = ByteReader(bytes)
        let domain = try Digest256(reader.readData(count: Digest256.byteCount))
        guard domain == Self.domain else {
            throw SuperNeoError.invalidEncoding("NumiSeal decomposition key domain mismatch")
        }
        let version = try reader.readUInt16()
        guard version == Self.version else {
            throw SuperNeoError.invalidEncoding("unsupported NumiSeal decomposition key version")
        }
        let verifierKeyDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        let laneKey = try reader.readNumiSealLaneKey()
        let aggregateIndex = try reader.readCount(
            maximum: NumiSealWireLimits.maximumAggregateCount,
            name: "NumiSeal decomposition aggregate index"
        )
        let requiredColumnCount = try reader.readCount(
            maximum: NumiSealWireLimits.maximumDigitTensorColumnCount,
            name: "NumiSeal decomposition column"
        )
        let derivationDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        try reader.finish()

        try Self.validate(aggregateIndex: aggregateIndex, requiredColumnCount: requiredColumnCount)
        let expectedDigest = Self.computeDerivationDigest(
            verifierKeyDigest: verifierKeyDigest,
            laneKey: laneKey,
            aggregateIndex: aggregateIndex,
            requiredColumnCount: requiredColumnCount
        )
        guard derivationDigest == expectedDigest else {
            throw SuperNeoError.invalidEncoding("NumiSeal decomposition key digest mismatch")
        }

        self.version = version
        self.verifierKeyDigest = verifierKeyDigest
        self.laneKey = laneKey
        self.aggregateIndex = aggregateIndex
        self.requiredColumnCount = requiredColumnCount
        self.derivationDigest = derivationDigest
    }

    public func deriveKey(parameters: SuperNeoParameters = .goldilocks) throws -> AjtaiCommitmentKey {
        guard laneKey.profileID == parameters.profileID else {
            throw SuperNeoError.invalidParameter("NumiSeal decomposition key profile mismatch")
        }
        return try AjtaiCommitmentKey(
            parameters: parameters,
            columns: requiredColumnCount,
            seed: derivationDigest.superNeoBytes
        )
    }

    public var superNeoBytes: [UInt8] {
        Self.domain.superNeoBytes
            + Self.bodyBytes(
                verifierKeyDigest: verifierKeyDigest,
                laneKey: laneKey,
                aggregateIndex: aggregateIndex,
                requiredColumnCount: requiredColumnCount
            )
            + derivationDigest.superNeoBytes
    }

    private static func computeDerivationDigest(
        verifierKeyDigest: Digest256,
        laneKey: NumiSealLaneKey,
        aggregateIndex: Int,
        requiredColumnCount: Int
    ) -> Digest256 {
        NumiSealEncoding.digest(
            label: "numiseal.decomposition-key.v1",
            bytes: bodyBytes(
                verifierKeyDigest: verifierKeyDigest,
                laneKey: laneKey,
                aggregateIndex: aggregateIndex,
                requiredColumnCount: requiredColumnCount
            )
        )
    }

    private static func bodyBytes(
        verifierKeyDigest: Digest256,
        laneKey: NumiSealLaneKey,
        aggregateIndex: Int,
        requiredColumnCount: Int
    ) -> [UInt8] {
        numiSealEncodeUInt16(Self.version)
            + verifierKeyDigest.superNeoBytes
            + laneKey.superNeoBytes
            + numiSealEncodeCount(aggregateIndex)
            + numiSealEncodeCount(requiredColumnCount)
    }

    private static func validate(aggregateIndex: Int, requiredColumnCount: Int) throws {
        guard aggregateIndex >= 0 else {
            throw SuperNeoError.invalidParameter("NumiSeal decomposition aggregate index must be non-negative")
        }
        guard requiredColumnCount > 0 else {
            throw SuperNeoError.invalidParameter("NumiSeal decomposition column count must be positive")
        }
        guard requiredColumnCount <= NumiSealWireLimits.maximumDigitTensorColumnCount else {
            throw SuperNeoError.invalidParameter("NumiSeal decomposition column count is too large")
        }
    }
}

public struct NumiSealDigitTensor: Equatable, Sendable, SuperNeoByteEncodable {
    public static let domain = Digest256.hash("SuperNeo-NuMetal.numiseal.digit-tensor.v1")
    public static let version: UInt16 = 10

    public let version: UInt16
    public let laneKey: NumiSealLaneKey
    public let aggregateIndex: Int
    public let columnCount: Int
    public let activeDigitCount: Int
    public let digits: [NumiSealTernaryDigit]

    public init(
        laneKey: NumiSealLaneKey,
        aggregateIndex: Int,
        columnCount: Int,
        activeDigitCount: Int,
        digits: [NumiSealTernaryDigit]
    ) throws {
        try Self.validate(
            aggregateIndex: aggregateIndex,
            columnCount: columnCount,
            activeDigitCount: activeDigitCount,
            digits: digits
        )
        self.version = Self.version
        self.laneKey = laneKey
        self.aggregateIndex = aggregateIndex
        self.columnCount = columnCount
        self.activeDigitCount = activeDigitCount
        self.digits = digits
    }

    public init(
        laneKey: NumiSealLaneKey,
        aggregateIndex: Int,
        message: [CyclotomicRing54],
        activeDigitCount: Int? = nil
    ) throws {
        var digits: [NumiSealTernaryDigit] = []
        digits.reserveCapacity(message.count * CyclotomicRing54.degree)
        for ring in message {
            for coefficient in ring.coefficients {
                digits.append(try NumiSealTernaryDigit(fieldElement: coefficient))
            }
        }
        let inferredActiveCount = activeDigitCount ?? ((digits.lastIndex { $0 != .zero } ?? -1) + 1)
        try self.init(
            laneKey: laneKey,
            aggregateIndex: aggregateIndex,
            columnCount: message.count,
            activeDigitCount: inferredActiveCount,
            digits: digits
        )
    }

    public init(bytes: [UInt8]) throws {
        var reader = ByteReader(bytes)
        let domain = try Digest256(reader.readData(count: Digest256.byteCount))
        guard domain == Self.domain else {
            throw SuperNeoError.invalidEncoding("NumiSeal digit tensor domain mismatch")
        }
        let version = try reader.readUInt16()
        guard version == Self.version else {
            throw SuperNeoError.invalidEncoding("unsupported NumiSeal digit tensor version")
        }
        let laneKey = try reader.readNumiSealLaneKey()
        let aggregateIndex = try reader.readCount(
            maximum: NumiSealWireLimits.maximumAggregateCount,
            name: "NumiSeal digit tensor aggregate index"
        )
        let columnCount = try reader.readCount(
            maximum: NumiSealWireLimits.maximumDigitTensorColumnCount,
            name: "NumiSeal digit tensor column"
        )
        let activeDigitCount = try reader.readCount(
            maximum: Self.checkedSlotCount(columnCount: columnCount),
            name: "NumiSeal active digit"
        )
        let slotCount = try Self.checkedSlotCount(columnCount: columnCount)
        let rawDigits = try reader.readData(count: slotCount)
        try reader.finish()
        let digits = try rawDigits.map { rawValue -> NumiSealTernaryDigit in
            guard let digit = NumiSealTernaryDigit(rawValue: rawValue) else {
                throw SuperNeoError.invalidEncoding("NumiSeal digit tensor contains non-ternary digit")
            }
            return digit
        }

        try Self.validate(
            aggregateIndex: aggregateIndex,
            columnCount: columnCount,
            activeDigitCount: activeDigitCount,
            digits: digits
        )

        self.version = version
        self.laneKey = laneKey
        self.aggregateIndex = aggregateIndex
        self.columnCount = columnCount
        self.activeDigitCount = activeDigitCount
        self.digits = digits
    }

    public var message: [CyclotomicRing54] {
        var output: [CyclotomicRing54] = []
        output.reserveCapacity(columnCount)
        for offset in stride(from: 0, to: digits.count, by: CyclotomicRing54.degree) {
            let coefficients = digits[offset..<offset + CyclotomicRing54.degree].map(\.fieldElement)
            output.append(CyclotomicRing54(coefficients))
        }
        return output
    }

    public var digest: Digest256 {
        NumiSealEncoding.digest(label: "numiseal.digit-tensor.v1", bytes: superNeoBytes)
    }

    public var superNeoBytes: [UInt8] {
        Self.domain.superNeoBytes
            + numiSealEncodeUInt16(version)
            + laneKey.superNeoBytes
            + numiSealEncodeCount(aggregateIndex)
            + numiSealEncodeCount(columnCount)
            + numiSealEncodeCount(activeDigitCount)
            + digits.map(\.rawValue)
    }

    private static func validate(
        aggregateIndex: Int,
        columnCount: Int,
        activeDigitCount: Int,
        digits: [NumiSealTernaryDigit]
    ) throws {
        guard aggregateIndex >= 0 else {
            throw SuperNeoError.invalidParameter("NumiSeal digit tensor aggregate index must be non-negative")
        }
        guard columnCount > 0 else {
            throw SuperNeoError.invalidParameter("NumiSeal digit tensor column count must be positive")
        }
        guard columnCount <= NumiSealWireLimits.maximumDigitTensorColumnCount else {
            throw SuperNeoError.invalidParameter("NumiSeal digit tensor column count is too large")
        }
        let slotCount = try checkedSlotCount(columnCount: columnCount)
        guard activeDigitCount >= 0, activeDigitCount <= slotCount else {
            throw SuperNeoError.invalidParameter("NumiSeal active digit count exceeds tensor size")
        }
        guard digits.count == slotCount else {
            throw SuperNeoError.invalidParameter("NumiSeal digit tensor length mismatch")
        }
        if activeDigitCount < digits.count {
            for digit in digits[activeDigitCount...] where digit != .zero {
                throw SuperNeoError.invalidParameter("NumiSeal digit tensor padding must be zero")
            }
        }
    }

    private static func checkedSlotCount(columnCount: Int) throws -> Int {
        let product = columnCount.multipliedReportingOverflow(by: CyclotomicRing54.degree)
        guard !product.overflow else {
            throw SuperNeoError.invalidParameter("NumiSeal digit tensor dimensions overflow")
        }
        return product.partialValue
    }
}

public struct NumiSealDecompositionCommitment: Equatable, Sendable, SuperNeoByteEncodable {
    public static let domain = Digest256.hash("SuperNeo-NuMetal.numiseal.decomposition-commitment.v1")
    public static let version: UInt16 = 10

    public let version: UInt16
    public let keyDerivation: NumiSealDecompositionKeyDerivation
    public let digitTensorDigest: Digest256
    public let commitment: AjtaiCommitment
    public let commitmentDigest: Digest256

    public var decompositionKeyDigest: Digest256 { keyDerivation.derivationDigest }

    public init(
        keyDerivation: NumiSealDecompositionKeyDerivation,
        digitTensor: NumiSealDigitTensor,
        parameters: SuperNeoParameters = .goldilocks,
        executionPolicy: SuperNeoExecutionPolicy = .highAssurance
    ) throws {
        try Self.validate(keyDerivation: keyDerivation, digitTensor: digitTensor)
        let key = try keyDerivation.deriveKey(parameters: parameters)
        let commitment = try Self.commit(
            key: key,
            digitTensor: digitTensor,
            executionPolicy: executionPolicy
        )
        self.version = Self.version
        self.keyDerivation = keyDerivation
        self.digitTensorDigest = digitTensor.digest
        self.commitment = commitment
        self.commitmentDigest = Self.computeCommitmentDigest(
            keyDerivation: keyDerivation,
            digitTensorDigest: digitTensor.digest,
            commitment: commitment
        )
    }

    public init(
        keyDerivation: NumiSealDecompositionKeyDerivation,
        digitTensorDigest: Digest256,
        commitment: AjtaiCommitment
    ) throws {
        guard commitment.elements.count == SuperNeoParameters.goldilocks.kappa else {
            throw SuperNeoError.invalidParameter("NumiSeal decomposition commitment has wrong length")
        }
        self.version = Self.version
        self.keyDerivation = keyDerivation
        self.digitTensorDigest = digitTensorDigest
        self.commitment = commitment
        self.commitmentDigest = Self.computeCommitmentDigest(
            keyDerivation: keyDerivation,
            digitTensorDigest: digitTensorDigest,
            commitment: commitment
        )
    }

    public init(bytes: [UInt8], parameters: SuperNeoParameters = .goldilocks) throws {
        var reader = ByteReader(bytes)
        let domain = try Digest256(reader.readData(count: Digest256.byteCount))
        guard domain == Self.domain else {
            throw SuperNeoError.invalidEncoding("NumiSeal decomposition commitment domain mismatch")
        }
        let version = try reader.readUInt16()
        guard version == Self.version else {
            throw SuperNeoError.invalidEncoding("unsupported NumiSeal decomposition commitment version")
        }
        let keyDerivationByteCount = try reader.readCount(
            maximum: NumiSealWireLimits.maximumProofComponentByteCount,
            name: "NumiSeal decomposition key derivation byte",
            elementByteWidth: 1
        )
        guard keyDerivationByteCount > 0 else {
            throw SuperNeoError.invalidEncoding("NumiSeal decomposition key derivation cannot be empty")
        }
        let keyDerivation = try NumiSealDecompositionKeyDerivation(
            bytes: reader.readData(count: keyDerivationByteCount)
        )
        let digitTensorDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        let commitment = try reader.readNumiSealCommitment(parameters: parameters)
        let commitmentDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        try reader.finish()

        let expectedDigest = Self.computeCommitmentDigest(
            keyDerivation: keyDerivation,
            digitTensorDigest: digitTensorDigest,
            commitment: commitment
        )
        guard commitmentDigest == expectedDigest else {
            throw SuperNeoError.invalidEncoding("NumiSeal decomposition commitment digest mismatch")
        }

        self.version = version
        self.keyDerivation = keyDerivation
        self.digitTensorDigest = digitTensorDigest
        self.commitment = commitment
        self.commitmentDigest = commitmentDigest
    }

    public func verifiesOpening(
        digitTensor: NumiSealDigitTensor,
        parameters: SuperNeoParameters = .goldilocks,
        executionPolicy: SuperNeoExecutionPolicy = .highAssurance
    ) throws -> Bool {
        guard digitTensor.digest == digitTensorDigest else {
            return false
        }
        try Self.validate(keyDerivation: keyDerivation, digitTensor: digitTensor)
        let key = try keyDerivation.deriveKey(parameters: parameters)
        let expectedCommitment = try Self.commit(
            key: key,
            digitTensor: digitTensor,
            executionPolicy: executionPolicy
        )
        return expectedCommitment == commitment
    }

    public var superNeoBytes: [UInt8] {
        let keyDerivationBytes = keyDerivation.superNeoBytes
        var bytes = Self.domain.superNeoBytes
        bytes += numiSealEncodeUInt16(version)
        bytes += numiSealEncodeCount(keyDerivationBytes.count)
        bytes += keyDerivationBytes
        bytes += digitTensorDigest.superNeoBytes
        bytes += commitment.superNeoBytes
        bytes += commitmentDigest.superNeoBytes
        return bytes
    }

    private static func validate(
        keyDerivation: NumiSealDecompositionKeyDerivation,
        digitTensor: NumiSealDigitTensor
    ) throws {
        guard keyDerivation.laneKey == digitTensor.laneKey else {
            throw SuperNeoError.invalidParameter("NumiSeal decomposition lane key mismatch")
        }
        guard keyDerivation.aggregateIndex == digitTensor.aggregateIndex else {
            throw SuperNeoError.invalidParameter("NumiSeal decomposition aggregate index mismatch")
        }
        guard keyDerivation.requiredColumnCount == digitTensor.columnCount else {
            throw SuperNeoError.invalidParameter("NumiSeal decomposition column count mismatch")
        }
    }

    private static func commit(
        key: AjtaiCommitmentKey,
        digitTensor: NumiSealDigitTensor,
        executionPolicy: SuperNeoExecutionPolicy
    ) throws -> AjtaiCommitment {
        if executionPolicy.usesConstantWorkCPU {
            return try AjtaiCommitter.commitConstantWorkReference(key: key, message: digitTensor.message)
        }
        return try AjtaiCommitter.commitReference(key: key, message: digitTensor.message)
    }

    private static func computeCommitmentDigest(
        keyDerivation: NumiSealDecompositionKeyDerivation,
        digitTensorDigest: Digest256,
        commitment: AjtaiCommitment
    ) -> Digest256 {
        NumiSealEncoding.digest(
            label: "numiseal.decomposition-commitment.v1",
            bytes: keyDerivation.derivationDigest.superNeoBytes
                + digitTensorDigest.superNeoBytes
                + commitment.superNeoBytes
        )
    }
}
