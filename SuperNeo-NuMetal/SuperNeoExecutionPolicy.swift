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

public enum SuperNeoMetalRoutingPolicy: Equatable, Sendable {
    /// Use Metal only for shapes where local benchmarks show it is likely to win.
    case automatic

    /// Use Metal whenever a context is supplied and secret-bearing GPU work is allowed.
    case always
}

public struct SuperNeoExecutionPolicy: Equatable, Sendable {
    /// Secure-by-default local policy. Secret-bearing prover work uses the
    /// constant-work CPU path and does not route to Metal unless the caller
    /// selects an explicit accelerated policy.
    public static let `default` = SuperNeoExecutionPolicy()

    /// Force Metal acceleration when a context is supplied. This is useful for
    /// benchmarking, kernel development, and users who know their workload wins
    /// on their target hardware.
    public static let metalAccelerated = SuperNeoExecutionPolicy(
        secretArithmetic: .optimized,
        metalRouting: .always
    )

    /// Conservative local policy for high-assurance runs: no secret-bearing GPU
    /// work, and any remaining Metal use must match the CPU oracle.
    public static let highAssurance = SuperNeoExecutionPolicy()

    /// Useful during Metal kernel development and fault-injection tests: keep
    /// acceleration enabled, but make CPU equality mandatory.
    public static let cpuRedundantMetal = SuperNeoExecutionPolicy(
        secretArithmetic: .optimized,
        metalTrust: .cpuRedundant,
        metalRouting: .always
    )

    public let secretArithmetic: SuperNeoSecretArithmeticPolicy
    public let metalTrust: SuperNeoMetalTrustPolicy
    public let metalRouting: SuperNeoMetalRoutingPolicy

    public init(
        secretArithmetic: SuperNeoSecretArithmeticPolicy = .constantWorkCPU,
        metalTrust: SuperNeoMetalTrustPolicy = .cpuRedundant,
        metalRouting: SuperNeoMetalRoutingPolicy = .automatic
    ) {
        self.secretArithmetic = secretArithmetic
        self.metalTrust = metalTrust
        self.metalRouting = metalRouting
    }

    var usesConstantWorkCPU: Bool {
        secretArithmetic == .constantWorkCPU
    }

    var requiresMetalCPUCheck: Bool {
        metalTrust == .cpuRedundant
    }

    func usesMetalAcceleration(for shape: CCSShape) -> Bool {
        guard !usesConstantWorkCPU else { return false }
        switch metalRouting {
        case .always:
            return true
        case .automatic:
            return shape.m >= 1024
        }
    }
}
