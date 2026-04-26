import XCTest
@_spi(Benchmarking) @testable import SuperNeo_NuMetal

final class PaperImplementationTracksTests: XCTestCase {
    func testLamportSignatureAggregationWorkloadValidatesSelectedBranches() throws {
        let instances = try makeLamportInstances(signatureCount: 2, bitCount: 4)
        let workload = try SuperNeoLamportSignatureAggregationWorkload(signatureCount: 2, bitCount: 4)

        XCTAssertTrue(
            try workload.builder.validateWitness(
                publicInput: workload.publicInput(instances: instances),
                privateWitness: workload.privateWitness(instances: instances)
            )
        )
        var invalidWitness = try workload.privateWitness(instances: instances)
        invalidWitness[0] = invalidWitness[0] + .one
        XCTAssertFalse(
            try workload.builder.validateWitness(
                publicInput: workload.publicInput(instances: instances),
                privateWitness: invalidWitness
            )
        )
        XCTAssertEqual(
            try workload.privateWitness(instances: instances).count,
            2 * 4 * (1 + SuperNeoLamportFieldHash.roundCount * 2)
        )
        XCTAssertThrowsError(
            try SuperNeoLamportSignatureInstance(
                messageBits: instances[0].messageBits,
                publicKeyZero: instances[0].publicKeyZero,
                publicKeyOne: instances[0].publicKeyOne,
                signature: instances[0].signature.map { $0 + GoldilocksField(7) }
            )
        )
        XCTAssertEqual(
            try workload.aggregationDigest(instances: instances),
            try workload.aggregationDigest(instances: instances)
        )
        let prepared = try workload.prepareForFolding(
            instances: instances,
            keySeed: Array("lamport-aggregation-workload-test".utf8)
        )
        XCTAssertEqual(prepared.publicFoldInput.instances.count, 1)
    }

    func testSNARKStyleCompressionProofCompressesAcceptedTerminalEnvelope() throws {
        let workload = try SuperNeoOneHotVectorWorkload(bitCount: 2)
        let prepared = try workload.prepareForFolding(
            bits: [true, false],
            keySeed: Array("snark-style-compression-test".utf8)
        )
        let statement = CCSStatement(
            shapeDigest: prepared.publicFoldInput.shape.shapeDigest,
            ccsInstances: prepared.publicFoldInput.instances,
            priorCEInstances: []
        )
        let context = ProofEnvelopeContext(
            profileID: prepared.key.parameters.profileID,
            kind: .terminalLocal,
            statement: statement,
            verifierKeyDigest: prepared.key.verifierKeyDigest
        )
        let envelope = try SuperNeoProver(key: prepared.key).terminalFoldEnvelopeDeterministic(
            prepared.foldInput,
            context: context,
            ceRandomSeed: Array("snark-style-compression-ce".utf8)
        )
        let policy = SuperNeoTerminalProofAcceptancePolicy(
            publicInput: prepared.publicFoldInput,
            verifierKeyDigest: prepared.key.verifierKeyDigest,
            proofKindPolicy: .terminalOnly
        )
        let compressionProof = try SuperNeoSNARKStyleCompressor.compressTerminalProof(
            publicInput: prepared.publicFoldInput,
            proofBytes: envelope.superNeoBytes,
            verifierKey: prepared.key,
            policy: policy
        )

        XCTAssertTrue(compressionProof.hasValidDigest())
        XCTAssertGreaterThan(compressionProof.compressionRatioAgainstSource, 1)
        XCTAssertEqual(
            SuperNeoSNARKStyleCompressor.verifyCompressionProof(
                compressionProof,
                sourceProofBytes: envelope.superNeoBytes,
                publicInput: prepared.publicFoldInput,
                verifierKey: prepared.key,
                policy: policy
            ),
            .valid
        )
        XCTAssertEqual(
            SuperNeoSNARKStyleCompressor.verifyCompressionProof(
                compressionProof,
                publicInput: prepared.publicFoldInput,
                verifierKeyDigest: prepared.key.verifierKeyDigest,
                policy: policy
            ),
            .invalid("SNARK-style compression verification requires source proof bytes until the terminal verifier relation is fully arithmetized")
        )
    }

