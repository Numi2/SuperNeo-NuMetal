import Foundation

public struct SuperNeoSHA256OneBlockHashWorkload: Sendable {
    public static let maximumMessageByteCount = 55

    public let messageByteCount: Int
    public let builder: SuperNeoR1CSBuilder

    public init(messageByteCount: Int) throws {
        guard messageByteCount >= 0, messageByteCount <= Self.maximumMessageByteCount else {
            throw SuperNeoError.invalidParameter("SHA-256 one-block hash circuit supports messages up to 55 bytes")
        }
        var assembler = SuperNeoSHA256CircuitAssembler(messageByteCount: messageByteCount, message: nil)
        self.messageByteCount = messageByteCount
        self.builder = try assembler.assemble()
    }

    public var publicInputCount: Int {
        builder.publicInputCount
    }

    public var privateWitnessCount: Int {
        builder.privateWitnessCount
    }

    public var constraintCount: Int {
        builder.constraints.count
    }

    public var arithmetizationDigest: Digest256 {
        Digest256.hash(
            Array("SuperNeo-NuMetal.sha256-one-block-r1cs.v1".utf8)
                + concreteHashEncodeCount(messageByteCount)
                + concreteHashEncodeCount(publicInputCount)
                + concreteHashEncodeCount(privateWitnessCount)
                + concreteHashEncodeCount(constraintCount)
        )
    }

    public func digest(message: [UInt8]) throws -> Digest256 {
        try validateMessageLength(message)
        return Digest256.hash(message)
    }

    public func publicInput(message: [UInt8]) throws -> [GoldilocksField] {
        try publicInput(digest: digest(message: message))
    }

    public func publicInput(digest: Digest256) throws -> [GoldilocksField] {
        [.one] + Self.digestBits(digest).map { $0 ? .one : .zero }
    }

    public func privateWitness(message: [UInt8]) throws -> [GoldilocksField] {
        try validateMessageLength(message)
        var assembler = SuperNeoSHA256CircuitAssembler(messageByteCount: messageByteCount, message: message)
        _ = try assembler.assemble()
        return assembler.privateWitness
    }

    public func validate(message: [UInt8], digest: Digest256? = nil) throws -> Bool {
        let expectedDigest = digest ?? Digest256.hash(message)
        return try builder.validateWitness(
            publicInput: publicInput(digest: expectedDigest),
            privateWitness: privateWitness(message: message)
        )
    }

    public func prepareForFolding(
        message: [UInt8],
        digest: Digest256? = nil,
        keySeed: [UInt8],
        parameters: SuperNeoParameters = .goldilocks,
        executionPolicy: SuperNeoExecutionPolicy = .default
    ) throws -> SuperNeoPreparedR1CS {
        let expectedDigest = digest ?? Digest256.hash(message)
        return try builder.prepareForFolding(
            publicInput: publicInput(digest: expectedDigest),
            privateWitness: privateWitness(message: message),
            keySeed: keySeed,
            parameters: parameters,
            executionPolicy: executionPolicy
        )
    }

    public static func digestBits(_ digest: Digest256) -> [Bool] {
        digest.bytes.flatMap { byte in
            (0..<8).map { bit in
                ((byte >> UInt8(7 - bit)) & 1) == 1
            }
        }
    }

    private func validateMessageLength(_ message: [UInt8]) throws {
        guard message.count == messageByteCount else {
            throw SuperNeoError.invalidParameter("SHA-256 hash circuit message length mismatch")
        }
    }
}

public struct SuperNeoSHA256OneBlockPublicMessageHashWorkload: Sendable {
    public static let maximumMessageByteCount = SuperNeoSHA256OneBlockHashWorkload.maximumMessageByteCount

    public let messageByteCount: Int
    public let builder: SuperNeoR1CSBuilder

    public init(messageByteCount: Int) throws {
        guard messageByteCount >= 0, messageByteCount <= Self.maximumMessageByteCount else {
            throw SuperNeoError.invalidParameter("SHA-256 one-block hash circuit supports messages up to 55 bytes")
        }
        var assembler = SuperNeoSHA256CircuitAssembler(
            messageByteCount: messageByteCount,
            message: nil,
            messageVisibility: .publicInput
        )
        self.messageByteCount = messageByteCount
        self.builder = try assembler.assemble()
    }

