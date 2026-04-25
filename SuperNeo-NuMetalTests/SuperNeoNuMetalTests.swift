import XCTest
import CryptoKit
import Metal
@_spi(Benchmarking) @testable import SuperNeo_NuMetal

private let encodedCountByteWidth = 8
private let proofEnvelopeVerifierKeyDigestOffset = 4 + 2 + 2 + 1 + (2 * Digest256.byteCount)
private let ceOpeningStatementVerifierKeyDigestOffset = 2 + Digest256.byteCount
private let terminalCEStatementVerifierKeyDigestOffset = 2 + Digest256.byteCount
private let compressedStatementContextVerifierKeyDigestOffset =
    Digest256.byteCount + 2 + 1 + (2 * Digest256.byteCount)
private let compressedStatementVerifierKeyDigestOffset =
    compressedStatementContextVerifierKeyDigestOffset + (4 * Digest256.byteCount)

private extension Digest256 {
    var hexStringForTest: String {
        bytes.map { String(format: "%02x", $0) }.joined()
    }
}

class SuperNeoTestCase: XCTestCase {
    func requireMetalDevice(file: StaticString = #filePath, line: UInt = #line) throws -> MTLDevice {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip(
                "Metal device unavailable; CPU-only environments intentionally skip Metal differential coverage",
                file: file,
                line: line
            )
        }
        return device
    }
}

final class AlgebraCoreTests: SuperNeoTestCase {
    // MARK: - Tier 0: deterministic algebra and backend differential properties

    func testTier0SHAKE256AndSplitQROVectors() throws {
        XCTAssertEqual(
            Digest256.shake256([]).hexStringForTest,
            "46b9dd2b0ba88d13233b3feb743eeb243fcd52ea62b81b82b50c27646ed5762f"
        )
        XCTAssertEqual(
            Digest384.shake256([]).hexString,
            "46b9dd2b0ba88d13233b3feb743eeb243fcd52ea62b81b82b50c27646ed5762fd75dc4ddd8c0f200cb05019d67b592f6"
        )
        XCTAssertEqual(
            Digest384.shake256("abc").hexString,
            "483366601360a8771c6863080cc4114d8db44530f8f1e1ee4f94ea37e78b5739d5a15bef186a5386c75744c0527e1faa"
        )

        let frames = SuperNeoSplitQRO.framedBytes(
            domain: SuperNeoSplitQRO.bindingDomain,
            frames: [Array("ctx".utf8), [1, 2, 3]]
        )
        XCTAssertEqual(Array(frames.prefix(8)), [25, 0, 0, 0, 0, 0, 0, 0])
        XCTAssertEqual(Array(frames.dropFirst(8).prefix(25)), Array(SuperNeoSplitQRO.bindingDomain.utf8))
        XCTAssertEqual(Array(frames.dropFirst(33).prefix(8)), [3, 0, 0, 0, 0, 0, 0, 0])
        XCTAssertNotEqual(
            SuperNeoSplitQRO.hBind(domain: SuperNeoSplitQRO.bindingDomain, frames: [[1]]),
            SuperNeoSplitQRO.hBind(domain: SuperNeoSplitQRO.challengeDomain, frames: [[1]])
        )

        let tapeSeed = SuperNeoSplitQRO.hChal(frames: [Array("seed".utf8)])
        var foldDigestTape = SuperNeoChallengeTape(
            seed: tapeSeed,
            proofKind: .foldReduction,
            label: "unit/challenge-tape"
        )
        var foldFieldTape = SuperNeoChallengeTape(
            seed: tapeSeed,
            proofKind: .foldReduction,
            label: "unit/challenge-tape"
        )
        var sameFoldFieldTape = SuperNeoChallengeTape(
            seed: tapeSeed,
            proofKind: .foldReduction,
            label: "unit/challenge-tape"
        )
        var terminalTape = SuperNeoChallengeTape(
            seed: tapeSeed,
            proofKind: .terminalLocal,
            label: "unit/challenge-tape"
        )
        XCTAssertEqual(
            foldDigestTape.nextDigest(),
            SuperNeoSplitQRO.expandChallenge(
                seed: tapeSeed,
                proofKind: .foldReduction,
                label: "unit/challenge-tape",
                index: 0
            )
        )
        XCTAssertEqual(foldFieldTape.nextField(), sameFoldFieldTape.nextField())
        XCTAssertEqual(foldFieldTape.nextExt2(), sameFoldFieldTape.nextExt2())
        XCTAssertEqual(foldFieldTape.nextRing().coefficients, sameFoldFieldTape.nextRing().coefficients)
        XCTAssertNotEqual(foldDigestTape.nextDigest(label: "round"), terminalTape.nextDigest(label: "round"))
        XCTAssertNotEqual(
            SuperNeoChallengeTape.expansionDigest(
                seed: tapeSeed,
                proofKind: .foldReduction,
                label: "unit/challenge-tape",
                digestCount: 2
            ),
            SuperNeoChallengeTape.expansionDigest(
                seed: tapeSeed,
                proofKind: .foldReduction,
                label: "unit/challenge-tape",
                digestCount: 3
            )
        )
    }

    func testTier0CTCOContextBinderIncludesProofKindAndRootBlocks() throws {
        let shape = Digest256.hash("shape")
        let statement = Digest256.hash("statement")
        let verifier = Digest256.hash("verifier")
        let transcript = Digest256.hash("transcript")
        let foldContext = ProofEnvelopeContext(
            profileID: 1,
            kind: .foldReduction,
            shapeDigest: shape,
            statementDigest: statement,
            verifierKeyDigest: verifier,
            transcriptDomain: transcript
        )
        let terminalContext = ProofEnvelopeContext(
            profileID: 1,
            kind: .terminalLocal,
            shapeDigest: shape,
            statementDigest: statement,
            verifierKeyDigest: verifier,
            transcriptDomain: transcript
        )

        XCTAssertNotEqual(foldContext.ctcoContextBinder, terminalContext.ctcoContextBinder)
        XCTAssertEqual(foldContext.transcriptBindingBytes[8], ProofEnvelopeKind.foldReduction.rawValue)

        let root = CTCOMoveOneCommitment(
            proofKind: .foldReduction,
            contextBinder: foldContext.ctcoContextBinder,
            traceBlocks: [
                CTCOTraceBlock(label: "source", bytes: [1, 2, 3]),
                CTCOTraceBlock(label: "ce", bytes: [4, 5])
            ]
        )
        let sameRoot = CTCOMoveOneCommitment(
            proofKind: .foldReduction,
            contextBinder: foldContext.ctcoContextBinder,
            traceBlocks: [
                CTCOTraceBlock(label: "source", bytes: [1, 2, 3]),
                CTCOTraceBlock(label: "ce", bytes: [4, 5])
            ]
        )
        let changedRoot = CTCOMoveOneCommitment(
            proofKind: .foldReduction,
            contextBinder: foldContext.ctcoContextBinder,
            traceBlocks: [
                CTCOTraceBlock(label: "source", bytes: [1, 2, 3]),
                CTCOTraceBlock(label: "ce", bytes: [4, 6])
            ]
        )
        XCTAssertEqual(root, sameRoot)
        XCTAssertNotEqual(root.root, changedRoot.root)

        let seed = SuperNeoSplitQRO.challengeTapeSeed(
            proofKind: .foldReduction,
            contextBinder: root.contextBinder,
            root: root.root,
            label: "fold/v2"
        )
        XCTAssertNotEqual(
            SuperNeoSplitQRO.expandChallenge(seed: seed, proofKind: .foldReduction, label: "ce", index: 0),
            SuperNeoSplitQRO.expandChallenge(seed: seed, proofKind: .foldReduction, label: "ce", index: 1)
        )

        for kind in [
            ProofEnvelopeKind.foldReduction,
            .terminalLocal,
            .compressedPublic,
            .numiSealTerminal,
            .numiSealZK
        ] {
            let body = Array("ctco-body-\(kind.rawValue)".utf8)
            let header = ProofEnvelopeHeader(
                profileID: 1,
                kind: kind,
                shapeDigest: shape,
                statementDigest: statement,
                verifierKeyDigest: verifier,
                transcriptDomain: transcript,
                bodyLength: UInt32(body.count)
            )
            let envelopeBytes = header.superNeoBytes + body
            let report = try ProofEnvelopeCTCOVerifier.verify(envelopeBytes: envelopeBytes)
            XCTAssertEqual(report.proofKind, kind)
            XCTAssertEqual(report.contextBinder, header.ctcoContextBinder)
            XCTAssertEqual(report.traceBlockCount, 4)
            XCTAssertEqual(report.bodyDigest, Digest256.hash(body))
            XCTAssertNoThrow(
                try ProofEnvelopeCTCOVerifier.verify(
                    envelopeBytes: envelopeBytes,
                    expectedRoot: report.root,
                    expectedChallengeTapeSeed: report.challengeTapeSeed
                )
            )
            var tampered = envelopeBytes
            tampered[tampered.count - 1] ^= 0x01
            XCTAssertThrowsSuperNeoError(
                try ProofEnvelopeCTCOVerifier.verify(envelopeBytes: tampered, expectedRoot: report.root),
                .verificationFailed("proof envelope CTCO root mismatch")
            )
        }

        let identity = SuperNeoProductProofIdentity(
            expectedContextID: "ctx",
            statementDigest: Digest256.hash("statement"),
            proofEnvelopeDigest: Digest256.hash("proof"),
            artifactDigest: Digest256.hash("artifact"),
            provenanceDigest: Digest256.hash("provenance"),
            recursiveCarryReplayBindingDigest: Digest256.hash("carry")
        )
        let changedIdentity = SuperNeoProductProofIdentity(
            expectedContextID: "ctx",
            statementDigest: Digest256.hash("statement"),
            proofEnvelopeDigest: Digest256.hash("proof"),
            artifactDigest: Digest256.hash("artifact"),
            provenanceDigest: Digest256.hash("changed-provenance"),
            recursiveCarryReplayBindingDigest: Digest256.hash("carry")
        )
        XCTAssertEqual(identity.hBindReplayBinder.bytes.count, Digest384.byteCount)
        XCTAssertNotEqual(identity.localReplayDigest.superNeoBytes, Array(identity.hBindReplayBinder.superNeoBytes.prefix(Digest256.byteCount)))
        XCTAssertNotEqual(identity.hBindReplayBinder, changedIdentity.hBindReplayBinder)
        XCTAssertEqual(try SuperNeoProductProofKind(envelopeKind: .foldReduction), .fold)

        let carry = try NumiSealProductRecursiveCarryReplayBinding(
            parentArtifactDigest: Digest256.hash("parent-artifact"),
            parentSourceFoldEnvelopeDigest: Digest256.hash("parent-source"),
            parentProductProofEnvelopeDigest: Digest256.hash("parent-product-proof"),
            parentProducerProofEnvelopeDigest: Digest256.hash("parent-producer-proof"),
            parentPublicStatementDigest: Digest256.hash("parent-public-statement"),
            consumerSessionDigest: Digest256.hash("consumer-session"),
            nextRecursionLevel: 1,
            claimCount: 1,
            contextRoot: Digest256.hash("context-root"),
            replayRoot: Digest256.hash("replay-root")
        )
        XCTAssertEqual(carry.hBindBindingDigest.bytes.count, Digest384.byteCount)
        XCTAssertNotEqual(carry.bindingDigest.superNeoBytes, Array(carry.hBindBindingDigest.superNeoBytes.prefix(Digest256.byteCount)))
    }

    func testTier0GoldilocksBoundaryReductionFixtures() {
        let minusOne = GoldilocksField(GoldilocksField.modulus - 1)
        let minusTwo = GoldilocksField(GoldilocksField.modulus - 2)
        let two = GoldilocksField(2)
        let two32 = GoldilocksField(1 << 32)
        let epsilon = GoldilocksField((1 << 32) - 1)

        XCTAssertEqual(minusOne + .one, .zero)
        XCTAssertEqual(minusTwo + two, .zero)
        XCTAssertEqual(minusOne + minusOne, minusTwo)
        XCTAssertEqual(minusOne + two, .one)
        XCTAssertEqual(.zero - .one, minusOne)
        XCTAssertEqual(.one - two, minusOne)
        XCTAssertEqual(-GoldilocksField.zero, .zero)
        XCTAssertEqual(-minusOne, .one)
        XCTAssertEqual(GoldilocksField(GoldilocksField.modulus), .zero)
        XCTAssertEqual(GoldilocksField(UInt64.max), GoldilocksField((1 << 32) - 2))

        XCTAssertEqual(minusOne * minusOne, .one)
        XCTAssertEqual(minusOne * two, minusTwo)
        XCTAssertEqual(minusTwo * minusTwo, GoldilocksField(4))
        XCTAssertEqual(two32 * two32, epsilon)
        XCTAssertEqual(epsilon * epsilon, GoldilocksField(0xFFFF_FFFE_0000_0001))
    }

    func testTier0GoldilocksAndExtensionFieldsSeededLaws() throws {
        let u = GoldilocksExt2(.zero, .one)
        XCTAssertEqual(u * u, GoldilocksExt2(GoldilocksExt2.nonResidue))

        let boundaryValues = [
            GoldilocksField.zero,
            .one,
            GoldilocksField(1 << 32),
            GoldilocksField((1 << 32) - 1),
            GoldilocksField(GoldilocksField.modulus - 2),
            GoldilocksField(GoldilocksField.modulus - 1),
            GoldilocksField(UInt64.max)
        ]
        XCTAssertEqual(GoldilocksField(UInt64.max), GoldilocksField((1 << 32) - 2))
        XCTAssertEqual(GoldilocksField(1 << 32) * GoldilocksField(1 << 32), GoldilocksField((1 << 32) - 1))

        var generator = SeededTestGenerator(seed: 0x5355_5045_524E_454F)
        var triples: [(GoldilocksField, GoldilocksField, GoldilocksField)] = []
        for index in 0..<128 {
            let a = index < boundaryValues.count ? boundaryValues[index] : generator.field()
            triples.append((a, generator.field(), generator.field()))
        }

        for (a, b, c) in triples {
            XCTAssertEqual(a + b, b + a)
            XCTAssertEqual(a * b, b * a)
            XCTAssertEqual((a + b) + c, a + (b + c))
            XCTAssertEqual((a * b) * c, a * (b * c))
            XCTAssertEqual(a * (b + c), (a * b) + (a * c))
            XCTAssertEqual((a + b) - b, a)
            XCTAssertEqual(try GoldilocksField(littleEndianBytes: a.littleEndianBytes[...]), a)
            if a != .zero {
                XCTAssertEqual(try a.inverse() * a, .one)
                XCTAssertEqual(a.pow(GoldilocksField.modulus - 1), .one)
            }

            let x = GoldilocksExt2(a, b)
            let y = GoldilocksExt2(b, c)
            let z = GoldilocksExt2(c, a)
            XCTAssertEqual(x + y, y + x)
            XCTAssertEqual(x * y, y * x)
            XCTAssertEqual((x + y) + z, x + (y + z))
            XCTAssertEqual((x * y) * z, x * (y * z))
            XCTAssertEqual(x * (y + z), (x * y) + (x * z))
            XCTAssertEqual(x.scaled(by: c), x * GoldilocksExt2(c))
            XCTAssertEqual(try GoldilocksExt2(littleEndianBytes: x.littleEndianBytes[...]), x)
            if x != .zero {
                XCTAssertEqual(try x.inverse() * x, .one)
            }
        }

        XCTAssertThrowsSuperNeoError(try GoldilocksField.zero.inverse(), .divisionByZero)
        XCTAssertThrowsSuperNeoError(
            try GoldilocksField(littleEndianBytes: withUnsafeBytes(of: GoldilocksField.modulus.littleEndian, Array.init)[...]),
            .invalidEncoding("non-canonical Goldilocks element")
        )
        XCTAssertThrowsSuperNeoError(
            try GoldilocksField(littleEndianBytes: [UInt8](repeating: 0, count: 7)[...]),
            .invalidEncoding("Goldilocks element must be 8 bytes")
        )
        XCTAssertThrowsSuperNeoError(try GoldilocksExt2.zero.inverse(), .divisionByZero)
        XCTAssertThrowsSuperNeoError(
            try GoldilocksExt2(littleEndianBytes: [UInt8](repeating: 0, count: 15)[...]),
            .invalidEncoding("GoldilocksExt2 element must be 16 bytes")
        )
    }

    func testTier0GoldilocksExt2SerializationUsesCanonicalC0ThenC1Order() throws {
        func leBytes(_ value: UInt64) -> [UInt8] {
            withUnsafeBytes(of: value.littleEndian, Array.init)
        }

        let c0Raw: UInt64 = 0x0102_0304_0506_0708
        let c1Raw: UInt64 = 0x1110_0F0E_0D0C_0B0A
        let c0 = GoldilocksField(c0Raw)
        let c1 = GoldilocksField(c1Raw)
        let element = GoldilocksExt2(c0, c1)
        let expected = leBytes(c0Raw) + leBytes(c1Raw)

        XCTAssertLessThan(c0Raw, GoldilocksField.modulus)
        XCTAssertLessThan(c1Raw, GoldilocksField.modulus)
        XCTAssertEqual(element.littleEndianBytes, expected)
        XCTAssertEqual(element.superNeoBytes, expected)
        XCTAssertEqual(try GoldilocksExt2(littleEndianBytes: expected[...]), element)

        let swapped = leBytes(c1Raw) + leBytes(c0Raw)
        XCTAssertEqual(try GoldilocksExt2(littleEndianBytes: swapped[...]), GoldilocksExt2(c1, c0))
        XCTAssertNotEqual(swapped, expected)

        let modulusBytes = leBytes(GoldilocksField.modulus)
        var nonCanonicalC0 = expected
        nonCanonicalC0.replaceSubrange(0..<8, with: modulusBytes)
        XCTAssertThrowsSuperNeoError(
            try GoldilocksExt2(littleEndianBytes: nonCanonicalC0[...]),
            .invalidEncoding("non-canonical Goldilocks element")
        )

        var nonCanonicalC1 = expected
        nonCanonicalC1.replaceSubrange(8..<16, with: modulusBytes)
        XCTAssertThrowsSuperNeoError(
            try GoldilocksExt2(littleEndianBytes: nonCanonicalC1[...]),
            .invalidEncoding("non-canonical Goldilocks element")
        )

        XCTAssertThrowsSuperNeoError(
            try GoldilocksExt2(littleEndianBytes: (expected + [0])[...]),
            .invalidEncoding("GoldilocksExt2 element must be 16 bytes")
        )

        let ring = CyclotomicExt2Ring54([element, GoldilocksExt2(c1, c0)])
        XCTAssertEqual(Array(ring.littleEndianBytes.prefix(16)), expected)
        XCTAssertEqual(Array(ring.littleEndianBytes.dropFirst(16).prefix(16)), swapped)
        XCTAssertEqual(try CyclotomicExt2Ring54(littleEndianBytes: ring.littleEndianBytes), ring)

        let sumcheck = SumcheckProof(
            claimedSum: element,
            rounds: [SumcheckRound(coeffs: [GoldilocksExt2(c1, c0), element])],
            finalPoint: [element],
            finalValue: GoldilocksExt2(c1, c0)
        )
        XCTAssertEqual(Array(sumcheck.superNeoBytes.prefix(16)), expected)
        XCTAssertEqual(Array(sumcheck.superNeoBytes.dropFirst(32).prefix(16)), swapped)
        XCTAssertEqual(Array(sumcheck.superNeoBytes.dropFirst(48).prefix(16)), expected)
        XCTAssertEqual(Array(sumcheck.superNeoBytes.dropFirst(72).prefix(16)), expected)
        XCTAssertEqual(Array(sumcheck.superNeoBytes.dropFirst(88).prefix(16)), swapped)

        let commitment = AjtaiCommitment(
            (0..<SuperNeoParameters.goldilocks.kappa).map { index in
                CyclotomicRing54([GoldilocksField(UInt64(index + 3))])
            }
        )
        let publicInput = [GoldilocksField(7), GoldilocksField(19)]
        let evaluationRing = CyclotomicExt2Ring54([element, GoldilocksExt2(c1, c0)])
        let claim = CCSEvaluationClaim(
            commitment: commitment,
            publicInput: publicInput,
            point: [element],
            evaluations: [evaluationRing]
        )
        let claimPointCountOffset = commitment.superNeoBytes.count
            + encodedCountByteWidth
            + publicInput.count * 8
        XCTAssertEqual(
            Array(claim.superNeoBytes.dropFirst(claimPointCountOffset).prefix(encodedCountByteWidth)),
            leBytes(1)
        )
        XCTAssertEqual(
            Array(claim.superNeoBytes.dropFirst(claimPointCountOffset + encodedCountByteWidth).prefix(16)),
            expected
        )
        let claimEvaluationCountOffset = claimPointCountOffset + encodedCountByteWidth + 16
        XCTAssertEqual(
            Array(claim.superNeoBytes.dropFirst(claimEvaluationCountOffset).prefix(encodedCountByteWidth)),
            leBytes(1)
        )
        XCTAssertEqual(
            Array(claim.superNeoBytes.dropFirst(claimEvaluationCountOffset + encodedCountByteWidth).prefix(16)),
            expected
        )
        XCTAssertEqual(
            Array(claim.superNeoBytes.dropFirst(claimEvaluationCountOffset + encodedCountByteWidth + 16).prefix(16)),
            swapped
        )

        let ceInstance = CEInstance(
            commitment: commitment,
            publicInput: publicInput,
            evalPoint: [GoldilocksExt2(c1, c0)],
            matrixEvals: [evaluationRing]
        )
        let cePointCountOffset = commitment.superNeoBytes.count
            + ceInstance.publicInputEncoding.superNeoBytes.count
        XCTAssertEqual(
            Array(ceInstance.superNeoBytes.dropFirst(cePointCountOffset).prefix(encodedCountByteWidth)),
            leBytes(1)
        )
        XCTAssertEqual(
            Array(ceInstance.superNeoBytes.dropFirst(cePointCountOffset + encodedCountByteWidth).prefix(16)),
            swapped
        )
        let ceMatrixEvalCountOffset = cePointCountOffset + encodedCountByteWidth + 16
        XCTAssertEqual(
            Array(ceInstance.superNeoBytes.dropFirst(ceMatrixEvalCountOffset).prefix(encodedCountByteWidth)),
            leBytes(1)
        )
        XCTAssertEqual(
            Array(ceInstance.superNeoBytes.dropFirst(ceMatrixEvalCountOffset + encodedCountByteWidth).prefix(16)),
            expected
        )
        XCTAssertEqual(try CEInstance(bytes: ceInstance.superNeoBytes), ceInstance)
    }

    func testTier0DeterministicRNGAndTranscriptChallengesBindAbsorbedBytes() throws {
        let seed = Array("deterministic-rng-byte-stream".utf8)
        var rng = DeterministicRNG(seed: seed)
        var reference = ReferenceDeterministicRNG(seed: seed)
        for _ in 0..<40 {
            XCTAssertEqual(rng.nextUInt64(), reference.nextUInt64())
        }

        var ringRng = DeterministicRNG(seed: Array("deterministic-rng-ring".utf8))
        var ringReference = ReferenceDeterministicRNG(seed: Array("deterministic-rng-ring".utf8))
        XCTAssertEqual(ringRng.nextChallengeRing(), ringReference.nextChallengeRing())

        let transcriptDomain = "deterministic-transcript"
        let transcriptSeed = Array("bound-seed".utf8)
        let payload = Array("absorbed-payload".utf8)
        var transcript = SumCheckTranscript(domainSeparator: transcriptDomain, seed: transcriptSeed)
        transcript.absorb(payload)
        var replay = SumCheckTranscript(domainSeparator: transcriptDomain, seed: transcriptSeed)
        replay.absorb(payload)
        var differentPayload = SumCheckTranscript(domainSeparator: transcriptDomain, seed: transcriptSeed)
        differentPayload.absorb(Array("different-absorbed-payload".utf8))

        let field = transcript.challengeField()
        XCTAssertEqual(field, replay.challengeField())
        XCTAssertNotEqual(field, differentPayload.challengeField())

        let ext2 = transcript.challengeExt2()
        XCTAssertEqual(ext2, replay.challengeExt2())
        XCTAssertNotEqual(ext2, differentPayload.challengeExt2())

        let ring = transcript.challengeRing()
        XCTAssertEqual(ring, replay.challengeRing())
        XCTAssertNotEqual(ring, differentPayload.challengeRing())
    }

    func testTier0CyclotomicRingSeededLawsAndEmbedding() throws {
        let x27 = monomialRing(27)
        let x54 = monomialRing(54)
        let x108 = monomialRing(108)
        XCTAssertEqual(x54 + x27 + .one, .zero)
        XCTAssertEqual(x108, x27)

        var high = Array(repeating: GoldilocksField.zero, count: 55)
        high[54] = .one
        let reduced = CyclotomicRing54(high)
        XCTAssertEqual(reduced[0], -GoldilocksField.one)
        XCTAssertEqual(reduced[27], -GoldilocksField.one)

        var generator = SeededTestGenerator(seed: 0x434C_4F54_4F4D_4943)
        for _ in 0..<32 {
            let a = generator.ring()
            let b = generator.ring()
            let c = generator.ring()
            let scalar = generator.field()

            XCTAssertEqual(a + b, b + a)
            XCTAssertEqual(a * .one, a)
            XCTAssertEqual(a * b, b * a)
            XCTAssertEqual(a.multipliedConstantWork(by: b), a * b)
            XCTAssertEqual((a * b) * c, a * (b * c))
            XCTAssertEqual(a * (b + c), (a * b) + (a * c))
            XCTAssertEqual(a.scaled(by: scalar), CyclotomicRing54(a.coefficients.map { $0 * scalar }))
            let scalarRing = CyclotomicRing54([scalar])
            XCTAssertEqual(scalarRing * a, a.scaled(by: scalar))
            XCTAssertEqual(a * scalarRing, a.scaled(by: scalar))
            let extRing = CyclotomicExt2Ring54(a.coefficients.map { GoldilocksExt2($0, scalar) })
            XCTAssertEqual(scalarRing * extRing, extRing.scaled(by: scalar))
            XCTAssertEqual(extRing * scalarRing, extRing.scaled(by: scalar))
            XCTAssertEqual(try CyclotomicRing54(littleEndianBytes: a.littleEndianBytes), a)
        }

        let ringMatrixElements = (0..<9).map { _ in generator.ring() }
        let ringMatrix = try RingMatrix(rows: 3, columns: 3, elements: ringMatrixElements)
        let sparseRingMatrix = try SparseRingMatrixCSR(ringMatrix)
        let ringVector = (0..<3).map { _ in generator.ring() }
        XCTAssertEqual(
            try ringMatrix.multipliedConstantWork(by: ringVector),
            try ringMatrix.multiplied(by: ringVector)
        )
        XCTAssertEqual(
            try sparseRingMatrix.multipliedConstantWork(by: ringVector),
            try sparseRingMatrix.multiplied(by: ringVector)
        )

        let vector = (0..<109).map { GoldilocksField(UInt64(($0 * 17 + 5) % 251)) }
        let padded = try SuperNeoEmbedding.packPadded(vector)
        let unpacked = SuperNeoEmbedding.unpack(padded)
        XCTAssertEqual(Array(unpacked.prefix(vector.count)), vector)
        XCTAssertEqual(Array(unpacked.dropFirst(vector.count)), Array(repeating: .zero, count: 53))
        XCTAssertTrue(try SuperNeoEmbedding.preservesNorm(Array(unpacked)))

        XCTAssertThrowsSuperNeoError(
            try SuperNeoEmbedding.pack(Array(vector.prefix(55))),
            .invalidParameter("field vector length must be a multiple of 54")
        )
        XCTAssertThrowsSuperNeoError(
            try CyclotomicRing54(littleEndianBytes: Array(CyclotomicRing54.one.littleEndianBytes.dropLast())),
            .invalidEncoding("ring element must be 432 bytes")
        )
        XCTAssertThrowsSuperNeoError(
            try RingMatrix(rows: Int.max, columns: 2, elements: []),
            .invalidParameter("ring matrix dimensions do not match element count")
        )
        XCTAssertThrowsSuperNeoError(
            try SparseRingMatrixCSR(
                rows: Int.max,
                columns: 1,
                rowOffsets: [0],
                columnIndices: [],
                values: []
            ),
            .invalidParameter("sparse ring row offsets must have rows + 1 entries and start at zero")
        )
        XCTAssertThrowsSuperNeoError(
            try SparseRingMatrixCSR(
                rows: 2,
                columns: 3,
                rowOffsets: [0, 2, 1],
                columnIndices: [0],
                values: [.one]
            ),
            .invalidParameter("sparse ring row offsets out of bounds")
        )
    }

    func testTier0SmallCoefficientRingProductsMatchReferenceReduction() {
        var challengeRNG = DeterministicRNG(seed: Array("small-ring-product-reference".utf8))
        var generator = SeededTestGenerator(seed: 0x534D_414C_4C52_494E)

        for _ in 0..<16 {
            let challenge = challengeRNG.nextChallengeRing()
            let ring = generator.ring()
            XCTAssertEqual(challenge * ring, referenceRingProduct(challenge, ring))
            XCTAssertEqual(ring * challenge, referenceRingProduct(ring, challenge))

            let extRing = CyclotomicExt2Ring54(
                (0..<CyclotomicRing54.degree).map { _ in
                    GoldilocksExt2(generator.field(), generator.field())
                }
            )
            XCTAssertEqual(challenge * extRing, referenceExtensionRingProduct(challenge, extRing))
            XCTAssertEqual(extRing * challenge, referenceExtensionRingProduct(challenge, extRing))
        }
    }

}

final class CommitmentCoreTests: SuperNeoTestCase {
    func testTier0AjtaiCommitmentSeededLinearityCorpus() throws {
        var generator = SeededTestGenerator(seed: 0x414A_5441_4943_4F4D)
        for columns in [1, 2, 4] {
            let keyA = try AjtaiCommitmentKey(columns: columns, seed: Array("ajtai-\(columns)".utf8))
            let keyB = try AjtaiCommitmentKey(columns: columns, seed: Array("ajtai-\(columns)".utf8))
            XCTAssertEqual(keyA, keyB)

            for _ in 0..<8 {
                let messageA = (0..<columns).map { _ in generator.ring() }
                let messageB = (0..<columns).map { _ in generator.ring() }
                let commitA = try AjtaiCommitter.commitReference(key: keyA, message: messageA)
                let commitB = try AjtaiCommitter.commitReference(key: keyA, message: messageB)
                let combinedMessage = zip(messageA, messageB).map(+)
                let combinedCommit = try AjtaiCommitter.commitReference(key: keyA, message: combinedMessage)
                XCTAssertEqual(commitA + commitB, combinedCommit)
                let scalar = generator.field()
                XCTAssertEqual(commitA.scaled(by: CyclotomicRing54([scalar])), commitA.scaled(by: scalar))
            }
        }

        let key = try AjtaiCommitmentKey(columns: 2, seed: Array("columns".utf8))
        XCTAssertThrowsSuperNeoError(
            try AjtaiCommitter.commitReference(key: key, fieldWitness: Array(repeating: .one, count: 54)),
            .invalidParameter("Ajtai packed witness has 1 ring columns, expected 2")
        )
        XCTAssertThrowsSuperNeoError(
            try AjtaiCommitter.commitReference(key: key, message: [CyclotomicRing54.one]),
            .invalidParameter("ring matrix/vector dimension mismatch")
        )
    }

    func testTier0AjtaiSeededKeyRejectsDimensionOverflowBeforeAllocation() {
        let overflowingColumns = (Int.max / SuperNeoParameters.goldilocks.kappa) + 1
        XCTAssertThrowsSuperNeoError(
            try AjtaiCommitmentKey(columns: overflowingColumns, seed: Array("overflow".utf8)),
            .invalidParameter("Ajtai key dimensions overflow")
        )
    }

    func testTier0AjtaiWorkProfileTracksSparseSmallCoefficientCost() throws {
        let rows = SuperNeoParameters.goldilocks.kappa
        let columns = 2
        let matrixElements = (0..<rows).flatMap { row in
            (0..<columns).map { column in
                var coefficients = Array(repeating: GoldilocksField.zero, count: CyclotomicRing54.degree)
                coefficients[0] = .one
                coefficients[1 + ((row * columns + column) % (CyclotomicRing54.degree - 1))] =
                    GoldilocksField(UInt64(7 + row + column))
                return CyclotomicRing54(coefficients)
            }
        }
        let key = try AjtaiCommitmentKey(
            matrix: try RingMatrix(rows: rows, columns: columns, elements: matrixElements)
        )

        func ring(_ entries: [(Int, GoldilocksField)]) -> CyclotomicRing54 {
            var coefficients = Array(repeating: GoldilocksField.zero, count: CyclotomicRing54.degree)
            for (index, value) in entries {
                coefficients[index] = value
            }
            return CyclotomicRing54(coefficients)
        }

        let binaryMessage = [
            ring([(0, .one), (13, .one), (53, .one)]),
            ring([(1, .one), (27, .one), (40, .one)])
        ]
        let binaryProfile = try AjtaiCommitter.workProfile(key: key, message: binaryMessage)
        XCTAssertEqual(binaryProfile.matrixRows, rows)
        XCTAssertEqual(binaryProfile.matrixColumns, columns)
        XCTAssertEqual(binaryProfile.ringDegree, CyclotomicRing54.degree)
        XCTAssertEqual(binaryProfile.messageCoefficientSlots, columns * CyclotomicRing54.degree)
        XCTAssertEqual(binaryProfile.nonzeroMessageCoefficients, 6)
        XCTAssertEqual(binaryProfile.smallMessageCoefficients, 6)
        XCTAssertEqual(binaryProfile.fullWidthMessageCoefficients, 0)
        XCTAssertEqual(binaryProfile.skippedZeroMessageCoefficients, columns * CyclotomicRing54.degree - 6)
        XCTAssertEqual(binaryProfile.activeRotationTerms, rows * 6)
        XCTAssertEqual(binaryProfile.smallCoefficientScalings, rows * 6 * 2)
        XCTAssertEqual(binaryProfile.fullWidthCoefficientScalings, 0)
        XCTAssertTrue(binaryProfile.usesOnlySmallCoefficientScalings)
        XCTAssertLessThan(binaryProfile.activeRotationTerms, rows * columns * CyclotomicRing54.degree)
        XCTAssertEqual(
            try AjtaiCommitter.commitReference(key: key, message: binaryMessage),
            AjtaiCommitment(try key.matrix.multiplied(by: binaryMessage))
        )

        let smallAndFullMessage = [
            ring([(0, GoldilocksField(3)), (1, -GoldilocksField(3)), (2, GoldilocksField(2))]),
            ring([(5, GoldilocksField(5)), (6, -GoldilocksField(2))])
        ]
        let mixedProfile = try AjtaiCommitter.workProfile(key: key, message: smallAndFullMessage)
        XCTAssertEqual(mixedProfile.nonzeroMessageCoefficients, 5)
        XCTAssertEqual(mixedProfile.smallMessageCoefficients, 2)
        XCTAssertEqual(mixedProfile.fullWidthMessageCoefficients, 3)
        XCTAssertEqual(mixedProfile.activeRotationTerms, rows * 5)
        XCTAssertEqual(mixedProfile.smallCoefficientScalings, rows * 2 * 2)
        XCTAssertEqual(mixedProfile.fullWidthCoefficientScalings, rows * 3 * 2)
        XCTAssertFalse(mixedProfile.usesOnlySmallCoefficientScalings)
        XCTAssertEqual(
            try AjtaiCommitter.commitReference(key: key, message: smallAndFullMessage),
            AjtaiCommitment(try key.matrix.multiplied(by: smallAndFullMessage))
        )

        XCTAssertThrowsSuperNeoError(
            try AjtaiCommitter.workProfile(key: key, message: [CyclotomicRing54.one]),
            .invalidParameter("ring matrix/vector dimension mismatch")
        )
    }

    func testTier0AjtaiConstantWorkReferenceMatchesOptimizedReference() throws {
        var generator = SeededTestGenerator(seed: 0x4354_414A_5441_4958)
        let key = try AjtaiCommitmentKey(columns: 3, seed: Array("constant-work-ajtai".utf8))

        for _ in 0..<8 {
            let message = (0..<key.matrix.columns).map { _ in generator.ring() }
            XCTAssertEqual(
                try AjtaiCommitter.commitConstantWorkReference(key: key, message: message),
                try AjtaiCommitter.commitReference(key: key, message: message)
            )
        }

        let smallWitness = (0..<(key.matrix.columns * CyclotomicRing54.degree)).map { index in
            [GoldilocksField.zero, .one, -GoldilocksField.one, GoldilocksField(2)][index % 4]
        }
        XCTAssertEqual(
            try AjtaiCommitter.commitConstantWorkReference(key: key, fieldWitness: smallWitness),
            try AjtaiCommitter.commitReference(key: key, fieldWitness: smallWitness)
        )
    }

    func testAjtaiCommitmentSchemeBoundaryVerifiesAndRejectsBadOpenings() throws {
        let workload = try SuperNeoOneHotVectorWorkload(bitCount: 8)
        let prepared = try workload.prepareForFolding(
            bits: [false, false, true, false, false, false, false, false],
            keySeed: Array("commitment-scheme-source".utf8)
        )
        let shape = prepared.publicFoldInput.shape
        let keyPair = try AjtaiSuperNeoCommitment.setup(
            shape: shape,
            seed: Array("commitment-scheme-key".utf8)
        )
        XCTAssertEqual(keyPair.proverKey, keyPair.verifierKey)
        XCTAssertEqual(AjtaiSuperNeoCommitment.digest(keyPair.verifierKey), keyPair.verifierKey.verifierKeyDigest)

        let instance = prepared.foldInput.instances[0]
        let witness = prepared.foldInput.witnesses[0].fullZ(for: instance)
        let commitment = try AjtaiSuperNeoCommitment.commit(
            proverKey: keyPair.proverKey,
            shape: shape,
            message: witness,
            executionPolicy: .highAssurance
        )
        XCTAssertTrue(try AjtaiSuperNeoCommitment.verifyOpening(
            verifierKey: keyPair.verifierKey,
            shape: shape,
            message: witness,
            commitment: commitment,
            executionPolicy: .highAssurance
        ))

        var badWitness = witness
        badWitness[0] = badWitness[0] + .one
        XCTAssertFalse(try AjtaiSuperNeoCommitment.verifyOpening(
            verifierKey: keyPair.verifierKey,
            shape: shape,
            message: badWitness,
            commitment: commitment,
            executionPolicy: .highAssurance
        ))

        let wrongShapeKey = try AjtaiCommitmentKey(
            columns: shape.nRing + 1,
            seed: Array("wrong-shape-key".utf8)
        )
        XCTAssertThrowsSuperNeoError(
            try AjtaiSuperNeoCommitment.commit(
                proverKey: wrongShapeKey,
                shape: shape,
                message: witness
            ),
            .invalidParameter("Ajtai prover key column count must match shape.nRing")
        )
    }

    func testAjtaiCommitmentSchemeBatchMatchesSingleCommitments() throws {
        let workload = try SuperNeoOneHotVectorWorkload(bitCount: 4)
        let preparedA = try workload.prepareForFolding(
            bits: [true, false, false, false],
            keySeed: Array("batch-a-source".utf8)
        )
        let preparedB = try workload.prepareForFolding(
            bits: [false, false, true, false],
            keySeed: Array("batch-b-source".utf8)
        )
        let shape = preparedA.publicFoldInput.shape
        let keyPair = try AjtaiSuperNeoCommitment.setup(
            shape: shape,
            seed: Array("batch-commitment-key".utf8)
        )
        let messages = [
            preparedA.foldInput.witnesses[0].fullZ(for: preparedA.foldInput.instances[0]),
            preparedB.foldInput.witnesses[0].fullZ(for: preparedB.foldInput.instances[0])
        ]
        let batch = try AjtaiSuperNeoCommitment.batchCommit(
            proverKey: keyPair.proverKey,
            shape: shape,
            messages: messages,
            executionPolicy: .highAssurance
        )
        let singles = try messages.map {
            try AjtaiSuperNeoCommitment.commit(
                proverKey: keyPair.proverKey,
                shape: shape,
                message: $0,
                executionPolicy: .highAssurance
            )
        }
        XCTAssertEqual(batch, singles)
    }

    func testAjtaiCommitmentKeySerializationRoundTripsAndRejectsProfileMutation() throws {
        let workload = try SuperNeoOneHotVectorWorkload(bitCount: 4)
        let prepared = try workload.prepareForFolding(
            bits: [false, true, false, false],
            keySeed: Array("key-wire-source".utf8)
        )
        let keyPair = try AjtaiSuperNeoCommitment.setup(
            shape: prepared.publicFoldInput.shape,
            seed: Array("key-wire-key".utf8)
        )
        let randomKeyPair = try AjtaiSuperNeoCommitment.setup(shape: prepared.publicFoldInput.shape)
        XCTAssertEqual(randomKeyPair.proverKey.matrix.columns, prepared.publicFoldInput.shape.nRing)
        XCTAssertEqual(
            AjtaiSuperNeoCommitment.digest(randomKeyPair.verifierKey),
            randomKeyPair.verifierKey.verifierKeyDigest
        )

        let encoded = keyPair.verifierKey.superNeoBytes
        XCTAssertEqual(try AjtaiCommitmentKey(bytes: encoded), keyPair.verifierKey)

        var wrongProfile = encoded
        wrongProfile[6] = 2
        XCTAssertThrowsSuperNeoError(
            try AjtaiCommitmentKey(bytes: wrongProfile),
            .invalidEncoding("unsupported Ajtai key profile")
        )

        XCTAssertThrowsSuperNeoError(
            try AjtaiCommitmentKey(bytes: Array(encoded.dropLast())),
            .invalidEncoding("Ajtai key element count exceeds remaining byte capacity")
        )
    }

}

final class EvaluationCoreTests: SuperNeoTestCase {
    func testTier0MultilinearEvaluationMatchesDirectHypercubeOracle() throws {
        var generator = SeededTestGenerator(seed: 0x4D55_4C54_494C_494E)
        for dimension in 1...6 {
            for _ in 0..<16 {
                let vector = (0..<(1 << dimension)).map { _ in generator.field() }
                let point = (0..<dimension).map { _ in generator.ext2() }
                let basis = try MultilinearEvaluation.checkedBasis(at: point)

                XCTAssertEqual(basis.reduce(.zero, +), .one)
                XCTAssertEqual(basis, directMultilinearBasis(at: point))
                XCTAssertEqual(
                    try MultilinearEvaluation.evaluate(vector, at: point),
                    directMultilinearEvaluation(vector, at: point)
                )
                for index in vector.indices {
                    let booleanPoint = (0..<dimension).map { bit in
                        ((index >> bit) & 1) == 0 ? GoldilocksExt2.zero : .one
                    }
                    XCTAssertEqual(try MultilinearEvaluation.evaluate(vector, at: booleanPoint), GoldilocksExt2(vector[index]))
                }
            }
        }

        let point = [
            GoldilocksExt2(GoldilocksField(2), GoldilocksField(1)),
            GoldilocksExt2(GoldilocksField(3), GoldilocksField(4))
        ]
        XCTAssertThrowsSuperNeoError(
            try MultilinearEvaluation.evaluate([.one, .one, .one], at: point),
            .invalidParameter("vector length must equal 2^point.count")
        )
        XCTAssertThrowsSuperNeoError(
            try MultilinearEvaluation.eq(point, [.one]),
            .invalidParameter("eq vector length mismatch")
        )
    }

    func testTier0MultilinearEqMatchesOriginalProductFormula() throws {
        var generator = SeededTestGenerator(seed: 0x4551_504F_4C59_4E4F)
        for dimension in 1...8 {
            for _ in 0..<16 {
                let lhs = (0..<dimension).map { _ in generator.ext2() }
                let rhs = (0..<dimension).map { _ in generator.ext2() }
                let expected = zip(lhs, rhs).reduce(GoldilocksExt2.one) { partial, pair in
                    let (a, b) = pair
                    return partial * (a * b + (.one - a) * (.one - b))
                }

                XCTAssertEqual(try MultilinearEvaluation.eq(lhs, rhs), expected)
            }
        }
    }

}

final class ProtocolShapeTests: SuperNeoTestCase {
    // MARK: - Tier 1: transcript, matrix, and shape soundness

    func testRealSumcheckVerifierAcceptsTranscriptBoundProof() throws {
        let proof = makeToySumcheckProof()
        var transcript = SumCheckTranscript(domainSeparator: "test.sumcheck")

        let accepted = try SumcheckVerifier.verify(
            proof: proof,
            transcript: &transcript,
            expectedDegree: 1,
            expectedRoundCount: 2
        ) { point, value in
            value == toySumcheckPolynomial(point[0], point[1])
        }

        XCTAssertTrue(accepted)
    }

    func testSumcheckProverProofIsTranscriptAndFinalCheckBound() throws {
        let evaluator: ([GoldilocksExt2]) throws -> GoldilocksExt2 = { point in
            self.toySumcheckPolynomial(point[0], point[1])
        }
        let claimed = try (0..<4).reduce(GoldilocksExt2.zero) { partial, bits in
            let x = (bits & 1) == 0 ? GoldilocksExt2.zero : .one
            let y = (bits & 2) == 0 ? GoldilocksExt2.zero : .one
            return partial + (try evaluator([x, y]))
        }
        var proverTranscript = SumCheckTranscript(domainSeparator: "strict.sumcheck", seed: Array("seed".utf8))
        var oracle = try EvaluatingSumcheckOracle(numVars: 2, maxDegreePerRound: 1, evaluator: evaluator)
        let proof = try SumcheckProver.prove(oracle: &oracle, claimedSum: claimed, transcript: &proverTranscript)

        var verifierTranscript = SumCheckTranscript(domainSeparator: "strict.sumcheck", seed: Array("seed".utf8))
        XCTAssertTrue(
            try SumcheckVerifier.verify(
                proof: proof,
                transcript: &verifierTranscript,
                expectedDegree: 1,
                expectedRoundCount: 2
            ) { point, value in
                try evaluator(point) == value
            }
        )

        verifierTranscript = SumCheckTranscript(domainSeparator: "strict.sumcheck", seed: Array("wrong-seed".utf8))
        XCTAssertFalse(
            try SumcheckVerifier.verify(
                proof: proof,
                transcript: &verifierTranscript,
                expectedDegree: 1,
                expectedRoundCount: 2
            ) { point, value in
                try evaluator(point) == value
            }
        )

        verifierTranscript = SumCheckTranscript(domainSeparator: "strict.sumcheck", seed: Array("seed".utf8))
        XCTAssertFalse(
            try SumcheckVerifier.verify(
                proof: proof,
                transcript: &verifierTranscript,
                expectedDegree: 1,
                expectedRoundCount: 2
            ) { _, _ in
                false
            }
        )
    }

    func testSumcheckProverRejectsOracleClaimMismatch() throws {
        let evaluator: ([GoldilocksExt2]) throws -> GoldilocksExt2 = { point in
            point[0]
        }
        var oracle = try EvaluatingSumcheckOracle(numVars: 1, maxDegreePerRound: 1, evaluator: evaluator)
        var transcript = SumCheckTranscript(domainSeparator: "strict.sumcheck.invalid")

        XCTAssertThrowsSuperNeoError(
            try SumcheckProver.prove(oracle: &oracle, claimedSum: .zero, transcript: &transcript),
            .invalidParameter("sum-check oracle round polynomial does not match running claim")
        )
    }

    func testRealSumcheckVerifierRejectsTamperedRoundPolynomial() throws {
        let proof = makeToySumcheckProof()
        let badRound = SumcheckRound(coeffs: [proof.rounds[0].coeffs[0] + .one, proof.rounds[0].coeffs[1]])
        let tampered = SumcheckProof(
            claimedSum: proof.claimedSum,
            rounds: [badRound, proof.rounds[1]],
            finalPoint: proof.finalPoint,
            finalValue: proof.finalValue
        )
        var transcript = SumCheckTranscript(domainSeparator: "test.sumcheck")

        let accepted = try SumcheckVerifier.verify(
            proof: tampered,
            transcript: &transcript,
            expectedDegree: 1,
            expectedRoundCount: 2
        ) { _, _ in true }

        XCTAssertFalse(accepted)
    }

    func testRealSumcheckVerifierRejectsWrongDegreeAndFinalPoint() throws {
        let proof = makeToySumcheckProof()
        var tooHighDegreeRounds = proof.rounds
        tooHighDegreeRounds[0] = SumcheckRound(coeffs: proof.rounds[0].coeffs + [.zero])
        let tooHighDegree = SumcheckProof(
            claimedSum: proof.claimedSum,
            rounds: tooHighDegreeRounds,
            finalPoint: proof.finalPoint,
            finalValue: proof.finalValue
        )
        var transcript = SumCheckTranscript(domainSeparator: "test.sumcheck")
        XCTAssertFalse(
            try SumcheckVerifier.verify(
                proof: tooHighDegree,
                transcript: &transcript,
                expectedDegree: 1,
                expectedRoundCount: 2
            ) { _, _ in true }
        )

        let wrongPoint = SumcheckProof(
            claimedSum: proof.claimedSum,
            rounds: proof.rounds,
            finalPoint: [proof.finalPoint[0] + .one, proof.finalPoint[1]],
            finalValue: proof.finalValue
        )
        transcript = SumCheckTranscript(domainSeparator: "test.sumcheck")
        XCTAssertFalse(
            try SumcheckVerifier.verify(
                proof: wrongPoint,
                transcript: &transcript,
                expectedDegree: 1,
                expectedRoundCount: 2
            ) { _, _ in true }
        )
    }

    func testSuperNeoMatrixTransformMatchesFieldMatrixVector() throws {
        let entries = [
            SparseFieldMatrix.Entry(row: 0, column: 0, value: GoldilocksField(3)),
            SparseFieldMatrix.Entry(row: 0, column: 17, value: GoldilocksField(5)),
            SparseFieldMatrix.Entry(row: 1, column: 9, value: GoldilocksField(7)),
            SparseFieldMatrix.Entry(row: 1, column: 53, value: GoldilocksField(11))
        ]
        let matrix = try SparseFieldMatrix(rows: 2, columns: 54, entries: entries)
        let vector = (0..<54).map { GoldilocksField(UInt64($0 + 1)) }

        let fieldProduct = try matrix.multiplied(by: vector)
        let ringConstants = try SuperNeoCPUBackend().matrixVectorConstants(matrix: matrix, vector: vector)
        let denseRows = try matrix.transformedForSuperNeo().multiplied(by: SuperNeoEmbedding.packPadded(vector))
        let sparseRows = try matrix.transformedSparseForSuperNeo().multiplied(by: SuperNeoEmbedding.packPadded(vector))

        XCTAssertEqual(ringConstants, fieldProduct)
        XCTAssertEqual(sparseRows, denseRows)
    }

    func testSuperNeoMatrixTransformHandlesMultipleRingColumnsAndDuplicateEntries() throws {
        let entries = [
            SparseFieldMatrix.Entry(row: 0, column: 0, value: GoldilocksField(3)),
            SparseFieldMatrix.Entry(row: 0, column: 54, value: GoldilocksField(5)),
            SparseFieldMatrix.Entry(row: 1, column: 17, value: GoldilocksField(7)),
            SparseFieldMatrix.Entry(row: 1, column: 17, value: GoldilocksField(11)),
            SparseFieldMatrix.Entry(row: 2, column: 69, value: GoldilocksField(13)),
            SparseFieldMatrix.Entry(row: 3, column: 1, value: GoldilocksField(19))
        ]
        let matrix = try SparseFieldMatrix(rows: 4, columns: 70, entries: entries)
        let vector = (0..<70).map { GoldilocksField(UInt64(($0 * 9 + 4) % 29)) }

        XCTAssertEqual(
            try SuperNeoCPUBackend().matrixVectorConstants(matrix: matrix, vector: vector),
            try matrix.multiplied(by: vector)
        )
        XCTAssertEqual(
            try matrix.transformedSparseForSuperNeo().multiplied(by: SuperNeoEmbedding.packPadded(vector)),
            try matrix.transformedForSuperNeo().multiplied(by: SuperNeoEmbedding.packPadded(vector))
        )
        let packedVector = try SuperNeoEmbedding.packPadded(vector)
        let denseTransformed = try matrix.transformedForSuperNeo()
        let sparseTransformed = try matrix.transformedSparseForSuperNeo()
        let point = [
            GoldilocksExt2(GoldilocksField(3), GoldilocksField(5)),
            GoldilocksExt2(GoldilocksField(7), GoldilocksField(11))
        ]
        let rHat = try MultilinearEvaluation.checkedBasis(at: point)
        let expectedRows = try sparseTransformed.multiplied(by: packedVector)
        let expectedEvaluation = CyclotomicExt2Ring54(directTransformedEvaluation(rows: expectedRows, rHat: rHat))

        XCTAssertEqual(try denseTransformed.evaluatedProduct(by: packedVector, rHat: rHat), expectedEvaluation)
        XCTAssertEqual(try sparseTransformed.evaluatedProduct(by: packedVector, rHat: rHat), expectedEvaluation)
        XCTAssertEqual(try denseTransformed.evaluatedProductConstantWork(by: packedVector, rHat: rHat), expectedEvaluation)
        XCTAssertEqual(try sparseTransformed.evaluatedProductConstantWork(by: packedVector, rHat: rHat), expectedEvaluation)
        XCTAssertEqual(
            try SuperNeoCPUBackend().transformedEvaluation(matrix: denseTransformed, vector: packedVector, point: point),
            expectedEvaluation.coefficients
        )
        XCTAssertEqual(
            try SuperNeoCPUBackend().transformedEvaluation(matrix: sparseTransformed, vector: packedVector, point: point),
            expectedEvaluation.coefficients
        )
        XCTAssertThrowsSuperNeoError(
            try matrix.multiplied(by: Array(vector.dropLast())),
            .invalidParameter("field matrix/vector mismatch")
        )
    }

    func testSuperNeoCSRTransformMatchesIndependentUnitVectorOracle() throws {
        let entries = [
            SparseFieldMatrix.Entry(row: 0, column: 0, value: GoldilocksField(3)),
            SparseFieldMatrix.Entry(row: 0, column: 53, value: GoldilocksField(5)),
            SparseFieldMatrix.Entry(row: 0, column: 54, value: GoldilocksField(7)),
            SparseFieldMatrix.Entry(row: 1, column: 62, value: GoldilocksField(11)),
            SparseFieldMatrix.Entry(row: 1, column: 62, value: GoldilocksField(13)),
            SparseFieldMatrix.Entry(row: 2, column: 107, value: GoldilocksField(17)),
            SparseFieldMatrix.Entry(row: 2, column: 118, value: GoldilocksField(19)),
            SparseFieldMatrix.Entry(row: 2, column: 13, value: GoldilocksField(23))
        ]
        let matrix = try SparseFieldMatrix(rows: 3, columns: 119, entries: entries)
        let csr = try SparseMatrixCSR(matrix)
        let oracle = try independentUnitVectorTransformedMatrix(matrix)
        let packedVector = try SuperNeoEmbedding.packPadded(
            (0..<119).map { GoldilocksField(UInt64(($0 * 19 + 3) % 251)) }
        )

        XCTAssertEqual(try csr.transformedForSuperNeo(), oracle)
        XCTAssertEqual(try csr.transformedSparseForSuperNeo().dense(), oracle)
        XCTAssertEqual(try matrix.transformedForSuperNeo(), oracle)
        XCTAssertEqual(try matrix.transformedSparseForSuperNeo().dense(), oracle)
        XCTAssertEqual(
            try csr.transformedSparseForSuperNeo().multiplied(by: packedVector),
            try oracle.multiplied(by: packedVector)
        )
    }

    func testSparseMatrixCSRCanonicalizesAndRejectsNonCanonicalRows() throws {
        let matrix = try SparseFieldMatrix(
            rows: 2,
            columns: 4,
            entries: [
                SparseFieldMatrix.Entry(row: 0, column: 3, value: GoldilocksField(5)),
                SparseFieldMatrix.Entry(row: 0, column: 3, value: GoldilocksField(7)),
                SparseFieldMatrix.Entry(row: 0, column: 1, value: GoldilocksField(9)),
                SparseFieldMatrix.Entry(row: 1, column: 2, value: GoldilocksField(4)),
                SparseFieldMatrix.Entry(row: 1, column: 2, value: -GoldilocksField(4)),
                SparseFieldMatrix.Entry(row: 1, column: 0, value: .zero)
            ]
        )
        let csr = try SparseMatrixCSR(matrix)

        XCTAssertEqual(csr.rowOffsets, [0, 2, 2])
        XCTAssertEqual(csr.columnIndices, [1, 3])
        XCTAssertEqual(csr.values, [GoldilocksField(9), GoldilocksField(12)])
        let vector = [GoldilocksField.one, .one, .one, .one]
        XCTAssertEqual(try csr.multiplied(by: vector), [GoldilocksField(21), .zero])
        XCTAssertEqual(try csr.multiplied(by: vector), try csr.toSparseFieldMatrix().multiplied(by: vector))
        XCTAssertThrowsSuperNeoError(
            try csr.multiplied(by: [.one, .one, .one]),
            .invalidParameter("field matrix/vector mismatch")
        )
        XCTAssertThrowsSuperNeoError(
            try SparseMatrixCSR(rowCount: 1, columnCount: 4, rowOffsets: [0, 2], columnIndices: [2, 1], values: [.one, .one]),
            .invalidParameter("CSR column indices must be strictly increasing within each row")
        )
        XCTAssertThrowsSuperNeoError(
            try SparseMatrixCSR(rowCount: 1, columnCount: 4, rowOffsets: [0, 1], columnIndices: [0], values: [.zero]),
            .invalidParameter("CSR matrices must omit zero entries")
        )
        XCTAssertThrowsSuperNeoError(
            try SparseMatrixCSR(
                rowCount: 2,
                columnCount: 4,
                rowOffsets: [0, 2, 1],
                columnIndices: [0],
                values: [.one]
            ),
            .invalidParameter("CSR row offsets out of bounds")
        )
    }

    func testCCSShapeEncodingRoundTripsAndBindsDigest() throws {
        let identity = try SparseFieldMatrix.identity(size: 2)
        let shape = try CCSShape.hadamardProduct(matrices: [identity], publicInputCount: 2)

        let reparsed = try CCSShape(bytes: shape.superNeoBytes)

        XCTAssertEqual(reparsed, shape)
        XCTAssertEqual(reparsed.shapeDigest, shape.shapeDigest)
        XCTAssertEqual(reparsed.matrices[0], try SparseMatrixCSR(identity))
        XCTAssertTrue(reparsed.hasIdentityFirstMatrix)
    }

    func testGoldilocksParameterProfileMatchesPaperProfile() {
        let profile = SuperNeoParameterProfile.goldilocksPhi81

        XCTAssertEqual(profile.profileID, SuperNeoParameters.goldilocks.profileID)
        XCTAssertEqual(profile.parameters.kappa, 18)
        XCTAssertEqual(profile.parameters.normBound, 2)
        XCTAssertEqual(profile.parameters.normRoots, [-.one, .zero, .one])
        XCTAssertEqual(profile.normRoots, profile.parameters.normRoots)
        XCTAssertEqual(profile.parameters.decompositionLength, 14)
        XCTAssertEqual(profile.parameters.challengeCoefficients, [-2, -1, 0, 1, 2])
        XCTAssertEqual(profile.parameters.challengeExpansionFactor, 216)
        XCTAssertEqual(profile.maxFreshBatchCount, 61)
        XCTAssertEqual(profile.claimedSecurityBits, 129)
        XCTAssertEqual(profile.cyclotomicIndex, 81)
        XCTAssertEqual(profile.cyclotomicRelationCoefficients.count, CyclotomicRing54.degree + 1)
    }

    func testCCSShapeRejectsTamperedDigest() throws {
        let shape = try CCSShape.hadamardProduct(matrices: [SparseFieldMatrix.identity(size: 2)], publicInputCount: 2)
        var bytes = shape.superNeoBytes
        bytes[0] ^= 1

        XCTAssertThrowsError(try CCSShape(bytes: bytes)) { error in
            XCTAssertEqual(error as? SuperNeoError, .invalidEncoding("CCS shape digest mismatch"))
        }
    }

    func testCCSShapeReaderRejectsHugeCSRCountsBeforeAllocation() throws {
        let shape = try CCSShape.hadamardProduct(matrices: [SparseFieldMatrix.identity(size: 2)], publicInputCount: 1)
        var bytes = shape.superNeoBytes
        let firstCSRRowCountOffset = 602
        let firstCSRRowOffsetCountOffset = 618
        writeUInt64(UInt64(1 << 30), into: &bytes, at: firstCSRRowCountOffset)
        writeUInt64(UInt64(1 << 30), into: &bytes, at: firstCSRRowOffsetCountOffset)

        XCTAssertThrowsSuperNeoError(
            try CCSShape(bytes: bytes),
            .invalidEncoding("CSR row offset count exceeds remaining byte capacity")
        )
    }

    func testCCSShapeRejectsNonCanonicalRelationAndDescriptorBytes() throws {
        let monomials = [
            RelationMonomial(coefficient: .one, exponents: [1, 0]),
            RelationMonomial(coefficient: GoldilocksField(2), exponents: [0, 1]),
            RelationMonomial(coefficient: GoldilocksField(3), exponents: [1, 0])
        ]
        let polynomial = try RelationPolynomial(variableCount: 2, monomials: monomials)
        XCTAssertEqual(
            polynomial.monomials,
            [
                RelationMonomial(coefficient: GoldilocksField(2), exponents: [0, 1]),
                RelationMonomial(coefficient: GoldilocksField(4), exponents: [1, 0])
            ]
        )

        XCTAssertThrowsSuperNeoError(
            try RelationPolynomial(variableCount: 2, monomials: [RelationMonomial(coefficient: .one, exponents: [1])]),
            .invalidParameter("relation monomial exponent count must match variable count")
        )
        XCTAssertThrowsSuperNeoError(
            try StrongSamplingSetDescriptor(coefficientSet: [0, -1, 1], expansionFactor: 1),
            .invalidParameter("challenge coefficient set must be canonical")
        )
        XCTAssertThrowsSuperNeoError(
            try CyclotomicDescriptor(degree: 54, relationCoefficients: [1, 0]),
            .invalidParameter("relation polynomial must have degree + 1 coefficients")
        )
    }

    func testCCSShapeRejectsFalseIdentityDeclaration() throws {
        let matrix = try SparseFieldMatrix(
            rows: 2,
            columns: 2,
            entries: [
                SparseFieldMatrix.Entry(row: 0, column: 1, value: .one),
                SparseFieldMatrix.Entry(row: 1, column: 0, value: .one)
            ]
        )

        XCTAssertThrowsError(
            try CCSShape(
                m: 2,
                nField: 2,
                nRing: 1,
                nPublicField: 2,
                matrices: [try SparseMatrixCSR(matrix)],
                relationPolynomial: try RelationPolynomial.hadamardProduct(variableCount: 1),
                hasIdentityFirstMatrix: true
            )
        ) { error in
            XCTAssertEqual(error as? SuperNeoError, .invalidParameter("first CCS matrix is not the declared identity"))
        }
    }

    func testFoldInputCarriesSerializableCustomRelationFromStructure() throws {
        let matrix = try SparseFieldMatrix.identity(size: 2)
        let relation = try RelationPolynomial(
            variableCount: 1,
            monomials: [
                RelationMonomial(coefficient: GoldilocksField(7), exponents: [1])
            ]
        )
        let structure = CCSStructure(matrices: [matrix], relationPolynomial: relation)

        let input = try SuperNeoFoldInput(structure: structure, instances: [], witnesses: [])

        XCTAssertEqual(input.shape.relationPolynomial, relation)
        XCTAssertEqual(input.structure.relationPolynomial, relation)
        XCTAssertEqual(
            try input.structure.evaluateRelation([GoldilocksExt2(GoldilocksField(3))]),
            GoldilocksExt2(GoldilocksField(21))
        )
    }

    func testFoldInputRejectsClosureOnlyCCSStructure() throws {
        let matrix = try SparseFieldMatrix.identity(size: 2)
        let structure = CCSStructure(matrices: [matrix]) { _ in
            GoldilocksExt2.zero
        }

        XCTAssertThrowsSuperNeoError(
            try SuperNeoFoldInput(structure: structure, instances: [], witnesses: []),
            .invalidParameter("fold input requires a serializable CCS relation polynomial")
        )
    }

    func testCCSAndCEInstanceEncodingRoundTripsPackedPublicInputs() throws {
        let key = try AjtaiCommitmentKey(columns: 1, seed: Array("instance-key".utf8))
        let publicInput = (0..<54).map { GoldilocksField(UInt64($0 & 1)) }
        let commitment = try SuperNeoCPUBackend().commit(key: key, message: publicInput)
        let ccs = CCSInstance(commitment: commitment, publicInput: publicInput)
        let ce = CEInstance(
            commitment: commitment,
            publicInput: publicInput,
            evalPoint: [GoldilocksExt2(GoldilocksField(3), GoldilocksField(5))],
            matrixEvals: [CyclotomicRing54([GoldilocksField(7), GoldilocksField(11)])]
        )

        let reparsedCCS = try CCSInstance(bytes: ccs.superNeoBytes)
        let reparsedCE = try CEInstance(bytes: ce.superNeoBytes)

        XCTAssertEqual(reparsedCCS, ccs)
        XCTAssertEqual(reparsedCCS.publicInput, publicInput)
        XCTAssertEqual(reparsedCCS.packedPublicInput, try SuperNeoEmbedding.pack(publicInput))
        XCTAssertEqual(reparsedCE, ce)
        XCTAssertEqual(reparsedCE.packedPublicInput, try SuperNeoEmbedding.pack(publicInput))
    }

    func testPublicInputEncodingRejectsTamperedPackedForm() throws {
        let publicInput = (0..<55).map { GoldilocksField(UInt64(($0 * 7 + 1) % 31)) }
        var packed = PublicInputEncoding(field: publicInput).packed
        var badRing = packed[1]
        badRing[0] = badRing[0] + .one
        packed[1] = badRing

        XCTAssertThrowsSuperNeoError(
            try PublicInputEncoding(field: publicInput, packed: packed),
            .invalidParameter("packed public input does not match field public input")
        )
    }

    func testCCSStatementDigestChangesWithPublicInstance() throws {
        let shape = try CCSShape.hadamardProduct(matrices: [SparseFieldMatrix.identity(size: 2)], publicInputCount: 2)
        let key = try AjtaiCommitmentKey(columns: 1, seed: Array("statement-key".utf8))
        let firstInput = Array(repeating: GoldilocksField.one, count: 54)
        let secondInput = [GoldilocksField.zero] + Array(repeating: GoldilocksField.one, count: 53)
        let first = CCSInstance(
            commitment: try SuperNeoCPUBackend().commit(key: key, message: firstInput),
            publicInput: firstInput
        )
        let second = CCSInstance(
            commitment: try SuperNeoCPUBackend().commit(key: key, message: secondInput),
            publicInput: secondInput
        )

        let firstStatement = CCSStatement(shapeDigest: shape.shapeDigest, ccsInstances: [first])
        let secondStatement = CCSStatement(shapeDigest: shape.shapeDigest, ccsInstances: [second])
        let context = ProofEnvelopeContext(
            profileID: 1,
            statement: firstStatement,
            verifierKeyDigest: key.verifierKeyDigest
        )

        XCTAssertNotEqual(firstStatement.statementDigest, secondStatement.statementDigest)
        XCTAssertEqual(context.shapeDigest, shape.shapeDigest)
        XCTAssertEqual(context.statementDigest, firstStatement.statementDigest)
    }

}

final class ProtocolSmokeTests: SuperNeoTestCase {
    // MARK: - Tier 2: fold smoke checks

    func testCPUOracleFoldVerifiesWithoutMetalContext() throws {
        let fixture = try makeFoldFixture()

        let fold = try fixture.backend.makeProver(key: fixture.key).foldWithOutput(fixture.input, transcriptSeed: fixture.seed)
        let verifier = SuperNeoVerifier(key: fixture.key)
        let reduction = verifier.reduceFold(input: fixture.input, proof: fold.proof, transcriptSeed: fixture.seed)
        let result = verifier.verifyFold(
            input: fixture.input,
            proof: fold.proof,
            outputClaims: fold.outputClaims,
            transcriptSeed: fixture.seed
        )

        XCTAssertTrue(reduction.isReductionAccepted, reduction.reason ?? "")
        XCTAssertTrue(reduction.requiresTerminalRelationCheck)
        XCTAssertEqual(reduction.outputClaims, fold.proof.outputClaims)
        XCTAssertEqual(result, .valid)
    }

    func testHighAssuranceCPUFoldMatchesOptimizedProof() throws {
        let fixture = try makeFoldFixture()

        let optimized = try SuperNeoProver(key: fixture.key).foldWithOutput(
            fixture.input,
            transcriptSeed: fixture.seed
        )
        let hardened = try SuperNeoProver(
            key: fixture.key,
            executionPolicy: .highAssurance
        ).foldWithOutput(
            fixture.input,
            transcriptSeed: fixture.seed
        )
        let verifier = SuperNeoVerifier(
            key: fixture.key,
            executionPolicy: .highAssurance
        )

        XCTAssertEqual(hardened, optimized)
        XCTAssertEqual(
            verifier.verifyFold(
                input: fixture.input,
                proof: hardened.proof,
                outputClaims: hardened.outputClaims,
                transcriptSeed: fixture.seed
            ),
            .valid
        )
    }

    func testPreparedFoldContextMatchesStandardFoldAndRejectsWrongKey() throws {
        let fixture = try makeFoldFixture()
        let prover = SuperNeoProver(key: fixture.key)
        let preparedContext = try prover.prepareFoldContext(for: fixture.input)

        let standard = try prover.foldWithOutput(fixture.input, transcriptSeed: fixture.seed)
        let prepared = try prover.foldWithOutput(
            fixture.input,
            transcriptSeed: fixture.seed,
            preparedContext: preparedContext
        )
        let wrongKey = try AjtaiCommitmentKey(
            columns: fixture.key.matrix.columns,
            seed: Array("prepared-fold-wrong-key".utf8)
        )

        XCTAssertEqual(prepared, standard)
        XCTAssertThrowsSuperNeoError(
            try SuperNeoProver(key: wrongKey).foldWithOutput(
                fixture.input,
                transcriptSeed: fixture.seed,
                preparedContext: preparedContext
            ),
            .invalidParameter("prepared fold context verifier key digest mismatch")
        )
    }

}

final class CEOpeningProtocolTests: SuperNeoTestCase {
    // MARK: - Tier 2: CE opening proof checks

    func testLocalCEOpeningRelationBindsStatementAndWitness() throws {
        let fixture = try makeFoldFixture()
        let fold = try fixture.backend.makeProver(key: fixture.key).foldWithOutput(fixture.input, transcriptSeed: fixture.seed)
        let claim = try XCTUnwrap(fold.outputClaims.first)
        let witness = try XCTUnwrap(CEOpeningWitness(claim: claim))
        let statement = CEOpeningStatement(
            profileID: fixture.key.parameters.profileID,
            shape: fixture.input.shape,
            key: fixture.key,
            claim: claim
        )

        XCTAssertNil(statement.claim.witness)
        XCTAssertEqual(statement.instance, CEInstance(claim))
        XCTAssertTrue(try CEOpeningRelation.verifyLocal(
            statement: statement,
            witness: witness,
            shape: fixture.input.shape,
            key: fixture.key
        ))

        let wrongProfile = CEOpeningStatement(
            profileID: fixture.key.parameters.profileID + 1,
            shape: fixture.input.shape,
            key: fixture.key,
            claim: claim
        )
        XCTAssertNotEqual(statement.statementDigest, wrongProfile.statementDigest)
        XCTAssertFalse(try CEOpeningRelation.verifyLocal(
            statement: wrongProfile,
            witness: witness,
            shape: fixture.input.shape,
            key: fixture.key
        ))

        var tamperedEvaluations = claim.evaluations
        tamperedEvaluations[0] = tamperedEvaluations[0] + CyclotomicExt2Ring54([GoldilocksExt2(.one)])
        let tamperedStatement = CEOpeningStatement(
            profileID: fixture.key.parameters.profileID,
            shape: fixture.input.shape,
            key: fixture.key,
            claim: replacing(claim, evaluations: tamperedEvaluations)
        )
        XCTAssertNotEqual(statement.statementDigest, tamperedStatement.statementDigest)
        XCTAssertFalse(try CEOpeningRelation.verifyLocal(
            statement: tamperedStatement,
            witness: witness,
            shape: fixture.input.shape,
            key: fixture.key
        ))

        let terminalStatement = try TerminalCEStatement(
            profileID: fixture.key.parameters.profileID,
            shape: fixture.input.shape,
            key: fixture.key,
            claims: fold.outputClaims
        )
        let terminalWitnesses = try fold.outputClaims.map { claim in
            try XCTUnwrap(CEOpeningWitness(claim: claim))
        }
        XCTAssertEqual(terminalStatement.openings.count, fixture.key.parameters.decompositionLength)
        XCTAssertTrue(terminalStatement.openings.allSatisfy { $0.claim.witness == nil })
        XCTAssertTrue(try CEOpeningRelation.verifyTerminalLocalBatch(
            statement: terminalStatement,
            witnesses: terminalWitnesses,
            shape: fixture.input.shape,
            key: fixture.key
        ))

        let shortTerminalStatement = try TerminalCEStatement(
            profileID: fixture.key.parameters.profileID,
            shape: fixture.input.shape,
            key: fixture.key,
            claims: Array(fold.outputClaims.dropLast())
        )
        XCTAssertFalse(try CEOpeningRelation.verifyTerminalLocalBatch(
            statement: shortTerminalStatement,
            witnesses: Array(terminalWitnesses.dropLast()),
            shape: fixture.input.shape,
            key: fixture.key
        ))

        XCTAssertThrowsSuperNeoError(
            try TerminalCEStatement(
                profileID: fixture.key.parameters.profileID,
                shape: fixture.input.shape,
                key: fixture.key,
                openings: [wrongProfile] + terminalStatement.openings.dropFirst()
            ),
            .invalidParameter("terminal CE statement profile mismatch")
        )

        var badWitnessValues = witness.witness
        badWitnessValues[0] = badWitnessValues[0] + .one
        XCTAssertFalse(try CEOpeningRelation.verifyLocal(
            statement: statement,
            witness: CEOpeningWitness(badWitnessValues),
            shape: fixture.input.shape,
            key: fixture.key
        ))
        var badTerminalWitnesses = terminalWitnesses
        badTerminalWitnesses[0] = CEOpeningWitness(badWitnessValues)
        XCTAssertFalse(try CEOpeningRelation.verifyLocalBatch(
            statement: terminalStatement,
            witnesses: badTerminalWitnesses,
            shape: fixture.input.shape,
            key: fixture.key
        ))
    }

    func testCEOpeningProofVerifiesPublicStatementWithoutWitness() throws {
        let fixture = try makeFoldFixture()
        let fold = try fixture.backend.makeProver(key: fixture.key).foldWithOutput(fixture.input, transcriptSeed: fixture.seed)
        let claim = try XCTUnwrap(fold.outputClaims.first)
        let witness = try XCTUnwrap(CEOpeningWitness(claim: claim))
        let statement = try TerminalCEStatement(
            profileID: fixture.key.parameters.profileID,
            shape: fixture.input.shape,
            key: fixture.key,
            claims: [claim]
        )

        let proof = try CEOpeningRelation.proveLocalBatchForTesting(
            statement: statement,
            witnesses: [witness],
            shape: fixture.input.shape,
            key: fixture.key,
            randomSeed: Array("ce-opening-proof".utf8)
        )
        XCTAssertNil(statement.openings[0].claim.witness)
        XCTAssertTrue(try CEOpeningRelation.verify(
            proof: proof,
            statement: statement,
            shape: fixture.input.shape,
            key: fixture.key
        ))

        let reparsed = try CEOpeningProof(bytes: proof.superNeoBytes)
        XCTAssertEqual(reparsed, proof)
        XCTAssertTrue(try CEOpeningRelation.verify(
            proof: reparsed,
            statement: statement,
            shape: fixture.input.shape,
            key: fixture.key
        ))

        XCTAssertThrowsSuperNeoError(
            try CEOpeningProof(rounds: proof.rounds + [proof.rounds[0]]),
            .invalidParameter("CE opening proof must contain exactly \(CEOpeningProof.roundCount) Stern rounds")
        )

        var tamperedEvaluations = claim.evaluations
        tamperedEvaluations[0] = tamperedEvaluations[0] + CyclotomicExt2Ring54([GoldilocksExt2(.one)])
        let tamperedStatement = try TerminalCEStatement(
            profileID: fixture.key.parameters.profileID,
            shape: fixture.input.shape,
            key: fixture.key,
            claims: [replacing(claim, evaluations: tamperedEvaluations)]
        )
        XCTAssertFalse(try CEOpeningRelation.verify(
            proof: proof,
            statement: tamperedStatement,
            shape: fixture.input.shape,
            key: fixture.key
        ))

        var tamperedProofBytes = proof.superNeoBytes
        tamperedProofBytes[tamperedProofBytes.count - 1] ^= 1
        if let tamperedProof = try? CEOpeningProof(bytes: tamperedProofBytes) {
            XCTAssertFalse(try CEOpeningRelation.verify(
                proof: tamperedProof,
                statement: statement,
                shape: fixture.input.shape,
                key: fixture.key
            ))
        }
    }

    func testCEOpeningProofSerializationCoversAllResponseTagsAndParserFailures() throws {
        func digest(_ seed: UInt8) throws -> Digest256 {
            try Digest256((0..<Digest256.byteCount).map { UInt8(truncatingIfNeeded: Int(seed) + $0) })
        }

        let firstCommitment = CEOpeningProofCommitments(
            maskLinearDigest: try digest(10),
            permutedMaskDigest: try digest(11),
            permutedMaskedWitnessDigest: try digest(12)
        )
        let secondCommitment = CEOpeningProofCommitments(
            maskLinearDigest: try digest(13),
            permutedMaskDigest: try digest(14),
            permutedMaskedWitnessDigest: try digest(15)
        )
        let commitments = [firstCommitment, secondCommitment]
        let maskOpenings = [
            CEOpeningLinearResponse(permutation: [0, 1], vector: [GoldilocksField(7), GoldilocksField(11)]),
            CEOpeningLinearResponse(permutation: [1, 0], vector: [GoldilocksField(13), GoldilocksField(17)])
        ]
        let maskedWitnessOpenings = [
            CEOpeningLinearResponse(permutation: [1, 1], vector: [GoldilocksField(19), GoldilocksField(23)]),
            CEOpeningLinearResponse(permutation: [0, 0], vector: [GoldilocksField(29), GoldilocksField(31)])
        ]
        let permutedWitnessOpenings = [
            CEOpeningNormResponse(
                permutedMask: [GoldilocksField(37), GoldilocksField(41)],
                permutedWitness: [GoldilocksField(43), GoldilocksField(47)]
            ),
            CEOpeningNormResponse(
                permutedMask: [GoldilocksField(53), GoldilocksField(59)],
                permutedWitness: [GoldilocksField(61), GoldilocksField(67)]
            )
        ]

        let rounds = (0..<CEOpeningProof.roundCount).map { index in
            let response: CEOpeningProofResponse
            switch index % 3 {
            case 0:
                response = .mask(maskOpenings)
            case 1:
                response = .maskedWitness(maskedWitnessOpenings)
            default:
                response = .permutedWitness(permutedWitnessOpenings)
            }
            return CEOpeningProofRound(commitments: commitments, response: response)
        }
        let proof = try CEOpeningProof(rounds: rounds)
        let bytes = proof.superNeoBytes
        let roundWidth = rounds[0].superNeoBytes.count
        let responseTagOffsetInRound = encodedCountByteWidth + commitments.count * 3 * Digest256.byteCount
        func responseTagOffset(round index: Int) -> Int {
            encodedCountByteWidth + index * roundWidth + responseTagOffsetInRound
        }

        XCTAssertTrue(rounds.allSatisfy { $0.superNeoBytes.count == roundWidth })
        XCTAssertEqual(bytes[responseTagOffset(round: 0)], 0)
        XCTAssertEqual(bytes[responseTagOffset(round: 1)], 1)
        XCTAssertEqual(bytes[responseTagOffset(round: 2)], 2)
        XCTAssertEqual(try CEOpeningProof(bytes: bytes), proof)

        let reparsed = try CEOpeningProof(bytes: bytes)
        if case .mask(let openings) = reparsed.rounds[0].response {
            XCTAssertEqual(openings, maskOpenings)
        } else {
            XCTFail("round 0 should parse as mask response")
        }
        if case .maskedWitness(let openings) = reparsed.rounds[1].response {
            XCTAssertEqual(openings, maskedWitnessOpenings)
        } else {
            XCTFail("round 1 should parse as masked-witness response")
        }
        if case .permutedWitness(let openings) = reparsed.rounds[2].response {
            XCTAssertEqual(openings, permutedWitnessOpenings)
        } else {
            XCTFail("round 2 should parse as permuted-witness response")
        }

        var wrongRoundCount = bytes
        wrongRoundCount[0] = UInt8(CEOpeningProof.roundCount - 1)
        XCTAssertThrowsSuperNeoError(
            try CEOpeningProof(bytes: wrongRoundCount),
            .invalidEncoding("wrong CE opening proof round count")
        )

        var invalidTag = bytes
        invalidTag[responseTagOffset(round: 0)] = 9
        XCTAssertThrowsSuperNeoError(
            try CEOpeningProof(bytes: invalidTag),
            .invalidEncoding("unsupported CE opening response challenge")
        )

        var wrongResponseCount = bytes
        wrongResponseCount[responseTagOffset(round: 0) + 1] = 1
        XCTAssertThrowsSuperNeoError(
            try CEOpeningProof(bytes: wrongResponseCount),
            .invalidEncoding("CE opening response count mismatch")
        )

        var truncatedCommitmentDigest = bytes
        truncatedCommitmentDigest.remove(at: encodedCountByteWidth + encodedCountByteWidth + Digest256.byteCount - 1)
        XCTAssertThrowsError(try CEOpeningProof(bytes: truncatedCommitmentDigest))

        XCTAssertThrowsSuperNeoError(
            try CEOpeningProof(bytes: bytes + [0]),
            .invalidEncoding("trailing proof bytes")
        )
    }

    func testCEOpeningMetalVerifierUsesWorkspaceTargetPreparation() throws {
        let device = try requireMetalDevice()
        let context = try MetalExecutionContext(device: device)
        let fixture = try makeFoldFixture()
        let fold = try fixture.backend.makeProver(key: fixture.key).foldWithOutput(fixture.input, transcriptSeed: fixture.seed)
        let statement = try TerminalCEStatement(
            profileID: fixture.key.parameters.profileID,
            shape: fixture.input.shape,
            key: fixture.key,
            claims: fold.outputClaims
        )
        let witnesses = try fold.outputClaims.map { claim in
            try XCTUnwrap(CEOpeningWitness(claim: claim))
        }
        let workspace = try SuperNeoMetalWorkspace(
            context: context,
            key: fixture.key,
            compiledShape: fixture.input.shape.compiledSparseForSuperNeo()
        )
        let proof = try CEOpeningRelation.proveLocalBatchForTesting(
            statement: statement,
            witnesses: witnesses,
            shape: fixture.input.shape,
            key: fixture.key,
            randomSeed: Array("ce-opening-metal-targets".utf8)
        )

        XCTAssertTrue(try CEOpeningRelation.verify(
            proof: proof,
            statement: statement,
            shape: fixture.input.shape,
            key: fixture.key,
            metalWorkspace: workspace
        ))
    }

    func testCEOpeningRejectsStaleMetalWorkspaceForShape() throws {
        let device = try requireMetalDevice()
        let context = try MetalExecutionContext(device: device)
        let fixture = try makeFoldFixture()
        let fold = try fixture.backend.makeProver(key: fixture.key).foldWithOutput(fixture.input, transcriptSeed: fixture.seed)
        let claim = try XCTUnwrap(fold.outputClaims.first)
        let witness = try XCTUnwrap(CEOpeningWitness(claim: claim))
        let statement = try TerminalCEStatement(
            profileID: fixture.key.parameters.profileID,
            shape: fixture.input.shape,
            key: fixture.key,
            claims: [claim]
        )
        let tamperedMatrix = try SparseFieldMatrix(
            rows: fixture.input.shape.m,
            columns: fixture.input.shape.nField,
            entries: (0..<fixture.input.shape.m).map { row in
                SparseFieldMatrix.Entry(
                    row: row,
                    column: row,
                    value: row == 0 ? GoldilocksField(2) : .one
                )
            }
        )
        let staleWorkspace = try SuperNeoMetalWorkspace(
            context: context,
            key: fixture.key,
            transformedSparseMatrices: [try tamperedMatrix.transformedSparseForSuperNeo()]
        )

        XCTAssertThrowsSuperNeoError(
            try CEOpeningRelation.proveLocalBatchForTesting(
                statement: statement,
                witnesses: [witness],
                shape: fixture.input.shape,
                key: fixture.key,
                randomSeed: Array("ce-opening-stale-workspace".utf8),
                metalWorkspace: staleWorkspace
            ),
            .invalidParameter("CE opening Metal workspace transformed matrix digest mismatch")
        )
    }

    func testCEOpeningRejectsAjtaiKeyColumnCountThatDoesNotMatchShape() throws {
        let fixture = try makeFoldFixture()
        let fold = try fixture.backend.makeProver(key: fixture.key).foldWithOutput(fixture.input, transcriptSeed: fixture.seed)
        let claim = try XCTUnwrap(fold.outputClaims.first)
        let witness = try XCTUnwrap(CEOpeningWitness(claim: claim))
        let statement = CEOpeningStatement(
            profileID: fixture.key.parameters.profileID,
            shape: fixture.input.shape,
            key: fixture.key,
            claim: claim
        )
        let terminalStatement = try TerminalCEStatement(
            profileID: fixture.key.parameters.profileID,
            shape: fixture.input.shape,
            key: fixture.key,
            claims: fold.outputClaims
        )
        let terminalWitnesses = try fold.outputClaims.map { claim in
            try XCTUnwrap(CEOpeningWitness(claim: claim))
        }
        let mismatchedKey = try AjtaiCommitmentKey(
            columns: fixture.input.shape.nRing + 1,
            seed: Array("ce-opening-key-mismatch".utf8)
        )

        XCTAssertFalse(try CEOpeningRelation.verifyLocal(
            statement: statement,
            witness: witness,
            shape: fixture.input.shape,
            key: mismatchedKey
        ))
        XCTAssertFalse(try CEOpeningRelation.verifyTerminalLocalBatch(
            statement: terminalStatement,
            witnesses: terminalWitnesses,
            shape: fixture.input.shape,
            key: mismatchedKey
        ))
        XCTAssertThrowsSuperNeoError(
            try CEOpeningRelation.proveLocalBatchForTesting(
                statement: terminalStatement,
                witnesses: terminalWitnesses,
                shape: fixture.input.shape,
                key: mismatchedKey,
                randomSeed: Array("ce-opening-key-mismatch-proof".utf8)
            ),
            .invalidParameter("terminal CE statement verifier key mismatch")
        )
        let mismatchedKeyStatement = try TerminalCEStatement(
            profileID: fixture.key.parameters.profileID,
            shape: fixture.input.shape,
            key: mismatchedKey,
            claims: fold.outputClaims
        )
        XCTAssertThrowsSuperNeoError(
            try CEOpeningRelation.proveLocalBatchForTesting(
                statement: mismatchedKeyStatement,
                witnesses: terminalWitnesses,
                shape: fixture.input.shape,
                key: mismatchedKey,
                randomSeed: Array("ce-opening-key-column-mismatch-proof".utf8)
            ),
            .invalidParameter("CE opening key column count must match shape.nRing")
        )

        let sameWidthWrongKey = try AjtaiCommitmentKey(
            columns: fixture.input.shape.nRing,
            seed: Array("ce-opening-same-width-wrong-key".utf8)
        )
        XCTAssertFalse(try CEOpeningRelation.verifyLocal(
            statement: statement,
            witness: witness,
            shape: fixture.input.shape,
            key: sameWidthWrongKey
        ))
        XCTAssertFalse(try CEOpeningRelation.verifyTerminalLocalBatch(
            statement: terminalStatement,
            witnesses: terminalWitnesses,
            shape: fixture.input.shape,
            key: sameWidthWrongKey
        ))
        XCTAssertThrowsSuperNeoError(
            try CEOpeningRelation.proveLocalBatchForTesting(
                statement: terminalStatement,
                witnesses: terminalWitnesses,
                shape: fixture.input.shape,
                key: sameWidthWrongKey,
                randomSeed: Array("ce-opening-same-width-wrong-key-proof".utf8)
            ),
            .invalidParameter("terminal CE statement verifier key mismatch")
        )
    }

}

final class ProtocolE2ETests: SuperNeoTestCase {
    // MARK: - Tier 2: end-to-end protocol and adversarial proof checks

    func testFoldRejectsPartialRingPublicInputForRModuleFolding() throws {
        let publicInput = [GoldilocksField.one]
        let privateWitness = Array(repeating: GoldilocksField.zero, count: 63)
        let matrix = try SparseFieldMatrix.identity(size: publicInput.count + privateWitness.count)
        let structure = CCSStructure.hadamardProduct(matrices: [matrix])
        let backend = SuperNeoCPUBackend()
        let key = try AjtaiCommitmentKey(columns: 2, seed: Array("partial-public-input".utf8))
        let commitment = try backend.commit(key: key, message: publicInput + privateWitness)

        XCTAssertThrowsSuperNeoError(
            try SuperNeoFoldInput(
                structure: structure,
                instances: [CCSInstance(commitment: commitment, publicInput: publicInput)],
                witnesses: [CCSWitness(privateWitness)]
            ),
            .invalidParameter(
                "SuperNeo folding requires a paper-normalized CCS shape: public input length must contain whole ring columns for R-module folding; use SuperNeoCCSNormalizer.normalize(...) for general CCS inputs"
            )
        )
        let shape = try CCSShape(
            matrices: structure.matrices,
            publicInputCount: publicInput.count,
            relationPolynomial: try XCTUnwrap(structure.relationPolynomial)
        )
        let reduction = SuperNeoVerifier(key: key).reduceFold(
            publicInput: SuperNeoPublicFoldInput(
                shape: shape,
                instances: [CCSInstance(commitment: commitment, publicInput: publicInput)]
            ),
            proof: makeEmptyFoldProofForShape(shape)
        )
        XCTAssertFalse(reduction.isReductionAccepted)
        XCTAssertFalse(reduction.requiresTerminalRelationCheck)
        XCTAssertEqual(
            reduction.reason,
            "invalidParameter(\"SuperNeo folding requires a paper-normalized CCS shape: public input length must contain whole ring columns for R-module folding; use SuperNeoCCSNormalizer.normalize(...) for general CCS inputs\")"
        )
    }

    func testPaperLinePiCCSPiRLCAndPiDECReferenceVectors() throws {
        let fixture = try makePaperAuditFixture()
        let fold = try fixture.backend.makeProver(key: fixture.key).foldWithOutput(fixture.input, transcriptSeed: fixture.seed)
        let verifier = SuperNeoVerifier(key: fixture.key)
        let publicInput = SuperNeoPublicFoldInput(fixture.input)

        let reduction = verifier.reduceFold(
            publicInput: publicInput,
            proof: fold.proof,
            transcriptSeed: fixture.seed
        )
        XCTAssertTrue(reduction.isReductionAccepted, reduction.reason ?? "")
        XCTAssertTrue(reduction.requiresTerminalRelationCheck)
        XCTAssertEqual(publicInput.instances.count, 2)
        XCTAssertEqual(publicInput.priorClaims.count, 2)
        XCTAssertEqual(fold.proof.piCCSClaims.count, 4)

        _ = try assertPiCCSMatchesPaperReference(
            input: publicInput,
            proof: fold.proof,
            seed: fixture.seed
        )
        try assertPiRLCMatchesPaperReference(
            input: publicInput,
            proof: fold.proof,
            seed: fixture.seed
        )
        try assertPiDECMatchesPaperReference(
            folded: fold.proof.foldedClaim,
            proofOutputClaims: fold.proof.outputClaims,
            witnessOutputClaims: fold.outputClaims,
            parameters: fixture.key.parameters
        )

        XCTAssertEqual(
            verifier.verifyTerminalFold(
                publicInput: publicInput,
                proof: fold.proof,
                outputClaims: fold.outputClaims,
                transcriptSeed: fixture.seed
            ),
            .valid
        )
    }

    func testFoldRejectsAjtaiKeyColumnCountThatDoesNotMatchShape() throws {
        let fixture = try makeFoldFixture()
        let mismatchedKey = try AjtaiCommitmentKey(
            columns: fixture.input.shape.nRing + 1,
            seed: Array("shape-key-mismatch".utf8)
        )

        XCTAssertThrowsSuperNeoError(
            try SuperNeoProver(key: mismatchedKey).fold(fixture.input, transcriptSeed: fixture.seed),
            .invalidParameter("prover key column count must match shape.nRing")
        )

        XCTAssertInvalid(
            SuperNeoVerifier(key: mismatchedKey).reduceFold(
                publicInput: SuperNeoPublicFoldInput(fixture.input),
                proof: makeEmptyFoldProofForShape(fixture.input.shape),
                transcriptSeed: fixture.seed
            ),
            reason: "invalidParameter(\"verifier key column count must match shape.nRing\")"
        )
    }

    func testPriorCEClaimPublicProjectionMustMatchActiveShape() throws {
        let fixture = try makePaperAuditFixture()
        var priorClaims = fixture.input.priorClaims
        let shortenedPublicInput = Array(priorClaims[0].publicInput.dropLast())
        priorClaims[0] = replacing(priorClaims[0], publicInput: shortenedPublicInput)
        let input = SuperNeoFoldInput(
            shape: fixture.input.shape,
            instances: fixture.input.instances,
            witnesses: fixture.input.witnesses,
            priorClaims: priorClaims
        )

        XCTAssertThrowsSuperNeoError(
            try SuperNeoProver(key: fixture.key).fold(input, transcriptSeed: fixture.seed),
            .invalidParameter("prior CE public input length must match shape.nPublicField")
        )

        XCTAssertInvalid(
            SuperNeoVerifier(key: fixture.key).reduceFold(
                publicInput: SuperNeoPublicFoldInput(input),
                proof: makeEmptyFoldProofForShape(input.shape),
                transcriptSeed: fixture.seed
            ),
            reason: "invalidParameter(\"prior CE public input length must match shape.nPublicField\")"
        )
    }

    func testProverRejectsPriorCEClaimWhenEvaluationDoesNotMatchWitness() throws {
        let fixture = try makePaperAuditFixture()
        var priorClaims = fixture.input.priorClaims
        var tamperedEvaluations = priorClaims[0].evaluations
        tamperedEvaluations[0] = tamperedEvaluations[0] + CyclotomicExt2Ring54([GoldilocksExt2(.one)])
        priorClaims[0] = replacing(priorClaims[0], evaluations: tamperedEvaluations)
        let input = SuperNeoFoldInput(
            shape: fixture.input.shape,
            instances: fixture.input.instances,
            witnesses: fixture.input.witnesses,
            priorClaims: priorClaims
        )

        XCTAssertThrowsSuperNeoError(
            try SuperNeoProver(key: fixture.key).fold(input, transcriptSeed: fixture.seed),
            .invalidParameter("prior CE claim witness does not satisfy its commitment/evaluation opening")
        )
    }

    func testProverRejectsPriorCEWitnessWhenPublicProjectionDoesNotMatchOpening() throws {
        let fixture = try makePaperAuditFixture()
        var priorClaims = fixture.input.priorClaims
        var shiftedPublicInput = priorClaims[0].publicInput
        shiftedPublicInput[0] = shiftedPublicInput[0] + .one
        priorClaims[0] = replacing(priorClaims[0], publicInput: shiftedPublicInput)
        let input = SuperNeoFoldInput(
            shape: fixture.input.shape,
            instances: fixture.input.instances,
            witnesses: fixture.input.witnesses,
            priorClaims: priorClaims
        )

        XCTAssertThrowsSuperNeoError(
            try SuperNeoProver(key: fixture.key).fold(input, transcriptSeed: fixture.seed),
            .invalidParameter("prior CE public input must be a prefix of its witness")
        )
    }

    func testPublicFoldVerifierDoesNotTreatReductionAsTerminalProof() throws {
        let fixture = try makeFoldFixture()
        let proof = try fixture.backend.makeProver(key: fixture.key).fold(fixture.input, transcriptSeed: fixture.seed)

        let verifier = SuperNeoVerifier(key: fixture.key)
        let reduction = verifier.reduceFold(
            input: fixture.input,
            proof: proof,
            transcriptSeed: fixture.seed
        )
        let terminalWithForgedClaims = verifier.verifyTerminalFold(
            input: fixture.input,
            proof: proof,
            outputClaims: proof.outputClaims,
            transcriptSeed: fixture.seed
        )

        XCTAssertTrue(reduction.isReductionAccepted, reduction.reason ?? "")
        XCTAssertTrue(reduction.requiresTerminalRelationCheck)
        XCTAssertInvalid(terminalWithForgedClaims, reason: "terminal CE relation check failed")
    }

    func testVerifierRejectsTamperedPiCCSClaimBinding() throws {
        let fixture = try makeFoldFixture()
        let proof = try fixture.backend.makeProver(key: fixture.key).fold(fixture.input, transcriptSeed: fixture.seed)
        var claims = proof.piCCSClaims
        claims[0] = replacing(claims[0], commitment: claims[0].commitment + unitCommitment(parameters: fixture.key.parameters))
        let tampered = replacing(proof, piCCSClaims: claims)

        let result = SuperNeoVerifier(key: fixture.key).reduceFold(input: fixture.input, proof: tampered, transcriptSeed: fixture.seed)

        XCTAssertInvalid(result)
    }

    func testVerifierRejectsTamperedPiCCSEvaluation() throws {
        let fixture = try makeFoldFixture()
        let proof = try fixture.backend.makeProver(key: fixture.key).fold(fixture.input, transcriptSeed: fixture.seed)
        var claims = proof.piCCSClaims
        var evaluations = claims[0].evaluations
        evaluations[0] = evaluations[0] + CyclotomicExt2Ring54([GoldilocksExt2(.one)])
        claims[0] = replacing(claims[0], evaluations: evaluations)
        let tampered = replacing(proof, piCCSClaims: claims)

        let result = SuperNeoVerifier(key: fixture.key).reduceFold(input: fixture.input, proof: tampered, transcriptSeed: fixture.seed)

        XCTAssertInvalid(result)
    }

    func testVerifierRejectsTamperedFoldedClaimPublicInput() throws {
        let fixture = try makeFoldFixture()
        let proof = try fixture.backend.makeProver(key: fixture.key).fold(fixture.input, transcriptSeed: fixture.seed)
        var publicInput = proof.foldedClaim.publicInput
        publicInput[0] = publicInput[0] + .one
        let tampered = replacing(proof, foldedClaim: replacing(proof.foldedClaim, publicInput: publicInput))

        let result = SuperNeoVerifier(key: fixture.key).reduceFold(input: fixture.input, proof: tampered, transcriptSeed: fixture.seed)

        XCTAssertInvalid(result, reason: "repeated PiRLC branch 0 verification failed")
    }

    func testVerifierRejectsMalformedDecompositionOutput() throws {
        let fixture = try makeFoldFixture()
        let proof = try fixture.backend.makeProver(key: fixture.key).fold(fixture.input, transcriptSeed: fixture.seed)
        var outputClaims = proof.outputClaims
        var badPublicInput = outputClaims[0].publicInput
        badPublicInput[0] = GoldilocksField(UInt64(fixture.key.parameters.normBound))
        outputClaims[0] = replacing(outputClaims[0], publicInput: badPublicInput)

        let result = SuperNeoVerifier(key: fixture.key).reduceFold(
            input: fixture.input,
            proof: replacing(proof, outputClaims: outputClaims),
            transcriptSeed: fixture.seed
        )

        XCTAssertInvalid(result, reason: "repeated PiRLC branch 0 verification failed")

        let missingOutput = replacing(proof, outputClaims: Array(proof.outputClaims.dropLast()))
        let missingResult = SuperNeoVerifier(key: fixture.key).reduceFold(
            input: fixture.input,
            proof: missingOutput,
            transcriptSeed: fixture.seed
        )
        XCTAssertInvalid(missingResult, reason: "invalidParameter(\"decomposition output count must equal 14\")")
    }

    func testProofEnvelopeRoundTripsThroughVerifierTranscript() throws {
        let fixture = try makeFoldFixture()
        let context = ProofEnvelopeContext(
            profileID: 1,
            statement: CCSStatement(
                shapeDigest: fixture.input.shape.shapeDigest,
                ccsInstances: fixture.input.instances
            ),
            verifierKeyDigest: fixture.key.verifierKeyDigest
        )

        let fold = try fixture.backend.makeProver(key: fixture.key).foldWithOutput(
            fixture.input,
            transcriptSeed: context.transcriptBindingBytes
        )
        let envelope = try FoldProofEnvelope(context: context, proof: fold.proof)
        let reparsed = try FoldProofEnvelope(bytes: envelope.superNeoBytes)
        let verifier = SuperNeoVerifier(key: fixture.key)
        let reduction = verifier.reduceFoldEnvelope(
            input: fixture.input,
            proofBytes: reparsed.superNeoBytes,
            context: context
        )
        let result = verifier.verifyFoldEnvelope(
            input: fixture.input,
            proofBytes: reparsed.superNeoBytes,
            context: context,
            outputClaims: fold.outputClaims
        )

        XCTAssertEqual(reparsed.header.profileID, context.profileID)
        XCTAssertEqual(reparsed.header.kind, .foldReduction)
        XCTAssertEqual(reparsed.header.shapeDigest, context.shapeDigest)
        XCTAssertEqual(reparsed.header.statementDigest, context.statementDigest)
        XCTAssertEqual(reparsed.header.verifierKeyDigest, fixture.key.verifierKeyDigest)
        XCTAssertEqual(reparsed.header.bodyLength, UInt32(reparsed.proof.superNeoBytes.count))
        XCTAssertTrue(reduction.isReductionAccepted, reduction.reason ?? "")
        XCTAssertTrue(reduction.requiresTerminalRelationCheck)
        XCTAssertEqual(result, .valid)
    }

    func testProofEnvelopeBindsVerifierKeyDigest() throws {
        let fixture = try makeFoldFixture()
        let statement = CCSStatement(
            shapeDigest: fixture.input.shape.shapeDigest,
            ccsInstances: fixture.input.instances
        )
        let context = ProofEnvelopeContext(
            profileID: 1,
            statement: statement,
            verifierKeyDigest: fixture.key.verifierKeyDigest
        )
        let proofBytes = try fixture.backend.makeProver(key: fixture.key)
            .foldEnvelope(fixture.input, context: context)
            .superNeoBytes
        let sameWidthWrongKey = try AjtaiCommitmentKey(
            columns: fixture.input.shape.nRing,
            seed: Array("fold-envelope-same-width-wrong-key".utf8)
        )
        let wrongDigestContext = ProofEnvelopeContext(
            profileID: context.profileID,
            kind: context.kind,
            shapeDigest: context.shapeDigest,
            statementDigest: context.statementDigest,
            verifierKeyDigest: sameWidthWrongKey.verifierKeyDigest,
            transcriptDomain: context.transcriptDomain
        )
        let verifier = SuperNeoVerifier(key: fixture.key)

        XCTAssertThrowsSuperNeoError(
            try fixture.backend.makeProver(key: fixture.key).foldEnvelope(
                fixture.input,
                context: wrongDigestContext
            ),
            .invalidParameter("proof envelope context verifier key digest mismatch")
        )
        XCTAssertInvalid(
            verifier.reduceFoldEnvelope(
                input: fixture.input,
                proofBytes: proofBytes,
                context: wrongDigestContext
            ),
            reason: "verifier key digest mismatch"
        )
        XCTAssertInvalid(
            SuperNeoVerifier(key: sameWidthWrongKey).reduceFoldEnvelope(
                input: fixture.input,
                proofBytes: proofBytes,
                context: context
            ),
            reason: "input verifier key digest mismatch"
        )

        var mutatedHeader = proofBytes
        mutatedHeader[proofEnvelopeVerifierKeyDigestOffset] ^= 0x01
        XCTAssertInvalid(
            verifier.reduceFoldEnvelope(
                input: fixture.input,
                proofBytes: mutatedHeader,
                context: context
            ),
            reason: "verifier key digest mismatch"
        )
    }

    func testProofEnvelopeBodyMutationCorpusNeverVerifies() throws {
        let fixture = try makeFoldFixture()
        let context = ProofEnvelopeContext(
            profileID: 1,
            statement: CCSStatement(
                shapeDigest: fixture.input.shape.shapeDigest,
                ccsInstances: fixture.input.instances
            ),
            verifierKeyDigest: fixture.key.verifierKeyDigest
        )
        let fold = try fixture.backend.makeProver(key: fixture.key).foldWithOutput(
            fixture.input,
            transcriptSeed: context.transcriptBindingBytes
        )
        let proofBytes = try FoldProofEnvelope(context: context, proof: fold.proof).superNeoBytes
        let bodyStart = ProofEnvelopeHeader.byteCount
        let mutationOffsets = [
            bodyStart,
            bodyStart + 8,
            bodyStart + 64,
            bodyStart + 257,
            proofBytes.count / 2,
            proofBytes.count - 9,
            proofBytes.count - 1
        ].filter { $0 >= bodyStart && $0 < proofBytes.count }

        let verifier = SuperNeoVerifier(key: fixture.key)
        for offset in mutationOffsets {
            var mutated = proofBytes
            mutated[offset] ^= 0x01
            guard (try? FoldProofEnvelope(bytes: mutated)) != nil else {
                continue
            }

            XCTAssertInvalid(verifier.verifyFoldEnvelope(
                input: fixture.input,
                proofBytes: mutated,
                context: context,
                outputClaims: fold.outputClaims
            ))
        }
    }

    func testTerminalLocalEnvelopeRoundTripsAndRequiresPublicCEProof() throws {
        let fixture = try makeFoldFixture()
        let context = ProofEnvelopeContext(
            profileID: 1,
            kind: .terminalLocal,
            statement: CCSStatement(
                shapeDigest: fixture.input.shape.shapeDigest,
                ccsInstances: fixture.input.instances
            ),
            verifierKeyDigest: fixture.key.verifierKeyDigest
        )
        let fold = try fixture.backend.makeProver(key: fixture.key).foldWithOutput(
            fixture.input,
            transcriptSeed: context.transcriptBindingBytes
        )
        let terminalStatement = try TerminalCEStatement(
            profileID: fixture.key.parameters.profileID,
            shape: fixture.input.shape,
            key: fixture.key,
            claims: fold.outputClaims
        )
        let proof = TerminalFoldProof(
            foldProof: fold.proof,
            terminalStatement: terminalStatement,
            ceOpeningProof: try invalidCEOpeningProof(openingCount: terminalStatement.openings.count)
        )
        let envelope = try TerminalFoldProofEnvelope(context: context, proof: proof)
        let reparsed = try TerminalFoldProofEnvelope(bytes: envelope.superNeoBytes)
        let verifier = SuperNeoVerifier(key: fixture.key)

        XCTAssertEqual(reparsed.header.kind, .terminalLocal)
        XCTAssertEqual(reparsed.header.bodyLength, UInt32(reparsed.proof.superNeoBytes.count))
        XCTAssertTrue(reparsed.proof.outputClaims.allSatisfy { $0.witness == nil })
        XCTAssertThrowsSuperNeoError(
            try FoldProofEnvelope(bytes: envelope.superNeoBytes),
            .invalidEncoding("fold proof envelope kind mismatch")
        )
        XCTAssertInvalid(
            verifier.verifyTerminalFoldEnvelope(
                input: fixture.input,
                proofBytes: reparsed.superNeoBytes,
                context: context
            ),
            reason: "terminal CE opening proof verification failed"
        )

        let terminalStatementOffset = ProofEnvelopeHeader.byteCount + proof.foldProof.superNeoBytes.count
        var mutatedTerminalStatementKey = envelope.superNeoBytes
        mutatedTerminalStatementKey[terminalStatementOffset + terminalCEStatementVerifierKeyDigestOffset] ^= 0x01
        XCTAssertThrowsSuperNeoError(
            try TerminalFoldProofEnvelope(bytes: mutatedTerminalStatementKey),
            .invalidParameter("terminal CE statement verifier key mismatch")
        )

        var mutatedFirstOpeningKey = envelope.superNeoBytes
        let firstOpeningOffset = terminalStatementOffset
            + terminalCEStatementVerifierKeyDigestOffset
            + Digest256.byteCount
            + encodedCountByteWidth
        mutatedFirstOpeningKey[firstOpeningOffset + ceOpeningStatementVerifierKeyDigestOffset] ^= 0x01
        XCTAssertThrowsSuperNeoError(
            try TerminalFoldProofEnvelope(bytes: mutatedFirstOpeningKey),
            .invalidParameter("terminal CE statement verifier key mismatch")
        )
    }

    func testCompressedPublicEnvelopeRoundTripsAndBindsPublicInputs() throws {
        let fixture = try makeFoldFixture()
        let statement = CCSStatement(
            shapeDigest: fixture.input.shape.shapeDigest,
            ccsInstances: fixture.input.instances
        )
        let context = ProofEnvelopeContext(
            profileID: 1,
            kind: .compressedPublic,
            statement: statement,
            verifierKeyDigest: fixture.key.verifierKeyDigest
        )
        let envelope = try fixture.backend.makeProver(key: fixture.key).compressedTerminalFoldEnvelopeForTesting(
            fixture.input,
            context: context,
            ceRandomSeed: Array("compressed-ce".utf8)
        )
        let reparsed = try CompressedTerminalProofEnvelope(bytes: envelope.superNeoBytes)
        let verifier = SuperNeoVerifier(key: fixture.key)
        let reconstructedTerminalStatement = try TerminalCEStatement(
            profileID: context.profileID,
            shape: fixture.input.shape,
            key: fixture.key,
            claims: reparsed.proof.foldProof.outputClaims
        )
        let reconstructedTerminalProof = TerminalFoldProof(
            foldProof: reparsed.proof.foldProof,
            terminalStatement: reconstructedTerminalStatement,
            ceOpeningProof: reparsed.proof.ceOpeningProof
        )

        XCTAssertEqual(reparsed.header.kind, .compressedPublic)
        XCTAssertEqual(reparsed.header.bodyLength, UInt32(reparsed.proof.superNeoBytes.count))
        XCTAssertLessThan(reparsed.proof.superNeoBytes.count, reconstructedTerminalProof.superNeoBytes.count)
        XCTAssertEqual(reparsed.proof.statement.terminalStatementDigest, reconstructedTerminalStatement.statementDigest)
        XCTAssertEqual(reparsed.proof.foldProofDigest, Digest256.hash(reparsed.proof.foldProof.superNeoBytes))
        XCTAssertEqual(reparsed.proof.ceOpeningProofDigest, Digest256.hash(reparsed.proof.ceOpeningProof.superNeoBytes))
        XCTAssertEqual(
            verifier.verifyCompressedTerminalFoldEnvelope(
                publicInput: SuperNeoPublicFoldInput(fixture.input),
                proofBytes: reparsed.superNeoBytes,
                context: context
            ),
            .valid
        )

        var tamperedInput = fixture.input
        var tamperedInstancePublic = tamperedInput.instances[0].publicInput
        tamperedInstancePublic[0] = tamperedInstancePublic[0] + .one
        tamperedInput = SuperNeoFoldInput(
            shape: fixture.input.shape,
            instances: [CCSInstance(commitment: fixture.input.instances[0].commitment, publicInput: tamperedInstancePublic)],
            witnesses: fixture.input.witnesses,
            priorClaims: fixture.input.priorClaims
        )
        XCTAssertInvalid(
            verifier.verifyCompressedTerminalFoldEnvelope(
                publicInput: SuperNeoPublicFoldInput(tamperedInput),
                proofBytes: reparsed.superNeoBytes,
                context: context
            ),
            reason: "input statement digest mismatch"
        )

        var mutatedHeaderKey = envelope.superNeoBytes
        mutatedHeaderKey[proofEnvelopeVerifierKeyDigestOffset] ^= 0x01
        XCTAssertInvalid(
            verifier.verifyCompressedTerminalFoldEnvelope(
                publicInput: SuperNeoPublicFoldInput(fixture.input),
                proofBytes: mutatedHeaderKey,
                context: context
            ),
            reason: "verifier key digest mismatch"
        )

        var mutatedFoldProofDigest = envelope.superNeoBytes
        mutatedFoldProofDigest[ProofEnvelopeHeader.byteCount + reparsed.proof.statement.superNeoBytes.count] ^= 0x01
        XCTAssertThrowsSuperNeoError(
            try CompressedTerminalProofEnvelope(bytes: mutatedFoldProofDigest),
            .invalidEncoding("compressed fold proof digest mismatch")
        )

        var mutatedCompressedContextKey = envelope.superNeoBytes
        mutatedCompressedContextKey[
            ProofEnvelopeHeader.byteCount + compressedStatementContextVerifierKeyDigestOffset
        ] ^= 0x01
        XCTAssertThrowsSuperNeoError(
            try CompressedTerminalProofEnvelope(bytes: mutatedCompressedContextKey),
            .invalidEncoding("compressed terminal proof transcript mismatch")
        )

        var mutatedCompressedRelationKey = envelope.superNeoBytes
        mutatedCompressedRelationKey[
            ProofEnvelopeHeader.byteCount + compressedStatementVerifierKeyDigestOffset
        ] ^= 0x01
        XCTAssertThrowsSuperNeoError(
            try CompressedTerminalProofEnvelope(bytes: mutatedCompressedRelationKey),
            .invalidEncoding("compressed terminal proof transcript mismatch")
        )
    }

    func testCCSNormalizerPadsGeneralShapeIntoPaperNormalizedInput() throws {
        let publicInput = [GoldilocksField.one]
        let witness = [GoldilocksField.zero, GoldilocksField.one]
        let matrix = try SparseFieldMatrix(
            rows: 3,
            columns: 3,
            entries: [
                SparseFieldMatrix.Entry(row: 0, column: 0, value: .one),
                SparseFieldMatrix.Entry(row: 1, column: 1, value: .one),
                SparseFieldMatrix.Entry(row: 2, column: 2, value: .one)
            ]
        )
        let relation = try RelationPolynomial(variableCount: 1, monomials: [])
        let structure = CCSStructure(matrices: [matrix], relationPolynomial: relation)
        let originalCommitment = AjtaiCommitment(Array(repeating: .zero, count: SuperNeoParameters.goldilocks.kappa))
        let result = try SuperNeoCCSNormalizer.normalize(
            structure: structure,
            instances: [CCSInstance(commitment: originalCommitment, publicInput: publicInput)],
            witnesses: [CCSWitness(witness)],
            keySeed: Array("normalized-key".utf8)
        )
        let highAssuranceResult = try SuperNeoCCSNormalizer.normalize(
            structure: structure,
            instances: [CCSInstance(commitment: originalCommitment, publicInput: publicInput)],
            witnesses: [CCSWitness(witness)],
            keySeed: Array("normalized-key".utf8),
            executionPolicy: .highAssurance
        )

        XCTAssertEqual(result.normalized.shape.m, 64)
        XCTAssertEqual(result.normalized.shape.nField, 64)
        XCTAssertEqual(result.normalized.shape.nPublicField, 54)
        XCTAssertTrue(result.normalized.shape.hasIdentityFirstMatrix)
        XCTAssertEqual(result.normalized.mapping.originalRowCount, 3)
        XCTAssertEqual(result.normalized.mapping.addedPublicInputs, 53)
        XCTAssertTrue(result.normalized.mapping.addedIdentityMatrix)
        XCTAssertEqual(try result.normalized.mapping.normalizedMatrixIndex(forOriginalMatrix: 0), 1)
        XCTAssertEqual(result.normalized.instances[0].publicInput.count, 54)
        XCTAssertEqual(result.normalized.witnesses[0].values.count, 10)
        XCTAssertFalse(SuperNeoFoldingShapeContract.paperNormalized.requiresNormalization(result.normalized.shape))
        XCTAssertNoThrow(try SuperNeoFoldingShapeContract.paperNormalized.validate(result.normalized.shape))

        let normalizedPublic = try result.normalized.mapping.embedPublicInput(publicInput)
        let normalizedPrivate = try result.normalized.mapping.embedPrivateWitness(witness)
        let normalizedWitness = try result.normalized.mapping.embedFullWitness(
            publicInput: publicInput,
            privateWitness: witness
        )
        XCTAssertEqual(result.normalized.instances[0].publicInput, normalizedPublic)
        XCTAssertEqual(result.normalized.witnesses[0].values, normalizedPrivate)
        XCTAssertEqual(highAssuranceResult.key, result.key)
        XCTAssertEqual(highAssuranceResult.normalized.instances, result.normalized.instances)
        XCTAssertEqual(highAssuranceResult.normalized.witnesses, result.normalized.witnesses)
        XCTAssertEqual(try result.normalized.mapping.projectPublicInput(normalizedPublic), publicInput)
        XCTAssertEqual(try result.normalized.mapping.projectPrivateWitness(normalizedPrivate), witness)
        XCTAssertEqual(try result.normalized.mapping.projectFullWitness(normalizedWitness), publicInput + witness)

        let originalRows = try matrix.multiplied(by: publicInput + witness)
        let normalizedMatrixRows = try result.normalized.shape.structure.matrices[1].multiplied(by: normalizedWitness)
        let normalizedIdentityRows = try result.normalized.shape.structure.matrices[0].multiplied(by: normalizedWitness)
        XCTAssertEqual(Array(normalizedMatrixRows.prefix(originalRows.count)), originalRows)
        XCTAssertTrue(normalizedMatrixRows.dropFirst(originalRows.count).allSatisfy { $0 == .zero })
        XCTAssertEqual(normalizedIdentityRows, normalizedWitness)

        XCTAssertNoThrow(try SuperNeoVerifier(key: result.key).reduceFold(input: result.normalized.foldInput, proof: SuperNeoProver(key: result.key).fold(result.normalized.foldInput)))
    }

    func testFoldingShapeContractReportsPaperNormalizationRequirementsForRawCCS() throws {
        let matrix = try SparseFieldMatrix(
            rows: 3,
            columns: 5,
            entries: [
                SparseFieldMatrix.Entry(row: 0, column: 4, value: .one)
            ]
        )
        let relation = try RelationPolynomial(variableCount: 1, monomials: [])
        let structure = CCSStructure(matrices: [matrix], relationPolynomial: relation)

        let requirements = try SuperNeoFoldingShapeContract.paperNormalized.normalizationRequirements(
            for: structure,
            publicInputCount: 1
        )

        XCTAssertEqual(requirements, [
            .positivePowerOfTwoRows(rowCount: 3),
            .squareFieldShape(rowCount: 3, fieldColumnCount: 5),
            .identityFirstMatrix,
            .wholeRingPublicInput(publicInputCount: 1, ringDegree: CyclotomicRing54.degree)
        ])
        XCTAssertEqual(requirements.map { $0.diagnostic }, [
            "CCS row count must be a positive power of two (rowCount: 3)",
            "shape.nField must equal shape.m (m: 3, nField: 5)",
            "M1 must be the identity matrix",
            "public input length must contain whole ring columns for R-module folding (nPublicField: 1, ringDegree: 54)"
        ])
        XCTAssertThrowsSuperNeoError(
            try SuperNeoFoldingShapeContract.paperNormalized.validate(structure, publicInputCount: 1),
            .invalidParameter(
                "SuperNeo folding requires a paper-normalized CCS shape: CCS row count must be a positive power of two; shape.nField must equal shape.m; M1 must be the identity matrix; public input length must contain whole ring columns for R-module folding; use SuperNeoCCSNormalizer.normalize(...) for general CCS inputs"
            )
        )
    }

    func testPrepareForFoldingNormalizesGeneralCCSAndReportsOriginalRequirements() throws {
        let publicInput = [GoldilocksField.one]
        let witness = [GoldilocksField.zero, GoldilocksField.one]
        let matrix = try SparseFieldMatrix.identity(size: 3)
        let relation = try RelationPolynomial(variableCount: 1, monomials: [])
        let structure = CCSStructure(matrices: [matrix], relationPolynomial: relation)
        let originalCommitment = AjtaiCommitment(Array(repeating: .zero, count: SuperNeoParameters.goldilocks.kappa))

        let prepared = try SuperNeoCCSNormalizer.prepareForFolding(
            structure: structure,
            instances: [CCSInstance(commitment: originalCommitment, publicInput: publicInput)],
            witnesses: [CCSWitness(witness)],
            keySeed: Array("prepared-general-key".utf8)
        )
        let hardenedPrepared = try SuperNeoCCSNormalizer.prepareForFolding(
            structure: structure,
            instances: [CCSInstance(commitment: originalCommitment, publicInput: publicInput)],
            witnesses: [CCSWitness(witness)],
            keySeed: Array("prepared-general-key".utf8),
            executionPolicy: .highAssurance
        )

        XCTAssertTrue(prepared.requiresNormalization)
        XCTAssertEqual(hardenedPrepared.key, prepared.key)
        XCTAssertEqual(hardenedPrepared.foldInput.instances, prepared.foldInput.instances)
        XCTAssertEqual(hardenedPrepared.foldInput.witnesses, prepared.foldInput.witnesses)
        XCTAssertEqual(prepared.originalNormalizationRequirements, [
            .positivePowerOfTwoRows(rowCount: 3),
            .wholeRingPublicInput(publicInputCount: 1, ringDegree: CyclotomicRing54.degree)
        ])
        XCTAssertFalse(SuperNeoFoldingShapeContract.paperNormalized.requiresNormalization(prepared.foldInput.shape))
        XCTAssertNoThrow(try SuperNeoFoldingShapeContract.paperNormalized.validate(prepared.foldInput.shape))
        XCTAssertEqual(prepared.foldInput.instances[0].publicInput.count, CyclotomicRing54.degree)
        XCTAssertEqual(prepared.foldInput.witnesses[0].values.count, 10)
        XCTAssertNoThrow(try SuperNeoVerifier(key: prepared.key).reduceFold(input: prepared.foldInput, proof: SuperNeoProver(key: prepared.key).fold(prepared.foldInput)))
    }

    func testPrepareForFoldingAcceptsAlreadyPaperNormalizedInputWithoutRequirements() throws {
        let fixture = try makeFoldFixture()

        let prepared = try SuperNeoCCSNormalizer.prepareForFolding(
            structure: fixture.input.structure,
            instances: fixture.input.instances,
            witnesses: fixture.input.witnesses,
            keySeed: Array("fold-key".utf8)
        )

        XCTAssertFalse(prepared.requiresNormalization)
        XCTAssertEqual(prepared.originalNormalizationRequirements, [])
        XCTAssertEqual(prepared.foldInput.shape, fixture.input.shape)
        XCTAssertEqual(prepared.foldInput.instances, fixture.input.instances)
        XCTAssertEqual(prepared.foldInput.witnesses, fixture.input.witnesses)
        XCTAssertNoThrow(try SuperNeoVerifier(key: prepared.key).reduceFold(input: prepared.foldInput, proof: SuperNeoProver(key: prepared.key).fold(prepared.foldInput)))
    }

    func testDirectFoldInputRequiresPaperNormalizedShapeContract() throws {
        let matrix = try SparseFieldMatrix(
            rows: 4,
            columns: 5,
            entries: (0..<4).map {
                SparseFieldMatrix.Entry(row: $0, column: $0, value: .one)
            }
        )
        let relation = try RelationPolynomial(variableCount: 1, monomials: [])
        let structure = CCSStructure(matrices: [matrix], relationPolynomial: relation)

        let shape = try CCSShape(
            matrices: [matrix],
            publicInputCount: 0,
            relationPolynomial: relation
        )
        XCTAssertTrue(SuperNeoFoldingShapeContract.paperNormalized.requiresNormalization(shape))
        XCTAssertThrowsSuperNeoError(
            try SuperNeoFoldingShapeContract.paperNormalized.validate(shape),
            .invalidParameter(
                "SuperNeo folding requires a paper-normalized CCS shape: shape.nField must equal shape.m; use SuperNeoCCSNormalizer.normalize(...) for general CCS inputs"
            )
        )
        XCTAssertThrowsSuperNeoError(
            try SuperNeoFoldInput(structure: structure, instances: [], witnesses: []),
            .invalidParameter(
                "SuperNeo folding requires a paper-normalized CCS shape: shape.nField must equal shape.m; use SuperNeoCCSNormalizer.normalize(...) for general CCS inputs"
            )
        )
    }

    func testDirectFoldInputRoutesRawGeneralCCSToNormalizerBeforeShapeConstruction() throws {
        let publicInput = [GoldilocksField.one]
        let witness = [GoldilocksField.zero, GoldilocksField.one]
        let matrix = try SparseFieldMatrix.identity(size: 3)
        let relation = try RelationPolynomial(variableCount: 1, monomials: [])
        let structure = CCSStructure(matrices: [matrix], relationPolynomial: relation)
        let originalCommitment = AjtaiCommitment(Array(repeating: .zero, count: SuperNeoParameters.goldilocks.kappa))

        XCTAssertThrowsSuperNeoError(
            try SuperNeoFoldInput(
                structure: structure,
                instances: [CCSInstance(commitment: originalCommitment, publicInput: publicInput)],
                witnesses: [CCSWitness(witness)]
            ),
            .invalidParameter(
                "SuperNeo folding requires a paper-normalized CCS shape: CCS row count must be a positive power of two; public input length must contain whole ring columns for R-module folding; use SuperNeoCCSNormalizer.normalize(...) for general CCS inputs"
            )
        )
    }

    func testCCSNormalizerRejectsPriorClaimsBeforeChangingShapeAndKey() throws {
        let publicInput = [GoldilocksField.one]
        let witness = [GoldilocksField.zero, GoldilocksField.one]
        let matrix = try SparseFieldMatrix(
            rows: 3,
            columns: 3,
            entries: [
                SparseFieldMatrix.Entry(row: 0, column: 0, value: .one),
                SparseFieldMatrix.Entry(row: 1, column: 1, value: .one),
                SparseFieldMatrix.Entry(row: 2, column: 2, value: .one)
            ]
        )
        let relation = try RelationPolynomial(variableCount: 1, monomials: [])
        let structure = CCSStructure(matrices: [matrix], relationPolynomial: relation)
        let originalCommitment = AjtaiCommitment(Array(repeating: .zero, count: SuperNeoParameters.goldilocks.kappa))
        let priorClaim = CCSEvaluationClaim(
            commitment: originalCommitment,
            publicInput: publicInput,
            point: [GoldilocksExt2.zero, GoldilocksExt2.zero],
            evaluations: [CyclotomicExt2Ring54.zero],
            witness: publicInput + witness
        )

        XCTAssertThrowsSuperNeoError(
            try SuperNeoCCSNormalizer.normalize(
                structure: structure,
                instances: [CCSInstance(commitment: originalCommitment, publicInput: publicInput)],
                witnesses: [CCSWitness(witness)],
                priorClaims: [priorClaim],
                keySeed: Array("normalized-key-with-prior".utf8)
            ),
            .invalidParameter("normalization requires empty prior CE claims; normalize before producing prior claims")
        )
    }

    func testProofEnvelopeRejectsProfileMismatchBeforeTranscriptVerification() throws {
        let fixture = try makeFoldFixture()
        let context = makeEnvelopeContext(for: fixture.input, verifierKeyDigest: fixture.key.verifierKeyDigest)
        let proofBytes = try fixture.backend.makeProver(key: fixture.key)
            .foldEnvelope(fixture.input, context: context)
            .superNeoBytes
        let wrongContext = makeEnvelopeContext(
            for: fixture.input,
            profileID: 8,
            verifierKeyDigest: fixture.key.verifierKeyDigest
        )

        let result = SuperNeoVerifier(key: fixture.key).reduceFoldEnvelope(
            input: fixture.input,
            proofBytes: proofBytes,
            context: wrongContext
        )

        XCTAssertFalse(result.isReductionAccepted)
        XCTAssertFalse(result.requiresTerminalRelationCheck)
        XCTAssertEqual(result.reason, "profile mismatch")
    }

    func testProofEnvelopeRejectsTrailingBytes() throws {
        let fixture = try makeFoldFixture()
        let context = makeEnvelopeContext(for: fixture.input, verifierKeyDigest: fixture.key.verifierKeyDigest)
        var proofBytes = try fixture.backend.makeProver(key: fixture.key)
            .foldEnvelope(fixture.input, context: context)
            .superNeoBytes
        proofBytes.append(0)

        XCTAssertThrowsError(try FoldProofEnvelope(bytes: proofBytes)) { error in
            XCTAssertEqual(error as? SuperNeoError, .invalidEncoding("trailing proof bytes"))
        }
    }

    func testProofEnvelopeRejectsHeaderTamperingAndLengthMismatch() throws {
        let fixture = try makeFoldFixture()
        let context = makeEnvelopeContext(for: fixture.input, verifierKeyDigest: fixture.key.verifierKeyDigest)
        let proofBytes = try fixture.backend.makeProver(key: fixture.key)
            .foldEnvelope(fixture.input, context: context)
            .superNeoBytes

        let header = try ProofEnvelopeHeader.parsePrefix(from: proofBytes)
        XCTAssertEqual(header.profileID, context.profileID)
        XCTAssertEqual(header.kind, .foldReduction)
        XCTAssertEqual(header.shapeDigest, context.shapeDigest)
        XCTAssertEqual(header.statementDigest, context.statementDigest)
        XCTAssertEqual(header.verifierKeyDigest, context.verifierKeyDigest)
        XCTAssertNoThrow(try header.validateEnvelopeLength(totalByteCount: proofBytes.count))

        XCTAssertThrowsSuperNeoError(
            try ProofEnvelopeHeader.parsePrefix(from: Array(proofBytes.prefix(ProofEnvelopeHeader.byteCount - 1))),
            .invalidEncoding("proof envelope is shorter than its header")
        )

        var wrongMagic = proofBytes
        wrongMagic[0] ^= 1
        XCTAssertThrowsSuperNeoError(
            try FoldProofEnvelope(bytes: wrongMagic),
            .invalidEncoding("wrong proof magic")
        )
        XCTAssertThrowsSuperNeoError(
            try ProofEnvelopeHeader.parsePrefix(from: wrongMagic),
            .invalidEncoding("wrong proof magic")
        )

        var wrongVersion = proofBytes
        wrongVersion[4] = 0
        wrongVersion[5] = 0
        XCTAssertThrowsSuperNeoError(
            try FoldProofEnvelope(bytes: wrongVersion),
            .invalidEncoding("unsupported proof version")
        )

        var tooLongBody = proofBytes
        writeUInt32(UInt32(proofBytes.count - ProofEnvelopeHeader.byteCount + 1), into: &tooLongBody, at: ProofEnvelopeHeader.byteCount - 4)
        let tooLongHeader = try ProofEnvelopeHeader.parsePrefix(from: tooLongBody)
        XCTAssertThrowsSuperNeoError(
            try tooLongHeader.validateEnvelopeLength(totalByteCount: tooLongBody.count),
            .invalidEncoding("proof envelope body length mismatch")
        )
        XCTAssertThrowsSuperNeoError(
            try FoldProofEnvelope(bytes: tooLongBody),
            .invalidEncoding("unexpected end of proof bytes")
        )
    }

    func testProofEnvelopeRejectsKindMismatch() throws {
        let fixture = try makeFoldFixture()
        let context = makeEnvelopeContext(for: fixture.input, verifierKeyDigest: fixture.key.verifierKeyDigest)
        var proofBytes = try fixture.backend.makeProver(key: fixture.key)
            .foldEnvelope(fixture.input, context: context)
            .superNeoBytes

        proofBytes[8] = ProofEnvelopeKind.terminalLocal.rawValue
        XCTAssertThrowsSuperNeoError(
            try FoldProofEnvelope(bytes: proofBytes),
            .invalidEncoding("fold proof envelope kind mismatch")
        )

        let wrongContext = makeEnvelopeContext(
            for: fixture.input,
            kind: .terminalLocal,
            verifierKeyDigest: fixture.key.verifierKeyDigest
        )
        let result = SuperNeoVerifier(key: fixture.key).reduceFoldEnvelope(
            input: fixture.input,
            proofBytes: try fixture.backend.makeProver(key: fixture.key).foldEnvelope(fixture.input, context: context).superNeoBytes,
            context: wrongContext
        )
        XCTAssertFalse(result.isReductionAccepted)
        XCTAssertFalse(result.requiresTerminalRelationCheck)
        XCTAssertEqual(result.reason, "proof kind mismatch")
    }

    func testProofEnvelopeRejectsShapeStatementAndTranscriptDomainMismatch() throws {
        let fixture = try makeFoldFixture()
        let context = makeEnvelopeContext(for: fixture.input, verifierKeyDigest: fixture.key.verifierKeyDigest)
        let proofBytes = try fixture.backend.makeProver(key: fixture.key)
            .foldEnvelope(fixture.input, context: context)
            .superNeoBytes
        let verifier = SuperNeoVerifier(key: fixture.key)

        XCTAssertInvalid(
            verifier.reduceFoldEnvelope(
                input: fixture.input,
                proofBytes: proofBytes,
                context: makeEnvelopeContext(
                    for: fixture.input,
                    shapeDigest: .hash("wrong-shape"),
                    verifierKeyDigest: fixture.key.verifierKeyDigest
                )
            ),
            reason: "shape digest mismatch"
        )
        XCTAssertInvalid(
            verifier.reduceFoldEnvelope(
                input: fixture.input,
                proofBytes: proofBytes,
                context: makeEnvelopeContext(
                    for: fixture.input,
                    statementDigest: .hash("wrong-statement"),
                    verifierKeyDigest: fixture.key.verifierKeyDigest
                )
            ),
            reason: "statement digest mismatch"
        )
        XCTAssertInvalid(
            verifier.reduceFoldEnvelope(
                input: fixture.input,
                proofBytes: proofBytes,
                context: makeEnvelopeContext(
                    for: fixture.input,
                    verifierKeyDigest: fixture.key.verifierKeyDigest,
                    transcriptDomain: .hash("wrong-domain")
                )
            ),
            reason: "transcript domain mismatch"
        )
    }

    func testProverEnvelopeRejectsMismatchedContextBinding() throws {
        let fixture = try makeFoldFixture()
        let prover = fixture.backend.makeProver(key: fixture.key)
        let context = makeEnvelopeContext(for: fixture.input, verifierKeyDigest: fixture.key.verifierKeyDigest)

        XCTAssertThrowsSuperNeoError(
            try prover.foldEnvelope(
                fixture.input,
                context: makeEnvelopeContext(
                    for: fixture.input,
                    profileID: context.profileID + 1,
                    verifierKeyDigest: fixture.key.verifierKeyDigest
                )
            ),
            .invalidParameter("proof envelope context profile mismatch")
        )
        XCTAssertThrowsSuperNeoError(
            try prover.foldEnvelope(
                fixture.input,
                context: makeEnvelopeContext(
                    for: fixture.input,
                    kind: .terminalLocal,
                    verifierKeyDigest: fixture.key.verifierKeyDigest
                )
            ),
            .invalidParameter("proof envelope context kind mismatch")
        )
        XCTAssertThrowsSuperNeoError(
            try prover.foldEnvelope(
                fixture.input,
                context: makeEnvelopeContext(
                    for: fixture.input,
                    shapeDigest: .hash("prover-wrong-shape"),
                    verifierKeyDigest: fixture.key.verifierKeyDigest
                )
            ),
            .invalidParameter("proof envelope context shape digest mismatch")
        )
        XCTAssertThrowsSuperNeoError(
            try prover.foldEnvelope(
                fixture.input,
                context: makeEnvelopeContext(
                    for: fixture.input,
                    statementDigest: .hash("prover-wrong-statement"),
                    verifierKeyDigest: fixture.key.verifierKeyDigest
                )
            ),
            .invalidParameter("proof envelope context statement digest mismatch")
        )
        XCTAssertThrowsSuperNeoError(
            try prover.terminalFoldEnvelope(
                fixture.input,
                context: makeEnvelopeContext(
                    for: fixture.input,
                    kind: .terminalLocal,
                    statementDigest: .hash("terminal-wrong-statement"),
                    verifierKeyDigest: fixture.key.verifierKeyDigest
                )
            ),
            .invalidParameter("proof envelope context statement digest mismatch")
        )
        XCTAssertThrowsSuperNeoError(
            try prover.compressedTerminalFoldEnvelope(
                fixture.input,
                context: makeEnvelopeContext(
                    for: fixture.input,
                    kind: .compressedPublic,
                    shapeDigest: .hash("compressed-wrong-shape"),
                    verifierKeyDigest: fixture.key.verifierKeyDigest
                )
            ),
            .invalidParameter("proof envelope context shape digest mismatch")
        )
    }

    func testProofEnvelopeRejectsNonCanonicalFieldEncoding() throws {
        let fixture = try makeFoldFixture()
        let context = makeEnvelopeContext(for: fixture.input, verifierKeyDigest: fixture.key.verifierKeyDigest)
        var proofBytes = try fixture.backend.makeProver(key: fixture.key)
            .foldEnvelope(fixture.input, context: context)
            .superNeoBytes

        let firstFieldOffset = ProofEnvelopeHeader.byteCount + 8
        let nonCanonical = withUnsafeBytes(of: GoldilocksField.modulus.littleEndian, Array.init)
        proofBytes.replaceSubrange(firstFieldOffset..<firstFieldOffset + 8, with: nonCanonical)

        XCTAssertThrowsError(try FoldProofEnvelope(bytes: proofBytes)) { error in
            XCTAssertEqual(error as? SuperNeoError, .invalidEncoding("non-canonical Goldilocks element"))
        }
    }

    func testVerifierRejectsTamperedRLCChallenge() throws {
        let fixture = try makeFoldFixture()
        let proof = try fixture.backend.makeProver(key: fixture.key).fold(fixture.input, transcriptSeed: fixture.seed)
        var challenges = proof.randomLinearCombinationChallenges
        challenges[0] = challenges[0] + .one
        let tampered = replacing(proof, randomLinearCombinationChallenges: challenges)

        let result = SuperNeoVerifier(key: fixture.key).reduceFold(input: fixture.input, proof: tampered, transcriptSeed: fixture.seed)

        XCTAssertFalse(result.isReductionAccepted)
        XCTAssertFalse(result.requiresTerminalRelationCheck)
        XCTAssertEqual(result.reason, "repeated PiRLC branch 0 verification failed")
    }

    func testVerifierRejectsRepeatedPiCCSTapeMismatch() throws {
        let fixture = try makeFoldFixture()
        let proof = try fixture.backend.makeProver(key: fixture.key).fold(fixture.input, transcriptSeed: fixture.seed)
        XCTAssertEqual(proof.piCCSTapes.count, FoldProof.selectedPiCCSTapeCount)

        var auxiliaryTapes = proof.auxiliaryPiCCSTapes
        let badTape = auxiliaryTapes[0]
        let badSumcheck = SumcheckProof(
            claimedSum: badTape.sumCheck.claimedSum,
            rounds: badTape.sumCheck.rounds,
            finalPoint: badTape.sumCheck.finalPoint,
            finalValue: badTape.sumCheck.finalValue + .one
        )
        auxiliaryTapes[0] = PiCCSSection(sumCheck: badSumcheck, finalClaims: badTape.finalClaims)

        let tampered = replacing(proof, auxiliaryPiCCSTapes: auxiliaryTapes)
        let result = SuperNeoVerifier(key: fixture.key).reduceFold(input: fixture.input, proof: tampered, transcriptSeed: fixture.seed)

        XCTAssertFalse(result.isReductionAccepted)
        XCTAssertEqual(result.reason, "repeated PiCCS tape 1 verification failed")
    }

    func testVerifierRejectsRepeatedPiRLCBranchMismatch() throws {
        let fixture = try makeFoldFixture()
        let proof = try fixture.backend.makeProver(key: fixture.key).fold(fixture.input, transcriptSeed: fixture.seed)
        XCTAssertEqual(proof.piRLCBranches.count, FoldProof.selectedPiRLCBranchCount)

        var auxiliaryBranches = proof.auxiliaryPiRLCBranches
        let badBranch = auxiliaryBranches[0]
        var badChallenges = badBranch.challenges
        badChallenges[0] = badChallenges[0] + .one
        auxiliaryBranches[0] = PiRLCBranch(
            piRLC: PiRLCSection(challenges: badChallenges, foldedClaim: badBranch.foldedClaim),
            piDEC: badBranch.piDEC
        )

        let tampered = replacing(proof, auxiliaryPiRLCBranches: auxiliaryBranches)
        let result = SuperNeoVerifier(key: fixture.key).reduceFold(input: fixture.input, proof: tampered, transcriptSeed: fixture.seed)

        XCTAssertFalse(result.isReductionAccepted)
        XCTAssertEqual(result.reason, "repeated PiRLC branch 1 verification failed")
    }

    func testVerifierRejectsLegacyOneShotFoldProofForSelectedProfile() throws {
        let fixture = try makeFoldFixture()
        let proof = try fixture.backend.makeProver(key: fixture.key).fold(fixture.input, transcriptSeed: fixture.seed)
        let oneShot = FoldProof(
            sumCheck: proof.sumCheck,
            randomLinearCombinationChallenges: proof.randomLinearCombinationChallenges,
            piCCSClaims: proof.piCCSClaims,
            foldedClaim: proof.foldedClaim,
            decomposition: proof.decomposition,
            outputClaims: proof.outputClaims
        )

        let result = SuperNeoVerifier(key: fixture.key).reduceFold(input: fixture.input, proof: oneShot, transcriptSeed: fixture.seed)

        XCTAssertFalse(result.isReductionAccepted)
        XCTAssertTrue(result.reason?.contains("selected repeated-tape fold proof requires") == true)
    }

    func testFoldProofParserRejectsWrongRepeatedTapeCount() throws {
        let fixture = try makeFoldFixture()
        let context = makeEnvelopeContext(for: fixture.input, verifierKeyDigest: fixture.key.verifierKeyDigest)
        var proofBytes = try fixture.backend.makeProver(key: fixture.key)
            .foldEnvelope(fixture.input, context: context)
            .superNeoBytes

        writeUInt64(1, into: &proofBytes, at: ProofEnvelopeHeader.byteCount)

        XCTAssertThrowsError(try FoldProofEnvelope(bytes: proofBytes)) { error in
            XCTAssertEqual(error as? SuperNeoError, .invalidEncoding("wrong PiCCS repeated tape count"))
        }
    }

    func testProverRejectsMixedWitnessAvailabilityInRLCClaims() throws {
        let fixture = try makePaperAuditFixture()
        let prover = fixture.backend.makeProver(key: fixture.key)
        let sumCheck = try prover.benchmarkSumCheckProof(input: fixture.input, transcriptSeed: fixture.seed)
        var claims = try prover.benchmarkPiCCSClaims(input: fixture.input, point: sumCheck.finalPoint)
        XCTAssertGreaterThan(claims.count, 1)
        XCTAssertTrue(claims.allSatisfy { $0.witness != nil })

        claims[1] = removingWitness(from: claims[1])

        XCTAssertThrowsSuperNeoError(
            try prover.benchmarkPiRLC(input: fixture.input, claims: claims, transcriptSeed: fixture.seed),
            .invalidParameter("RLC claims must either all carry witnesses or all be public")
        )
    }

    func testPreparedPiRLCTranscriptMatchesFoldAndRejectsWrongPoint() throws {
        let fixture = try makeFoldFixture()
        let prover = fixture.backend.makeProver(key: fixture.key)
        let sumCheck = try prover.benchmarkSumCheckProof(input: fixture.input, transcriptSeed: fixture.seed)
        let claims = try prover.benchmarkPiCCSClaims(input: fixture.input, point: sumCheck.finalPoint)
        let preparedTranscript = try prover.preparePiRLCTranscript(
            input: fixture.input,
            sumCheck: sumCheck,
            claims: claims,
            transcriptSeed: fixture.seed
        )

        let rlc = try prover.benchmarkPiRLC(
            claims: claims,
            preparedTranscript: preparedTranscript
        )

        XCTAssertEqual(rlc.challenges.count, claims.count)
        XCTAssertEqual(rlc.foldedClaim.point, sumCheck.finalPoint)

        var wrongPoint = sumCheck.finalPoint
        wrongPoint[0] = wrongPoint[0] + .one
        var wrongClaims = claims
        wrongClaims[0] = replacing(wrongClaims[0], point: wrongPoint)
        XCTAssertThrowsSuperNeoError(
            try prover.preparePiRLCTranscript(
                input: fixture.input,
                sumCheck: sumCheck,
                claims: wrongClaims,
                transcriptSeed: fixture.seed
            ),
            .invalidParameter("PiRLC claims must use the sum-check final point")
        )
    }

    func testVerifierRejectsTamperedDecompositionCommitment() throws {
        let fixture = try makeFoldFixture()
        let proof = try fixture.backend.makeProver(key: fixture.key).fold(fixture.input, transcriptSeed: fixture.seed)
        var outputClaims = proof.outputClaims
        let brokenCommitment = outputClaims[0].commitment
            + AjtaiCommitment(Array(repeating: CyclotomicRing54.one, count: fixture.key.parameters.kappa))
        outputClaims[0] = CCSEvaluationClaim(
            commitment: brokenCommitment,
            publicInput: outputClaims[0].publicInput,
            point: outputClaims[0].point,
            evaluations: outputClaims[0].evaluations,
            witness: outputClaims[0].witness
        )
        let tampered = replacing(proof, outputClaims: outputClaims)

        let result = SuperNeoVerifier(key: fixture.key).reduceFold(input: fixture.input, proof: tampered, transcriptSeed: fixture.seed)

        XCTAssertFalse(result.isReductionAccepted)
        XCTAssertFalse(result.requiresTerminalRelationCheck)
        XCTAssertEqual(result.reason, "invalidParameter(\"decomposition commitments must match output claims\")")
    }

}

final class NumiSealCanonicalizationTests: SuperNeoTestCase {
    private struct NumiSealProofBodyFixture {
        let obligation: NumiSealObligation
        let publicStatement: NumiSealPublicStatement
        let policy: NumiSealAcceptancePolicy
        let terminalPolicy: NumiSealTerminalProofAcceptancePolicy
        let aggregate: NumiSealLaneAggregate
        let digitTensor: NumiSealDigitTensor
        let decomposition: NumiSealDecompositionCommitment
        let scalarization: NumiSealLinearResidual
        let digitOpeningStatement: TerminalCEStatement
        let residualStatement: NumiSealResidualCEStatement
        let residualOpening: NumiSealResidualOpening
        let laneProof: NumiSealLaneProof
        let proof: NumiSealProof
        let envelope: NumiSealProofEnvelope
    }

    private struct NumiSealResidualCEFixture {
        let shape: CCSShape
        let key: AjtaiCommitmentKey
        let context: ProofEnvelopeContext
        let obligation: NumiSealObligation
        let claim: CCSEvaluationClaim
        let publicStatement: NumiSealPublicStatement
        let policy: NumiSealAcceptancePolicy
        let terminalPolicy: NumiSealTerminalProofAcceptancePolicy
        let aggregate: NumiSealLaneAggregate
        let witnessedAggregate: CCSEvaluationClaim
        let digitTensor: NumiSealDigitTensor
        let decomposition: NumiSealDecompositionCommitment
        let scalarization: NumiSealLinearResidual
        let digitOpeningStatement: TerminalCEStatement
        let residualStatement: NumiSealResidualCEStatement
        let residualOpening: NumiSealResidualOpening
        let laneProof: NumiSealLaneProof
        let proof: NumiSealProof
        let envelope: NumiSealProofEnvelope
    }

    private func makeNumiSealCanonicalFixture(
        claimCount: Int,
        laneID: NumiSealLaneID? = nil
    ) throws -> (
        canonicalization: NumiSealCanonicalizationResult,
        policy: NumiSealAcceptancePolicy,
        obligations: [NumiSealObligation]
    ) {
        let fixture = try makeFoldFixture()
        let fold = try fixture.backend.makeProver(key: fixture.key).foldWithOutput(
            fixture.input,
            transcriptSeed: fixture.seed
        )
        let publicInput = SuperNeoPublicFoldInput(fixture.input)
        let statement = CCSStatement(
            shapeDigest: publicInput.shape.shapeDigest,
            ccsInstances: publicInput.instances
        )
        let laneID = try laneID ?? NumiSealLaneID("main")
        let obligations = fold.outputClaims.prefix(claimCount).enumerated().map { index, claim in
            NumiSealObligation(
                laneID: laneID,
                profileID: fixture.key.parameters.profileID,
                statement: statement,
                verifierKeyDigest: fixture.key.verifierKeyDigest,
                instance: CEInstance(claim),
                sourceFoldDigest: Digest256.hash("numiseal-source-\(index)")
            )
        }
        let policy = NumiSealAcceptancePolicy(
            statement: statement,
            verifierKeyDigest: fixture.key.verifierKeyDigest,
            acceptedLaneIDs: [laneID]
        )
        let canonicalization = try NumiSealCanonicalization.canonicalize(
            obligations: obligations,
            policy: policy
        )
        return (canonicalization, policy, obligations)
    }

    func testNumiSealCanonicalizationIsDeterministicAcrossInputOrder() throws {
        let fixture = try makeFoldFixture()
        let fold = try fixture.backend.makeProver(key: fixture.key).foldWithOutput(
            fixture.input,
            transcriptSeed: fixture.seed
        )
        let publicInput = SuperNeoPublicFoldInput(fixture.input)
        let statement = CCSStatement(
            shapeDigest: publicInput.shape.shapeDigest,
            ccsInstances: publicInput.instances
        )
        let laneID = try NumiSealLaneID("main")
        let obligations = fold.outputClaims.prefix(2).enumerated().map { index, claim in
            NumiSealObligation(
                laneID: laneID,
                profileID: fixture.key.parameters.profileID,
                statement: statement,
                verifierKeyDigest: fixture.key.verifierKeyDigest,
                instance: CEInstance(claim),
                sourceFoldDigest: Digest256.hash("numiseal-source-\(index)")
            )
        }
        let policy = NumiSealAcceptancePolicy(
            shapeDigest: statement.shapeDigest,
            statementDigest: statement.statementDigest,
            verifierKeyDigest: fixture.key.verifierKeyDigest,
            acceptedLaneIDs: [laneID]
        )

        let canonical = try NumiSealCanonicalization.canonicalize(
            obligations: obligations,
            policy: policy
        )
        let canonicalFromReversed = try NumiSealCanonicalization.canonicalize(
            obligations: obligations.reversed(),
            policy: policy
        )

        XCTAssertEqual(canonical.obligationRoot, canonicalFromReversed.obligationRoot)
        XCTAssertEqual(canonical.laneSummaryRoot, canonicalFromReversed.laneSummaryRoot)
        XCTAssertEqual(
            canonical.obligations.map(\.obligationDigest),
            canonicalFromReversed.obligations.map(\.obligationDigest)
        )
        XCTAssertEqual(canonical.laneSummaries.count, 1)
        XCTAssertEqual(canonical.laneSummaries[0].obligationCount, obligations.count)
        XCTAssertEqual(canonical.laneSummaries[0].laneKey.laneID, laneID)
    }

    func testNumiSealCanonicalizationKeepsDistinctEvaluationPointsInSeparateLanes() throws {
        let fixture = try makeFoldFixture()
        let fold = try fixture.backend.makeProver(key: fixture.key).foldWithOutput(
            fixture.input,
            transcriptSeed: fixture.seed
        )
        let publicInput = SuperNeoPublicFoldInput(fixture.input)
        let statement = CCSStatement(
            shapeDigest: publicInput.shape.shapeDigest,
            ccsInstances: publicInput.instances
        )
        let laneID = try NumiSealLaneID("main")
        let claim = fold.outputClaims[0]
        let base = NumiSealObligation(
            laneID: laneID,
            profileID: fixture.key.parameters.profileID,
            statement: statement,
            verifierKeyDigest: fixture.key.verifierKeyDigest,
            instance: CEInstance(claim),
            sourceFoldDigest: Digest256.hash("numiseal-source-base")
        )
        var shiftedPoint = claim.point
        shiftedPoint[0] = shiftedPoint[0] + .one
        let shifted = NumiSealObligation(
            laneID: laneID,
            profileID: fixture.key.parameters.profileID,
            shapeDigest: statement.shapeDigest,
            statementDigest: statement.statementDigest,
            verifierKeyDigest: fixture.key.verifierKeyDigest,
            commitment: claim.commitment,
            publicInputEncoding: PublicInputEncoding(field: claim.publicInput),
            evalPoint: shiftedPoint,
            matrixEvaluations: claim.evaluations,
            sourceFoldDigest: Digest256.hash("numiseal-source-shifted")
        )
        let policy = NumiSealAcceptancePolicy(
            shapeDigest: statement.shapeDigest,
            statementDigest: statement.statementDigest,
            verifierKeyDigest: fixture.key.verifierKeyDigest,
            acceptedLaneIDs: [laneID]
        )

        let canonical = try NumiSealCanonicalization.canonicalize(
            obligations: [shifted, base],
            policy: policy
        )

        XCTAssertEqual(canonical.laneSummaries.count, 2)
        XCTAssertNotEqual(
            canonical.laneSummaries[0].laneKey.evalPointDigest,
            canonical.laneSummaries[1].laneKey.evalPointDigest
        )

        let aggregates = try NumiSealLaneAggregation.aggregate(
            canonicalization: canonical,
            policy: policy,
            limits: try NumiSealAggregationLimits(maximumObligationsPerAggregate: 1)
        )
        XCTAssertEqual(aggregates.count, 2)
        XCTAssertEqual(aggregates.map(\.aggregateIndex), [0, 0])
        XCTAssertNotEqual(aggregates[0].laneKey, aggregates[1].laneKey)
    }

    private func makeNumiSealProofBodyFixture(
        laneLabel: String = "phase1",
        digitTensorColumnCount: Int = 1,
        carryBytes: [UInt8]? = nil,
        aggregateIndexOverride: Int? = nil
    ) throws -> NumiSealProofBodyFixture {
        let laneID = try NumiSealLaneID(laneLabel)
        let shapeDigest = Digest256.hash("numiseal-proof-body-shape")
        let statementDigest = Digest256.hash("numiseal-proof-body-statement")
        let verifierKeyDigest = Digest256.hash("numiseal-proof-body-verifier-key")
        let evalPoint = [GoldilocksExt2(GoldilocksField(UInt64(laneLabel.utf8.count + 7)))]
        let obligation = NumiSealObligation(
            laneID: laneID,
            profileID: SuperNeoParameterProfile.goldilocksPhi81.profileID,
            shapeDigest: shapeDigest,
            statementDigest: statementDigest,
            verifierKeyDigest: verifierKeyDigest,
            commitment: AjtaiCommitment(
                Array(repeating: CyclotomicRing54.zero, count: SuperNeoParameters.goldilocks.kappa)
            ),
            publicInputEncoding: PublicInputEncoding(field: [GoldilocksField(3), GoldilocksField(5)]),
            evalPoint: evalPoint,
            matrixEvaluations: [CyclotomicExt2Ring54([GoldilocksExt2(GoldilocksField(11))])],
            sourceFoldDigest: Digest256.hash("numiseal-proof-body-source-\(laneLabel)")
        )
        let policy = NumiSealAcceptancePolicy(
            profileID: SuperNeoParameterProfile.goldilocksPhi81.profileID,
            shapeDigest: shapeDigest,
            statementDigest: statementDigest,
            verifierKeyDigest: verifierKeyDigest,
            acceptedLaneIDs: [laneID]
        )
        let canonicalization = try NumiSealCanonicalization.canonicalize(
            obligations: [obligation],
            policy: policy
        )
        let publicStatement = try NumiSealPublicStatement(
            canonicalization: canonicalization,
            policy: policy
        )
        let generatedAggregate = try XCTUnwrap(
            NumiSealLaneAggregation.aggregate(
                canonicalization: canonicalization,
                policy: policy,
                limits: try NumiSealAggregationLimits(maximumObligationsPerAggregate: 1)
            ).first
        )
        let aggregate: NumiSealLaneAggregate
        if let aggregateIndexOverride {
            aggregate = try NumiSealLaneAggregate(
                laneKey: generatedAggregate.laneKey,
                aggregateIndex: aggregateIndexOverride,
                obligationDigests: generatedAggregate.obligationDigests,
                challenges: generatedAggregate.challenges,
                aggregateCommitment: generatedAggregate.aggregateCommitment,
                aggregatePublicInputEncoding: generatedAggregate.aggregatePublicInputEncoding,
                evalPoint: generatedAggregate.evalPoint,
                aggregateMatrixEvaluations: generatedAggregate.aggregateMatrixEvaluations
            )
        } else {
            aggregate = generatedAggregate
        }
        let digitTensor = try NumiSealDigitTensor(
            laneKey: aggregate.laneKey,
            aggregateIndex: aggregate.aggregateIndex,
            message: makeNumiSealTernaryMessage(columnCount: digitTensorColumnCount)
        )
        let decompositionKey = try NumiSealDecompositionKeyDerivation(
            verifierKeyDigest: policy.verifierKeyDigest,
            laneKey: aggregate.laneKey,
            aggregateIndex: aggregate.aggregateIndex,
            requiredColumnCount: digitTensor.columnCount
        )
        let decomposition = try NumiSealDecompositionCommitment(
            keyDerivation: decompositionKey,
            digitTensor: digitTensor
        )
        let scalarization = try NumiSealLinearResidual(
            publicStatement: publicStatement,
            aggregate: aggregate,
            decomposition: decomposition
        )
        let sumcheckProof = try NumiSealSumcheckOracle.prove(
            linearResidual: scalarization,
            digitTensor: digitTensor
        )
        let digitOpening = try makeNumiSealDigitOpeningPayload(
            profileID: policy.profileID,
            decomposition: decomposition,
            digitTensor: digitTensor,
            point: sumcheckProof.finalPoint
        )
        let residualOpening = try NumiSealResidualOpening(
            laneKey: aggregate.laneKey,
            aggregateIndex: aggregate.aggregateIndex,
            linearResidual: scalarization,
            sumcheckProof: sumcheckProof,
            decomposition: decomposition,
            digitTensor: digitTensor,
            claimedDigitEvaluation: digitOpening.claimedDigitEvaluation,
            digitOpeningStatement: digitOpening.statement,
            ceOpeningProof: try invalidCEOpeningProof(openingCount: digitOpening.statement.openings.count)
        )
        let laneProof = try NumiSealLaneProof(
            laneKey: aggregate.laneKey,
            aggregateIndex: aggregate.aggregateIndex,
            aggregateDigest: aggregate.aggregateDigest,
            decompositionKeyDigest: decomposition.decompositionKeyDigest,
            decompositionCommitment: decomposition.commitment,
            scalarizationDigest: scalarization.residualDigest,
            sumcheckProof: sumcheckProof,
            residualOpening: residualOpening,
            optionalCarryClaim: try carryBytes.map(NumiSealCarryClaim.init)
        )
        let proof = try NumiSealProof(publicStatement: publicStatement, laneProofs: [laneProof])
        let terminalPolicy = NumiSealTerminalProofAcceptancePolicy(
            profileID: policy.profileID,
            shapeDigest: policy.shapeDigest,
            statementDigest: policy.statementDigest,
            verifierKeyDigest: policy.verifierKeyDigest,
            transcriptDomain: policy.transcriptDomain,
            acceptedLaneIDs: policy.acceptedLaneIDs,
            maximumProofByteCount: nil,
            maximumLaneCount: 1,
            maximumAggregatesPerLane: 1,
            acceptedResidualMode: .immediate,
            acceptedCarryMode: carryBytes == nil ? .none : .optional
        )
        let context = ProofEnvelopeContext(
            profileID: policy.profileID,
            kind: .numiSealTerminal,
            shapeDigest: policy.shapeDigest,
            statementDigest: policy.statementDigest,
            verifierKeyDigest: policy.verifierKeyDigest,
            transcriptDomain: policy.transcriptDomain
        )
        let envelope = try NumiSealProofEnvelope(context: context, proof: proof)
        return NumiSealProofBodyFixture(
            obligation: obligation,
            publicStatement: publicStatement,
            policy: policy,
            terminalPolicy: terminalPolicy,
            aggregate: aggregate,
            digitTensor: digitTensor,
            decomposition: decomposition,
            scalarization: scalarization,
            digitOpeningStatement: digitOpening.statement,
            residualStatement: residualOpening.residualStatement,
            residualOpening: residualOpening,
            laneProof: laneProof,
            proof: proof,
            envelope: envelope
        )
    }

    private func makeNumiSealResidualCEFixture() throws -> NumiSealResidualCEFixture {
        let foldFixture = try makeFoldFixture()
        let fold = try foldFixture.backend.makeProver(key: foldFixture.key).foldWithOutput(
            foldFixture.input,
            transcriptSeed: foldFixture.seed
        )
        let publicInput = SuperNeoPublicFoldInput(foldFixture.input)
        let statement = CCSStatement(
            shapeDigest: publicInput.shape.shapeDigest,
            ccsInstances: publicInput.instances
        )
        let laneID = try NumiSealLaneID("residual-ce")
        let claim = try XCTUnwrap(fold.outputClaims.first)
        let obligation = NumiSealObligation(
            laneID: laneID,
            profileID: foldFixture.key.parameters.profileID,
            statement: statement,
            verifierKeyDigest: foldFixture.key.verifierKeyDigest,
            instance: CEInstance(claim),
            sourceFoldDigest: Digest256.hash("numiseal-residual-ce-source")
        )
        let policy = NumiSealAcceptancePolicy(
            statement: statement,
            verifierKeyDigest: foldFixture.key.verifierKeyDigest,
            acceptedLaneIDs: [laneID]
        )
        let canonicalization = try NumiSealCanonicalization.canonicalize(
            obligations: [obligation],
            policy: policy
        )
        let publicStatement = try NumiSealPublicStatement(
            canonicalization: canonicalization,
            policy: policy
        )
        let aggregate = try XCTUnwrap(
            NumiSealLaneAggregation.aggregate(
                canonicalization: canonicalization,
                policy: policy,
                limits: try NumiSealAggregationLimits(maximumObligationsPerAggregate: 1)
            ).first
        )
        let witnessedAggregate = try NumiSealAggregateEvaluationOracle.witnessedAggregateClaim(
            aggregate: aggregate,
            claims: [claim],
            shape: foldFixture.input.shape,
            executionPolicy: .highAssurance
        )
        let digitTensor = try NumiSealDigitTensor(
            laneKey: aggregate.laneKey,
            aggregateIndex: aggregate.aggregateIndex,
            message: makeNumiSealTernaryMessage()
        )
        let decompositionKey = try NumiSealDecompositionKeyDerivation(
            verifierKeyDigest: policy.verifierKeyDigest,
            laneKey: aggregate.laneKey,
            aggregateIndex: aggregate.aggregateIndex,
            requiredColumnCount: digitTensor.columnCount
        )
        let decomposition = try NumiSealDecompositionCommitment(
            keyDerivation: decompositionKey,
            digitTensor: digitTensor
        )
        let scalarization = try NumiSealLinearResidual(
            publicStatement: publicStatement,
            aggregate: aggregate,
            decomposition: decomposition
        )
        let sumcheckProof = try NumiSealSumcheckOracle.prove(
            linearResidual: scalarization,
            digitTensor: digitTensor
        )
        let residualCE = try NumiSealResidualCEBuilder.proveImmediateOpeningForTesting(
            publicStatement: publicStatement,
            aggregate: aggregate,
            decomposition: decomposition,
            digitTensor: digitTensor,
            linearResidual: scalarization,
            sumcheckProof: sumcheckProof,
            aggregateClaim: witnessedAggregate,
            shape: foldFixture.input.shape,
            key: foldFixture.key,
            randomSeed: Array("numiseal-residual-ce-opening".utf8),
            executionPolicy: .highAssurance
        )
        let laneProof = try NumiSealLaneProof(
            laneKey: aggregate.laneKey,
            aggregateIndex: aggregate.aggregateIndex,
            aggregateDigest: aggregate.aggregateDigest,
            decompositionKeyDigest: decomposition.decompositionKeyDigest,
            decompositionCommitment: decomposition.commitment,
            scalarizationDigest: scalarization.residualDigest,
            sumcheckProof: sumcheckProof,
            residualOpening: residualCE.residualOpening
        )
        let proof = try NumiSealProof(publicStatement: publicStatement, laneProofs: [laneProof])
        let terminalPolicy = NumiSealTerminalProofAcceptancePolicy(
            profileID: policy.profileID,
            shapeDigest: policy.shapeDigest,
            statementDigest: policy.statementDigest,
            verifierKeyDigest: policy.verifierKeyDigest,
            transcriptDomain: policy.transcriptDomain,
            acceptedLaneIDs: policy.acceptedLaneIDs,
            maximumLaneCount: 1,
            maximumAggregatesPerLane: 1
        )
        let context = ProofEnvelopeContext(
            profileID: policy.profileID,
            kind: .numiSealTerminal,
            shapeDigest: policy.shapeDigest,
            statementDigest: policy.statementDigest,
            verifierKeyDigest: policy.verifierKeyDigest,
            transcriptDomain: policy.transcriptDomain
        )
        let envelope = try NumiSealProofEnvelope(context: context, proof: proof)
        return NumiSealResidualCEFixture(
            shape: foldFixture.input.shape,
            key: foldFixture.key,
            context: context,
            obligation: obligation,
            claim: claim,
            publicStatement: publicStatement,
            policy: policy,
            terminalPolicy: terminalPolicy,
            aggregate: aggregate,
            witnessedAggregate: witnessedAggregate,
            digitTensor: digitTensor,
            decomposition: decomposition,
            scalarization: scalarization,
            digitOpeningStatement: residualCE.digitOpeningStatement,
            residualStatement: residualCE.residualOpening.residualStatement,
            residualOpening: residualCE.residualOpening,
            laneProof: laneProof,
            proof: proof,
            envelope: envelope
        )
    }

    private func makeNumiSealTernaryMessage() -> [CyclotomicRing54] {
        [
            CyclotomicRing54([
                .one,
                -GoldilocksField.one,
                .zero,
                .one,
                .zero,
                -GoldilocksField.one
            ])
        ]
    }

    private func makeNumiSealTernaryMessage(columnCount: Int) -> [CyclotomicRing54] {
        precondition(columnCount > 0)
        var message = makeNumiSealTernaryMessage()
        message.append(contentsOf: repeatElement(CyclotomicRing54.zero, count: columnCount - message.count))
        return message
    }

    private func makeNumiSealDigitOpeningPayload(
        profileID: UInt16,
        decomposition: NumiSealDecompositionCommitment,
        digitTensor: NumiSealDigitTensor,
        point: [GoldilocksExt2],
        executionPolicy: SuperNeoExecutionPolicy = .highAssurance
    ) throws -> (statement: TerminalCEStatement, claimedDigitEvaluation: GoldilocksExt2) {
        let paddedSlotCount = NumiSealResidualCEShape.nextPowerOfTwo(digitTensor.digits.count)
        let openingShape = try NumiSealResidualCEShape.digitOpeningShape(
            columnCount: digitTensor.columnCount,
            paddedSlotCount: paddedSlotCount
        )
        let openingKey = try decomposition.keyDerivation.deriveKey(parameters: .goldilocks)
        var digitValues = digitTensor.digits.map(\.fieldElement)
        digitValues += Array(repeating: .zero, count: paddedSlotCount - digitValues.count)
        let claimedDigitEvaluation = try MultilinearEvaluation.evaluate(digitValues, at: point)
        let transformed = try openingShape.compiledSparseForSuperNeo().transformedSparseMatrices[0]
        let basis = try MultilinearEvaluation.checkedBasis(at: point)
        let matrixEvaluation: CyclotomicExt2Ring54
        if executionPolicy.usesConstantWorkCPU {
            matrixEvaluation = try transformed.evaluatedProductConstantWork(
                by: digitTensor.message,
                rHat: basis
            )
        } else {
            matrixEvaluation = try transformed.evaluatedProduct(
                by: digitTensor.message,
                rHat: basis
            )
        }
        XCTAssertEqual(matrixEvaluation.constantTerm, claimedDigitEvaluation)
        let claim = CCSEvaluationClaim(
            commitment: decomposition.commitment,
            publicInput: [],
            point: point,
            evaluations: [matrixEvaluation],
            witness: digitTensor.digits.map(\.fieldElement)
        )
        return try (
            TerminalCEStatement(
                profileID: profileID,
                shape: openingShape,
                key: openingKey,
                claims: [claim]
            ),
            claimedDigitEvaluation
        )
    }

    private func numiSealDigitEvaluation(
        digitTensor: NumiSealDigitTensor,
        point: [GoldilocksExt2]
    ) throws -> GoldilocksExt2 {
        let paddedSlotCount = NumiSealResidualCEShape.nextPowerOfTwo(digitTensor.digits.count)
        var digitValues = digitTensor.digits.map(\.fieldElement)
        digitValues += Array(repeating: .zero, count: paddedSlotCount - digitValues.count)
        return try MultilinearEvaluation.evaluate(digitValues, at: point)
    }

    private struct NumiSealProofBodyOffsetMap {
        let sumcheckRoundCountOffset: Int
        let firstRoundCoefficientCountOffset: Int
        let firstRoundFirstCoefficientOffset: Int
        let finalPointCountOffset: Int
        let finalValueOffset: Int
        let residualOpeningSumcheckDigestOffset: Int
    }

    private func numiSealProofBodyOffsets(
        fixture: NumiSealProofBodyFixture
    ) -> NumiSealProofBodyOffsetMap {
        let proofBytes = fixture.proof.superNeoBytes
        let publicStatementLength = fixture.publicStatement.superNeoBytes.count
        let firstLaneFrameOffset = 2
            + encodedCountByteWidth
            + publicStatementLength
            + encodedCountByteWidth
            + encodedCountByteWidth
        let lanePayloadOffset = firstLaneFrameOffset + encodedCountByteWidth
        let laneProof = fixture.laneProof
        let aggregateIndexOffset = laneProof.laneKey.superNeoBytes.count
        let aggregateDigestOffset = aggregateIndexOffset + encodedCountByteWidth
        let decompositionKeyDigestOffset = aggregateDigestOffset + Digest256.byteCount
        let decompositionCommitmentOffset = decompositionKeyDigestOffset + Digest256.byteCount
        let scalarizationDigestOffset = decompositionCommitmentOffset + laneProof.decompositionCommitment.superNeoBytes.count
        let sumcheckFrameOffset = scalarizationDigestOffset + Digest256.byteCount
        let sumcheckPayloadOffset = lanePayloadOffset + sumcheckFrameOffset + encodedCountByteWidth
        let sumcheckProof = laneProof.sumcheckProof
        let sumcheckRoundCountOffset = sumcheckPayloadOffset + sumcheckProof.claimedSum.superNeoBytes.count
        let firstRoundCoefficientCountOffset = sumcheckRoundCountOffset + encodedCountByteWidth
        let firstRoundFirstCoefficientOffset = firstRoundCoefficientCountOffset + encodedCountByteWidth
        let finalPointCountOffset = sumcheckRoundCountOffset
            + encodedCountByteWidth
            + sumcheckProof.rounds.reduce(0) { $0 + $1.superNeoBytes.count }
        let finalValueOffset = finalPointCountOffset
            + encodedCountByteWidth
            + sumcheckProof.finalPoint.count * 16
        let residualFrameOffset = sumcheckPayloadOffset + sumcheckProof.superNeoBytes.count
        let residualPayloadOffset = residualFrameOffset + encodedCountByteWidth
        let residualOpeningSumcheckDigestOffset = residualPayloadOffset
            + Digest256.byteCount
            + 2
            + laneProof.laneKey.superNeoBytes.count
            + encodedCountByteWidth
            + 6 * Digest256.byteCount

        XCTAssertLessThan(finalValueOffset, proofBytes.count)
        XCTAssertLessThan(residualOpeningSumcheckDigestOffset, proofBytes.count)
        return NumiSealProofBodyOffsetMap(
            sumcheckRoundCountOffset: sumcheckRoundCountOffset,
            firstRoundCoefficientCountOffset: firstRoundCoefficientCountOffset,
            firstRoundFirstCoefficientOffset: firstRoundFirstCoefficientOffset,
            finalPointCountOffset: finalPointCountOffset,
            finalValueOffset: finalValueOffset,
            residualOpeningSumcheckDigestOffset: residualOpeningSumcheckDigestOffset
        )
    }

    private func assertNumiSealProofBodyMutationRejected(
        fixture: NumiSealProofBodyFixture,
        label: String,
        mutateBody: (inout [UInt8]) -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        var body = fixture.proof.superNeoBytes
        mutateBody(&body)
        XCTAssertThrowsError(
            try NumiSealProof(bytes: body),
            "body mutation should be rejected: \(label)",
            file: file,
            line: line
        ) { error in
            XCTAssertNotNil(error as? SuperNeoError, file: file, line: line)
        }

        var envelope = fixture.envelope.superNeoBytes
        let bodyRange = ProofEnvelopeHeader.byteCount..<envelope.count
        envelope.replaceSubrange(bodyRange, with: body)
        XCTAssertThrowsError(
            try fixture.terminalPolicy.preflight(proofBytes: envelope),
            "envelope mutation should be rejected: \(label)",
            file: file,
            line: line
        ) { error in
            XCTAssertNotNil(error as? SuperNeoError, file: file, line: line)
        }
    }

    func testNumiSealDecompositionKeyDerivationIsDeterministicAndPubliclyBound() throws {
        let fixture = try makeNumiSealProofBodyFixture()
        let laneKey = fixture.laneProof.laneKey
        let derivation = try NumiSealDecompositionKeyDerivation(
            verifierKeyDigest: fixture.policy.verifierKeyDigest,
            laneKey: laneKey,
            aggregateIndex: fixture.laneProof.aggregateIndex,
            requiredColumnCount: 1
        )
        let reparsed = try NumiSealDecompositionKeyDerivation(bytes: derivation.superNeoBytes)

        XCTAssertEqual(reparsed, derivation)
        XCTAssertEqual(try reparsed.deriveKey(), try derivation.deriveKey())
        XCTAssertEqual(derivation.derivationDigest, fixture.laneProof.decompositionKeyDigest)

        let changedVerifierKey = try NumiSealDecompositionKeyDerivation(
            verifierKeyDigest: Digest256.hash("numiseal-other-verifier-key"),
            laneKey: laneKey,
            aggregateIndex: fixture.laneProof.aggregateIndex,
            requiredColumnCount: 1
        )
        let changedAggregate = try NumiSealDecompositionKeyDerivation(
            verifierKeyDigest: fixture.policy.verifierKeyDigest,
            laneKey: laneKey,
            aggregateIndex: fixture.laneProof.aggregateIndex + 1,
            requiredColumnCount: 1
        )
        let changedColumnCount = try NumiSealDecompositionKeyDerivation(
            verifierKeyDigest: fixture.policy.verifierKeyDigest,
            laneKey: laneKey,
            aggregateIndex: fixture.laneProof.aggregateIndex,
            requiredColumnCount: 2
        )

        XCTAssertNotEqual(derivation.derivationDigest, changedVerifierKey.derivationDigest)
        XCTAssertNotEqual(derivation.derivationDigest, changedAggregate.derivationDigest)
        XCTAssertNotEqual(derivation.derivationDigest, changedColumnCount.derivationDigest)

        var tampered = derivation.superNeoBytes
        tampered[tampered.count - Digest256.byteCount] ^= 1
        XCTAssertThrowsSuperNeoError(
            try NumiSealDecompositionKeyDerivation(bytes: tampered),
            .invalidEncoding("NumiSeal decomposition key digest mismatch")
        )
    }

    func testNumiSealDigitTensorRoundTripsReconstructsAndRejectsMalformedDigits() throws {
        let fixture = try makeNumiSealProofBodyFixture()
        let tensor = try NumiSealDigitTensor(
            laneKey: fixture.laneProof.laneKey,
            aggregateIndex: fixture.laneProof.aggregateIndex,
            message: makeNumiSealTernaryMessage()
        )
        let reparsed = try NumiSealDigitTensor(bytes: tensor.superNeoBytes)

        XCTAssertEqual(reparsed, tensor)
        XCTAssertEqual(reparsed.message, makeNumiSealTernaryMessage())
        XCTAssertEqual(tensor.columnCount, 1)
        XCTAssertEqual(tensor.activeDigitCount, 6)

        var invalidDigit = tensor.superNeoBytes
        let digitOffset = Digest256.byteCount
            + 2
            + tensor.laneKey.superNeoBytes.count
            + encodedCountByteWidth
            + encodedCountByteWidth
            + encodedCountByteWidth
        invalidDigit[digitOffset] = 2
        XCTAssertThrowsSuperNeoError(
            try NumiSealDigitTensor(bytes: invalidDigit),
            .invalidEncoding("NumiSeal digit tensor contains non-ternary digit")
        )

        var nonzeroPadding = Array(repeating: NumiSealTernaryDigit.zero, count: CyclotomicRing54.degree)
        nonzeroPadding[0] = .one
        nonzeroPadding[3] = .one
        XCTAssertThrowsSuperNeoError(
            try NumiSealDigitTensor(
                laneKey: fixture.laneProof.laneKey,
                aggregateIndex: fixture.laneProof.aggregateIndex,
                columnCount: 1,
                activeDigitCount: 2,
                digits: nonzeroPadding
            ),
            .invalidParameter("NumiSeal digit tensor padding must be zero")
        )

        XCTAssertThrowsSuperNeoError(
            try NumiSealDigitTensor(
                laneKey: fixture.laneProof.laneKey,
                aggregateIndex: fixture.laneProof.aggregateIndex,
                message: [CyclotomicRing54([GoldilocksField(2)])]
            ),
            .invalidParameter("NumiSeal digit tensor contains a non-ternary coefficient")
        )
    }

    func testNumiSealDecompositionCommitmentUsesDerivedKeyAndVerifiesTensor() throws {
        let fixture = try makeNumiSealProofBodyFixture()
        let tensor = try NumiSealDigitTensor(
            laneKey: fixture.laneProof.laneKey,
            aggregateIndex: fixture.laneProof.aggregateIndex,
            message: makeNumiSealTernaryMessage()
        )
        let derivation = try NumiSealDecompositionKeyDerivation(
            verifierKeyDigest: fixture.policy.verifierKeyDigest,
            laneKey: fixture.laneProof.laneKey,
            aggregateIndex: fixture.laneProof.aggregateIndex,
            requiredColumnCount: tensor.columnCount
        )
        let decomposition = try NumiSealDecompositionCommitment(
            keyDerivation: derivation,
            digitTensor: tensor,
            executionPolicy: .highAssurance
        )
        let key = try derivation.deriveKey()
        let expectedCommitment = try AjtaiCommitter.commitConstantWorkReference(
            key: key,
            message: tensor.message
        )
        let publicCommitment = try NumiSealDecompositionCommitment(
            keyDerivation: derivation,
            digitTensorDigest: tensor.digest,
            commitment: decomposition.commitment
        )
        let reparsed = try NumiSealDecompositionCommitment(bytes: decomposition.superNeoBytes)

        XCTAssertEqual(decomposition.decompositionKeyDigest, derivation.derivationDigest)
        XCTAssertEqual(decomposition.commitment, expectedCommitment)
        XCTAssertEqual(decomposition.commitmentDigest, publicCommitment.commitmentDigest)
        XCTAssertEqual(decomposition, reparsed)
        XCTAssertTrue(
            try decomposition.verifiesOpening(
                digitTensor: tensor,
                executionPolicy: .highAssurance
            )
        )

        let otherTensor = try NumiSealDigitTensor(
            laneKey: fixture.laneProof.laneKey,
            aggregateIndex: fixture.laneProof.aggregateIndex,
            message: [CyclotomicRing54([.one, .zero, .one])]
        )
        XCTAssertFalse(
            try decomposition.verifiesOpening(
                digitTensor: otherTensor,
                executionPolicy: .highAssurance
            )
        )

        let mismatchedDerivation = try NumiSealDecompositionKeyDerivation(
            verifierKeyDigest: fixture.policy.verifierKeyDigest,
            laneKey: fixture.laneProof.laneKey,
            aggregateIndex: fixture.laneProof.aggregateIndex + 1,
            requiredColumnCount: tensor.columnCount
        )
        XCTAssertThrowsSuperNeoError(
            try NumiSealDecompositionCommitment(
                keyDerivation: mismatchedDerivation,
                digitTensor: tensor
            ),
            .invalidParameter("NumiSeal decomposition aggregate index mismatch")
        )

        var tampered = decomposition.superNeoBytes
        tampered[tampered.count - Digest256.byteCount] ^= 1
        XCTAssertThrowsSuperNeoError(
            try NumiSealDecompositionCommitment(bytes: tampered),
            .invalidEncoding("NumiSeal decomposition commitment digest mismatch")
        )
    }

    func testNumiSealScalarizationResidualBindsAggregateAndDecomposition() throws {
        let fixture = try makeNumiSealProofBodyFixture()
        let reparsed = try NumiSealLinearResidual(bytes: fixture.scalarization.superNeoBytes)
        let weights = try NumiSealScalarizationWeights(
            statement: fixture.scalarization.statement,
            aggregate: fixture.aggregate,
            decomposition: fixture.decomposition
        )
        let weightsAgain = try NumiSealScalarizationWeights(
            statement: fixture.scalarization.statement,
            aggregate: fixture.aggregate,
            decomposition: fixture.decomposition
        )

        XCTAssertEqual(reparsed, fixture.scalarization)
        XCTAssertEqual(fixture.laneProof.scalarizationDigest, fixture.scalarization.residualDigest)
        XCTAssertEqual(weights, weightsAgain)
        XCTAssertNoThrow(
            try fixture.scalarization.validate(
                publicStatement: fixture.publicStatement,
                aggregate: fixture.aggregate,
                decomposition: fixture.decomposition
            )
        )

        var changedCommitmentElements = fixture.aggregate.aggregateCommitment.elements
        changedCommitmentElements[0] = changedCommitmentElements[0] + .one
        let changedCommitmentAggregate = try replacingNumiSealAggregate(
            fixture.aggregate,
            aggregateCommitment: AjtaiCommitment(changedCommitmentElements)
        )
        XCTAssertThrowsSuperNeoError(
            try NumiSealScalarizationWeights(
                statement: fixture.scalarization.statement,
                aggregate: changedCommitmentAggregate,
                decomposition: fixture.decomposition
            ),
            .invalidParameter("NumiSeal scalarization aggregate digest mismatch")
        )
        let changedCommitmentResidual = try NumiSealLinearResidual(
            publicStatement: fixture.publicStatement,
            aggregate: changedCommitmentAggregate,
            decomposition: fixture.decomposition
        )
        XCTAssertThrowsSuperNeoError(
            try fixture.scalarization.validate(
                publicStatement: fixture.publicStatement,
                aggregate: changedCommitmentAggregate,
                decomposition: fixture.decomposition
            ),
            .verificationFailed("NumiSeal linear residual mismatch")
        )

        let changedPublicInputAggregate = try replacingNumiSealAggregate(
            fixture.aggregate,
            aggregatePublicInputEncoding: PublicInputEncoding(field: [GoldilocksField(7), GoldilocksField(5)])
        )
        let changedPublicInputResidual = try NumiSealLinearResidual(
            publicStatement: fixture.publicStatement,
            aggregate: changedPublicInputAggregate,
            decomposition: fixture.decomposition
        )

        let changedMatrixAggregate = try replacingNumiSealAggregate(
            fixture.aggregate,
            aggregateMatrixEvaluations: [CyclotomicExt2Ring54([GoldilocksExt2(GoldilocksField(13))])]
        )
        let changedMatrixResidual = try NumiSealLinearResidual(
            publicStatement: fixture.publicStatement,
            aggregate: changedMatrixAggregate,
            decomposition: fixture.decomposition
        )

        let changedTensor = try NumiSealDigitTensor(
            laneKey: fixture.aggregate.laneKey,
            aggregateIndex: fixture.aggregate.aggregateIndex,
            message: [CyclotomicRing54([.zero, .one, -GoldilocksField.one])]
        )
        let changedDerivation = try NumiSealDecompositionKeyDerivation(
            verifierKeyDigest: fixture.policy.verifierKeyDigest,
            laneKey: fixture.aggregate.laneKey,
            aggregateIndex: fixture.aggregate.aggregateIndex,
            requiredColumnCount: changedTensor.columnCount
        )
        let changedDecomposition = try NumiSealDecompositionCommitment(
            keyDerivation: changedDerivation,
            digitTensor: changedTensor
        )
        XCTAssertThrowsSuperNeoError(
            try NumiSealScalarizationWeights(
                statement: fixture.scalarization.statement,
                aggregate: fixture.aggregate,
                decomposition: changedDecomposition
            ),
            .invalidParameter("NumiSeal scalarization decomposition digest mismatch")
        )
        let changedDecompositionResidual = try NumiSealLinearResidual(
            publicStatement: fixture.publicStatement,
            aggregate: fixture.aggregate,
            decomposition: changedDecomposition
        )

        XCTAssertNotEqual(changedCommitmentResidual.residualDigest, fixture.scalarization.residualDigest)
        XCTAssertNotEqual(changedPublicInputResidual.residualDigest, fixture.scalarization.residualDigest)
        XCTAssertNotEqual(changedMatrixResidual.residualDigest, fixture.scalarization.residualDigest)
        XCTAssertNotEqual(changedDecompositionResidual.residualDigest, fixture.scalarization.residualDigest)
    }

    func testNumiSealScalarizationRejectsWrongLaneAndDigestMutations() throws {
        let fixture = try makeNumiSealProofBodyFixture()
        let wrongLaneKey = NumiSealLaneKey(
            profileID: fixture.aggregate.laneKey.profileID,
            shapeDigest: fixture.aggregate.laneKey.shapeDigest,
            verifierKeyDigest: fixture.aggregate.laneKey.verifierKeyDigest,
            evalPointDigest: fixture.aggregate.laneKey.evalPointDigest,
            laneID: try NumiSealLaneID("scalar-other")
        )
        let wrongLaneAggregate = try NumiSealLaneAggregate(
            laneKey: wrongLaneKey,
            aggregateIndex: fixture.aggregate.aggregateIndex,
            obligationDigests: fixture.aggregate.obligationDigests,
            challenges: fixture.aggregate.challenges,
            aggregateCommitment: fixture.aggregate.aggregateCommitment,
            aggregatePublicInputEncoding: fixture.aggregate.aggregatePublicInputEncoding,
            evalPoint: fixture.aggregate.evalPoint,
            aggregateMatrixEvaluations: fixture.aggregate.aggregateMatrixEvaluations
        )
        XCTAssertThrowsSuperNeoError(
            try NumiSealScalarizationStatement(
                publicStatement: fixture.publicStatement,
                aggregate: wrongLaneAggregate,
                decomposition: fixture.decomposition
            ),
            .invalidParameter("NumiSeal scalarization aggregate lane is not covered by public statement")
        )

        var tamperedStatement = fixture.scalarization.statement.superNeoBytes
        tamperedStatement[tamperedStatement.count - 1] ^= 1
        XCTAssertThrowsSuperNeoError(
            try NumiSealScalarizationStatement(bytes: tamperedStatement),
            .invalidEncoding("NumiSeal scalarization statement digest mismatch")
        )

        var tamperedResidual = fixture.scalarization.superNeoBytes
        tamperedResidual[tamperedResidual.count - 1] ^= 1
        XCTAssertThrowsSuperNeoError(
            try NumiSealLinearResidual(bytes: tamperedResidual),
            .invalidEncoding("NumiSeal linear residual digest mismatch")
        )
    }

    func testNumiSealSumcheckOracleBindsResidualAndDigitTensor() throws {
        let fixture = try makeNumiSealProofBodyFixture()
        let proof = fixture.laneProof.sumcheckProof

        XCTAssertEqual(proof.claimedSum, fixture.scalarization.residualValue)
        XCTAssertEqual(proof.rounds.count, 6)
        XCTAssertTrue(
            try NumiSealSumcheckOracle.verify(
                proof: proof,
                linearResidual: fixture.scalarization,
                digitTensor: fixture.digitTensor
            )
        )

        var tamperedRounds = proof.rounds
        tamperedRounds[0] = SumcheckRound(
            coeffs: [tamperedRounds[0].coeffs[0] + .one] + Array(tamperedRounds[0].coeffs.dropFirst())
        )
        let tamperedRoundProof = SumcheckProof(
            claimedSum: proof.claimedSum,
            rounds: tamperedRounds,
            finalPoint: proof.finalPoint,
            finalValue: proof.finalValue
        )
        XCTAssertFalse(
            try NumiSealSumcheckOracle.verify(
                proof: tamperedRoundProof,
                linearResidual: fixture.scalarization,
                digitTensor: fixture.digitTensor
            )
        )

        var tooHighDegreeRounds = proof.rounds
        tooHighDegreeRounds[0] = SumcheckRound(coeffs: proof.rounds[0].coeffs + [.zero])
        let tooHighDegreeProof = SumcheckProof(
            claimedSum: proof.claimedSum,
            rounds: tooHighDegreeRounds,
            finalPoint: proof.finalPoint,
            finalValue: proof.finalValue
        )
        XCTAssertFalse(
            try NumiSealSumcheckOracle.verify(
                proof: tooHighDegreeProof,
                linearResidual: fixture.scalarization,
                digitTensor: fixture.digitTensor
            )
        )

        let otherTensor = try NumiSealDigitTensor(
            laneKey: fixture.digitTensor.laneKey,
            aggregateIndex: fixture.digitTensor.aggregateIndex,
            message: [CyclotomicRing54([.one, .zero, .one])]
        )
        XCTAssertFalse(
            try NumiSealSumcheckOracle.verify(
                proof: proof,
                linearResidual: fixture.scalarization,
                digitTensor: otherTensor
            )
        )

        let changedPublicInputAggregate = try replacingNumiSealAggregate(
            fixture.aggregate,
            aggregatePublicInputEncoding: PublicInputEncoding(field: [GoldilocksField(7), GoldilocksField(5)])
        )
        let changedResidual = try NumiSealLinearResidual(
            publicStatement: fixture.publicStatement,
            aggregate: changedPublicInputAggregate,
            decomposition: fixture.decomposition
        )
        XCTAssertFalse(
            try NumiSealSumcheckOracle.verify(
                proof: proof,
                linearResidual: changedResidual,
                digitTensor: fixture.digitTensor
            )
        )

        let wrongLaneTensor = try NumiSealDigitTensor(
            laneKey: NumiSealLaneKey(
                profileID: fixture.digitTensor.laneKey.profileID,
                shapeDigest: fixture.digitTensor.laneKey.shapeDigest,
                verifierKeyDigest: fixture.digitTensor.laneKey.verifierKeyDigest,
                evalPointDigest: fixture.digitTensor.laneKey.evalPointDigest,
                laneID: try NumiSealLaneID("wrong-sumcheck-lane")
            ),
            aggregateIndex: fixture.digitTensor.aggregateIndex,
            message: makeNumiSealTernaryMessage()
        )
        XCTAssertThrowsSuperNeoError(
            try NumiSealSumcheckOracle.prove(
                linearResidual: fixture.scalarization,
                digitTensor: wrongLaneTensor
            ),
            .invalidParameter("NumiSeal sum-check digit tensor lane mismatch")
        )
    }

    func testNumiSealSumcheckOracleProvesLargeDigitTensorBeyondReferenceCap() throws {
        let fixture = try makeNumiSealProofBodyFixture()
        let largeMessage = makeNumiSealTernaryMessage(columnCount: 80)
        let largeTensor = try NumiSealDigitTensor(
            laneKey: fixture.aggregate.laneKey,
            aggregateIndex: fixture.aggregate.aggregateIndex,
            message: largeMessage
        )
        let decompositionKey = try NumiSealDecompositionKeyDerivation(
            verifierKeyDigest: fixture.policy.verifierKeyDigest,
            laneKey: fixture.aggregate.laneKey,
            aggregateIndex: fixture.aggregate.aggregateIndex,
            requiredColumnCount: largeTensor.columnCount
        )
        let decomposition = try NumiSealDecompositionCommitment(
            keyDerivation: decompositionKey,
            digitTensor: largeTensor
        )
        let residual = try NumiSealLinearResidual(
            publicStatement: fixture.publicStatement,
            aggregate: fixture.aggregate,
            decomposition: decomposition
        )
        let proof = try NumiSealSumcheckOracle.prove(
            linearResidual: residual,
            digitTensor: largeTensor
        )

        XCTAssertGreaterThan(proof.rounds.count, NumiSealSumcheckOracle.maximumReferenceVariableCount)
        XCTAssertEqual(proof.rounds.count, 13)
        XCTAssertTrue(
            try NumiSealSumcheckOracle.verify(
                proof: proof,
                linearResidual: residual,
                digitTensor: largeTensor
            )
        )

        let claimedDigitEvaluation = try numiSealDigitEvaluation(
            digitTensor: largeTensor,
            point: proof.finalPoint
        )
        XCTAssertTrue(
            try NumiSealSumcheckOracle.verifyFinalOpening(
                proof: proof,
                linearResidualDigest: residual.residualDigest,
                scalarizationStatementDigest: residual.statement.statementDigest,
                digitTensorDigest: largeTensor.digest,
                laneKey: largeTensor.laneKey,
                aggregateIndex: largeTensor.aggregateIndex,
                columnCount: largeTensor.columnCount,
                activeDigitCount: largeTensor.activeDigitCount,
                claimedDigitEvaluation: claimedDigitEvaluation
            )
        )

        let residualShape = try NumiSealResidualCEShape(
            laneKey: largeTensor.laneKey,
            aggregateIndex: largeTensor.aggregateIndex,
            digitTensor: largeTensor,
            sumcheckFinalPoint: proof.finalPoint
        )
        XCTAssertEqual(residualShape.variableCount, proof.rounds.count)
        XCTAssertEqual(try NumiSealResidualCEShape(bytes: residualShape.superNeoBytes), residualShape)
    }

    func testNumiSealLargeTensorProofBodyRejectsMalformedSumcheckFrames() throws {
        let fixture = try makeNumiSealProofBodyFixture(digitTensorColumnCount: 80)
        let proof = fixture.laneProof.sumcheckProof
        let offsets = numiSealProofBodyOffsets(fixture: fixture)

        XCTAssertEqual(proof.rounds.count, 13)
        XCTAssertGreaterThan(proof.rounds.count, NumiSealSumcheckOracle.maximumReferenceVariableCount)
        XCTAssertNoThrow(try fixture.terminalPolicy.preflight(proofBytes: fixture.envelope.superNeoBytes))

        assertNumiSealProofBodyMutationRejected(
            fixture: fixture,
            label: "large sum-check round count does not match final point count"
        ) { body in
            writeUInt64(UInt64(proof.rounds.count - 1), into: &body, at: offsets.sumcheckRoundCountOffset)
        }

        assertNumiSealProofBodyMutationRejected(
            fixture: fixture,
            label: "large sum-check round polynomial is empty"
        ) { body in
            writeUInt64(0, into: &body, at: offsets.firstRoundCoefficientCountOffset)
        }

        assertNumiSealProofBodyMutationRejected(
            fixture: fixture,
            label: "large sum-check coefficient byte mutation"
        ) { body in
            body[offsets.firstRoundFirstCoefficientOffset] ^= 1
        }

        assertNumiSealProofBodyMutationRejected(
            fixture: fixture,
            label: "large sum-check final point count does not match round count"
        ) { body in
            writeUInt64(UInt64(proof.finalPoint.count - 1), into: &body, at: offsets.finalPointCountOffset)
        }

        assertNumiSealProofBodyMutationRejected(
            fixture: fixture,
            label: "large sum-check final value byte mutation"
        ) { body in
            body[offsets.finalValueOffset] ^= 1
        }

        assertNumiSealProofBodyMutationRejected(
            fixture: fixture,
            label: "large residual opening mirrored sum-check digest mutation"
        ) { body in
            body[offsets.residualOpeningSumcheckDigestOffset] ^= 1
        }
    }

    func testNumiSealResidualOpeningBindsImmediateCEPayload() throws {
        let fixture = try makeNumiSealProofBodyFixture()
        let residualOpening = fixture.residualOpening
        let reparsed = try NumiSealResidualOpening(residualOpening.superNeoBytes)

        XCTAssertEqual(reparsed, residualOpening)
        XCTAssertEqual(residualOpening.linearResidualDigest, fixture.scalarization.residualDigest)
        XCTAssertEqual(
            residualOpening.sumcheckProofDigest,
            NumiSealResidualOpening.sumcheckProofDigest(fixture.laneProof.sumcheckProof)
        )
        XCTAssertEqual(residualOpening.residualStatement, fixture.residualStatement)
        XCTAssertEqual(residualOpening.residualStatementDigest, fixture.residualStatement.statementDigest)
        XCTAssertEqual(
            residualOpening.residualStatement.residualShape.residualShapeDigest,
            fixture.residualStatement.residualShape.residualShapeDigest
        )
        XCTAssertEqual(residualOpening.decompositionKeyDigest, fixture.decomposition.decompositionKeyDigest)
        XCTAssertEqual(residualOpening.decompositionCommitmentDigest, fixture.decomposition.commitmentDigest)
        XCTAssertEqual(residualOpening.digitTensorDigest, fixture.digitTensor.digest)
        XCTAssertEqual(residualOpening.scalarizationStatementDigest, fixture.scalarization.statement.statementDigest)
        XCTAssertEqual(residualOpening.digitOpeningStatementDigest, fixture.digitOpeningStatement.statementDigest)
        XCTAssertEqual(
            try NumiSealResidualCEStatement(bytes: fixture.residualStatement.superNeoBytes),
            fixture.residualStatement
        )
        XCTAssertEqual(
            try NumiSealResidualCEShape(bytes: fixture.residualStatement.residualShape.superNeoBytes),
            fixture.residualStatement.residualShape
        )
        XCTAssertNoThrow(
            try residualOpening.validate(
                linearResidual: fixture.scalarization,
                sumcheckProof: fixture.laneProof.sumcheckProof,
                decomposition: fixture.decomposition,
                digitTensor: fixture.digitTensor,
                claimedDigitEvaluation: fixture.residualStatement.claimedDigitEvaluation
            )
        )
        XCTAssertNoThrow(try fixture.terminalPolicy.validate(proof: fixture.proof))

        var tamperedOpening = residualOpening.superNeoBytes
        tamperedOpening[tamperedOpening.count - 1] ^= 1
        XCTAssertThrowsSuperNeoError(
            try NumiSealResidualOpening(tamperedOpening),
            .invalidEncoding("NumiSeal residual opening digest mismatch")
        )

        let changedPublicInputAggregate = try replacingNumiSealAggregate(
            fixture.aggregate,
            aggregatePublicInputEncoding: PublicInputEncoding(field: [GoldilocksField(7), GoldilocksField(5)])
        )
        let changedResidual = try NumiSealLinearResidual(
            publicStatement: fixture.publicStatement,
            aggregate: changedPublicInputAggregate,
            decomposition: fixture.decomposition
        )
        XCTAssertThrowsSuperNeoError(
            try residualOpening.validate(
                linearResidual: changedResidual,
                sumcheckProof: fixture.laneProof.sumcheckProof,
                decomposition: fixture.decomposition,
                digitTensor: fixture.digitTensor,
                claimedDigitEvaluation: fixture.residualStatement.claimedDigitEvaluation
            ),
            .verificationFailed("NumiSeal residual opening linear residual digest mismatch")
        )

        let wrongClaimedSumProof = SumcheckProof(
            claimedSum: fixture.laneProof.sumcheckProof.claimedSum + .one,
            rounds: fixture.laneProof.sumcheckProof.rounds,
            finalPoint: fixture.laneProof.sumcheckProof.finalPoint,
            finalValue: fixture.laneProof.sumcheckProof.finalValue
        )
        XCTAssertThrowsSuperNeoError(
            try NumiSealResidualOpening(
                laneKey: fixture.laneProof.laneKey,
                aggregateIndex: fixture.laneProof.aggregateIndex,
                linearResidual: fixture.scalarization,
                sumcheckProof: wrongClaimedSumProof,
                decomposition: fixture.decomposition,
                digitTensor: fixture.digitTensor,
                claimedDigitEvaluation: fixture.residualStatement.claimedDigitEvaluation,
                digitOpeningStatement: fixture.digitOpeningStatement,
                ceOpeningProof: fixture.residualOpening.ceOpeningProof
            ),
            .invalidParameter("NumiSeal residual opening sum-check claimed sum mismatch")
        )

        let wrongProfileStatement = try TerminalCEStatement(
            profileID: fixture.policy.profileID + 1,
            shapeDigest: fixture.digitOpeningStatement.shapeDigest,
            verifierKeyDigest: fixture.digitOpeningStatement.verifierKeyDigest,
            claims: fixture.digitOpeningStatement.outputClaims
        )
        XCTAssertThrowsSuperNeoError(
            try NumiSealResidualOpening(
                laneKey: fixture.laneProof.laneKey,
                aggregateIndex: fixture.laneProof.aggregateIndex,
                linearResidual: fixture.scalarization,
                sumcheckProof: fixture.laneProof.sumcheckProof,
                decomposition: fixture.decomposition,
                digitTensor: fixture.digitTensor,
                claimedDigitEvaluation: fixture.residualStatement.claimedDigitEvaluation,
                digitOpeningStatement: wrongProfileStatement,
                ceOpeningProof: fixture.residualOpening.ceOpeningProof
            ),
            .verificationFailed("NumiSeal residual CE digit statement profile mismatch")
        )

        let wrongOpeningCountProof = try invalidCEOpeningProof(
            openingCount: fixture.digitOpeningStatement.openings.count + 1
        )
        XCTAssertThrowsSuperNeoError(
            try NumiSealResidualOpening(
                laneKey: fixture.laneProof.laneKey,
                aggregateIndex: fixture.laneProof.aggregateIndex,
                linearResidual: fixture.scalarization,
                sumcheckProof: fixture.laneProof.sumcheckProof,
                decomposition: fixture.decomposition,
                digitTensor: fixture.digitTensor,
                claimedDigitEvaluation: fixture.residualStatement.claimedDigitEvaluation,
                digitOpeningStatement: fixture.digitOpeningStatement,
                ceOpeningProof: wrongOpeningCountProof
            ),
            .invalidParameter("NumiSeal residual CE proof opening count mismatch")
        )

        let sameClaimDifferentProof = SumcheckProof(
            claimedSum: fixture.laneProof.sumcheckProof.claimedSum,
            rounds: fixture.laneProof.sumcheckProof.rounds,
            finalPoint: fixture.laneProof.sumcheckProof.finalPoint,
            finalValue: fixture.laneProof.sumcheckProof.finalValue + .one
        )
        XCTAssertThrowsSuperNeoError(
            try NumiSealResidualOpening(
                laneKey: fixture.laneProof.laneKey,
                aggregateIndex: fixture.laneProof.aggregateIndex,
                linearResidual: fixture.scalarization,
                sumcheckProof: sameClaimDifferentProof,
                decomposition: fixture.decomposition,
                digitTensor: fixture.digitTensor,
                claimedDigitEvaluation: fixture.residualStatement.claimedDigitEvaluation,
                digitOpeningStatement: fixture.digitOpeningStatement,
                ceOpeningProof: fixture.residualOpening.ceOpeningProof
            ),
            .verificationFailed("NumiSeal residual sum-check final opening failed")
        )
    }

    func testNumiSealResidualOpeningVerifiesCEOpeningRelation() throws {
        let fixture = try makeNumiSealResidualCEFixture()

        XCTAssertTrue(
            try fixture.residualOpening.verifyCEOpening(
                shape: fixture.shape,
                key: fixture.key,
                executionPolicy: .highAssurance
            )
        )
        XCTAssertEqual(
            try fixture.terminalPolicy.verify(
                proofBytes: fixture.envelope.superNeoBytes,
                shape: fixture.shape,
                key: fixture.key,
                executionPolicy: .highAssurance
            ),
            fixture.envelope
        )

        XCTAssertNoThrow(
            try fixture.terminalPolicy.preflight(proofBytes: fixture.envelope.superNeoBytes)
        )

        let invalidResidualOpening = try NumiSealResidualOpening(
            laneKey: fixture.laneProof.laneKey,
            aggregateIndex: fixture.laneProof.aggregateIndex,
            linearResidual: fixture.scalarization,
            sumcheckProof: fixture.laneProof.sumcheckProof,
            decomposition: fixture.decomposition,
            digitTensor: fixture.digitTensor,
            claimedDigitEvaluation: fixture.residualStatement.claimedDigitEvaluation,
            digitOpeningStatement: fixture.digitOpeningStatement,
            ceOpeningProof: try invalidCEOpeningProof(openingCount: fixture.digitOpeningStatement.openings.count)
        )
        let invalidLaneProof = try NumiSealLaneProof(
            laneKey: fixture.laneProof.laneKey,
            aggregateIndex: fixture.laneProof.aggregateIndex,
            aggregateDigest: fixture.laneProof.aggregateDigest,
            decompositionKeyDigest: fixture.laneProof.decompositionKeyDigest,
            decompositionCommitment: fixture.laneProof.decompositionCommitment,
            scalarizationDigest: fixture.laneProof.scalarizationDigest,
            sumcheckProof: fixture.laneProof.sumcheckProof,
            residualOpening: invalidResidualOpening
        )
        let invalidProof = try NumiSealProof(
            publicStatement: fixture.publicStatement,
            laneProofs: [invalidLaneProof]
        )
        let invalidEnvelope = try NumiSealProofEnvelope(
            context: fixture.context,
            proof: invalidProof
        )

        XCTAssertNoThrow(
            try fixture.terminalPolicy.preflight(proofBytes: invalidEnvelope.superNeoBytes)
        )
        XCTAssertThrowsSuperNeoError(
            try fixture.terminalPolicy.verify(
                proofBytes: invalidEnvelope.superNeoBytes,
                shape: fixture.shape,
                key: fixture.key,
                executionPolicy: .highAssurance
            ),
            .verificationFailed("NumiSeal residual CE opening proof verification failed")
        )

        let wrongKey = try AjtaiCommitmentKey(
            columns: fixture.key.matrix.columns,
            seed: Array("numiseal-wrong-ce-key".utf8)
        )
        XCTAssertThrowsSuperNeoError(
            try fixture.residualOpening.verifyCEOpening(
                shape: fixture.shape,
                key: wrongKey,
                executionPolicy: .highAssurance
            ),
            .verificationFailed("NumiSeal residual CE opening verifier key mismatch")
        )
        XCTAssertThrowsSuperNeoError(
            try fixture.terminalPolicy.verify(
                proofBytes: fixture.envelope.superNeoBytes,
                shape: fixture.shape,
                key: wrongKey,
                executionPolicy: .highAssurance
            ),
            .verificationFailed("NumiSeal verification verifier key mismatch")
        )
    }

    func testNumiSealResidualCEBuilderBindsInternalShapeAndWitness() throws {
        let fixture = try makeNumiSealResidualCEFixture()
        let residualStatement = fixture.residualOpening.residualStatement

        XCTAssertEqual(residualStatement, fixture.residualStatement)
        XCTAssertEqual(residualStatement.publicStatementDigest, fixture.publicStatement.digest)
        XCTAssertEqual(residualStatement.aggregateDigest, fixture.aggregate.aggregateDigest)
        XCTAssertEqual(residualStatement.decompositionKeyDigest, fixture.decomposition.decompositionKeyDigest)
        XCTAssertEqual(residualStatement.decompositionCommitmentDigest, fixture.decomposition.commitmentDigest)
        XCTAssertEqual(residualStatement.digitTensorDigest, fixture.digitTensor.digest)
        XCTAssertEqual(residualStatement.scalarizationStatementDigest, fixture.scalarization.statement.statementDigest)
        XCTAssertEqual(residualStatement.linearResidualDigest, fixture.scalarization.residualDigest)
        XCTAssertEqual(
            residualStatement.sumcheckProofDigest,
            NumiSealResidualOpening.sumcheckProofDigest(fixture.laneProof.sumcheckProof)
        )
        XCTAssertEqual(residualStatement.sumcheckFinalPoint, fixture.laneProof.sumcheckProof.finalPoint)
        XCTAssertEqual(
            residualStatement.claimedDigitEvaluation,
            fixture.digitOpeningStatement.openings[0].instance.matrixEvals[0].constantTerm
        )
        XCTAssertEqual(residualStatement.digitOpeningStatementDigest, fixture.digitOpeningStatement.statementDigest)
        XCTAssertEqual(residualStatement.residualShape.laneKey, fixture.aggregate.laneKey)
        XCTAssertEqual(residualStatement.residualShape.aggregateIndex, fixture.aggregate.aggregateIndex)
        XCTAssertEqual(residualStatement.residualShape.columnCount, fixture.digitTensor.columnCount)
        XCTAssertEqual(residualStatement.residualShape.activeDigitCount, fixture.digitTensor.activeDigitCount)
        XCTAssertEqual(residualStatement.residualShape.slotCount, fixture.digitTensor.digits.count)
        XCTAssertEqual(
            residualStatement.residualShape.paddedSlotCount,
            NumiSealResidualCEShape.nextPowerOfTwo(fixture.digitTensor.digits.count)
        )
        XCTAssertEqual(
            residualStatement.residualShape.variableCount,
            try NumiSealResidualCEShape.log2Exact(residualStatement.residualShape.paddedSlotCount)
        )
        XCTAssertEqual(residualStatement.residualShape.digitOpeningShapeDigest, fixture.digitOpeningStatement.shapeDigest)
        XCTAssertNoThrow(
            try residualStatement.validate(
                linearResidual: fixture.scalarization,
                sumcheckProof: fixture.laneProof.sumcheckProof,
                decomposition: fixture.decomposition,
                digitTensor: fixture.digitTensor,
                claimedDigitEvaluation: residualStatement.claimedDigitEvaluation,
                digitOpeningStatement: fixture.digitOpeningStatement
            )
        )

        let badCommitment = fixture.witnessedAggregate.commitment
            + AjtaiCommitment(Array(repeating: CyclotomicRing54.one, count: fixture.key.parameters.kappa))
        let mismatchedClaim = CCSEvaluationClaim(
            commitment: badCommitment,
            publicInput: fixture.witnessedAggregate.publicInput,
            point: fixture.witnessedAggregate.point,
            evaluations: fixture.witnessedAggregate.evaluations,
            witness: fixture.witnessedAggregate.witness
        )
        XCTAssertThrowsSuperNeoError(
            try NumiSealResidualCEBuilder.proveImmediateOpeningForTesting(
                publicStatement: fixture.publicStatement,
                aggregate: fixture.aggregate,
                decomposition: fixture.decomposition,
                digitTensor: fixture.digitTensor,
                linearResidual: fixture.scalarization,
                sumcheckProof: fixture.laneProof.sumcheckProof,
                aggregateClaim: mismatchedClaim,
                shape: fixture.shape,
                key: fixture.key,
                randomSeed: Array("numiseal-residual-ce-bad-claim".utf8),
                executionPolicy: .highAssurance
            ),
            .invalidParameter("NumiSeal residual aggregate claim does not match aggregate")
        )

        var changedDigits = fixture.digitTensor.digits
        changedDigits[0] = changedDigits[0] == .zero ? .one : .zero
        let changedDigitTensor = try NumiSealDigitTensor(
            laneKey: fixture.digitTensor.laneKey,
            aggregateIndex: fixture.digitTensor.aggregateIndex,
            columnCount: fixture.digitTensor.columnCount,
            activeDigitCount: fixture.digitTensor.activeDigitCount,
            digits: changedDigits
        )
        XCTAssertThrowsSuperNeoError(
            try NumiSealResidualCEBuilder.proveImmediateOpeningForTesting(
                publicStatement: fixture.publicStatement,
                aggregate: fixture.aggregate,
                decomposition: fixture.decomposition,
                digitTensor: changedDigitTensor,
                linearResidual: fixture.scalarization,
                sumcheckProof: fixture.laneProof.sumcheckProof,
                aggregateClaim: fixture.witnessedAggregate,
                shape: fixture.shape,
                key: fixture.key,
                randomSeed: Array("numiseal-residual-ce-bad-digits".utf8),
                executionPolicy: .highAssurance
            ),
            .verificationFailed("NumiSeal residual sum-check verification failed")
        )
    }

    func testNumiSealProverVerifierAssemblesSingleAggregateEnvelope() throws {
        let fixture = try makeNumiSealResidualCEFixture()
        let witnessed = try NumiSealWitnessedObligation(
            obligation: fixture.obligation,
            claim: fixture.claim
        )
        let aggregationLimits = try NumiSealAggregationLimits(maximumObligationsPerAggregate: 1)
        let prover = NumiSealProver(
            shape: fixture.shape,
            key: fixture.key,
            executionPolicy: .highAssurance
        )
        let envelope = try prover.prove(
            witnessedObligations: [witnessed],
            policy: fixture.policy,
            digitTensorMessage: makeNumiSealTernaryMessage(),
            aggregationLimits: aggregationLimits
        )
        let verifier = NumiSealVerifier(
            shape: fixture.shape,
            key: fixture.key,
            executionPolicy: .highAssurance
        )
        let result = verifier.verify(
            proofBytes: envelope.superNeoBytes,
            obligations: [fixture.obligation],
            policy: fixture.terminalPolicy,
            aggregationLimits: aggregationLimits
        )

        XCTAssertTrue(result.isValid, result.reason ?? "NumiSeal verifier rejected API-built envelope")
        XCTAssertNil(result.reason)
        XCTAssertEqual(result.envelope, envelope)

        let staleObligation = NumiSealObligation(
            laneID: fixture.obligation.laneID,
            profileID: fixture.obligation.profileID,
            shapeDigest: fixture.obligation.shapeDigest,
            statementDigest: fixture.obligation.statementDigest,
            verifierKeyDigest: fixture.obligation.verifierKeyDigest,
            commitment: fixture.obligation.commitment,
            publicInputEncoding: fixture.obligation.publicInputEncoding,
            evalPoint: fixture.obligation.evalPoint,
            matrixEvaluations: fixture.obligation.matrixEvaluations,
            sourceFoldDigest: Digest256.hash("numiseal-stale-api-obligation")
        )
        let staleResult = verifier.verify(
            proofBytes: envelope.superNeoBytes,
            obligations: [staleObligation],
            policy: fixture.terminalPolicy,
            aggregationLimits: aggregationLimits
        )
        XCTAssertFalse(staleResult.isValid)
        XCTAssertEqual(
            staleResult.reason,
            "verificationFailed(\"NumiSeal verifier public statement mismatch\")"
        )

        XCTAssertThrowsSuperNeoError(
            try NumiSealWitnessedObligation(
                obligation: fixture.obligation,
                claim: CCSEvaluationClaim(
                    commitment: fixture.claim.commitment,
                    publicInput: fixture.claim.publicInput,
                    point: fixture.claim.point,
                    evaluations: fixture.claim.evaluations
                )
            ),
            .invalidParameter("NumiSeal witnessed obligation is missing witness")
        )
    }

    func testNumiSealProverVerifierAssemblesMultipleAggregateEnvelope() throws {
        let foldFixture = try makeFoldFixture()
        let fold = try foldFixture.backend.makeProver(key: foldFixture.key).foldWithOutput(
            foldFixture.input,
            transcriptSeed: foldFixture.seed
        )
        let publicInput = SuperNeoPublicFoldInput(foldFixture.input)
        let statement = CCSStatement(
            shapeDigest: publicInput.shape.shapeDigest,
            ccsInstances: publicInput.instances
        )
        let laneID = try NumiSealLaneID("terminal-api-multi-aggregate")
        let claims = Array(fold.outputClaims.prefix(2))
        XCTAssertEqual(claims.count, 2)

        let obligations = claims.enumerated().map { index, claim in
            NumiSealObligation(
                laneID: laneID,
                profileID: foldFixture.key.parameters.profileID,
                statement: statement,
                verifierKeyDigest: foldFixture.key.verifierKeyDigest,
                instance: CEInstance(claim),
                sourceFoldDigest: Digest256.hash("numiseal-api-multi-aggregate-\(index)")
            )
        }
        let witnessed = try zip(obligations, claims).map { pair in
            let (obligation, claim) = pair
            return try NumiSealWitnessedObligation(
                obligation: obligation,
                claim: claim
            )
        }
        let policy = NumiSealAcceptancePolicy(
            statement: statement,
            verifierKeyDigest: foldFixture.key.verifierKeyDigest,
            acceptedLaneIDs: [laneID]
        )
        let terminalPolicy = NumiSealTerminalProofAcceptancePolicy(
            profileID: policy.profileID,
            shapeDigest: policy.shapeDigest,
            statementDigest: policy.statementDigest,
            verifierKeyDigest: policy.verifierKeyDigest,
            transcriptDomain: policy.transcriptDomain,
            acceptedLaneIDs: policy.acceptedLaneIDs,
            maximumLaneCount: 1,
            maximumAggregatesPerLane: 2
        )
        let aggregationLimits = try NumiSealAggregationLimits(maximumObligationsPerAggregate: 1)
        let digitTensorInputs = try claims.map { _ in
            try NumiSealAggregateDigitTensorInput(message: makeNumiSealTernaryMessage())
        }
        let prover = NumiSealProver(
            shape: foldFixture.input.shape,
            key: foldFixture.key,
            executionPolicy: .highAssurance
        )
        let plan = try prover.provingPlan(
            obligations: Array(obligations.reversed()),
            policy: policy,
            aggregationLimits: aggregationLimits
        )
        XCTAssertEqual(plan.aggregateCount, 2)
        XCTAssertEqual(plan.publicStatement.laneSummaries.count, 1)
        XCTAssertEqual(plan.aggregates.map(\.aggregateIndex), [0, 1])

        let envelope = try prover.prove(
            witnessedObligations: witnessed,
            policy: policy,
            digitTensorInputs: digitTensorInputs,
            aggregationLimits: aggregationLimits
        )

        XCTAssertEqual(envelope.proof.laneProofs.count, 2)
        XCTAssertEqual(envelope.proof.publicStatement, plan.publicStatement)
        XCTAssertEqual(envelope.proof.laneProofs.map(\.aggregateDigest), plan.aggregateDigests)
        XCTAssertEqual(envelope.proof.laneProofs.map(\.laneKey), Array(repeating: envelope.proof.laneProofs[0].laneKey, count: 2))
        XCTAssertEqual(envelope.proof.laneProofs.map(\.aggregateIndex), [0, 1])

        let verifier = NumiSealVerifier(
            shape: foldFixture.input.shape,
            key: foldFixture.key,
            executionPolicy: .highAssurance
        )
        let result = verifier.verify(
            proofBytes: envelope.superNeoBytes,
            obligations: obligations,
            policy: terminalPolicy,
            aggregationLimits: aggregationLimits
        )
        XCTAssertTrue(result.isValid, result.reason ?? "NumiSeal verifier rejected multi-aggregate envelope")
        XCTAssertEqual(result.envelope, envelope)

        let restrictedPolicy = NumiSealTerminalProofAcceptancePolicy(
            profileID: policy.profileID,
            shapeDigest: policy.shapeDigest,
            statementDigest: policy.statementDigest,
            verifierKeyDigest: policy.verifierKeyDigest,
            transcriptDomain: policy.transcriptDomain,
            acceptedLaneIDs: policy.acceptedLaneIDs,
            maximumLaneCount: 1,
            maximumAggregatesPerLane: 1
        )
        let restrictedResult = verifier.verify(
            proofBytes: envelope.superNeoBytes,
            obligations: obligations,
            policy: restrictedPolicy,
            aggregationLimits: aggregationLimits
        )
        XCTAssertFalse(restrictedResult.isValid)
        XCTAssertEqual(
            restrictedResult.reason,
            "verificationFailed(\"NumiSeal aggregate count exceeds policy maximum\")"
        )

        XCTAssertThrowsSuperNeoError(
            try prover.prove(
                witnessedObligations: witnessed,
                policy: policy,
                digitTensorInputs: Array(digitTensorInputs.prefix(1)),
                aggregationLimits: aggregationLimits
            ),
            .invalidParameter("NumiSeal prover digit tensor input count must match aggregate count")
        )
    }

    func testNumiSealProvingPlanDrivesMultiLaneAggregateEnvelope() throws {
        let foldFixture = try makeFoldFixture()
        let fold = try foldFixture.backend.makeProver(key: foldFixture.key).foldWithOutput(
            foldFixture.input,
            transcriptSeed: foldFixture.seed
        )
        let publicInput = SuperNeoPublicFoldInput(foldFixture.input)
        let statement = CCSStatement(
            shapeDigest: publicInput.shape.shapeDigest,
            ccsInstances: publicInput.instances
        )
        let laneA = try NumiSealLaneID("terminal-api-lane-a")
        let laneB = try NumiSealLaneID("terminal-api-lane-b")
        let claims = Array(fold.outputClaims.prefix(3))
        XCTAssertEqual(claims.count, 3)

        let laneIDs = [laneA, laneA, laneB]
        let obligations = zip(laneIDs, claims).enumerated().map { index, pair in
            let (laneID, claim) = pair
            return NumiSealObligation(
                laneID: laneID,
                profileID: foldFixture.key.parameters.profileID,
                statement: statement,
                verifierKeyDigest: foldFixture.key.verifierKeyDigest,
                instance: CEInstance(claim),
                sourceFoldDigest: Digest256.hash("numiseal-api-multi-lane-\(index)")
            )
        }
        let witnessed = try zip(obligations, claims).map { pair in
            let (obligation, claim) = pair
            return try NumiSealWitnessedObligation(
                obligation: obligation,
                claim: claim
            )
        }
        let policy = NumiSealAcceptancePolicy(
            statement: statement,
            verifierKeyDigest: foldFixture.key.verifierKeyDigest,
            acceptedLaneIDs: [laneA, laneB]
        )
        let terminalPolicy = NumiSealTerminalProofAcceptancePolicy(
            profileID: policy.profileID,
            shapeDigest: policy.shapeDigest,
            statementDigest: policy.statementDigest,
            verifierKeyDigest: policy.verifierKeyDigest,
            transcriptDomain: policy.transcriptDomain,
            acceptedLaneIDs: policy.acceptedLaneIDs,
            maximumLaneCount: 2,
            maximumAggregatesPerLane: 2
        )
        let aggregationLimits = try NumiSealAggregationLimits(maximumObligationsPerAggregate: 1)
        let prover = NumiSealProver(
            shape: foldFixture.input.shape,
            key: foldFixture.key,
            executionPolicy: .highAssurance
        )
        let plan = try prover.provingPlan(
            obligations: Array(obligations.reversed()),
            policy: policy,
            aggregationLimits: aggregationLimits
        )
        let indexRuns = Dictionary(grouping: plan.aggregates, by: \.laneKey).values
            .map { aggregates in aggregates.map(\.aggregateIndex) }
            .sorted { lhs, rhs in
                if lhs.count != rhs.count {
                    return lhs.count < rhs.count
                }
                return lhs.lexicographicallyPrecedes(rhs)
            }

        XCTAssertEqual(plan.aggregateCount, 3)
        XCTAssertEqual(plan.publicStatement.laneSummaries.count, 2)
        XCTAssertEqual(indexRuns, [[0], [0, 1]])

        let digitTensorInputs = try plan.aggregates.map { _ in
            try NumiSealAggregateDigitTensorInput(message: makeNumiSealTernaryMessage())
        }
        let envelope = try prover.prove(
            witnessedObligations: Array(witnessed.reversed()),
            policy: policy,
            digitTensorInputs: digitTensorInputs,
            aggregationLimits: aggregationLimits
        )

        XCTAssertEqual(envelope.proof.publicStatement, plan.publicStatement)
        XCTAssertEqual(envelope.proof.laneProofs.map(\.aggregateDigest), plan.aggregateDigests)
        XCTAssertEqual(envelope.proof.laneProofs.map(\.laneKey), plan.aggregates.map(\.laneKey))
        XCTAssertEqual(envelope.proof.laneProofs.map(\.aggregateIndex), plan.aggregates.map(\.aggregateIndex))

        let verifier = NumiSealVerifier(
            shape: foldFixture.input.shape,
            key: foldFixture.key,
            executionPolicy: .highAssurance
        )
        let result = verifier.verify(
            proofBytes: envelope.superNeoBytes,
            obligations: Array(obligations.reversed()),
            policy: terminalPolicy,
            aggregationLimits: aggregationLimits
        )
        XCTAssertTrue(result.isValid, result.reason ?? "NumiSeal verifier rejected multi-lane envelope")
        XCTAssertEqual(result.envelope, envelope)

        let laneRestrictedPolicy = NumiSealTerminalProofAcceptancePolicy(
            profileID: policy.profileID,
            shapeDigest: policy.shapeDigest,
            statementDigest: policy.statementDigest,
            verifierKeyDigest: policy.verifierKeyDigest,
            transcriptDomain: policy.transcriptDomain,
            acceptedLaneIDs: policy.acceptedLaneIDs,
            maximumLaneCount: 1,
            maximumAggregatesPerLane: 2
        )
        let laneRestrictedResult = verifier.verify(
            proofBytes: envelope.superNeoBytes,
            obligations: obligations,
            policy: laneRestrictedPolicy,
            aggregationLimits: aggregationLimits
        )
        XCTAssertFalse(laneRestrictedResult.isValid)
        XCTAssertEqual(
            laneRestrictedResult.reason,
            "verificationFailed(\"NumiSeal lane count exceeds policy maximum\")"
        )
    }

    private func replacingNumiSealAggregate(
        _ aggregate: NumiSealLaneAggregate,
        aggregateCommitment: AjtaiCommitment? = nil,
        aggregatePublicInputEncoding: PublicInputEncoding? = nil,
        aggregateMatrixEvaluations: [CyclotomicExt2Ring54]? = nil
    ) throws -> NumiSealLaneAggregate {
        try NumiSealLaneAggregate(
            laneKey: aggregate.laneKey,
            aggregateIndex: aggregate.aggregateIndex,
            obligationDigests: aggregate.obligationDigests,
            challenges: aggregate.challenges,
            aggregateCommitment: aggregateCommitment ?? aggregate.aggregateCommitment,
            aggregatePublicInputEncoding: aggregatePublicInputEncoding ?? aggregate.aggregatePublicInputEncoding,
            evalPoint: aggregate.evalPoint,
            aggregateMatrixEvaluations: aggregateMatrixEvaluations ?? aggregate.aggregateMatrixEvaluations
        )
    }

    func testNumiSealCanonicalizationRejectsPolicyMismatches() throws {
        let fixture = try makeFoldFixture()
        let fold = try fixture.backend.makeProver(key: fixture.key).foldWithOutput(
            fixture.input,
            transcriptSeed: fixture.seed
        )
        let publicInput = SuperNeoPublicFoldInput(fixture.input)
        let statement = CCSStatement(
            shapeDigest: publicInput.shape.shapeDigest,
            ccsInstances: publicInput.instances
        )
        let laneID = try NumiSealLaneID("main")
        let obligation = NumiSealObligation(
            laneID: laneID,
            profileID: fixture.key.parameters.profileID,
            statement: statement,
            verifierKeyDigest: fixture.key.verifierKeyDigest,
            instance: CEInstance(fold.outputClaims[0]),
            sourceFoldDigest: Digest256.hash("numiseal-source-policy")
        )

        XCTAssertThrowsSuperNeoError(
            try NumiSealCanonicalization.canonicalize(
                obligations: [obligation],
                policy: NumiSealAcceptancePolicy(
                    shapeDigest: statement.shapeDigest,
                    statementDigest: statement.statementDigest,
                    verifierKeyDigest: fixture.key.verifierKeyDigest,
                    acceptedLaneIDs: [try NumiSealLaneID("other")]
                )
            ),
            .verificationFailed("NumiSeal obligation lane is not accepted by policy")
        )

        XCTAssertThrowsSuperNeoError(
            try NumiSealCanonicalization.canonicalize(
                obligations: [obligation],
                policy: NumiSealAcceptancePolicy(
                    shapeDigest: statement.shapeDigest,
                    statementDigest: Digest256.hash("wrong statement"),
                    verifierKeyDigest: fixture.key.verifierKeyDigest,
                    acceptedLaneIDs: [laneID]
                )
            ),
            .verificationFailed("NumiSeal obligation statement mismatch")
        )
    }

    func testNumiSealPublicStatementSerializationRoundTripsAndBindsPolicy() throws {
        let fixture = try makeNumiSealCanonicalFixture(claimCount: 2)
        let statement = try NumiSealPublicStatement(
            canonicalization: fixture.canonicalization,
            policy: fixture.policy
        )
        let reparsed = try NumiSealPublicStatement(bytes: statement.superNeoBytes)

        XCTAssertEqual(reparsed, statement)
        XCTAssertEqual(reparsed.digest, statement.digest)
        XCTAssertNoThrow(try reparsed.validate(against: fixture.policy))

        let wrongPolicy = NumiSealAcceptancePolicy(
            profileID: fixture.policy.profileID,
            shapeDigest: fixture.policy.shapeDigest,
            statementDigest: fixture.policy.statementDigest,
            verifierKeyDigest: fixture.policy.verifierKeyDigest,
            transcriptDomain: Digest256.hash("wrong-numiseal-domain"),
            acceptedLaneIDs: fixture.policy.acceptedLaneIDs
        )
        XCTAssertThrowsSuperNeoError(
            try reparsed.validate(against: wrongPolicy),
            .verificationFailed("NumiSeal public statement transcript domain mismatch")
        )

        var tampered = statement.superNeoBytes
        tampered[tampered.count - 1] ^= 1
        XCTAssertThrowsSuperNeoError(
            try NumiSealPublicStatement(bytes: tampered),
            .invalidEncoding("NumiSeal lane summary digest mismatch")
        )
    }

    func testNumiSealLaneAggregationChunksDeterministicallyAndRoundTrips() throws {
        let fixture = try makeNumiSealCanonicalFixture(claimCount: 3)
        let limits = try NumiSealAggregationLimits(maximumObligationsPerAggregate: 2)
        let aggregates = try NumiSealLaneAggregation.aggregate(
            canonicalization: fixture.canonicalization,
            policy: fixture.policy,
            limits: limits
        )
        let canonicalFromReversed = try NumiSealCanonicalization.canonicalize(
            obligations: fixture.obligations.reversed(),
            policy: fixture.policy
        )
        let aggregatesFromReversed = try NumiSealLaneAggregation.aggregate(
            canonicalization: canonicalFromReversed,
            policy: fixture.policy,
            limits: limits
        )

        XCTAssertEqual(aggregates.count, 2)
        XCTAssertEqual(aggregates.map(\.aggregateIndex), [0, 1])
        XCTAssertEqual(aggregates.map(\.obligationDigests.count), [2, 1])
        XCTAssertEqual(
            aggregates.map(\.aggregateDigest),
            aggregatesFromReversed.map(\.aggregateDigest)
        )
        XCTAssertEqual(
            aggregates.map(\.challenges),
            aggregatesFromReversed.map(\.challenges)
        )

        for aggregate in aggregates {
            XCTAssertEqual(try NumiSealLaneAggregate(bytes: aggregate.superNeoBytes), aggregate)
        }

        var tampered = aggregates[0].superNeoBytes
        tampered[tampered.count - 1] ^= 1
        XCTAssertThrowsSuperNeoError(
            try NumiSealLaneAggregate(bytes: tampered),
            .invalidEncoding("NumiSeal aggregate digest mismatch")
        )
    }

    func testNumiSealAggregateEvaluationOracleReconstructsSparseCCSOpening() throws {
        let fixture = try makeFoldFixture()
        let fold = try fixture.backend.makeProver(key: fixture.key).foldWithOutput(
            fixture.input,
            transcriptSeed: fixture.seed
        )
        let publicInput = SuperNeoPublicFoldInput(fixture.input)
        let statement = CCSStatement(
            shapeDigest: publicInput.shape.shapeDigest,
            ccsInstances: publicInput.instances
        )
        let laneID = try NumiSealLaneID("oracle")
        let claims = Array(fold.outputClaims.prefix(2))
        let obligations = claims.enumerated().map { index, claim in
            NumiSealObligation(
                laneID: laneID,
                profileID: fixture.key.parameters.profileID,
                statement: statement,
                verifierKeyDigest: fixture.key.verifierKeyDigest,
                instance: CEInstance(claim),
                sourceFoldDigest: Digest256.hash("numiseal-oracle-source-\(index)")
            )
        }
        let policy = NumiSealAcceptancePolicy(
            statement: statement,
            verifierKeyDigest: fixture.key.verifierKeyDigest,
            acceptedLaneIDs: [laneID]
        )
        let canonicalization = try NumiSealCanonicalization.canonicalize(
            obligations: obligations,
            policy: policy
        )
        let aggregate = try XCTUnwrap(
            NumiSealLaneAggregation.aggregate(
                canonicalization: canonicalization,
                policy: policy,
                limits: try NumiSealAggregationLimits(maximumObligationsPerAggregate: 2)
            ).first
        )
        let claimByDigest = Dictionary(
            uniqueKeysWithValues: zip(
                obligations.map { NumiSealCanonicalization.obligationDigest($0) },
                claims
            )
        )
        let orderedClaims = try aggregate.obligationDigests.map { digest in
            try XCTUnwrap(claimByDigest[digest])
        }
        let witnessedClaim = try NumiSealAggregateEvaluationOracle.witnessedAggregateClaim(
            aggregate: aggregate,
            claims: orderedClaims,
            shape: fixture.input.shape,
            executionPolicy: .highAssurance
        )
        let witness = try XCTUnwrap(witnessedClaim.witness)
        let transformedMatrices = try fixture.input.shape.compiledSparseForSuperNeo().transformedSparseMatrices

        XCTAssertEqual(witnessedClaim.commitment, aggregate.aggregateCommitment)
        XCTAssertEqual(witnessedClaim.publicInput, aggregate.aggregatePublicInputEncoding.field)
        XCTAssertEqual(witnessedClaim.evaluations, aggregate.aggregateMatrixEvaluations)
        XCTAssertTrue(
            try NumiSealAggregateEvaluationOracle.verifyAggregateOpening(
                aggregate: aggregate,
                witness: witness,
                shape: fixture.input.shape,
                key: fixture.key,
                transformedMatrices: transformedMatrices,
                executionPolicy: .highAssurance
            )
        )

        var tamperedWitness = witness
        tamperedWitness[0] = tamperedWitness[0] + .one
        XCTAssertFalse(
            try NumiSealAggregateEvaluationOracle.verifyAggregateOpening(
                aggregate: aggregate,
                witness: tamperedWitness,
                shape: fixture.input.shape,
                key: fixture.key,
                transformedMatrices: transformedMatrices,
                executionPolicy: .highAssurance
            )
        )

        var tamperedEvaluations = aggregate.aggregateMatrixEvaluations
        tamperedEvaluations[0] = tamperedEvaluations[0] + CyclotomicExt2Ring54([GoldilocksExt2(.one)])
        let tamperedAggregate = try NumiSealLaneAggregate(
            laneKey: aggregate.laneKey,
            aggregateIndex: aggregate.aggregateIndex,
            obligationDigests: aggregate.obligationDigests,
            challenges: aggregate.challenges,
            aggregateCommitment: aggregate.aggregateCommitment,
            aggregatePublicInputEncoding: aggregate.aggregatePublicInputEncoding,
            evalPoint: aggregate.evalPoint,
            aggregateMatrixEvaluations: tamperedEvaluations
        )
        XCTAssertFalse(
            try NumiSealAggregateEvaluationOracle.verifyAggregateOpening(
                aggregate: tamperedAggregate,
                witness: witness,
                shape: fixture.input.shape,
                key: fixture.key,
                transformedMatrices: transformedMatrices,
                executionPolicy: .highAssurance
            )
        )

        var missingWitnessClaims = orderedClaims
        missingWitnessClaims[0] = CCSEvaluationClaim(
            commitment: missingWitnessClaims[0].commitment,
            publicInput: missingWitnessClaims[0].publicInput,
            point: missingWitnessClaims[0].point,
            evaluations: missingWitnessClaims[0].evaluations
        )
        XCTAssertThrowsSuperNeoError(
            try NumiSealAggregateEvaluationOracle.witnessedAggregateClaim(
                aggregate: aggregate,
                claims: missingWitnessClaims,
                shape: fixture.input.shape,
                executionPolicy: .highAssurance
            ),
            .invalidParameter("NumiSeal aggregate claim is missing witness")
        )
    }

    func testNumiSealLaneAggregationRejectsMismatchedPublicInputLengths() throws {
        let fixture = try makeFoldFixture()
        let fold = try fixture.backend.makeProver(key: fixture.key).foldWithOutput(
            fixture.input,
            transcriptSeed: fixture.seed
        )
        let publicInput = SuperNeoPublicFoldInput(fixture.input)
        let statement = CCSStatement(
            shapeDigest: publicInput.shape.shapeDigest,
            ccsInstances: publicInput.instances
        )
        let laneID = try NumiSealLaneID("main")
        let claim = fold.outputClaims[0]
        let base = NumiSealObligation(
            laneID: laneID,
            profileID: fixture.key.parameters.profileID,
            statement: statement,
            verifierKeyDigest: fixture.key.verifierKeyDigest,
            instance: CEInstance(claim),
            sourceFoldDigest: Digest256.hash("numiseal-source-base")
        )
        let widerPublicInput = PublicInputEncoding(field: claim.publicInput + [.one])
        let wider = NumiSealObligation(
            laneID: laneID,
            profileID: fixture.key.parameters.profileID,
            shapeDigest: statement.shapeDigest,
            statementDigest: statement.statementDigest,
            verifierKeyDigest: fixture.key.verifierKeyDigest,
            commitment: claim.commitment,
            publicInputEncoding: widerPublicInput,
            evalPoint: claim.point,
            matrixEvaluations: claim.evaluations,
            sourceFoldDigest: Digest256.hash("numiseal-source-wider-public")
        )
        let policy = NumiSealAcceptancePolicy(
            statement: statement,
            verifierKeyDigest: fixture.key.verifierKeyDigest,
            acceptedLaneIDs: [laneID]
        )
        let canonical = try NumiSealCanonicalization.canonicalize(
            obligations: [base, wider],
            policy: policy
        )

        XCTAssertThrowsSuperNeoError(
            try NumiSealLaneAggregation.aggregate(
                canonicalization: canonical,
                policy: policy
            ),
            .invalidParameter("NumiSeal lane aggregate public input lengths must match")
        )
    }

    func testNumiSealProofBodyRoundTripsAndUsesTypedAbsentCarryDigest() throws {
        let fixture = try makeNumiSealProofBodyFixture()
        let reparsed = try NumiSealProof(bytes: fixture.proof.superNeoBytes)
        let envelope = try NumiSealProofEnvelope(bytes: fixture.envelope.superNeoBytes)
        let preflight = try fixture.terminalPolicy.preflight(proofBytes: fixture.envelope.superNeoBytes)

        XCTAssertEqual(reparsed, fixture.proof)
        XCTAssertEqual(envelope, fixture.envelope)
        XCTAssertEqual(preflight, fixture.envelope)
        XCTAssertEqual(fixture.proof.aggregateCount, 1)
        XCTAssertEqual(fixture.proof.laneProofs.count, 1)

        let carryComponent = try XCTUnwrap(
            fixture.proof.componentDigests.first { $0.kind == .carry }
        )
        XCTAssertTrue(carryComponent.isAbsent)
        XCTAssertEqual(
            carryComponent.leafDigest,
            NumiSealComponentDigest.absent(
                kind: .carry,
                laneKey: fixture.laneProof.laneKey,
                aggregateIndex: fixture.laneProof.aggregateIndex
            ).leafDigest
        )
        XCTAssertNotEqual(carryComponent.payloadDigest, Digest256.hash([]))
    }

    func testNumiSealProofBodyRejectsMalformedPublicFields() throws {
        let fixture = try makeNumiSealProofBodyFixture()
        let proofBytes = fixture.proof.superNeoBytes
        let publicStatementLength = fixture.publicStatement.superNeoBytes.count
        let aggregateCountOffset = 2 + encodedCountByteWidth + publicStatementLength
        let laneProofCountOffset = aggregateCountOffset + encodedCountByteWidth
        let componentRootOffset = proofBytes.count - (2 * Digest256.byteCount)
        let transcriptDigestOffset = proofBytes.count - Digest256.byteCount

        var wrongVersion = proofBytes
        wrongVersion[0] ^= 1
        XCTAssertThrowsSuperNeoError(
            try NumiSealProof(bytes: wrongVersion),
            .invalidEncoding("unsupported NumiSeal proof body version")
        )

        var wrongAggregateCount = proofBytes
        writeUInt64(2, into: &wrongAggregateCount, at: aggregateCountOffset)
        XCTAssertThrowsSuperNeoError(
            try NumiSealProof(bytes: wrongAggregateCount),
            .invalidEncoding("NumiSeal aggregate count must match lane proof count")
        )

        var wrongLaneProofCount = proofBytes
        writeUInt64(2, into: &wrongLaneProofCount, at: laneProofCountOffset)
        XCTAssertThrowsSuperNeoError(
            try NumiSealProof(bytes: wrongLaneProofCount),
            .invalidEncoding("NumiSeal aggregate count must match lane proof count")
        )

        var wrongComponentRoot = proofBytes
        wrongComponentRoot[componentRootOffset] ^= 1
        XCTAssertThrowsSuperNeoError(
            try NumiSealProof(bytes: wrongComponentRoot),
            .invalidEncoding("NumiSeal component digest root mismatch")
        )

        var wrongTranscriptDigest = proofBytes
        wrongTranscriptDigest[transcriptDigestOffset] ^= 1
        XCTAssertThrowsSuperNeoError(
            try NumiSealProof(bytes: wrongTranscriptDigest),
            .invalidEncoding("NumiSeal transcript digest mismatch")
        )

        XCTAssertThrowsSuperNeoError(
            try NumiSealProof(bytes: proofBytes + [0]),
            .invalidEncoding("trailing proof bytes")
        )
    }

    func testNumiSealZKProofBodyRoundTripsAndRejectsRandomnessReuse() throws {
        let fixture = try makeNumiSealProofBodyFixture()
        let prover = NumiSealZKProver()
        let sessionMaterial = Array("numiseal-zk-test-session".utf8)
        let envelope = try prover.prove(
            terminalEnvelope: fixture.envelope,
            digitTensors: [fixture.digitTensor],
            randomnessSessionMaterial: sessionMaterial,
            randomnessSessionLabel: "unit-test"
        )
        let reparsed = try NumiSealZKProofEnvelope(bytes: envelope.superNeoBytes)

        XCTAssertEqual(envelope.header.kind, .numiSealZK)
        XCTAssertEqual(reparsed, envelope)
        XCTAssertEqual(envelope.proof.zkMode, NumiSealZK.maskedDigitTensorMode)
        XCTAssertEqual(envelope.proof.baseProof, fixture.proof)
        XCTAssertEqual(envelope.proof.maskStatements.count, 1)
        XCTAssertEqual(envelope.proof.maskStatements[0].laneKey, fixture.laneProof.laneKey)
        XCTAssertEqual(envelope.proof.maskStatements[0].aggregateIndex, fixture.laneProof.aggregateIndex)
        XCTAssertEqual(envelope.proof.maskStatements[0].digitTensorDigest, fixture.digitTensor.digest)
        XCTAssertEqual(envelope.proof.maskedResidualStatements.count, 1)
        let maskedResidual = envelope.proof.maskedResidualStatements[0]
        XCTAssertEqual(maskedResidual.laneKey, fixture.laneProof.laneKey)
        XCTAssertEqual(maskedResidual.aggregateIndex, fixture.laneProof.aggregateIndex)
        XCTAssertEqual(maskedResidual.residualOpeningDigest, fixture.residualOpening.openingDigest)
        XCTAssertEqual(maskedResidual.digitTensorDigest, fixture.digitTensor.digest)
        XCTAssertEqual(
            maskedResidual.maskedDigitEvaluation,
            maskedResidual.claimedDigitEvaluation + maskedResidual.maskEvaluation
        )
        XCTAssertEqual(maskedResidual.version, NumiSealZKMaskedResidualStatement.version)
        XCTAssertEqual(envelope.proof.bodyVersion, NumiSealZKProof.bodyVersion)
        try maskedResidual.validate(
            laneProof: fixture.laneProof,
            maskStatement: envelope.proof.maskStatements[0]
        )

        let wrongMaskedResidual = try NumiSealZKMaskedResidualStatement(
            laneKey: maskedResidual.laneKey,
            aggregateIndex: maskedResidual.aggregateIndex,
            residualOpeningDigest: Digest256.hash("wrong-opening"),
            linearResidualDigest: maskedResidual.linearResidualDigest,
            sumcheckProofDigest: maskedResidual.sumcheckProofDigest,
            finalPointDigest: maskedResidual.finalPointDigest,
            digitTensorDigest: maskedResidual.digitTensorDigest,
            maskDigest: maskedResidual.maskDigest,
            maskedTensorDigest: maskedResidual.maskedTensorDigest,
            decompositionCommitmentDigest: maskedResidual.decompositionCommitmentDigest,
            claimedDigitEvaluation: maskedResidual.claimedDigitEvaluation,
            maskEvaluation: maskedResidual.maskEvaluation,
            maskedDigitEvaluation: maskedResidual.maskedDigitEvaluation,
            accumulationChallengeDigest: maskedResidual.accumulationChallengeDigest,
            denseFoldDigest: maskedResidual.denseFoldDigest,
            equalityWeightDigest: maskedResidual.equalityWeightDigest,
            sumcheckAccumulationDigest: maskedResidual.sumcheckAccumulationDigest
        )
        XCTAssertThrowsSuperNeoError(
            try NumiSealZKProof(
                randomnessSessionDigest: envelope.proof.randomnessSessionDigest,
                baseProof: fixture.proof,
                maskStatements: envelope.proof.maskStatements,
                maskedResidualStatements: [wrongMaskedResidual]
            ),
            .verificationFailed("NumiSealZK masked residual opening digest mismatch")
        )

        let wrongAccumulationChallenge = try NumiSealZKMaskedResidualStatement(
            laneKey: maskedResidual.laneKey,
            aggregateIndex: maskedResidual.aggregateIndex,
            residualOpeningDigest: maskedResidual.residualOpeningDigest,
            linearResidualDigest: maskedResidual.linearResidualDigest,
            sumcheckProofDigest: maskedResidual.sumcheckProofDigest,
            finalPointDigest: maskedResidual.finalPointDigest,
            digitTensorDigest: maskedResidual.digitTensorDigest,
            maskDigest: maskedResidual.maskDigest,
            maskedTensorDigest: maskedResidual.maskedTensorDigest,
            decompositionCommitmentDigest: maskedResidual.decompositionCommitmentDigest,
            claimedDigitEvaluation: maskedResidual.claimedDigitEvaluation,
            maskEvaluation: maskedResidual.maskEvaluation,
            maskedDigitEvaluation: maskedResidual.maskedDigitEvaluation,
            accumulationChallengeDigest: Digest256.hash("wrong-accumulation-challenge"),
            denseFoldDigest: maskedResidual.denseFoldDigest,
            equalityWeightDigest: maskedResidual.equalityWeightDigest,
            sumcheckAccumulationDigest: maskedResidual.sumcheckAccumulationDigest
        )
        XCTAssertThrowsSuperNeoError(
            try NumiSealZKProof(
                randomnessSessionDigest: envelope.proof.randomnessSessionDigest,
                baseProof: fixture.proof,
                maskStatements: envelope.proof.maskStatements,
                maskedResidualStatements: [wrongAccumulationChallenge]
            ),
            .verificationFailed("NumiSealZK masked residual accumulation challenge mismatch")
        )

        let wrongEqualityWeightDigest = try NumiSealZKMaskedResidualStatement(
            laneKey: maskedResidual.laneKey,
            aggregateIndex: maskedResidual.aggregateIndex,
            residualOpeningDigest: maskedResidual.residualOpeningDigest,
            linearResidualDigest: maskedResidual.linearResidualDigest,
            sumcheckProofDigest: maskedResidual.sumcheckProofDigest,
            finalPointDigest: maskedResidual.finalPointDigest,
            digitTensorDigest: maskedResidual.digitTensorDigest,
            maskDigest: maskedResidual.maskDigest,
            maskedTensorDigest: maskedResidual.maskedTensorDigest,
            decompositionCommitmentDigest: maskedResidual.decompositionCommitmentDigest,
            claimedDigitEvaluation: maskedResidual.claimedDigitEvaluation,
            maskEvaluation: maskedResidual.maskEvaluation,
            maskedDigitEvaluation: maskedResidual.maskedDigitEvaluation,
            accumulationChallengeDigest: maskedResidual.accumulationChallengeDigest,
            denseFoldDigest: maskedResidual.denseFoldDigest,
            equalityWeightDigest: Digest256.hash("wrong-equality-weight-digest"),
            sumcheckAccumulationDigest: maskedResidual.sumcheckAccumulationDigest
        )
        XCTAssertThrowsSuperNeoError(
            try NumiSealZKProof(
                randomnessSessionDigest: envelope.proof.randomnessSessionDigest,
                baseProof: fixture.proof,
                maskStatements: envelope.proof.maskStatements,
                maskedResidualStatements: [wrongEqualityWeightDigest]
            ),
            .verificationFailed("NumiSealZK masked residual equality weight digest mismatch")
        )

        XCTAssertThrowsSuperNeoError(
            try prover.prove(
                terminalEnvelope: fixture.envelope,
                digitTensors: [fixture.digitTensor],
                randomnessSessionMaterial: sessionMaterial,
                randomnessSessionLabel: "unit-test"
            ),
            .verificationFailed("NumiSealZK randomness session reuse detected")
        )

        var wrongTranscript = envelope.superNeoBytes
        wrongTranscript[wrongTranscript.count - 1] ^= 1
        XCTAssertThrowsSuperNeoError(
            try NumiSealZKProofEnvelope(bytes: wrongTranscript),
            .invalidEncoding("NumiSealZK transcript digest mismatch")
        )

        let secondSession = Array("numiseal-zk-test-session-2".utf8)
        let secondEnvelope = try NumiSealZKProver().prove(
            terminalEnvelope: fixture.envelope,
            digitTensors: [fixture.digitTensor],
            randomnessSessionMaterial: secondSession,
            randomnessSessionLabel: "unit-test"
        )
        XCTAssertNotEqual(
            secondEnvelope.proof.maskStatements[0].maskDigest,
            envelope.proof.maskStatements[0].maskDigest
        )
    }

    func testNumiSealZKDefaultGuardRejectsRandomnessReuseAcrossProvers() throws {
        let fixture = try makeNumiSealProofBodyFixture()
        let sessionMaterial = Array("numiseal-zk-cross-prover-reuse-test".utf8)
        _ = try NumiSealZKProver().prove(
            terminalEnvelope: fixture.envelope,
            digitTensors: [fixture.digitTensor],
            randomnessSessionMaterial: sessionMaterial,
            randomnessSessionLabel: "cross-prover-unit-test"
        )

        XCTAssertThrowsSuperNeoError(
            try NumiSealZKProver().prove(
                terminalEnvelope: fixture.envelope,
                digitTensors: [fixture.digitTensor],
                randomnessSessionMaterial: sessionMaterial,
                randomnessSessionLabel: "cross-prover-unit-test"
            ),
            .verificationFailed("NumiSealZK randomness session reuse detected")
        )
    }

    func testNumiSealZKFixedRandomnessCPUAndMetalProofBytesMatch() throws {
        let fixture = try makeNumiSealProofBodyFixture()
        let device = try requireMetalDevice()
        let context = try MetalExecutionContext(device: device)
        let foldFixture = try makeFoldFixture()
        let baseWorkspace = try SuperNeoMetalWorkspace(
            context: context,
            key: foldFixture.key,
            compiledShape: foldFixture.input.shape.compiledSparseForSuperNeo()
        )
        let provingWorkspace = NumiSealMetalProvingWorkspace(
            baseWorkspace: baseWorkspace,
            provingPolicy: .zkRedundantMetal
        )
        let sessionMaterial = Array("numiseal-zk-fixed-metal-equivalence".utf8)
        let deterministicGuard = NumiSealZKRandomnessReuseGuard(enforcesReuseDetection: false)
        let cpuEnvelope = try NumiSealZKProver(randomnessReuseGuard: deterministicGuard).prove(
            terminalEnvelope: fixture.envelope,
            digitTensors: [fixture.digitTensor],
            randomnessSessionMaterial: sessionMaterial,
            randomnessSessionLabel: "fixed-equivalence"
        )
        let metalEnvelope = try NumiSealZKProver(randomnessReuseGuard: deterministicGuard).prove(
            terminalEnvelope: fixture.envelope,
            digitTensors: [fixture.digitTensor],
            randomnessSessionMaterial: sessionMaterial,
            randomnessSessionLabel: "fixed-equivalence",
            provingWorkspace: provingWorkspace
        )

        XCTAssertEqual(metalEnvelope, cpuEnvelope)
        XCTAssertEqual(metalEnvelope.superNeoBytes, cpuEnvelope.superNeoBytes)
        XCTAssertEqual(
            metalEnvelope.proof.maskedResidualStatements[0].denseFoldDigest,
            cpuEnvelope.proof.maskedResidualStatements[0].denseFoldDigest
        )
        XCTAssertEqual(
            metalEnvelope.proof.maskedResidualStatements[0].sumcheckAccumulationDigest,
            cpuEnvelope.proof.maskedResidualStatements[0].sumcheckAccumulationDigest
        )
    }

    func testNumiSealProofBodyMutationsCoverLaneProofPublicFields() throws {
        let fixture = try makeNumiSealProofBodyFixture()
        let proofBytes = fixture.proof.superNeoBytes
        let publicStatementLength = fixture.publicStatement.superNeoBytes.count
        let firstLaneFrameOffset = 2
            + encodedCountByteWidth
            + publicStatementLength
            + encodedCountByteWidth
            + encodedCountByteWidth
        let lanePayloadOffset = firstLaneFrameOffset + encodedCountByteWidth
        let laneProof = fixture.laneProof
        let aggregateIndexOffset = laneProof.laneKey.superNeoBytes.count
        let aggregateDigestOffset = aggregateIndexOffset + encodedCountByteWidth
        let decompositionKeyDigestOffset = aggregateDigestOffset + Digest256.byteCount
        let decompositionCommitmentOffset = decompositionKeyDigestOffset + Digest256.byteCount
        let scalarizationDigestOffset = decompositionCommitmentOffset + laneProof.decompositionCommitment.superNeoBytes.count
        let sumcheckFrameOffset = scalarizationDigestOffset + Digest256.byteCount
        let sumcheckPayloadOffset = sumcheckFrameOffset + encodedCountByteWidth
        let residualFrameOffset = sumcheckPayloadOffset + laneProof.sumcheckProof.superNeoBytes.count
        let residualPayloadOffset = residualFrameOffset + encodedCountByteWidth
        let carryTagOffset = residualPayloadOffset + laneProof.residualOpening.superNeoBytes.count

        let mutationOffsets = [
            lanePayloadOffset,
            lanePayloadOffset + aggregateIndexOffset,
            lanePayloadOffset + aggregateDigestOffset,
            lanePayloadOffset + decompositionKeyDigestOffset,
            lanePayloadOffset + decompositionCommitmentOffset,
            lanePayloadOffset + scalarizationDigestOffset,
            lanePayloadOffset + sumcheckPayloadOffset,
            lanePayloadOffset + residualPayloadOffset,
            lanePayloadOffset + carryTagOffset
        ]

        for offset in mutationOffsets {
            var mutated = proofBytes
            mutated[offset] ^= 1
            XCTAssertThrowsError(try NumiSealProof(bytes: mutated)) { error in
                XCTAssertNotNil(error as? SuperNeoError)
            }
        }
    }

    func testNumiSealProofBodyEnforcesLaneMajorAggregateOrdering() throws {
        let first = try makeNumiSealProofBodyFixture(laneLabel: "a")
        let second = try makeNumiSealProofBodyFixture(laneLabel: "b")

        XCTAssertNoThrow(
            try NumiSealProof(
                publicStatement: first.publicStatement,
                laneProofs: [first.laneProof, second.laneProof]
            )
        )
        XCTAssertThrowsSuperNeoError(
            try NumiSealProof(
                publicStatement: first.publicStatement,
                laneProofs: [second.laneProof, first.laneProof]
            ),
            .invalidEncoding("NumiSeal lane proofs must be lane-major and aggregate-index sorted")
        )
        XCTAssertThrowsSuperNeoError(
            try NumiSealProof(
                publicStatement: first.publicStatement,
                laneProofs: [first.laneProof, first.laneProof]
            ),
            .invalidEncoding("NumiSeal lane proofs must be lane-major and aggregate-index sorted")
        )
    }

    func testNumiSealEnvelopeKindAndTerminalPolicyAreSeparated() throws {
        let fixture = try makeNumiSealProofBodyFixture()
        XCTAssertEqual(fixture.envelope.header.kind, .numiSealTerminal)
        XCTAssertEqual(try NumiSealProofEnvelope(bytes: fixture.envelope.superNeoBytes), fixture.envelope)

        let legacyTerminalPolicy = SuperNeoTerminalProofAcceptancePolicy(
            profileID: fixture.policy.profileID,
            shapeDigest: fixture.policy.shapeDigest,
            statementDigest: fixture.policy.statementDigest,
            verifierKeyDigest: fixture.policy.verifierKeyDigest,
            transcriptDomain: fixture.policy.transcriptDomain
        )
        XCTAssertThrowsSuperNeoError(
            try legacyTerminalPolicy.context(
                for: fixture.envelope.header,
                totalByteCount: fixture.envelope.superNeoBytes.count
            ),
            .verificationFailed("proof kind not accepted by policy")
        )

        let foldHeader = ProofEnvelopeHeader(
            profileID: fixture.policy.profileID,
            kind: .foldReduction,
            shapeDigest: fixture.policy.shapeDigest,
            statementDigest: fixture.policy.statementDigest,
            verifierKeyDigest: fixture.policy.verifierKeyDigest,
            transcriptDomain: fixture.policy.transcriptDomain,
            bodyLength: 0
        )
        XCTAssertThrowsSuperNeoError(
            try fixture.terminalPolicy.context(
                for: foldHeader,
                totalByteCount: ProofEnvelopeHeader.byteCount
            ),
            .verificationFailed("NumiSeal terminal proof required")
        )

        var wrongKindEnvelope = fixture.envelope.superNeoBytes
        wrongKindEnvelope[8] = ProofEnvelopeKind.terminalLocal.rawValue
        XCTAssertThrowsSuperNeoError(
            try NumiSealProofEnvelope(bytes: wrongKindEnvelope),
            .invalidEncoding("NumiSeal proof envelope kind mismatch")
        )
    }

    func testNumiSealTerminalPolicyRejectsWrongLaneCarryModeAndProofSize() throws {
        let fixture = try makeNumiSealProofBodyFixture()
        let wrongLanePolicy = NumiSealTerminalProofAcceptancePolicy(
            profileID: fixture.policy.profileID,
            shapeDigest: fixture.policy.shapeDigest,
            statementDigest: fixture.policy.statementDigest,
            verifierKeyDigest: fixture.policy.verifierKeyDigest,
            transcriptDomain: fixture.policy.transcriptDomain,
            acceptedLaneIDs: [try NumiSealLaneID("other")]
        )
        XCTAssertThrowsSuperNeoError(
            try wrongLanePolicy.preflight(proofBytes: fixture.envelope.superNeoBytes),
            .verificationFailed("NumiSeal public statement lane is not accepted by policy")
        )

        let uncoveredLane = try makeNumiSealProofBodyFixture(laneLabel: "uncovered")
        let uncoveredProof = try NumiSealProof(
            publicStatement: fixture.publicStatement,
            laneProofs: [uncoveredLane.laneProof]
        )
        let uncoveredContext = ProofEnvelopeContext(
            profileID: fixture.policy.profileID,
            kind: .numiSealTerminal,
            shapeDigest: fixture.policy.shapeDigest,
            statementDigest: fixture.policy.statementDigest,
            verifierKeyDigest: fixture.policy.verifierKeyDigest,
            transcriptDomain: fixture.policy.transcriptDomain
        )
        let uncoveredEnvelope = try NumiSealProofEnvelope(context: uncoveredContext, proof: uncoveredProof)
        let uncoveredPolicy = NumiSealTerminalProofAcceptancePolicy(
            profileID: fixture.policy.profileID,
            shapeDigest: fixture.policy.shapeDigest,
            statementDigest: fixture.policy.statementDigest,
            verifierKeyDigest: fixture.policy.verifierKeyDigest,
            transcriptDomain: fixture.policy.transcriptDomain,
            acceptedLaneIDs: fixture.policy.acceptedLaneIDs.union([uncoveredLane.laneProof.laneKey.laneID])
        )
        XCTAssertThrowsSuperNeoError(
            try uncoveredPolicy.preflight(proofBytes: uncoveredEnvelope.superNeoBytes),
            .verificationFailed("NumiSeal lane proof is not covered by public statement")
        )

        let secondLane = try makeNumiSealProofBodyFixture(laneLabel: "second-lane")
        let twoLanePolicy = NumiSealAcceptancePolicy(
            profileID: fixture.policy.profileID,
            shapeDigest: fixture.policy.shapeDigest,
            statementDigest: fixture.policy.statementDigest,
            verifierKeyDigest: fixture.policy.verifierKeyDigest,
            transcriptDomain: fixture.policy.transcriptDomain,
            acceptedLaneIDs: fixture.policy.acceptedLaneIDs.union(secondLane.policy.acceptedLaneIDs)
        )
        let twoLaneCanonicalization = try NumiSealCanonicalization.canonicalize(
            obligations: [fixture.obligation, secondLane.obligation],
            policy: twoLanePolicy
        )
        let twoLanePublicStatement = try NumiSealPublicStatement(
            canonicalization: twoLaneCanonicalization,
            policy: twoLanePolicy
        )
        let missingLaneProof = try NumiSealProof(
            publicStatement: twoLanePublicStatement,
            laneProofs: [fixture.laneProof]
        )
        let missingLaneEnvelope = try NumiSealProofEnvelope(
            context: uncoveredContext,
            proof: missingLaneProof
        )
        let twoLaneTerminalPolicy = NumiSealTerminalProofAcceptancePolicy(
            profileID: twoLanePolicy.profileID,
            shapeDigest: twoLanePolicy.shapeDigest,
            statementDigest: twoLanePolicy.statementDigest,
            verifierKeyDigest: twoLanePolicy.verifierKeyDigest,
            transcriptDomain: twoLanePolicy.transcriptDomain,
            acceptedLaneIDs: twoLanePolicy.acceptedLaneIDs,
            maximumLaneCount: 2
        )
        XCTAssertThrowsSuperNeoError(
            try twoLaneTerminalPolicy.preflight(proofBytes: missingLaneEnvelope.superNeoBytes),
            .verificationFailed("NumiSeal lane summary has no lane proof")
        )

        let skippedIndexFixture = try makeNumiSealProofBodyFixture(aggregateIndexOverride: 1)
        XCTAssertThrowsSuperNeoError(
            try skippedIndexFixture.terminalPolicy.preflight(proofBytes: skippedIndexFixture.envelope.superNeoBytes),
            .verificationFailed("NumiSeal lane proof aggregate indices must be contiguous")
        )

        let overCoveredProof = try NumiSealProof(
            publicStatement: fixture.publicStatement,
            laneProofs: [fixture.laneProof, skippedIndexFixture.laneProof]
        )
        let overCoveredEnvelope = try NumiSealProofEnvelope(
            context: uncoveredContext,
            proof: overCoveredProof
        )
        XCTAssertThrowsSuperNeoError(
            try fixture.terminalPolicy.preflight(proofBytes: overCoveredEnvelope.superNeoBytes),
            .verificationFailed("NumiSeal aggregate count exceeds lane obligation count")
        )

        let cappedPolicy = NumiSealTerminalProofAcceptancePolicy(
            profileID: fixture.policy.profileID,
            shapeDigest: fixture.policy.shapeDigest,
            statementDigest: fixture.policy.statementDigest,
            verifierKeyDigest: fixture.policy.verifierKeyDigest,
            transcriptDomain: fixture.policy.transcriptDomain,
            acceptedLaneIDs: fixture.policy.acceptedLaneIDs,
            maximumProofByteCount: fixture.envelope.superNeoBytes.count - 1
        )
        XCTAssertThrowsSuperNeoError(
            try cappedPolicy.preflight(proofBytes: fixture.envelope.superNeoBytes),
            .verificationFailed("NumiSeal proof byte count exceeds policy maximum")
        )

        let carryFixture = try makeNumiSealProofBodyFixture(carryBytes: Array("carry".utf8))
        let noCarryPolicy = NumiSealTerminalProofAcceptancePolicy(
            profileID: carryFixture.policy.profileID,
            shapeDigest: carryFixture.policy.shapeDigest,
            statementDigest: carryFixture.policy.statementDigest,
            verifierKeyDigest: carryFixture.policy.verifierKeyDigest,
            transcriptDomain: carryFixture.policy.transcriptDomain,
            acceptedLaneIDs: carryFixture.policy.acceptedLaneIDs,
            acceptedCarryMode: .none
        )
        XCTAssertThrowsSuperNeoError(
            try noCarryPolicy.preflight(proofBytes: carryFixture.envelope.superNeoBytes),
            .verificationFailed("NumiSeal carry claims are not accepted by policy")
        )

        let requiredCarryPolicy = NumiSealTerminalProofAcceptancePolicy(
            profileID: fixture.policy.profileID,
            shapeDigest: fixture.policy.shapeDigest,
            statementDigest: fixture.policy.statementDigest,
            verifierKeyDigest: fixture.policy.verifierKeyDigest,
            transcriptDomain: fixture.policy.transcriptDomain,
            acceptedLaneIDs: fixture.policy.acceptedLaneIDs,
            acceptedCarryMode: .required
        )
        XCTAssertThrowsSuperNeoError(
            try requiredCarryPolicy.preflight(proofBytes: fixture.envelope.superNeoBytes),
            .verificationFailed("NumiSeal carry claim required by policy")
        )
    }

    func testNumiSealTypedCarryStatementRoundTripsAndPolicyRejectsMalformedCarry() throws {
        let fixture = try makeNumiSealProofBodyFixture()
        let consumerContextDigest = Digest256.hash("typed-carry-consumer-context")
        let statement = try NumiSealCarryStatement(
            carryKind: .residualOpening,
            recursionLevel: 1,
            producerProofEnvelopeDigest: Digest256.hash(fixture.envelope.superNeoBytes),
            producerProofTranscriptDigest: fixture.proof.transcriptDigest,
            parentStatementDigest: fixture.policy.statementDigest,
            parentPublicStatementDigest: fixture.publicStatement.digest,
            laneKey: fixture.aggregate.laneKey,
            aggregateIndex: fixture.aggregate.aggregateIndex,
            residualOpeningDigest: fixture.residualOpening.openingDigest,
            decompositionKeyDigest: fixture.decomposition.decompositionKeyDigest,
            decompositionCommitmentDigest: fixture.decomposition.commitmentDigest,
            finalPointDigest: NumiSealCarryStatement.finalPointDigest(fixture.laneProof.sumcheckProof.finalPoint),
            claimedDigitEvaluation: fixture.residualStatement.claimedDigitEvaluation,
            consumerContextDigest: consumerContextDigest
        )
        let claim = try NumiSealCarryClaim(statement.superNeoBytes)

        XCTAssertEqual(claim.typedStatement, statement)
        XCTAssertEqual(try NumiSealCarryStatement(bytes: statement.superNeoBytes), statement)

        let typedCarryFixture = try makeNumiSealProofBodyFixture(carryBytes: statement.superNeoBytes)
        let typedRequiredPolicy = NumiSealTerminalProofAcceptancePolicy(
            profileID: typedCarryFixture.policy.profileID,
            shapeDigest: typedCarryFixture.policy.shapeDigest,
            statementDigest: typedCarryFixture.policy.statementDigest,
            verifierKeyDigest: typedCarryFixture.policy.verifierKeyDigest,
            transcriptDomain: typedCarryFixture.policy.transcriptDomain,
            acceptedLaneIDs: typedCarryFixture.policy.acceptedLaneIDs,
            acceptedCarryMode: .typedRequired
        )
        XCTAssertNoThrow(try typedRequiredPolicy.preflight(proofBytes: typedCarryFixture.envelope.superNeoBytes))

        let rawCarryFixture = try makeNumiSealProofBodyFixture(carryBytes: Array("carry".utf8))
        let rawTypedPolicy = NumiSealTerminalProofAcceptancePolicy(
            profileID: rawCarryFixture.policy.profileID,
            shapeDigest: rawCarryFixture.policy.shapeDigest,
            statementDigest: rawCarryFixture.policy.statementDigest,
            verifierKeyDigest: rawCarryFixture.policy.verifierKeyDigest,
            transcriptDomain: rawCarryFixture.policy.transcriptDomain,
            acceptedLaneIDs: rawCarryFixture.policy.acceptedLaneIDs,
            acceptedCarryMode: .typedRequired
        )
        XCTAssertThrowsSuperNeoError(
            try rawTypedPolicy.preflight(proofBytes: rawCarryFixture.envelope.superNeoBytes),
            .verificationFailed("NumiSeal typed carry claim is malformed")
        )
    }

    func testNumiSealCarryConsumerBindsContextAndRejectsReplay() throws {
        let fixture = try makeNumiSealProofBodyFixture()
        let consumerContextDigest = Digest256.hash("typed-carry-consumer-context")
        let producerProofEnvelopeDigest = Digest256.hash(fixture.envelope.superNeoBytes)
        let statement = try NumiSealCarryStatement(
            carryKind: .residualOpening,
            recursionLevel: 2,
            producerProofEnvelopeDigest: producerProofEnvelopeDigest,
            producerProofTranscriptDigest: fixture.proof.transcriptDigest,
            parentStatementDigest: fixture.policy.statementDigest,
            parentPublicStatementDigest: fixture.publicStatement.digest,
            laneKey: fixture.aggregate.laneKey,
            aggregateIndex: fixture.aggregate.aggregateIndex,
            residualOpeningDigest: fixture.residualOpening.openingDigest,
            decompositionKeyDigest: fixture.decomposition.decompositionKeyDigest,
            decompositionCommitmentDigest: fixture.decomposition.commitmentDigest,
            finalPointDigest: NumiSealCarryStatement.finalPointDigest(fixture.laneProof.sumcheckProof.finalPoint),
            claimedDigitEvaluation: fixture.residualStatement.claimedDigitEvaluation,
            consumerContextDigest: consumerContextDigest
        )

        var consumer = NumiSealCarryConsumer()
        let accepted = try consumer.consume(
            statement,
            parentProofAccepted: true,
            expectedProducerProofEnvelopeDigest: producerProofEnvelopeDigest,
            expectedProducerProofTranscriptDigest: fixture.proof.transcriptDigest,
            expectedParentStatementDigest: fixture.policy.statementDigest,
            expectedParentPublicStatementDigest: fixture.publicStatement.digest,
            expectedConsumerContextDigest: consumerContextDigest,
            minimumNextRecursionLevel: 2
        )
        XCTAssertEqual(accepted.statement, statement)

        XCTAssertThrowsSuperNeoError(
            try consumer.consume(
                statement,
                parentProofAccepted: true,
                expectedProducerProofEnvelopeDigest: producerProofEnvelopeDigest,
                expectedProducerProofTranscriptDigest: fixture.proof.transcriptDigest,
                expectedParentStatementDigest: fixture.policy.statementDigest,
                expectedParentPublicStatementDigest: fixture.publicStatement.digest,
                expectedConsumerContextDigest: consumerContextDigest,
                minimumNextRecursionLevel: 2
            ),
            .verificationFailed("NumiSeal carry replay detected")
        )

        var freshConsumer = NumiSealCarryConsumer()
        XCTAssertThrowsSuperNeoError(
            try freshConsumer.consume(
                statement,
                parentProofAccepted: true,
                expectedProducerProofEnvelopeDigest: producerProofEnvelopeDigest,
                expectedProducerProofTranscriptDigest: fixture.proof.transcriptDigest,
                expectedParentStatementDigest: fixture.policy.statementDigest,
                expectedParentPublicStatementDigest: fixture.publicStatement.digest,
                expectedConsumerContextDigest: Digest256.hash("wrong-consumer-context"),
                minimumNextRecursionLevel: 2
            ),
            .verificationFailed("NumiSeal carry consumer context digest mismatch")
        )
    }

    func testNumiSealTypedCarryProducerFeedsConsumerAndRejectsUnacceptedParent() throws {
        let fixture = try makeNumiSealProofBodyFixture()
        let consumerContextDigest = Digest256.hash("typed-carry-recursive-consumer-context")
        let producer = NumiSealTypedCarryProducer()
        let statement = try producer.produce(
            fromAcceptedParent: fixture.envelope,
            parentProofAccepted: true,
            laneKey: fixture.aggregate.laneKey,
            aggregateIndex: fixture.aggregate.aggregateIndex,
            consumerContextDigest: consumerContextDigest,
            nextRecursionLevel: 3
        )
        XCTAssertEqual(statement.producerProofEnvelopeDigest, Digest256.hash(fixture.envelope.superNeoBytes))
        XCTAssertEqual(statement.producerProofTranscriptDigest, fixture.proof.transcriptDigest)
        XCTAssertEqual(statement.parentStatementDigest, fixture.policy.statementDigest)
        XCTAssertEqual(statement.parentPublicStatementDigest, fixture.publicStatement.digest)
        XCTAssertEqual(statement.residualOpeningDigest, fixture.residualOpening.openingDigest)
        XCTAssertEqual(statement.decompositionCommitmentDigest, fixture.decomposition.commitmentDigest)
        XCTAssertEqual(statement.finalPointDigest, NumiSealCarryStatement.finalPointDigest(fixture.laneProof.sumcheckProof.finalPoint))

        var consumer = NumiSealCarryConsumer()
        let accepted = try consumer.consume(
            statement,
            parentProofAccepted: true,
            expectedProducerProofEnvelopeDigest: Digest256.hash(fixture.envelope.superNeoBytes),
            expectedProducerProofTranscriptDigest: fixture.proof.transcriptDigest,
            expectedParentStatementDigest: fixture.policy.statementDigest,
            expectedParentPublicStatementDigest: fixture.publicStatement.digest,
            expectedConsumerContextDigest: consumerContextDigest,
            minimumNextRecursionLevel: 3
        )
        XCTAssertEqual(accepted.statement, statement)

        XCTAssertThrowsSuperNeoError(
            try producer.produce(
                fromAcceptedParent: fixture.envelope,
                parentProofAccepted: false,
                laneKey: fixture.aggregate.laneKey,
                aggregateIndex: fixture.aggregate.aggregateIndex,
                consumerContextDigest: consumerContextDigest,
                nextRecursionLevel: 3
            ),
            .verificationFailed("NumiSeal typed carry parent proof is not accepted")
        )
    }

    func testNumiSealZKMaskSamplerUsesExactFieldRejectionSampling() {
        XCTAssertEqual(NumiSealZKMaskSampler.candidateBitWidth, 64)
        XCTAssertEqual(NumiSealZKMaskSampler.rejectedCandidateCount, 0xFFFF_FFFF)
        XCTAssertTrue(NumiSealZKMaskSampler.accepts(candidate: GoldilocksField.modulus - 1))
        XCTAssertFalse(NumiSealZKMaskSampler.accepts(candidate: GoldilocksField.modulus))
        XCTAssertFalse(NumiSealZKMaskSampler.accepts(candidate: UInt64.max))
    }

    func testNumiSealArtifactVerifierValidatesCheckedVectorWithStrictPins() throws {
        let artifact = try loadNumiSealArtifact(named: "numiseal-terminal-single-aggregate-v1.json")
        let expectedContext = try strictExpectedContext(for: artifact)

        let report = try NumiSealArtifactVerifier.verify(
            artifact: artifact,
            expectedContext: expectedContext,
            executionPolicy: .highAssurance
        )

        XCTAssertTrue(report.verificationResult.isValid, report.verificationResult.reason ?? "")
        XCTAssertEqual(report.verificationResult.envelope, report.envelope)
        XCTAssertEqual(report.material.obligations.count, artifact.laneIDsUTF8.count)
        XCTAssertEqual(report.material.plan.aggregateDigests.map(\.hexStringForTest), artifact.aggregateDigestsHex)
        XCTAssertEqual(report.envelope.proof.publicStatement.digest.hexStringForTest, artifact.publicStatementDigestHex)
        XCTAssertEqual(report.envelope.proof.componentDigestRoot.hexStringForTest, artifact.componentDigestRootHex)
        XCTAssertEqual(report.envelope.proof.transcriptDigest.hexStringForTest, artifact.proofTranscriptDigestHex)
    }

    func testNumiSealArtifactVerifierRejectsExpectedContextTrustPinMismatches() throws {
        let artifact = try loadNumiSealArtifact(named: "numiseal-terminal-single-aggregate-v1.json")
        let material = try NumiSealArtifactVerifier.makeVerificationMaterial(
            from: artifact,
            keySeed: artifact.keySeedUTF8,
            executionPolicy: .highAssurance
        )
        try NumiSealArtifactVerifier.validateMaterial(material, against: artifact)

        let wrongDigest = Digest256.hash("numiseal-artifact-verifier-wrong-digest")
        XCTAssertThrowsNumiSealArtifactError(
            try NumiSealArtifactVerifier.validateExpectedContext(
                artifact: artifact,
                material: material,
                expectedContext: NumiSealArtifactExpectedContext(shapeDigest: wrongDigest)
            ),
            containing: "expected shape digest"
        )
        XCTAssertThrowsNumiSealArtifactError(
            try NumiSealArtifactVerifier.validateExpectedContext(
                artifact: artifact,
                material: material,
                expectedContext: NumiSealArtifactExpectedContext(statementDigest: wrongDigest)
            ),
            containing: "expected statement digest"
        )
        XCTAssertThrowsNumiSealArtifactError(
            try NumiSealArtifactVerifier.validateExpectedContext(
                artifact: artifact,
                material: material,
                expectedContext: NumiSealArtifactExpectedContext(verifierKeyDigest: wrongDigest)
            ),
            containing: "expected verifier key digest"
        )
        XCTAssertThrowsNumiSealArtifactError(
            try NumiSealArtifactVerifier.validateExpectedContext(
                artifact: artifact,
                material: material,
                expectedContext: NumiSealArtifactExpectedContext(transcriptDomainDigest: wrongDigest)
            ),
            containing: "expected transcript domain"
        )
        XCTAssertThrowsNumiSealArtifactError(
            try NumiSealArtifactVerifier.validateExpectedContext(
                artifact: artifact,
                material: material,
                expectedContext: NumiSealArtifactExpectedContext(publicStatementDigest: wrongDigest)
            ),
            containing: "expected public statement digest"
        )
        XCTAssertThrowsNumiSealArtifactError(
            try NumiSealArtifactVerifier.validateExpectedContext(
                artifact: artifact,
                material: material,
                expectedContext: NumiSealArtifactExpectedContext(obligationRoot: wrongDigest)
            ),
            containing: "expected obligation root"
        )
        XCTAssertThrowsNumiSealArtifactError(
            try NumiSealArtifactVerifier.validateExpectedContext(
                artifact: artifact,
                material: material,
                expectedContext: NumiSealArtifactExpectedContext(laneSummaryRoot: wrongDigest)
            ),
            containing: "expected lane summary root"
        )
        XCTAssertThrowsNumiSealArtifactError(
            try NumiSealArtifactVerifier.validateExpectedContext(
                artifact: artifact,
                material: material,
                expectedContext: NumiSealArtifactExpectedContext(aggregateDigests: [wrongDigest])
            ),
            containing: "expected aggregate digests"
        )
        XCTAssertThrowsNumiSealArtifactError(
            try NumiSealArtifactVerifier.validateExpectedContext(
                artifact: artifact,
                material: material,
                expectedContext: NumiSealArtifactExpectedContext(componentDigestRoot: wrongDigest)
            ),
            containing: "expected component digest root"
        )
        XCTAssertThrowsNumiSealArtifactError(
            try NumiSealArtifactVerifier.validateExpectedContext(
                artifact: artifact,
                material: material,
                expectedContext: NumiSealArtifactExpectedContext(proofTranscriptDigest: wrongDigest)
            ),
            containing: "expected proof transcript digest"
        )

        var wrongPublicInputs = artifact.publicInputs
        wrongPublicInputs[0] ^= 1
        XCTAssertThrowsNumiSealArtifactError(
            try NumiSealArtifactVerifier.verify(
                artifact: artifact,
                expectedContext: NumiSealArtifactExpectedContext(
                    trustedKeySeedUTF8: artifact.keySeedUTF8,
                    publicInputs: wrongPublicInputs
                ),
                executionPolicy: .highAssurance
            ),
            containing: "expected public inputs"
        )
        XCTAssertThrowsNumiSealArtifactError(
            try NumiSealArtifactVerifier.verify(
                artifact: artifact,
                expectedContext: NumiSealArtifactExpectedContext(trustedKeySeedUTF8: "wrong-numiseal-key-seed"),
                executionPolicy: .highAssurance
            ),
            containing: "regenerated key"
        )
    }

    func testNumiSealArtifactVerifierRejectsSelfDescribedContextWithoutKeyTrustPin() throws {
        let artifact = try loadNumiSealArtifact(named: "numiseal-terminal-single-aggregate-v1.json")

        XCTAssertThrowsNumiSealArtifactError(
            try NumiSealArtifactVerifier.verify(
                artifact: artifact,
                expectedContext: NumiSealArtifactExpectedContext(publicInputs: artifact.publicInputs),
                executionPolicy: .highAssurance
            ),
            containing: "trusted key seed or verifier key digest"
        )
    }

    func testNumiSealProductVerifierAcceptsThroughIntegrationHooks() throws {
        let data = try loadNumiSealArtifactData(named: "numiseal-terminal-single-aggregate-v1.json")
        let artifact = try JSONDecoder().decode(NumiSealArtifact.self, from: data)
        let expectedContext = try strictExpectedContext(for: artifact)
        let store = ProductExpectedContextStore(expectedContext: expectedContext)
        let authorizer = ProductAuthorizer()
        let provenanceVerifier = ProductProvenanceVerifier()
        let replayLedger = ProductReplayLedger()
        let auditSink = ProductAuditSink()
        let verifier = SuperNeoNumiSealProductVerifier(
            expectedContextStore: store,
            authorizer: authorizer,
            provenanceVerifier: provenanceVerifier,
            replayLedger: replayLedger,
            auditSink: auditSink
        )

        let request = SuperNeoNumiSealProductVerificationRequest(
            callerID: "tenant-a",
            expectedContextID: "ctx-numiseal-single",
            artifact: artifact,
            artifactBytes: [UInt8](data),
            maximumArtifactByteCount: data.count
        )
        let report = try verifier.verify(request)

        XCTAssertTrue(report.innerReport.verificationResult.isValid)
        XCTAssertTrue(try replayLedger.hasAccepted(report.identity))
        XCTAssertEqual(auditSink.events.count, 1)
        XCTAssertEqual(auditSink.events.last?.decision, .accepted)
        XCTAssertEqual(auditSink.events.last?.artifactDigest, Digest256.hash([UInt8](data)))
        XCTAssertEqual(auditSink.events.last?.provenanceDigest, provenanceVerifier.provenanceDigest)
    }

    func testNumiSealProductVerifierRejectsArtifactObjectThatDoesNotMatchBytes() throws {
        let data = try loadNumiSealArtifactData(named: "numiseal-terminal-single-aggregate-v1.json")
        let artifact = try JSONDecoder().decode(NumiSealArtifact.self, from: data)
        let mismatchedArtifact = NumiSealArtifact(
            artifactVersion: artifact.artifactVersion,
            workload: "\(artifact.workload)-mismatch",
            profile: artifact.profile,
            proofKind: artifact.proofKind,
            residualMode: artifact.residualMode,
            keySeedUTF8: artifact.keySeedUTF8,
            keyColumnCount: artifact.keyColumnCount,
            foldTranscriptSeedUTF8: artifact.foldTranscriptSeedUTF8,
            laneIDsUTF8: artifact.laneIDsUTF8,
            sourceFoldDigestSeedsUTF8: artifact.sourceFoldDigestSeedsUTF8,
            ceRandomSeedsUTF8: artifact.ceRandomSeedsUTF8,
            maximumObligationsPerAggregate: artifact.maximumObligationsPerAggregate,
            maximumLaneCount: artifact.maximumLaneCount,
            maximumAggregatesPerLane: artifact.maximumAggregatesPerLane,
            publicInputCount: artifact.publicInputCount,
            privateWitnessCount: artifact.privateWitnessCount,
            publicInputs: artifact.publicInputs,
            shapeDigestHex: artifact.shapeDigestHex,
            statementDigestHex: artifact.statementDigestHex,
            verifierKeyDigestHex: artifact.verifierKeyDigestHex,
            transcriptDomainHex: artifact.transcriptDomainHex,
            publicStatementDigestHex: artifact.publicStatementDigestHex,
            obligationRootHex: artifact.obligationRootHex,
            laneSummaryRootHex: artifact.laneSummaryRootHex,
            aggregateDigestsHex: artifact.aggregateDigestsHex,
            componentDigestRootHex: artifact.componentDigestRootHex,
            proofTranscriptDigestHex: artifact.proofTranscriptDigestHex,
            proofEnvelopeBase64: artifact.proofEnvelopeBase64
        )
        let auditSink = ProductAuditSink()
        let verifier = SuperNeoNumiSealProductVerifier(
            expectedContextStore: ProductExpectedContextStore(expectedContext: try strictExpectedContext(for: artifact)),
            authorizer: ProductAuthorizer(),
            provenanceVerifier: ProductProvenanceVerifier(),
            replayLedger: ProductReplayLedger(),
            auditSink: auditSink
        )

        XCTAssertThrowsProductIntegrationError(
            try verifier.verify(
                SuperNeoNumiSealProductVerificationRequest(
                    callerID: "tenant-a",
                    expectedContextID: "ctx-numiseal-single",
                    artifact: mismatchedArtifact,
                    artifactBytes: [UInt8](data)
                )
            ),
            containing: "artifact bytes do not match request artifact"
        )
        XCTAssertEqual(auditSink.events.last?.decision, .rejected)
        XCTAssertNil(auditSink.events.last?.proofEnvelopeDigest)
        XCTAssertNil(auditSink.events.last?.provenanceDigest)
    }

    func testNumiSealProductVerifierFailsClosedOnAuthorizationRejection() throws {
        let data = try loadNumiSealArtifactData(named: "numiseal-terminal-single-aggregate-v1.json")
        let artifact = try JSONDecoder().decode(NumiSealArtifact.self, from: data)
        let auditSink = ProductAuditSink()
        let verifier = SuperNeoNumiSealProductVerifier(
            expectedContextStore: ProductExpectedContextStore(expectedContext: try strictExpectedContext(for: artifact)),
            authorizer: ProductAuthorizer(error: .unauthorized("caller is not authorized for expected context")),
            provenanceVerifier: ProductProvenanceVerifier(),
            replayLedger: ProductReplayLedger(),
            auditSink: auditSink
        )

        XCTAssertThrowsProductIntegrationError(
            try verifier.verify(
                SuperNeoNumiSealProductVerificationRequest(
                    callerID: "tenant-a",
                    expectedContextID: "ctx-numiseal-single",
                    artifact: artifact,
                    artifactBytes: [UInt8](data)
                )
            ),
            containing: "not authorized"
        )
        XCTAssertEqual(auditSink.events.count, 1)
        XCTAssertEqual(auditSink.events.last?.decision, .rejected)
        XCTAssertNil(auditSink.events.last?.provenanceDigest)
    }

    func testNumiSealProductVerifierRejectsAcceptedReplayBeforeAlgebraicVerification() throws {
        let data = try loadNumiSealArtifactData(named: "numiseal-terminal-single-aggregate-v1.json")
        let artifact = try JSONDecoder().decode(NumiSealArtifact.self, from: data)
        let expectedContext = try strictExpectedContext(for: artifact)
        let replayLedger = ProductReplayLedger()
        let auditSink = ProductAuditSink()
        let verifier = SuperNeoNumiSealProductVerifier(
            expectedContextStore: ProductExpectedContextStore(expectedContext: expectedContext),
            authorizer: ProductAuthorizer(),
            provenanceVerifier: ProductProvenanceVerifier(),
            replayLedger: replayLedger,
            auditSink: auditSink
        )
        let request = SuperNeoNumiSealProductVerificationRequest(
            callerID: "tenant-a",
            expectedContextID: "ctx-numiseal-single",
            artifact: artifact,
            artifactBytes: [UInt8](data)
        )

        _ = try verifier.verify(request)
        XCTAssertThrowsProductIntegrationError(
            try verifier.verify(request),
            containing: "already been accepted"
        )
        XCTAssertEqual(auditSink.events.map(\.decision), [.accepted, .rejected])
        XCTAssertEqual(replayLedger.recordedCount, 1)
    }

    func testNumiSealProductVerifierFailsClosedOnProductByteLimit() throws {
        let data = try loadNumiSealArtifactData(named: "numiseal-terminal-single-aggregate-v1.json")
        let artifact = try JSONDecoder().decode(NumiSealArtifact.self, from: data)
        let auditSink = ProductAuditSink()
        let verifier = SuperNeoNumiSealProductVerifier(
            expectedContextStore: ProductExpectedContextStore(expectedContext: try strictExpectedContext(for: artifact)),
            authorizer: ProductAuthorizer(),
            provenanceVerifier: ProductProvenanceVerifier(),
            replayLedger: ProductReplayLedger(),
            auditSink: auditSink
        )

        XCTAssertThrowsProductIntegrationError(
            try verifier.verify(
                SuperNeoNumiSealProductVerificationRequest(
                    callerID: "tenant-a",
                    expectedContextID: "ctx-numiseal-single",
                    artifact: artifact,
                    artifactBytes: [UInt8](data),
                    maximumArtifactByteCount: data.count - 1
                )
            ),
            containing: "exceeds product maximum"
        )
        XCTAssertEqual(auditSink.events.last?.decision, .rejected)
        XCTAssertNil(auditSink.events.last?.proofEnvelopeDigest)
    }

    func testLocalProductControlsVerifySignedContextProvenanceReplayAndAudit() throws {
        let directory = try temporaryDirectory()
        let signingKey = Curve25519.Signing.PrivateKey()
        let publicKeyDigest = Digest256.hash([UInt8](signingKey.publicKey.rawRepresentation)).hexString
        let releaseBuildDigest = Digest256.hash("release-build").hexString
        let artifactDigest = Digest256.hash("artifact").hexString
        let proofEnvelopeDigest = Digest256.hash("proof-envelope").hexString
        let statementDigest = Digest256.hash("statement").hexString
        let shapeDigest = Digest256.hash("shape").hexString
        let verifierKeyDigest = Digest256.hash("verifier-key").hexString
        let transcriptDomainDigest = Digest256.hash("transcript-domain").hexString
        let contextPayload = SuperNeoTrustedContextPayload(
            contextID: "ctx-terminal",
            issuer: "SuperNeo Release",
            validFromUTC: "2026-01-01T00:00:00Z",
            validUntilUTC: "2027-01-01T00:00:00Z",
            expectedVerifierKeyDigestHex: verifierKeyDigest,
            expectedShapeDigestHex: shapeDigest,
            expectedStatementDigestHex: statementDigest,
            expectedTranscriptDomainDigestHex: transcriptDomainDigest,
            acceptedProofKinds: [.terminal, .compressedTerminal],
            maximumArtifactByteCount: 1_000_000,
            maximumProofEnvelopeByteCount: 100_000,
            allowedWorkloads: ["one-hot-vector-v1"],
            publicInputs: [1],
            releaseBuildDigestHex: releaseBuildDigest,
            keyRotation: SuperNeoTrustedContextKeyRotation(
                currentIssuerKeyDigestHex: publicKeyDigest,
                nextIssuerKeyDigestHex: Digest256.hash("next-issuer-key").hexString
            ),
            revocation: SuperNeoTrustedContextRevocation(issuedAtUTC: "2026-04-16T00:00:00Z")
        )
        let contextPack = SuperNeoSignedTrustedContextPack(
            payload: contextPayload,
            signature: try productSignature(for: contextPayload, signingKey: signingKey)
        )
        let contextURL = directory.appendingPathComponent("context.json")
        try writeSecureJSON(contextPack, to: contextURL)

        let provenancePayload = SuperNeoArtifactProvenancePayload(
            issuer: "SuperNeo Release",
            contextID: "ctx-terminal",
            artifactDigestHex: artifactDigest,
            proofEnvelopeDigestHex: proofEnvelopeDigest,
            statementDigestHex: statementDigest,
            releaseBuildDigestHex: releaseBuildDigest,
            issuedAtUTC: "2026-04-16T00:00:00Z"
        )
        let provenanceManifest = SuperNeoSignedArtifactProvenanceManifest(
            payload: provenancePayload,
            signature: try productSignature(for: provenancePayload, signingKey: signingKey)
        )
        let provenanceURL = directory.appendingPathComponent("provenance.json")
        try writeSecureJSON(provenanceManifest, to: provenanceURL)

        let revocationFeedPayload = SuperNeoRevocationFeedPayload(
            feedID: "ctx-terminal-revocations",
            issuer: "SuperNeo Release",
            contextID: "ctx-terminal",
            releaseBuildDigestHex: releaseBuildDigest,
            sequence: 1,
            issuedAtUTC: "2026-04-16T00:00:00Z",
            validUntilUTC: "2027-01-01T00:00:00Z"
        )
        let revocationFeed = SuperNeoSignedRevocationFeed(
            payload: revocationFeedPayload,
            signature: try productSignature(for: revocationFeedPayload, signingKey: signingKey)
        )
        let revocationFeedURL = directory.appendingPathComponent("revocations.json")
        try writeSecureJSON(revocationFeed, to: revocationFeedURL)

        let databaseURL = directory.appendingPathComponent("replay.sqlite")
        let auditURL = directory.appendingPathComponent("audit.jsonl")
        let profile = SuperNeoLocalOperatorProfile(
            callerID: "local-operator",
            contextPackPath: contextURL.path,
            artifactProvenancePath: provenanceURL.path,
            revocationFeedPath: revocationFeedURL.path,
            replayDatabasePath: databaseURL.path,
            auditLogPath: auditURL.path,
            trustedContextIssuerKeyDigestsHex: [publicKeyDigest],
            trustedProvenanceIssuerKeyDigestsHex: [publicKeyDigest],
            trustedSideChannelIssuerKeyDigestsHex: [publicKeyDigest],
            trustedRevocationIssuerKeyDigestsHex: [publicKeyDigest],
            releaseBuildDigestHex: releaseBuildDigest
        )
        let profileURL = directory.appendingPathComponent("profile.json")
        try writeSecureJSON(profile, to: profileURL)
        try SuperNeoSQLiteReplayLedger.bootstrap(databaseURL: databaseURL)
        try SuperNeoJSONLAuditLog.bootstrap(url: auditURL)

        let loadedProfile = try SuperNeoLocalOperatorProfile.load(from: profileURL)
        let verifiedContext = try SuperNeoSignedTrustedContextPack.loadVerified(
            from: contextURL,
            trustedIssuerKeyDigestsHex: try loadedProfile.trustedContextIssuerKeyDigestSet(),
            now: try SuperNeoProductTime.parseUTC("2026-04-16T00:00:00Z", name: "test now")
        )
        XCTAssertEqual(verifiedContext.payload.contextID, "ctx-terminal")

        let verifiedProvenance = try SuperNeoSignedArtifactProvenanceManifest.loadVerified(
            from: provenanceURL,
            trustedIssuerKeyDigestsHex: try loadedProfile.trustedProvenanceIssuerKeyDigestSet()
        )
        try verifiedProvenance.validateBinding(
            artifactDigest: try Digest256(hexDigest: artifactDigest),
            proofEnvelopeDigest: try Digest256(hexDigest: proofEnvelopeDigest),
            contextID: contextPayload.contextID,
            statementDigest: try Digest256(hexDigest: statementDigest),
            releaseBuildDigest: try Digest256(hexDigest: releaseBuildDigest)
        )
        let verifiedRevocationFeed = try SuperNeoSignedRevocationFeed.loadVerified(
            from: revocationFeedURL,
            trustedIssuerKeyDigestsHex: try loadedProfile.trustedRevocationIssuerKeyDigestSet(),
            context: verifiedContext.payload,
            now: try SuperNeoProductTime.parseUTC("2026-04-16T00:00:00Z", name: "test now")
        )
        XCTAssertEqual(verifiedRevocationFeed.payload.feedID, "ctx-terminal-revocations")
        XCTAssertEqual(verifiedRevocationFeed.payload.sequence, 1)
        let effectiveRevocation = verifiedContext.payload.revocation.merged(with: verifiedRevocationFeed.payload.revocation)
        try effectiveRevocation.requireNotRevoked(
            contextID: contextPayload.contextID,
            artifactDigest: try Digest256(hexDigest: artifactDigest),
            proofEnvelopeDigest: try Digest256(hexDigest: proofEnvelopeDigest),
            provenanceDigest: verifiedProvenance.provenanceDigest
        )

        let identity = SuperNeoProductProofIdentity(
            expectedContextID: contextPayload.contextID,
            statementDigest: try Digest256(hexDigest: statementDigest),
            proofEnvelopeDigest: try Digest256(hexDigest: proofEnvelopeDigest),
            artifactDigest: try Digest256(hexDigest: artifactDigest),
            provenanceDigest: verifiedProvenance.provenanceDigest
        )
        let ledger = try SuperNeoSQLiteReplayLedger(databaseURL: databaseURL)
        XCTAssertFalse(try ledger.hasAccepted(identity))
        try ledger.recordAccepted(identity)
        XCTAssertTrue(try ledger.hasAccepted(identity))
        XCTAssertThrowsProductIntegrationError(
            try ledger.recordAccepted(identity),
            containing: "already been accepted"
        )

        let auditLog = try SuperNeoJSONLAuditLog(url: auditURL)
        try auditLog.append(
            SuperNeoAuditLogEvent(
                decision: "accepted",
                artifactDigestHex: artifactDigest,
                proofEnvelopeDigestHex: proofEnvelopeDigest,
                provenanceDigestHex: verifiedProvenance.provenanceDigest.hexString,
                revocationFeedDigestHex: verifiedRevocationFeed.feedDigest.hexString,
                proofKind: SuperNeoProductProofKind.terminal.rawValue,
                contextID: contextPayload.contextID,
                statementDigestHex: statementDigest,
                toolVersion: "test-tool",
                releaseBuildDigestHex: releaseBuildDigest
            )
        )
        let auditStatus = try auditLog.validateChain()
        XCTAssertTrue(auditStatus.isValid)
        XCTAssertEqual(auditStatus.recordCount, 1)
        XCTAssertEqual(auditStatus.lastSequence, 1)
        let auditSnapshot = try auditLog.exportSnapshot(exportedAtUTC: "2026-04-16T00:00:00Z")
        XCTAssertEqual(auditSnapshot.formatVersion, 1)
        XCTAssertEqual(auditSnapshot.exportedAtUTC, "2026-04-16T00:00:00Z")
        XCTAssertEqual(auditSnapshot.chainStatus, auditStatus)
        XCTAssertEqual(auditSnapshot.records.count, 1)
        XCTAssertEqual(auditSnapshot.records.first?.payload.sequence, 1)
        XCTAssertEqual(auditSnapshot.records.first?.payload.event.contextID, contextPayload.contextID)
        XCTAssertEqual(
            auditSnapshot.records.first?.payload.event.revocationFeedDigestHex,
            verifiedRevocationFeed.feedDigest.hexString
        )
        XCTAssertEqual(try auditLog.records().map(\.payload.sequence), [1])

        let operationsStatus = try SuperNeoProductOperationsStatus.make(
            profile: loadedProfile,
            context: verifiedContext,
            revocationFeed: verifiedRevocationFeed,
            effectiveRevocation: effectiveRevocation,
            sideChannelCertificate: nil,
            acceptedReplayCount: try ledger.acceptedReplayCount(),
            auditStatus: try auditLog.statusSnapshot(),
            now: try SuperNeoProductTime.parseUTC("2026-04-16T00:00:00Z", name: "test now")
        )
        XCTAssertEqual(operationsStatus.formatVersion, 2)
        XCTAssertEqual(operationsStatus.readiness, .ready)
        XCTAssertEqual(operationsStatus.contextID, contextPayload.contextID)
        XCTAssertEqual(operationsStatus.contextPayloadDigestHex, verifiedContext.payloadDigest.hexString)
        XCTAssertEqual(operationsStatus.revocationFeedID, "ctx-terminal-revocations")
        XCTAssertEqual(operationsStatus.revocationFeedSequence, 1)
        XCTAssertEqual(operationsStatus.revocationFeedDigestHex, verifiedRevocationFeed.feedDigest.hexString)
        XCTAssertEqual(operationsStatus.acceptedReplayCount, 1)
        XCTAssertEqual(operationsStatus.auditLogRecordCount, 1)
        XCTAssertEqual(operationsStatus.keyRotationStatus, "next-key-staged")
        XCTAssertEqual(operationsStatus.revocationStatus, "signed-feed-current-empty")
        XCTAssertEqual(operationsStatus.sideChannelCertificateStatus, "not-required")
        XCTAssertTrue(operationsStatus.checks.allSatisfy { $0.status == .ok })
        XCTAssertTrue(operationsStatus.retryPolicy.contains("signed context"))

        let revokedFeedPayload = SuperNeoRevocationFeedPayload(
            feedID: "ctx-terminal-revocations",
            issuer: "SuperNeo Release",
            contextID: "ctx-terminal",
            releaseBuildDigestHex: releaseBuildDigest,
            sequence: 2,
            issuedAtUTC: "2026-04-17T00:00:00Z",
            validUntilUTC: "2027-01-01T00:00:00Z",
            revokedArtifactDigestHex: [artifactDigest.uppercased()]
        )
        let revokedEffective = verifiedContext.payload.revocation.merged(with: revokedFeedPayload.revocation)
        XCTAssertThrowsProductIntegrationError(
            try revokedEffective.requireNotRevoked(
                contextID: contextPayload.contextID,
                artifactDigest: try Digest256(hexDigest: artifactDigest),
                proofEnvelopeDigest: try Digest256(hexDigest: proofEnvelopeDigest),
                provenanceDigest: verifiedProvenance.provenanceDigest
            ),
            containing: "artifact digest has been revoked"
        )
    }

    func testProductOperationsStatusAllowsNumiSealZKWithoutCertificateByDefault() throws {
        let issuerDigest = Digest256.hash("numiseal-zk-ops-issuer")
        let releaseBuildDigest = Digest256.hash("numiseal-zk-ops-release")
        let now = try SuperNeoProductTime.parseUTC("2026-04-16T00:00:00Z", name: "test now")
        let zkPolicy = SuperNeoTrustedNumiSealZKContext(
            acceptedMetalModes: ["cpu-reference"],
            acceptedExecutionPolicies: [NumiSealProvingExecutionPolicy.zkHighAssuranceCPU.rawValue],
            allowedLeakageDigestsHex: [Digest256.hash("numiseal-zk-ops-leakage").hexString]
        )
        let payload = SuperNeoTrustedContextPayload(
            contextID: "ctx-numiseal-zk-ops",
            issuer: "SuperNeo Release",
            validFromUTC: "2026-01-01T00:00:00Z",
            validUntilUTC: "2027-01-01T00:00:00Z",
            expectedVerifierKeyDigestHex: Digest256.hash("verifier").hexString,
            expectedShapeDigestHex: Digest256.hash("shape").hexString,
            expectedStatementDigestHex: Digest256.hash("statement").hexString,
            expectedTranscriptDomainDigestHex: Digest256.hash("domain").hexString,
            acceptedProofKinds: [.numiSealZK],
            maximumArtifactByteCount: 1_000_000,
            maximumProofEnvelopeByteCount: 1_000_000,
            allowedWorkloads: ["one-hot-vector-v1"],
            releaseBuildDigestHex: releaseBuildDigest.hexString,
            numiSeal: SuperNeoTrustedNumiSealContext(
                publicStatementDigestHex: Digest256.hash("public-statement").hexString,
                obligationRootHex: Digest256.hash("obligation-root").hexString,
                laneSummaryRootHex: Digest256.hash("lane-summary-root").hexString,
                aggregateDigestsHex: [Digest256.hash("aggregate").hexString],
                componentDigestRootHex: Digest256.hash("component-root").hexString,
                proofTranscriptDigestHex: Digest256.hash("proof-transcript").hexString
            ),
            numiSealZK: zkPolicy,
            keyRotation: SuperNeoTrustedContextKeyRotation(
                currentIssuerKeyDigestHex: issuerDigest.hexString,
                nextIssuerKeyDigestHex: Digest256.hash("next-issuer").hexString
            )
        )
        let context = SuperNeoVerifiedTrustedContextPack(
            payload: payload,
            payloadDigest: Digest256.hash([UInt8](try SuperNeoCanonicalJSON.encode(payload))),
            issuerKeyDigest: issuerDigest
        )
        let revocationPayload = SuperNeoRevocationFeedPayload(
            feedID: "ctx-numiseal-zk-ops-revocations",
            issuer: "SuperNeo Release",
            contextID: payload.contextID,
            releaseBuildDigestHex: releaseBuildDigest.hexString,
            sequence: 1,
            issuedAtUTC: "2026-04-16T00:00:00Z",
            validUntilUTC: "2027-01-01T00:00:00Z"
        )
        let revocationFeed = SuperNeoVerifiedRevocationFeed(
            payload: revocationPayload,
            feedDigest: Digest256.hash([UInt8](try SuperNeoCanonicalJSON.encode(revocationPayload))),
            issuerKeyDigest: issuerDigest
        )
        let profile = SuperNeoLocalOperatorProfile(
            callerID: "tenant-a",
            artifactProvenancePath: "provenance.json",
            revocationFeedPath: "revocations.json",
            replayDatabasePath: "replay.sqlite",
            auditLogPath: "audit.jsonl",
            trustedContextIssuerKeyDigestsHex: [issuerDigest.hexString],
            trustedProvenanceIssuerKeyDigestsHex: [issuerDigest.hexString],
            trustedSideChannelIssuerKeyDigestsHex: [issuerDigest.hexString],
            trustedRevocationIssuerKeyDigestsHex: [issuerDigest.hexString],
            releaseBuildDigestHex: releaseBuildDigest.hexString
        )
        let status = try SuperNeoProductOperationsStatus.make(
            profile: profile,
            context: context,
            revocationFeed: revocationFeed,
            effectiveRevocation: revocationPayload.revocation,
            sideChannelCertificate: nil,
            acceptedReplayCount: 0,
            auditStatus: SuperNeoAuditLogStatusSnapshot(
                auditLogDigestHex: Digest256.hash("empty-audit").hexString,
                chainStatus: SuperNeoAuditLogChainStatus(
                    isValid: true,
                    recordCount: 0,
                    lastSequence: 0,
                    lastRecordDigestHex: SuperNeoJSONLAuditLog.genesisDigestHex
                )
            ),
            now: now
        )

        XCTAssertEqual(status.readiness, SuperNeoProductOperationsReadiness.ready)
        XCTAssertEqual(status.sideChannelCertificateStatus, "not-attached-optional")
        XCTAssertTrue(status.checks.contains { check in
            check.id == "side-channel-certificate" && check.status == SuperNeoProductOperationsCheckStatus.ok
        })

        let requiredZKPolicy = SuperNeoTrustedNumiSealZKContext(
            acceptedMetalModes: ["cpu-reference"],
            acceptedExecutionPolicies: [NumiSealProvingExecutionPolicy.zkHighAssuranceCPU.rawValue],
            allowedLeakageDigestsHex: [Digest256.hash("numiseal-zk-ops-leakage").hexString],
            minimumSideChannelCertificationLevel: .constantTraceReviewed
        )
        let requiredPayload = SuperNeoTrustedContextPayload(
            contextID: "ctx-numiseal-zk-ops-required",
            issuer: "SuperNeo Release",
            validFromUTC: "2026-01-01T00:00:00Z",
            validUntilUTC: "2027-01-01T00:00:00Z",
            expectedVerifierKeyDigestHex: Digest256.hash("verifier").hexString,
            expectedShapeDigestHex: Digest256.hash("shape").hexString,
            expectedStatementDigestHex: Digest256.hash("statement").hexString,
            expectedTranscriptDomainDigestHex: Digest256.hash("domain").hexString,
            acceptedProofKinds: [.numiSealZK],
            maximumArtifactByteCount: 1_000_000,
            maximumProofEnvelopeByteCount: 1_000_000,
            allowedWorkloads: ["one-hot-vector-v1"],
            releaseBuildDigestHex: releaseBuildDigest.hexString,
            numiSeal: SuperNeoTrustedNumiSealContext(
                publicStatementDigestHex: Digest256.hash("public-statement").hexString,
                obligationRootHex: Digest256.hash("obligation-root").hexString,
                laneSummaryRootHex: Digest256.hash("lane-summary-root").hexString,
                aggregateDigestsHex: [Digest256.hash("aggregate").hexString],
                componentDigestRootHex: Digest256.hash("component-root").hexString,
                proofTranscriptDigestHex: Digest256.hash("proof-transcript").hexString
            ),
            numiSealZK: requiredZKPolicy,
            keyRotation: SuperNeoTrustedContextKeyRotation(
                currentIssuerKeyDigestHex: issuerDigest.hexString,
                nextIssuerKeyDigestHex: Digest256.hash("next-issuer").hexString
            )
        )
        let requiredContext = SuperNeoVerifiedTrustedContextPack(
            payload: requiredPayload,
            payloadDigest: Digest256.hash([UInt8](try SuperNeoCanonicalJSON.encode(requiredPayload))),
            issuerKeyDigest: issuerDigest
        )
        let requiredRevocationPayload = SuperNeoRevocationFeedPayload(
            feedID: "ctx-numiseal-zk-ops-required-revocations",
            issuer: "SuperNeo Release",
            contextID: requiredPayload.contextID,
            releaseBuildDigestHex: releaseBuildDigest.hexString,
            sequence: 1,
            issuedAtUTC: "2026-04-16T00:00:00Z",
            validUntilUTC: "2027-01-01T00:00:00Z"
        )
        let requiredRevocationFeed = SuperNeoVerifiedRevocationFeed(
            payload: requiredRevocationPayload,
            feedDigest: Digest256.hash([UInt8](try SuperNeoCanonicalJSON.encode(requiredRevocationPayload))),
            issuerKeyDigest: issuerDigest
        )
        let requiredStatus = try SuperNeoProductOperationsStatus.make(
            profile: profile,
            context: requiredContext,
            revocationFeed: requiredRevocationFeed,
            effectiveRevocation: requiredRevocationPayload.revocation,
            sideChannelCertificate: nil,
            acceptedReplayCount: 0,
            auditStatus: SuperNeoAuditLogStatusSnapshot(
                auditLogDigestHex: Digest256.hash("empty-audit").hexString,
                chainStatus: SuperNeoAuditLogChainStatus(
                    isValid: true,
                    recordCount: 0,
                    lastSequence: 0,
                    lastRecordDigestHex: SuperNeoJSONLAuditLog.genesisDigestHex
                )
            ),
            now: now
        )
        XCTAssertEqual(requiredStatus.readiness, SuperNeoProductOperationsReadiness.blocked)
        XCTAssertEqual(requiredStatus.sideChannelCertificateStatus, "missing-required")
        XCTAssertTrue(requiredStatus.checks.contains { check in
            check.id == "side-channel-certificate" && check.status == SuperNeoProductOperationsCheckStatus.blocked
        })
    }

    func testLocalProductReplayIdentityBindsRecursiveCarryReplayMetadata() throws {
        let contextID = "ctx-recursive-carry"
        let statementDigest = Digest256.hash("recursive-statement")
        let proofEnvelopeDigest = Digest256.hash("recursive-proof")
        let artifactDigest = Digest256.hash("recursive-artifact")
        let provenanceDigest = Digest256.hash("recursive-provenance")
        let binding = try NumiSealProductRecursiveCarryReplayBinding(
            parentArtifactDigest: Digest256.hash("recursive-parent-artifact"),
            parentSourceFoldEnvelopeDigest: Digest256.hash("recursive-parent-source-fold"),
            parentProductProofEnvelopeDigest: Digest256.hash("recursive-parent-product-proof"),
            parentProducerProofEnvelopeDigest: Digest256.hash("recursive-parent-producer-proof"),
            parentPublicStatementDigest: Digest256.hash("recursive-parent-public-statement"),
            consumerSessionDigest: Digest256.hash("recursive-child-session"),
            nextRecursionLevel: 1,
            claimCount: 2,
            contextRoot: Digest256.hash("recursive-context-root"),
            replayRoot: Digest256.hash("recursive-replay-root")
        )

        let nonRecursiveIdentity = SuperNeoProductProofIdentity(
            expectedContextID: contextID,
            statementDigest: statementDigest,
            proofEnvelopeDigest: proofEnvelopeDigest,
            artifactDigest: artifactDigest,
            provenanceDigest: provenanceDigest
        )
        let recursiveIdentity = SuperNeoProductProofIdentity(
            expectedContextID: contextID,
            statementDigest: statementDigest,
            proofEnvelopeDigest: proofEnvelopeDigest,
            artifactDigest: artifactDigest,
            provenanceDigest: provenanceDigest,
            recursiveCarryReplayBindingDigest: binding.bindingDigest
        )
        let swappedRecursiveIdentity = SuperNeoProductProofIdentity(
            expectedContextID: contextID,
            statementDigest: statementDigest,
            proofEnvelopeDigest: proofEnvelopeDigest,
            artifactDigest: artifactDigest,
            provenanceDigest: provenanceDigest,
            recursiveCarryReplayBindingDigest: Digest256.hash("different-recursive-carry-binding")
        )
        let duplicateCarryConsumptionIdentity = SuperNeoProductProofIdentity(
            expectedContextID: contextID,
            statementDigest: statementDigest,
            proofEnvelopeDigest: Digest256.hash("recursive-proof-2"),
            artifactDigest: Digest256.hash("recursive-artifact-2"),
            provenanceDigest: Digest256.hash("recursive-provenance-2"),
            recursiveCarryReplayBindingDigest: binding.bindingDigest
        )

        XCTAssertNotEqual(nonRecursiveIdentity.localReplayDigest, recursiveIdentity.localReplayDigest)
        XCTAssertNotEqual(recursiveIdentity.localReplayDigest, swappedRecursiveIdentity.localReplayDigest)
        XCTAssertNotEqual(recursiveIdentity.localReplayDigest, duplicateCarryConsumptionIdentity.localReplayDigest)
        XCTAssertEqual(recursiveIdentity.recursiveCarryReplayBindingDigestColumn, binding.bindingDigest.hexString)

        let directory = try temporaryDirectory()
        let databaseURL = directory.appendingPathComponent("recursive-replay.sqlite")
        try SuperNeoSQLiteReplayLedger.bootstrap(databaseURL: databaseURL)
        let ledger = try SuperNeoSQLiteReplayLedger(databaseURL: databaseURL)
        try ledger.recordAccepted(recursiveIdentity)
        XCTAssertTrue(try ledger.hasAccepted(recursiveIdentity))
        XCTAssertThrowsProductIntegrationError(
            try ledger.recordAccepted(duplicateCarryConsumptionIdentity),
            containing: "already been accepted"
        )

        let event = SuperNeoAuditLogEvent(
            decision: "accepted",
            artifactDigestHex: artifactDigest.hexString,
            proofEnvelopeDigestHex: proofEnvelopeDigest.hexString,
            provenanceDigestHex: provenanceDigest.hexString,
            proofKind: SuperNeoProductProofKind.numiSealTerminal.rawValue,
            carryMode: "typed-required",
            recursiveCarryReplayBindingDigestHex: binding.bindingDigest.hexString,
            recursiveCarryContextRootHex: binding.contextRoot.hexString,
            recursiveCarryReplayRootHex: binding.replayRoot.hexString,
            recursiveCarryParentArtifactDigestHex: binding.parentArtifactDigest.hexString,
            recursiveCarryParentProofEnvelopeDigestHex: binding.parentProductProofEnvelopeDigest.hexString,
            recursiveCarryParentProvenanceDigestHex: Digest256.hash("recursive-parent-provenance").hexString,
            recursiveCarryParentAcceptedReplayDigestHex: Digest256.hash("recursive-parent-replay").hexString,
            recursiveCarryConsumerSessionDigestHex: binding.consumerSessionDigest.hexString,
            recursiveCarryNextRecursionLevel: binding.nextRecursionLevel,
            recursiveCarryClaimCount: binding.claimCount,
            contextID: contextID,
            statementDigestHex: statementDigest.hexString,
            toolVersion: "test-tool",
            releaseBuildDigestHex: Digest256.hash("recursive-release-build").hexString
        )
        XCTAssertEqual(event.carryMode, "typed-required")
        XCTAssertEqual(event.recursiveCarryReplayBindingDigestHex, binding.bindingDigest.hexString)
        XCTAssertEqual(event.recursiveCarryParentProofEnvelopeDigestHex, binding.parentProductProofEnvelopeDigest.hexString)
        XCTAssertEqual(event.recursiveCarryClaimCount, 2)
    }

    func testNumiSealZKSideChannelCertificateIsOptionalAndBindingChecked() throws {
        let signingKey = Curve25519.Signing.PrivateKey()
        let publicKeyDigest = Digest256.hash([UInt8](signingKey.publicKey.rawRepresentation)).hexString
        let releaseBuildDigest = Digest256.hash("numiseal-zk-release-build").hexString
        let now = try SuperNeoProductTime.parseUTC("2026-04-16T00:00:00Z", name: "test now")

        let workload = try SuperNeoOneHotVectorWorkload(bitCount: 2)
        let prepared = try workload.prepareForFolding(
            bits: [false, true],
            keySeed: Array("numiseal-zk-side-channel-key".utf8)
        )
        let artifact = try NumiSealProductProver().prove(
            NumiSealProvingRequest(
                preparedR1CS: prepared,
                workload: "one-hot-vector-v1",
                bitCount: 2,
                publicInputs: [1],
                keySeedUTF8: "numiseal-zk-side-channel-key",
                workloadParameters: ["selectedCount": "1"],
                laneID: try NumiSealLaneID("product"),
                executionPolicy: .zkHighAssuranceCPU,
                zkMode: NumiSealZK.maskedDigitTensorMode,
                aggregationLimits: try NumiSealAggregationLimits(maximumObligationsPerAggregate: 32)
            )
        )

        let contextWithoutZKPolicy = SuperNeoTrustedContextPayload(
            contextID: "ctx-numiseal-zk",
            issuer: "SuperNeo Release",
            validFromUTC: "2026-01-01T00:00:00Z",
            validUntilUTC: "2027-01-01T00:00:00Z",
            expectedKeySeedUTF8: "numiseal-zk-side-channel-key",
            expectedVerifierKeyDigestHex: artifact.verifierKeyDigestHex,
            expectedShapeDigestHex: artifact.shapeDigestHex,
            expectedStatementDigestHex: artifact.statementDigestHex,
            expectedTranscriptDomainDigestHex: artifact.transcriptDomainHex,
            acceptedProofKinds: [.numiSealZK],
            maximumArtifactByteCount: 1_000_000,
            maximumProofEnvelopeByteCount: 1_000_000,
            allowedWorkloads: [artifact.workload],
            publicInputs: artifact.publicInputs,
            releaseBuildDigestHex: releaseBuildDigest,
            numiSeal: SuperNeoTrustedNumiSealContext(
                publicStatementDigestHex: artifact.publicStatementDigestHex,
                obligationRootHex: artifact.obligationRootHex,
                laneSummaryRootHex: artifact.laneSummaryRootHex,
                aggregateDigestsHex: artifact.aggregateDigestsHex,
                componentDigestRootHex: artifact.componentDigestRootHex,
                proofTranscriptDigestHex: artifact.proofTranscriptDigestHex
            ),
            keyRotation: SuperNeoTrustedContextKeyRotation(currentIssuerKeyDigestHex: publicKeyDigest)
        )
        XCTAssertThrowsProductIntegrationError(
            try contextWithoutZKPolicy.validate(now: now, issuerKeyDigestHex: publicKeyDigest),
            containing: "must include NumiSealZK policy"
        )

        let certificatePayload = NumiSealZKSideChannelCertificationPayload(
            certificateID: "numiseal-zk-side-channel-cpu-reference-v1",
            issuer: "SuperNeo Release",
            contextID: "ctx-numiseal-zk",
            releaseBuildDigestHex: releaseBuildDigest,
            certifiedLevel: .productionSideChannelCleared,
            metalMode: artifact.metalMode,
            executionPolicy: artifact.executionPolicy,
            leakageDigestHex: try artifact.requiredExecutionMetadata("zkLeakageDigest"),
            metalWorkspaceFeatureDigestHex: try artifact.requiredExecutionMetadata("metalWorkspaceFeatureDigest"),
            reviewedKernelNames: [
                "numiseal_apply_mask_kernel",
                "numiseal_dense_fold_kernel",
                "numiseal_eq_weight_kernel",
                "numiseal_sumcheck_accumulate_kernel",
                "numiseal_mask_accumulate_kernel"
            ],
            reviewedStageNames: [
                "mask-expansion",
                "masked-digit-tensor-application",
                "dense-layer-folding",
                "sumcheck-polynomial-accumulation"
            ],
            evidenceDigestsHex: [
                Digest256.hash("constant-trace-review").hexString,
                Digest256.hash("fixed-randomness-proof-equivalence").hexString
            ],
            benchmarkReportDigestHex: Digest256.hash("benchmark-report").hexString,
            issuedAtUTC: "2026-04-16T00:00:00Z",
            validUntilUTC: "2027-01-01T00:00:00Z"
        )
        let signedCertificate = SuperNeoSignedNumiSealZKSideChannelCertificate(
            payload: certificatePayload,
            signature: try productSignature(for: certificatePayload, signingKey: signingKey)
        )
        let verifiedCertificate = try signedCertificate.verified(
            trustedIssuerKeyDigestsHex: [publicKeyDigest],
            now: now
        )
        let zkPolicy = SuperNeoTrustedNumiSealZKContext(
            acceptedMetalModes: [artifact.metalMode],
            acceptedExecutionPolicies: [artifact.executionPolicy],
            allowedLeakageDigestsHex: [try artifact.requiredExecutionMetadata("zkLeakageDigest")]
        )
        let context = SuperNeoTrustedContextPayload(
            contextID: "ctx-numiseal-zk",
            issuer: "SuperNeo Release",
            validFromUTC: "2026-01-01T00:00:00Z",
            validUntilUTC: "2027-01-01T00:00:00Z",
            expectedKeySeedUTF8: "numiseal-zk-side-channel-key",
            expectedVerifierKeyDigestHex: artifact.verifierKeyDigestHex,
            expectedShapeDigestHex: artifact.shapeDigestHex,
            expectedStatementDigestHex: artifact.statementDigestHex,
            expectedTranscriptDomainDigestHex: artifact.transcriptDomainHex,
            acceptedProofKinds: [.numiSealZK],
            maximumArtifactByteCount: 1_000_000,
            maximumProofEnvelopeByteCount: 1_000_000,
            allowedWorkloads: [artifact.workload],
            publicInputs: artifact.publicInputs,
            releaseBuildDigestHex: releaseBuildDigest,
            numiSeal: SuperNeoTrustedNumiSealContext(
                publicStatementDigestHex: artifact.publicStatementDigestHex,
                obligationRootHex: artifact.obligationRootHex,
                laneSummaryRootHex: artifact.laneSummaryRootHex,
                aggregateDigestsHex: artifact.aggregateDigestsHex,
                componentDigestRootHex: artifact.componentDigestRootHex,
                proofTranscriptDigestHex: artifact.proofTranscriptDigestHex
            ),
            numiSealZK: zkPolicy,
            keyRotation: SuperNeoTrustedContextKeyRotation(currentIssuerKeyDigestHex: publicKeyDigest)
        )
        try context.validate(now: now, issuerKeyDigestHex: publicKeyDigest)

        XCTAssertEqual(zkPolicy.minimumSideChannelCertificationLevel, .correctnessOnly)
        try zkPolicy.validate(
            artifact: artifact,
            contextID: context.contextID,
            releaseBuildDigest: try context.releaseBuildDigest,
            certificate: nil
        )
        try zkPolicy.validate(
            artifact: artifact,
            contextID: context.contextID,
            releaseBuildDigest: try context.releaseBuildDigest,
            certificate: verifiedCertificate
        )

        let wrongCertificatePayload = NumiSealZKSideChannelCertificationPayload(
            certificateID: certificatePayload.certificateID,
            issuer: certificatePayload.issuer,
            contextID: certificatePayload.contextID,
            releaseBuildDigestHex: certificatePayload.releaseBuildDigestHex,
            certifiedLevel: certificatePayload.certifiedLevel,
            metalMode: certificatePayload.metalMode,
            executionPolicy: certificatePayload.executionPolicy,
            leakageDigestHex: Digest256.hash("wrong-leakage").hexString,
            metalWorkspaceFeatureDigestHex: certificatePayload.metalWorkspaceFeatureDigestHex,
            reviewedKernelNames: certificatePayload.reviewedKernelNames,
            reviewedStageNames: certificatePayload.reviewedStageNames,
            evidenceDigestsHex: certificatePayload.evidenceDigestsHex,
            benchmarkReportDigestHex: certificatePayload.benchmarkReportDigestHex,
            issuedAtUTC: certificatePayload.issuedAtUTC,
            validUntilUTC: certificatePayload.validUntilUTC
        )
        let wrongCertificate = try SuperNeoSignedNumiSealZKSideChannelCertificate(
            payload: wrongCertificatePayload,
            signature: productSignature(for: wrongCertificatePayload, signingKey: signingKey)
        ).verified(trustedIssuerKeyDigestsHex: [publicKeyDigest], now: now)
        XCTAssertThrowsProductIntegrationError(
            try zkPolicy.validate(
                artifact: artifact,
                contextID: context.contextID,
                releaseBuildDigest: try context.releaseBuildDigest,
                certificate: wrongCertificate
            ),
            containing: "certificate leakage digest mismatch"
        )

        let lowLevelCertificatePayload = NumiSealZKSideChannelCertificationPayload(
            certificateID: certificatePayload.certificateID,
            issuer: certificatePayload.issuer,
            contextID: certificatePayload.contextID,
            releaseBuildDigestHex: certificatePayload.releaseBuildDigestHex,
            certifiedLevel: .constantTraceReviewed,
            metalMode: certificatePayload.metalMode,
            executionPolicy: certificatePayload.executionPolicy,
            leakageDigestHex: certificatePayload.leakageDigestHex,
            metalWorkspaceFeatureDigestHex: certificatePayload.metalWorkspaceFeatureDigestHex,
            reviewedKernelNames: certificatePayload.reviewedKernelNames,
            reviewedStageNames: certificatePayload.reviewedStageNames,
            evidenceDigestsHex: certificatePayload.evidenceDigestsHex,
            benchmarkReportDigestHex: certificatePayload.benchmarkReportDigestHex,
            issuedAtUTC: certificatePayload.issuedAtUTC,
            validUntilUTC: certificatePayload.validUntilUTC
        )
        let lowLevelCertificate = try SuperNeoSignedNumiSealZKSideChannelCertificate(
            payload: lowLevelCertificatePayload,
            signature: productSignature(for: lowLevelCertificatePayload, signingKey: signingKey)
        ).verified(trustedIssuerKeyDigestsHex: [publicKeyDigest], now: now)
        try zkPolicy.validate(
            artifact: artifact,
            contextID: context.contextID,
            releaseBuildDigest: try context.releaseBuildDigest,
            certificate: lowLevelCertificate
        )

        let productionRequiredPolicy = SuperNeoTrustedNumiSealZKContext(
            acceptedMetalModes: [artifact.metalMode],
            acceptedExecutionPolicies: [artifact.executionPolicy],
            allowedLeakageDigestsHex: [try artifact.requiredExecutionMetadata("zkLeakageDigest")],
            minimumSideChannelCertificationLevel: .productionSideChannelCleared
        )
        XCTAssertThrowsProductIntegrationError(
            try productionRequiredPolicy.validate(
                artifact: artifact,
                contextID: context.contextID,
                releaseBuildDigest: try context.releaseBuildDigest,
                certificate: nil
            ),
            containing: "certificate is required"
        )
        XCTAssertThrowsProductIntegrationError(
            try productionRequiredPolicy.validate(
                artifact: artifact,
                contextID: context.contextID,
                releaseBuildDigest: try context.releaseBuildDigest,
                certificate: lowLevelCertificate
            ),
            containing: "certificate level is below"
        )
        try productionRequiredPolicy.validate(
            artifact: artifact,
            contextID: context.contextID,
            releaseBuildDigest: try context.releaseBuildDigest,
            certificate: verifiedCertificate
        )
    }

    func testLocalProductControlsRejectGroupWritableTrustedContextPack() throws {
        let directory = try temporaryDirectory()
        let signingKey = Curve25519.Signing.PrivateKey()
        let publicKeyDigest = Digest256.hash([UInt8](signingKey.publicKey.rawRepresentation)).hexString
        let payload = SuperNeoTrustedContextPayload(
            contextID: "ctx-terminal",
            issuer: "SuperNeo Release",
            validFromUTC: "2026-01-01T00:00:00Z",
            validUntilUTC: "2027-01-01T00:00:00Z",
            expectedVerifierKeyDigestHex: Digest256.hash("verifier").hexString,
            expectedShapeDigestHex: Digest256.hash("shape").hexString,
            expectedStatementDigestHex: Digest256.hash("statement").hexString,
            expectedTranscriptDomainDigestHex: Digest256.hash("domain").hexString,
            acceptedProofKinds: [.terminal],
            maximumArtifactByteCount: 1024,
            allowedWorkloads: ["one-hot-vector-v1"],
            releaseBuildDigestHex: Digest256.hash("release").hexString,
            keyRotation: SuperNeoTrustedContextKeyRotation(currentIssuerKeyDigestHex: publicKeyDigest)
        )
        let pack = SuperNeoSignedTrustedContextPack(
            payload: payload,
            signature: try productSignature(for: payload, signingKey: signingKey)
        )
        let url = directory.appendingPathComponent("context.json")
        try writeSecureJSON(pack, to: url)
        try FileManager.default.setAttributes([.posixPermissions: 0o660], ofItemAtPath: url.path)

        XCTAssertThrowsProductIntegrationError(
            try SuperNeoSignedTrustedContextPack.loadVerified(
                from: url,
                trustedIssuerKeyDigestsHex: [publicKeyDigest],
                now: try SuperNeoProductTime.parseUTC("2026-04-16T00:00:00Z", name: "test now")
            ),
            containing: "must not be group- or world-writable"
        )
    }

    func testLocalProductControlsRejectSymlinkedTrustedContextPack() throws {
        let directory = try temporaryDirectory()
        let signingKey = Curve25519.Signing.PrivateKey()
        let publicKeyDigest = Digest256.hash([UInt8](signingKey.publicKey.rawRepresentation)).hexString
        let payload = SuperNeoTrustedContextPayload(
            contextID: "ctx-terminal",
            issuer: "SuperNeo Release",
            validFromUTC: "2026-01-01T00:00:00Z",
            validUntilUTC: "2027-01-01T00:00:00Z",
            expectedVerifierKeyDigestHex: Digest256.hash("verifier").hexString,
            expectedShapeDigestHex: Digest256.hash("shape").hexString,
            expectedStatementDigestHex: Digest256.hash("statement").hexString,
            expectedTranscriptDomainDigestHex: Digest256.hash("domain").hexString,
            acceptedProofKinds: [.terminal],
            maximumArtifactByteCount: 1024,
            allowedWorkloads: ["one-hot-vector-v1"],
            releaseBuildDigestHex: Digest256.hash("release").hexString,
            keyRotation: SuperNeoTrustedContextKeyRotation(currentIssuerKeyDigestHex: publicKeyDigest)
        )
        let pack = SuperNeoSignedTrustedContextPack(
            payload: payload,
            signature: try productSignature(for: payload, signingKey: signingKey)
        )
        let targetURL = directory.appendingPathComponent("context-target.json")
        let symlinkURL = directory.appendingPathComponent("context-link.json")
        try writeSecureJSON(pack, to: targetURL)
        try FileManager.default.createSymbolicLink(at: symlinkURL, withDestinationURL: targetURL)

        XCTAssertThrowsProductIntegrationError(
            try SuperNeoSignedTrustedContextPack.loadVerified(
                from: symlinkURL,
                trustedIssuerKeyDigestsHex: [publicKeyDigest],
                now: try SuperNeoProductTime.parseUTC("2026-04-16T00:00:00Z", name: "test now")
            ),
            containing: "must not be a symlink"
        )
    }

    func testLocalProductAuditLogDetectsHashChainTampering() throws {
        let directory = try temporaryDirectory()
        let auditURL = directory.appendingPathComponent("audit.jsonl")
        try SuperNeoJSONLAuditLog.bootstrap(url: auditURL)
        let auditLog = try SuperNeoJSONLAuditLog(url: auditURL)
        try auditLog.append(
            SuperNeoAuditLogEvent(
                decision: "accepted",
                artifactDigestHex: Digest256.hash("artifact").hexString,
                proofKind: SuperNeoProductProofKind.terminal.rawValue,
                contextID: "ctx-terminal",
                toolVersion: "test-tool",
                releaseBuildDigestHex: Digest256.hash("release").hexString
            )
        )
        var text = try String(contentsOf: auditURL, encoding: .utf8)
        text = text.replacingOccurrences(of: "\"decision\":\"accepted\"", with: "\"decision\":\"rejected\"")
        try text.write(to: auditURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: auditURL.path)

        let tamperedStatus = try auditLog.validateChain()
        XCTAssertFalse(tamperedStatus.isValid)
        XCTAssertEqual(tamperedStatus.reason, "audit log record digest mismatch")
    }

    private func loadNumiSealArtifact(named name: String) throws -> NumiSealArtifact {
        try JSONDecoder().decode(NumiSealArtifact.self, from: loadNumiSealArtifactData(named: name))
    }

    private func loadNumiSealArtifactData(named name: String) throws -> Data {
        let testFile = URL(fileURLWithPath: #filePath)
        let repositoryRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = repositoryRoot
            .appendingPathComponent("TestVectors")
            .appendingPathComponent(name)
        return try Data(contentsOf: url)
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

    private func XCTAssertThrowsNumiSealArtifactError<T>(
        _ expression: @autoclosure () throws -> T,
        containing expectedMessage: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try expression(), file: file, line: line) { error in
            guard let artifactError = error as? NumiSealArtifactVerificationError else {
                XCTFail("expected NumiSealArtifactVerificationError, got \(error)", file: file, line: line)
                return
            }
            XCTAssertTrue(
                artifactError.description.contains(expectedMessage),
                "expected \(artifactError.description) to contain \(expectedMessage)",
                file: file,
                line: line
            )
        }
    }

    private func XCTAssertThrowsProductIntegrationError<T>(
        _ expression: @autoclosure () throws -> T,
        containing expectedMessage: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try expression(), file: file, line: line) { error in
            guard let productError = error as? SuperNeoProductIntegrationError else {
                XCTFail("expected SuperNeoProductIntegrationError, got \(error)", file: file, line: line)
                return
            }
            XCTAssertTrue(
                productError.description.contains(expectedMessage),
                "expected \(productError.description) to contain \(expectedMessage)",
                file: file,
                line: line
            )
        }
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("superneo-product-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func writeSecureJSON<T: Encodable>(_ value: T, to url: URL) throws {
        let data = try SuperNeoCanonicalJSON.encode(value)
        XCTAssertTrue(FileManager.default.createFile(atPath: url.path, contents: data))
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
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
}

private final class ProductExpectedContextStore: SuperNeoNumiSealExpectedContextStore {
    let expectedContext: NumiSealArtifactExpectedContext?

    init(expectedContext: NumiSealArtifactExpectedContext?) {
        self.expectedContext = expectedContext
    }

    func expectedContext(
        for request: SuperNeoNumiSealProductVerificationRequest
    ) throws -> NumiSealArtifactExpectedContext {
        guard let expectedContext else {
            throw SuperNeoProductIntegrationError.missingExpectedContext(
                "expected context not found: \(request.expectedContextID)"
            )
        }
        return expectedContext
    }
}

private final class ProductAuthorizer: SuperNeoProductAuthorizer {
    let error: SuperNeoProductIntegrationError?

    init(error: SuperNeoProductIntegrationError? = nil) {
        self.error = error
    }

    func authorize(_ request: SuperNeoNumiSealProductVerificationRequest) throws {
        if let error {
            throw error
        }
    }
}

private final class ProductProvenanceVerifier: SuperNeoArtifactProvenanceVerifier {
    let provenanceDigest = Digest256.hash("trusted-numiseal-artifact-provenance")
    let error: SuperNeoProductIntegrationError?

    init(error: SuperNeoProductIntegrationError? = nil) {
        self.error = error
    }

    func verifyProvenance(
        for request: SuperNeoNumiSealProductVerificationRequest,
        artifactDigest: Digest256
    ) throws -> Digest256 {
        if let error {
            throw error
        }
        return provenanceDigest
    }
}

private final class ProductReplayLedger: SuperNeoReplayLedger {
    private var accepted: Set<SuperNeoProductProofIdentity> = []

    var recordedCount: Int { accepted.count }

    func hasAccepted(_ identity: SuperNeoProductProofIdentity) throws -> Bool {
        accepted.contains(identity)
    }

    func recordAccepted(_ identity: SuperNeoProductProofIdentity) throws {
        accepted.insert(identity)
    }
}

private final class ProductAuditSink: SuperNeoVerificationAuditSink {
    private(set) var events: [SuperNeoProductVerificationAuditEvent] = []

    func record(_ event: SuperNeoProductVerificationAuditEvent) {
        events.append(event)
    }
}

final class UsabilitySurfaceTests: SuperNeoTestCase {
    func testPublicNumiSealProductAPIGeneratesOneHotArtifactWithTraceAndQROMEvidence() throws {
        let output = try NumiSealProductAPI.proveOneHotVector(
            bits: [false, true],
            keySeedUTF8: "numiseal-product-public-api-key",
            sourceApplicationPathUTF8: "app://public-api/one-hot",
            executionPolicy: .zkHighAssuranceCPU,
            aggregationLimits: try NumiSealAggregationLimits(maximumObligationsPerAggregate: 32)
        )

        let artifact = output.artifact
        XCTAssertEqual(artifact.workload, "one-hot-vector-v1")
        XCTAssertEqual(artifact.bitCount, 2)
        XCTAssertEqual(artifact.publicInputs, [1])
        XCTAssertEqual(artifact.workloadParameters["selectedCount"], "1")
        XCTAssertEqual(artifact.sourceApplicationPathUTF8, "app://public-api/one-hot")
        XCTAssertEqual(artifact.executionPolicyMetadata["frontendObligationPath"], "r1cs-prepared-to-source-fold-output-claims-v1")
        XCTAssertEqual(
            artifact.executionPolicyMetadata["frontendContextDigest"],
            output.trustedContext.contextDigest.hexString
        )
        XCTAssertEqual(
            artifact.executionPolicyMetadata["swiftTraceExtractorEvidenceDigest"],
            output.traceExtractorEvidence.evidenceDigest.hexString
        )
        XCTAssertEqual(artifact.executionPolicyMetadata["ctcoCompilerFamily"], "ctco")
        XCTAssertEqual(
            artifact.executionPolicyMetadata["ctcoContextBinder384Hex"],
            output.traceExtractorEvidence.ctcoContextBinder.hexString
        )
        XCTAssertEqual(
            artifact.executionPolicyMetadata["ctcoRoot384Hex"],
            output.traceExtractorEvidence.ctcoRoot.hexString
        )
        let sourceCTCO = try ProofEnvelopeCTCOVerifier.verify(envelopeBytes: artifact.sourceFoldEnvelopeBytes())
        let proofCTCO = try ProofEnvelopeCTCOVerifier.verify(envelopeBytes: artifact.proofEnvelopeBytes())
        XCTAssertEqual(
            artifact.executionPolicyMetadata["sourceFoldCTCORoot384Hex"],
            sourceCTCO.root.hexString
        )
        XCTAssertEqual(
            artifact.executionPolicyMetadata["proofEnvelopeCTCORoot384Hex"],
            proofCTCO.root.hexString
        )
        XCTAssertEqual(
            artifact.executionPolicyMetadata["qromEvidenceDigest"],
            output.qromEvidence.evidenceDigest.hexString
        )
        XCTAssertEqual(output.qromEvidence.challengeOracleBits, 256)
        XCTAssertEqual(output.qromEvidence.bindingOracleBits, 384)

        let verified = try NumiSealProductVerifier().verify(
            artifact: artifact,
            sourcePublicInput: output.sourcePublicInput,
            key: output.verifierKey,
            executionPolicy: .highAssurance
        )
        XCTAssertTrue(verified.sourceFoldResult.isReductionAccepted, verified.sourceFoldResult.reason ?? "")
        XCTAssertTrue(verified.numiSealResult.isValid, verified.numiSealResult.reason ?? "")
    }

    func testNumiSealProductConcreteExtractorReplaysAcceptedProductBindings() throws {
        let output = try NumiSealProductAPI.proveOneHotVector(
            bits: [false, true],
            keySeedUTF8: "numiseal-product-concrete-extractor-key",
            sourceApplicationPathUTF8: "app://public-api/extractor",
            executionPolicy: .zkHighAssuranceCPU,
            aggregationLimits: try NumiSealAggregationLimits(maximumObligationsPerAggregate: 32)
        )

        let extraction = try NumiSealProductConcreteExtractor.extract(
            artifact: output.artifact,
            trustedContext: output.trustedContext,
            sourcePublicInput: output.sourcePublicInput,
            key: output.verifierKey,
            executionPolicy: .highAssurance
        )

        XCTAssertEqual(extraction.sourceFoldHeader.kind, .foldReduction)
        XCTAssertEqual(extraction.productProofHeader.kind, .numiSealZK)
        XCTAssertEqual(extraction.sourceFoldOutputClaims.count, output.artifact.sourceFoldOutputClaimCount)
        XCTAssertEqual(
            extraction.sourceFoldOutputClaimDigests.map(\.hexString),
            output.artifact.sourceFoldOutputClaimDigestsHex
        )
        XCTAssertEqual(extraction.obligations.count, output.artifact.sourceFoldOutputClaimCount)
        XCTAssertEqual(extraction.publicStatementDigest.hexString, output.artifact.publicStatementDigestHex)
        XCTAssertEqual(extraction.obligationRoot.hexString, output.artifact.obligationRootHex)
        XCTAssertEqual(extraction.laneSummaryRoot.hexString, output.artifact.laneSummaryRootHex)
        XCTAssertEqual(extraction.aggregateDigests.map(\.hexString), output.artifact.aggregateDigestsHex)
        XCTAssertEqual(extraction.componentDigestRoot.hexString, output.artifact.componentDigestRootHex)
        XCTAssertEqual(extraction.proofTranscriptDigest.hexString, output.artifact.proofTranscriptDigestHex)
        XCTAssertEqual(
            extraction.traceExtractorEvidence.evidenceDigest,
            output.traceExtractorEvidence.evidenceDigest
        )
        XCTAssertEqual(extraction.qromEvidence.evidenceDigest, output.qromEvidence.evidenceDigest)
        XCTAssertEqual(
            output.artifact.executionPolicyMetadata["swiftConcreteExtractorEvidenceDigest"],
            extraction.extractionDigest.hexString
        )

        let wrongContext = try NumiSealProductTrustedContext(
            workload: output.trustedContext.workload,
            bitCount: output.trustedContext.bitCount,
            publicInputs: output.trustedContext.publicInputs,
            workloadParameters: output.trustedContext.workloadParameters,
            sourceApplicationPathUTF8: "app://public-api/wrong-extractor-context"
        )
        XCTAssertThrowsSuperNeoError(
            try NumiSealProductConcreteExtractor.extract(
                artifact: output.artifact,
                trustedContext: wrongContext,
                sourcePublicInput: output.sourcePublicInput,
                key: output.verifierKey,
                executionPolicy: .highAssurance
            ),
            .invalidParameter("NumiSeal product extractor trusted context mismatch")
        )
    }

    func testPublicNumiSealProductAPIGeneratesBinaryAdditionArtifact() throws {
        let output = try NumiSealProductAPI.proveBinaryAddition(
            left: 1,
            right: 2,
            operandBits: 2,
            keySeedUTF8: "numiseal-product-public-binary-api-key",
            executionPolicy: .zkHighAssuranceCPU,
            aggregationLimits: try NumiSealAggregationLimits(maximumObligationsPerAggregate: 32)
        )

        XCTAssertEqual(output.artifact.workload, "binary-addition-v1")
        XCTAssertEqual(output.artifact.bitCount, 2)
        XCTAssertEqual(output.artifact.workloadParameters["leftBitCount"], "2")
        XCTAssertEqual(output.artifact.workloadParameters["publicSum"], "3")
        XCTAssertEqual(
            output.artifact.executionPolicyMetadata["frontendContextDigest"],
            output.trustedContext.contextDigest.hexString
        )

        let verified = try NumiSealProductVerifier().verify(
            artifact: output.artifact,
            sourcePublicInput: output.sourcePublicInput,
            key: output.verifierKey,
            executionPolicy: .highAssurance,
            trustedContext: output.trustedContext
        )
        XCTAssertTrue(verified.sourceFoldResult.isReductionAccepted, verified.sourceFoldResult.reason ?? "")
        XCTAssertTrue(verified.numiSealResult.isValid, verified.numiSealResult.reason ?? "")

        var tamperedPublicInputs = output.artifact
        tamperedPublicInputs.publicInputs = [0]
        XCTAssertThrowsSuperNeoError(
            try NumiSealProductVerifier().verify(
                artifact: tamperedPublicInputs,
                sourcePublicInput: output.sourcePublicInput,
                key: output.verifierKey,
                executionPolicy: .highAssurance
            ),
            .invalidEncoding("NumiSeal product frontend context digest mismatch")
        )

        let wrongContext = try NumiSealProductTrustedContext(
            workload: output.trustedContext.workload,
            bitCount: output.trustedContext.bitCount,
            publicInputs: [0],
            workloadParameters: output.trustedContext.workloadParameters,
            sourceApplicationPathUTF8: output.trustedContext.sourceApplicationPathUTF8
        )
        XCTAssertThrowsSuperNeoError(
            try NumiSealProductVerifier().verify(
                artifact: output.artifact,
                sourcePublicInput: output.sourcePublicInput,
                key: output.verifierKey,
                executionPolicy: .highAssurance,
                trustedContext: wrongContext
            ),
            .invalidParameter("NumiSeal product trusted context mismatch")
        )
    }

    func testNumiSealProductProverEmitsVerifiableV2Artifact() throws {
        let workload = try SuperNeoOneHotVectorWorkload(bitCount: 2)
        let prepared = try workload.prepareForFolding(
            bits: [false, true],
            keySeed: Array("numiseal-product-key".utf8)
        )
        let artifact = try NumiSealProductProver().prove(
            NumiSealProvingRequest(
                preparedR1CS: prepared,
                workload: "one-hot-vector-v1",
                bitCount: 2,
                publicInputs: [1],
                keySeedUTF8: "numiseal-product-key",
                workloadParameters: ["selectedCount": "1"],
                laneID: try NumiSealLaneID("product"),
                executionPolicy: .zkHighAssuranceCPU,
                aggregationLimits: try NumiSealAggregationLimits(maximumObligationsPerAggregate: 32)
            )
        )

        XCTAssertEqual(artifact.artifactVersion, NumiSealProductArtifact.artifactVersion)
        XCTAssertEqual(artifact.proofKind, NumiSealProductArtifact.zkProofKind)
        XCTAssertEqual(artifact.sealMode, NumiSealZK.sealMode)
        XCTAssertEqual(artifact.carryMode, "none")
        XCTAssertEqual(artifact.zkMode, NumiSealZK.maskedDigitTensorMode)
        XCTAssertEqual(artifact.sourceFoldOutputClaimCount, 14)
        XCTAssertEqual(artifact.aggregateDigestsHex.count, 1)
        XCTAssertEqual(artifact.executionPolicyMetadata["terminalCarryPolicy"], "none")
        XCTAssertEqual(artifact.executionPolicyMetadata["ctcoCompilerFamily"], "ctco")
        XCTAssertEqual(artifact.executionPolicyMetadata["qromBindingOracleBits"], "384")
        XCTAssertNotNil(artifact.executionPolicyMetadata["sourceFoldCTCORoot384Hex"])
        XCTAssertNotNil(artifact.executionPolicyMetadata["sourceFoldCTCOChallengeTapeSeedHex"])
        XCTAssertNotNil(artifact.executionPolicyMetadata["proofEnvelopeCTCORoot384Hex"])
        XCTAssertNotNil(artifact.executionPolicyMetadata["proofEnvelopeCTCOChallengeTapeSeedHex"])
        XCTAssertNotNil(artifact.executionPolicyMetadata["swiftTraceExtractorEvidenceDigest"])
        XCTAssertLessThanOrEqual(
            artifact.sourceFoldOutputClaimCount,
            NumiSealProductTheoremLimits.maximumSourceFoldOutputClaimCount
        )
        XCTAssertLessThanOrEqual(
            artifact.maximumObligationsPerAggregate,
            NumiSealProductTheoremLimits.maximumObligationsPerAggregate
        )
        XCTAssertLessThanOrEqual(artifact.maximumLaneCount, NumiSealProductTheoremLimits.maximumLaneCount)
        XCTAssertLessThanOrEqual(
            artifact.maximumAggregatesPerLane,
            NumiSealProductTheoremLimits.maximumAggregatesPerLane
        )

        let result = try NumiSealProductVerifier().verify(
            artifact: artifact,
            sourcePublicInput: prepared.publicFoldInput,
            key: prepared.key,
            executionPolicy: .highAssurance
        )
        XCTAssertTrue(result.sourceFoldResult.isReductionAccepted, result.sourceFoldResult.reason ?? "")
        XCTAssertTrue(result.numiSealResult.isValid, result.numiSealResult.reason ?? "")

        var tampered = artifact
        tampered.sourceFoldEnvelopeDigestHex = String(repeating: "0", count: 64)
        XCTAssertThrowsSuperNeoError(
            try NumiSealProductVerifier().verify(
                artifact: tampered,
                sourcePublicInput: prepared.publicFoldInput,
                key: prepared.key,
                executionPolicy: .highAssurance
            ),
            .invalidEncoding("NumiSeal product CTCO root mismatch")
        )

        var tamperedRoot = artifact
        tamperedRoot.executionPolicyMetadata["ctcoRoot384Hex"] = String(repeating: "0", count: 96)
        XCTAssertThrowsSuperNeoError(
            try NumiSealProductVerifier().verify(
                artifact: tamperedRoot,
                sourcePublicInput: prepared.publicFoldInput,
                key: prepared.key,
                executionPolicy: .highAssurance
            ),
            .invalidEncoding("NumiSeal product CTCO root mismatch")
        )

        var tamperedSourceRoot = artifact
        tamperedSourceRoot.executionPolicyMetadata["sourceFoldCTCORoot384Hex"] = String(repeating: "0", count: 96)
        XCTAssertThrowsSuperNeoError(
            try NumiSealProductVerifier().verify(
                artifact: tamperedSourceRoot,
                sourcePublicInput: prepared.publicFoldInput,
                key: prepared.key,
                executionPolicy: .highAssurance
            ),
            .invalidEncoding("NumiSeal product source-fold CTCO root mismatch")
        )
    }

    func testNumiSealProductTheoremLimitsFailClosed() throws {
        let workload = try SuperNeoOneHotVectorWorkload(bitCount: 2)
        let prepared = try workload.prepareForFolding(
            bits: [false, true],
            keySeed: Array("numiseal-product-theorem-limits-key".utf8)
        )

        XCTAssertThrowsSuperNeoError(
            try NumiSealProductProver().prove(
                NumiSealProvingRequest(
                    preparedR1CS: prepared,
                    workload: "one-hot-vector-v1",
                    bitCount: 2,
                    publicInputs: [1],
                    keySeedUTF8: "numiseal-product-theorem-limits-key",
                    workloadParameters: ["selectedCount": "1"],
                    laneID: try NumiSealLaneID("product"),
                    executionPolicy: .zkHighAssuranceCPU,
                    aggregationLimits: try NumiSealAggregationLimits(
                        maximumObligationsPerAggregate:
                            NumiSealProductTheoremLimits.maximumObligationsPerAggregate + 1
                    )
                )
            ),
            .invalidParameter("NumiSeal product aggregate limit exceeds theorem maximum")
        )

        let artifact = try NumiSealProductProver().prove(
            NumiSealProvingRequest(
                preparedR1CS: prepared,
                workload: "one-hot-vector-v1",
                bitCount: 2,
                publicInputs: [1],
                keySeedUTF8: "numiseal-product-theorem-limits-key",
                workloadParameters: ["selectedCount": "1"],
                laneID: try NumiSealLaneID("product"),
                executionPolicy: .zkHighAssuranceCPU,
                aggregationLimits: try NumiSealAggregationLimits(maximumObligationsPerAggregate: 32)
            )
        )

        var tooManyLanes = artifact
        tooManyLanes.maximumLaneCount = NumiSealProductTheoremLimits.maximumLaneCount + 1
        XCTAssertThrowsSuperNeoError(
            try NumiSealProductVerifier().verify(
                artifact: tooManyLanes,
                sourcePublicInput: prepared.publicFoldInput,
                key: prepared.key,
                executionPolicy: .highAssurance
            ),
            .invalidEncoding("NumiSeal product lane count exceeds theorem maximum")
        )

        var tooManyAggregates = artifact
        tooManyAggregates.maximumAggregatesPerLane = NumiSealProductTheoremLimits.maximumAggregatesPerLane + 1
        XCTAssertThrowsSuperNeoError(
            try NumiSealProductVerifier().verify(
                artifact: tooManyAggregates,
                sourcePublicInput: prepared.publicFoldInput,
                key: prepared.key,
                executionPolicy: .highAssurance
            ),
            .invalidEncoding("NumiSeal product aggregate count exceeds theorem maximum")
        )

        var tooManyClaims = artifact
        tooManyClaims.sourceFoldOutputClaimCount = NumiSealProductTheoremLimits.maximumSourceFoldOutputClaimCount + 1
        tooManyClaims.sourceFoldOutputClaimDigestsHex = Array(
            repeating: String(repeating: "0", count: 64),
            count: tooManyClaims.sourceFoldOutputClaimCount
        )
        XCTAssertThrowsSuperNeoError(
            try NumiSealProductVerifier().verify(
                artifact: tooManyClaims,
                sourcePublicInput: prepared.publicFoldInput,
                key: prepared.key,
                executionPolicy: .highAssurance
            ),
            .invalidEncoding("NumiSeal product source claim count exceeds theorem maximum")
        )
    }

    func testNumiSealProductVerifierBindsCarryModeToTerminalPolicy() throws {
        let workload = try SuperNeoOneHotVectorWorkload(bitCount: 2)
        let prepared = try workload.prepareForFolding(
            bits: [false, true],
            keySeed: Array("numiseal-product-carry-policy-key".utf8)
        )
        let artifact = try NumiSealProductProver().prove(
            NumiSealProvingRequest(
                preparedR1CS: prepared,
                workload: "one-hot-vector-v1",
                bitCount: 2,
                publicInputs: [1],
                keySeedUTF8: "numiseal-product-carry-policy-key",
                workloadParameters: ["selectedCount": "1"],
                laneID: try NumiSealLaneID("product"),
                executionPolicy: .zkHighAssuranceCPU,
                aggregationLimits: try NumiSealAggregationLimits(maximumObligationsPerAggregate: 32)
            )
        )
        let verifier = NumiSealProductVerifier()

        var mismatchedMetadata = artifact
        mismatchedMetadata.carryMode = "typed-required"
        XCTAssertThrowsSuperNeoError(
            try verifier.verify(
                artifact: mismatchedMetadata,
                sourcePublicInput: prepared.publicFoldInput,
                key: prepared.key,
                executionPolicy: .highAssurance
            ),
            .invalidEncoding("NumiSeal product terminal carry policy metadata mismatch")
        )

        var typedOptional = artifact
        typedOptional.carryMode = "typed-optional"
        typedOptional.executionPolicyMetadata["terminalCarryPolicy"] = "typed-optional"
        let optionalResult = try verifier.verify(
            artifact: typedOptional,
            sourcePublicInput: prepared.publicFoldInput,
            key: prepared.key,
            executionPolicy: .highAssurance
        )
        XCTAssertTrue(optionalResult.numiSealResult.isValid, optionalResult.numiSealResult.reason ?? "")

        var typedRequired = artifact
        typedRequired.carryMode = "typed-required"
        typedRequired.executionPolicyMetadata["terminalCarryPolicy"] = "typed-required"
        XCTAssertThrowsSuperNeoError(
            try verifier.verify(
                artifact: typedRequired,
                sourcePublicInput: prepared.publicFoldInput,
                key: prepared.key,
                executionPolicy: .highAssurance
            ),
            .invalidEncoding("NumiSeal recursive carry metadata is incomplete")
        )
    }

    func testNumiSealProductRecursiveCarryContextBindsParentArtifactAndSession() throws {
        let workload = try SuperNeoOneHotVectorWorkload(bitCount: 2)
        let prepared = try workload.prepareForFolding(
            bits: [false, true],
            keySeed: Array("numiseal-product-recursive-carry-key".utf8)
        )
        let artifact = try NumiSealProductProver().prove(
            NumiSealProvingRequest(
                preparedR1CS: prepared,
                workload: "one-hot-vector-v1",
                bitCount: 2,
                publicInputs: [1],
                keySeedUTF8: "numiseal-product-recursive-carry-key",
                workloadParameters: ["selectedCount": "1"],
                laneID: try NumiSealLaneID("product"),
                executionPolicy: .zkHighAssuranceCPU,
                aggregationLimits: try NumiSealAggregationLimits(maximumObligationsPerAggregate: 32)
            )
        )
        let result = try NumiSealProductVerifier().verify(
            artifact: artifact,
            sourcePublicInput: prepared.publicFoldInput,
            key: prepared.key,
            executionPolicy: .highAssurance
        )
        let parentEnvelope = try XCTUnwrap(result.numiSealResult.envelope)
        let parentLaneProof = try XCTUnwrap(parentEnvelope.proof.laneProofs.first)
        let artifactDigest = try NumiSealProductArtifact.canonicalDigest(artifact)
        let sourceFoldEnvelopeDigest = try Digest256(
            hexDigest: artifact.sourceFoldEnvelopeDigestHex,
            name: "NumiSeal product source fold envelope digest"
        )
        let proofEnvelopeDigest = try Digest256(
            hexDigest: artifact.proofEnvelopeDigestHex,
            name: "NumiSeal product proof envelope digest"
        )
        let productCarryContext = try NumiSealProductCarryContext(
            consumerSessionDigest: Digest256.hash("child-product-session"),
            parentProductArtifactDigest: artifactDigest,
            parentSourceFoldEnvelopeDigest: sourceFoldEnvelopeDigest,
            parentProductProofEnvelopeDigest: proofEnvelopeDigest,
            parentProducerProofEnvelopeDigest: Digest256.hash(parentEnvelope.superNeoBytes),
            parentPublicStatementDigest: parentEnvelope.proof.publicStatement.digest,
            laneKey: parentLaneProof.laneKey,
            aggregateIndex: parentLaneProof.aggregateIndex,
            nextRecursionLevel: 1
        )
        XCTAssertEqual(productCarryContext.parentProductArtifactDigest, artifactDigest)
        XCTAssertEqual(productCarryContext.parentProductProofEnvelopeDigest, proofEnvelopeDigest)
        XCTAssertEqual(productCarryContext.parentProducerProofEnvelopeDigest, Digest256.hash(parentEnvelope.superNeoBytes))
        XCTAssertEqual(productCarryContext.parentPublicStatementDigest, parentEnvelope.proof.publicStatement.digest)

        let statement = try NumiSealTypedCarryProducer().produce(
            fromAcceptedParent: parentEnvelope,
            parentProofAccepted: true,
            laneProof: parentLaneProof,
            consumerContextDigest: productCarryContext.contextDigest,
            nextRecursionLevel: productCarryContext.nextRecursionLevel
        )
        XCTAssertEqual(statement.consumerContextDigest, productCarryContext.contextDigest)
        XCTAssertEqual(statement.producerProofEnvelopeDigest, productCarryContext.parentProducerProofEnvelopeDigest)
        XCTAssertEqual(statement.parentPublicStatementDigest, productCarryContext.parentPublicStatementDigest)

        var consumer = NumiSealCarryConsumer()
        let accepted = try consumer.consume(
            statement,
            parentProofAccepted: true,
            expectedProducerProofEnvelopeDigest: productCarryContext.parentProducerProofEnvelopeDigest,
            expectedProducerProofTranscriptDigest: parentEnvelope.proof.transcriptDigest,
            expectedParentStatementDigest: parentEnvelope.header.statementDigest,
            expectedParentPublicStatementDigest: productCarryContext.parentPublicStatementDigest,
            expectedConsumerContextDigest: productCarryContext.contextDigest,
            minimumNextRecursionLevel: productCarryContext.nextRecursionLevel
        )
        XCTAssertEqual(accepted.statement, statement)

        let swappedSessionContext = try NumiSealProductCarryContext(
            consumerSessionDigest: Digest256.hash("different-child-product-session"),
            parentProductArtifactDigest: artifactDigest,
            parentSourceFoldEnvelopeDigest: sourceFoldEnvelopeDigest,
            parentProductProofEnvelopeDigest: proofEnvelopeDigest,
            parentProducerProofEnvelopeDigest: Digest256.hash(parentEnvelope.superNeoBytes),
            parentPublicStatementDigest: parentEnvelope.proof.publicStatement.digest,
            laneKey: parentLaneProof.laneKey,
            aggregateIndex: parentLaneProof.aggregateIndex,
            nextRecursionLevel: 1
        )
        var swappedSessionConsumer = NumiSealCarryConsumer()
        XCTAssertThrowsSuperNeoError(
            try swappedSessionConsumer.consume(
                statement,
                parentProofAccepted: true,
                expectedProducerProofEnvelopeDigest: productCarryContext.parentProducerProofEnvelopeDigest,
                expectedProducerProofTranscriptDigest: parentEnvelope.proof.transcriptDigest,
                expectedParentStatementDigest: parentEnvelope.header.statementDigest,
                expectedParentPublicStatementDigest: productCarryContext.parentPublicStatementDigest,
                expectedConsumerContextDigest: swappedSessionContext.contextDigest,
                minimumNextRecursionLevel: productCarryContext.nextRecursionLevel
            ),
            .verificationFailed("NumiSeal carry consumer context digest mismatch")
        )

        let swappedParentArtifactContext = try NumiSealProductCarryContext(
            consumerSessionDigest: Digest256.hash("child-product-session"),
            parentProductArtifactDigest: Digest256.hash("different-parent-product-artifact"),
            parentSourceFoldEnvelopeDigest: sourceFoldEnvelopeDigest,
            parentProductProofEnvelopeDigest: proofEnvelopeDigest,
            parentProducerProofEnvelopeDigest: Digest256.hash(parentEnvelope.superNeoBytes),
            parentPublicStatementDigest: parentEnvelope.proof.publicStatement.digest,
            laneKey: parentLaneProof.laneKey,
            aggregateIndex: parentLaneProof.aggregateIndex,
            nextRecursionLevel: 1
        )
        var swappedArtifactConsumer = NumiSealCarryConsumer()
        XCTAssertThrowsSuperNeoError(
            try swappedArtifactConsumer.consume(
                statement,
                parentProofAccepted: true,
                expectedProducerProofEnvelopeDigest: productCarryContext.parentProducerProofEnvelopeDigest,
                expectedProducerProofTranscriptDigest: parentEnvelope.proof.transcriptDigest,
                expectedParentStatementDigest: parentEnvelope.header.statementDigest,
                expectedParentPublicStatementDigest: productCarryContext.parentPublicStatementDigest,
                expectedConsumerContextDigest: swappedParentArtifactContext.contextDigest,
                minimumNextRecursionLevel: productCarryContext.nextRecursionLevel
            ),
            .verificationFailed("NumiSeal carry consumer context digest mismatch")
        )
    }

    @inline(never)
    private func proveNumiSealProductRecursiveCarryFixture(
        request: NumiSealProvingRequest
    ) throws -> NumiSealProductArtifact {
        try NumiSealProductProver().prove(request)
    }

    @inline(never)
    private func verifyNumiSealProductRecursiveCarryFixture(
        artifact: NumiSealProductArtifact,
        prepared: SuperNeoPreparedR1CS
    ) throws -> NumiSealProductVerificationResult {
        try NumiSealProductVerifier().verify(
            artifact: artifact,
            sourcePublicInput: prepared.publicFoldInput,
            key: prepared.key,
            executionPolicy: .highAssurance
        )
    }

    @inline(never)
    private func makeNumiSealRecursiveCarryParentFixture(
        artifact: NumiSealProductArtifact,
        verificationResult: NumiSealProductVerificationResult,
        consumerSessionDigest: Digest256,
        nextRecursionLevel: Int
    ) throws -> NumiSealProductRecursiveCarryParent {
        try NumiSealProductRecursiveCarryParent(
            artifact: artifact,
            verificationResult: verificationResult,
            consumerSessionDigest: consumerSessionDigest,
            nextRecursionLevel: nextRecursionLevel
        )
    }

    @inline(never)
    private func verifyNumiSealRecursiveCarryChildFixture(
        artifact: NumiSealProductArtifact,
        prepared: SuperNeoPreparedR1CS,
        recursiveCarryParent: NumiSealProductRecursiveCarryParent
    ) throws -> NumiSealProductVerificationResult {
        try NumiSealProductVerifier().verify(
            artifact: artifact,
            sourcePublicInput: prepared.publicFoldInput,
            key: prepared.key,
            executionPolicy: .highAssurance,
            recursiveCarryParent: recursiveCarryParent
        )
    }

    func testNumiSealProductRecursiveCarryParentProducesAndVerifiesTypedRequiredChild() {
        guard let workload = try? SuperNeoOneHotVectorWorkload(bitCount: 2) else {
            XCTFail("NumiSeal recursive carry workload fixture failed")
            return
        }
        guard let parentPrepared = try? workload.prepareForFolding(
            bits: [false, true],
            keySeed: Array("numiseal-product-recursive-parent-key".utf8)
        ) else {
            XCTFail("NumiSeal recursive carry parent preparation fixture failed")
            return
        }
        guard let childPrepared = try? workload.prepareForFolding(
            bits: [false, true],
            keySeed: Array("numiseal-product-recursive-parent-key".utf8)
        ) else {
            XCTFail("NumiSeal recursive carry child preparation fixture failed")
            return
        }
        guard let laneID = try? NumiSealLaneID("product") else {
            XCTFail("NumiSeal recursive carry lane fixture failed")
            return
        }
        let verifier = NumiSealProductVerifier()
        guard let aggregationLimits = try? NumiSealAggregationLimits(maximumObligationsPerAggregate: 32) else {
            XCTFail("NumiSeal recursive carry aggregation limit fixture failed")
            return
        }
        let parentRequest = NumiSealProvingRequest(
            preparedR1CS: parentPrepared,
            workload: "one-hot-vector-v1",
            bitCount: 2,
            publicInputs: [1],
            keySeedUTF8: "numiseal-product-recursive-parent-key",
            workloadParameters: ["selectedCount": "1"],
            laneID: laneID,
            executionPolicy: .zkHighAssuranceCPU,
            aggregationLimits: aggregationLimits
        )
        var parentArtifact: NumiSealProductArtifact?
        XCTAssertNoThrow(
            parentArtifact = try proveNumiSealProductRecursiveCarryFixture(request: parentRequest)
        )
        guard let parentArtifact else {
            return
        }
        var parentResult: NumiSealProductVerificationResult?
        XCTAssertNoThrow(
            parentResult = try verifyNumiSealProductRecursiveCarryFixture(
                artifact: parentArtifact,
                prepared: parentPrepared
            )
        )
        guard let parentResult else {
            return
        }
        var recursiveParent: NumiSealProductRecursiveCarryParent?
        XCTAssertNoThrow(
            recursiveParent = try makeNumiSealRecursiveCarryParentFixture(
                artifact: parentArtifact,
                verificationResult: parentResult,
                consumerSessionDigest: Digest256.hash("numiseal-product-recursive-child-session"),
                nextRecursionLevel: 2
            )
        )
        guard let recursiveParent else {
            return
        }
        let childRequest = NumiSealProvingRequest(
            preparedR1CS: childPrepared,
            workload: "one-hot-vector-v1",
            bitCount: 2,
            publicInputs: [1],
            keySeedUTF8: "numiseal-product-recursive-parent-key",
            workloadParameters: ["selectedCount": "1"],
            laneID: laneID,
            executionPolicy: .zkHighAssuranceCPU,
            aggregationLimits: aggregationLimits,
            recursiveCarryParent: recursiveParent
        )
        let childArtifact = try! proveNumiSealProductRecursiveCarryFixture(request: childRequest)

        XCTAssertEqual(childArtifact.carryMode, "typed-required")
        XCTAssertEqual(childArtifact.executionPolicyMetadata["terminalCarryPolicy"], "typed-required")
        XCTAssertEqual(
            childArtifact.executionPolicyMetadata["recursiveCarryParentArtifactDigest"],
            recursiveParent.parentProductArtifactDigest.hexString
        )
        XCTAssertEqual(
            childArtifact.executionPolicyMetadata["recursiveCarryParentProducerProofEnvelopeDigest"],
            recursiveParent.parentProducerProofEnvelopeDigest.hexString
        )
        XCTAssertEqual(childArtifact.executionPolicyMetadata["recursiveCarryClaimCount"], "1")
        let recursiveBinding = try? childArtifact.recursiveCarryReplayBinding()
        XCTAssertEqual(recursiveBinding?.parentArtifactDigest, recursiveParent.parentProductArtifactDigest)
        XCTAssertEqual(recursiveBinding?.parentProducerProofEnvelopeDigest, recursiveParent.parentProducerProofEnvelopeDigest)
        XCTAssertEqual(recursiveBinding?.consumerSessionDigest, recursiveParent.consumerSessionDigest)
        XCTAssertEqual(recursiveBinding?.nextRecursionLevel, 2)
        XCTAssertEqual(childArtifact.executionPolicyMetadata["recursiveCarryMaximumSupportedDepth"], "2")
        XCTAssertNotNil(recursiveBinding?.bindingDigest)

        #if DEBUG
        guard let childResult = try? verifyNumiSealRecursiveCarryChildFixture(
            artifact: childArtifact,
            prepared: childPrepared,
            recursiveCarryParent: recursiveParent
        ) else {
            XCTFail("NumiSeal recursive carry typed-required child verification failed")
            return
        }
        XCTAssertTrue(childResult.numiSealResult.isValid, childResult.numiSealResult.reason ?? "")
        guard let childEnvelope = childResult.numiSealResult.envelope,
              let childLaneProof = childEnvelope.proof.laneProofs.first,
              let typedCarry = childLaneProof.optionalCarryClaim?.typedStatement else {
            XCTFail("NumiSeal recursive carry typed-required child proof is missing typed carry")
            return
        }
        XCTAssertEqual(typedCarry.recursionLevel, 2)
        XCTAssertEqual(typedCarry.producerProofEnvelopeDigest, recursiveParent.parentProducerProofEnvelopeDigest)
        XCTAssertEqual(typedCarry.parentPublicStatementDigest, recursiveParent.parentPublicStatementDigest)

        let grandchildParent = try! makeNumiSealRecursiveCarryParentFixture(
            artifact: childArtifact,
            verificationResult: childResult,
            consumerSessionDigest: Digest256.hash("numiseal-product-recursive-grandchild-session"),
            nextRecursionLevel: 3
        )
        let grandchildRequest = NumiSealProvingRequest(
            preparedR1CS: childPrepared,
            workload: "one-hot-vector-v1",
            bitCount: 2,
            publicInputs: [1],
            keySeedUTF8: "numiseal-product-recursive-parent-key",
            workloadParameters: ["selectedCount": "1"],
            laneID: laneID,
            executionPolicy: .zkHighAssuranceCPU,
            aggregationLimits: aggregationLimits,
            recursiveCarryParent: grandchildParent
        )
        let grandchildArtifact = try! proveNumiSealProductRecursiveCarryFixture(request: grandchildRequest)
        XCTAssertEqual(grandchildArtifact.executionPolicyMetadata["recursiveCarryNextRecursionLevel"], "3")
        XCTAssertEqual(grandchildArtifact.executionPolicyMetadata["recursiveCarryMaximumSupportedDepth"], "3")
        guard let grandchildResult = try? verifyNumiSealRecursiveCarryChildFixture(
            artifact: grandchildArtifact,
            prepared: childPrepared,
            recursiveCarryParent: grandchildParent
        ) else {
            XCTFail("NumiSeal recursive carry depth-3 child verification failed")
            return
        }
        XCTAssertTrue(grandchildResult.numiSealResult.isValid, grandchildResult.numiSealResult.reason ?? "")
        guard let grandchildEnvelope = grandchildResult.numiSealResult.envelope,
              let grandchildLaneProof = grandchildEnvelope.proof.laneProofs.first,
              let grandchildCarry = grandchildLaneProof.optionalCarryClaim?.typedStatement else {
            XCTFail("NumiSeal recursive carry depth-3 proof is missing typed carry")
            return
        }
        XCTAssertEqual(grandchildCarry.recursionLevel, 3)
        XCTAssertEqual(grandchildCarry.producerProofEnvelopeDigest, grandchildParent.parentProducerProofEnvelopeDigest)
        XCTAssertEqual(grandchildCarry.parentPublicStatementDigest, grandchildParent.parentPublicStatementDigest)

        XCTAssertThrowsSuperNeoError(
            try verifier.verify(
                artifact: childArtifact,
                sourcePublicInput: childPrepared.publicFoldInput,
                key: childPrepared.key,
                executionPolicy: .highAssurance
            ),
            .verificationFailed("NumiSeal typed-required product carry requires recursive carry parent context")
        )

        var swappedParent: NumiSealProductRecursiveCarryParent?
        XCTAssertNoThrow(
            swappedParent = try makeNumiSealRecursiveCarryParentFixture(
                artifact: parentArtifact,
                verificationResult: parentResult,
                consumerSessionDigest: Digest256.hash("different-numiseal-product-recursive-child-session"),
                nextRecursionLevel: 2
            )
        )
        guard let swappedParent else {
            return
        }
        XCTAssertThrowsSuperNeoError(
            try verifier.verify(
                artifact: childArtifact,
                sourcePublicInput: childPrepared.publicFoldInput,
                key: childPrepared.key,
                executionPolicy: .highAssurance,
                recursiveCarryParent: swappedParent
            ),
            .verificationFailed("NumiSeal recursive carry parent metadata mismatch")
        )

        var tampered = childArtifact
        tampered.executionPolicyMetadata["recursiveCarryContextRoot"] = String(repeating: "0", count: 64)
        XCTAssertThrowsSuperNeoError(
            try verifier.verify(
                artifact: tampered,
                sourcePublicInput: childPrepared.publicFoldInput,
                key: childPrepared.key,
                executionPolicy: .highAssurance,
                recursiveCarryParent: recursiveParent
            ),
            .verificationFailed("NumiSeal recursive carry context root mismatch")
        )
        #else
        let childProof: NumiSealProof
        do {
            switch childArtifact.zkMode {
            case NumiSealZK.nonZKMode:
                childProof = try NumiSealProofEnvelope(
                    bytes: childArtifact.proofEnvelopeBytes(),
                    parameters: .goldilocks
                ).proof
            case NumiSealZK.maskedDigitTensorMode:
                childProof = try NumiSealZKProofEnvelope(
                    bytes: childArtifact.proofEnvelopeBytes(),
                    parameters: .goldilocks
                ).proof.baseProof
            default:
                XCTFail("unsupported NumiSeal product ZK mode")
                return
            }
        } catch {
            XCTFail("could not decode NumiSeal recursive carry child proof: \(error)")
            return
        }
        guard let childLaneProof = childProof.laneProofs.first,
              let typedCarry = childLaneProof.optionalCarryClaim?.typedStatement else {
            XCTFail("NumiSeal recursive carry typed-required child proof is missing typed carry")
            return
        }
        XCTAssertEqual(typedCarry.recursionLevel, 2)
        XCTAssertEqual(typedCarry.producerProofEnvelopeDigest, recursiveParent.parentProducerProofEnvelopeDigest)
        XCTAssertEqual(typedCarry.parentPublicStatementDigest, recursiveParent.parentPublicStatementDigest)
        #endif
    }

    func testNumiSealProductProverEmitsVerifiableZKV2Artifact() throws {
        let workload = try SuperNeoOneHotVectorWorkload(bitCount: 2)
        let prepared = try workload.prepareForFolding(
            bits: [false, true],
            keySeed: Array("numiseal-product-zk-key".utf8)
        )
        let artifact = try NumiSealProductProver().prove(
            NumiSealProvingRequest(
                preparedR1CS: prepared,
                workload: "one-hot-vector-v1",
                bitCount: 2,
                publicInputs: [1],
                keySeedUTF8: "numiseal-product-zk-key",
                workloadParameters: ["selectedCount": "1"],
                laneID: try NumiSealLaneID("product"),
                executionPolicy: .zkHighAssuranceCPU,
                zkMode: NumiSealZK.maskedDigitTensorMode,
                aggregationLimits: try NumiSealAggregationLimits(maximumObligationsPerAggregate: 32)
            )
        )

        XCTAssertEqual(artifact.artifactVersion, NumiSealProductArtifact.artifactVersion)
        XCTAssertEqual(artifact.proofKind, NumiSealProductArtifact.zkProofKind)
        XCTAssertEqual(artifact.sealMode, NumiSealZK.sealMode)
        XCTAssertEqual(artifact.carryMode, "none")
        XCTAssertEqual(artifact.zkMode, NumiSealZK.maskedDigitTensorMode)
        XCTAssertEqual(artifact.sourceFoldOutputClaimCount, 14)
        XCTAssertEqual(artifact.aggregateDigestsHex.count, 1)
        XCTAssertEqual(artifact.executionPolicyMetadata["numiSealProofKind"], NumiSealProductArtifact.zkProofKind)
        XCTAssertEqual(artifact.executionPolicyMetadata["terminalCarryPolicy"], "none")
        XCTAssertEqual(artifact.executionPolicyMetadata["zkProofBodyVersion"], "\(NumiSealZKProof.bodyVersion)")
        XCTAssertEqual(
            artifact.executionPolicyMetadata["zkMaskedResidualStatementVersion"],
            "\(NumiSealZKMaskedResidualStatement.version)"
        )
        XCTAssertEqual(artifact.executionPolicyMetadata["zkMaskedResidualStatementCount"], "1")
        XCTAssertNotNil(artifact.executionPolicyMetadata["zkRandomnessSessionDigest"])
        XCTAssertNotNil(artifact.executionPolicyMetadata["zkLeakageDigest"])
        XCTAssertEqual(
            artifact.executionPolicyMetadata["zkSimulatorCouplingSurface"],
            "terminal-base-proof-to-masked-residual-session-v1"
        )
        XCTAssertNoThrow(
            try Digest256(
                hexDigest: artifact.executionPolicyMetadata["zkSimulatorCouplingEvidenceDigest"] ?? "",
                name: "NumiSeal ZK simulator coupling evidence digest"
            )
        )

        let proofBytes = try artifact.proofEnvelopeBytes()
        let header = try ProofEnvelopeHeader.parsePrefix(from: proofBytes)
        XCTAssertEqual(header.kind, .numiSealZK)
        let zkEnvelope = try NumiSealZKProofEnvelope(bytes: proofBytes)
        XCTAssertEqual(zkEnvelope.proof.maskStatements.count, 1)
        XCTAssertEqual(zkEnvelope.proof.maskedResidualStatements.count, 1)
        XCTAssertEqual(zkEnvelope.proof.baseProof.publicStatement.digest.hexString, artifact.publicStatementDigestHex)
        XCTAssertEqual(zkEnvelope.proof.componentDigestRoot.hexString, artifact.componentDigestRootHex)
        XCTAssertEqual(zkEnvelope.proof.transcriptDigest.hexString, artifact.proofTranscriptDigestHex)

        let result = try NumiSealProductVerifier().verify(
            artifact: artifact,
            sourcePublicInput: prepared.publicFoldInput,
            key: prepared.key,
            executionPolicy: .highAssurance
        )
        XCTAssertTrue(result.sourceFoldResult.isReductionAccepted, result.sourceFoldResult.reason ?? "")
        XCTAssertTrue(result.numiSealResult.isValid, result.numiSealResult.reason ?? "")

        var tampered = artifact
        tampered.zkMode = NumiSealZK.nonZKMode
        XCTAssertThrowsSuperNeoError(
            try NumiSealProductVerifier().verify(
                artifact: tampered,
                sourcePublicInput: prepared.publicFoldInput,
                key: prepared.key,
                executionPolicy: .highAssurance
            ),
            .invalidEncoding("NumiSeal product proof kind, seal mode, and ZK mode are inconsistent")
        )
    }

    func testR1CSProgramGeneratesTerminalProofAndVerifiesUnderPolicy() throws {
        let workload = try SuperNeoOneHotVectorWorkload(bitCount: 2)
        let program = SuperNeoR1CSProgram(
            builder: workload.builder,
            witnessGenerator: SuperNeoR1CSWitnessGenerator<[Bool]>(
                publicInput: { _ in workload.publicInput },
                privateWitness: { try workload.privateWitness(bits: $0) }
            )
        )

        let output = try program.prove(
            input: [false, true],
            keySeed: Array("r1cs-terminal-stack-key".utf8),
            proofKind: .terminalLocal,
            executionPolicy: .default
        )

        XCTAssertEqual(output.proofKind, .terminalLocal)
        XCTAssertTrue(output.requiresNormalization)
        XCTAssertEqual(output.statement.statementDigest, output.context.statementDigest)
        XCTAssertEqual(output.verifierKeyDigest, output.context.verifierKeyDigest)

        let result = SuperNeoR1CSProvingStack.verifyTerminalProof(
            publicInput: output.publicFoldInput,
            proofBytes: output.proofBytes,
            verifierKey: output.verifierKey,
            policy: output.terminalAcceptancePolicy,
            executionPolicy: .default
        )
        XCTAssertTrue(result.isValid, result.reason ?? "")
    }

    func testR1CSProgramKeepsFoldReductionSeparateFromTerminalAcceptance() throws {
        let workload = try SuperNeoOneHotVectorWorkload(bitCount: 2)
        let output = try SuperNeoR1CSProvingStack.prove(
            builder: workload.builder,
            assignment: SuperNeoR1CSAssignment(
                publicInput: workload.publicInput,
                privateWitness: try workload.privateWitness(bits: [true, false])
            ),
            keySeed: Array("r1cs-fold-stack-key".utf8),
            proofKind: .foldReduction,
            executionPolicy: .highAssurance
        )

        let reduction = SuperNeoR1CSProvingStack.reduceFoldProof(
            publicInput: output.publicFoldInput,
            proofBytes: output.proofBytes,
            context: output.context,
            verifierKey: output.verifierKey,
            executionPolicy: .highAssurance
        )
        XCTAssertTrue(reduction.isReductionAccepted, reduction.reason ?? "")
        XCTAssertTrue(reduction.requiresTerminalRelationCheck)

        let terminalResult = SuperNeoR1CSProvingStack.verifyTerminalProof(
            publicInput: output.publicFoldInput,
            proofBytes: output.proofBytes,
            verifierKey: output.verifierKey,
            policy: output.terminalAcceptancePolicy,
            executionPolicy: .highAssurance
        )
        XCTAssertInvalid(terminalResult)
        XCTAssertTrue(terminalResult.reason?.contains("terminal proof required") ?? false)
    }

    func testR1CSProvingStackRejectsUnsatisfiedGeneratedWitness() throws {
        let workload = try SuperNeoOneHotVectorWorkload(bitCount: 2)
        XCTAssertThrowsSuperNeoError(
            try SuperNeoR1CSProvingStack.prove(
                builder: workload.builder,
                assignment: SuperNeoR1CSAssignment(
                    publicInput: workload.publicInput,
                    privateWitness: [.one, .one]
                ),
                keySeed: Array("r1cs-bad-witness-key".utf8),
                proofKind: .terminalLocal
            ),
            .invalidParameter("R1CS witness does not satisfy all constraints")
        )
    }

    func testOneHotR1CSBuilderPreparesVerifiableFoldEnvelope() throws {
        let workload = try SuperNeoOneHotVectorWorkload(bitCount: 8)
        let prepared = try workload.prepareForFolding(
            bits: [false, false, true, false, false, false, false, false],
            keySeed: Array("usability-one-hot-key".utf8)
        )
        XCTAssertTrue(prepared.preparedFoldInput.requiresNormalization)
        XCTAssertEqual(prepared.foldInput.shape.nPublicField, CyclotomicRing54.degree)
        XCTAssertEqual(prepared.foldInput.shape.nField, 64)
        XCTAssertTrue(prepared.foldInput.shape.hasIdentityFirstMatrix)

        let publicInput = prepared.publicFoldInput
        let statement = CCSStatement(
            shapeDigest: publicInput.shape.shapeDigest,
            ccsInstances: publicInput.instances
        )
        let context = ProofEnvelopeContext(
            kind: .foldReduction,
            statement: statement,
            verifierKeyDigest: prepared.key.verifierKeyDigest
        )
        let envelope = try SuperNeoCPUBackend()
            .makeProver(key: prepared.key)
            .foldEnvelope(prepared.foldInput, context: context)
        let reduction = SuperNeoCPUBackend()
            .makeVerifier(key: prepared.key)
            .reduceFoldEnvelope(
                publicInput: publicInput,
                proofBytes: envelope.superNeoBytes,
                context: context
            )

        XCTAssertTrue(reduction.isReductionAccepted, reduction.reason ?? "")
        XCTAssertTrue(reduction.requiresTerminalRelationCheck)
        XCTAssertEqual(reduction.outputClaims.count, prepared.key.parameters.decompositionLength)
    }

    func testOneHotR1CSBuilderRejectsNonOneHotWitness() throws {
        let workload = try SuperNeoOneHotVectorWorkload(bitCount: 4)
        XCTAssertThrowsSuperNeoError(
            try workload.privateWitness(bits: [true, false, true, false]),
            .invalidParameter("one-hot witness must contain exactly one selected bit")
        )
    }

    func testR1CSBuilderRejectsOutOfBoundsVariablesWithoutTrapping() throws {
        var builder = SuperNeoR1CSBuilder()
        let invalid = SuperNeoR1CSVariable(kind: .publicInput, offset: 99)
        builder.enforce(
            .variable(invalid),
            times: .constant(.one, one: builder.one),
            equals: .zero()
        )

        XCTAssertThrowsSuperNeoError(
            try builder.validateWitness(publicInput: [.one], privateWitness: []),
            .invalidParameter("R1CS public variable out of bounds")
        )
    }

    func testWorkloadDefaultKeySeedsAreParameterSeparatedAndVectorCompatible() throws {
        XCTAssertEqual(try SuperNeoWorkloadKeySeed.oneHotVector(bitCount: 8), "SuperNeoCLI.one-hot-vector.v1")
        XCTAssertEqual(try SuperNeoWorkloadKeySeed.oneHotVector(bitCount: 4), "SuperNeoCLI.one-hot-vector.u4.v1")
        XCTAssertEqual(try SuperNeoWorkloadKeySeed.binaryAddition(operandBits: 8), "SuperNeoCLI.binary-addition.u8.v1")
        XCTAssertEqual(try SuperNeoWorkloadKeySeed.binaryAddition(operandBits: 16), "SuperNeoCLI.binary-addition.u16.v1")
        XCTAssertNotEqual(
            try SuperNeoWorkloadKeySeed.binaryAddition(operandBits: 8),
            try SuperNeoWorkloadKeySeed.binaryAddition(operandBits: 16)
        )
        XCTAssertThrowsSuperNeoError(
            try SuperNeoWorkloadKeySeed.binaryAddition(operandBits: 63),
            .invalidParameter("binary-addition key seed requires operand bits in 1...62")
        )
    }

    func testCPUBackendFactoriesExposeExecutionPolicy() throws {
        let key = try AjtaiCommitmentKey(columns: 1, seed: Array("cpu-backend-policy".utf8))
        XCTAssertEqual(SuperNeoExecutionPolicy.default, .highAssurance)
        XCTAssertEqual(SuperNeoExecutionPolicy(), .highAssurance)
        XCTAssertTrue(SuperNeoExecutionPolicy.default.usesConstantWorkCPU)
        XCTAssertTrue(SuperNeoExecutionPolicy.default.requiresMetalCPUCheck)
        XCTAssertEqual(
            SuperNeoCPUBackend().makeProver(key: key).executionPolicy,
            .highAssurance
        )
        XCTAssertEqual(
            SuperNeoCPUBackend().makeVerifier(key: key).executionPolicy,
            .highAssurance
        )
        XCTAssertEqual(
            SuperNeoCPUBackend().makeProver(key: key, executionPolicy: .highAssurance).executionPolicy,
            .highAssurance
        )
        XCTAssertEqual(
            SuperNeoCPUBackend().makeVerifier(key: key, executionPolicy: .cpuRedundantMetal).executionPolicy,
            .cpuRedundantMetal
        )
        XCTAssertEqual(
            NumiSealProvingExecutionPolicy.defaultProduct.resolvedSuperNeoPolicy(metalContext: nil),
            .highAssurance
        )
        XCTAssertEqual(
            NumiSealProvingExecutionPolicy.defaultProduct.resolvedMetalMode(metalContext: nil),
            "cpu-reference"
        )
        if let device = MTLCreateSystemDefaultDevice(),
           let context = try? MetalExecutionContext(device: device) {
            XCTAssertEqual(
                NumiSealProvingExecutionPolicy.defaultProduct.resolvedSuperNeoPolicy(metalContext: context),
                .highAssurance
            )
            XCTAssertEqual(
                NumiSealProvingExecutionPolicy.defaultProduct.resolvedMetalMode(metalContext: context),
                "cpu-reference"
            )
        }
    }

    func testBinaryAdditionR1CSBuilderPreparesVerifiableFoldEnvelope() throws {
        let workload = try SuperNeoBinaryAdditionWorkload(bitCount: 8)
        let prepared = try workload.prepareForFolding(
            left: 13,
            right: 29,
            keySeed: Array("usability-binary-addition-key".utf8)
        )
        XCTAssertTrue(prepared.preparedFoldInput.requiresNormalization)
        XCTAssertEqual(prepared.foldInput.shape.nPublicField, CyclotomicRing54.degree)
        XCTAssertEqual(prepared.foldInput.shape.nField, 128)
        XCTAssertTrue(prepared.foldInput.shape.hasIdentityFirstMatrix)

        let publicInput = prepared.publicFoldInput
        let statement = CCSStatement(
            shapeDigest: publicInput.shape.shapeDigest,
            ccsInstances: publicInput.instances
        )
        let context = ProofEnvelopeContext(
            kind: .foldReduction,
            statement: statement,
            verifierKeyDigest: prepared.key.verifierKeyDigest
        )
        let envelope = try SuperNeoCPUBackend()
            .makeProver(key: prepared.key)
            .foldEnvelope(prepared.foldInput, context: context)
        let reduction = SuperNeoCPUBackend()
            .makeVerifier(key: prepared.key)
            .reduceFoldEnvelope(
                publicInput: publicInput,
                proofBytes: envelope.superNeoBytes,
                context: context
            )

        XCTAssertTrue(reduction.isReductionAccepted, reduction.reason ?? "")
        XCTAssertTrue(reduction.requiresTerminalRelationCheck)
        XCTAssertEqual(reduction.outputClaims.count, prepared.key.parameters.decompositionLength)
    }

    func testGoldenOneHotFoldVectorVerifies() throws {
        let artifact = try loadGoldenArtifact(named: "one-hot-vector-fold-v1.json")
        XCTAssertEqual(artifact.artifactVersion, 1)
        XCTAssertEqual(artifact.workload, "one-hot-vector-v1")
        XCTAssertEqual(artifact.profile, SuperNeoParameterProfile.goldilocksPhi81.name)
        XCTAssertEqual(artifact.proofKind, "fold")
        XCTAssertEqual(artifact.publicInputs, [1])
        XCTAssertEqual(artifact.expectedSelectedCount, 1)

        let workload = try SuperNeoOneHotVectorWorkload(bitCount: artifact.bitCount)
        let commitment = try parseGoldenCommitment(artifact.commitmentBase64, parameters: .goldilocks)
        let publicInput = try workload.publicFoldInput(commitment: commitment)
        XCTAssertEqual(publicInput.shape.shapeDigest.hexStringForTest, artifact.shapeDigestHex)

        let key = try AjtaiCommitmentKey(columns: publicInput.shape.nRing, seed: Array(artifact.keySeedUTF8.utf8))
        XCTAssertEqual(key.verifierKeyDigest.hexStringForTest, artifact.verifierKeyDigestHex)
        let statement = CCSStatement(
            shapeDigest: publicInput.shape.shapeDigest,
            ccsInstances: publicInput.instances
        )
        XCTAssertEqual(statement.statementDigest.hexStringForTest, artifact.statementDigestHex)

        let proofBytes = try XCTUnwrap(Data(base64Encoded: artifact.proofEnvelopeBase64)).map { UInt8($0) }
        let context = ProofEnvelopeContext(
            kind: .foldReduction,
            statement: statement,
            verifierKeyDigest: key.verifierKeyDigest
        )
        let reduction = SuperNeoCPUBackend()
            .makeVerifier(key: key)
            .reduceFoldEnvelope(
                publicInput: publicInput,
                proofBytes: proofBytes,
                context: context
            )

        XCTAssertTrue(reduction.isReductionAccepted, reduction.reason ?? "")
        XCTAssertTrue(reduction.requiresTerminalRelationCheck)
        XCTAssertEqual(reduction.outputClaims.count, key.parameters.decompositionLength)
    }

    func testGoldenOneHotTerminalVectorVerifies() throws {
        let artifact = try loadGoldenArtifact(named: "one-hot-vector-terminal-v1.json")
        XCTAssertEqual(artifact.artifactVersion, 1)
        XCTAssertEqual(artifact.workload, "one-hot-vector-v1")
        XCTAssertEqual(artifact.profile, SuperNeoParameterProfile.goldilocksPhi81.name)
        XCTAssertEqual(artifact.proofKind, "terminal")
        XCTAssertEqual(artifact.publicInputs, [1])
        XCTAssertEqual(artifact.expectedSelectedCount, 1)

        let workload = try SuperNeoOneHotVectorWorkload(bitCount: artifact.bitCount)
        let commitment = try parseGoldenCommitment(artifact.commitmentBase64, parameters: .goldilocks)
        let publicInput = try workload.publicFoldInput(commitment: commitment)
        XCTAssertEqual(publicInput.shape.shapeDigest.hexStringForTest, artifact.shapeDigestHex)

        let key = try AjtaiCommitmentKey(columns: publicInput.shape.nRing, seed: Array(artifact.keySeedUTF8.utf8))
        XCTAssertEqual(key.verifierKeyDigest.hexStringForTest, artifact.verifierKeyDigestHex)
        let statement = CCSStatement(
            shapeDigest: publicInput.shape.shapeDigest,
            ccsInstances: publicInput.instances
        )
        XCTAssertEqual(statement.statementDigest.hexStringForTest, artifact.statementDigestHex)

        let proofBytes = try XCTUnwrap(Data(base64Encoded: artifact.proofEnvelopeBase64)).map { UInt8($0) }
        let context = ProofEnvelopeContext(
            kind: .terminalLocal,
            statement: statement,
            verifierKeyDigest: key.verifierKeyDigest
        )
        let result = SuperNeoCPUBackend()
            .makeVerifier(key: key)
            .verifyTerminalFoldEnvelope(
                publicInput: publicInput,
                proofBytes: proofBytes,
                context: context
            )

        XCTAssertTrue(result.isValid, result.reason ?? "")
    }

    func testGoldenOneHotCompressedTerminalVectorVerifies() throws {
        let artifact = try loadGoldenArtifact(named: "one-hot-vector-compressed-terminal-v1.json")
        XCTAssertEqual(artifact.artifactVersion, 1)
        XCTAssertEqual(artifact.workload, "one-hot-vector-v1")
        XCTAssertEqual(artifact.profile, SuperNeoParameterProfile.goldilocksPhi81.name)
        XCTAssertEqual(artifact.proofKind, "compressed-terminal")
        XCTAssertEqual(artifact.publicInputs, [1])
        XCTAssertEqual(artifact.expectedSelectedCount, 1)

        let workload = try SuperNeoOneHotVectorWorkload(bitCount: artifact.bitCount)
        let commitment = try parseGoldenCommitment(artifact.commitmentBase64, parameters: .goldilocks)
        let publicInput = try workload.publicFoldInput(commitment: commitment)
        XCTAssertEqual(publicInput.shape.shapeDigest.hexStringForTest, artifact.shapeDigestHex)

        let key = try AjtaiCommitmentKey(columns: publicInput.shape.nRing, seed: Array(artifact.keySeedUTF8.utf8))
        XCTAssertEqual(key.verifierKeyDigest.hexStringForTest, artifact.verifierKeyDigestHex)
        let statement = CCSStatement(
            shapeDigest: publicInput.shape.shapeDigest,
            ccsInstances: publicInput.instances
        )
        XCTAssertEqual(statement.statementDigest.hexStringForTest, artifact.statementDigestHex)

        let proofBytes = try XCTUnwrap(Data(base64Encoded: artifact.proofEnvelopeBase64)).map { UInt8($0) }
        let context = ProofEnvelopeContext(
            kind: .compressedPublic,
            statement: statement,
            verifierKeyDigest: key.verifierKeyDigest
        )
        let result = SuperNeoCPUBackend()
            .makeVerifier(key: key)
            .verifyCompressedTerminalFoldEnvelope(
                publicInput: publicInput,
                proofBytes: proofBytes,
                context: context
            )

        XCTAssertTrue(result.isValid, result.reason ?? "")
    }

    func testTerminalAcceptancePolicyRejectsFoldAndDispatchesTerminalKinds() throws {
        let foldArtifact = try loadGoldenArtifact(named: "one-hot-vector-fold-v1.json")
        let terminalArtifact = try loadGoldenArtifact(named: "one-hot-vector-terminal-v1.json")
        let compressedArtifact = try loadGoldenArtifact(named: "one-hot-vector-compressed-terminal-v1.json")
        let workload = try SuperNeoOneHotVectorWorkload(bitCount: foldArtifact.bitCount)
        let commitment = try parseGoldenCommitment(foldArtifact.commitmentBase64, parameters: .goldilocks)
        let publicInput = try workload.publicFoldInput(commitment: commitment)
        let key = try AjtaiCommitmentKey(columns: publicInput.shape.nRing, seed: Array(foldArtifact.keySeedUTF8.utf8))
        let statement = CCSStatement(
            shapeDigest: publicInput.shape.shapeDigest,
            ccsInstances: publicInput.instances
        )
        let policy = SuperNeoTerminalProofAcceptancePolicy(
            publicInput: publicInput,
            verifierKeyDigest: key.verifierKeyDigest
        )
        let verifier = SuperNeoCPUBackend().makeVerifier(key: key)

        let foldBytes = try XCTUnwrap(Data(base64Encoded: foldArtifact.proofEnvelopeBase64)).map { UInt8($0) }
        let foldResult = verifier.verifyTerminalProofEnvelope(
            publicInput: publicInput,
            proofBytes: foldBytes,
            policy: policy
        )
        XCTAssertFalse(foldResult.isValid)
        XCTAssertTrue(foldResult.reason?.contains("terminal proof required") ?? false)

        let terminalBytes = try XCTUnwrap(Data(base64Encoded: terminalArtifact.proofEnvelopeBase64)).map { UInt8($0) }
        XCTAssertTrue(
            verifier.verifyTerminalProofEnvelope(
                publicInput: publicInput,
                proofBytes: terminalBytes,
                policy: policy
            ).isValid
        )

        let compressedBytes = try XCTUnwrap(Data(base64Encoded: compressedArtifact.proofEnvelopeBase64)).map { UInt8($0) }
        XCTAssertTrue(
            verifier.verifyTerminalProofEnvelope(
                publicInput: publicInput,
                proofBytes: compressedBytes,
                policy: policy
            ).isValid
        )

        let compressedOnlyPolicy = SuperNeoTerminalProofAcceptancePolicy(
            publicInput: publicInput,
            verifierKeyDigest: key.verifierKeyDigest,
            proofKindPolicy: .compressedOnly
        )
        let terminalRejectedByKindPolicy = verifier.verifyTerminalProofEnvelope(
            publicInput: publicInput,
            proofBytes: terminalBytes,
            policy: compressedOnlyPolicy
        )
        XCTAssertFalse(terminalRejectedByKindPolicy.isValid)
        XCTAssertTrue(terminalRejectedByKindPolicy.reason?.contains("proof kind not accepted by policy") ?? false)

        let terminalOnlyPolicy = SuperNeoTerminalProofAcceptancePolicy(
            publicInput: publicInput,
            verifierKeyDigest: key.verifierKeyDigest,
            proofKindPolicy: .terminalOnly
        )
        let compressedRejectedByKindPolicy = verifier.verifyTerminalProofEnvelope(
            publicInput: publicInput,
            proofBytes: compressedBytes,
            policy: terminalOnlyPolicy
        )
        XCTAssertFalse(compressedRejectedByKindPolicy.isValid)
        XCTAssertTrue(compressedRejectedByKindPolicy.reason?.contains("proof kind not accepted by policy") ?? false)

        let cappedPolicy = SuperNeoTerminalProofAcceptancePolicy(
            publicInput: publicInput,
            verifierKeyDigest: key.verifierKeyDigest,
            maximumProofByteCount: terminalBytes.count - 1
        )
        let cappedResult = verifier.verifyTerminalProofEnvelope(
            publicInput: publicInput,
            proofBytes: terminalBytes,
            policy: cappedPolicy
        )
        XCTAssertFalse(cappedResult.isValid)
        XCTAssertTrue(cappedResult.reason?.contains("proof byte count exceeds policy maximum") ?? false)

        let wrongStatementPolicy = SuperNeoTerminalProofAcceptancePolicy(
            profileID: SuperNeoParameterProfile.goldilocksPhi81.profileID,
            shapeDigest: statement.shapeDigest,
            statementDigest: Digest256.hash("wrong statement digest"),
            verifierKeyDigest: key.verifierKeyDigest
        )
        let wrongStatementResult = verifier.verifyTerminalProofEnvelope(
            publicInput: publicInput,
            proofBytes: terminalBytes,
            policy: wrongStatementPolicy
        )
        XCTAssertFalse(wrongStatementResult.isValid)
        XCTAssertTrue(wrongStatementResult.reason?.contains("CTCO context binder mismatch") ?? false)
    }

    func testGoldenBinaryAdditionFoldVectorVerifies() throws {
        let artifact = try loadGoldenArtifact(named: "binary-addition-u8-fold-v1.json")
        XCTAssertEqual(artifact.artifactVersion, 1)
        XCTAssertEqual(artifact.workload, "binary-addition-v1")
        XCTAssertEqual(artifact.profile, SuperNeoParameterProfile.goldilocksPhi81.name)
        XCTAssertEqual(artifact.proofKind, "fold")
        XCTAssertEqual(artifact.bitCount, 8)
        XCTAssertEqual(artifact.workloadParameters?["publicSum"], "42")

        let workload = try SuperNeoBinaryAdditionWorkload(bitCount: artifact.bitCount)
        let commitment = try parseGoldenCommitment(artifact.commitmentBase64, parameters: .goldilocks)
        let publicInput = try workload.publicFoldInput(
            commitment: commitment,
            publicInput: artifact.publicInputs.map { GoldilocksField($0) }
        )
        XCTAssertEqual(publicInput.shape.shapeDigest.hexStringForTest, artifact.shapeDigestHex)

        let key = try AjtaiCommitmentKey(columns: publicInput.shape.nRing, seed: Array(artifact.keySeedUTF8.utf8))
        XCTAssertEqual(key.verifierKeyDigest.hexStringForTest, artifact.verifierKeyDigestHex)
        let statement = CCSStatement(
            shapeDigest: publicInput.shape.shapeDigest,
            ccsInstances: publicInput.instances
        )
        XCTAssertEqual(statement.statementDigest.hexStringForTest, artifact.statementDigestHex)

        let proofBytes = try XCTUnwrap(Data(base64Encoded: artifact.proofEnvelopeBase64)).map { UInt8($0) }
        let context = ProofEnvelopeContext(
            kind: .foldReduction,
            statement: statement,
            verifierKeyDigest: key.verifierKeyDigest
        )
        let reduction = SuperNeoCPUBackend()
            .makeVerifier(key: key)
            .reduceFoldEnvelope(
                publicInput: publicInput,
                proofBytes: proofBytes,
                context: context
            )

        XCTAssertTrue(reduction.isReductionAccepted, reduction.reason ?? "")
        XCTAssertTrue(reduction.requiresTerminalRelationCheck)
        XCTAssertEqual(reduction.outputClaims.count, key.parameters.decompositionLength)
    }

    func testGoldenBinaryAdditionTerminalVectorVerifies() throws {
        let artifact = try loadGoldenArtifact(named: "binary-addition-u8-terminal-v1.json")
        XCTAssertEqual(artifact.artifactVersion, 1)
        XCTAssertEqual(artifact.workload, "binary-addition-v1")
        XCTAssertEqual(artifact.profile, SuperNeoParameterProfile.goldilocksPhi81.name)
        XCTAssertEqual(artifact.proofKind, "terminal")
        XCTAssertEqual(artifact.bitCount, 8)
        XCTAssertEqual(artifact.workloadParameters?["leftBitCount"], "8")
        XCTAssertEqual(artifact.workloadParameters?["publicSum"], "42")

        let workload = try SuperNeoBinaryAdditionWorkload(bitCount: artifact.bitCount)
        let commitment = try parseGoldenCommitment(artifact.commitmentBase64, parameters: .goldilocks)
        let publicInput = try workload.publicFoldInput(
            commitment: commitment,
            publicInput: artifact.publicInputs.map { GoldilocksField($0) }
        )
        XCTAssertEqual(publicInput.shape.shapeDigest.hexStringForTest, artifact.shapeDigestHex)

        let key = try AjtaiCommitmentKey(columns: publicInput.shape.nRing, seed: Array(artifact.keySeedUTF8.utf8))
        XCTAssertEqual(key.verifierKeyDigest.hexStringForTest, artifact.verifierKeyDigestHex)
        let statement = CCSStatement(
            shapeDigest: publicInput.shape.shapeDigest,
            ccsInstances: publicInput.instances
        )
        XCTAssertEqual(statement.statementDigest.hexStringForTest, artifact.statementDigestHex)

        let proofBytes = try XCTUnwrap(Data(base64Encoded: artifact.proofEnvelopeBase64)).map { UInt8($0) }
        let context = ProofEnvelopeContext(
            kind: .terminalLocal,
            statement: statement,
            verifierKeyDigest: key.verifierKeyDigest
        )
        let result = SuperNeoCPUBackend()
            .makeVerifier(key: key)
            .verifyTerminalFoldEnvelope(
                publicInput: publicInput,
                proofBytes: proofBytes,
                context: context
            )

        XCTAssertTrue(result.isValid, result.reason ?? "")
    }

    private struct GoldenArtifact: Decodable {
        let artifactVersion: UInt32
        let workload: String
        let profile: String
        let proofKind: String
        let bitCount: Int
        let expectedSelectedCount: UInt64?
        let keySeedUTF8: String
        let workloadParameters: [String: String]?
        let publicInputs: [UInt64]
        let commitmentBase64: String
        let proofEnvelopeBase64: String
        let shapeDigestHex: String
        let statementDigestHex: String
        let verifierKeyDigestHex: String
    }

    private func loadGoldenArtifact(named name: String) throws -> GoldenArtifact {
        let testFile = URL(fileURLWithPath: #filePath)
        let repositoryRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = repositoryRoot
            .appendingPathComponent("TestVectors")
            .appendingPathComponent(name)
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(GoldenArtifact.self, from: data)
    }

    private func parseGoldenCommitment(_ base64: String, parameters: SuperNeoParameters) throws -> AjtaiCommitment {
        let data = try XCTUnwrap(Data(base64Encoded: base64))
        let ringByteCount = CyclotomicRing54.degree * 8
        XCTAssertEqual(data.count, parameters.kappa * ringByteCount)
        let bytes = [UInt8](data)
        let elements = try stride(from: 0, to: bytes.count, by: ringByteCount).map { offset in
            try CyclotomicRing54(littleEndianBytes: Array(bytes[offset..<offset + ringByteCount]))
        }
        return AjtaiCommitment(elements)
    }
}

final class MetalDifferentialTests: SuperNeoTestCase {
    // MARK: - Tier 0: Metal differential kernels

    func testTier0CPURedundantMetalPolicyVerifiesFoldOutputs() throws {
        let device = try requireMetalDevice()
        let context = try MetalExecutionContext(device: device)
        let fixture = try makeFoldFixture()
        let prover = SuperNeoProver(
            key: fixture.key,
            context: context,
            executionPolicy: .cpuRedundantMetal
        )
        let verifier = SuperNeoVerifier(
            key: fixture.key,
            context: context,
            executionPolicy: .cpuRedundantMetal
        )

        let fold = try prover.foldWithOutput(fixture.input, transcriptSeed: fixture.seed)
        let reduction = verifier.reduceFold(input: fixture.input, proof: fold.proof, transcriptSeed: fixture.seed)

        XCTAssertTrue(reduction.isReductionAccepted, reduction.reason ?? "")
        XCTAssertEqual(
            verifier.verifyFold(
                input: fixture.input,
                proof: fold.proof,
                outputClaims: fold.outputClaims,
                transcriptSeed: fixture.seed
            ),
            .valid
        )
    }

    func testTier0PreparedMetalFoldContextMatchesCPUOracle() throws {
        let device = try requireMetalDevice()
        let context = try MetalExecutionContext(device: device)
        let fixture = try makeFoldFixture()
        let cpuReference = try SuperNeoProver(key: fixture.key).foldWithOutput(
            fixture.input,
            transcriptSeed: fixture.seed
        )
        let prover = SuperNeoProver(key: fixture.key, context: context)
        let preparedContext = try prover.prepareFoldContext(for: fixture.input)
        let forcedMetalProver = SuperNeoProver(
            key: fixture.key,
            context: context,
            executionPolicy: .metalAccelerated
        )
        let forcedMetalPreparedContext = try forcedMetalProver.prepareFoldContext(for: fixture.input)

        let prepared = try prover.foldWithOutput(
            fixture.input,
            transcriptSeed: fixture.seed,
            preparedContext: preparedContext
        )
        let forcedMetalPrepared = try forcedMetalProver.foldWithOutput(
            fixture.input,
            transcriptSeed: fixture.seed,
            preparedContext: forcedMetalPreparedContext
        )
        let highAssurancePreparedContext = try SuperNeoProver(
            key: fixture.key,
            context: context,
            executionPolicy: .highAssurance
        ).prepareFoldContext(for: fixture.input)

        XCTAssertNil(preparedContext.metalWorkspace)
        XCTAssertNotNil(forcedMetalPreparedContext.metalWorkspace)
        XCTAssertEqual(prepared, cpuReference)
        XCTAssertEqual(forcedMetalPrepared, cpuReference)
        XCTAssertNil(highAssurancePreparedContext.metalWorkspace)
    }

    func testTier0MetalSeededDifferentialCorpusMatchesCPUOracle() throws {
        let device = try requireMetalDevice()
        let context = try MetalExecutionContext(device: device)
        let backend = SuperNeoMetalBackend(context: context)
        var generator = SeededTestGenerator(seed: 0x4D45_5441_4C44_4946)
        var lhs = (0..<128).map { _ in generator.field() }
        var rhs = (0..<128).map { _ in generator.field() }
        lhs.replaceSubrange(0..<6, with: [
            .zero,
            .one,
            GoldilocksField(1 << 32),
            GoldilocksField((1 << 32) - 1),
            GoldilocksField(GoldilocksField.modulus - 1),
            GoldilocksField(UInt64.max)
        ])
        rhs.replaceSubrange(0..<6, with: [
            .one,
            GoldilocksField(GoldilocksField.modulus - 1),
            GoldilocksField(7),
            GoldilocksField(GoldilocksField.modulus - 2),
            GoldilocksField(11),
            GoldilocksField(1 << 32)
        ])

        XCTAssertEqual(try backend.add(lhs, rhs), zip(lhs, rhs).map(+))
        XCTAssertEqual(try backend.subtract(lhs, rhs), zip(lhs, rhs).map(-))
        XCTAssertEqual(try backend.multiply(lhs, rhs), zip(lhs, rhs).map(*))

        let multiplicationBoundaries = [
            GoldilocksField.zero,
            .one,
            GoldilocksField(2),
            GoldilocksField(1 << 32),
            GoldilocksField((1 << 32) - 1),
            GoldilocksField((1 << 32) + 1),
            GoldilocksField(GoldilocksField.modulus - 3),
            GoldilocksField(GoldilocksField.modulus - 2),
            GoldilocksField(GoldilocksField.modulus - 1)
        ]
        var boundaryLhs: [GoldilocksField] = []
        var boundaryRhs: [GoldilocksField] = []
        for lhs in multiplicationBoundaries {
            for rhs in multiplicationBoundaries {
                boundaryLhs.append(lhs)
                boundaryRhs.append(rhs)
            }
        }
        XCTAssertEqual(try backend.multiply(boundaryLhs, boundaryRhs), zip(boundaryLhs, boundaryRhs).map(*))

        let rings = (0..<8).map { _ in generator.ring() }
        let otherRings = (0..<8).map { _ in generator.ring() }
        let scalars = (0..<8).map { _ in generator.field() }
        XCTAssertEqual(try backend.add(rings, otherRings), zip(rings, otherRings).map(+))
        XCTAssertEqual(try backend.multiply(rings, by: scalars), zip(rings, scalars).map { $0.scaled(by: $1) })
        XCTAssertEqual(try backend.multiply(rings, otherRings), zip(rings, otherRings).map(*))

        func sparseRing(_ entries: [(Int, GoldilocksField)]) -> CyclotomicRing54 {
            var coefficients = Array(repeating: GoldilocksField.zero, count: CyclotomicRing54.degree)
            for (index, value) in entries {
                coefficients[index] = value
            }
            return CyclotomicRing54(coefficients)
        }

        let smallScalars: [GoldilocksField] = [
            .zero,
            .one,
            GoldilocksField(2),
            -GoldilocksField.one,
            -GoldilocksField(2),
            GoldilocksField(3),
            GoldilocksField(5),
            -GoldilocksField(7)
        ]
        XCTAssertEqual(
            try backend.multiply(rings, by: smallScalars),
            zip(rings, smallScalars).map { $0.scaled(by: $1) }
        )

        let sparseSmallRings = [
            sparseRing([(0, .one), (53, -GoldilocksField(2))]),
            sparseRing([(3, GoldilocksField(2)), (41, -GoldilocksField.one)])
        ]
        let sparseSmallOtherRings = [
            sparseRing([(1, .one), (28, GoldilocksField(2))]),
            sparseRing([(0, -GoldilocksField.one), (52, -GoldilocksField(2))])
        ]
        XCTAssertEqual(
            try backend.multiply(sparseSmallRings, sparseSmallOtherRings),
            zip(sparseSmallRings, sparseSmallOtherRings).map(*)
        )

        let key = try AjtaiCommitmentKey(columns: 3, seed: Array("metal-ajtai-seeded".utf8))
        let message = (0..<3).map { _ in generator.ring() }
        XCTAssertEqual(
            try backend.ajtaiCommitment(key: key, message: message),
            try AjtaiCommitter.commitReference(key: key, message: message)
        )
        let smallMessage = [
            sparseRing([(0, .one), (13, GoldilocksField(2)), (53, -GoldilocksField.one)]),
            sparseRing([(1, -GoldilocksField(2)), (27, .one)]),
            sparseRing([(5, .one), (40, GoldilocksField(2))])
        ]
        let smallProfile = try AjtaiCommitter.workProfile(key: key, message: smallMessage)
        XCTAssertTrue(smallProfile.usesOnlySmallCoefficientScalings)
        XCTAssertLessThan(smallProfile.activeRotationTerms, key.matrix.rows * key.matrix.columns * CyclotomicRing54.degree)
        let smallReference = try AjtaiCommitter.commitReference(key: key, message: smallMessage)
        XCTAssertEqual(try backend.ajtaiCommitment(key: key, message: smallMessage), smallReference)
        let smallTiledSchedule = try AjtaiMatvecSchedule(
            columnTileSize: 2,
            rowTileSize: 2,
            maxBatchSize: 2,
            kernel: .tiled
        )
        XCTAssertEqual(
            try backend.ajtaiCommitments(
                key: key,
                messages: [smallMessage, smallMessage],
                schedule: smallTiledSchedule
            ),
            [smallReference, smallReference]
        )

        let matrix = try RingMatrix(
            rows: 4,
            columns: 3,
            elements: (0..<12).map { _ in generator.ring() }
        )
        let sparseMatrix = try SparseRingMatrixCSR(matrix)
        let vector = (0..<3).map { _ in generator.ring() }
        let rows = try matrix.multiplied(by: vector)
        let sparseRows = try sparseMatrix.multiplied(by: vector)
        let point = [generator.ext2(), generator.ext2()]
        let rHat = try MultilinearEvaluation.checkedBasis(at: point)

        XCTAssertEqual(sparseRows, rows)
        XCTAssertEqual(try backend.transformedMatrixVector(matrix: matrix, vector: vector), rows)
        XCTAssertEqual(try backend.transformedMatrixVector(matrix: sparseMatrix, vector: vector), rows)
        XCTAssertEqual(try backend.transformedEvaluation(rows: rows, rHat: rHat), directTransformedEvaluation(rows: rows, rHat: rHat))
        XCTAssertEqual(try backend.transformedEvaluation(matrix: matrix, vector: vector, point: point), directTransformedEvaluation(rows: rows, rHat: rHat))
        XCTAssertEqual(try backend.transformedEvaluation(matrix: sparseMatrix, vector: vector, point: point), directTransformedEvaluation(rows: rows, rHat: rHat))

        var wideDenseElements = Array(repeating: CyclotomicRing54.zero, count: 2 * 128)
        for row in 0..<2 {
            for column in [row, row + 17, row + 93] {
                wideDenseElements[row * 128 + column] = generator.ring()
            }
        }
        let wideDenseMatrix = try RingMatrix(rows: 2, columns: 128, elements: wideDenseElements)
        let wideDenseVector = (0..<128).map { _ in generator.ring() }
        XCTAssertEqual(
            try backend.transformedMatrixVector(matrix: wideDenseMatrix, vector: wideDenseVector),
            try wideDenseMatrix.multiplied(by: wideDenseVector)
        )

        let secondVector = (0..<3).map { _ in generator.ring() }
        let secondRows = try sparseMatrix.multiplied(by: secondVector)
        let batchedEvaluations = try backend.transformedEvaluations(
            matrices: [sparseMatrix, sparseMatrix],
            vectors: [vector, secondVector],
            point: point
        )
        XCTAssertEqual(batchedEvaluations[0][0].coefficients, directTransformedEvaluation(rows: rows, rHat: rHat))
        XCTAssertEqual(batchedEvaluations[0][1].coefficients, directTransformedEvaluation(rows: rows, rHat: rHat))
        XCTAssertEqual(batchedEvaluations[1][0].coefficients, directTransformedEvaluation(rows: secondRows, rHat: rHat))
        XCTAssertEqual(batchedEvaluations[1][1].coefficients, directTransformedEvaluation(rows: secondRows, rHat: rHat))

        let workspace = try SuperNeoMetalWorkspace(
            context: context,
            key: key,
            transformedSparseMatrices: [sparseMatrix]
        )
        let mismatchedSparseMatrix = try SparseRingMatrixCSR(
            rows: sparseMatrix.rows,
            columns: key.matrix.columns + 1,
            rowOffsets: Array(repeating: 0, count: sparseMatrix.rows + 1),
            columnIndices: [],
            values: []
        )
        XCTAssertThrowsSuperNeoError(
            try SuperNeoMetalWorkspace(
                context: context,
                key: key,
                transformedSparseMatrices: [mismatchedSparseMatrix]
            ),
            .invalidParameter("transformed matrix column count must match Ajtai key columns")
        )
        XCTAssertEqual(
            try workspace.ajtaiCommitments(messages: [message, message]),
            [
                try AjtaiCommitter.commitReference(key: key, message: message),
                try AjtaiCommitter.commitReference(key: key, message: message)
            ]
        )
        let tiledSchedule = try AjtaiMatvecSchedule(columnTileSize: 1, rowTileSize: 2, maxBatchSize: 1, kernel: .tiled)
        XCTAssertEqual(
            try workspace.ajtaiCommitments(messages: [message, message], schedule: tiledSchedule),
            [
                try AjtaiCommitter.commitReference(key: key, message: message),
                try AjtaiCommitter.commitReference(key: key, message: message)
            ]
        )
        XCTAssertEqual(
            try workspace.ajtaiCommitments(messages: [message], executionPolicy: .cpuRedundantMetal),
            [try AjtaiCommitter.commitReference(key: key, message: message)]
        )
        XCTAssertEqual(
            try workspace.ajtaiCommitments(messages: [message], executionPolicy: .highAssurance),
            [try AjtaiCommitter.commitConstantWorkReference(key: key, message: message)]
        )
        let workspaceEvaluations = try workspace.transformedEvaluations(
            vectors: [vector, secondVector],
            point: point
        )
        XCTAssertEqual(workspaceEvaluations[0][0].coefficients, directTransformedEvaluation(rows: rows, rHat: rHat))
        XCTAssertEqual(workspaceEvaluations[1][0].coefficients, directTransformedEvaluation(rows: secondRows, rHat: rHat))
        let checkedWorkspaceEvaluations = try workspace.transformedEvaluations(
            vectors: [vector],
            point: point,
            executionPolicy: .cpuRedundantMetal
        )
        XCTAssertEqual(checkedWorkspaceEvaluations[0][0].coefficients, directTransformedEvaluation(rows: rows, rHat: rHat))
        let combinedWorkspaceResults = try workspace.commitmentsAndTransformedEvaluations(
            messages: [vector, secondVector],
            point: point
        )
        XCTAssertEqual(combinedWorkspaceResults.commitments, [
            try AjtaiCommitter.commitReference(key: key, message: vector),
            try AjtaiCommitter.commitReference(key: key, message: secondVector)
        ])
        XCTAssertEqual(combinedWorkspaceResults.evaluations[0][0].coefficients, directTransformedEvaluation(rows: rows, rHat: rHat))
        XCTAssertEqual(combinedWorkspaceResults.evaluations[1][0].coefficients, directTransformedEvaluation(rows: secondRows, rHat: rHat))
        let combinedTiledSchedule = try AjtaiMatvecSchedule(
            columnTileSize: 1,
            rowTileSize: 2,
            maxBatchSize: 2,
            kernel: .tiled
        )
        let tiledCombinedWorkspaceResults = try workspace.commitmentsAndTransformedEvaluations(
            messages: [vector, secondVector],
            point: point,
            schedule: combinedTiledSchedule
        )
        XCTAssertEqual(tiledCombinedWorkspaceResults.commitments, combinedWorkspaceResults.commitments)
        XCTAssertEqual(tiledCombinedWorkspaceResults.evaluations, combinedWorkspaceResults.evaluations)
        let highAssuranceCombinedWorkspaceResults = try workspace.commitmentsAndTransformedEvaluations(
            messages: [vector],
            point: point,
            executionPolicy: .highAssurance
        )
        XCTAssertEqual(
            highAssuranceCombinedWorkspaceResults.commitments,
            [try AjtaiCommitter.commitConstantWorkReference(key: key, message: vector)]
        )
        XCTAssertEqual(
            highAssuranceCombinedWorkspaceResults.evaluations[0][0].coefficients,
            directTransformedEvaluation(rows: rows, rHat: rHat)
        )

        let blockedRows = 1024
        let blockedColumns = 3
        func blockedRing(row: Int, bias: Int) -> CyclotomicRing54 {
            var coefficients = Array(repeating: GoldilocksField.zero, count: CyclotomicRing54.degree)
            coefficients[(row + bias) % CyclotomicRing54.degree] = GoldilocksField(UInt64((row % 251) + 1))
            coefficients[(row * 7 + bias + 11) % CyclotomicRing54.degree] = GoldilocksField(UInt64((row % 127) + 2))
            return CyclotomicRing54(coefficients)
        }

        func blockedSparseMatrix(bias: Int, extraEntryStride: Int) throws -> SparseRingMatrixCSR {
            var rowOffsets = [0]
            var columnIndices: [Int] = []
            var values: [CyclotomicRing54] = []
            for row in 0..<blockedRows {
                var entries = [((row + bias) % blockedColumns, blockedRing(row: row, bias: bias))]
                if row % extraEntryStride == 0 {
                    entries.append(((row + bias + 1) % blockedColumns, blockedRing(row: row, bias: bias + 19)))
                }
                for (column, value) in entries.sorted(by: { $0.0 < $1.0 }) {
                    columnIndices.append(column)
                    values.append(value)
                }
                rowOffsets.append(columnIndices.count)
            }
            return try SparseRingMatrixCSR(
                rows: blockedRows,
                columns: blockedColumns,
                rowOffsets: rowOffsets,
                columnIndices: columnIndices,
                values: values
            )
        }

        let blockedMatrices = [
            try blockedSparseMatrix(bias: 1, extraEntryStride: 5),
            try blockedSparseMatrix(bias: 2, extraEntryStride: 7)
        ]
        let blockedPoint = (0..<10).map { index -> GoldilocksExt2 in
            let c0 = GoldilocksField(UInt64(index + 2))
            let c1 = GoldilocksField(UInt64(index * 3 + 5))
            return GoldilocksExt2(c0, c1)
        }
        let blockedRHat = try MultilinearEvaluation.checkedBasis(at: blockedPoint)
        let blockedVectors = [vector, secondVector]
        let blockedWorkspace = try SuperNeoMetalWorkspace(
            context: context,
            key: key,
            transformedSparseMatrices: blockedMatrices
        )
        let blockedEvaluations = try blockedWorkspace.transformedEvaluations(
            vectors: blockedVectors,
            point: blockedPoint
        )
        let blockedCombined = try blockedWorkspace.commitmentsAndTransformedEvaluations(
            messages: blockedVectors,
            point: blockedPoint
        )
        XCTAssertEqual(blockedCombined.commitments, try blockedVectors.map {
            try AjtaiCommitter.commitReference(key: key, message: $0)
        })
        for vectorIndex in blockedVectors.indices {
            for matrixIndex in blockedMatrices.indices {
                let blockedMatrixRows = try blockedMatrices[matrixIndex].multiplied(by: blockedVectors[vectorIndex])
                XCTAssertEqual(
                    blockedEvaluations[vectorIndex][matrixIndex].coefficients,
                    directTransformedEvaluation(rows: blockedMatrixRows, rHat: blockedRHat)
                )
                XCTAssertEqual(
                    blockedCombined.evaluations[vectorIndex][matrixIndex].coefficients,
                    directTransformedEvaluation(rows: blockedMatrixRows, rHat: blockedRHat)
                )
            }
        }
    }

    func testTier0NumiSealMetalProvingKernelsMatchCPUOracles() throws {
        let device = try requireMetalDevice()
        let context = try MetalExecutionContext(device: device)
        let backend = SuperNeoMetalBackend(context: context)
        var generator = SeededTestGenerator(seed: 0x4E55_4D49_5A4B_4D54)

        let digitTensor = (0..<4).map { _ in generator.ring() }
        let mask = (0..<4).map { _ in generator.ring() }
        XCTAssertEqual(
            try backend.numiSealApplyMask(digitTensor: digitTensor, mask: mask),
            try SuperNeoMetalBackend.numiSealApplyMaskReference(digitTensor: digitTensor, mask: mask)
        )

        let lhs = (0..<128).map { _ in generator.field() }
        let rhs = (0..<128).map { _ in generator.field() }
        let challenge = generator.field()
        XCTAssertEqual(
            try backend.numiSealDenseFold(lhs: lhs, rhs: rhs, challenge: challenge),
            try SuperNeoMetalBackend.numiSealDenseFoldReference(lhs: lhs, rhs: rhs, challenge: challenge)
        )

        let equalityPoint = (0..<6).map { _ in generator.field() }
        XCTAssertEqual(
            try backend.numiSealEqualityWeights(point: equalityPoint),
            try SuperNeoMetalBackend.numiSealEqualityWeightsReference(point: equalityPoint)
        )

        let terms = (0..<5).map { _ in (0..<64).map { _ in generator.field() } }
        let weights = (0..<5).map { _ in generator.field() }
        XCTAssertEqual(
            try backend.numiSealSumcheckAccumulate(terms: terms, weights: weights),
            try SuperNeoMetalBackend.numiSealSumcheckAccumulateReference(terms: terms, weights: weights)
        )

        let fusedWeights = Array(weights.prefix(3))
        XCTAssertEqual(
            try backend.numiSealApplyMaskAndAccumulate(
                digitTensor: digitTensor,
                mask: mask,
                weights: fusedWeights
            ),
            try SuperNeoMetalBackend.numiSealApplyMaskAndAccumulateReference(
                digitTensor: digitTensor,
                mask: mask,
                weights: fusedWeights
            )
        )

        let fixture = try makeFoldFixture()
        let baseWorkspace = try SuperNeoMetalWorkspace(
            context: context,
            key: fixture.key,
            compiledShape: fixture.input.shape.compiledSparseForSuperNeo()
        )
        let provingWorkspace = NumiSealMetalProvingWorkspace(
            baseWorkspace: baseWorkspace,
            provingPolicy: .zkRedundantMetal
        )
        XCTAssertTrue(provingWorkspace.supportedStages.contains("sumcheck-polynomial-accumulation"))
        XCTAssertTrue(provingWorkspace.supportedStages.contains("fused-mask-sumcheck-accumulation"))
        XCTAssertEqual(
            try provingWorkspace.applyMask(digitTensor: digitTensor, mask: mask),
            try SuperNeoMetalBackend.numiSealApplyMaskReference(digitTensor: digitTensor, mask: mask)
        )
        XCTAssertEqual(
            try provingWorkspace.denseFold(lhs: lhs, rhs: rhs, challenge: challenge),
            try SuperNeoMetalBackend.numiSealDenseFoldReference(lhs: lhs, rhs: rhs, challenge: challenge)
        )
        XCTAssertEqual(
            try provingWorkspace.equalityWeights(point: equalityPoint),
            try SuperNeoMetalBackend.numiSealEqualityWeightsReference(point: equalityPoint)
        )
        XCTAssertEqual(
            try provingWorkspace.sumcheckAccumulate(terms: terms, weights: weights),
            try SuperNeoMetalBackend.numiSealSumcheckAccumulateReference(terms: terms, weights: weights)
        )
        XCTAssertEqual(
            try provingWorkspace.applyMaskAndAccumulate(
                digitTensor: digitTensor,
                mask: mask,
                weights: fusedWeights
            ),
            try SuperNeoMetalBackend.numiSealApplyMaskAndAccumulateReference(
                digitTensor: digitTensor,
                mask: mask,
                weights: fusedWeights
            )
        )
    }

}

struct SeededTestGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        state = state &* 0x9E37_79B9_7F4A_7C15 &+ 0xD1B5_4A32_D192_ED03
        var value = state
        value ^= value >> 30
        value &*= 0xBF58_476D_1CE4_E5B9
        value ^= value >> 27
        value &*= 0x94D0_49BB_1331_11EB
        value ^= value >> 31
        return value
    }

    mutating func field() -> GoldilocksField {
        GoldilocksField(next())
    }

    mutating func ext2() -> GoldilocksExt2 {
        GoldilocksExt2(field(), field())
    }

    mutating func ring() -> CyclotomicRing54 {
        CyclotomicRing54((0..<CyclotomicRing54.degree).map { _ in field() })
    }
}

private struct ReferenceDeterministicRNG {
    private let seed: [UInt8]
    private var counter: UInt64 = 0
    private var buffer: [UInt8] = []
    private var offset: Int = 0

    init(seed: [UInt8]) {
        self.seed = seed
    }

    mutating func nextUInt64() -> UInt64 {
        var bytes: [UInt8] = []
        bytes.reserveCapacity(8)
        while bytes.count < 8 {
            if offset == buffer.count {
                refill()
            }
            let take = min(8 - bytes.count, buffer.count - offset)
            bytes.append(contentsOf: buffer[offset..<offset + take])
            offset += take
        }
        return bytes.enumerated().reduce(UInt64(0)) { acc, pair in
            acc | (UInt64(pair.element) << UInt64(pair.offset * 8))
        }
    }

    mutating func nextField() -> GoldilocksField {
        var value = nextUInt64()
        while value >= GoldilocksField.modulus {
            value = nextUInt64()
        }
        return GoldilocksField(value)
    }

    mutating func nextExt2() -> GoldilocksExt2 {
        GoldilocksExt2(nextField(), nextField())
    }

    mutating func nextChallengeRing(parameters: SuperNeoParameters = .goldilocks) -> CyclotomicRing54 {
        let choices = parameters.challengeCoefficients
        var coeffs = Array(repeating: GoldilocksField.zero, count: CyclotomicRing54.degree)
        for coefficientIndex in 0..<CyclotomicRing54.degree {
            let choiceIndex = nextUniformIndex(upperBound: choices.count)
            let value = choices[choiceIndex]
            coeffs[coefficientIndex] = value >= 0
                ? GoldilocksField(UInt64(value))
                : -GoldilocksField(UInt64(-value))
        }
        return CyclotomicRing54(coeffs)
    }

    private mutating func nextUniformIndex(upperBound: Int) -> Int {
        guard upperBound > 1 else { return 0 }
        let bound = UInt64(upperBound)
        let limit = UInt64.max - (UInt64.max % bound)
        while true {
            let value = nextUInt64()
            if value < limit {
                return Int(value % bound)
            }
        }
    }

    private mutating func refill() {
        let counterBytes = withUnsafeBytes(of: counter.littleEndian, Array.init)
        let digest = SHA256.hash(data: Data(seed + counterBytes))
        buffer = Array(digest)
        offset = 0
        counter &+= 1
    }
}

extension SuperNeoTestCase {

    func directMultilinearEvaluation(_ vector: [GoldilocksField], at point: [GoldilocksExt2]) -> GoldilocksExt2 {
        var accumulator = GoldilocksExt2.zero
        for (index, value) in vector.enumerated() {
            var weight = GoldilocksExt2.one
            for dimension in point.indices {
                weight = weight * (((index >> dimension) & 1) == 0 ? (.one - point[dimension]) : point[dimension])
            }
            accumulator = accumulator + GoldilocksExt2(value) * weight
        }
        return accumulator
    }

    func directMultilinearBasis(at point: [GoldilocksExt2]) -> [GoldilocksExt2] {
        (0..<(1 << point.count)).map { index in
            point.indices.reduce(GoldilocksExt2.one) { weight, dimension in
                weight * (((index >> dimension) & 1) == 0 ? (.one - point[dimension]) : point[dimension])
            }
        }
    }

    func directTransformedEvaluation(rows: [CyclotomicRing54], rHat: [GoldilocksExt2]) -> [GoldilocksExt2] {
        var output = Array(repeating: GoldilocksExt2.zero, count: CyclotomicRing54.degree)
        for (row, weight) in zip(rows, rHat) {
            for coefficient in 0..<CyclotomicRing54.degree {
                output[coefficient] = output[coefficient] + GoldilocksExt2(row[coefficient]) * weight
            }
        }
        return output
    }

    func referenceRingProduct(_ lhs: CyclotomicRing54, _ rhs: CyclotomicRing54) -> CyclotomicRing54 {
        var product = Array(repeating: GoldilocksField.zero, count: (CyclotomicRing54.degree * 2) - 1)
        for i in 0..<CyclotomicRing54.degree where lhs[i] != .zero {
            for j in 0..<CyclotomicRing54.degree where rhs[j] != .zero {
                product[i + j] = product[i + j] + lhs[i] * rhs[j]
            }
        }
        for exponent in stride(from: product.count - 1, through: CyclotomicRing54.degree, by: -1) {
            let value = product[exponent]
            product[exponent] = .zero
            let shifted = exponent - CyclotomicRing54.degree
            product[shifted] = product[shifted] - value
            product[shifted + 27] = product[shifted + 27] - value
        }
        return CyclotomicRing54(Array(product.prefix(CyclotomicRing54.degree)))
    }

    func referenceExtensionRingProduct(
        _ lhs: CyclotomicRing54,
        _ rhs: CyclotomicExt2Ring54
    ) -> CyclotomicExt2Ring54 {
        var product = Array(repeating: GoldilocksExt2.zero, count: (CyclotomicRing54.degree * 2) - 1)
        for i in 0..<CyclotomicRing54.degree where lhs[i] != .zero {
            for j in 0..<CyclotomicRing54.degree where rhs[j] != .zero {
                product[i + j] = product[i + j] + GoldilocksExt2(lhs[i]) * rhs[j]
            }
        }
        for exponent in stride(from: product.count - 1, through: CyclotomicRing54.degree, by: -1) {
            let value = product[exponent]
            product[exponent] = .zero
            let shifted = exponent - CyclotomicRing54.degree
            product[shifted] = product[shifted] - value
            product[shifted + 27] = product[shifted + 27] - value
        }
        return CyclotomicExt2Ring54(Array(product.prefix(CyclotomicRing54.degree)))
    }

    func independentUnitVectorTransformedMatrix(_ matrix: SparseFieldMatrix) throws -> RingMatrix {
        let ringColumns = (matrix.columns + CyclotomicRing54.degree - 1) / CyclotomicRing54.degree
        var elements = Array(repeating: CyclotomicRing54.zero, count: matrix.rows * ringColumns)
        for entry in matrix.entries where entry.value != .zero {
            var unit = Array(repeating: GoldilocksField.zero, count: CyclotomicRing54.degree)
            unit[entry.column % CyclotomicRing54.degree] = entry.value
            let transformed = CyclotomicRing54(try CyclotomicRing54.innerProductTransform(unit))
            let elementIndex = entry.row * ringColumns + entry.column / CyclotomicRing54.degree
            elements[elementIndex] = elements[elementIndex] + transformed
        }
        return try RingMatrix(rows: matrix.rows, columns: ringColumns, elements: elements)
    }

    func monomialRing(_ exponent: Int) -> CyclotomicRing54 {
        var coefficients = Array(repeating: GoldilocksField.zero, count: exponent + 1)
        coefficients[exponent] = .one
        return CyclotomicRing54(coefficients)
    }

    func XCTAssertThrowsSuperNeoError<T>(
        _ expression: @autoclosure () throws -> T,
        _ expected: SuperNeoError,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try expression(), file: file, line: line) { error in
            XCTAssertEqual(error as? SuperNeoError, expected, file: file, line: line)
        }
    }

    func XCTAssertInvalid(
        _ result: VerificationResult,
        reason: String? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertFalse(result.isValid, file: file, line: line)
        if let reason {
            XCTAssertEqual(result.reason, reason, file: file, line: line)
        }
    }

    func XCTAssertInvalid(
        _ result: FoldReductionResult,
        reason: String? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertFalse(result.isReductionAccepted, file: file, line: line)
        XCTAssertFalse(result.requiresTerminalRelationCheck, file: file, line: line)
        if let reason {
            XCTAssertEqual(result.reason, reason, file: file, line: line)
        }
    }

    func unitCommitment(parameters: SuperNeoParameters) -> AjtaiCommitment {
        AjtaiCommitment([CyclotomicRing54.one] + Array(repeating: .zero, count: parameters.kappa - 1))
    }

    func invalidCEOpeningProof(openingCount: Int) throws -> CEOpeningProof {
        let zeroDigest = try Digest256(Array(repeating: 0, count: Digest256.byteCount))
        let commitments = Array(
            repeating: CEOpeningProofCommitments(
                maskLinearDigest: zeroDigest,
                permutedMaskDigest: zeroDigest,
                permutedMaskedWitnessDigest: zeroDigest
            ),
            count: openingCount
        )
        let responses = Array(
            repeating: CEOpeningNormResponse(permutedMask: [], permutedWitness: []),
            count: openingCount
        )
        let round = CEOpeningProofRound(
            commitments: commitments,
            response: .permutedWitness(responses)
        )
        return try CEOpeningProof(
            rounds: Array(repeating: round, count: CEOpeningProof.roundCount)
        )
    }

    func replacing(
        _ proof: FoldProof,
        sumCheck: SumcheckProof? = nil,
        randomLinearCombinationChallenges: [CyclotomicRing54]? = nil,
        piCCSClaims: [CCSEvaluationClaim]? = nil,
        foldedClaim: CCSEvaluationClaim? = nil,
        decomposition: DecompositionProof? = nil,
        outputClaims: [CCSEvaluationClaim]? = nil,
        auxiliaryPiCCSTapes: [PiCCSSection]? = nil,
        auxiliaryPiRLCBranches: [PiRLCBranch]? = nil
    ) -> FoldProof {
        FoldProof(
            sumCheck: sumCheck ?? proof.sumCheck,
            randomLinearCombinationChallenges: randomLinearCombinationChallenges ?? proof.randomLinearCombinationChallenges,
            piCCSClaims: piCCSClaims ?? proof.piCCSClaims,
            foldedClaim: foldedClaim ?? proof.foldedClaim,
            decomposition: decomposition ?? proof.decomposition,
            outputClaims: outputClaims ?? proof.outputClaims,
            auxiliaryPiCCSTapes: auxiliaryPiCCSTapes ?? proof.auxiliaryPiCCSTapes,
            auxiliaryPiRLCBranches: auxiliaryPiRLCBranches ?? proof.auxiliaryPiRLCBranches
        )
    }

    func replacing(
        _ claim: CCSEvaluationClaim,
        commitment: AjtaiCommitment? = nil,
        publicInput: [GoldilocksField]? = nil,
        point: [GoldilocksExt2]? = nil,
        evaluations: [CyclotomicExt2Ring54]? = nil
    ) -> CCSEvaluationClaim {
        CCSEvaluationClaim(
            commitment: commitment ?? claim.commitment,
            publicInput: publicInput ?? claim.publicInput,
            point: point ?? claim.point,
            evaluations: evaluations ?? claim.evaluations,
            witness: claim.witness
        )
    }

    func removingWitness(from claim: CCSEvaluationClaim) -> CCSEvaluationClaim {
        CCSEvaluationClaim(
            commitment: claim.commitment,
            publicInput: claim.publicInput,
            point: claim.point,
            evaluations: claim.evaluations,
            witness: nil
        )
    }

    func writeUInt32(_ value: UInt32, into bytes: inout [UInt8], at offset: Int) {
        bytes.replaceSubrange(offset..<offset + 4, with: withUnsafeBytes(of: value.littleEndian, Array.init))
    }

    func writeUInt64(_ value: UInt64, into bytes: inout [UInt8], at offset: Int) {
        bytes.replaceSubrange(offset..<offset + 8, with: withUnsafeBytes(of: value.littleEndian, Array.init))
    }

    func makeEmptyFoldProofForShape(_ shape: CCSShape) -> FoldProof {
        let point = Array(repeating: GoldilocksExt2.zero, count: shape.m.trailingZeroBitCount)
        let emptyClaim = CCSEvaluationClaim(
            commitment: AjtaiCommitment([]),
            publicInput: [],
            point: point,
            evaluations: [CyclotomicExt2Ring54](),
            witness: nil as [GoldilocksField]?
        )
        return FoldProof(
            sumCheck: SumcheckProof(
                claimedSum: .zero,
                rounds: [],
                finalPoint: point,
                finalValue: .zero
            ),
            randomLinearCombinationChallenges: [],
            piCCSClaims: [],
            foldedClaim: emptyClaim,
            decomposition: DecompositionProof(commitments: [], evaluations: []),
            outputClaims: []
        )
    }

    struct PaperReferenceTranscriptState {
        let alpha: [GoldilocksExt2]
        let gamma: GoldilocksExt2
        let transcriptAfterSumcheck: SumCheckTranscript
    }

    func makePaperAuditFixture() throws -> (
        backend: SuperNeoCPUBackend,
        key: AjtaiCommitmentKey,
        input: SuperNeoFoldInput,
        seed: [UInt8]
    ) {
        let bootstrap = try makePaperAuditInput(priorClaims: [])
        let bootstrapFold = try bootstrap.backend.makeProver(key: bootstrap.key).foldWithOutput(
            bootstrap.input,
            transcriptSeed: Array("paper-audit-prior".utf8)
        )
        let priorClaims = Array(bootstrapFold.outputClaims.prefix(2))
        let input = try makePaperAuditInput(priorClaims: priorClaims)
        return (
            input.backend,
            input.key,
            input.input,
            Array("paper-audit-fold".utf8)
        )
    }

    func makePaperAuditInput(
        priorClaims: [CCSEvaluationClaim]
    ) throws -> (
        backend: SuperNeoCPUBackend,
        key: AjtaiCommitmentKey,
        input: SuperNeoFoldInput
    ) {
        let identity = try SparseFieldMatrix.identity(size: 64)
        let relation = try RelationPolynomial(
            variableCount: 2,
            monomials: [
                RelationMonomial(coefficient: .one, exponents: [1, 0]),
                RelationMonomial(coefficient: -GoldilocksField.one, exponents: [0, 1])
            ]
        )
        let shape = try CCSShape(
            matrices: [identity, identity],
            publicInputCount: CyclotomicRing54.degree,
            relationPolynomial: relation
        )
        let backend = SuperNeoCPUBackend()
        let key = try AjtaiCommitmentKey(columns: 2, seed: Array("paper-audit-key".utf8))
        let publicInputs = [
            (0..<CyclotomicRing54.degree).map { index in
                [GoldilocksField.one, -GoldilocksField.one, .zero][index % 3]
            },
            (0..<CyclotomicRing54.degree).map { index in
                [-GoldilocksField.one, .zero, GoldilocksField.one][index % 3]
            }
        ]
        let privateWitnesses = [
            (0..<10).map { index in [GoldilocksField.zero, GoldilocksField.one][index % 2] },
            (0..<10).map { index in [GoldilocksField.one, GoldilocksField.zero][index % 2] }
        ]
        let instances = try zip(publicInputs, privateWitnesses).map { publicInput, privateWitness in
            return CCSInstance(
                commitment: try backend.commit(key: key, message: publicInput + privateWitness),
                publicInput: publicInput
            )
        }
        let witnesses = privateWitnesses.map(CCSWitness.init)
        let input = SuperNeoFoldInput(
            shape: shape,
            instances: instances,
            witnesses: witnesses,
            priorClaims: priorClaims
        )
        return (backend, key, input)
    }

    func assertPiCCSMatchesPaperReference(
        input: SuperNeoPublicFoldInput,
        proof: FoldProof,
        seed: [UInt8]
    ) throws -> PaperReferenceTranscriptState {
        let label = selectedRepeatedTapeLabelPiCCS(0)
        var transcript = makePublicFoldTranscript(
            input: input,
            seed: repeatedTapeSeedForTest(base: seed, label: label),
            tapeLabel: label
        )
        let numVars = try log2ForTest(input.shape.m)
        let alpha = (0..<numVars).map { _ in transcript.challengeExt2() }
        let gamma = transcript.challengeExt2()
        let claimedSum = try paperReferenceClaimedSum(input: input, gamma: gamma)
        XCTAssertEqual(proof.sumCheck.claimedSum, claimedSum)

        let accepted = try SumcheckVerifier.verify(
            proof: proof.sumCheck,
            transcript: &transcript,
            expectedDegree: paperReferenceMaxDegreePerRound(shape: input.shape, parameters: .goldilocks),
            expectedRoundCount: numVars
        ) { point, value in
            try self.paperReferenceFinalQ(
                input: input,
                proofClaims: proof.piCCSClaims,
                point: point,
                alpha: alpha,
                gamma: gamma
            ) == value
        }
        XCTAssertTrue(accepted)
        XCTAssertEqual(proof.sumCheck.finalValue, try paperReferenceFinalQ(
            input: input,
            proofClaims: proof.piCCSClaims,
            point: proof.sumCheck.finalPoint,
            alpha: alpha,
            gamma: gamma
        ))

        return PaperReferenceTranscriptState(
            alpha: alpha,
            gamma: gamma,
            transcriptAfterSumcheck: transcript
        )
    }

    func assertPiRLCMatchesPaperReference(
        input: SuperNeoPublicFoldInput,
        proof: FoldProof,
        seed: [UInt8]
    ) throws {
        let label = selectedRepeatedTapeLabelPiRLC(0)
        var transcript = makePublicFoldTranscript(
            input: input,
            seed: repeatedTapeSeedForTest(
                base: seed,
                label: label,
                extra: repeatedPiRLCTranscriptExtraForTest(proof: proof)
            ),
            tapeLabel: label
        )
        transcript.absorb(proof.sumCheck.superNeoBytes)
        transcript.absorb(transcriptEncodeCount(proof.piCCSClaims.count))
        proof.piCCSClaims.forEach { transcript.absorb($0.superNeoBytes) }

        let expectedChallenges = proof.piCCSClaims.map { _ in transcript.challengeRing() }
        XCTAssertEqual(proof.randomLinearCombinationChallenges, expectedChallenges)
        XCTAssertStrongSamplingCapacity(
            freshCount: input.instances.count,
            priorCount: input.priorClaims.count,
            parameters: .goldilocks
        )
        expectedChallenges.forEach {
            XCTAssertStrongSamplingChallenge($0, parameters: .goldilocks)
        }

        let folded = try paperReferenceRandomLinearCombination(
            claims: proof.piCCSClaims,
            challenges: expectedChallenges
        )
        XCTAssertEqual(proof.foldedClaim.commitment, folded.commitment)
        XCTAssertEqual(proof.foldedClaim.publicInput, folded.publicInput)
        XCTAssertEqual(proof.foldedClaim.point, folded.point)
        XCTAssertEqual(proof.foldedClaim.evaluations, folded.evaluations)
    }

    func assertPiDECMatchesPaperReference(
        folded: CCSEvaluationClaim,
        proofOutputClaims: [CCSEvaluationClaim],
        witnessOutputClaims: [CCSEvaluationClaim],
        parameters: SuperNeoParameters
    ) throws {
        XCTAssertEqual(proofOutputClaims.count, parameters.decompositionLength)
        XCTAssertEqual(proofOutputClaims.count, witnessOutputClaims.count)
        for (proofClaim, witnessClaim) in zip(proofOutputClaims, witnessOutputClaims) {
            XCTAssertClaimsSharePublicData(proofClaim, witnessClaim)
            XCTAssertTrue(proofClaim.publicInput.allSatisfy { signedMagnitudeForTest($0) < UInt64(parameters.normBound) })
            guard let witness = witnessClaim.witness else {
                XCTFail("decomposition output claim is missing its local witness")
                continue
            }
            XCTAssertTrue(witness.allSatisfy { signedMagnitudeForTest($0) < UInt64(parameters.normBound) })
        }

        var commitment = AjtaiCommitment(Array(repeating: CyclotomicRing54.zero, count: folded.commitment.elements.count))
        let foldedPackedInput = try SuperNeoEmbedding.packPadded(folded.publicInput)
        var packedInput = Array(repeating: CyclotomicRing54.zero, count: foldedPackedInput.count)
        var evaluations = Array(repeating: CyclotomicExt2Ring54.zero, count: folded.evaluations.count)

        for (index, part) in proofOutputClaims.enumerated() {
            let scalar = try decompositionScalarForTest(base: parameters.normBound, exponent: index)
            for commitmentIndex in commitment.elements.indices {
                commitment.elements[commitmentIndex] = commitment.elements[commitmentIndex]
                    + scalar * part.commitment.elements[commitmentIndex]
            }

            let packedPartInput = try SuperNeoEmbedding.packPadded(part.publicInput)
            XCTAssertEqual(packedPartInput.count, packedInput.count)
            for inputIndex in packedInput.indices {
                packedInput[inputIndex] = packedInput[inputIndex] + scalar * packedPartInput[inputIndex]
            }
            for evalIndex in evaluations.indices {
                evaluations[evalIndex] = evaluations[evalIndex] + scalar * part.evaluations[evalIndex]
            }
        }

        XCTAssertEqual(commitment, folded.commitment)
        XCTAssertEqual(packedInput, foldedPackedInput)
        XCTAssertEqual(evaluations, folded.evaluations)
    }

    func paperReferenceClaimedSum(
        input: SuperNeoPublicFoldInput,
        gamma: GoldilocksExt2
    ) throws -> GoldilocksExt2 {
        let freshCount = input.instances.count
        let priorCount = input.priorClaims.count
        guard priorCount > 0 else { return .zero }

        var total = GoldilocksExt2.zero
        for priorIndex in input.priorClaims.indices {
            let claim = input.priorClaims[priorIndex]
            XCTAssertEqual(claim.evaluations.count, input.shape.numMatrices)
            for matrixIndex in 0..<input.shape.numMatrices {
                for coefficientIndex in 0..<CyclotomicRing54.degree {
                    let exponent = paperPriorExponent(
                        priorIndex: priorIndex,
                        matrixIndex: matrixIndex,
                        coefficientIndex: coefficientIndex,
                        priorCount: priorCount,
                        matrixCount: input.shape.numMatrices
                    )
                    total = total
                        + powExt2ForTest(gamma, exponent) * claim.evaluations[matrixIndex].coefficients[coefficientIndex]
                }
            }
        }
        return powExt2ForTest(gamma, (2 * freshCount) + priorCount) * total
    }

    func paperReferenceFinalQ(
        input: SuperNeoPublicFoldInput,
        proofClaims: [CCSEvaluationClaim],
        point: [GoldilocksExt2],
        alpha: [GoldilocksExt2],
        gamma: GoldilocksExt2
    ) throws -> GoldilocksExt2 {
        let freshCount = input.instances.count
        let priorCount = input.priorClaims.count
        XCTAssertEqual(proofClaims.count, freshCount + priorCount)

        var relationPart = GoldilocksExt2.zero
        for freshIndex in 0..<freshCount {
            let matrixValues = proofClaims[freshIndex].evaluations.map(\.constantTerm)
            relationPart = relationPart
                + powExt2ForTest(gamma, freshIndex) * (try input.shape.relationPolynomial.evaluate(matrixValues))
        }

        let normRoots = SuperNeoParameters.goldilocks.normRoots.map { GoldilocksExt2($0) }
        var normPart = GoldilocksExt2.zero
        for claimIndex in proofClaims.indices {
            guard let zAtPoint = proofClaims[claimIndex].evaluations.first?.constantTerm else {
                throw SuperNeoError.invalidParameter("paper reference claim is missing identity evaluation")
            }
            let product = normRoots.reduce(GoldilocksExt2.one) { partial, root in
                partial * (zAtPoint - root)
            }
            normPart = normPart + powExt2ForTest(gamma, claimIndex) * product
        }

        var priorEvalPart = GoldilocksExt2.zero
        if let priorPoint = input.priorClaims.first?.point {
            let eq = try MultilinearEvaluation.eq(point, priorPoint)
            var inner = GoldilocksExt2.zero
            for priorIndex in 0..<priorCount {
                let claim = proofClaims[freshCount + priorIndex]
                for matrixIndex in 0..<input.shape.numMatrices {
                    for coefficientIndex in 0..<CyclotomicRing54.degree {
                        let exponent = paperPriorExponent(
                            priorIndex: priorIndex,
                            matrixIndex: matrixIndex,
                            coefficientIndex: coefficientIndex,
                            priorCount: priorCount,
                            matrixCount: input.shape.numMatrices
                        )
                        inner = inner
                            + powExt2ForTest(gamma, exponent) * claim.evaluations[matrixIndex].coefficients[coefficientIndex]
                    }
                }
            }
            priorEvalPart = eq * inner
        }

        return try MultilinearEvaluation.eq(point, alpha)
            * (relationPart + powExt2ForTest(gamma, freshCount) * normPart)
            + powExt2ForTest(gamma, (2 * freshCount) + priorCount) * priorEvalPart
    }

    func paperReferenceRandomLinearCombination(
        claims: [CCSEvaluationClaim],
        challenges: [CyclotomicRing54]
    ) throws -> CCSEvaluationClaim {
        guard let first = claims.first else {
            throw SuperNeoError.invalidParameter("paper reference RLC needs at least one claim")
        }
        XCTAssertEqual(claims.count, challenges.count)

        var commitment = AjtaiCommitment(Array(repeating: CyclotomicRing54.zero, count: first.commitment.elements.count))
        let packedPublicInputCount = SuperNeoEmbedding.paddedLength(forFieldElementCount: first.publicInput.count)
        var publicInput = Array(repeating: CyclotomicRing54.zero, count: packedPublicInputCount / CyclotomicRing54.degree)
        var evaluations = Array(repeating: CyclotomicExt2Ring54.zero, count: first.evaluations.count)

        for (challenge, claim) in zip(challenges, claims) {
            XCTAssertEqual(claim.commitment.elements.count, commitment.elements.count)
            XCTAssertEqual(claim.point, first.point)
            XCTAssertEqual(claim.publicInput.count, first.publicInput.count)
            XCTAssertEqual(claim.evaluations.count, evaluations.count)

            for index in commitment.elements.indices {
                commitment.elements[index] = commitment.elements[index] + challenge * claim.commitment.elements[index]
            }

            let packedInput = try SuperNeoEmbedding.packPadded(claim.publicInput)
            XCTAssertEqual(packedInput.count, publicInput.count)
            for index in publicInput.indices {
                publicInput[index] = publicInput[index] + challenge * packedInput[index]
            }
            for index in evaluations.indices {
                evaluations[index] = evaluations[index] + challenge * claim.evaluations[index]
            }
        }

        return CCSEvaluationClaim(
            commitment: commitment,
            publicInput: Array(SuperNeoEmbedding.unpack(publicInput).prefix(first.publicInput.count)),
            point: first.point,
            evaluations: evaluations
        )
    }

    func paperReferenceMaxDegreePerRound(shape: CCSShape, parameters: SuperNeoParameters) -> Int {
        max(shape.relationDegree, parameters.normRoots.count) + 1
    }

    func paperPriorExponent(
        priorIndex: Int,
        matrixIndex: Int,
        coefficientIndex: Int,
        priorCount: Int,
        matrixCount: Int
    ) -> Int {
        priorIndex + priorCount * matrixIndex + priorCount * matrixCount * coefficientIndex
    }

    func powExt2ForTest(_ base: GoldilocksExt2, _ exponent: Int) -> GoldilocksExt2 {
        guard exponent > 0 else { return .one }
        return (0..<exponent).reduce(GoldilocksExt2.one) { value, _ in value * base }
    }

    func decompositionScalarForTest(base: Int, exponent: Int) throws -> CyclotomicRing54 {
        guard base > 0, exponent >= 0 else {
            throw SuperNeoError.invalidParameter("invalid decomposition scalar")
        }
        var value: UInt64 = 1
        for _ in 0..<exponent {
            let (next, overflow) = value.multipliedReportingOverflow(by: UInt64(base))
            guard !overflow else {
                throw SuperNeoError.invalidParameter("decomposition scalar overflow")
            }
            value = next
        }
        return CyclotomicRing54([GoldilocksField(value)])
    }

    func XCTAssertStrongSamplingCapacity(
        freshCount: Int,
        priorCount: Int,
        parameters: SuperNeoParameters,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let batchCount = UInt64(freshCount + priorCount)
        let left = batchCount
            * UInt64(parameters.challengeExpansionFactor)
            * UInt64(parameters.normBound - 1)
        let right = (0..<parameters.decompositionLength).reduce(UInt64(1)) { value, _ in
            value * UInt64(parameters.normBound)
        }
        XCTAssertLessThan(left, right, file: file, line: line)
    }

    func XCTAssertStrongSamplingChallenge(
        _ challenge: CyclotomicRing54,
        parameters: SuperNeoParameters,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let allowed = Set(parameters.challengeCoefficients.map(Int.init))
        for coefficient in challenge.coefficients {
            guard let centered = centeredSmallIntForTest(coefficient) else {
                XCTFail("challenge coefficient is outside the expected small range", file: file, line: line)
                continue
            }
            XCTAssertTrue(allowed.contains(centered), file: file, line: line)
        }
    }

    func XCTAssertClaimsSharePublicData(
        _ lhs: CCSEvaluationClaim,
        _ rhs: CCSEvaluationClaim,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(lhs.commitment, rhs.commitment, file: file, line: line)
        XCTAssertEqual(lhs.publicInput, rhs.publicInput, file: file, line: line)
        XCTAssertEqual(lhs.point, rhs.point, file: file, line: line)
        XCTAssertEqual(lhs.evaluations, rhs.evaluations, file: file, line: line)
    }

    func log2ForTest(_ value: Int) throws -> Int {
        guard value > 0, (value & (value - 1)) == 0 else {
            throw SuperNeoError.invalidParameter("test value must be a positive power of two")
        }
        return value.trailingZeroBitCount
    }

    func centeredFieldForTest(_ value: Int) -> GoldilocksField {
        value >= 0 ? GoldilocksField(UInt64(value)) : -GoldilocksField(UInt64(-value))
    }

    func centeredSmallIntForTest(_ value: GoldilocksField) -> Int? {
        if value.rawValue <= 2 { return Int(value.rawValue) }
        let negative = GoldilocksField.modulus - value.rawValue
        if negative <= 2 { return -Int(negative) }
        return nil
    }

    func makeForgedReductionFixture() throws -> (
        key: AjtaiCommitmentKey,
        publicInput: SuperNeoPublicFoldInput,
        proof: FoldProof,
        seed: [UInt8]
    ) {
        let publicInput = [GoldilocksField.one] + Array(repeating: GoldilocksField.zero, count: CyclotomicRing54.degree - 1)
        let shape = try CCSShape.hadamardProduct(
            matrices: [SparseFieldMatrix.identity(size: 64)],
            publicInputCount: publicInput.count
        )
        let key = try AjtaiCommitmentKey(columns: 2, seed: Array("forged-key".utf8))
        let committedInvalidWitness = publicInput + Array(repeating: GoldilocksField.zero, count: 10)
        let commitment = try SuperNeoCPUBackend().commit(key: key, message: committedInvalidWitness)
        let instance = CCSInstance(commitment: commitment, publicInput: publicInput)
        let publicFoldInput = SuperNeoPublicFoldInput(shape: shape, instances: [instance])
        let seed = Array("forged".utf8)

        var transcript = makePublicFoldTranscript(input: publicFoldInput, seed: seed)
        for _ in 0..<6 { _ = transcript.challengeExt2() }
        _ = transcript.challengeExt2()

        let claimedSum = GoldilocksExt2.zero
        transcript.absorb(claimedSum.superNeoBytes)
        var rounds: [SumcheckRound] = []
        var finalPoint: [GoldilocksExt2] = []
        for _ in 0..<6 {
            let round = SumcheckRound(coeffs: [.zero])
            rounds.append(round)
            transcript.absorb(round.superNeoBytes)
            finalPoint.append(transcript.challengeExt2())
        }
        let sumCheck = SumcheckProof(
            claimedSum: claimedSum,
            rounds: rounds,
            finalPoint: finalPoint,
            finalValue: .zero
        )

        let piClaim = CCSEvaluationClaim(
            commitment: commitment,
            publicInput: publicInput,
            point: finalPoint,
            evaluations: [CyclotomicExt2Ring54.zero]
        )
        transcript.absorb(transcriptEncodeCount(1))
        transcript.absorb(piClaim.superNeoBytes)
        let challenge = transcript.challengeRing()
        let foldedCommitment = commitment.scaled(by: challenge)
        let foldedInputRing = challenge * (try SuperNeoEmbedding.packPadded(publicInput))[0]
        let foldedPublicInput = Array(SuperNeoEmbedding.unpack([foldedInputRing]).prefix(publicInput.count))
        let foldedClaim = CCSEvaluationClaim(
            commitment: foldedCommitment,
            publicInput: foldedPublicInput,
            point: finalPoint,
            evaluations: [CyclotomicExt2Ring54.zero]
        )

        let publicInputLimbs = splitSignedBaseForTest(
            foldedPublicInput,
            base: key.parameters.normBound,
            count: key.parameters.decompositionLength
        )
        let outputClaims = (0..<key.parameters.decompositionLength).map { index in
            CCSEvaluationClaim(
                commitment: index == 0
                    ? foldedCommitment
                    : AjtaiCommitment(Array(repeating: CyclotomicRing54.zero, count: key.parameters.kappa)),
                publicInput: publicInputLimbs[index],
                point: finalPoint,
                evaluations: [CyclotomicExt2Ring54.zero]
            )
        }

        return (
            key,
            publicFoldInput,
            FoldProof(
                sumCheck: sumCheck,
                randomLinearCombinationChallenges: [challenge],
                piCCSClaims: [piClaim],
                foldedClaim: foldedClaim,
                decomposition: DecompositionProof(
                    commitments: outputClaims.map(\.commitment),
                    evaluations: outputClaims.map(\.evaluations)
                ),
                outputClaims: outputClaims
            ),
            seed
        )
    }

    func makePublicFoldTranscript(input: SuperNeoPublicFoldInput, seed: [UInt8]) -> SumCheckTranscript {
        makePublicFoldTranscript(input: input, seed: seed, tapeLabel: nil)
    }

    func makePublicFoldTranscript(
        input: SuperNeoPublicFoldInput,
        seed: [UInt8],
        tapeLabel: String?
    ) -> SumCheckTranscript {
        let labelBytes = tapeLabel.map { Array($0.utf8) } ?? []
        let labelFrame = tapeLabel == nil ? [] : transcriptEncodeCount(labelBytes.count) + labelBytes
        let contextSeed = seed
            + labelFrame
            + input.shape.shapeDigest.superNeoBytes
            + transcriptEncodeCount(input.instances.count)
            + input.instances.flatMap(\.superNeoBytes)
            + transcriptEncodeCount(input.priorClaims.count)
            + input.priorClaims.flatMap(\.superNeoBytes)
        let domainSeparator = tapeLabel.map { "SuperNeo-NuMetal.fold/\($0)" } ?? "SuperNeo-NuMetal.fold"
        var transcript = SumCheckTranscript(domainSeparator: domainSeparator, seed: contextSeed)
        if !labelBytes.isEmpty {
            transcript.absorb(labelBytes)
        }
        transcript.absorb(input.shape.shapeDigest.superNeoBytes)
        transcript.absorb(transcriptEncodeCount(input.instances.count))
        input.instances.forEach { transcript.absorb($0.superNeoBytes) }
        transcript.absorb(transcriptEncodeCount(input.priorClaims.count))
        input.priorClaims.forEach { transcript.absorb($0.superNeoBytes) }
        return transcript
    }

    func selectedRepeatedTapeLabelPiCCS(_ index: Int) -> String {
        "selected-repeated-tape-v1/piccs-tape-\(index)"
    }

    func selectedRepeatedTapeLabelPiRLC(_ index: Int) -> String {
        "selected-repeated-tape-v1/pirlc-branch-\(index)"
    }

    func repeatedTapeSeedForTest(base seed: [UInt8], label: String, extra: [UInt8] = []) -> [UInt8] {
        let version = Array("selected-repeated-tape-v1".utf8)
        let labelBytes = Array(label.utf8)
        return seed
            + transcriptEncodeCount(version.count)
            + version
            + transcriptEncodeCount(labelBytes.count)
            + labelBytes
            + transcriptEncodeCount(extra.count)
            + extra
    }

    func repeatedPiRLCTranscriptExtraForTest(proof: FoldProof) -> [UInt8] {
        proof.sumCheck.superNeoBytes
            + transcriptEncodeCount(proof.piCCSClaims.count)
            + proof.piCCSClaims.flatMap(\.superNeoBytes)
    }

    func transcriptEncodeCount(_ value: Int) -> [UInt8] {
        withUnsafeBytes(of: UInt64(value).littleEndian, Array.init)
    }

    func splitSignedBaseForTest(_ values: [GoldilocksField], base: Int, count: Int) -> [[GoldilocksField]] {
        var limbs = Array(repeating: Array(repeating: GoldilocksField.zero, count: values.count), count: count)
        let radix = UInt64(base)
        for (index, value) in values.enumerated() {
            var raw = signedMagnitudeForTest(value)
            let isNegative = value.rawValue > GoldilocksField.modulus / 2
            for limb in 0..<count {
                let digit = raw % radix
                if digit != 0 {
                    let fieldDigit = GoldilocksField(digit)
                    limbs[limb][index] = isNegative ? -fieldDigit : fieldDigit
                }
                raw /= radix
            }
        }
        return limbs
    }

    func signedMagnitudeForTest(_ value: GoldilocksField) -> UInt64 {
        value.rawValue <= GoldilocksField.modulus / 2
            ? value.rawValue
            : GoldilocksField.modulus - value.rawValue
    }

    func makeFoldFixture() throws -> (
        backend: SuperNeoCPUBackend,
        key: AjtaiCommitmentKey,
        input: SuperNeoFoldInput,
        seed: [UInt8]
    ) {
        let publicInput = Array(repeating: GoldilocksField.zero, count: CyclotomicRing54.degree)
        let privateWitness = Array(repeating: GoldilocksField.zero, count: 10)
        let matrix = try SparseFieldMatrix.identity(size: publicInput.count + privateWitness.count)
        let structure = CCSStructure.hadamardProduct(matrices: [matrix])
        let backend = SuperNeoCPUBackend()
        let key = try AjtaiCommitmentKey(
            columns: SuperNeoEmbedding.paddedLength(forFieldElementCount: publicInput.count + privateWitness.count) / CyclotomicRing54.degree,
            seed: Array("fold-key".utf8)
        )
        let commitment = try backend.commit(key: key, message: publicInput + privateWitness)
        let input = try SuperNeoFoldInput(
            structure: structure,
            instances: [CCSInstance(commitment: commitment, publicInput: publicInput)],
            witnesses: [CCSWitness(privateWitness)]
        )
        return (backend, key, input, Array("fold".utf8))
    }

    func makeEnvelopeContext(
        for input: SuperNeoFoldInput,
        profileID: UInt16 = 1,
        kind: ProofEnvelopeKind = .foldReduction,
        shapeDigest: Digest256? = nil,
        statementDigest: Digest256? = nil,
        verifierKeyDigest: Digest256 = .hash("test-verifier-key"),
        transcriptDomain: Digest256 = .hash("SuperNeo-NuMetal.fold.v1")
    ) -> ProofEnvelopeContext {
        let publicInput = SuperNeoPublicFoldInput(input)
        let statement = CCSStatement(
            shapeDigest: publicInput.shape.shapeDigest,
            ccsInstances: publicInput.instances,
            priorCEInstances: publicInput.priorClaims.map { CEInstance($0) }
        )
        return ProofEnvelopeContext(
            profileID: profileID,
            kind: kind,
            shapeDigest: shapeDigest ?? publicInput.shape.shapeDigest,
            statementDigest: statementDigest ?? statement.statementDigest,
            verifierKeyDigest: verifierKeyDigest,
            transcriptDomain: transcriptDomain
        )
    }

    func makeEnvelopeContext(
        profileID: UInt16 = 1,
        kind: ProofEnvelopeKind = .foldReduction,
        shapeDigest: Digest256 = .hash("test-shape"),
        statementDigest: Digest256 = .hash("test-statement"),
        verifierKeyDigest: Digest256 = .hash("test-verifier-key"),
        transcriptDomain: Digest256 = .hash("SuperNeo-NuMetal.fold.v1")
    ) -> ProofEnvelopeContext {
        ProofEnvelopeContext(
            profileID: profileID,
            kind: kind,
            shapeDigest: shapeDigest,
            statementDigest: statementDigest,
            verifierKeyDigest: verifierKeyDigest,
            transcriptDomain: transcriptDomain
        )
    }

    func makeToySumcheckProof() -> SumcheckProof {
        let claimed = GoldilocksExt2(GoldilocksField(31))
        var transcript = SumCheckTranscript(domainSeparator: "test.sumcheck")
        transcript.absorb(claimed.superNeoBytes)

        let round1 = SumcheckRound(coeffs: [
            GoldilocksExt2(GoldilocksField(9)),
            GoldilocksExt2(GoldilocksField(13))
        ])
        transcript.absorb(round1.superNeoBytes)
        let r1 = transcript.challengeExt2()

        let round2 = SumcheckRound(coeffs: [
            GoldilocksExt2(GoldilocksField(2)) + GoldilocksExt2(GoldilocksField(3)) * r1,
            GoldilocksExt2(GoldilocksField(5)) + GoldilocksExt2(GoldilocksField(7)) * r1
        ])
        transcript.absorb(round2.superNeoBytes)
        let r2 = transcript.challengeExt2()

        return SumcheckProof(
            claimedSum: claimed,
            rounds: [round1, round2],
            finalPoint: [r1, r2],
            finalValue: toySumcheckPolynomial(r1, r2)
        )
    }

    func toySumcheckPolynomial(_ x: GoldilocksExt2, _ y: GoldilocksExt2) -> GoldilocksExt2 {
        GoldilocksExt2(GoldilocksField(2))
            + GoldilocksExt2(GoldilocksField(3)) * x
            + GoldilocksExt2(GoldilocksField(5)) * y
            + GoldilocksExt2(GoldilocksField(7)) * x * y
    }
}
