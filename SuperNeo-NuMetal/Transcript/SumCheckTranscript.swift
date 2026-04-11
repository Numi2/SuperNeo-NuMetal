import CryptoKit
import Foundation

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
        var bytes: [UInt8] = []
        bytes.reserveCapacity(8)
        while bytes.count < 8 {
            if offset == buffer.count {
                refill()
            }
            let take = min(8 - bytes.count, buffer.count - offset)
            bytes.append(contentsOf: buffer[offset..<offset + take])
            offset += take
        }
        return bytes.enumerated().reduce(UInt64(0)) { acc, pair in
            acc | (UInt64(pair.element) << UInt64(pair.offset * 8))
        }
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
        let coeffs = (0..<CyclotomicRing54.degree).map { _ -> GoldilocksField in
            let index = nextUniformIndex(upperBound: choices.count)
            let value = choices[index]
            if value >= 0 { return GoldilocksField(UInt64(value)) }
            return -GoldilocksField(UInt64(-value))
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
    private var rng: DeterministicRNG
    private var absorbed: [UInt8]

    public init(domainSeparator: String, seed: [UInt8] = []) {
        self.rng = DeterministicRNG(seed: [])
        self.absorbed = []
        absorb(Array(domainSeparator.utf8))
        absorb(seed)
    }

    public mutating func absorb(_ bytes: [UInt8]) {
        absorbed += Self.frameLength(bytes.count)
        absorbed += bytes
        rng = DeterministicRNG(seed: absorbed)
    }

    public mutating func challengeField() -> GoldilocksField {
        rng.nextField()
    }

    public mutating func challengeExt2() -> GoldilocksExt2 {
        rng.nextExt2()
    }

    public mutating func challengeRing() -> CyclotomicRing54 {
        rng.nextChallengeRing()
    }

    private static func frameLength(_ value: Int) -> [UInt8] {
        withUnsafeBytes(of: UInt64(value).littleEndian, Array.init)
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
        rounds.reserveCapacity(oracle.numVars)
        prefix.reserveCapacity(oracle.numVars)

        for _ in 0..<oracle.numVars {
            let coeffs = try oracle.roundPolynomial(prefix: prefix)
            guard !coeffs.isEmpty, coeffs.count <= oracle.maxDegreePerRound + 1 else {
                throw SuperNeoError.invalidParameter("oracle returned invalid round polynomial degree")
            }
            let round = SumcheckRound(coeffs: coeffs)
            rounds.append(round)
            transcript.absorb(round.superNeoBytes)
            prefix.append(transcript.challengeExt2())
        }

        let finalValue = try oracle.finalEvaluation(point: prefix)
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
