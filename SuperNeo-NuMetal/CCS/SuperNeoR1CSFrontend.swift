import Foundation

public struct SuperNeoR1CSAssignment: Equatable, Sendable {
    public let publicInput: [GoldilocksField]
    public let privateWitness: [GoldilocksField]

    public init(publicInput: [GoldilocksField], privateWitness: [GoldilocksField]) {
        self.publicInput = publicInput
        self.privateWitness = privateWitness
    }
}

public struct SuperNeoR1CSWitnessGenerator<Input: Sendable>: Sendable {
    private let makeAssignment: @Sendable (Input) throws -> SuperNeoR1CSAssignment

    public init(makeAssignment: @escaping @Sendable (Input) throws -> SuperNeoR1CSAssignment) {
        self.makeAssignment = makeAssignment
    }

    public init(
        publicInput: @escaping @Sendable (Input) throws -> [GoldilocksField],
        privateWitness: @escaping @Sendable (Input) throws -> [GoldilocksField]
    ) {
        self.makeAssignment = { input in
            SuperNeoR1CSAssignment(
                publicInput: try publicInput(input),
                privateWitness: try privateWitness(input)
            )
        }
    }

    public func generate(for input: Input) throws -> SuperNeoR1CSAssignment {
        try makeAssignment(input)
    }
}

public struct SuperNeoR1CSProgram<Input: Sendable>: Sendable {
    public let builder: SuperNeoR1CSBuilder
    public let witnessGenerator: SuperNeoR1CSWitnessGenerator<Input>

    public init(
        builder: SuperNeoR1CSBuilder,
        witnessGenerator: SuperNeoR1CSWitnessGenerator<Input>
    ) {
        self.builder = builder
        self.witnessGenerator = witnessGenerator
    }

    public func assignment(for input: Input) throws -> SuperNeoR1CSAssignment {
        try witnessGenerator.generate(for: input)
    }

    public func prove(
        input: Input,
        keySeed: [UInt8],
        proofKind: ProofEnvelopeKind = .terminalLocal,
        parameters: SuperNeoParameters = .goldilocks,
        metalContext: MetalExecutionContext? = nil,
        executionPolicy: SuperNeoExecutionPolicy = .highAssurance
    ) throws -> SuperNeoR1CSProvingOutput {
        try SuperNeoR1CSProvingStack.prove(
            builder: builder,
            assignment: assignment(for: input),
            keySeed: keySeed,
            proofKind: proofKind,
            parameters: parameters,
            metalContext: metalContext,
            executionPolicy: executionPolicy
        )
    }
}

public struct SuperNeoR1CSProvingOutput: Sendable {
    public let proofKind: ProofEnvelopeKind
    public let proofBytes: [UInt8]
    public let verifierKey: AjtaiCommitmentKey
    public let publicFoldInput: SuperNeoPublicFoldInput
    public let statement: CCSStatement
    public let context: ProofEnvelopeContext
    public let ccsStructure: CCSStructure
    public let normalizationMapping: NormalizedCCSMapping
    public let originalNormalizationRequirements: [SuperNeoFoldingShapeRequirement]

    public var verifierKeyDigest: Digest256 {
        verifierKey.verifierKeyDigest
    }

    public var requiresNormalization: Bool {
        !originalNormalizationRequirements.isEmpty
    }

    public var terminalAcceptancePolicy: SuperNeoTerminalProofAcceptancePolicy {
        SuperNeoTerminalProofAcceptancePolicy(
            publicInput: publicFoldInput,
            verifierKeyDigest: verifierKey.verifierKeyDigest
        )
    }
}

public enum SuperNeoR1CSProvingStack {
    public static func prove(
        builder: SuperNeoR1CSBuilder,
        assignment: SuperNeoR1CSAssignment,
        keySeed: [UInt8],
        proofKind: ProofEnvelopeKind = .terminalLocal,
        parameters: SuperNeoParameters = .goldilocks,
        metalContext: MetalExecutionContext? = nil,
        executionPolicy: SuperNeoExecutionPolicy = .highAssurance
    ) throws -> SuperNeoR1CSProvingOutput {
        let prepared = try builder.prepareForFolding(
            publicInput: assignment.publicInput,
            privateWitness: assignment.privateWitness,
            keySeed: keySeed,
            parameters: parameters,
            executionPolicy: executionPolicy
        )
        let publicInput = prepared.publicFoldInput
        let statement = CCSStatement(
            shapeDigest: publicInput.shape.shapeDigest,
            ccsInstances: publicInput.instances,
            priorCEInstances: publicInput.priorClaims.map { CEInstance($0) }
        )
        let context = ProofEnvelopeContext(
            profileID: parameters.profileID,
            kind: proofKind,
            statement: statement,
            verifierKeyDigest: prepared.key.verifierKeyDigest
        )
        let prover = SuperNeoProver(
            parameters: parameters,
            key: prepared.key,
            context: metalContext,
            executionPolicy: executionPolicy
        )
        let proofBytes: [UInt8]
        switch proofKind {
        case .foldReduction:
            proofBytes = try prover.foldEnvelope(prepared.foldInput, context: context).superNeoBytes
        case .terminalLocal:
            proofBytes = try prover.terminalFoldEnvelope(prepared.foldInput, context: context).superNeoBytes
        case .compressedPublic:
            proofBytes = try prover.compressedTerminalFoldEnvelope(prepared.foldInput, context: context).superNeoBytes
        }
        return SuperNeoR1CSProvingOutput(
            proofKind: proofKind,
            proofBytes: proofBytes,
            verifierKey: prepared.key,
            publicFoldInput: publicInput,
            statement: statement,
            context: context,
            ccsStructure: prepared.structure,
            normalizationMapping: prepared.preparedFoldInput.normalized.mapping,
            originalNormalizationRequirements: prepared.preparedFoldInput.originalNormalizationRequirements
        )
    }

    public static func verifyTerminalProof(
        publicInput: SuperNeoPublicFoldInput,
        proofBytes: [UInt8],
        verifierKey: AjtaiCommitmentKey,
        policy: SuperNeoTerminalProofAcceptancePolicy? = nil,
        parameters: SuperNeoParameters = .goldilocks,
        metalContext: MetalExecutionContext? = nil,
        executionPolicy: SuperNeoExecutionPolicy = .default
    ) -> VerificationResult {
        let trustedPolicy = policy ?? SuperNeoTerminalProofAcceptancePolicy(
            publicInput: publicInput,
            verifierKeyDigest: verifierKey.verifierKeyDigest,
            profileID: parameters.profileID
        )
        return SuperNeoVerifier(
            parameters: parameters,
            key: verifierKey,
            context: metalContext,
            executionPolicy: executionPolicy
        ).verifyTerminalProofEnvelope(
            publicInput: publicInput,
            proofBytes: proofBytes,
            policy: trustedPolicy
        )
    }

    public static func reduceFoldProof(
        publicInput: SuperNeoPublicFoldInput,
        proofBytes: [UInt8],
        context: ProofEnvelopeContext,
        verifierKey: AjtaiCommitmentKey,
        parameters: SuperNeoParameters = .goldilocks,
        metalContext: MetalExecutionContext? = nil,
        executionPolicy: SuperNeoExecutionPolicy = .default
    ) -> FoldReductionResult {
        SuperNeoVerifier(
            parameters: parameters,
            key: verifierKey,
            context: metalContext,
            executionPolicy: executionPolicy
        ).reduceFoldEnvelope(
            publicInput: publicInput,
            proofBytes: proofBytes,
            context: context
        )
    }
}
