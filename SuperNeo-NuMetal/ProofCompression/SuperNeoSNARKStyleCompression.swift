import Foundation

public struct SuperNeoSNARKStyleCompressionProof: Equatable, Sendable, SuperNeoByteEncodable {
    public static let schemeID = "superneo-local-recursive-verifier-snark-style-v0"
    public static let domain = Digest256.hash("SuperNeo-NuMetal.snark-style-compression.v0")
    public static let version: UInt16 = 1

    public let version: UInt16
    public let schemeID: String
    public let sourceProofKind: ProofEnvelopeKind
    public let sourceProofByteCount: Int
    public let sourceProofDigest: Digest256
    public let profileID: UInt16
    public let shapeDigest: Digest256
    public let statementDigest: Digest256
    public let verifierKeyDigest: Digest256
    public let transcriptDomain: Digest256
    public let compressionCircuitDigest: Digest256
    public let recursiveVerifierTraceDigest: Digest256
    public let terminalVerifierProof: SuperNeoTerminalVerifierArithmetizationProof
    public let proofDigest: Digest384

    public init(
        sourceProofKind: ProofEnvelopeKind,
        sourceProofByteCount: Int,
        sourceProofDigest: Digest256,
        profileID: UInt16,
        shapeDigest: Digest256,
        statementDigest: Digest256,
        verifierKeyDigest: Digest256,
        transcriptDomain: Digest256,
        compressionCircuitDigest: Digest256,
        recursiveVerifierTraceDigest: Digest256,
        terminalVerifierProof: SuperNeoTerminalVerifierArithmetizationProof
    ) throws {
        guard sourceProofKind == .terminalLocal || sourceProofKind == .compressedPublic else {
            throw SuperNeoError.invalidParameter("SNARK-style compression only accepts terminal proof sources")
        }
        guard sourceProofByteCount > 0 else {
            throw SuperNeoError.invalidParameter("SNARK-style compression source byte count must be positive")
        }
        guard terminalVerifierProof.sourceProofKind == sourceProofKind,
              terminalVerifierProof.sourceProofByteCount == sourceProofByteCount,
              terminalVerifierProof.sourceProofDigest == sourceProofDigest,
              terminalVerifierProof.profileID == profileID,
              terminalVerifierProof.shapeDigest == shapeDigest,
              terminalVerifierProof.statementDigest == statementDigest,
              terminalVerifierProof.verifierKeyDigest == verifierKeyDigest,
              terminalVerifierProof.transcriptDomain == transcriptDomain else {
            throw SuperNeoError.invalidParameter("SNARK-style compression terminal verifier relation mismatch")
        }
        self.version = Self.version
        self.schemeID = Self.schemeID
        self.sourceProofKind = sourceProofKind
        self.sourceProofByteCount = sourceProofByteCount
        self.sourceProofDigest = sourceProofDigest
        self.profileID = profileID
        self.shapeDigest = shapeDigest
        self.statementDigest = statementDigest
        self.verifierKeyDigest = verifierKeyDigest
        self.transcriptDomain = transcriptDomain
        self.compressionCircuitDigest = compressionCircuitDigest
        self.recursiveVerifierTraceDigest = recursiveVerifierTraceDigest
        self.terminalVerifierProof = terminalVerifierProof
        self.proofDigest = Self.computeProofDigest(
            version: Self.version,
            schemeID: Self.schemeID,
            sourceProofKind: sourceProofKind,
            sourceProofByteCount: sourceProofByteCount,
            sourceProofDigest: sourceProofDigest,
            profileID: profileID,
            shapeDigest: shapeDigest,
            statementDigest: statementDigest,
            verifierKeyDigest: verifierKeyDigest,
            transcriptDomain: transcriptDomain,
            compressionCircuitDigest: compressionCircuitDigest,
            recursiveVerifierTraceDigest: recursiveVerifierTraceDigest,
            terminalVerifierProof: terminalVerifierProof
        )
    }

    public var compressionRatioAgainstSource: Double {
        Double(sourceProofByteCount) / Double(max(1, superNeoBytes.count))
    }

