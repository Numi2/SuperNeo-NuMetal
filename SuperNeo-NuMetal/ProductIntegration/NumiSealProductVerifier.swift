import Foundation

public enum SuperNeoProductIntegrationError: Error, Equatable, CustomStringConvertible {
    case invalidRequest(String)
    case unauthorized(String)
    case missingExpectedContext(String)
    case provenanceRejected(String)
    case replayDetected(String)
    case verificationFailed(String)

    public var description: String {
        switch self {
        case .invalidRequest(let message),
             .unauthorized(let message),
             .missingExpectedContext(let message),
             .provenanceRejected(let message),
             .replayDetected(let message),
             .verificationFailed(let message):
            return message
        }
    }
}

public struct SuperNeoNumiSealProductVerificationRequest: Equatable, Sendable {
    public let callerID: String
    public let expectedContextID: String
    public let artifact: NumiSealArtifact
    public let artifactBytes: [UInt8]
    public let maximumArtifactByteCount: Int?

    public init(
        callerID: String,
        expectedContextID: String,
        artifact: NumiSealArtifact,
        artifactBytes: [UInt8],
        maximumArtifactByteCount: Int? = nil
    ) {
        self.callerID = callerID
        self.expectedContextID = expectedContextID
        self.artifact = artifact
        self.artifactBytes = artifactBytes
        self.maximumArtifactByteCount = maximumArtifactByteCount
    }

    public var artifactDigest: Digest256 {
        Digest256.hash(artifactBytes)
    }
}

public struct SuperNeoProductProofIdentity: Equatable, Hashable, Sendable {
    public let expectedContextID: String
    public let statementDigest: Digest256
    public let proofEnvelopeDigest: Digest256
    public let artifactDigest: Digest256
    public let provenanceDigest: Digest256
    public let recursiveCarryReplayBindingDigest: Digest256?

    public init(
        expectedContextID: String,
        statementDigest: Digest256,
        proofEnvelopeDigest: Digest256,
        artifactDigest: Digest256,
        provenanceDigest: Digest256,
        recursiveCarryReplayBindingDigest: Digest256? = nil
    ) {
        self.expectedContextID = expectedContextID
        self.statementDigest = statementDigest
        self.proofEnvelopeDigest = proofEnvelopeDigest
        self.artifactDigest = artifactDigest
        self.provenanceDigest = provenanceDigest
        self.recursiveCarryReplayBindingDigest = recursiveCarryReplayBindingDigest
    }
}

public enum SuperNeoProductAuditDecision: Equatable, Sendable {
    case accepted
    case rejected
}

public struct SuperNeoProductVerificationAuditEvent: Equatable, Sendable {
    public let callerID: String
    public let expectedContextID: String
    public let artifactDigest: Digest256
    public let proofEnvelopeDigest: Digest256?
    public let provenanceDigest: Digest256?
    public let recursiveCarryReplayBindingDigest: Digest256?
    public let decision: SuperNeoProductAuditDecision
    public let reason: String?

    public init(
        callerID: String,
        expectedContextID: String,
        artifactDigest: Digest256,
        proofEnvelopeDigest: Digest256?,
        provenanceDigest: Digest256?,
        recursiveCarryReplayBindingDigest: Digest256? = nil,
        decision: SuperNeoProductAuditDecision,
        reason: String?
    ) {
        self.callerID = callerID
        self.expectedContextID = expectedContextID
        self.artifactDigest = artifactDigest
        self.proofEnvelopeDigest = proofEnvelopeDigest
        self.provenanceDigest = provenanceDigest
        self.recursiveCarryReplayBindingDigest = recursiveCarryReplayBindingDigest
        self.decision = decision
        self.reason = reason
    }
}

public protocol SuperNeoNumiSealExpectedContextStore {
    func expectedContext(for request: SuperNeoNumiSealProductVerificationRequest) throws -> NumiSealArtifactExpectedContext
}

public protocol SuperNeoProductAuthorizer {
    func authorize(_ request: SuperNeoNumiSealProductVerificationRequest) throws
}

public protocol SuperNeoArtifactProvenanceVerifier {
    func verifyProvenance(
        for request: SuperNeoNumiSealProductVerificationRequest,
        artifactDigest: Digest256
    ) throws -> Digest256
}

public protocol SuperNeoReplayLedger {
    func hasAccepted(_ identity: SuperNeoProductProofIdentity) throws -> Bool
    func recordAccepted(_ identity: SuperNeoProductProofIdentity) throws
}

public protocol SuperNeoVerificationAuditSink {
    func record(_ event: SuperNeoProductVerificationAuditEvent)
}

public struct SuperNeoNumiSealProductVerificationReport: Equatable, Sendable {
    public let identity: SuperNeoProductProofIdentity
    public let artifactDigest: Digest256
    public let innerReport: NumiSealArtifactVerificationReport

    public init(
        identity: SuperNeoProductProofIdentity,
        artifactDigest: Digest256,
        innerReport: NumiSealArtifactVerificationReport
    ) {
        self.identity = identity
        self.artifactDigest = artifactDigest
        self.innerReport = innerReport
    }
}

