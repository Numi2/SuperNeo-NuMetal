import Foundation

public struct GoldilocksField: Equatable, Hashable, Sendable {
    public static let modulus: UInt64 = 0xFFFF_FFFF_0000_0001
    public let rawValue: UInt64

    public init(_ value: UInt64) {
        self.rawValue = value >= Self.modulus ? value &- Self.modulus : value
    }

    public init(integerLiteral value: UInt64) {
        self.init(value)
    }

    public static let zero = GoldilocksField(0)
    public static let one = GoldilocksField(1)

    public static func + (lhs: Self, rhs: Self) -> Self {
        let (sum, overflow) = lhs.rawValue.addingReportingOverflow(rhs.rawValue)
        if overflow {
            // 2^64 == 2^32 - 1 mod p for p = 2^64 - 2^32 + 1.
            let folded = Self(sum) + Self(0xFFFF_FFFF)
            return folded.rawValue >= modulus ? Self(folded.rawValue &- modulus) : folded
        }
        return sum >= modulus ? Self(sum &- modulus) : Self(sum)
    }

    public static func - (lhs: Self, rhs: Self) -> Self {
        if lhs.rawValue >= rhs.rawValue {
            return Self(lhs.rawValue - rhs.rawValue)
        }
        return Self(modulus - (rhs.rawValue - lhs.rawValue))
    }

    public static prefix func - (value: Self) -> Self {
        value.rawValue == 0 ? .zero : Self(modulus - value.rawValue)
    }

    public static func * (lhs: Self, rhs: Self) -> Self {
        let product = lhs.rawValue.multipliedFullWidth(by: rhs.rawValue)
        return Self(Self.reduce(product.high, product.low))
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
        // p = 2^64 - 2^32 + 1, so 2^64 == 2^32 - 1 mod p.
        let lowPart = UInt128(low)
        let highPart = UInt128(high)
        let folded = lowPart + (highPart << 32) - highPart
        var value = folded.mod(UInt128(modulus))
        if value >= UInt128(modulus) { value = value - UInt128(modulus) }
        return value.low
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
        let adbc = (lhs.c0 * rhs.c1) + (lhs.c1 * rhs.c0)
        return Self(ac + bd * nonResidue, adbc)
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

struct UInt128: Comparable, Equatable {
    var high: UInt64
    var low: UInt64

    init(_ value: UInt64) {
        high = 0
        low = value
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.high == rhs.high ? lhs.low < rhs.low : lhs.high < rhs.high
    }

    static func + (lhs: Self, rhs: Self) -> Self {
        let (low, carry) = lhs.low.addingReportingOverflow(rhs.low)
        return Self(high: lhs.high &+ rhs.high &+ (carry ? 1 : 0), low: low)
    }

    static func - (lhs: Self, rhs: Self) -> Self {
        let (low, borrow) = lhs.low.subtractingReportingOverflow(rhs.low)
        return Self(high: lhs.high &- rhs.high &- (borrow ? 1 : 0), low: low)
    }

    static func << (lhs: Self, rhs: Int) -> Self {
        precondition(rhs >= 0 && rhs < 64)
        if rhs == 0 { return lhs }
        return Self(high: (lhs.high << rhs) | (lhs.low >> (64 - rhs)), low: lhs.low << rhs)
    }

    init(high: UInt64, low: UInt64) {
        self.high = high
        self.low = low
    }

    func mod(_ modulus: UInt128) -> UInt128 {
        var remainder = self
        while remainder >= modulus {
            let shift = max(0, remainder.bitWidth - modulus.bitWidth)
            var shifted = modulus << min(shift, 63)
            if shifted > remainder { shifted = modulus << max(0, min(shift - 1, 63)) }
            remainder = remainder - shifted
        }
        return remainder
    }

    var bitWidth: Int {
        if high != 0 { return 64 + (64 - high.leadingZeroBitCount) }
        if low != 0 { return 64 - low.leadingZeroBitCount }
        return 0
    }
}

public enum SuperNeoError: Error, Equatable {
    case divisionByZero
    case invalidEncoding(String)
    case invalidParameter(String)
    case metalUnavailable
    case metalFailure(String)
    case verificationFailed(String)
}
