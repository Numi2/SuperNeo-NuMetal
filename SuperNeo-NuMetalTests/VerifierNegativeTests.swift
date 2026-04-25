import Foundation
import XCTest
@_spi(Benchmarking) @testable import SuperNeo_NuMetal

final class VerifierNegativeTests: XCTestCase {
    func testNumiSealArtifactVerifierRejectsMutatedArtifactPins() throws {
        let artifact = try loadNumiSealArtifact(named: "numiseal-terminal-single-aggregate-v1.json")
        let context = try strictExpectedContext(for: artifact)
        let wrongDigest = Digest256.hash("verifier-negative-wrong-digest").hexString
        var wrongPublicInputs = artifact.publicInputs
        wrongPublicInputs[0] ^= 1

        try assertRejects(
            copyArtifact(artifact, publicInputs: wrongPublicInputs),
            context: context,
            containing: "expected public inputs"
        )
        try assertRejects(
            copyArtifact(artifact, verifierKeyDigestHex: wrongDigest),
            context: context,
            containing: "CTCO context binder"
        )
        try assertRejects(
            copyArtifact(artifact, transcriptDomainHex: wrongDigest),
            context: context,
            containing: "CTCO context binder"
        )
        try assertRejects(
            copyArtifact(artifact, aggregateDigestsHex: [wrongDigest]),
            context: context,
            containing: "aggregate digest"
        )
        try assertRejects(
            copyArtifact(artifact, laneIDsUTF8: ["product-swapped"]),
            context: context,
            containing: "public statement"
        )
        try assertRejects(
            copyArtifact(artifact, proofKind: "numiseal-zk"),
            context: context,
            containing: "proof kind"
        )
        try assertRejects(
            copyArtifact(artifact, publicInputCount: artifact.publicInputCount + 1),
            context: context,
            containing: "public input count mismatch"
        )
    }

    func testNumiSealArtifactVerifierRejectsProofEnvelopeKindLengthAndBitFlips() throws {
        let artifact = try loadNumiSealArtifact(named: "numiseal-terminal-single-aggregate-v1.json")
        let context = try strictExpectedContext(for: artifact)
        let proofBytes = try artifact.proofEnvelopeBytes()

        var wrongKind = proofBytes
        wrongKind[8] = ProofEnvelopeKind.numiSealZK.rawValue
        try assertRejects(
            copyArtifact(artifact, proofEnvelopeBase64: Data(wrongKind).base64EncodedString()),
            context: context,
            containing: "kind"
        )

        var wrongLength = proofBytes
        writeUInt32(UInt32(proofBytes.count - ProofEnvelopeHeader.byteCount + 1), into: &wrongLength, at: ProofEnvelopeHeader.byteCount - 4)
        try assertRejects(
            copyArtifact(artifact, proofEnvelopeBase64: Data(wrongLength).base64EncodedString()),
            context: context,
            containing: "length"
        )

        for offset in bitFlipOffsets(for: proofBytes) {
            var mutated = proofBytes
            mutated[offset] ^= 0x01
            try assertRejects(
                copyArtifact(artifact, proofEnvelopeBase64: Data(mutated).base64EncodedString()),
                context: context,
                containing: nil,
                file: #filePath,
                line: #line
            )
        }
    }

