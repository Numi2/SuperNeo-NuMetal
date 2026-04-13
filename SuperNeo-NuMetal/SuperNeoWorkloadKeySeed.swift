import Foundation

public enum SuperNeoWorkloadKeySeed {
    public static func oneHotVector(bitCount: Int) throws -> String {
        guard bitCount > 0 else {
            throw SuperNeoError.invalidParameter("one-hot key seed requires a positive bit count")
        }
        if bitCount == 8 {
            return "SuperNeoCLI.one-hot-vector.v1"
        }
        return "SuperNeoCLI.one-hot-vector.u\(bitCount).v1"
    }

    public static func binaryAddition(operandBits: Int) throws -> String {
        guard operandBits > 0, operandBits <= 62 else {
            throw SuperNeoError.invalidParameter("binary-addition key seed requires operand bits in 1...62")
        }
        if operandBits == 8 {
            return "SuperNeoCLI.binary-addition.u8.v1"
        }
        return "SuperNeoCLI.binary-addition.u\(operandBits).v1"
    }
}
