import CryptoKit
import Foundation

public struct SuperNeoQROChallenge: Equatable, Sendable, SuperNeoByteEncodable {
    public static let minimumVerifierPublicCoinByteCount = 32
    public static let defaultDomainSeparator = "SuperNeo-NuMetal.qro.public-coin.v1"

    public let domainSeparator: String
    public let sessionID: String
    public let verifierPublicCoin: [UInt8]
    public let transcriptContext: [UInt8]

    public init(
        domainSeparator: String = Self.defaultDomainSeparator,
        sessionID: String,
        verifierPublicCoin: [UInt8],
        transcriptContext: [UInt8] = []
    ) throws {
        guard !domainSeparator.isEmpty else {
            throw SuperNeoError.invalidParameter("QRO challenge domain separator must not be empty")
        }
        guard !sessionID.isEmpty else {
            throw SuperNeoError.invalidParameter("QRO challenge session ID must not be empty")
        }
        guard verifierPublicCoin.count >= Self.minimumVerifierPublicCoinByteCount else {
            throw SuperNeoError.invalidParameter("QRO challenge verifier public coin must carry at least 256 bits")
        }
        self.domainSeparator = domainSeparator
        self.sessionID = sessionID
        self.verifierPublicCoin = verifierPublicCoin
        self.transcriptContext = transcriptContext
    }

    public var superNeoBytes: [UInt8] {
        SuperNeoSplitQRO.framedBytes(
            domain: "superneo/qro/public-coin-challenge/v1",
            frames: [
                Array(domainSeparator.utf8),
                Array(sessionID.utf8),
                verifierPublicCoin,
                transcriptContext
            ]
        )
    }

    public var challengeDigest: Digest384 {
        SuperNeoSplitQRO.hBind(
            domain: "superneo/qro/public-coin-challenge/digest/v1",
            frames: [superNeoBytes]
        )
    }

    public func bindingTranscriptContext(label: String, context: [UInt8]) throws -> SuperNeoQROChallenge {
        guard !label.isEmpty else {
            throw SuperNeoError.invalidParameter("QRO challenge binding label must not be empty")
        }
        return try SuperNeoQROChallenge(
            domainSeparator: "\(domainSeparator)/\(label)",
            sessionID: sessionID,
            verifierPublicCoin: verifierPublicCoin,
            transcriptContext: SuperNeoSplitQRO.framedBytes(
                domain: "superneo/qro/public-coin-challenge/context-binding/v1",
                frames: [
                    transcriptContext,
                    Array(label.utf8),
                    context
                ]
            )
        )
    }

    public func transcriptDomainDigest(label: String) throws -> Digest256 {
        guard !label.isEmpty else {
            throw SuperNeoError.invalidParameter("QRO transcript domain label must not be empty")
        }
        return SuperNeoSplitQRO.hChal(
            domain: "superneo/qro/public-coin-challenge/transcript-domain/v1",
            frames: [
                Array(label.utf8),
                challengeDigest.superNeoBytes,
                superNeoBytes
            ]
        )
    }

    public func transcriptSeed(label: String) -> [UInt8] {
        SuperNeoSplitQRO.framedBytes(
            domain: "superneo/qro/public-coin-challenge/transcript-seed/v1",
            frames: [
                Array(label.utf8),
                challengeDigest.superNeoBytes,
                superNeoBytes
            ]
        )
    }
}

public struct DeterministicRNG: Sendable {
    private let seed: [UInt8]
    private var counter: UInt64
    private var buffer: [UInt8]
    private var offset: Int

    public init(seed: [UInt8]) {
        self.seed = seed
        self.counter = 0
        self.buffer = []
        self.offset = 0
    }

    public mutating func nextUInt64() -> UInt64 {
        var value = UInt64(0)
        var shift = UInt64(0)
        var remaining = 8
        while remaining > 0 {
            if offset == buffer.count {
                refill()
            }
            let take = min(remaining, buffer.count - offset)
            for byteIndex in 0..<take {
                value |= UInt64(buffer[offset + byteIndex]) << shift
                shift += 8
            }
            offset += take
            remaining -= take
        }
        return value
    }

    public mutating func nextField() -> GoldilocksField {
        var value = nextUInt64()
        while value >= GoldilocksField.modulus {
            value = nextUInt64()
        }
        return GoldilocksField(value)
    }

    public mutating func nextExt2() -> GoldilocksExt2 {
        GoldilocksExt2(nextField(), nextField())
    }