    func testSNARKStyleCompressionAcceptsCompressedTerminalSource() throws {
        let workload = try SuperNeoOneHotVectorWorkload(bitCount: 2)
        let prepared = try workload.prepareForFolding(
            bits: [true, false],
            keySeed: Array("snark-style-compressed-source-test".utf8)
        )
        let statement = CCSStatement(
            shapeDigest: prepared.publicFoldInput.shape.shapeDigest,
            ccsInstances: prepared.publicFoldInput.instances,
            priorCEInstances: []
        )
        let context = ProofEnvelopeContext(
            profileID: prepared.key.parameters.profileID,
            kind: .compressedPublic,
            statement: statement,
            verifierKeyDigest: prepared.key.verifierKeyDigest
        )
        let envelope = try SuperNeoProver(key: prepared.key).compressedTerminalFoldEnvelopeDeterministic(
            prepared.foldInput,
            context: context,
            ceRandomSeed: Array("snark-style-compressed-source-ce".utf8)
        )
        let policy = SuperNeoTerminalProofAcceptancePolicy(
            publicInput: prepared.publicFoldInput,
            verifierKeyDigest: prepared.key.verifierKeyDigest,
            proofKindPolicy: .compressedOnly
        )
        let compressionProof = try SuperNeoSNARKStyleCompressor.compressAcceptedProof(
            publicInput: prepared.publicFoldInput,
            proofBytes: envelope.superNeoBytes,
            verifierKey: prepared.key,
            policy: policy
        )

        XCTAssertEqual(compressionProof.sourceProofKind, .compressedPublic)
        XCTAssertEqual(
            SuperNeoSNARKStyleCompressor.verifyCompressionProof(
                compressionProof,
                sourceProofBytes: envelope.superNeoBytes,
                publicInput: prepared.publicFoldInput,
                verifierKey: prepared.key,
                policy: policy
            ),
            .valid
        )
    }

    func testSNARKStyleCompressionRejectsTamperedRecursiveTraceDigest() throws {
        let workload = try SuperNeoOneHotVectorWorkload(bitCount: 2)
        let prepared = try workload.prepareForFolding(
            bits: [true, false],
            keySeed: Array("snark-style-trace-digest-test".utf8)
        )
        let statement = CCSStatement(
            shapeDigest: prepared.publicFoldInput.shape.shapeDigest,
            ccsInstances: prepared.publicFoldInput.instances,
            priorCEInstances: []
        )
        let context = ProofEnvelopeContext(
            profileID: prepared.key.parameters.profileID,
            kind: .terminalLocal,
            statement: statement,
            verifierKeyDigest: prepared.key.verifierKeyDigest
        )
        let envelope = try SuperNeoProver(key: prepared.key).terminalFoldEnvelopeDeterministic(
            prepared.foldInput,
            context: context,
            ceRandomSeed: Array("snark-style-trace-digest-ce".utf8)
        )
        let policy = SuperNeoTerminalProofAcceptancePolicy(
            publicInput: prepared.publicFoldInput,
            verifierKeyDigest: prepared.key.verifierKeyDigest,
            proofKindPolicy: .terminalOnly
        )
        let compressionProof = try SuperNeoSNARKStyleCompressor.compressTerminalProof(
            publicInput: prepared.publicFoldInput,
            proofBytes: envelope.superNeoBytes,
            verifierKey: prepared.key,
            policy: policy
        )
        let tamperedProof = try SuperNeoSNARKStyleCompressionProof(
            sourceProofKind: compressionProof.sourceProofKind,
            sourceProofByteCount: compressionProof.sourceProofByteCount,
            sourceProofDigest: compressionProof.sourceProofDigest,
            profileID: compressionProof.profileID,
            shapeDigest: compressionProof.shapeDigest,
            statementDigest: compressionProof.statementDigest,
            verifierKeyDigest: compressionProof.verifierKeyDigest,
            transcriptDomain: compressionProof.transcriptDomain,
            compressionCircuitDigest: compressionProof.compressionCircuitDigest,
            recursiveVerifierTraceDigest: Digest256.hash("tampered-recursive-verifier-trace")
        )

        XCTAssertEqual(
            SuperNeoSNARKStyleCompressor.verifyCompressionProof(
                tamperedProof,
                sourceProofBytes: envelope.superNeoBytes,
                publicInput: prepared.publicFoldInput,
                verifierKey: prepared.key,
                policy: policy
            ),
            .invalid("SNARK-style compression recursive verifier trace digest mismatch")
        )
    }

