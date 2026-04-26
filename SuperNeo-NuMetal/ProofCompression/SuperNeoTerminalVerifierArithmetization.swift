import Foundation

public struct SuperNeoTerminalVerifierArithmetizationProof: Equatable, Sendable, SuperNeoByteEncodable {
    public static let version: UInt16 = 1
    public static let domain = Digest256.hash("SuperNeo-NuMetal.terminal-verifier-arithmetization.v1")
    public static let relationTag = "terminal-verifier-relation/fold-plus-terminal-ce/v1"

    public let version: UInt16
    public let sourceProofKind: ProofEnvelopeKind
    public let sourceProofByteCount: Int
    public let sourceProofDigest: Digest256
    public let profileID: UInt16
    public let shapeDigest: Digest256
    public let statementDigest: Digest256
    public let verifierKeyDigest: Digest256
    public let transcriptDomain: Digest256
    public let publicInputDigest: Digest256
    public let terminalStatementDigest: Digest256
    public let foldProofDigest: Digest256
    public let ceOpeningProofDigest: Digest256
    public let compressedStatement: CompressedTerminalStatement?
    public let terminalStatement: TerminalCEStatement
    public let foldProof: FoldProof
    public let ceOpeningProof: CEOpeningProof
    public let relationDigest: Digest256
    public let terminalVerifierTraceDigest: Digest256
    public let residualDigest: Digest256
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
        publicInputDigest: Digest256,
        terminalStatementDigest: Digest256,
        foldProofDigest: Digest256,
        ceOpeningProofDigest: Digest256,
        compressedStatement: CompressedTerminalStatement?,
        terminalStatement: TerminalCEStatement,
        foldProof: FoldProof,
        ceOpeningProof: CEOpeningProof
    ) throws {
        guard sourceProofKind == .terminalLocal || sourceProofKind == .compressedPublic else {
            throw SuperNeoError.invalidParameter("terminal verifier arithmetization only accepts terminal proof sources")
        }
        guard sourceProofByteCount > ProofEnvelopeHeader.byteCount else {
            throw SuperNeoError.invalidParameter("terminal verifier source byte count must include a proof body")
        }
        guard terminalStatement.outputClaims == foldProof.outputClaims else {
            throw SuperNeoError.invalidParameter("terminal verifier relation statement must match fold output claims")
        }
        guard terminalStatement.profileID == profileID,
              terminalStatement.shapeDigest == shapeDigest,
              terminalStatement.verifierKeyDigest == verifierKeyDigest else {
            throw SuperNeoError.invalidParameter("terminal verifier relation statement context mismatch")
        }
        guard terminalStatement.statementDigest == terminalStatementDigest else {
            throw SuperNeoError.invalidParameter("terminal verifier relation terminal statement digest mismatch")
        }
        guard Digest256.hash(foldProof.superNeoBytes) == foldProofDigest else {
            throw SuperNeoError.invalidParameter("terminal verifier relation fold proof digest mismatch")
        }
        guard Digest256.hash(ceOpeningProof.superNeoBytes) == ceOpeningProofDigest else {
            throw SuperNeoError.invalidParameter("terminal verifier relation CE opening proof digest mismatch")
        }
        switch sourceProofKind {
        case .terminalLocal:
            guard compressedStatement == nil else {
                throw SuperNeoError.invalidParameter("terminal-local verifier relation must not include a compressed statement")
            }
        case .compressedPublic:
            guard let compressedStatement else {
                throw SuperNeoError.invalidParameter("compressed-public verifier relation requires a compressed statement")
            }
            guard compressedStatement.context.kind == .compressedPublic,
                  compressedStatement.context.profileID == profileID,
                  compressedStatement.context.shapeDigest == shapeDigest,
                  compressedStatement.context.statementDigest == statementDigest,
                  compressedStatement.context.verifierKeyDigest == verifierKeyDigest,
                  compressedStatement.context.transcriptDomain == transcriptDomain,
                  compressedStatement.publicInputDigest == publicInputDigest,
                  compressedStatement.terminalStatementDigest == terminalStatementDigest,
                  compressedStatement.verifierKeyDigest == verifierKeyDigest else {
                throw SuperNeoError.invalidParameter("compressed-public verifier relation statement mismatch")
            }
        case .foldReduction, .numiSealTerminal, .numiSealZK:
            throw SuperNeoError.invalidParameter("terminal verifier arithmetization only accepts terminal proof sources")
        }
        self.version = Self.version
        self.sourceProofKind = sourceProofKind
        self.sourceProofByteCount = sourceProofByteCount
        self.sourceProofDigest = sourceProofDigest
        self.profileID = profileID
        self.shapeDigest = shapeDigest
        self.statementDigest = statementDigest
        self.verifierKeyDigest = verifierKeyDigest
        self.transcriptDomain = transcriptDomain
        self.publicInputDigest = publicInputDigest
        self.terminalStatementDigest = terminalStatementDigest
        self.foldProofDigest = foldProofDigest
        self.ceOpeningProofDigest = ceOpeningProofDigest
        self.compressedStatement = compressedStatement
        self.terminalStatement = terminalStatement
        self.foldProof = foldProof
        self.ceOpeningProof = ceOpeningProof
        let relationDigest = Self.computeRelationDigest(
            sourceProofKind: sourceProofKind,
            profileID: profileID,
            shapeDigest: shapeDigest,
            statementDigest: statementDigest,
            verifierKeyDigest: verifierKeyDigest,
            transcriptDomain: transcriptDomain,
            publicInputDigest: publicInputDigest
        )
        self.relationDigest = relationDigest
        self.terminalVerifierTraceDigest = Self.computeTraceDigest(
            sourceProofKind: sourceProofKind,
            sourceProofByteCount: sourceProofByteCount,
            sourceProofDigest: sourceProofDigest,
            profileID: profileID,
            shapeDigest: shapeDigest,
            statementDigest: statementDigest,
            verifierKeyDigest: verifierKeyDigest,
            transcriptDomain: transcriptDomain,
            publicInputDigest: publicInputDigest,
            terminalStatementDigest: terminalStatementDigest,
            foldProofDigest: foldProofDigest,
            ceOpeningProofDigest: ceOpeningProofDigest,
            compressedStatement: compressedStatement,
            terminalStatement: terminalStatement,
            foldProof: foldProof,
            ceOpeningProof: ceOpeningProof
        )
        self.residualDigest = Self.computeResidualDigest(
            relationDigest: relationDigest,
            terminalVerifierTraceDigest: terminalVerifierTraceDigest
        )
        self.proofDigest = Self.computeProofDigest(
            version: Self.version,
            sourceProofKind: sourceProofKind,
            sourceProofByteCount: sourceProofByteCount,
            sourceProofDigest: sourceProofDigest,
            profileID: profileID,
            shapeDigest: shapeDigest,
            statementDigest: statementDigest,
            verifierKeyDigest: verifierKeyDigest,
            transcriptDomain: transcriptDomain,
            publicInputDigest: publicInputDigest,
            terminalStatementDigest: terminalStatementDigest,
            foldProofDigest: foldProofDigest,
            ceOpeningProofDigest: ceOpeningProofDigest,
            compressedStatement: compressedStatement,
            terminalStatement: terminalStatement,
            foldProof: foldProof,
            ceOpeningProof: ceOpeningProof,
            relationDigest: relationDigest,
            terminalVerifierTraceDigest: terminalVerifierTraceDigest,
            residualDigest: residualDigest
        )
    }

    public var superNeoBytes: [UInt8] {
        Self.domain.superNeoBytes
            + Self.bodyBytes(
                version: version,
                sourceProofKind: sourceProofKind,
                sourceProofByteCount: sourceProofByteCount,
                sourceProofDigest: sourceProofDigest,
                profileID: profileID,
                shapeDigest: shapeDigest,
                statementDigest: statementDigest,
                verifierKeyDigest: verifierKeyDigest,
                transcriptDomain: transcriptDomain,
                publicInputDigest: publicInputDigest,
                terminalStatementDigest: terminalStatementDigest,
                foldProofDigest: foldProofDigest,
                ceOpeningProofDigest: ceOpeningProofDigest,
                compressedStatement: compressedStatement,
                terminalStatement: terminalStatement,
                foldProof: foldProof,
                ceOpeningProof: ceOpeningProof,
                relationDigest: relationDigest,
                terminalVerifierTraceDigest: terminalVerifierTraceDigest,
                residualDigest: residualDigest
            )
            + proofDigest.superNeoBytes
    }

    public func hasValidDigest() -> Bool {
        relationDigest == Self.computeRelationDigest(
            sourceProofKind: sourceProofKind,
            profileID: profileID,
            shapeDigest: shapeDigest,
            statementDigest: statementDigest,
            verifierKeyDigest: verifierKeyDigest,
            transcriptDomain: transcriptDomain,
            publicInputDigest: publicInputDigest
        )
        && terminalVerifierTraceDigest == Self.computeTraceDigest(
            sourceProofKind: sourceProofKind,
            sourceProofByteCount: sourceProofByteCount,
            sourceProofDigest: sourceProofDigest,
            profileID: profileID,
            shapeDigest: shapeDigest,
            statementDigest: statementDigest,
            verifierKeyDigest: verifierKeyDigest,
            transcriptDomain: transcriptDomain,
            publicInputDigest: publicInputDigest,
            terminalStatementDigest: terminalStatementDigest,
            foldProofDigest: foldProofDigest,
            ceOpeningProofDigest: ceOpeningProofDigest,
            compressedStatement: compressedStatement,
            terminalStatement: terminalStatement,
            foldProof: foldProof,
            ceOpeningProof: ceOpeningProof
        )
        && residualDigest == Self.computeResidualDigest(
            relationDigest: relationDigest,
            terminalVerifierTraceDigest: terminalVerifierTraceDigest
        )
        && proofDigest == Self.computeProofDigest(
            version: version,
            sourceProofKind: sourceProofKind,
            sourceProofByteCount: sourceProofByteCount,
            sourceProofDigest: sourceProofDigest,
            profileID: profileID,
            shapeDigest: shapeDigest,
            statementDigest: statementDigest,
            verifierKeyDigest: verifierKeyDigest,
            transcriptDomain: transcriptDomain,
            publicInputDigest: publicInputDigest,
            terminalStatementDigest: terminalStatementDigest,
            foldProofDigest: foldProofDigest,
            ceOpeningProofDigest: ceOpeningProofDigest,
            compressedStatement: compressedStatement,
            terminalStatement: terminalStatement,
            foldProof: foldProof,
            ceOpeningProof: ceOpeningProof,
            relationDigest: relationDigest,
            terminalVerifierTraceDigest: terminalVerifierTraceDigest,
            residualDigest: residualDigest
        )
    }

    public static func make(
        publicInput: SuperNeoPublicFoldInput,
        proofBytes: [UInt8],
        policy: SuperNeoTerminalProofAcceptancePolicy,
        parameters: SuperNeoParameters = .goldilocks
    ) throws -> Self {
        let header = try ProofEnvelopeHeader.parsePrefix(from: proofBytes)
        _ = try policy.context(for: header, totalByteCount: proofBytes.count)
        let publicInputDigest = terminalVerifierPublicInputDigest(publicInput)
        switch header.kind {
        case .terminalLocal:
            let envelope = try TerminalFoldProofEnvelope(bytes: proofBytes, parameters: parameters)
            return try Self(
                sourceProofKind: header.kind,
                sourceProofByteCount: proofBytes.count,
                sourceProofDigest: Digest256.hash(proofBytes),
                profileID: header.profileID,
                shapeDigest: header.shapeDigest,
                statementDigest: header.statementDigest,
                verifierKeyDigest: header.verifierKeyDigest,
                transcriptDomain: header.transcriptDomain,
                publicInputDigest: publicInputDigest,
                terminalStatementDigest: envelope.proof.terminalStatement.statementDigest,
                foldProofDigest: Digest256.hash(envelope.proof.foldProof.superNeoBytes),
                ceOpeningProofDigest: Digest256.hash(envelope.proof.ceOpeningProof.superNeoBytes),
                compressedStatement: nil,
                terminalStatement: envelope.proof.terminalStatement,
                foldProof: envelope.proof.foldProof,
                ceOpeningProof: envelope.proof.ceOpeningProof
            )
        case .compressedPublic:
            let envelope = try CompressedTerminalProofEnvelope(bytes: proofBytes, parameters: parameters)
            let terminalStatement = try TerminalCEStatement(
                profileID: header.profileID,
                shapeDigest: header.shapeDigest,
                verifierKeyDigest: header.verifierKeyDigest,
                claims: envelope.proof.foldProof.outputClaims
            )
            return try Self(
                sourceProofKind: header.kind,
                sourceProofByteCount: proofBytes.count,
                sourceProofDigest: Digest256.hash(proofBytes),
                profileID: header.profileID,
                shapeDigest: header.shapeDigest,
                statementDigest: header.statementDigest,
                verifierKeyDigest: header.verifierKeyDigest,
                transcriptDomain: header.transcriptDomain,
                publicInputDigest: terminalVerifierCompressedPublicInputDigest(publicInput),
                terminalStatementDigest: terminalStatement.statementDigest,
                foldProofDigest: envelope.proof.foldProofDigest,
                ceOpeningProofDigest: envelope.proof.ceOpeningProofDigest,
                compressedStatement: envelope.proof.statement,
                terminalStatement: terminalStatement,
                foldProof: envelope.proof.foldProof,
                ceOpeningProof: envelope.proof.ceOpeningProof
            )
        case .foldReduction, .numiSealTerminal, .numiSealZK:
            throw SuperNeoError.invalidParameter("terminal verifier arithmetization source must be terminal or compressed-public")
        }
    }

    public func verifySourceFree(
        publicInput: SuperNeoPublicFoldInput,
        verifierKey: AjtaiCommitmentKey,
        policy: SuperNeoTerminalProofAcceptancePolicy,
        parameters: SuperNeoParameters = .goldilocks,
        metalContext: MetalExecutionContext? = nil,
        executionPolicy: SuperNeoExecutionPolicy = .default
    ) -> VerificationResult {
        do {
            guard version == Self.version else {
                return .invalid("unsupported terminal verifier arithmetization proof version")
            }
            guard hasValidDigest() else {
                return .invalid("terminal verifier arithmetization digest mismatch")
            }
            guard profileID == policy.profileID,
                  shapeDigest == policy.shapeDigest,
                  statementDigest == policy.statementDigest,
                  verifierKeyDigest == policy.verifierKeyDigest,
                  transcriptDomain == policy.transcriptDomain else {
                return .invalid("terminal verifier arithmetization policy mismatch")
            }
            guard verifierKeyDigest == verifierKey.verifierKeyDigest,
                  verifierKey.parameters == parameters else {
                return .invalid("terminal verifier arithmetization verifier key mismatch")
            }
            guard policy.proofKindPolicy.accepts(sourceProofKind) else {
                return .invalid("terminal verifier arithmetization proof kind not accepted")
            }
            let statement = CCSStatement(
                shapeDigest: publicInput.shape.shapeDigest,
                ccsInstances: publicInput.instances,
                priorCEInstances: publicInput.priorClaims.map(CEInstance.init),
                recursiveRelationDigest: publicInput.recursiveRelationDigest
            )
            guard statement.shapeDigest == shapeDigest,
                  statement.statementDigest == statementDigest else {
                return .invalid("terminal verifier arithmetization public statement mismatch")
            }
            guard terminalStatement.outputClaims == foldProof.outputClaims else {
                return .invalid("terminal verifier arithmetization statement/output mismatch")
            }

            let sourceBytes = try canonicalSourceEnvelopeBytes()
            guard sourceBytes.count == sourceProofByteCount else {
                return .invalid("terminal verifier arithmetization source byte count mismatch")
            }
            guard Digest256.hash(sourceBytes) == sourceProofDigest else {
                return .invalid("terminal verifier arithmetization source digest mismatch")
            }

            let verifier = SuperNeoVerifier(
                parameters: parameters,
                key: verifierKey,
                context: metalContext,
                executionPolicy: executionPolicy
            )
            let result: VerificationResult
            switch sourceProofKind {
            case .terminalLocal:
                guard publicInputDigest == terminalVerifierPublicInputDigest(publicInput) else {
                    return .invalid("terminal verifier arithmetization public input digest mismatch")
                }
                let proof = TerminalFoldProof(
                    foldProof: foldProof,
                    terminalStatement: terminalStatement,
                    ceOpeningProof: ceOpeningProof
                )
                let context = ProofEnvelopeContext(
                    profileID: profileID,
                    kind: .terminalLocal,
                    shapeDigest: shapeDigest,
                    statementDigest: statementDigest,
                    verifierKeyDigest: verifierKeyDigest,
                    transcriptDomain: transcriptDomain
                )
                result = verifier.verifyTerminalFold(
                    publicInput: publicInput,
                    proof: proof,
                    transcriptSeed: context.transcriptBindingBytes
                )
            case .compressedPublic:
                guard publicInputDigest == terminalVerifierCompressedPublicInputDigest(publicInput) else {
                    return .invalid("terminal verifier arithmetization compressed public input digest mismatch")
                }
                guard let compressedStatement else {
                    return .invalid("terminal verifier arithmetization compressed statement missing")
                }
                guard compressedStatement.publicInputDigest == terminalVerifierCompressedPublicInputDigest(publicInput),
                      compressedStatement.terminalStatementDigest == terminalStatementDigest,
                      compressedStatement.verifierKeyDigest == verifierKeyDigest else {
                    return .invalid("terminal verifier arithmetization compressed statement mismatch")
                }
                let terminalContext = ProofEnvelopeContext(
                    profileID: profileID,
                    kind: .terminalLocal,
                    shapeDigest: shapeDigest,
                    statementDigest: statementDigest,
                    verifierKeyDigest: verifierKeyDigest,
                    transcriptDomain: transcriptDomain
                )
                let proof = TerminalFoldProof(
                    foldProof: foldProof,
                    terminalStatement: terminalStatement,
                    ceOpeningProof: ceOpeningProof
                )
                result = verifier.verifyTerminalFold(
                    publicInput: publicInput,
                    proof: proof,
                    transcriptSeed: terminalContext.transcriptBindingBytes
                )
            case .foldReduction, .numiSealTerminal, .numiSealZK:
                return .invalid("terminal verifier arithmetization proof kind not accepted")
            }
            guard result.isValid else {
                return .invalid("terminal verifier arithmetized relation rejected: \(result.reason ?? "unknown")")
            }
            return .valid
        } catch {
            return .invalid("\(error)")
        }
    }

    public func canonicalSourceEnvelopeBytes() throws -> [UInt8] {
        switch sourceProofKind {
        case .terminalLocal:
            let context = ProofEnvelopeContext(
                profileID: profileID,
                kind: .terminalLocal,
                shapeDigest: shapeDigest,
                statementDigest: statementDigest,
                verifierKeyDigest: verifierKeyDigest,
                transcriptDomain: transcriptDomain
            )
            let proof = TerminalFoldProof(
                foldProof: foldProof,
                terminalStatement: terminalStatement,
                ceOpeningProof: ceOpeningProof
            )
            return try TerminalFoldProofEnvelope(context: context, proof: proof).superNeoBytes
        case .compressedPublic:
            guard let compressedStatement else {
                throw SuperNeoError.invalidParameter("compressed-public relation missing compressed statement")
            }
            let context = ProofEnvelopeContext(
                profileID: profileID,
                kind: .compressedPublic,
                shapeDigest: shapeDigest,
                statementDigest: statementDigest,
                verifierKeyDigest: verifierKeyDigest,
                transcriptDomain: transcriptDomain
            )
            let compressedProof = CompressedTerminalProof(
                statement: compressedStatement,
                foldProof: foldProof,
                ceOpeningProof: ceOpeningProof
            )
            return try CompressedTerminalProofEnvelope(context: context, proof: compressedProof).superNeoBytes
        case .foldReduction, .numiSealTerminal, .numiSealZK:
            throw SuperNeoError.invalidParameter("terminal verifier arithmetization source must be terminal or compressed-public")
        }
    }

    private static func computeRelationDigest(
        sourceProofKind: ProofEnvelopeKind,
        profileID: UInt16,
        shapeDigest: Digest256,
        statementDigest: Digest256,
        verifierKeyDigest: Digest256,
        transcriptDomain: Digest256,
        publicInputDigest: Digest256
    ) -> Digest256 {
        Digest256.hash(
            Self.domain.superNeoBytes
                + terminalVerifierEncodeString(Self.relationTag)
                + [sourceProofKind.rawValue]
                + terminalVerifierEncodeUInt16(profileID)
                + shapeDigest.superNeoBytes
                + statementDigest.superNeoBytes
                + verifierKeyDigest.superNeoBytes
                + transcriptDomain.superNeoBytes
                + publicInputDigest.superNeoBytes
        )
    }

    private static func computeTraceDigest(
        sourceProofKind: ProofEnvelopeKind,
        sourceProofByteCount: Int,
        sourceProofDigest: Digest256,
        profileID: UInt16,
        shapeDigest: Digest256,
        statementDigest: Digest256,
        verifierKeyDigest: Digest256,
        transcriptDomain: Digest256,
        publicInputDigest: Digest256,
        terminalStatementDigest: Digest256,
        foldProofDigest: Digest256,
        ceOpeningProofDigest: Digest256,
        compressedStatement: CompressedTerminalStatement?,
        terminalStatement: TerminalCEStatement,
        foldProof: FoldProof,
        ceOpeningProof: CEOpeningProof
    ) -> Digest256 {
        Digest256.hash(
            Self.domain.superNeoBytes
                + terminalVerifierEncodeString("trace")
                + [sourceProofKind.rawValue]
                + terminalVerifierEncodeCount(sourceProofByteCount)
                + sourceProofDigest.superNeoBytes
                + terminalVerifierEncodeUInt16(profileID)
                + shapeDigest.superNeoBytes
                + statementDigest.superNeoBytes
                + verifierKeyDigest.superNeoBytes
                + transcriptDomain.superNeoBytes
                + publicInputDigest.superNeoBytes
                + terminalStatementDigest.superNeoBytes
                + foldProofDigest.superNeoBytes
                + ceOpeningProofDigest.superNeoBytes
                + (compressedStatement.map { [UInt8(1)] + $0.statementDigest.superNeoBytes + $0.superNeoBytes } ?? [UInt8(0)])
                + terminalStatement.superNeoBytes
                + foldProof.superNeoBytes
                + ceOpeningProof.superNeoBytes
        )
    }

    private static func computeResidualDigest(
        relationDigest: Digest256,
        terminalVerifierTraceDigest: Digest256
    ) -> Digest256 {
        Digest256.hash(
            Self.domain.superNeoBytes
                + terminalVerifierEncodeString("residual-zero")
                + relationDigest.superNeoBytes
                + terminalVerifierTraceDigest.superNeoBytes
        )
    }

    private static func computeProofDigest(
        version: UInt16,
        sourceProofKind: ProofEnvelopeKind,
        sourceProofByteCount: Int,
        sourceProofDigest: Digest256,
        profileID: UInt16,
        shapeDigest: Digest256,
        statementDigest: Digest256,
        verifierKeyDigest: Digest256,
        transcriptDomain: Digest256,
        publicInputDigest: Digest256,
        terminalStatementDigest: Digest256,
        foldProofDigest: Digest256,
        ceOpeningProofDigest: Digest256,
        compressedStatement: CompressedTerminalStatement?,
        terminalStatement: TerminalCEStatement,
        foldProof: FoldProof,
        ceOpeningProof: CEOpeningProof,
        relationDigest: Digest256,
        terminalVerifierTraceDigest: Digest256,
        residualDigest: Digest256
    ) -> Digest384 {
        Digest384.shake256(
            Self.domain.superNeoBytes
                + bodyBytes(
                    version: version,
                    sourceProofKind: sourceProofKind,
                    sourceProofByteCount: sourceProofByteCount,
                    sourceProofDigest: sourceProofDigest,
                    profileID: profileID,
                    shapeDigest: shapeDigest,
                    statementDigest: statementDigest,
                    verifierKeyDigest: verifierKeyDigest,
                    transcriptDomain: transcriptDomain,
                    publicInputDigest: publicInputDigest,
                    terminalStatementDigest: terminalStatementDigest,
                    foldProofDigest: foldProofDigest,
                    ceOpeningProofDigest: ceOpeningProofDigest,
                    compressedStatement: compressedStatement,
                    terminalStatement: terminalStatement,
                    foldProof: foldProof,
                    ceOpeningProof: ceOpeningProof,
                    relationDigest: relationDigest,
                    terminalVerifierTraceDigest: terminalVerifierTraceDigest,
                    residualDigest: residualDigest
                )
        )
    }

    private static func bodyBytes(
        version: UInt16,
        sourceProofKind: ProofEnvelopeKind,
        sourceProofByteCount: Int,
        sourceProofDigest: Digest256,
        profileID: UInt16,
        shapeDigest: Digest256,
        statementDigest: Digest256,
        verifierKeyDigest: Digest256,
        transcriptDomain: Digest256,
        publicInputDigest: Digest256,
        terminalStatementDigest: Digest256,
        foldProofDigest: Digest256,
        ceOpeningProofDigest: Digest256,
        compressedStatement: CompressedTerminalStatement?,
        terminalStatement: TerminalCEStatement,
        foldProof: FoldProof,
        ceOpeningProof: CEOpeningProof,
        relationDigest: Digest256,
        terminalVerifierTraceDigest: Digest256,
        residualDigest: Digest256
    ) -> [UInt8] {
        terminalVerifierEncodeUInt16(version)
            + [sourceProofKind.rawValue]
            + terminalVerifierEncodeCount(sourceProofByteCount)
            + sourceProofDigest.superNeoBytes
            + terminalVerifierEncodeUInt16(profileID)
            + shapeDigest.superNeoBytes
            + statementDigest.superNeoBytes
            + verifierKeyDigest.superNeoBytes
            + transcriptDomain.superNeoBytes
            + publicInputDigest.superNeoBytes
            + terminalStatementDigest.superNeoBytes
            + foldProofDigest.superNeoBytes
            + ceOpeningProofDigest.superNeoBytes
            + (compressedStatement.map { [UInt8(1)] + $0.superNeoBytes } ?? [UInt8(0)])
            + terminalStatement.superNeoBytes
            + foldProof.superNeoBytes
            + ceOpeningProof.superNeoBytes
            + relationDigest.superNeoBytes
            + terminalVerifierTraceDigest.superNeoBytes
            + residualDigest.superNeoBytes
    }
}