    public mutating func nextChallengeRing(parameters: SuperNeoParameters = .goldilocks) -> CyclotomicRing54 {
        let choices = parameters.challengeCoefficients
        var coeffs = Array(repeating: GoldilocksField.zero, count: CyclotomicRing54.degree)
        for coefficientIndex in 0..<CyclotomicRing54.degree {
            let index = nextUniformIndex(upperBound: choices.count)
            let value = choices[index]
            coeffs[coefficientIndex] = value >= 0
                ? GoldilocksField(UInt64(value))
                : -GoldilocksField(UInt64(-value))
        }
        return CyclotomicRing54(coeffs)
    }

    private mutating func nextUniformIndex(upperBound: Int) -> Int {
        guard upperBound > 1 else { return 0 }
        let bound = UInt64(upperBound)
        let limit = UInt64.max - (UInt64.max % bound)
        while true {
            let value = nextUInt64()
            if value < limit {
                return Int(value % bound)
            }
        }
    }

    private mutating func refill() {
        let counterBytes = withUnsafeBytes(of: counter.littleEndian, Array.init)
        let digest = SHA256.hash(data: Data(seed + counterBytes))
        buffer = Array(digest)
        offset = 0
        counter &+= 1
    }
}

public struct SumCheckTranscript: Sendable {
    public let proofKind: ProofEnvelopeKind
    public let challengeTapeSeed: Digest256

    private let domainSeparator: String
    private var stateDigest: Digest256
    private var challengeCounter: UInt64

    public init(domainSeparator: String, seed: [UInt8] = [], proofKind: ProofEnvelopeKind? = nil) {
        let resolvedProofKind = proofKind ?? Self.inferProofKind(from: seed) ?? .foldReduction
        let seedDigest = SuperNeoSplitQRO.sumCheckTranscriptSeed(
            domainSeparator: domainSeparator,
            seed: seed,
            proofKind: resolvedProofKind
        )
        self.proofKind = resolvedProofKind
        self.challengeTapeSeed = seedDigest
        self.domainSeparator = domainSeparator
        self.stateDigest = SuperNeoSplitQRO.sumCheckTranscriptInitialState(
            proofKind: resolvedProofKind,
            seedDigest: seedDigest
        )
        self.challengeCounter = 0
        absorb(Array(domainSeparator.utf8))
        absorb(seed)
    }

    public mutating func absorb(_ bytes: [UInt8]) {
        stateDigest = SuperNeoSplitQRO.sumCheckTranscriptAbsorbState(
            proofKind: proofKind,
            stateDigest: stateDigest,
            bytes: bytes
        )
    }

    public mutating func challengeField() -> GoldilocksField {
        let seed = makeChallengeSeed(label: "field")
        return SuperNeoSplitQRO.expandChallengeField(
            seed: seed,
            proofKind: proofKind,
            label: "\(domainSeparator)/field"
        )
    }

    public mutating func challengeExt2() -> GoldilocksExt2 {
        var tape = makeChallengeTape(label: "ext2")
        return tape.nextExt2()
    }

    public mutating func challengeRing(parameters: SuperNeoParameters = .goldilocks) -> CyclotomicRing54 {
        var tape = makeChallengeTape(label: "ring")
        return tape.nextRing(parameters: parameters)
    }

    private mutating func makeChallengeTape(label: String) -> SuperNeoChallengeTape {
        let seed = makeChallengeSeed(label: label)
        return SuperNeoChallengeTape(
            seed: seed,
            proofKind: proofKind,
            label: "\(domainSeparator)/\(label)"
        )
    }

    private mutating func makeChallengeSeed(label: String) -> Digest256 {
        let seed = SuperNeoSplitQRO.sumCheckTranscriptChallenge(
            label: label,
            proofKind: proofKind,
            challengeTapeSeed: challengeTapeSeed,
            stateDigest: stateDigest,
            challengeCounter: challengeCounter
        )
        challengeCounter &+= 1
        return seed
    }

    private static func inferProofKind(from seed: [UInt8]) -> ProofEnvelopeKind? {
        guard seed.count > 8,
              readUInt32LE(seed, offset: 0) == ProofEnvelopeHeader.magic,
              readUInt16LE(seed, offset: 4) == ProofEnvelopeHeader.version else {
            return nil
        }
        return ProofEnvelopeKind(rawValue: seed[8])
    }

    private static func readUInt16LE(_ bytes: [UInt8], offset: Int) -> UInt16? {
        guard bytes.count >= offset + 2 else {
            return nil
        }
        return UInt16(bytes[offset]) | (UInt16(bytes[offset + 1]) << 8)
    }

