import Foundation

enum SuperNeoPayPerBitConstantSchedule {
    static func splitSignedBase(
        _ values: [GoldilocksField],
        base: Int,
        count: Int
    ) throws -> [[GoldilocksField]] {
        guard base >= 2 else {
            throw SuperNeoError.invalidParameter("decomposition base must be at least two")
        }
        guard count > 0 else {
            throw SuperNeoError.invalidParameter("decomposition limb count must be positive")
        }
        var limbs = Array(
            repeating: Array(repeating: GoldilocksField.zero, count: values.count),
            count: count
        )
        let radix = UInt64(base)
        var overflowMask: UInt64 = 0
        for (valueIndex, value) in values.enumerated() {
            var magnitude = signedMagnitude(value)
            let sign = signedUnit(value)
            for limbIndex in 0..<count {
                let digit = magnitude % radix
                limbs[limbIndex][valueIndex] = sign * GoldilocksField(digit)
                magnitude /= radix
            }
            overflowMask |= GoldilocksField.truthMask(magnitude != 0)
        }
        guard overflowMask == 0 else {
            throw SuperNeoError.invalidParameter(
                "value exceeds signed base-\(base) decomposition bound with \(count) limbs"
            )
        }
        return limbs
    }

    static func signedMagnitude(_ value: GoldilocksField) -> UInt64 {
        let isNegative = value.rawValue > GoldilocksField.modulus / 2
        let mask = GoldilocksField.truthMask(isNegative)
        let negativeMagnitude = GoldilocksField.modulus &- value.rawValue
        return (negativeMagnitude & mask) | (value.rawValue & ~mask)
    }

    static func signedUnit(_ value: GoldilocksField) -> GoldilocksField {
        GoldilocksField.constantTimeSelect(
            .one,
            -GoldilocksField.one,
            when: value.rawValue > GoldilocksField.modulus / 2
        )
    }
}
