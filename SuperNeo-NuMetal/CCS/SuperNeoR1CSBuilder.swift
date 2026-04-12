import Foundation

public struct SuperNeoR1CSVariable: Equatable, Hashable, Sendable {
    public enum Kind: Equatable, Hashable, Sendable {
        case publicInput
        case privateWitness
    }

    public let kind: Kind
    public let offset: Int

    public init(kind: Kind, offset: Int) {
        self.kind = kind
        self.offset = offset
    }
}

public struct SuperNeoR1CSTerm: Equatable, Sendable {
    public let variable: SuperNeoR1CSVariable
    public let coefficient: GoldilocksField

    public init(variable: SuperNeoR1CSVariable, coefficient: GoldilocksField = .one) {
        self.variable = variable
        self.coefficient = coefficient
    }
}

public struct SuperNeoR1CSLinearCombination: Equatable, Sendable {
    public let terms: [SuperNeoR1CSTerm]

    public init(_ terms: [SuperNeoR1CSTerm] = []) {
        self.terms = terms.filter { $0.coefficient != .zero }
    }

    public static func zero() -> Self {
        Self()
    }

    public static func variable(
        _ variable: SuperNeoR1CSVariable,
        coefficient: GoldilocksField = .one
    ) -> Self {
        Self([SuperNeoR1CSTerm(variable: variable, coefficient: coefficient)])
    }

    public static func constant(
        _ value: GoldilocksField,
        one: SuperNeoR1CSVariable
    ) -> Self {
        value == .zero ? .zero() : .variable(one, coefficient: value)
    }

    public func adding(_ other: Self) -> Self {
        Self(terms + other.terms)
    }

    public func subtracting(_ other: Self) -> Self {
        adding(other.scaled(by: -.one))
    }

    public func scaled(by scalar: GoldilocksField) -> Self {
        guard scalar != .zero else { return .zero() }
        return Self(terms.map { SuperNeoR1CSTerm(variable: $0.variable, coefficient: $0.coefficient * scalar) })
    }
}

public struct SuperNeoR1CSConstraint: Equatable, Sendable {
    public let a: SuperNeoR1CSLinearCombination
    public let b: SuperNeoR1CSLinearCombination
    public let c: SuperNeoR1CSLinearCombination

    public init(
        a: SuperNeoR1CSLinearCombination,
        b: SuperNeoR1CSLinearCombination,
        c: SuperNeoR1CSLinearCombination
    ) {
        self.a = a
        self.b = b
        self.c = c
    }
}

public struct SuperNeoPreparedR1CS: Sendable {
    public let structure: CCSStructure
    public let preparedFoldInput: SuperNeoPreparedFoldInput

    public var key: AjtaiCommitmentKey { preparedFoldInput.key }
    public var foldInput: SuperNeoFoldInput { preparedFoldInput.foldInput }
    public var publicFoldInput: SuperNeoPublicFoldInput { preparedFoldInput.publicFoldInput }
}

public struct SuperNeoR1CSBuilder: Sendable {
    public private(set) var publicInputCount: Int
    public private(set) var privateWitnessCount: Int
    public private(set) var constraints: [SuperNeoR1CSConstraint]
    public let one: SuperNeoR1CSVariable

    public init() {
        self.publicInputCount = 1
        self.privateWitnessCount = 0
        self.constraints = []
        self.one = SuperNeoR1CSVariable(kind: .publicInput, offset: 0)
    }

    @discardableResult
    public mutating func addPublicInput() -> SuperNeoR1CSVariable {
        defer { publicInputCount += 1 }
        return SuperNeoR1CSVariable(kind: .publicInput, offset: publicInputCount)
    }

    @discardableResult
    public mutating func addPrivateWitness() -> SuperNeoR1CSVariable {
        defer { privateWitnessCount += 1 }
        return SuperNeoR1CSVariable(kind: .privateWitness, offset: privateWitnessCount)
    }

    public mutating func enforce(
        _ a: SuperNeoR1CSLinearCombination,
        times b: SuperNeoR1CSLinearCombination,
        equals c: SuperNeoR1CSLinearCombination
    ) {
        constraints.append(SuperNeoR1CSConstraint(a: a, b: b, c: c))
    }

    public mutating func enforceBoolean(_ variable: SuperNeoR1CSVariable) {
        let value = SuperNeoR1CSLinearCombination.variable(variable)
        enforce(
            value,
            times: value.subtracting(.constant(.one, one: one)),
            equals: .zero()
        )
    }

