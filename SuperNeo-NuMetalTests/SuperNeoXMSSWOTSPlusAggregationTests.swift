import XCTest
@_spi(Benchmarking) @testable import SuperNeo_NuMetal

final class SuperNeoXMSSWOTSPlusAggregationTests: SuperNeoTestCase {
    func testXMSSWOTSPlusWorkloadValidatesReferenceSignatures() throws {
        let parameters = try compactParameters()
        let instances = try makeInstances(parameters: parameters, count: 2)
        let workload = try SuperNeoXMSSWOTSPlusAggregationWorkload(
            signatureCount: instances.count,
            parameters: parameters
        )
        let publicInput = try workload.publicInput(instances: instances)
        let witness = try workload.privateWitness(instances: instances)

        XCTAssertTrue(
            try workload.builder.validateWitness(
                publicInput: publicInput,
                privateWitness: witness
            )
        )
        XCTAssertEqual(
            try workload.aggregationDigest(instances: instances),
            try workload.aggregationDigest(instances: instances)
        )
        XCTAssertEqual(parameters.hashInvocationCountPerSignature, 9)
        XCTAssertEqual(parameters.hashProductWitnessCountPerSignature, 72)

        var badWitness = witness
        badWitness[0] = badWitness[0] + .one
        XCTAssertFalse(
            try workload.builder.validateWitness(
                publicInput: publicInput,
                privateWitness: badWitness
            )
        )

        var badHashTrace = witness
        let firstHashProductOffset = parameters.messageDigitCount * parameters.logW
            + parameters.checksumDigitCount * (1 + parameters.logW)
            + 1
        badHashTrace[firstHashProductOffset] = .one - badHashTrace[firstHashProductOffset]
        XCTAssertFalse(
            try workload.builder.validateWitness(
                publicInput: publicInput,
                privateWitness: badHashTrace
            )
        )

        var badPublicInput = publicInput
        badPublicInput[1] = badPublicInput[1] + .one
        XCTAssertFalse(
            try workload.builder.validateWitness(
                publicInput: badPublicInput,
                privateWitness: witness
            )
        )
    }

    func testXMSSWOTSPlusInstanceRejectsWrongAuthenticationPath() throws {
        let parameters = try compactParameters()
        let instance = try makeInstances(parameters: parameters, count: 1)[0]
        var path = instance.authenticationPath
        path[0] = .one - path[0]

        XCTAssertThrowsSuperNeoError(
            try SuperNeoXMSSWOTSPlusSignatureInstance(
                parameters: parameters,
                root: instance.root,
                messageDigits: instance.messageDigits,
                leafIndex: instance.leafIndex,
                signatureElements: instance.signatureElements,
                authenticationPath: path
            ),
            .invalidParameter("XMSS/WOTS+ signature does not reconstruct the supplied root")
        )
    }

    func testXMSSWOTSPlusManySignaturesPrepareAsFoldInstances() throws {
        let parameters = try compactParameters()
        let instances = try makeInstances(parameters: parameters, count: 2)
        let prepared = try SuperNeoXMSSWOTSPlusAggregationWorkload.prepareManyForFolding(
            instances: instances,
            keySeed: Array("xmss-wots-plus-many-fold".utf8),
            executionPolicy: .highAssurance
        )

        XCTAssertEqual(prepared.publicFoldInput.instances.count, instances.count)
        XCTAssertEqual(prepared.foldInput.witnesses.count, instances.count)

        let fold = try SuperNeoProver(
            key: prepared.key,
            executionPolicy: .highAssurance
        ).foldWithOutput(
            prepared.foldInput,
            transcriptSeed: Array("xmss-wots-plus-fold-reduction".utf8)
        )
        let reduction = SuperNeoVerifier(
            key: prepared.key,
            executionPolicy: .highAssurance
        ).reduceFold(
            input: prepared.foldInput,
            proof: fold.proof,
            transcriptSeed: Array("xmss-wots-plus-fold-reduction".utf8)
        )

        XCTAssertTrue(reduction.isReductionAccepted, reduction.reason ?? "XMSS/WOTS+ fold reduction rejected")
        XCTAssertEqual(reduction.outputClaims, fold.proof.outputClaims)
    }