    public var publicInputCount: Int {
        builder.publicInputCount
    }

    public var privateWitnessCount: Int {
        builder.privateWitnessCount
    }

    public var constraintCount: Int {
        builder.constraints.count
    }

    public var arithmetizationDigest: Digest256 {
        Digest256.hash(
            Array("SuperNeo-NuMetal.sha256-one-block-public-message-r1cs.v1".utf8)
                + concreteHashEncodeCount(messageByteCount)
                + concreteHashEncodeCount(publicInputCount)
                + concreteHashEncodeCount(privateWitnessCount)
                + concreteHashEncodeCount(constraintCount)
        )
    }

    public func digest(message: [UInt8]) throws -> Digest256 {
        try validateMessageLength(message)
        return Digest256.hash(message)
    }

    public func publicInput(message: [UInt8], digest: Digest256? = nil) throws -> [GoldilocksField] {
        try validateMessageLength(message)
        let expectedDigest = digest ?? Digest256.hash(message)
        return [.one]
            + SuperNeoSHA256OneBlockHashWorkload.digestBits(expectedDigest).map { $0 ? .one : .zero }
            + message.flatMap { byte in
                (0..<8).map { bit in
                    ((byte >> UInt8(7 - bit)) & 1) == 1 ? GoldilocksField.one : .zero
                }
            }
    }

    public func privateWitness(message: [UInt8]) throws -> [GoldilocksField] {
        try validateMessageLength(message)
        var assembler = SuperNeoSHA256CircuitAssembler(
            messageByteCount: messageByteCount,
            message: message,
            messageVisibility: .publicInput
        )
        _ = try assembler.assemble()
        return assembler.privateWitness
    }

    public func validate(message: [UInt8], digest: Digest256? = nil) throws -> Bool {
        try builder.validateWitness(
            publicInput: publicInput(message: message, digest: digest),
            privateWitness: privateWitness(message: message)
        )
    }

    public func prepareForFolding(
        message: [UInt8],
        digest: Digest256? = nil,
        keySeed: [UInt8],
        parameters: SuperNeoParameters = .goldilocks,
        executionPolicy: SuperNeoExecutionPolicy = .default
    ) throws -> SuperNeoPreparedR1CS {
        try builder.prepareForFolding(
            publicInput: publicInput(message: message, digest: digest),
            privateWitness: privateWitness(message: message),
            keySeed: keySeed,
            parameters: parameters,
            executionPolicy: executionPolicy
        )
    }

    private func validateMessageLength(_ message: [UInt8]) throws {
        guard message.count == messageByteCount else {
            throw SuperNeoError.invalidParameter("SHA-256 hash circuit message length mismatch")
        }
    }
}

private enum SuperNeoSHA256CircuitMessageVisibility {
    case privateWitness
    case publicInput
}

private struct SuperNeoSHA256CircuitBit {
    let linear: SuperNeoR1CSLinearCombination
    let value: Bool?
    let constantValue: Bool?
}

private struct SuperNeoSHA256CircuitWord {
    let bits: [SuperNeoSHA256CircuitBit]

    init(_ bits: [SuperNeoSHA256CircuitBit]) {
        precondition(bits.count == 32, "SHA-256 circuit words must be 32 bits")
        self.bits = bits
    }
}

private struct SuperNeoSHA256CircuitAssembler {
    let messageByteCount: Int
    let message: [UInt8]?
    var messageVisibility: SuperNeoSHA256CircuitMessageVisibility = .privateWitness
    var builder = SuperNeoR1CSBuilder()
    var privateWitness: [GoldilocksField] = []
    var digestPublicBits: [SuperNeoSHA256CircuitBit] = []

    mutating func assemble() throws -> SuperNeoR1CSBuilder {
        digestPublicBits = (0..<(Digest256.byteCount * 8)).map { _ in publicBit() }
        for bit in digestPublicBits {
            enforceBoolean(bit)
        }

        let blockWords = try paddedMessageWords()
        let digestWords = compress(blockWords)
        let digestBits = digestWords.flatMap { word in word.bits.reversed() }
        for (actual, expected) in zip(digestBits, digestPublicBits) {
            enforceEqual(actual, expected)
        }
        return builder
    }