func terminalVerifierPublicInputDigest(_ input: SuperNeoPublicFoldInput) -> Digest256 {
    Digest256.hash(
        Array("SuperNeo-NuMetal.terminal-verifier.public-input.v1".utf8)
            + input.shape.shapeDigest.superNeoBytes
            + terminalVerifierEncodeCount(input.instances.count)
            + input.instances.flatMap(\.superNeoBytes)
            + terminalVerifierEncodeCount(input.priorClaims.count)
            + input.priorClaims.flatMap(\.superNeoBytes)
            + (input.recursiveRelationDigest.map { [UInt8(1)] + $0.superNeoBytes } ?? [UInt8(0)])
    )
}

func terminalVerifierCompressedPublicInputDigest(_ input: SuperNeoPublicFoldInput) -> Digest256 {
    Digest256.hash(
        Array("SuperNeo-NuMetal.compressed-public.input.v1".utf8)
            + input.shape.shapeDigest.superNeoBytes
            + terminalVerifierEncodeCount(input.instances.count)
            + input.instances.flatMap(\.superNeoBytes)
            + terminalVerifierEncodeCount(input.priorClaims.count)
            + input.priorClaims.flatMap(\.superNeoBytes)
    )
}

func terminalVerifierEncodeCount(_ value: Int) -> [UInt8] {
    withUnsafeBytes(of: UInt64(value).littleEndian, Array.init)
}

private func terminalVerifierEncodeUInt16(_ value: UInt16) -> [UInt8] {
    withUnsafeBytes(of: value.littleEndian, Array.init)
}

private func terminalVerifierEncodeString(_ value: String) -> [UInt8] {
    let bytes = Array(value.utf8)
    return terminalVerifierEncodeCount(bytes.count) + bytes
}