    func testSNARKStyleCompressionBindsRecursiveRelationDigest() throws {
        let workload = try SuperNeoOneHotVectorWorkload(bitCount: 2)
        let prepared = try workload.prepareForFolding(
            bits: [true, false],
            keySeed: Array("snark-style-recursive-relation-test".utf8)
        )
        let recursiveRelationDigest = Digest256.hash("snark-style-recursive-relation")
        let recursiveInput = SuperNeoFoldInput(
            shape: prepared.foldInput.shape,
            instances: prepared.foldInput.instances,
            witnesses: prepared.foldInput.witnesses,
            priorClaims: prepared.foldInput.priorClaims,
            recursiveRelationDigest: recursiveRelationDigest
        )
        let recursivePublicInput = SuperNeoPublicFoldInput(recursiveInput)
        let statement = CCSStatement(
            shapeDigest: recursivePublicInput.shape.shapeDigest,
            ccsInstances: recursivePublicInput.instances,
            priorCEInstances: recursivePublicInput.priorClaims.map(CEInstance.init),
            recursiveRelationDigest: recursiveRelationDigest
        )
        let context = ProofEnvelopeContext(
            profileID: prepared.key.parameters.profileID,
            kind: .terminalLocal,
            statement: statement,
            verifierKeyDigest: prepared.key.verifierKeyDigest
        )
        let envelope = try SuperNeoProver(key: prepared.key).terminalFoldEnvelopeDeterministic(
            recursiveInput,
            context: context,
            ceRandomSeed: Array("snark-style-recursive-relation-ce".utf8)
        )
        let policy = SuperNeoTerminalProofAcceptancePolicy(
            publicInput: recursivePublicInput,
            verifierKeyDigest: prepared.key.verifierKeyDigest,
            proofKindPolicy: .terminalOnly
        )
        let compressionProof = try SuperNeoSNARKStyleCompressor.compressTerminalProof(
            publicInput: recursivePublicInput,
            proofBytes: envelope.superNeoBytes,
            verifierKey: prepared.key,
            policy: policy
        )
        let wrongPublicInput = SuperNeoPublicFoldInput(
            shape: recursivePublicInput.shape,
            instances: recursivePublicInput.instances,
            priorClaims: recursivePublicInput.priorClaims,
            recursiveRelationDigest: Digest256.hash("snark-style-wrong-recursive-relation")
        )

        XCTAssertEqual(
            SuperNeoSNARKStyleCompressor.verifyCompressionProof(
                compressionProof,
                sourceProofBytes: envelope.superNeoBytes,
                publicInput: wrongPublicInput,
                verifierKey: prepared.key,
                policy: policy
            ),
            .invalid("SNARK-style compression source proof rejected: input statement digest mismatch")
        )
    }

