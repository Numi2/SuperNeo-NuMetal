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

public struct SuperNeoProductProofIdentity: Equatable, Hashable, Sendable {
    public let expectedContextID: String
    public let statementDigest: Digest256
    public let proofEnvelopeDigest: Digest256
    public let artifactDigest: Digest256
    public let provenanceDigest: Digest256
    public let issuedQROChallengeDigest: Digest256?
    public let recursiveCarryReplayBindingDigest: Digest256?

    public init(
        expectedContextID: String,
        statementDigest: Digest256,
        proofEnvelopeDigest: Digest256,
        artifactDigest: Digest256,
        provenanceDigest: Digest256,
        issuedQROChallengeDigest: Digest256? = nil,
        recursiveCarryReplayBindingDigest: Digest256? = nil
    ) {
        self.expectedContextID = expectedContextID
        self.statementDigest = statementDigest
        self.proofEnvelopeDigest = proofEnvelopeDigest
        self.artifactDigest = artifactDigest
        self.provenanceDigest = provenanceDigest
        self.issuedQROChallengeDigest = issuedQROChallengeDigest
        self.recursiveCarryReplayBindingDigest = recursiveCarryReplayBindingDigest
    }
}

public protocol SuperNeoReplayLedger {
    func hasAccepted(_ identity: SuperNeoProductProofIdentity) throws -> Bool
    func recordAccepted(_ identity: SuperNeoProductProofIdentity) throws
}