    func testProductVerifierRejectsDuplicateAndUnknownJSONKeysBeforeAcceptance() throws {
        let artifact = try loadNumiSealArtifact(named: "numiseal-terminal-single-aggregate-v1.json")
        let duplicateKeyBytes = Data(#"{"artifactVersion":1,"artifactVersion":1}"#.utf8)
        let unknownKeyBytes = Data(#"{"unexpectedVerifierBypass":true}"#.utf8)

        let duplicateVerifier = SuperNeoNumiSealProductVerifier(
            expectedContextStore: NegativeExpectedContextStore(expectedContext: try strictExpectedContext(for: artifact)),
            authorizer: NegativeAuthorizer(),
            provenanceVerifier: NegativeProvenanceVerifier(),
            replayLedger: NegativeReplayLedger(),
            auditSink: NegativeAuditSink()
        )
        XCTAssertThrowsError(
            try duplicateVerifier.verify(
                SuperNeoNumiSealProductVerificationRequest(
                    callerID: "tenant-negative",
                    expectedContextID: "ctx-negative",
                    artifact: artifact,
                    artifactBytes: [UInt8](duplicateKeyBytes)
                )
            )
        ) { error in
            XCTAssertTrue(String(describing: error).contains("duplicate JSON key"))
        }

        let unknownVerifier = SuperNeoNumiSealProductVerifier(
            expectedContextStore: NegativeExpectedContextStore(expectedContext: try strictExpectedContext(for: artifact)),
            authorizer: NegativeAuthorizer(),
            provenanceVerifier: NegativeProvenanceVerifier(),
            replayLedger: NegativeReplayLedger(),
            auditSink: NegativeAuditSink()
        )
        XCTAssertThrowsError(
            try unknownVerifier.verify(
                SuperNeoNumiSealProductVerificationRequest(
                    callerID: "tenant-negative",
                    expectedContextID: "ctx-negative",
                    artifact: artifact,
                    artifactBytes: [UInt8](unknownKeyBytes)
                )
            )
        ) { error in
            XCTAssertTrue(String(describing: error).contains("unknown top-level") || String(describing: error).contains("could not decode"))
        }
    }

    func testProductVerifierRejectsReplayBeforeAlgebraicReverification() throws {
        let data = try loadNumiSealArtifactData(named: "numiseal-terminal-single-aggregate-v1.json")
        let artifact = try JSONDecoder().decode(NumiSealArtifact.self, from: data)
        let replayLedger = NegativeReplayLedger()
        let auditSink = NegativeAuditSink()
        let verifier = SuperNeoNumiSealProductVerifier(
            expectedContextStore: NegativeExpectedContextStore(expectedContext: try strictExpectedContext(for: artifact)),
            authorizer: NegativeAuthorizer(),
            provenanceVerifier: NegativeProvenanceVerifier(),
            replayLedger: replayLedger,
            auditSink: auditSink
        )
        let request = SuperNeoNumiSealProductVerificationRequest(
            callerID: "tenant-negative",
            expectedContextID: "ctx-negative",
            artifact: artifact,
            artifactBytes: [UInt8](data)
        )

        _ = try verifier.verify(request)
        XCTAssertThrowsError(try verifier.verify(request)) { error in
            XCTAssertTrue(String(describing: error).contains("already been accepted"))
        }
        XCTAssertEqual(auditSink.decisions, [.accepted, .rejected])
        XCTAssertEqual(replayLedger.recordedCount, 1)
    }

    func testRecursiveCarryReplayIdentityRejectsCarryContextSwaps() throws {
        let contextID = "ctx-recursive-carry-negative"
        let statementDigest = Digest256.hash("recursive-negative-statement")
        let proofEnvelopeDigest = Digest256.hash("recursive-negative-proof")
        let artifactDigest = Digest256.hash("recursive-negative-artifact")
        let provenanceDigest = Digest256.hash("recursive-negative-provenance")
        let carry = try NumiSealProductRecursiveCarryReplayBinding(
            parentArtifactDigest: Digest256.hash("recursive-negative-parent-artifact"),
            parentSourceFoldEnvelopeDigest: Digest256.hash("recursive-negative-parent-source-fold"),
            parentProductProofEnvelopeDigest: Digest256.hash("recursive-negative-parent-product-proof"),
            parentProducerProofEnvelopeDigest: Digest256.hash("recursive-negative-parent-producer-proof"),
            parentPublicStatementDigest: Digest256.hash("recursive-negative-parent-public-statement"),
            consumerSessionDigest: Digest256.hash("recursive-negative-child-session"),
            nextRecursionLevel: 1,
            claimCount: 2,
            contextRoot: Digest256.hash("recursive-negative-context-root"),
            replayRoot: Digest256.hash("recursive-negative-replay-root")
        )
        let swappedCarry = try NumiSealProductRecursiveCarryReplayBinding(
            parentArtifactDigest: carry.parentArtifactDigest,
            parentSourceFoldEnvelopeDigest: carry.parentSourceFoldEnvelopeDigest,
            parentProductProofEnvelopeDigest: carry.parentProductProofEnvelopeDigest,
            parentProducerProofEnvelopeDigest: carry.parentProducerProofEnvelopeDigest,
            parentPublicStatementDigest: carry.parentPublicStatementDigest,
            consumerSessionDigest: carry.consumerSessionDigest,
            nextRecursionLevel: carry.nextRecursionLevel,
            claimCount: carry.claimCount,
            contextRoot: Digest256.hash("recursive-negative-swapped-context-root"),
            replayRoot: carry.replayRoot
        )
        let accepted = SuperNeoProductProofIdentity(
            expectedContextID: contextID,
            statementDigest: statementDigest,
            proofEnvelopeDigest: proofEnvelopeDigest,
            artifactDigest: artifactDigest,
            provenanceDigest: provenanceDigest,
            recursiveCarryReplayBindingDigest: carry.bindingDigest
        )
        let swapped = SuperNeoProductProofIdentity(
            expectedContextID: contextID,
            statementDigest: statementDigest,
            proofEnvelopeDigest: proofEnvelopeDigest,
            artifactDigest: artifactDigest,
            provenanceDigest: provenanceDigest,
            recursiveCarryReplayBindingDigest: swappedCarry.bindingDigest
        )

        XCTAssertNotEqual(accepted.localReplayDigest, swapped.localReplayDigest)
        let ledger = NegativeReplayLedger()
        try ledger.recordAccepted(accepted)
        XCTAssertTrue(try ledger.hasAccepted(accepted))
        XCTAssertFalse(try ledger.hasAccepted(swapped))
    }

    private func assertRejects(
        _ artifact: NumiSealArtifact,
        context: NumiSealArtifactExpectedContext,
        containing expectedMessage: String?,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        XCTAssertThrowsError(
            try NumiSealArtifactVerifier.verify(
                artifact: artifact,
                expectedContext: context,
                executionPolicy: .highAssurance
            ),
            file: file,
            line: line
        ) { error in
            if let expectedMessage {
                XCTAssertTrue(
                    String(describing: error).contains(expectedMessage),
                    "expected \(error) to contain \(expectedMessage)",
                    file: file,
                    line: line
                )
            }
        }
    }

    private func loadNumiSealArtifact(named name: String) throws -> NumiSealArtifact {
        try JSONDecoder().decode(NumiSealArtifact.self, from: loadNumiSealArtifactData(named: name))
    }

    private func loadNumiSealArtifactData(named name: String) throws -> Data {
        let testFile = URL(fileURLWithPath: #filePath)
        let repositoryRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try Data(
            contentsOf: repositoryRoot
                .appendingPathComponent("TestVectors")
                .appendingPathComponent(name)
        )
    }

    private func strictExpectedContext(for artifact: NumiSealArtifact) throws -> NumiSealArtifactExpectedContext {
        NumiSealArtifactExpectedContext(
            trustedKeySeedUTF8: artifact.keySeedUTF8,
            verifierKeyDigest: try Digest256(hexDigest: artifact.verifierKeyDigestHex),
            shapeDigest: try Digest256(hexDigest: artifact.shapeDigestHex),
            statementDigest: try Digest256(hexDigest: artifact.statementDigestHex),
            transcriptDomainDigest: try Digest256(hexDigest: artifact.transcriptDomainHex),
            publicStatementDigest: try Digest256(hexDigest: artifact.publicStatementDigestHex),
            obligationRoot: try Digest256(hexDigest: artifact.obligationRootHex),
            laneSummaryRoot: try Digest256(hexDigest: artifact.laneSummaryRootHex),
            aggregateDigests: try artifact.aggregateDigestsHex.map { try Digest256(hexDigest: $0) },
            componentDigestRoot: try Digest256(hexDigest: artifact.componentDigestRootHex),
            proofTranscriptDigest: try Digest256(hexDigest: artifact.proofTranscriptDigestHex),
            publicInputs: artifact.publicInputs
        )
    }

    private func copyArtifact(
        _ artifact: NumiSealArtifact,
        proofKind: String? = nil,
        publicInputCount: Int? = nil,
        publicInputs: [UInt64]? = nil,
        verifierKeyDigestHex: String? = nil,
        transcriptDomainHex: String? = nil,
        aggregateDigestsHex: [String]? = nil,
        laneIDsUTF8: [String]? = nil,
        proofEnvelopeBase64: String? = nil
    ) -> NumiSealArtifact {
        NumiSealArtifact(
            artifactVersion: artifact.artifactVersion,
            workload: artifact.workload,
            profile: artifact.profile,
            proofKind: proofKind ?? artifact.proofKind,
            residualMode: artifact.residualMode,
            keySeedUTF8: artifact.keySeedUTF8,
            keyColumnCount: artifact.keyColumnCount,
            foldTranscriptSeedUTF8: artifact.foldTranscriptSeedUTF8,
            laneIDsUTF8: laneIDsUTF8 ?? artifact.laneIDsUTF8,
            sourceFoldDigestSeedsUTF8: artifact.sourceFoldDigestSeedsUTF8,
            ceRandomSeedsUTF8: artifact.ceRandomSeedsUTF8,
            maximumObligationsPerAggregate: artifact.maximumObligationsPerAggregate,
            maximumLaneCount: artifact.maximumLaneCount,
            maximumAggregatesPerLane: artifact.maximumAggregatesPerLane,
            publicInputCount: publicInputCount ?? artifact.publicInputCount,
            privateWitnessCount: artifact.privateWitnessCount,
            publicInputs: publicInputs ?? artifact.publicInputs,
            shapeDigestHex: artifact.shapeDigestHex,
            statementDigestHex: artifact.statementDigestHex,
            verifierKeyDigestHex: verifierKeyDigestHex ?? artifact.verifierKeyDigestHex,
            transcriptDomainHex: transcriptDomainHex ?? artifact.transcriptDomainHex,
            publicStatementDigestHex: artifact.publicStatementDigestHex,
            obligationRootHex: artifact.obligationRootHex,
            laneSummaryRootHex: artifact.laneSummaryRootHex,
            aggregateDigestsHex: aggregateDigestsHex ?? artifact.aggregateDigestsHex,
            componentDigestRootHex: artifact.componentDigestRootHex,
            proofTranscriptDigestHex: artifact.proofTranscriptDigestHex,
            proofEnvelopeBase64: proofEnvelopeBase64 ?? artifact.proofEnvelopeBase64
        )
    }

    private func bitFlipOffsets(for bytes: [UInt8]) -> [Int] {
        [
            ProofEnvelopeHeader.byteCount,
            ProofEnvelopeHeader.byteCount + 17,
            bytes.count / 2,
            max(ProofEnvelopeHeader.byteCount, bytes.count - 2),
            bytes.count - 1,
        ].filter { $0 >= 0 && $0 < bytes.count }
    }

    private func writeUInt32(_ value: UInt32, into bytes: inout [UInt8], at offset: Int) {
        bytes.replaceSubrange(offset..<offset + 4, with: withUnsafeBytes(of: value.littleEndian, Array.init))
    }
}

private final class NegativeExpectedContextStore: SuperNeoNumiSealExpectedContextStore {
    let expectedContext: NumiSealArtifactExpectedContext

    init(expectedContext: NumiSealArtifactExpectedContext) {
        self.expectedContext = expectedContext
    }

    func expectedContext(for request: SuperNeoNumiSealProductVerificationRequest) throws -> NumiSealArtifactExpectedContext {
        expectedContext
    }
}

private final class NegativeAuthorizer: SuperNeoProductAuthorizer {
    func authorize(_ request: SuperNeoNumiSealProductVerificationRequest) throws {}
}

private final class NegativeProvenanceVerifier: SuperNeoArtifactProvenanceVerifier {
    func verifyProvenance(
        for request: SuperNeoNumiSealProductVerificationRequest,
        artifactDigest: Digest256
    ) throws -> Digest256 {
        Digest256.hash("negative-test-provenance")
    }
}

private final class NegativeReplayLedger: SuperNeoReplayLedger {
    private var accepted: Set<SuperNeoProductProofIdentity> = []
    private(set) var recordedCount = 0

    func hasAccepted(_ identity: SuperNeoProductProofIdentity) throws -> Bool {
        accepted.contains(identity)
    }

    func recordAccepted(_ identity: SuperNeoProductProofIdentity) throws {
        guard !accepted.contains(identity) else {
            throw SuperNeoProductIntegrationError.replayDetected("proof identity has already been accepted")
        }
        accepted.insert(identity)
        recordedCount += 1
    }
}

private final class NegativeAuditSink: SuperNeoVerificationAuditSink {
    private(set) var decisions: [SuperNeoProductAuditDecision] = []

    func record(_ event: SuperNeoProductVerificationAuditEvent) {
        decisions.append(event.decision)
    }
}
