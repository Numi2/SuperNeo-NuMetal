import Foundation

public enum SuperNeoSecretArithmeticPolicy: Equatable, Sendable {
    /// Use the optimized sparse/small-coefficient CPU implementation and Metal
    /// acceleration when a context is supplied.
    case optimized

    /// Use CPU reference code with fixed loop structure for secret-bearing
    /// commitment and transformed-evaluation work. This removes the largest
    /// witness-dependent zero-skip branches in this repository, but it is not a
    /// formal constant-time guarantee for Swift, the compiler, or hardware.
    case constantWorkCPU
}

public enum SuperNeoMetalTrustPolicy: Equatable, Sendable {
    /// Treat Metal as a normal accelerator after shape/key/workspace checks.
    case accelerationOnly

    /// Recompute Metal-produced commitments and transformed evaluations on CPU
    /// and reject mismatches before using the GPU result.
    case cpuRedundant
}

public struct SuperNeoExecutionPolicy: Equatable, Sendable {
    public static let `default` = SuperNeoExecutionPolicy()

    /// Conservative local policy for high-assurance runs: no secret-bearing GPU
    /// work, and any remaining Metal use must match the CPU oracle.
    public static let highAssurance = SuperNeoExecutionPolicy(
        secretArithmetic: .constantWorkCPU,
        metalTrust: .cpuRedundant
    )

    /// Useful during Metal kernel development and fault-injection tests: keep
    /// acceleration enabled, but make CPU equality mandatory.
    public static let cpuRedundantMetal = SuperNeoExecutionPolicy(
        secretArithmetic: .optimized,
        metalTrust: .cpuRedundant
    )

    public let secretArithmetic: SuperNeoSecretArithmeticPolicy
    public let metalTrust: SuperNeoMetalTrustPolicy

    public init(
        secretArithmetic: SuperNeoSecretArithmeticPolicy = .optimized,
        metalTrust: SuperNeoMetalTrustPolicy = .accelerationOnly
    ) {
        self.secretArithmetic = secretArithmetic
        self.metalTrust = metalTrust
    }

    var usesConstantWorkCPU: Bool {
        secretArithmetic == .constantWorkCPU
    }

    var requiresMetalCPUCheck: Bool {
        metalTrust == .cpuRedundant
    }
}
