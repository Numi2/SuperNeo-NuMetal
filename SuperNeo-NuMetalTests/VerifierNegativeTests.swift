import XCTest
import Foundation
import CryptoKit
@_spi(Benchmarking) @testable import SuperNeo_NuMetal

final class VerifierNegativeTests: SuperNeoTestCase {
    func testIssuedQROChallengePackBindsContextExpiryAndSingleUseReplay() throws {
        let signingKey = Curve25519.Signing.PrivateKey()
        let publicKeyDigest = Digest256.hash([UInt8](signingKey.publicKey.rawRepresentation)).hexString
        let frontendContextDigest = Digest256.hash("issued-qro-frontend")
        let publicCoin = Digest256.hash("issued-qro-public-coin").superNeoBytes
        let qroChallenge = try issuedQROChallenge(
            sessionID: "issued-qro-session",
            publicCoin: publicCoin,
            frontendContextDigest: frontendContextDigest
        )
        let transcriptDomainDigest = try qroChallenge.transcriptDomainDigest(label: "numiseal-product-terminal")
        let context = SuperNeoTrustedContextPayload(
            contextID: "ctx-issued-qro",
            issuer: "SuperNeo QRO Issuer",
            validFromUTC: "2026-04-25T00:00:00Z",
            validUntilUTC: "2026-04-26T00:00:00Z",
            expectedVerifierKeyDigestHex: Digest256.hash("issued-qro-verifier-key").hexString,
            expectedShapeDigestHex: Digest256.hash("issued-qro-shape").hexString,
            expectedStatementDigestHex: Digest256.hash("issued-qro-statement").hexString,
            expectedTranscriptDomainDigestHex: transcriptDomainDigest.hexString,
            acceptedProofKinds: [.numiSealZK],
            maximumArtifactByteCount: 1_000_000,
            maximumProofEnvelopeByteCount: 1_000_000,
            allowedWorkloads: ["one-hot-vector-v1"],
            publicInputs: [1],
            releaseBuildDigestHex: Digest256.hash("issued-qro-release").hexString,
            numiSeal: SuperNeoTrustedNumiSealContext(
                publicStatementDigestHex: Digest256.hash("issued-qro-public-statement").hexString,
                obligationRootHex: Digest256.hash("issued-qro-obligation").hexString,
                laneSummaryRootHex: Digest256.hash("issued-qro-lane-summary").hexString,
                aggregateDigestsHex: [Digest256.hash("issued-qro-aggregate").hexString],
                componentDigestRootHex: Digest256.hash("issued-qro-component").hexString,
                proofTranscriptDigestHex: Digest256.hash("issued-qro-proof-transcript").hexString
            ),
            keyRotation: SuperNeoTrustedContextKeyRotation(currentIssuerKeyDigestHex: publicKeyDigest),
            revocation: SuperNeoTrustedContextRevocation(issuedAtUTC: "2026-04-25T00:00:00Z")
        )
        let payload = SuperNeoIssuedQROChallengePayload(
            issuer: "SuperNeo QRO Issuer",
            contextID: context.contextID,
            qroSessionID: qroChallenge.sessionID,
            qroDomainSeparator: qroChallenge.domainSeparator,
            qroVerifierPublicCoinHex: hex(publicCoin),
            frontendContextDigestHex: frontendContextDigest.hexString,
            expectedVerifierKeyDigestHex: context.expectedVerifierKeyDigestHex,
            expectedShapeDigestHex: context.expectedShapeDigestHex,
            expectedStatementDigestHex: context.expectedStatementDigestHex,
            expectedTranscriptDomainDigestHex: transcriptDomainDigest.hexString,
            expectedPublicInputs: [1],
            qroChallengeDigest384Hex: qroChallenge.challengeDigest.hexString,
            issuedAtUTC: "2026-04-25T00:00:00Z",
            validUntilUTC: "2026-04-25T00:10:00Z"
        )
        let signedPack = SuperNeoSignedQROChallengePack(
            payload: payload,
            signature: try productSignature(for: payload, signingKey: signingKey)
        )
        let now = try SuperNeoProductTime.parseUTC("2026-04-25T00:05:00Z", name: "test now")
        let verified = try signedPack.verified(
            trustedIssuerKeyDigestsHex: [publicKeyDigest],
            context: context,
            frontendContextDigest: frontendContextDigest,
            now: now
        )
        XCTAssertEqual(verified.qroChallenge.challengeDigest, qroChallenge.challengeDigest)
        let preProofExpectedContext = SuperNeoIssuedQROChallengeExpectedContext(
            contextID: context.contextID,
            validFromUTC: context.validFromUTC,
            validUntilUTC: context.validUntilUTC,
            frontendContextDigest: frontendContextDigest,
            expectedVerifierKeyDigestHex: context.expectedVerifierKeyDigestHex,
            expectedShapeDigestHex: context.expectedShapeDigestHex,
            expectedStatementDigestHex: context.expectedStatementDigestHex,
            expectedTranscriptDomainDigestHex: context.expectedTranscriptDomainDigestHex,
            expectedPublicInputs: [1]
        )
        let preProofVerified = try signedPack.verified(
            trustedIssuerKeyDigestsHex: [publicKeyDigest],
            expectedContext: preProofExpectedContext,
            now: now
        )
        XCTAssertEqual(preProofVerified.qroChallenge.challengeDigest, qroChallenge.challengeDigest)

        let wrongPreProofStatement = SuperNeoIssuedQROChallengeExpectedContext(
            contextID: context.contextID,
            validFromUTC: context.validFromUTC,
            validUntilUTC: context.validUntilUTC,
            frontendContextDigest: frontendContextDigest,
            expectedVerifierKeyDigestHex: context.expectedVerifierKeyDigestHex,
            expectedShapeDigestHex: context.expectedShapeDigestHex,
            expectedStatementDigestHex: Digest256.hash("wrong-pre-proof-statement").hexString,
            expectedTranscriptDomainDigestHex: context.expectedTranscriptDomainDigestHex,
            expectedPublicInputs: [1]
        )
        try assertProductThrows(
            try signedPack.verified(
                trustedIssuerKeyDigestsHex: [publicKeyDigest],
                expectedContext: wrongPreProofStatement,
                now: now
            ),
            .unauthorized("QRO challenge statement digest does not match trusted context")
        )

        try assertProductThrows(
            try SuperNeoSignedQROChallengePack(
                payload: payload,
                signature: productSignature(for: payload, signingKey: Curve25519.Signing.PrivateKey())
            ).verified(
                trustedIssuerKeyDigestsHex: [publicKeyDigest],
                context: context,
                frontendContextDigest: frontendContextDigest,
                now: now
            ),
            .unauthorized("QRO challenge pack signer is not trusted")
        )

        let expiredPayload = replacingIssuedQROPayload(payload, validUntilUTC: "2026-04-25T00:01:00Z")
        try assertProductThrows(
            try SuperNeoSignedQROChallengePack(
                payload: expiredPayload,
                signature: productSignature(for: expiredPayload, signingKey: signingKey)
            ).verified(
                trustedIssuerKeyDigestsHex: [publicKeyDigest],
                context: context,
                frontendContextDigest: frontendContextDigest,
                now: now
            ),
            .unauthorized("QRO challenge has expired")
        )

        let swappedContextPayload = replacingIssuedQROPayload(payload, frontendContextDigestHex: Digest256.hash("other-frontend").hexString)
        try assertProductThrows(
            try SuperNeoSignedQROChallengePack(
                payload: swappedContextPayload,
                signature: productSignature(for: swappedContextPayload, signingKey: signingKey)
            ).verified(
                trustedIssuerKeyDigestsHex: [publicKeyDigest],
                context: context,
                frontendContextDigest: frontendContextDigest,
                now: now
            ),
            .unauthorized("QRO challenge frontend context digest does not match artifact context")
        )

        try assertProductThrows(
            try SuperNeoSignedQROChallengePack(
                payload: swappedContextPayload,
                signature: signedPack.signature
            ).verified(
                trustedIssuerKeyDigestsHex: [publicKeyDigest],
                context: context,
                frontendContextDigest: frontendContextDigest,
                now: now
            ),
            .unauthorized("QRO challenge pack signature is invalid")
        )

        let badDigestPayload = replacingIssuedQROPayload(payload, qroChallengeDigest384Hex: Digest384.shake256("wrong-qro-digest").hexString)
        try assertProductThrows(
            try SuperNeoSignedQROChallengePack(
                payload: badDigestPayload,
                signature: productSignature(for: badDigestPayload, signingKey: signingKey)
            ).verified(
                trustedIssuerKeyDigestsHex: [publicKeyDigest],
                context: context,
                frontendContextDigest: frontendContextDigest,
                now: now
            ),
            .unauthorized("QRO challenge digest does not match signed payload")
        )

        let reusablePayload = replacingIssuedQROPayload(payload, singleUse: false)
        try assertProductThrows(
            try SuperNeoSignedQROChallengePack(
                payload: reusablePayload,
                signature: productSignature(for: reusablePayload, signingKey: signingKey)
            ).verified(
                trustedIssuerKeyDigestsHex: [publicKeyDigest],
                context: context,
                frontendContextDigest: frontendContextDigest,
                now: now
            ),
            .unauthorized("QRO challenge pack must be single-use")
        )

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("superneo-issued-qro-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let databaseURL = directory.appendingPathComponent("replay.sqlite")
        try SuperNeoSQLiteReplayLedger.bootstrap(databaseURL: databaseURL)
        let ledger = try SuperNeoSQLiteReplayLedger(databaseURL: databaseURL)
        let issuedDigest = verified.payloadDigest
        let first = SuperNeoProductProofIdentity(
            expectedContextID: context.contextID,
            statementDigest: Digest256.hash("issued-qro-statement-1"),
            proofEnvelopeDigest: Digest256.hash("issued-qro-proof-1"),
            artifactDigest: Digest256.hash("issued-qro-artifact-1"),
            provenanceDigest: Digest256.hash("issued-qro-provenance-1"),
            issuedQROChallengeDigest: issuedDigest
        )
        try ledger.recordAccepted(first)
        let replayWithDifferentArtifact = SuperNeoProductProofIdentity(
            expectedContextID: context.contextID,
            statementDigest: Digest256.hash("issued-qro-statement-2"),
            proofEnvelopeDigest: Digest256.hash("issued-qro-proof-2"),
            artifactDigest: Digest256.hash("issued-qro-artifact-2"),
            provenanceDigest: Digest256.hash("issued-qro-provenance-2"),
            issuedQROChallengeDigest: issuedDigest
        )
        try assertProductThrows(
            try ledger.recordAccepted(replayWithDifferentArtifact),
            .replayDetected("proof identity has already been accepted")
        )
    }

    func testNumiSealProductVerifierRejectsQROPayPerBitArtifactMutations() throws {
        let qroChallenge = try makeQROChallenge("numiseal-product-negative-mutations")
        let output = try NumiSealProductAPI.proveOneHotVector(
            bits: [false, true],
            keySeedUTF8: "numiseal-product-negative-mutations-key",
            qroChallenge: qroChallenge,
            sourceApplicationPathUTF8: "app://negative/product-mutations",
            executionPolicy: .zkHighAssuranceCPU,
            aggregationLimits: try NumiSealAggregationLimits(maximumObligationsPerAggregate: 32)
        )
        let verifier = NumiSealProductVerifier()
        let honest = try verifier.verify(
            artifact: output.artifact,
            sourcePublicInput: output.sourcePublicInput,
            key: output.verifierKey,
            qroChallenge: qroChallenge,
            executionPolicy: .highAssurance,
            trustedContext: output.trustedContext
        )
        XCTAssertTrue(honest.sourceFoldResult.isReductionAccepted, honest.sourceFoldResult.reason ?? "")
        XCTAssertTrue(honest.numiSealResult.isValid, honest.numiSealResult.reason ?? "")

        func assertRejects(
            _ mutation: String,
            expected: SuperNeoError,
            file: StaticString = #filePath,
            line: UInt = #line,
            mutate: (inout NumiSealProductArtifact) throws -> Void
        ) throws {
            var artifact = output.artifact
            try mutate(&artifact)
            XCTAssertThrowsSuperNeoError(
                try verifier.verify(
                    artifact: artifact,
                    sourcePublicInput: output.sourcePublicInput,
                    key: output.verifierKey,
                    qroChallenge: qroChallenge,
                    executionPolicy: .highAssurance,
                    trustedContext: output.trustedContext
                ),
                expected,
                file: file,
                line: line
            )
            _ = mutation
        }

        try assertRejects(
            "wrong public inputs",
            expected: .invalidEncoding("NumiSeal product frontend context digest mismatch")
        ) { artifact in
            artifact.publicInputs = [0]
        }
        try assertRejects(
            "unsupported proof kind",
            expected: .invalidEncoding("unsupported NumiSeal product proof kind")
        ) { artifact in
            artifact.proofKind = "fold"
        }
        try assertRejects(
            "proof kind / ZK mode confusion",
            expected: .invalidEncoding("NumiSeal product proof kind, seal mode, and ZK mode are inconsistent")
        ) { artifact in
            artifact.proofKind = NumiSealProductArtifact.proofKind
        }
        try assertRejects(
            "transcript domain swap",
            expected: .invalidEncoding("NumiSeal product QRO transcript domain mismatch")
        ) { artifact in
            artifact.transcriptDomainHex = String(repeating: "0", count: Digest256.byteCount * 2)
        }
        try assertRejects(
            "source output digest mutation",
            expected: .invalidEncoding("NumiSeal product CTCO root mismatch")
        ) { artifact in
            artifact.sourceFoldOutputClaimDigestsHex[0] = String(repeating: "0", count: Digest256.byteCount * 2)
        }
        try assertRejects(
            "aggregate digest mutation",
            expected: .invalidEncoding("NumiSeal product CTCO root mismatch")
        ) { artifact in
            artifact.aggregateDigestsHex[0] = String(repeating: "0", count: Digest256.byteCount * 2)
        }
        try assertRejects(
            "lane mutation",
            expected: .invalidEncoding("NumiSeal product frontend context digest mismatch")
        ) { artifact in
            artifact.laneIDsUTF8 = ["mutated-lane"]
        }
        try assertRejects(
            "public statement digest bit flip",
            expected: .invalidEncoding("NumiSeal product CTCO root mismatch")
        ) { artifact in
            artifact.publicStatementDigestHex = String(repeating: "0", count: Digest256.byteCount * 2)
        }
        try assertRejects(
            "metadata QROM width bit flip",
            expected: .invalidEncoding("NumiSeal product QROM width metadata mismatch")
        ) { artifact in
            artifact.executionPolicyMetadata["qromQueryCapLog2"] = "63"
        }
        try assertRejects(
            "CTCO root bit flip",
            expected: .invalidEncoding("NumiSeal product CTCO root mismatch")
        ) { artifact in
            artifact.executionPolicyMetadata["ctcoRoot384Hex"] = String(repeating: "0", count: Digest384.byteCount * 2)
        }
        try assertRejects(
            "source-fold CTCO root bit flip",
            expected: .invalidEncoding("NumiSeal product source-fold CTCO root mismatch")
        ) { artifact in
            artifact.executionPolicyMetadata["sourceFoldCTCORoot384Hex"] = String(repeating: "0", count: Digest384.byteCount * 2)
        }
        try assertRejects(
            "proof-envelope CTCO root bit flip",
            expected: .invalidEncoding("NumiSeal product proof-envelope CTCO root mismatch")
        ) { artifact in
            artifact.executionPolicyMetadata["proofEnvelopeCTCORoot384Hex"] = String(repeating: "0", count: Digest384.byteCount * 2)
        }
        try assertRejects(
            "pay-per-bit source claim count mutation",
            expected: .invalidEncoding("NumiSeal product source claim count mismatch")
        ) { artifact in
            artifact.sourceFoldOutputClaimCount += 1
        }
        try assertRejects(
            "top-level decomposition profile mutation",
            expected: .invalidEncoding("NumiSeal product source decomposition profile mismatch")
        ) { artifact in
            artifact.sourceDecompositionProfile = "fixed-maximum-v1"
        }
        try assertRejects(
            "metadata decomposition profile mutation",
            expected: .invalidEncoding("NumiSeal product source decomposition profile metadata mismatch")
        ) { artifact in
            artifact.executionPolicyMetadata["sourceDecompositionProfile"] = "fixed-maximum-v1"
        }
        try assertRejects(
            "malformed source envelope base64",
            expected: .invalidEncoding("NumiSeal product source fold envelope is not valid base64")
        ) { artifact in
            artifact.sourceFoldEnvelopeBase64 = "not-base64"
        }
        try assertRejects(
            "malformed NumiSeal envelope base64",
            expected: .invalidEncoding("NumiSeal product proof envelope is not valid base64")
        ) { artifact in
            artifact.numiSealProofEnvelopeBase64 = "not-base64"
        }
        try assertRejects(
            "truncated source fold envelope",
            expected: .invalidEncoding("proof envelope body length mismatch")
        ) { artifact in
            artifact.sourceFoldEnvelopeBase64 = try droppingLastByteBase64(artifact.sourceFoldEnvelopeBase64)
        }
        try assertRejects(
            "truncated NumiSeal envelope",
            expected: .invalidEncoding("proof envelope body length mismatch")
        ) { artifact in
            artifact.numiSealProofEnvelopeBase64 = try droppingLastByteBase64(artifact.numiSealProofEnvelopeBase64)
        }
        try assertRejects(
            "source envelope bit flip",
            expected: .invalidEncoding("NumiSeal product source-fold CTCO root mismatch")
        ) { artifact in
            artifact.sourceFoldEnvelopeBase64 = try flippingLastByteBase64(artifact.sourceFoldEnvelopeBase64)
        }
        try assertRejects(
            "NumiSeal envelope bit flip",
            expected: .invalidEncoding("NumiSeal product proof-envelope CTCO root mismatch")
        ) { artifact in
            artifact.numiSealProofEnvelopeBase64 = try flippingLastByteBase64(artifact.numiSealProofEnvelopeBase64)
        }

        let swappedQROChallenge = try makeQROChallenge("numiseal-product-negative-mutations-swapped-qro")
        XCTAssertThrowsSuperNeoError(
            try verifier.verify(
                artifact: output.artifact,
                sourcePublicInput: output.sourcePublicInput,
                key: output.verifierKey,
                qroChallenge: swappedQROChallenge,
                executionPolicy: .highAssurance,
                trustedContext: output.trustedContext
            ),
            .invalidEncoding("NumiSeal product QRO challenge digest mismatch")
        )

        let swappedKey = try AjtaiCommitmentKey(
            columns: output.verifierKey.matrix.columns,
            seed: Array("numiseal-product-negative-swapped-key".utf8)
        )
        XCTAssertThrowsSuperNeoError(
            try verifier.verify(
                artifact: output.artifact,
                sourcePublicInput: output.sourcePublicInput,
                key: swappedKey,
                qroChallenge: qroChallenge,
                executionPolicy: .highAssurance,
                trustedContext: output.trustedContext
            ),
            .verificationFailed("NumiSeal product verifier key digest mismatch")
        )
    }

    func testProductControlJSONDuplicateKeysFailClosed() throws {
        let rootDuplicate = #"{"payload":{"contextID":"ctx-a"},"payload":{"contextID":"ctx-b"}}"#
        try assertProductThrows(
            try SuperNeoJSONDuplicateKeyValidator.validate(
                data: Data(rootDuplicate.utf8),
                artifactName: "QRO challenge pack"
            ),
            .invalidRequest("QRO challenge pack contains duplicate JSON key 'payload' at $")
        )

        let nestedDuplicate = #"{"payload":{"contextID":"ctx-a","contextID":"ctx-b"}}"#
        try assertProductThrows(
            try SuperNeoJSONDuplicateKeyValidator.validate(
                data: Data(nestedDuplicate.utf8),
                artifactName: "trusted context pack"
            ),
            .invalidRequest("trusted context pack contains duplicate JSON key 'contextID' at $.payload")
        )
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
}

private func flippingLastByteBase64(_ encoded: String) throws -> String {
    guard let data = Data(base64Encoded: encoded) else {
        throw SuperNeoError.invalidEncoding("test fixture base64 decode failed")
    }
    var bytes = [UInt8](data)
    guard !bytes.isEmpty else {
        throw SuperNeoError.invalidEncoding("test fixture base64 payload is empty")
    }
    bytes[bytes.count - 1] ^= 0x01
    return Data(bytes).base64EncodedString()
}

private func droppingLastByteBase64(_ encoded: String) throws -> String {
    guard let data = Data(base64Encoded: encoded) else {
        throw SuperNeoError.invalidEncoding("test fixture base64 decode failed")
    }
    var bytes = [UInt8](data)
    guard !bytes.isEmpty else {
        throw SuperNeoError.invalidEncoding("test fixture base64 payload is empty")
    }
    bytes.removeLast()
    return Data(bytes).base64EncodedString()
}

private func issuedQROChallenge(
    sessionID: String,
    publicCoin: [UInt8],
    frontendContextDigest: Digest256
) throws -> SuperNeoQROChallenge {
    try SuperNeoQROChallenge(
        domainSeparator: SuperNeoQROChallenge.defaultDomainSeparator,
        sessionID: sessionID,
        verifierPublicCoin: publicCoin,
        transcriptContext: SuperNeoSplitQRO.framedBytes(
            domain: "superneo/cli/numiseal-product/qro-context/v1",
            frames: [frontendContextDigest.superNeoBytes]
        )
    )
}

private func productSignature<T: Encodable>(
    for payload: T,
    signingKey: Curve25519.Signing.PrivateKey
) throws -> SuperNeoProductSignature {
    let payloadData = try SuperNeoCanonicalJSON.encode(payload)
    let signature = try signingKey.signature(for: payloadData)
    let publicKey = signingKey.publicKey.rawRepresentation
    return SuperNeoProductSignature(
        publicKeyBase64: publicKey.base64EncodedString(),
        publicKeyDigestHex: Digest256.hash([UInt8](publicKey)).hexString,
        signatureBase64: signature.base64EncodedString()
    )
}

private func assertProductThrows<T>(
    _ expression: @autoclosure () throws -> T,
    _ expected: SuperNeoProductIntegrationError,
    file: StaticString = #filePath,
    line: UInt = #line
) throws {
    do {
        _ = try expression()
        XCTFail("expected \(expected)", file: file, line: line)
    } catch let error as SuperNeoProductIntegrationError {
        XCTAssertEqual(error, expected, file: file, line: line)
    } catch {
        XCTFail("expected \(expected), got \(error)", file: file, line: line)
    }
}

private func replacingIssuedQROPayload(
    _ payload: SuperNeoIssuedQROChallengePayload,
    frontendContextDigestHex: String? = nil,
    qroChallengeDigest384Hex: String? = nil,
    singleUse: Bool? = nil,
    validUntilUTC: String? = nil
) -> SuperNeoIssuedQROChallengePayload {
    SuperNeoIssuedQROChallengePayload(
        formatVersion: payload.formatVersion,
        issuer: payload.issuer,
        contextID: payload.contextID,
        qroSessionID: payload.qroSessionID,
        qroDomainSeparator: payload.qroDomainSeparator,
        qroVerifierPublicCoinHex: payload.qroVerifierPublicCoinHex,
        frontendContextDigestHex: frontendContextDigestHex ?? payload.frontendContextDigestHex,
        expectedVerifierKeyDigestHex: payload.expectedVerifierKeyDigestHex,
        expectedShapeDigestHex: payload.expectedShapeDigestHex,
        expectedStatementDigestHex: payload.expectedStatementDigestHex,
        expectedTranscriptDomainDigestHex: payload.expectedTranscriptDomainDigestHex,
        expectedPublicInputs: payload.expectedPublicInputs,
        qroChallengeDigest384Hex: qroChallengeDigest384Hex ?? payload.qroChallengeDigest384Hex,
        singleUse: singleUse ?? payload.singleUse,
        issuedAtUTC: payload.issuedAtUTC,
        validUntilUTC: validUntilUTC ?? payload.validUntilUTC
    )
}

private func hex(_ bytes: [UInt8]) -> String {
    bytes.map { String(format: "%02x", $0) }.joined()
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