    public func buildStructure() throws -> CCSStructure {
        guard !constraints.isEmpty else {
            throw SuperNeoError.invalidParameter("R1CS builder requires at least one constraint")
        }
        let matrices = try (0..<3).map { matrixIndex in
            try makeMatrix(matrixIndex: matrixIndex)
        }
        let relation = try RelationPolynomial(
            variableCount: 3,
            monomials: [
                RelationMonomial(coefficient: .one, exponents: [1, 1, 0]),
                RelationMonomial(coefficient: -.one, exponents: [0, 0, 1])
            ]
        )
        return CCSStructure(matrices: matrices, relationPolynomial: relation)
    }

    public func evaluate(
        publicInput: [GoldilocksField],
        privateWitness: [GoldilocksField]
    ) throws -> [GoldilocksField] {
        let fullWitness = try fullWitness(publicInput: publicInput, privateWitness: privateWitness)
        return try constraints.map { constraint in
            try evaluate(constraint.a, fullWitness: fullWitness)
                * evaluate(constraint.b, fullWitness: fullWitness)
                - evaluate(constraint.c, fullWitness: fullWitness)
        }
    }

    public func validateWitness(
        publicInput: [GoldilocksField],
        privateWitness: [GoldilocksField]
    ) throws -> Bool {
        try evaluate(publicInput: publicInput, privateWitness: privateWitness).allSatisfy { $0 == .zero }
    }

    public func prepareForFolding(
        publicInput: [GoldilocksField],
        privateWitness: [GoldilocksField],
        keySeed: [UInt8],
        parameters: SuperNeoParameters = .goldilocks
    ) throws -> SuperNeoPreparedR1CS {
        guard publicInput.first == .one else {
            throw SuperNeoError.invalidParameter("R1CS public input 0 must be the constant one")
        }
        guard try validateWitness(publicInput: publicInput, privateWitness: privateWitness) else {
            throw SuperNeoError.invalidParameter("R1CS witness does not satisfy all constraints")
        }
        let structure = try buildStructure()
        let prepared = try SuperNeoCCSNormalizer.prepareForFolding(
            structure: structure,
            publicInputs: [publicInput],
            privateWitnesses: [privateWitness],
            keySeed: keySeed,
            parameters: parameters
        )
        return SuperNeoPreparedR1CS(structure: structure, preparedFoldInput: prepared)
    }

    private func makeMatrix(matrixIndex: Int) throws -> SparseFieldMatrix {
        let rows = constraints.count
        let columns = publicInputCount + privateWitnessCount
        var entries: [SparseFieldMatrix.Entry] = []
        for (row, constraint) in constraints.enumerated() {
            let combination: SuperNeoR1CSLinearCombination
            switch matrixIndex {
            case 0: combination = constraint.a
            case 1: combination = constraint.b
            default: combination = constraint.c
            }
            let rowEntries = try canonicalEntries(for: combination, row: row)
            entries.append(contentsOf: rowEntries)
        }
        return try SparseFieldMatrix(rows: rows, columns: columns, entries: entries)
    }

    private func canonicalEntries(
        for combination: SuperNeoR1CSLinearCombination,
        row: Int
    ) throws -> [SparseFieldMatrix.Entry] {
        var byColumn: [Int: GoldilocksField] = [:]
        for term in combination.terms {
            let column = try columnIndex(for: term.variable)
            byColumn[column, default: .zero] = byColumn[column, default: .zero] + term.coefficient
        }
        return byColumn
            .filter { $0.value != .zero }
            .sorted { $0.key < $1.key }
            .map { SparseFieldMatrix.Entry(row: row, column: $0.key, value: $0.value) }
    }

    private func columnIndex(for variable: SuperNeoR1CSVariable) throws -> Int {
        switch variable.kind {
        case .publicInput:
            guard variable.offset >= 0, variable.offset < publicInputCount else {
                throw SuperNeoError.invalidParameter("R1CS public variable out of bounds")
            }
            return variable.offset
        case .privateWitness:
            guard variable.offset >= 0, variable.offset < privateWitnessCount else {
                throw SuperNeoError.invalidParameter("R1CS private variable out of bounds")
            }
            return publicInputCount + variable.offset
        }
    }