public struct SuperNeoNumiSealProductVerifier {
    public let expectedContextStore: SuperNeoNumiSealExpectedContextStore
    public let authorizer: SuperNeoProductAuthorizer
    public let provenanceVerifier: SuperNeoArtifactProvenanceVerifier
    public let replayLedger: SuperNeoReplayLedger
    public let auditSink: SuperNeoVerificationAuditSink
    public let parameters: SuperNeoParameters
    public let executionPolicy: SuperNeoExecutionPolicy

    public init(
        expectedContextStore: SuperNeoNumiSealExpectedContextStore,
        authorizer: SuperNeoProductAuthorizer,
        provenanceVerifier: SuperNeoArtifactProvenanceVerifier,
        replayLedger: SuperNeoReplayLedger,
        auditSink: SuperNeoVerificationAuditSink,
        parameters: SuperNeoParameters = .goldilocks,
        executionPolicy: SuperNeoExecutionPolicy = .highAssurance
    ) {
        self.expectedContextStore = expectedContextStore
        self.authorizer = authorizer
        self.provenanceVerifier = provenanceVerifier
        self.replayLedger = replayLedger
        self.auditSink = auditSink
        self.parameters = parameters
        self.executionPolicy = executionPolicy
    }

    public func verify(
        _ request: SuperNeoNumiSealProductVerificationRequest
    ) throws -> SuperNeoNumiSealProductVerificationReport {
        let artifactDigest = request.artifactDigest
        var proofEnvelopeDigest: Digest256?
        var provenanceDigest: Digest256?

        do {
            try validateRequest(request)
            let proofBytes = try request.artifact.proofEnvelopeBytes()
            let proofBytesDigest = Digest256.hash(proofBytes)
            proofEnvelopeDigest = proofBytesDigest

            try NumiSealArtifactVerifier.validateMetadata(request.artifact)
            try authorizer.authorize(request)
            let expectedContext = try expectedContextStore.expectedContext(for: request)
            let verifiedProvenanceDigest = try provenanceVerifier.verifyProvenance(
                for: request,
                artifactDigest: artifactDigest
            )
            provenanceDigest = verifiedProvenanceDigest

            let statementDigest = try Digest256(
                hexDigest: request.artifact.statementDigestHex,
                name: "NumiSeal product statement digest"
            )
            let identity = SuperNeoProductProofIdentity(
                expectedContextID: request.expectedContextID,
                statementDigest: statementDigest,
                proofEnvelopeDigest: proofBytesDigest,
                artifactDigest: artifactDigest,
                provenanceDigest: verifiedProvenanceDigest
            )
            guard try !replayLedger.hasAccepted(identity) else {
                throw SuperNeoProductIntegrationError.replayDetected(
                    "proof identity has already been accepted"
                )
            }

            let innerReport = try NumiSealArtifactVerifier.verify(
                artifact: request.artifact,
                expectedContext: expectedContext,
                parameters: parameters,
                executionPolicy: executionPolicy
            )
            try replayLedger.recordAccepted(identity)

            auditSink.record(
                SuperNeoProductVerificationAuditEvent(
                    callerID: request.callerID,
                    expectedContextID: request.expectedContextID,
                    artifactDigest: artifactDigest,
                    proofEnvelopeDigest: proofEnvelopeDigest,
                    provenanceDigest: provenanceDigest,
                    decision: .accepted,
                    reason: nil
                )
            )
            return SuperNeoNumiSealProductVerificationReport(
                identity: identity,
                artifactDigest: artifactDigest,
                innerReport: innerReport
            )
        } catch {
            auditSink.record(
                SuperNeoProductVerificationAuditEvent(
                    callerID: request.callerID,
                    expectedContextID: request.expectedContextID,
                    artifactDigest: artifactDigest,
                    proofEnvelopeDigest: proofEnvelopeDigest,
                    provenanceDigest: provenanceDigest,
                    decision: .rejected,
                    reason: String(describing: error)
                )
            )
            throw error
        }
    }

    private func validateRequest(_ request: SuperNeoNumiSealProductVerificationRequest) throws {
        guard !request.callerID.isEmpty else {
            throw SuperNeoProductIntegrationError.invalidRequest("caller ID is required")
        }
        guard !request.expectedContextID.isEmpty else {
            throw SuperNeoProductIntegrationError.invalidRequest("expected context ID is required")
        }
        guard !request.artifactBytes.isEmpty else {
            throw SuperNeoProductIntegrationError.invalidRequest("artifact bytes are required")
        }
        if let maximumArtifactByteCount = request.maximumArtifactByteCount {
            guard maximumArtifactByteCount > 0 else {
                throw SuperNeoProductIntegrationError.invalidRequest(
                    "maximum artifact byte count must be positive"
                )
            }
            guard request.artifactBytes.count <= maximumArtifactByteCount else {
                throw SuperNeoProductIntegrationError.invalidRequest(
                    "artifact byte count exceeds product maximum"
                )
            }
        }
    }
}