    func testBoundedRecursiveDriverBuildsTypedCarryChain() throws {
        let workload = try SuperNeoOneHotVectorWorkload(bitCount: 2)
        let keySeed = Array("bounded-recursive-driver-test".utf8)
        let prepared = try workload.prepareForFolding(bits: [false, true], keySeed: keySeed)
        let context = try NumiSealProductTrustedContext(
            workload: "one-hot-vector-v1",
            bitCount: 2,
            publicInputs: [1],
            workloadParameters: ["selectedCount": "1"],
            sourceApplicationPathUTF8: "bounded-recursive-driver-test"
        )
        let requests: [NumiSealBoundedRecursiveStepRequest] = try (0..<2).map { index in
            let limits = try NumiSealAggregationLimits(maximumObligationsPerAggregate: 32)
            return NumiSealBoundedRecursiveStepRequest(
                preparedR1CS: prepared,
                trustedContext: context,
                qroChallenge: try makeQROChallenge("bounded-recursive-driver-\(index)"),
                keySeedUTF8: "bounded-recursive-driver-test",
                executionPolicy: .zkHighAssuranceCPU,
                zkMode: NumiSealZK.nonZKMode,
                aggregationLimits: limits
            )
        }
        let run = try NumiSealBoundedRecursiveDriver.proveAndVerify(requests: requests, maximumDepth: 2)

        XCTAssertEqual(run.steps.count, 2)
        XCTAssertNil(run.steps[0].recursiveCarryChainRoot)
        XCTAssertNotNil(run.steps[1].recursiveCarryChainRoot)
        XCTAssertEqual(run.accounting.requestedDepth, 2)
        XCTAssertEqual(run.accounting.finalCarryChainRoot, run.steps[1].productCarryChainRoot)
        XCTAssertEqual(run.accounting.stepArtifactDigests, run.steps.map { $0.artifactDigest })
        XCTAssertTrue(run.steps[0].provingOutput.payPerBitEvidence.hasValidDigest())
        XCTAssertEqual(
            run.steps[0].provingOutput.payPerBitEvidence.maxActiveLimbCount,
            SuperNeoParameters.goldilocks.decompositionLength
        )
        XCTAssertEqual(run.steps[0].provingOutput.payPerBitEvidence.totalSkippedFixedLimbCount, 0)
    }

    func testBoundedPCDDriverBindsFanInParentSet() throws {
        let workload = try SuperNeoOneHotVectorWorkload(bitCount: 2)
        let prepared = try workload.prepareForFolding(
            bits: [true, false],
            keySeed: Array("bounded-pcd-driver-test".utf8)
        )
        let context = try NumiSealProductTrustedContext(
            workload: "one-hot-vector-v1",
            bitCount: 2,
            publicInputs: [1],
            workloadParameters: ["selectedCount": "1"],
            sourceApplicationPathUTF8: "bounded-pcd-driver-test"
        )
        let limits = try NumiSealAggregationLimits(maximumObligationsPerAggregate: 32)
        let nodeRequests = try [
            NumiSealBoundedPCDNodeRequest(
                step: NumiSealBoundedRecursiveStepRequest(
                    preparedR1CS: prepared,
                    trustedContext: context,
                    qroChallenge: makeQROChallenge("bounded-pcd-root-a"),
                    keySeedUTF8: "bounded-pcd-driver-test",
                    executionPolicy: .zkHighAssuranceCPU,
                    zkMode: NumiSealZK.nonZKMode,
                    aggregationLimits: limits
                )
            ),
            NumiSealBoundedPCDNodeRequest(
                step: NumiSealBoundedRecursiveStepRequest(
                    preparedR1CS: prepared,
                    trustedContext: context,
                    qroChallenge: makeQROChallenge("bounded-pcd-root-b"),
                    keySeedUTF8: "bounded-pcd-driver-test",
                    executionPolicy: .zkHighAssuranceCPU,
                    zkMode: NumiSealZK.nonZKMode,
                    aggregationLimits: limits
                )
            ),
            NumiSealBoundedPCDNodeRequest(
                step: NumiSealBoundedRecursiveStepRequest(
                    preparedR1CS: prepared,
                    trustedContext: context,
                    qroChallenge: makeQROChallenge("bounded-pcd-join"),
                    keySeedUTF8: "bounded-pcd-driver-test",
                    executionPolicy: .zkHighAssuranceCPU,
                    zkMode: NumiSealZK.nonZKMode,
                    aggregationLimits: limits
                ),
                parentNodeIndices: [0, 1],
                primaryCarryParentIndex: 0
            )
        ]

        let run = try NumiSealBoundedRecursiveDriver.proveAndVerifyPCD(
            requests: nodeRequests,
            maximumDepth: 2,
            maximumFanIn: 2
        )

        XCTAssertEqual(run.nodes.count, 3)
        XCTAssertEqual(run.nodes[2].step.depth, 2)
        XCTAssertNotNil(run.nodes[2].step.recursiveCarryChainRoot)
        let parentSetRoot = try XCTUnwrap(run.nodes[2].parentSetBinding?.parentSetRoot)
        XCTAssertEqual(
            run.nodes[2].step.provingOutput.artifact.workloadParameters["pcdParentSetRoot"],
            parentSetRoot.hexString
        )
        XCTAssertEqual(run.accounting.terminalNodeIndices, [2])
        XCTAssertEqual(run.accounting.nodeParentSetRoots[2], parentSetRoot)
    }