    private func fullWitness(
        publicInput: [GoldilocksField],
        privateWitness: [GoldilocksField]
    ) throws -> [GoldilocksField] {
        guard publicInput.count == publicInputCount else {
            throw SuperNeoError.invalidParameter("R1CS public input length mismatch")
        }
        guard privateWitness.count == privateWitnessCount else {
            throw SuperNeoError.invalidParameter("R1CS private witness length mismatch")
        }
        return publicInput + privateWitness
    }

    private func evaluate(
        _ combination: SuperNeoR1CSLinearCombination,
        fullWitness: [GoldilocksField]
    ) throws -> GoldilocksField {
        try combination.terms.reduce(.zero) { partial, term in
            let column = try columnIndex(for: term.variable)
            return partial + term.coefficient * fullWitness[column]
        }
    }
}

public struct SuperNeoOneHotVectorWorkload: Sendable {
    public let bitCount: Int
    public let builder: SuperNeoR1CSBuilder
    public let bitVariables: [SuperNeoR1CSVariable]

    public init(bitCount: Int) throws {
        guard bitCount > 0 else {
            throw SuperNeoError.invalidParameter("one-hot workload requires at least one bit")
        }
        guard bitCount <= 1 << 20 else {
            throw SuperNeoError.invalidParameter("one-hot workload is too large")
        }
        var builder = SuperNeoR1CSBuilder()
        let bits = (0..<bitCount).map { _ in builder.addPrivateWitness() }
        for bit in bits {
            builder.enforceBoolean(bit)
        }

        var sumCombination = SuperNeoR1CSLinearCombination.zero()
        for bit in bits {
            sumCombination = sumCombination.adding(.variable(bit))
        }
        sumCombination = sumCombination.subtracting(.constant(.one, one: builder.one))
        builder.enforce(sumCombination, times: .constant(.one, one: builder.one), equals: .zero())

        self.bitCount = bitCount
        self.builder = builder
        self.bitVariables = bits
    }

    public var publicInput: [GoldilocksField] {
        [.one]
    }

    public func privateWitness(bits: [Bool]) throws -> [GoldilocksField] {
        guard bits.count == bitCount else {
            throw SuperNeoError.invalidParameter("one-hot witness length mismatch")
        }
        guard bits.filter({ $0 }).count == 1 else {
            throw SuperNeoError.invalidParameter("one-hot witness must contain exactly one selected bit")
        }
        return bits.map { $0 ? .one : .zero }
    }

    public func prepareForFolding(
        bits: [Bool],
        keySeed: [UInt8],
        parameters: SuperNeoParameters = .goldilocks
    ) throws -> SuperNeoPreparedR1CS {
        try builder.prepareForFolding(
            publicInput: publicInput,
            privateWitness: privateWitness(bits: bits),
            keySeed: keySeed,
            parameters: parameters
        )
    }

    public func publicFoldInput(commitment: AjtaiCommitment) throws -> SuperNeoPublicFoldInput {
        let structure = try builder.buildStructure()
        let normalized = try SuperNeoCCSNormalizer.normalizeShape(
            structure: structure,
            publicInputCount: builder.publicInputCount
        )
        let normalizedPublicInput = try normalized.mapping.embedPublicInput(publicInput)
        return SuperNeoPublicFoldInput(
            shape: normalized.shape,
            instances: [CCSInstance(commitment: commitment, publicInput: normalizedPublicInput)]
        )
    }
}

public struct SuperNeoBinaryAdditionWorkload: Sendable {
    public let bitCount: Int
    public let builder: SuperNeoR1CSBuilder
    public let leftVariables: [SuperNeoR1CSVariable]
    public let rightVariables: [SuperNeoR1CSVariable]
    public let sumVariables: [SuperNeoR1CSVariable]
    public let carryVariables: [SuperNeoR1CSVariable]