    public var superNeoBytes: [UInt8] {
        Self.domain.superNeoBytes
            + Self.bodyBytes(
                version: version,
                schemeID: schemeID,
                sourceProofKind: sourceProofKind,
                sourceProofByteCount: sourceProofByteCount,
                sourceProofDigest: sourceProofDigest,
                profileID: profileID,
                shapeDigest: shapeDigest,
                statementDigest: statementDigest,
                verifierKeyDigest: verifierKeyDigest,
                transcriptDomain: transcriptDomain,
                compressionCircuitDigest: compressionCircuitDigest,
                recursiveVerifierTraceDigest: recursiveVerifierTraceDigest,
                terminalVerifierProof: terminalVerifierProof
            )
            + proofDigest.superNeoBytes
    }

    public func hasValidDigest() -> Bool {
        terminalVerifierProof.hasValidDigest()
        && proofDigest == Self.computeProofDigest(
            version: version,
            schemeID: schemeID,
            sourceProofKind: sourceProofKind,
            sourceProofByteCount: sourceProofByteCount,
            sourceProofDigest: sourceProofDigest,
            profileID: profileID,
            shapeDigest: shapeDigest,
            statementDigest: statementDigest,
            verifierKeyDigest: verifierKeyDigest,
            transcriptDomain: transcriptDomain,
            compressionCircuitDigest: compressionCircuitDigest,
            recursiveVerifierTraceDigest: recursiveVerifierTraceDigest,
            terminalVerifierProof: terminalVerifierProof
        )
    }

    static func compressionCircuitDigest(
        profileID: UInt16,
        sourceProofKind: ProofEnvelopeKind,
        statementDigest: Digest256,
        verifierKeyDigest: Digest256,
        terminalVerifierRelationDigest: Digest256
    ) -> Digest256 {
        Digest256.hash(
            Self.domain.superNeoBytes
                + encodeString("recursive-terminal-verifier-circuit")
                + encodeUInt16Local(profileID)
                + [sourceProofKind.rawValue]
                + statementDigest.superNeoBytes
                + verifierKeyDigest.superNeoBytes
                + terminalVerifierRelationDigest.superNeoBytes
        )
    }

    static func recursiveVerifierTraceDigest(
        header: ProofEnvelopeHeader,
        sourceProofDigest: Digest256,
        publicStatement: CCSStatement,
        accepted: Bool
    ) -> Digest256 {
        Digest256.hash(
            Self.domain.superNeoBytes
                + encodeString("recursive-terminal-verifier-trace")
                + header.superNeoBytes
                + sourceProofDigest.superNeoBytes
                + publicStatement.superNeoBytes
                + [accepted ? 1 : 0]
        )
    }

    private static func computeProofDigest(
        version: UInt16,
        schemeID: String,
        sourceProofKind: ProofEnvelopeKind,
        sourceProofByteCount: Int,
        sourceProofDigest: Digest256,
        profileID: UInt16,
        shapeDigest: Digest256,
        statementDigest: Digest256,
        verifierKeyDigest: Digest256,
        transcriptDomain: Digest256,
        compressionCircuitDigest: Digest256,
        recursiveVerifierTraceDigest: Digest256,
        terminalVerifierProof: SuperNeoTerminalVerifierArithmetizationProof
    ) -> Digest384 {
        Digest384.shake256(
            Self.domain.superNeoBytes
                + bodyBytes(
                    version: version,
                    schemeID: schemeID,
                    sourceProofKind: sourceProofKind,
                    sourceProofByteCount: sourceProofByteCount,
                    sourceProofDigest: sourceProofDigest,
                    profileID: profileID,
                    shapeDigest: shapeDigest,
                    statementDigest: statementDigest,
                    verifierKeyDigest: verifierKeyDigest,
                    transcriptDomain: transcriptDomain,
                    compressionCircuitDigest: compressionCircuitDigest,
                    recursiveVerifierTraceDigest: recursiveVerifierTraceDigest,
                    terminalVerifierProof: terminalVerifierProof
                )
        )
    }

