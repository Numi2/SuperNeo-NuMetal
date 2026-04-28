import XCTest
@testable import SuperNeo_NuMetal

final class SuperNeoConcreteHashArithmetizationTests: SuperNeoTestCase {
    func testSHA256OneBlockCircuitMatchesDigest256Hash() throws {
        let message = Array("abc".utf8)
        let workload = try SuperNeoSHA256OneBlockHashWorkload(messageByteCount: message.count)
        let digest = try workload.digest(message: message)
        let publicInput = try workload.publicInput(digest: digest)
        let witness = try workload.privateWitness(message: message)

        XCTAssertEqual(digest, Digest256.hash(message))
        XCTAssertEqual(
            digest.hexString,
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        )
        XCTAssertEqual(publicInput.count, workload.publicInputCount)
        XCTAssertEqual(witness.count, workload.privateWitnessCount)
        XCTAssertTrue(witness.allSatisfy { $0 == .zero || $0 == .one })
        XCTAssertTrue(
            try workload.builder.validateWitness(
                publicInput: publicInput,
                privateWitness: witness
            )
        )
        XCTAssertEqual(workload.arithmetizationDigest, workload.arithmetizationDigest)
    }

    func testSHA256OneBlockCircuitRejectsWrongDigestAndTrace() throws {
        let message = Array("abc".utf8)
        let workload = try SuperNeoSHA256OneBlockHashWorkload(messageByteCount: message.count)
        let digest = try workload.digest(message: message)
        let publicInput = try workload.publicInput(digest: digest)
        let witness = try workload.privateWitness(message: message)

        var wrongPublicInput = publicInput
        wrongPublicInput[1] = .one - wrongPublicInput[1]
        XCTAssertFalse(
            try workload.builder.validateWitness(
                publicInput: wrongPublicInput,
                privateWitness: witness
            )
        )

        var tamperedWitness = witness
        let firstAuxiliaryBit = message.count * 8
        tamperedWitness[firstAuxiliaryBit] = .one - tamperedWitness[firstAuxiliaryBit]
        XCTAssertFalse(
            try workload.builder.validateWitness(
                publicInput: publicInput,
                privateWitness: tamperedWitness
            )
        )
    }

    func testSHA256OneBlockCircuitRejectsUnsupportedMessageLength() throws {
        XCTAssertThrowsSuperNeoError(
            try SuperNeoSHA256OneBlockHashWorkload(
                messageByteCount: SuperNeoSHA256OneBlockHashWorkload.maximumMessageByteCount + 1
            ),
            .invalidParameter("SHA-256 one-block hash circuit supports messages up to 55 bytes")
        )
        let workload = try SuperNeoSHA256OneBlockHashWorkload(messageByteCount: 3)
        XCTAssertThrowsSuperNeoError(
            try workload.privateWitness(message: Array("abcd".utf8)),
            .invalidParameter("SHA-256 hash circuit message length mismatch")
        )
    }

    func testSHA256OneBlockPublicMessageCircuitBindsStructuredMessageBits() throws {
        let parameters = try SuperNeoXMSSWOTSPlusParameters(
            baseW: 2,
            messageDigitCount: 2,
            treeHeight: 2,
            hashRoundCount: 8,
            hashMode: .sha256OneBlock
        )
        let inputDigest = Digest256.hash("wots-public-message-input")
        let message = try SuperNeoSHA256WOTSPlusReference.chainStepMessage(
            inputDigest: inputDigest,
            parameters: parameters,
            publicSeed: 1,
            leafIndex: 0,
            chainIndex: 0,
            step: 0
        )
        let workload = try SuperNeoSHA256OneBlockPublicMessageHashWorkload(messageByteCount: message.count)
        let digest = try workload.digest(message: message)
        let publicInput = try workload.publicInput(message: message, digest: digest)
        let witness = try workload.privateWitness(message: message)

        XCTAssertEqual(message.count, SuperNeoSHA256WOTSPlusReference.chainMessageByteCount)
        XCTAssertEqual(digest, Digest256.hash(message))
        XCTAssertEqual(publicInput.count, workload.publicInputCount)
        XCTAssertEqual(witness.count, workload.privateWitnessCount)
        XCTAssertTrue(try workload.builder.validateWitness(publicInput: publicInput, privateWitness: witness))

        var tamperedMessagePublicInput = publicInput
        let firstMessageBitOffset = 1 + Digest256.byteCount * 8
        tamperedMessagePublicInput[firstMessageBitOffset] = .one - tamperedMessagePublicInput[firstMessageBitOffset]
        XCTAssertFalse(
            try workload.builder.validateWitness(
                publicInput: tamperedMessagePublicInput,
                privateWitness: witness
            )
        )
    }

    func testSHA256OneBlockCircuitPreparesFoldableLowNormInstance() throws {
        let message: [UInt8] = []
        let workload = try SuperNeoSHA256OneBlockHashWorkload(messageByteCount: message.count)
        let prepared = try workload.prepareForFolding(
            message: message,
            keySeed: Array("sha256-concrete-hash-folding".utf8)
        )

        XCTAssertEqual(prepared.publicFoldInput.instances.count, 1)
        XCTAssertEqual(prepared.foldInput.witnesses.count, 1)
        let opening = prepared.foldInput.witnesses[0].fullZ(for: prepared.foldInput.instances[0])
        XCTAssertTrue(opening.allSatisfy { $0 == .zero || $0 == .one })
    }
}