    private static func readUInt32LE(_ bytes: [UInt8], offset: Int) -> UInt32? {
        guard bytes.count >= offset + 4 else {
            return nil
        }
        return UInt32(bytes[offset])
            | (UInt32(bytes[offset + 1]) << 8)
            | (UInt32(bytes[offset + 2]) << 16)
            | (UInt32(bytes[offset + 3]) << 24)
    }
}

public struct VerificationResult: Equatable, Sendable {
    public let isValid: Bool
    public let reason: String?

    public static let valid = VerificationResult(isValid: true, reason: nil)
    public static func invalid(_ reason: String) -> VerificationResult {
        VerificationResult(isValid: false, reason: reason)
    }
}

public struct SumcheckRound: Equatable, Sendable, SuperNeoByteEncodable {
    public let coeffs: [GoldilocksExt2]

    public init(coeffs: [GoldilocksExt2]) {
        self.coeffs = coeffs
    }

    public var superNeoBytes: [UInt8] {
        sumcheckEncodeCount(coeffs.count) + coeffs.flatMap(\.superNeoBytes)
    }
}

public struct SumcheckProof: Equatable, Sendable, SuperNeoByteEncodable {
    public let claimedSum: GoldilocksExt2
    public let rounds: [SumcheckRound]
    public let finalPoint: [GoldilocksExt2]
    public let finalValue: GoldilocksExt2

    public init(
        claimedSum: GoldilocksExt2,
        rounds: [SumcheckRound],
        finalPoint: [GoldilocksExt2],
        finalValue: GoldilocksExt2
    ) {
        self.claimedSum = claimedSum
        self.rounds = rounds
        self.finalPoint = finalPoint
        self.finalValue = finalValue
    }

    public var superNeoBytes: [UInt8] {
        claimedSum.superNeoBytes
            + sumcheckEncodeCount(rounds.count)
            + rounds.flatMap(\.superNeoBytes)
            + sumcheckEncodeCount(finalPoint.count)
            + finalPoint.flatMap(\.superNeoBytes)
            + finalValue.superNeoBytes
    }
}

public enum SumcheckVerifier {
    public static func evaluatePolynomial(_ coeffs: [GoldilocksExt2], at point: GoldilocksExt2) -> GoldilocksExt2 {
        var result = GoldilocksExt2.zero
        for coefficient in coeffs.reversed() {
            result = result * point + coefficient
        }
        return result
    }

    public static func verify(
        proof: SumcheckProof,
        transcript: inout SumCheckTranscript,
        expectedDegree: Int,
        expectedRoundCount: Int? = nil,
        finalCheck: ([GoldilocksExt2], GoldilocksExt2) throws -> Bool
    ) throws -> Bool {
        guard expectedDegree >= 0 else {
            throw SuperNeoError.invalidParameter("sum-check expected degree must be nonnegative")
        }
        if let expectedRoundCount {
            guard proof.rounds.count == expectedRoundCount else { return false }
        }
        guard proof.finalPoint.count == proof.rounds.count else { return false }

        transcript.absorb(proof.claimedSum.superNeoBytes)
        var claim = proof.claimedSum
        var prefix: [GoldilocksExt2] = []
        prefix.reserveCapacity(proof.rounds.count)

        for round in proof.rounds {
            guard !round.coeffs.isEmpty, round.coeffs.count <= expectedDegree + 1 else {
                return false
            }
            let g0 = evaluatePolynomial(round.coeffs, at: .zero)
            let g1 = evaluatePolynomial(round.coeffs, at: .one)
            guard g0 + g1 == claim else { return false }

            transcript.absorb(round.superNeoBytes)
            let challenge = transcript.challengeExt2()
            prefix.append(challenge)
            claim = evaluatePolynomial(round.coeffs, at: challenge)
        }

        guard prefix == proof.finalPoint else { return false }
        guard claim == proof.finalValue else { return false }
        return try finalCheck(proof.finalPoint, proof.finalValue)
    }
}

public protocol SumcheckOracle {
    var numVars: Int { get }
    var maxDegreePerRound: Int { get }

    mutating func roundPolynomial(prefix: [GoldilocksExt2]) throws -> [GoldilocksExt2]
    mutating func finalEvaluation(point: [GoldilocksExt2]) throws -> GoldilocksExt2
}