    func testAlgebraicXMSSWorkloadRejectsSHA256Mode() throws {
        let parameters = try sha256CompactParameters()

        XCTAssertThrowsSuperNeoError(
            try SuperNeoXMSSWOTSPlusAggregationWorkload(signatureCount: 1, parameters: parameters),
            .invalidParameter("XMSS/WOTS+ aggregation circuit uses the algebraic-toy hash mode")
        )
        XCTAssertThrowsSuperNeoError(
            try SuperNeoXMSSWOTSPlusReference.sign(
                seed: Array("xmss-sha-mode-rejected".utf8),
                parameters: parameters,
                messageDigits: [1, 1],
                leafIndex: 0
            ),
            .invalidParameter("XMSS/WOTS+ algebraic-toy reference requires algebraic-toy hash mode")
        )
    }

    func testSHA256WOTSPlusChainWorkloadUsesConcreteHashCircuit() throws {
        let parameters = try sha256CompactParameters()
        let messageDigits = [1, 1]
        let signatureElements = (0..<parameters.wotsLength).map { index in
            Digest256.hash(Array("sha256-wots-signature-\(index)".utf8))
        }
        let publicKey = try SuperNeoSHA256WOTSPlusReference.publicKey(
            parameters: parameters,
            messageDigits: messageDigits,
            leafIndex: 1,
            signatureElements: signatureElements
        )
        let instance = try SuperNeoSHA256WOTSPlusChainInstance(
            parameters: parameters,
            messageDigits: messageDigits,
            leafIndex: 1,
            signatureElements: signatureElements,
            publicKey: publicKey
        )
        let calls = try SuperNeoSHA256WOTSPlusChainWorkload.hashCalls(instances: [instance])
        let workload = try SuperNeoSHA256OneBlockPublicMessageHashWorkload(
            messageByteCount: SuperNeoSHA256WOTSPlusReference.chainMessageByteCount
        )

        XCTAssertEqual(calls.count, 2)
        XCTAssertTrue(calls.allSatisfy { $0.message.count == SuperNeoSHA256WOTSPlusReference.chainMessageByteCount })
        for call in calls {
            XCTAssertEqual(call.outputDigest, Digest256.hash(call.message))
            XCTAssertTrue(try workload.validate(message: call.message, digest: call.outputDigest))
            XCTAssertEqual(Array(call.message.prefix(8)), Array("SNWOTS1\0".utf8))
        }

        var tamperedPublicKey = publicKey
        tamperedPublicKey[0] = Digest256.hash("sha256-wots-wrong-public-key")
        XCTAssertThrowsSuperNeoError(
            try SuperNeoSHA256WOTSPlusChainInstance(
                parameters: parameters,
                messageDigits: messageDigits,
                leafIndex: 1,
                signatureElements: signatureElements,
                publicKey: tamperedPublicKey
            ),
            .invalidParameter("SHA-256 WOTS+ chain signature does not reconstruct the supplied public key")
        )

        let prepared = try SuperNeoSHA256WOTSPlusChainWorkload.prepareHashCallsForFolding(
            instances: [instance],
            keySeed: Array("sha256-wots-concrete-fold".utf8),
            executionPolicy: .highAssurance
        )
        XCTAssertEqual(prepared.publicFoldInput.instances.count, calls.count)
        XCTAssertEqual(prepared.foldInput.witnesses.count, calls.count)
    }

    private func compactParameters() throws -> SuperNeoXMSSWOTSPlusParameters {
        try SuperNeoXMSSWOTSPlusParameters(
            baseW: 2,
            messageDigitCount: 2,
            treeHeight: 2,
            hashRoundCount: 8
        )
    }

    private func sha256CompactParameters() throws -> SuperNeoXMSSWOTSPlusParameters {
        try SuperNeoXMSSWOTSPlusParameters(
            baseW: 2,
            messageDigitCount: 2,
            treeHeight: 2,
            hashRoundCount: 8,
            hashMode: .sha256OneBlock
        )
    }

    private func makeInstances(
        parameters: SuperNeoXMSSWOTSPlusParameters,
        count: Int
    ) throws -> [SuperNeoXMSSWOTSPlusSignatureInstance] {
        try (0..<count).map { index in
            try SuperNeoXMSSWOTSPlusReference.sign(
                seed: Array("xmss-wots-plus-reference-seed".utf8),
                parameters: parameters,
                messageDigits: [
                    index % parameters.baseW,
                    (index + 1) % parameters.baseW
                ],
                leafIndex: index
            )
        }
    }
}