    private static func bodyBytes(
        version: UInt16,
        schemeID: String,
        sourceProofKind: ProofEnvelopeKind,
        sourceProofByteCount: Int,
        sourceProofDigest: Digest256,
        profileID: UInt16,
        shapeDigest: Digest256,
        statementDigest: Digest256,
        verifierKeyDigest: Digest256,
        transcriptDomain: Digest256,
        compressionCircuitDigest: Digest256,
        recursiveVerifierTraceDigest: Digest256,
        terminalVerifierProof: SuperNeoTerminalVerifierArithmetizationProof
    ) -> [UInt8] {
        encodeUInt16Local(version)
            + encodeString(schemeID)
            + [sourceProofKind.rawValue]
            + encodeCountLocal(sourceProofByteCount)
            + sourceProofDigest.superNeoBytes
            + encodeUInt16Local(profileID)
            + shapeDigest.superNeoBytes
            + statementDigest.superNeoBytes
            + verifierKeyDigest.superNeoBytes
            + transcriptDomain.superNeoBytes
            + compressionCircuitDigest.superNeoBytes
            + recursiveVerifierTraceDigest.superNeoBytes
            + terminalVerifierProof.superNeoBytes
    }
}

public enum SuperNeoSNARKStyleCompressor {
    public static func compressTerminalProof(
        publicInput: SuperNeoPublicFoldInput,
        proofBytes: [UInt8],
        verifierKey: AjtaiCommitmentKey,
        policy: SuperNeoTerminalProofAcceptancePolicy? = nil,
        parameters: SuperNeoParameters = .goldilocks,
        metalContext: MetalExecutionContext? = nil,
        executionPolicy: SuperNeoExecutionPolicy = .default
    ) throws -> SuperNeoSNARKStyleCompressionProof {
        try compressAcceptedProof(
            publicInput: publicInput,
            proofBytes: proofBytes,
            verifierKey: verifierKey,
            policy: policy,
            parameters: parameters,
            metalContext: metalContext,
            executionPolicy: executionPolicy
        )
    }

    public static func compressAcceptedProof(
        publicInput: SuperNeoPublicFoldInput,
        proofBytes: [UInt8],
        verifierKey: AjtaiCommitmentKey,
        policy: SuperNeoTerminalProofAcceptancePolicy? = nil,
        parameters: SuperNeoParameters = .goldilocks,
        metalContext: MetalExecutionContext? = nil,
        executionPolicy: SuperNeoExecutionPolicy = .default
    ) throws -> SuperNeoSNARKStyleCompressionProof {
        let header = try ProofEnvelopeHeader.parsePrefix(from: proofBytes)
        let statement = CCSStatement(
            shapeDigest: publicInput.shape.shapeDigest,
            ccsInstances: publicInput.instances,
            priorCEInstances: publicInput.priorClaims.map { CEInstance($0) },
            recursiveRelationDigest: publicInput.recursiveRelationDigest
        )
        let trustedPolicy = policy ?? SuperNeoTerminalProofAcceptancePolicy(
            statement: statement,
            verifierKeyDigest: verifierKey.verifierKeyDigest,
            profileID: parameters.profileID,
            transcriptDomain: header.transcriptDomain
        )
        let verification = SuperNeoVerifier(
            parameters: parameters,
            key: verifierKey,
            context: metalContext,
            executionPolicy: executionPolicy
        ).verifyTerminalProofEnvelope(
            publicInput: publicInput,
            proofBytes: proofBytes,
            policy: trustedPolicy
        )
        guard verification.isValid else {
            throw SuperNeoError.verificationFailed(
                "SNARK-style compression requires an accepted terminal proof: \(verification.reason ?? "unknown")"
            )
        }
        let terminalVerifierProof = try SuperNeoTerminalVerifierArithmetizationProof.make(
            publicInput: publicInput,
            proofBytes: proofBytes,
            policy: trustedPolicy,
            parameters: parameters
        )
        let sourceProofDigest = Digest256.hash(proofBytes)
        let circuitDigest = SuperNeoSNARKStyleCompressionProof.compressionCircuitDigest(
            profileID: header.profileID,
            sourceProofKind: header.kind,
            statementDigest: header.statementDigest,
            verifierKeyDigest: header.verifierKeyDigest,
            terminalVerifierRelationDigest: terminalVerifierProof.relationDigest
        )
        let traceDigest = SuperNeoSNARKStyleCompressionProof.recursiveVerifierTraceDigest(
            header: header,
            sourceProofDigest: sourceProofDigest,
            publicStatement: statement,
            accepted: true
        )
        return try SuperNeoSNARKStyleCompressionProof(
            sourceProofKind: header.kind,
            sourceProofByteCount: proofBytes.count,
            sourceProofDigest: sourceProofDigest,
            profileID: header.profileID,
            shapeDigest: header.shapeDigest,
            statementDigest: header.statementDigest,
            verifierKeyDigest: header.verifierKeyDigest,
            transcriptDomain: header.transcriptDomain,
            compressionCircuitDigest: circuitDigest,
            recursiveVerifierTraceDigest: traceDigest,
            terminalVerifierProof: terminalVerifierProof
        )
    }