    private mutating func paddedMessageWords() throws -> [SuperNeoSHA256CircuitWord] {
        let messageBits = try messageBits()
        let padded = messageBits + paddingBits()
        guard padded.count == 512 else {
            throw SuperNeoError.invalidParameter("SHA-256 one-block padding produced an invalid block length")
        }
        return stride(from: 0, to: 512, by: 32).map { wordStart in
            let bits = (0..<32).map { bit in
                padded[wordStart + 31 - bit]
            }
            return SuperNeoSHA256CircuitWord(bits)
        }
    }

    private mutating func messageBits() throws -> [SuperNeoSHA256CircuitBit] {
        if let message {
            guard message.count == messageByteCount else {
                throw SuperNeoError.invalidParameter("SHA-256 hash circuit message length mismatch")
            }
        }
        var bits: [SuperNeoSHA256CircuitBit] = []
        bits.reserveCapacity(messageByteCount * 8)
        for byteIndex in 0..<messageByteCount {
            let byte = message?[byteIndex]
            for bit in 0..<8 {
                let value = byte.map { (($0 >> UInt8(7 - bit)) & 1) == 1 }
                switch messageVisibility {
                case .privateWitness:
                    bits.append(privateBit(value))
                case .publicInput:
                    bits.append(publicBit(value))
                }
            }
        }
        return bits
    }

    private func paddingBits() -> [SuperNeoSHA256CircuitBit] {
        let messageBitCount = messageByteCount * 8
        let zeroCount = 448 - messageBitCount - 1
        let length = UInt64(messageBitCount)
        var bits: [SuperNeoSHA256CircuitBit] = [constantBit(true)]
        bits.append(contentsOf: Array(repeating: constantBit(false), count: zeroCount))
        for bit in stride(from: 63, through: 0, by: -1) {
            bits.append(constantBit(((length >> UInt64(bit)) & 1) == 1))
        }
        return bits
    }

    private mutating func compress(_ initialWords: [SuperNeoSHA256CircuitWord]) -> [SuperNeoSHA256CircuitWord] {
        var schedule = initialWords
        schedule.reserveCapacity(64)
        for index in 16..<64 {
            let word = addWords([
                smallSigma1(schedule[index - 2]),
                schedule[index - 7],
                smallSigma0(schedule[index - 15]),
                schedule[index - 16]
            ])
            schedule.append(word)
        }

        var a = constantWord(0x6a09e667)
        var b = constantWord(0xbb67ae85)
        var c = constantWord(0x3c6ef372)
        var d = constantWord(0xa54ff53a)
        var e = constantWord(0x510e527f)
        var f = constantWord(0x9b05688c)
        var g = constantWord(0x1f83d9ab)
        var h = constantWord(0x5be0cd19)

        for round in 0..<64 {
            let temp1 = addWords([
                h,
                bigSigma1(e),
                choice(x: e, y: f, z: g),
                constantWord(sha256RoundConstants[round]),
                schedule[round]
            ])
            let temp2 = addWords([
                bigSigma0(a),
                majority(x: a, y: b, z: c)
            ])
            h = g
            g = f
            f = e
            e = addWords([d, temp1])
            d = c
            c = b
            b = a
            a = addWords([temp1, temp2])
        }

        let initialState = [
            constantWord(0x6a09e667),
            constantWord(0xbb67ae85),
            constantWord(0x3c6ef372),
            constantWord(0xa54ff53a),
            constantWord(0x510e527f),
            constantWord(0x9b05688c),
            constantWord(0x1f83d9ab),
            constantWord(0x5be0cd19)
        ]
        return zip(initialState, [a, b, c, d, e, f, g, h]).map { addWords([$0, $1]) }
    }

    private mutating func bigSigma0(_ word: SuperNeoSHA256CircuitWord) -> SuperNeoSHA256CircuitWord {
        xorWords([rotateRight(word, by: 2), rotateRight(word, by: 13), rotateRight(word, by: 22)])
    }

    private mutating func bigSigma1(_ word: SuperNeoSHA256CircuitWord) -> SuperNeoSHA256CircuitWord {
        xorWords([rotateRight(word, by: 6), rotateRight(word, by: 11), rotateRight(word, by: 25)])
    }

    private mutating func smallSigma0(_ word: SuperNeoSHA256CircuitWord) -> SuperNeoSHA256CircuitWord {
        xorWords([rotateRight(word, by: 7), rotateRight(word, by: 18), shiftRight(word, by: 3)])
    }