public struct EvaluatingSumcheckOracle: SumcheckOracle {
    public let numVars: Int
    public let maxDegreePerRound: Int
    private let evaluator: ([GoldilocksExt2]) throws -> GoldilocksExt2

    public init(
        numVars: Int,
        maxDegreePerRound: Int,
        evaluator: @escaping ([GoldilocksExt2]) throws -> GoldilocksExt2
    ) throws {
        guard numVars >= 0 else {
            throw SuperNeoError.invalidParameter("sum-check variable count must be nonnegative")
        }
        guard maxDegreePerRound >= 0 else {
            throw SuperNeoError.invalidParameter("sum-check degree must be nonnegative")
        }
        self.numVars = numVars
        self.maxDegreePerRound = maxDegreePerRound
        self.evaluator = evaluator
    }

    public mutating func roundPolynomial(prefix: [GoldilocksExt2]) throws -> [GoldilocksExt2] {
        guard prefix.count < numVars else {
            throw SuperNeoError.invalidParameter("sum-check prefix is already complete")
        }
        let samplePoints = (0...maxDegreePerRound).map { GoldilocksExt2(GoldilocksField(UInt64($0))) }
        let values = try samplePoints.map { sample in
            try partialHypercubeSum(prefix: prefix + [sample])
        }
        return try interpolatePolynomial(samplePoints: samplePoints, values: values)
    }

    public mutating func finalEvaluation(point: [GoldilocksExt2]) throws -> GoldilocksExt2 {
        guard point.count == numVars else {
            throw SuperNeoError.invalidParameter("sum-check final point length mismatch")
        }
        return try evaluator(point)
    }

    private func partialHypercubeSum(prefix: [GoldilocksExt2]) throws -> GoldilocksExt2 {
        let remaining = numVars - prefix.count
        guard remaining >= 0 else {
            throw SuperNeoError.invalidParameter("sum-check prefix is longer than variable count")
        }
        guard remaining < Int.bitWidth - 1 else {
            throw SuperNeoError.invalidParameter("sum-check Boolean suffix is too large for reference oracle")
        }
        var total = GoldilocksExt2.zero
        let suffixCount = 1 << remaining
        for suffixBits in 0..<suffixCount {
            var point = prefix
            point.reserveCapacity(numVars)
            for bit in 0..<remaining {
                point.append(((suffixBits >> bit) & 1) == 0 ? .zero : .one)
            }
            total = total + (try evaluator(point))
        }
        return total
    }
}

public enum SumcheckProver {
    public static func prove<Oracle: SumcheckOracle>(
        oracle: inout Oracle,
        claimedSum: GoldilocksExt2,
        transcript: inout SumCheckTranscript
    ) throws -> SumcheckProof {
        transcript.absorb(claimedSum.superNeoBytes)
        var rounds: [SumcheckRound] = []
        var prefix: [GoldilocksExt2] = []
        var runningClaim = claimedSum
        rounds.reserveCapacity(oracle.numVars)
        prefix.reserveCapacity(oracle.numVars)

        for _ in 0..<oracle.numVars {
            let coeffs = try oracle.roundPolynomial(prefix: prefix)
            guard !coeffs.isEmpty, coeffs.count <= oracle.maxDegreePerRound + 1 else {
                throw SuperNeoError.invalidParameter("oracle returned invalid round polynomial degree")
            }
            let g0 = SumcheckVerifier.evaluatePolynomial(coeffs, at: .zero)
            let g1 = SumcheckVerifier.evaluatePolynomial(coeffs, at: .one)
            guard g0 + g1 == runningClaim else {
                throw SuperNeoError.invalidParameter("sum-check oracle round polynomial does not match running claim")
            }
            let round = SumcheckRound(coeffs: coeffs)
            rounds.append(round)
            transcript.absorb(round.superNeoBytes)
            let challenge = transcript.challengeExt2()
            prefix.append(challenge)
            runningClaim = SumcheckVerifier.evaluatePolynomial(coeffs, at: challenge)
        }

        let finalValue = try oracle.finalEvaluation(point: prefix)
        guard finalValue == runningClaim else {
            throw SuperNeoError.invalidParameter("sum-check oracle final evaluation does not match running claim")
        }
        return SumcheckProof(
            claimedSum: claimedSum,
            rounds: rounds,
            finalPoint: prefix,
            finalValue: finalValue
        )
    }
}