    public static func verifyCompressionProof(
        _ proof: SuperNeoSNARKStyleCompressionProof,
        publicInput: SuperNeoPublicFoldInput,
        verifierKeyDigest: Digest256,
        policy: SuperNeoTerminalProofAcceptancePolicy
    ) -> VerificationResult {
        .invalid(
            "SNARK-style source-free compression verification requires the verifier key"
        )
    }

    public static func verifyCompressionProof(
        _ proof: SuperNeoSNARKStyleCompressionProof,
        publicInput: SuperNeoPublicFoldInput,
        verifierKey: AjtaiCommitmentKey,
        policy: SuperNeoTerminalProofAcceptancePolicy,
        parameters: SuperNeoParameters = .goldilocks,
        metalContext: MetalExecutionContext? = nil,
        executionPolicy: SuperNeoExecutionPolicy = .default
    ) -> VerificationResult {
        let relation = proof.terminalVerifierProof.verifySourceFree(
            publicInput: publicInput,
            verifierKey: verifierKey,
            policy: policy,
            parameters: parameters,
            metalContext: metalContext,
            executionPolicy: executionPolicy
        )
        guard relation.isValid else {
            return .invalid("SNARK-style terminal verifier arithmetization rejected: \(relation.reason ?? "unknown")")
        }
        return verifyAcceptedCompressionProof(
            proof,
            publicInput: publicInput,
            verifierKeyDigest: verifierKey.verifierKeyDigest,
            policy: policy
        )
    }

    private static func verifyAcceptedCompressionProof(
        _ proof: SuperNeoSNARKStyleCompressionProof,
        publicInput: SuperNeoPublicFoldInput,
        verifierKeyDigest: Digest256,
        policy: SuperNeoTerminalProofAcceptancePolicy
    ) -> VerificationResult {
        let statement = CCSStatement(
            shapeDigest: publicInput.shape.shapeDigest,
            ccsInstances: publicInput.instances,
            priorCEInstances: publicInput.priorClaims.map { CEInstance($0) },
            recursiveRelationDigest: publicInput.recursiveRelationDigest
        )
        guard proof.version == SuperNeoSNARKStyleCompressionProof.version else {
            return .invalid("unsupported SNARK-style compression proof version")
        }
        guard proof.schemeID == SuperNeoSNARKStyleCompressionProof.schemeID else {
            return .invalid("unsupported SNARK-style compression scheme")
        }
        guard proof.hasValidDigest() else {
            return .invalid("SNARK-style compression proof digest mismatch")
        }
        guard proof.profileID == policy.profileID else {
            return .invalid("SNARK-style compression profile mismatch")
        }
        guard proof.shapeDigest == statement.shapeDigest,
              proof.statementDigest == statement.statementDigest else {
            return .invalid("SNARK-style compression statement mismatch")
        }
        guard proof.verifierKeyDigest == verifierKeyDigest,
              proof.verifierKeyDigest == policy.verifierKeyDigest else {
            return .invalid("SNARK-style compression verifier key mismatch")
        }
        guard proof.transcriptDomain == policy.transcriptDomain else {
            return .invalid("SNARK-style compression transcript domain mismatch")
        }
        guard policy.proofKindPolicy.accepts(proof.sourceProofKind) else {
            return .invalid("SNARK-style compression source proof kind not accepted")
        }
        let expectedCircuitDigest = SuperNeoSNARKStyleCompressionProof.compressionCircuitDigest(
            profileID: proof.profileID,
            sourceProofKind: proof.sourceProofKind,
            statementDigest: proof.statementDigest,
            verifierKeyDigest: proof.verifierKeyDigest,
            terminalVerifierRelationDigest: proof.terminalVerifierProof.relationDigest
        )
        guard proof.compressionCircuitDigest == expectedCircuitDigest else {
            return .invalid("SNARK-style compression circuit digest mismatch")
        }
        guard proof.sourceProofByteCount >= ProofEnvelopeHeader.byteCount else {
            return .invalid("SNARK-style compression source byte count below envelope header")
        }
        let bodyLength = proof.sourceProofByteCount - ProofEnvelopeHeader.byteCount
        guard bodyLength <= Int(UInt32.max) else {
            return .invalid("SNARK-style compression source body length exceeds envelope format")
        }
        let expectedHeader = ProofEnvelopeHeader(
            profileID: proof.profileID,
            kind: proof.sourceProofKind,
            shapeDigest: proof.shapeDigest,
            statementDigest: proof.statementDigest,
            verifierKeyDigest: proof.verifierKeyDigest,
            transcriptDomain: proof.transcriptDomain,
            bodyLength: UInt32(bodyLength)
        )
        let expectedTraceDigest = SuperNeoSNARKStyleCompressionProof.recursiveVerifierTraceDigest(
            header: expectedHeader,
            sourceProofDigest: proof.sourceProofDigest,
            publicStatement: statement,
            accepted: true
        )
        guard proof.recursiveVerifierTraceDigest == expectedTraceDigest else {
            return .invalid("SNARK-style compression recursive verifier trace digest mismatch")
        }
        guard proof.terminalVerifierProof.sourceProofKind == proof.sourceProofKind,
              proof.terminalVerifierProof.sourceProofByteCount == proof.sourceProofByteCount,
              proof.terminalVerifierProof.sourceProofDigest == proof.sourceProofDigest,
              proof.terminalVerifierProof.profileID == proof.profileID,
              proof.terminalVerifierProof.shapeDigest == proof.shapeDigest,
              proof.terminalVerifierProof.statementDigest == proof.statementDigest,
              proof.terminalVerifierProof.verifierKeyDigest == proof.verifierKeyDigest,
              proof.terminalVerifierProof.transcriptDomain == proof.transcriptDomain else {
            return .invalid("SNARK-style terminal verifier relation mismatch")
        }
        return .valid
    }