    func testBoundedRecursiveDriverRejectsDepthBeyondSelectedTheorem() throws {
        XCTAssertThrowsError(
            try NumiSealBoundedRecursiveDriver.proveAndVerify(requests: [], maximumDepth: NumiSealProductTheoremLimits.selectedDepth + 1)
        )
    }

    func testBoundedPCDDriverRejectsFutureParentIndex() throws {
        let workload = try SuperNeoOneHotVectorWorkload(bitCount: 1)
        let prepared = try workload.prepareForFolding(
            bits: [true],
            keySeed: Array("bounded-pcd-future-parent-test".utf8)
        )
        let context = try NumiSealProductTrustedContext(
            workload: "one-hot-vector-v1",
            bitCount: 1,
            publicInputs: [1],
            workloadParameters: ["selectedCount": "1"],
            sourceApplicationPathUTF8: "bounded-pcd-future-parent-test"
        )
        let request = try NumiSealBoundedPCDNodeRequest(
            step: NumiSealBoundedRecursiveStepRequest(
                preparedR1CS: prepared,
                trustedContext: context,
                qroChallenge: makeQROChallenge("bounded-pcd-future-parent"),
                keySeedUTF8: "bounded-pcd-future-parent-test",
                executionPolicy: .zkHighAssuranceCPU,
                zkMode: NumiSealZK.nonZKMode,
                aggregationLimits: NumiSealAggregationLimits(maximumObligationsPerAggregate: 32)
            ),
            parentNodeIndices: [0]
        )

        XCTAssertThrowsError(
            try NumiSealBoundedRecursiveDriver.proveAndVerifyPCD(requests: [request], maximumDepth: 2)
        )
    }

    private func makeQROChallenge(_ label: String) throws -> SuperNeoQROChallenge {
        try SuperNeoQROChallenge(
            sessionID: "paper-implementation-tracks/\(label)",
            verifierPublicCoin: Digest256.hash("paper-implementation-qro/\(label)").superNeoBytes,
            transcriptContext: SuperNeoSplitQRO.framedBytes(
                domain: "superneo/tests/paper-implementation-qro-context/v1",
                frames: [Array(label.utf8)]
            )
        )
    }

    private func makeLamportInstances(
        signatureCount: Int,
        bitCount: Int
    ) throws -> [SuperNeoLamportSignatureInstance] {
        try (0..<signatureCount).map { signatureIndex in
            let messageBits = (0..<bitCount).map { (($0 + signatureIndex) % 2) == 0 }
            let zeroSecret = (0..<bitCount).map { GoldilocksField(UInt64(10 + signatureIndex * 32 + $0)) }
            let oneSecret = (0..<bitCount).map { GoldilocksField(UInt64(100 + signatureIndex * 32 + $0)) }
            let zero = zeroSecret.map(SuperNeoLamportFieldHash.digest)
            let one = oneSecret.map(SuperNeoLamportFieldHash.digest)
            let signature = (0..<bitCount).map { messageBits[$0] ? oneSecret[$0] : zeroSecret[$0] }
            return try SuperNeoLamportSignatureInstance(
                messageBits: messageBits,
                publicKeyZero: zero,
                publicKeyOne: one,
                signature: signature
            )
        }
    }
}