    private mutating func smallSigma1(_ word: SuperNeoSHA256CircuitWord) -> SuperNeoSHA256CircuitWord {
        xorWords([rotateRight(word, by: 17), rotateRight(word, by: 19), shiftRight(word, by: 10)])
    }

    private mutating func choice(
        x: SuperNeoSHA256CircuitWord,
        y: SuperNeoSHA256CircuitWord,
        z: SuperNeoSHA256CircuitWord
    ) -> SuperNeoSHA256CircuitWord {
        SuperNeoSHA256CircuitWord(zip3(x.bits, y.bits, z.bits).map { xBit, yBit, zBit in
            xor(and(xBit, yBit), and(not(xBit), zBit))
        })
    }

    private mutating func majority(
        x: SuperNeoSHA256CircuitWord,
        y: SuperNeoSHA256CircuitWord,
        z: SuperNeoSHA256CircuitWord
    ) -> SuperNeoSHA256CircuitWord {
        SuperNeoSHA256CircuitWord(zip3(x.bits, y.bits, z.bits).map { xBit, yBit, zBit in
            xorMany([
                and(xBit, yBit),
                and(xBit, zBit),
                and(yBit, zBit)
            ])
        })
    }

    private mutating func addWords(_ words: [SuperNeoSHA256CircuitWord]) -> SuperNeoSHA256CircuitWord {
        precondition(!words.isEmpty, "SHA-256 word addition requires at least one word")
        return words.dropFirst().reduce(words[0]) { partial, word in
            addTwoWords(partial, word)
        }
    }

    private mutating func addTwoWords(
        _ lhs: SuperNeoSHA256CircuitWord,
        _ rhs: SuperNeoSHA256CircuitWord
    ) -> SuperNeoSHA256CircuitWord {
        var carry = constantBit(false)
        var output: [SuperNeoSHA256CircuitBit] = []
        output.reserveCapacity(32)
        for index in 0..<32 {
            let total = optionalSum(lhs.bits[index].intValue, rhs.bits[index].intValue, carry.intValue)
            let bit = privateBit(total.map { ($0 & 1) == 1 })
            let nextCarry = privateBit(total.map { (($0 >> 1) & 1) == 1 })
            enforceBoolean(bit)
            enforceBoolean(nextCarry)
            let equation = lhs.bits[index].linear
                .adding(rhs.bits[index].linear)
                .adding(carry.linear)
                .subtracting(bit.linear)
                .subtracting(nextCarry.linear.scaled(by: GoldilocksField(2)))
            builder.enforce(
                equation,
                times: .constant(.one, one: builder.one),
                equals: .zero()
            )
            output.append(bit)
            carry = nextCarry
        }
        return SuperNeoSHA256CircuitWord(output)
    }

    private mutating func xorWords(_ words: [SuperNeoSHA256CircuitWord]) -> SuperNeoSHA256CircuitWord {
        precondition(!words.isEmpty, "SHA-256 XOR requires at least one word")
        let bits = (0..<32).map { index in
            xorMany(words.map { $0.bits[index] })
        }
        return SuperNeoSHA256CircuitWord(bits)
    }

    private mutating func xorMany(_ bits: [SuperNeoSHA256CircuitBit]) -> SuperNeoSHA256CircuitBit {
        precondition(!bits.isEmpty, "SHA-256 XOR requires at least one bit")
        return bits.dropFirst().reduce(bits[0]) { partial, bit in
            xor(partial, bit)
        }
    }

    private mutating func xor(
        _ lhs: SuperNeoSHA256CircuitBit,
        _ rhs: SuperNeoSHA256CircuitBit
    ) -> SuperNeoSHA256CircuitBit {
        if lhs.isConstantFalse { return rhs }
        if rhs.isConstantFalse { return lhs }
        if lhs.isConstantTrue { return not(rhs) }
        if rhs.isConstantTrue { return not(lhs) }
        let product = and(lhs, rhs)
        return SuperNeoSHA256CircuitBit(
            linear: lhs.linear
                .adding(rhs.linear)
                .subtracting(product.linear.scaled(by: GoldilocksField(2))),
            value: lhs.value.flatMap { lhsValue in rhs.value.map { lhsValue != $0 } },
            constantValue: nil
        )
    }