    public static func verifyCompressionProof(
        _ proof: SuperNeoSNARKStyleCompressionProof,
        sourceProofBytes: [UInt8],
        publicInput: SuperNeoPublicFoldInput,
        verifierKey: AjtaiCommitmentKey,
        policy: SuperNeoTerminalProofAcceptancePolicy,
        parameters: SuperNeoParameters = .goldilocks,
        metalContext: MetalExecutionContext? = nil,
        executionPolicy: SuperNeoExecutionPolicy = .default
    ) -> VerificationResult {
        guard sourceProofBytes.count == proof.sourceProofByteCount else {
            return .invalid("SNARK-style compression source byte count mismatch")
        }
        guard Digest256.hash(sourceProofBytes) == proof.sourceProofDigest else {
            return .invalid("SNARK-style compression source digest mismatch")
        }
        let inputStatement = CCSStatement(
            shapeDigest: publicInput.shape.shapeDigest,
            ccsInstances: publicInput.instances,
            priorCEInstances: publicInput.priorClaims.map { CEInstance($0) },
            recursiveRelationDigest: publicInput.recursiveRelationDigest
        )
        guard proof.statementDigest == inputStatement.statementDigest else {
            return .invalid("SNARK-style compression source proof rejected: input statement digest mismatch")
        }
        let sourceVerification = SuperNeoVerifier(
            parameters: parameters,
            key: verifierKey,
            context: metalContext,
            executionPolicy: executionPolicy
        ).verifyTerminalProofEnvelope(
            publicInput: publicInput,
            proofBytes: sourceProofBytes,
            policy: policy
        )
        guard sourceVerification.isValid else {
            return .invalid(
                "SNARK-style compression source proof rejected: \(sourceVerification.reason ?? "unknown")"
            )
        }
        return verifyAcceptedCompressionProof(
            proof,
            publicInput: publicInput,
            verifierKeyDigest: verifierKey.verifierKeyDigest,
            policy: policy
        )
    }
}

private func encodeUInt16Local(_ value: UInt16) -> [UInt8] {
    withUnsafeBytes(of: value.littleEndian, Array.init)
}

private func encodeCountLocal(_ value: Int) -> [UInt8] {
    withUnsafeBytes(of: UInt64(value).littleEndian, Array.init)
}

private func encodeString(_ value: String) -> [UInt8] {
    let bytes = Array(value.utf8)
    return encodeCountLocal(bytes.count) + bytes
}