public struct ProverQOracle: SumcheckOracle {
    public let numVars: Int
    public let maxDegreePerRound: Int
    public let alpha: [GoldilocksExt2]
    public let gammaPowerForNorm: GoldilocksExt2
    public let gammaPowerForPriorEvaluations: GoldilocksExt2

    private var evaluatorOracle: EvaluatingSumcheckOracle

    public init(
        numVars: Int,
        maxDegreePerRound: Int,
        alpha: [GoldilocksExt2],
        gamma: GoldilocksExt2,
        normPowerExponent: Int,
        priorEvaluationPowerExponent: Int,
        fEvaluator: @escaping ([GoldilocksExt2]) throws -> GoldilocksExt2,
        normEvaluator: @escaping ([GoldilocksExt2]) throws -> GoldilocksExt2,
        priorEvaluationEvaluator: @escaping ([GoldilocksExt2]) throws -> GoldilocksExt2
    ) throws {
        guard alpha.count == numVars else {
            throw SuperNeoError.invalidParameter("Q oracle alpha length must match variable count")
        }
        guard normPowerExponent >= 0, priorEvaluationPowerExponent >= 0 else {
            throw SuperNeoError.invalidParameter("Q oracle gamma exponents must be nonnegative")
        }
        let gammaPowerForNorm = pow(gamma, normPowerExponent)
        let gammaPowerForPriorEvaluations = pow(gamma, priorEvaluationPowerExponent)
        self.numVars = numVars
        self.maxDegreePerRound = maxDegreePerRound
        self.alpha = alpha
        self.gammaPowerForNorm = gammaPowerForNorm
        self.gammaPowerForPriorEvaluations = gammaPowerForPriorEvaluations
        self.evaluatorOracle = try EvaluatingSumcheckOracle(
            numVars: numVars,
            maxDegreePerRound: maxDegreePerRound
        ) { point in
            let eq = try MultilinearEvaluation.eq(point, alpha)
            let f = try fEvaluator(point)
            let norm = try normEvaluator(point)
            let prior = try priorEvaluationEvaluator(point)
            return eq * (f + gammaPowerForNorm * norm) + gammaPowerForPriorEvaluations * prior
        }
    }

    public mutating func roundPolynomial(prefix: [GoldilocksExt2]) throws -> [GoldilocksExt2] {
        try evaluatorOracle.roundPolynomial(prefix: prefix)
    }

    public mutating func finalEvaluation(point: [GoldilocksExt2]) throws -> GoldilocksExt2 {
        try evaluatorOracle.finalEvaluation(point: point)
    }
}

private func sumcheckEncodeCount(_ value: Int) -> [UInt8] {
    withUnsafeBytes(of: UInt64(value).littleEndian, Array.init)
}

private func interpolatePolynomial(
    samplePoints: [GoldilocksExt2],
    values: [GoldilocksExt2]
) throws -> [GoldilocksExt2] {
    guard samplePoints.count == values.count, !samplePoints.isEmpty else {
        throw SuperNeoError.invalidParameter("interpolation sample count mismatch")
    }
    var coefficients = Array(repeating: GoldilocksExt2.zero, count: values.count)
    for index in samplePoints.indices {
        var basis = [GoldilocksExt2.one]
        var denominator = GoldilocksExt2.one
        for other in samplePoints.indices where other != index {
            basis = multiplyPolynomial(basis, byLinearTermWithRoot: samplePoints[other])
            denominator = denominator * (samplePoints[index] - samplePoints[other])
        }
        let scale = values[index] * (try denominator.inverse())
        for coeffIndex in basis.indices {
            coefficients[coeffIndex] = coefficients[coeffIndex] + basis[coeffIndex] * scale
        }
    }
    while coefficients.count > 1, coefficients.last == .zero {
        coefficients.removeLast()
    }
    return coefficients
}

private func multiplyPolynomial(
    _ coeffs: [GoldilocksExt2],
    byLinearTermWithRoot root: GoldilocksExt2
) -> [GoldilocksExt2] {
    var output = Array(repeating: GoldilocksExt2.zero, count: coeffs.count + 1)
    for index in coeffs.indices {
        output[index] = output[index] - coeffs[index] * root
        output[index + 1] = output[index + 1] + coeffs[index]
    }
    return output
}

private func pow(_ value: GoldilocksExt2, _ exponent: Int) -> GoldilocksExt2 {
    var result = GoldilocksExt2.one
    var base = value
    var exp = exponent
    while exp > 0 {
        if exp & 1 == 1 { result = result * base }
        exp >>= 1
        if exp > 0 { base = base * base }
    }
    return result
}