    public init(bitCount: Int) throws {
        guard bitCount > 0 else {
            throw SuperNeoError.invalidParameter("binary addition workload requires at least one bit")
        }
        guard bitCount <= 62 else {
            throw SuperNeoError.invalidParameter("binary addition integer helpers support at most 62 operand bits")
        }

        var builder = SuperNeoR1CSBuilder()
        let sumBits = (0...bitCount).map { _ in builder.addPublicInput() }
        let leftBits = (0..<bitCount).map { _ in builder.addPrivateWitness() }
        let rightBits = (0..<bitCount).map { _ in builder.addPrivateWitness() }
        let carryBits = (0..<bitCount).map { _ in builder.addPrivateWitness() }

        for variable in sumBits + leftBits + rightBits + carryBits {
            builder.enforceBoolean(variable)
        }

        let one = SuperNeoR1CSLinearCombination.constant(.one, one: builder.one)
        for index in 0..<bitCount {
            var bitEquation = SuperNeoR1CSLinearCombination
                .variable(leftBits[index])
                .adding(.variable(rightBits[index]))
                .subtracting(.variable(sumBits[index]))
                .subtracting(.variable(carryBits[index], coefficient: GoldilocksField(2)))
            if index > 0 {
                bitEquation = bitEquation.adding(.variable(carryBits[index - 1]))
            }
            builder.enforce(bitEquation, times: one, equals: .zero())
        }

        let finalCarryEquation = SuperNeoR1CSLinearCombination
            .variable(carryBits[bitCount - 1])
            .subtracting(.variable(sumBits[bitCount]))
        builder.enforce(finalCarryEquation, times: one, equals: .zero())

        self.bitCount = bitCount
        self.builder = builder
        self.leftVariables = leftBits
        self.rightVariables = rightBits
        self.sumVariables = sumBits
        self.carryVariables = carryBits
    }

    public func publicInput(sum: UInt64) throws -> [GoldilocksField] {
        guard sum < (UInt64(1) << UInt64(bitCount + 1)) else {
            throw SuperNeoError.invalidParameter("binary addition public sum does not fit output bit count")
        }
        return [.one] + bits(sum, count: bitCount + 1).map { $0 ? .one : .zero }
    }

    public func privateWitness(left: UInt64, right: UInt64) throws -> [GoldilocksField] {
        let bound = UInt64(1) << UInt64(bitCount)
        guard left < bound else {
            throw SuperNeoError.invalidParameter("binary addition left operand does not fit bit count")
        }
        guard right < bound else {
            throw SuperNeoError.invalidParameter("binary addition right operand does not fit bit count")
        }
        let leftBits = bits(left, count: bitCount)
        let rightBits = bits(right, count: bitCount)
        var carry = false
        var carryBits: [Bool] = []
        carryBits.reserveCapacity(bitCount)
        for index in 0..<bitCount {
            let total = (leftBits[index] ? 1 : 0)
                + (rightBits[index] ? 1 : 0)
                + (carry ? 1 : 0)
            carry = total >= 2
            carryBits.append(carry)
        }
        return (leftBits + rightBits + carryBits).map { $0 ? .one : .zero }
    }

    public func prepareForFolding(
        left: UInt64,
        right: UInt64,
        keySeed: [UInt8],
        parameters: SuperNeoParameters = .goldilocks
    ) throws -> SuperNeoPreparedR1CS {
        let addition = left.addingReportingOverflow(right)
        guard !addition.overflow else {
            throw SuperNeoError.invalidParameter("binary addition operands overflow UInt64")
        }
        return try builder.prepareForFolding(
            publicInput: publicInput(sum: addition.partialValue),
            privateWitness: privateWitness(left: left, right: right),
            keySeed: keySeed,
            parameters: parameters
        )
    }

    public func publicFoldInput(
        commitment: AjtaiCommitment,
        publicInput: [GoldilocksField]
    ) throws -> SuperNeoPublicFoldInput {
        guard publicInput.count == bitCount + 2 else {
            throw SuperNeoError.invalidParameter("binary addition public input length mismatch")
        }
        guard publicInput.first == .one else {
            throw SuperNeoError.invalidParameter("binary addition public input 0 must be the constant one")
        }
        guard publicInput.dropFirst().allSatisfy({ $0 == .zero || $0 == .one }) else {
            throw SuperNeoError.invalidParameter("binary addition public sum bits must be binary")
        }
        let structure = try builder.buildStructure()
        let normalized = try SuperNeoCCSNormalizer.normalizeShape(
            structure: structure,
            publicInputCount: builder.publicInputCount
        )
        let normalizedPublicInput = try normalized.mapping.embedPublicInput(publicInput)
        return SuperNeoPublicFoldInput(
            shape: normalized.shape,
            instances: [CCSInstance(commitment: commitment, publicInput: normalizedPublicInput)]
        )
    }

    private func bits(_ value: UInt64, count: Int) -> [Bool] {
        (0..<count).map { index in
            ((value >> UInt64(index)) & 1) == 1
        }
    }
}
