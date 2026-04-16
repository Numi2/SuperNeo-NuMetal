import Foundation

public struct GoldilocksField: Equatable, Hashable, Sendable {
    public static let modulus: UInt64 = 0xFFFF_FFFF_0000_0001
    private static let epsilon: UInt64 = 0xFFFF_FFFF
    public let rawValue: UInt64

    public init(_ value: UInt64) {
        self.rawValue = Self.subtractModulusIfNeeded(value)
    }

    private init(uncheckedRawValue: UInt64) {
        self.rawValue = uncheckedRawValue
    }

    public init(integerLiteral value: UInt64) {
        self.init(value)
    }

    public static let zero = GoldilocksField(0)
    public static let one = GoldilocksField(1)

    public static func + (lhs: Self, rhs: Self) -> Self {
        let (sum, overflow) = lhs.rawValue.addingReportingOverflow(rhs.rawValue)
        let value = addFoldedCarry(sum, epsilon & truthMask(overflow))
        return Self(uncheckedRawValue: subtractModulusIfNeeded(value))
    }

    public static func - (lhs: Self, rhs: Self) -> Self {
        let (difference, borrow) = lhs.rawValue.subtractingReportingOverflow(rhs.rawValue)
        return Self(uncheckedRawValue: difference &+ (modulus & truthMask(borrow)))
    }

    public static prefix func - (value: Self) -> Self {
        .zero - value
    }

    public static func * (lhs: Self, rhs: Self) -> Self {
        let product = lhs.rawValue.multipliedFullWidth(by: rhs.rawValue)
        return Self(uncheckedRawValue: Self.reduce(product.high, product.low))
    }

    public func squared() -> Self { self * self }

    public func pow(_ exponent: UInt64) -> Self {
        var base = self
        var exp = exponent
        var result = Self.one
        while exp > 0 {
            if exp & 1 == 1 { result = result * base }
            exp >>= 1
            if exp > 0 { base = base * base }
        }
        return result
    }

    public func inverse() throws -> Self {
        guard rawValue != 0 else { throw SuperNeoError.divisionByZero }
        return pow(Self.modulus - 2)
    }

    public var littleEndianBytes: [UInt8] {
        withUnsafeBytes(of: rawValue.littleEndian, Array.init)
    }

    public init(littleEndianBytes bytes: ArraySlice<UInt8>) throws {
        guard bytes.count == 8 else { throw SuperNeoError.invalidEncoding("Goldilocks element must be 8 bytes") }
        let value = bytes.enumerated().reduce(UInt64(0)) { acc, pair in
            acc | (UInt64(pair.element) << UInt64(pair.offset * 8))
        }
        guard value < Self.modulus else { throw SuperNeoError.invalidEncoding("non-canonical Goldilocks element") }
        self.rawValue = value
    }

    private static func reduce(_ high: UInt64, _ low: UInt64) -> UInt64 {
        // p = 2^64 - 2^32 + 1, so fold the 128-bit high word with
        // 2^64 == 2^32 - 1 instead of running a generic 128-bit modulus loop.
        let highLow = high & epsilon
        let highHigh = high >> 32

        let reduced = (low &- highHigh) &- (epsilon & truthMask(low < highHigh))

        let foldedHighLow = highLow &* epsilon
        let (sum, overflow) = reduced.addingReportingOverflow(foldedHighLow)
        let value = addFoldedCarry(sum, epsilon & truthMask(overflow))
        return subtractModulusIfNeeded(value)
    }

    private static func addFoldedCarry(_ value: UInt64, _ foldedCarry: UInt64) -> UInt64 {
        let (first, firstOverflow) = value.addingReportingOverflow(foldedCarry)
        let (second, secondOverflow) = first.addingReportingOverflow(epsilon & truthMask(firstOverflow))
        return second &+ (epsilon & truthMask(secondOverflow))
    }

    private static func subtractModulusIfNeeded(_ value: UInt64) -> UInt64 {
        let (candidate, borrow) = value.subtractingReportingOverflow(modulus)
        let mask = truthMask(!borrow)
        return (candidate & mask) | (value & ~mask)
    }

    private static func truthMask(_ condition: Bool) -> UInt64 {
        0 &- UInt64(condition ? 1 : 0)
    }
}

public struct GoldilocksExt2: Equatable, Hashable, Sendable {
    public let c0: GoldilocksField
    public let c1: GoldilocksField

    public init(_ c0: GoldilocksField, _ c1: GoldilocksField = .zero) {
        self.c0 = c0
        self.c1 = c1
    }

    public static let zero = GoldilocksExt2(.zero)
    public static let one = GoldilocksExt2(.one)
    public static let nonResidue = GoldilocksField(7)

    public static func + (lhs: Self, rhs: Self) -> Self {
        Self(lhs.c0 + rhs.c0, lhs.c1 + rhs.c1)
    }

    public static func - (lhs: Self, rhs: Self) -> Self {
        Self(lhs.c0 - rhs.c0, lhs.c1 - rhs.c1)
    }

    public static prefix func - (value: Self) -> Self {
        Self(-value.c0, -value.c1)
    }

    public static func * (lhs: Self, rhs: Self) -> Self {
        let ac = lhs.c0 * rhs.c0
        let bd = lhs.c1 * rhs.c1
        let adbc = (lhs.c0 + lhs.c1) * (rhs.c0 + rhs.c1) - ac - bd
        return Self(ac + bd * nonResidue, adbc)
    }

    public func scaled(by scalar: GoldilocksField) -> Self {
        Self(c0 * scalar, c1 * scalar)
    }

    public func inverse() throws -> Self {
        let denominator = (c0 * c0) - (c1 * c1 * Self.nonResidue)
        let inv = try denominator.inverse()
        return Self(c0 * inv, -c1 * inv)
    }

    public var littleEndianBytes: [UInt8] {
        c0.littleEndianBytes + c1.littleEndianBytes
    }

    public init(littleEndianBytes bytes: ArraySlice<UInt8>) throws {
        guard bytes.count == 16 else { throw SuperNeoError.invalidEncoding("GoldilocksExt2 element must be 16 bytes") }
        self.c0 = try GoldilocksField(littleEndianBytes: bytes.prefix(8))
        self.c1 = try GoldilocksField(littleEndianBytes: bytes.suffix(8))
    }
}

public enum SuperNeoError: Error, Equatable {
    case divisionByZero
    case invalidEncoding(String)
    case invalidParameter(String)
    case randomnessUnavailable(String)
    case metalUnavailable
    case metalFailure(String)
    case verificationFailed(String)
}