    private mutating func and(
        _ lhs: SuperNeoSHA256CircuitBit,
        _ rhs: SuperNeoSHA256CircuitBit
    ) -> SuperNeoSHA256CircuitBit {
        if lhs.isConstantFalse || rhs.isConstantFalse { return constantBit(false) }
        if lhs.isConstantTrue { return rhs }
        if rhs.isConstantTrue { return lhs }
        let product = privateBit(lhs.value.flatMap { lhsValue in rhs.value.map { lhsValue && $0 } })
        enforceBoolean(product)
        builder.enforce(lhs.linear, times: rhs.linear, equals: product.linear)
        return product
    }

    private func not(_ bit: SuperNeoSHA256CircuitBit) -> SuperNeoSHA256CircuitBit {
        SuperNeoSHA256CircuitBit(
            linear: .constant(.one, one: builder.one).subtracting(bit.linear),
            value: bit.value.map { !$0 },
            constantValue: bit.constantValue.map { !$0 }
        )
    }

    private func rotateRight(_ word: SuperNeoSHA256CircuitWord, by amount: Int) -> SuperNeoSHA256CircuitWord {
        SuperNeoSHA256CircuitWord((0..<32).map { index in
            word.bits[(index + amount) % 32]
        })
    }

    private func shiftRight(_ word: SuperNeoSHA256CircuitWord, by amount: Int) -> SuperNeoSHA256CircuitWord {
        SuperNeoSHA256CircuitWord((0..<32).map { index in
            index + amount < 32 ? word.bits[index + amount] : constantBit(false)
        })
    }

    private func constantWord(_ value: UInt32) -> SuperNeoSHA256CircuitWord {
        SuperNeoSHA256CircuitWord((0..<32).map { bit in
            constantBit(((value >> UInt32(bit)) & 1) == 1)
        })
    }

    private mutating func publicBit(_ value: Bool? = nil) -> SuperNeoSHA256CircuitBit {
        SuperNeoSHA256CircuitBit(
            linear: .variable(builder.addPublicInput()),
            value: value,
            constantValue: nil
        )
    }

    private mutating func privateBit(_ value: Bool?) -> SuperNeoSHA256CircuitBit {
        let variable = builder.addPrivateWitness()
        if let value {
            privateWitness.append(value ? .one : .zero)
        }
        return SuperNeoSHA256CircuitBit(
            linear: .variable(variable),
            value: value,
            constantValue: nil
        )
    }

    private func constantBit(_ value: Bool) -> SuperNeoSHA256CircuitBit {
        SuperNeoSHA256CircuitBit(
            linear: .constant(value ? .one : .zero, one: builder.one),
            value: value,
            constantValue: value
        )
    }

    private mutating func enforceBoolean(_ bit: SuperNeoSHA256CircuitBit) {
        builder.enforce(
            bit.linear,
            times: bit.linear.subtracting(.constant(.one, one: builder.one)),
            equals: .zero()
        )
    }

    private mutating func enforceEqual(_ lhs: SuperNeoSHA256CircuitBit, _ rhs: SuperNeoSHA256CircuitBit) {
        builder.enforce(
            lhs.linear.subtracting(rhs.linear),
            times: .constant(.one, one: builder.one),
            equals: .zero()
        )
    }
}

private extension SuperNeoSHA256CircuitBit {
    var isConstantFalse: Bool { constantValue == false }
    var isConstantTrue: Bool { constantValue == true }

    var intValue: Int? {
        value.map { $0 ? 1 : 0 }
    }
}

private func zip3<A, B, C>(_ a: [A], _ b: [B], _ c: [C]) -> [(A, B, C)] {
    precondition(a.count == b.count && b.count == c.count, "zip3 inputs must have equal length")
    return a.indices.map { (a[$0], b[$0], c[$0]) }
}

private func optionalSum(_ values: Int?...) -> Int? {
    var total = 0
    for value in values {
        guard let value else { return nil }
        total += value
    }
    return total
}

private func concreteHashEncodeCount(_ value: Int) -> [UInt8] {
    withUnsafeBytes(of: UInt64(value).littleEndian, Array.init)
}

private let sha256RoundConstants: [UInt32] = [
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
    0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
    0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
    0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
    0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
    0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
    0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
    0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
    0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
]
