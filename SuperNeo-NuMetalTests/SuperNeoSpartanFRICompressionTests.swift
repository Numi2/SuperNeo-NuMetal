import XCTest
@_spi(Benchmarking) @testable import SuperNeo_NuMetal

final class SuperNeoSpartanFRICompressionTests: SuperNeoTestCase {
    func testSpartanFRICompressionVerifiesTerminalSource() throws {
        let fixture = try makeFoldFixture()
        let publicInput = SuperNeoPublicFoldInput(fixture.input)
        let statement = CCSStatement(
            shapeDigest: publicInput.shape.shapeDigest,
            ccsInstances: publicInput.instances,
            priorCEInstances: publicInput.priorClaims.map(CEInstance.init)
        )
        let context = ProofEnvelopeContext(
            profileID: SuperNeoParameters.goldilocks.profileID,
            kind: .terminalLocal,
            statement: statement,
            verifierKeyDigest: fixture.key.verifierKeyDigest
        )
        let envelope = try SuperNeoProver(key: fixture.key).terminalFoldEnvelopeDeterministic(
            fixture.input,
            context: context,
            ceRandomSeed: Array("spartan-fri-terminal-ce".utf8)
        )
        let policy = SuperNeoTerminalProofAcceptancePolicy(
            statement: statement,
            verifierKeyDigest: fixture.key.verifierKeyDigest,
            profileID: SuperNeoParameters.goldilocks.profileID,
            transcriptDomain: context.transcriptDomain,
            proofKindPolicy: .terminalOnly
        )

        let proof = try SuperNeoSpartanFRICompressor.compressAcceptedProof(
            publicInput: publicInput,
            proofBytes: envelope.superNeoBytes,
            verifierKey: fixture.key,
            policy: policy
        )

        XCTAssertEqual(proof.statement.sourceProofKind, ProofEnvelopeKind.terminalLocal)
        XCTAssertTrue(proof.statement.hasValidDigest())
        XCTAssertTrue(proof.terminalVerifierPCSProof.hasValidDigest())
        XCTAssertTrue(proof.witnessPCS.hasValidDigest())
        XCTAssertTrue(proof.residualPCS.hasValidDigest())
        XCTAssertEqual(proof.witnessPCS.baseCommitment.domainSize, proof.paddedDomainSize)
        XCTAssertEqual(proof.residualPCS.baseCommitment.domainSize, proof.paddedDomainSize)
        XCTAssertEqual(
            SuperNeoSpartanFRICompressor.verifyCompressionProof(
                proof,
                sourceProofBytes: envelope.superNeoBytes,
                publicInput: publicInput,
                verifierKey: fixture.key,
                policy: policy
            ),
            .valid
        )
        XCTAssertEqual(
            SuperNeoSpartanFRICompressor.verifyCompressionProof(
                proof,
                publicInput: publicInput,
                verifierKey: fixture.key,
                policy: policy
            ),
            .valid
        )
        let decodedProof = try SuperNeoSpartanFRICompressionProof(bytes: proof.superNeoBytes)
        XCTAssertEqual(decodedProof.proofDigest, proof.proofDigest)
        XCTAssertEqual(
            SuperNeoSpartanFRICompressor.verifyCompressionProof(
                proofBytes: proof.superNeoBytes,
                publicInput: publicInput,
                verifierKey: fixture.key,
                policy: policy
            ),
            .valid
        )
        var mutatedProofBytes = proof.superNeoBytes
        mutatedProofBytes[mutatedProofBytes.count - 1] ^= 0x01
        let mutatedByteResult = SuperNeoSpartanFRICompressor.verifyCompressionProof(
            proofBytes: mutatedProofBytes,
            publicInput: publicInput,
            verifierKey: fixture.key,
            policy: policy
        )
        XCTAssertFalse(mutatedByteResult.isValid)
        XCTAssertTrue(mutatedByteResult.reason?.contains("decoding failed") ?? false)
        XCTAssertEqual(
            SuperNeoSpartanFRICompressor.verifyCompressionProof(
                proof,
                publicInput: publicInput,
                verifierKeyDigest: fixture.key.verifierKeyDigest,
                policy: policy
            ),
            .invalid("Spartan/FRI source-free compression verification requires the verifier key")
        )
    }

    func testSpartanFRICompressionBindsRecursiveRelationDigest() throws {
        let fixture = try makeFoldFixture()
        let recursiveRelationDigest = Digest256.hash("spartan-fri-recursive-relation")
        let recursiveInput = SuperNeoFoldInput(
            shape: fixture.input.shape,
            instances: fixture.input.instances,
            witnesses: fixture.input.witnesses,
            priorClaims: fixture.input.priorClaims,
            recursiveRelationDigest: recursiveRelationDigest
        )
        let publicInput = SuperNeoPublicFoldInput(recursiveInput)
        let statement = CCSStatement(
            shapeDigest: publicInput.shape.shapeDigest,
            ccsInstances: publicInput.instances,
            priorCEInstances: publicInput.priorClaims.map(CEInstance.init),
            recursiveRelationDigest: recursiveRelationDigest
        )
        let context = ProofEnvelopeContext(
            profileID: SuperNeoParameters.goldilocks.profileID,
            kind: .terminalLocal,
            statement: statement,
            verifierKeyDigest: fixture.key.verifierKeyDigest
        )
        let envelope = try SuperNeoProver(key: fixture.key).terminalFoldEnvelopeDeterministic(
            recursiveInput,
            context: context,
            ceRandomSeed: Array("spartan-fri-recursive-ce".utf8)
        )
        let policy = SuperNeoTerminalProofAcceptancePolicy(
            publicInput: publicInput,
            verifierKeyDigest: fixture.key.verifierKeyDigest,
            proofKindPolicy: .terminalOnly
        )
        let proof = try SuperNeoSpartanFRICompressor.compressAcceptedProof(
            publicInput: publicInput,
            proofBytes: envelope.superNeoBytes,
            verifierKey: fixture.key,
            policy: policy
        )
        let wrongPublicInput = SuperNeoPublicFoldInput(
            shape: publicInput.shape,
            instances: publicInput.instances,
            priorClaims: publicInput.priorClaims,
            recursiveRelationDigest: Digest256.hash("spartan-fri-wrong-recursive-relation")
        )

        XCTAssertEqual(
            SuperNeoSpartanFRICompressor.verifyCompressionProof(
                proof,
                sourceProofBytes: envelope.superNeoBytes,
                publicInput: wrongPublicInput,
                verifierKey: fixture.key,
                policy: policy
            ),
            .invalid("Spartan/FRI compression source proof rejected: input statement digest mismatch")
        )
    }

    func testSpartanFRICompressionAcceptsCompressedPublicSource() throws {
        let fixture = try makeFoldFixture()
        let publicInput = SuperNeoPublicFoldInput(fixture.input)
        let statement = CCSStatement(
            shapeDigest: publicInput.shape.shapeDigest,
            ccsInstances: publicInput.instances,
            priorCEInstances: publicInput.priorClaims.map(CEInstance.init)
        )
        let context = ProofEnvelopeContext(
            profileID: SuperNeoParameters.goldilocks.profileID,
            kind: .compressedPublic,
            statement: statement,
            verifierKeyDigest: fixture.key.verifierKeyDigest
        )
        let envelope = try SuperNeoProver(key: fixture.key).compressedTerminalFoldEnvelopeDeterministic(
            fixture.input,
            context: context,
            ceRandomSeed: Array("spartan-fri-compressed-ce".utf8)
        )
        let policy = SuperNeoTerminalProofAcceptancePolicy(
            statement: statement,
            verifierKeyDigest: fixture.key.verifierKeyDigest,
            profileID: SuperNeoParameters.goldilocks.profileID,
            transcriptDomain: context.transcriptDomain,
            proofKindPolicy: .compressedOnly
        )

        let proof = try SuperNeoSpartanFRICompressor.compressAcceptedProof(
            publicInput: publicInput,
            proofBytes: envelope.superNeoBytes,
            verifierKey: fixture.key,
            policy: policy
        )

        XCTAssertEqual(proof.statement.sourceProofKind, ProofEnvelopeKind.compressedPublic)
        XCTAssertEqual(
            SuperNeoSpartanFRICompressor.verifyCompressionProof(
                proof,
                sourceProofBytes: envelope.superNeoBytes,
                publicInput: publicInput,
                verifierKey: fixture.key,
                policy: policy
            ),
            .valid
        )
        XCTAssertEqual(
            SuperNeoSpartanFRICompressor.verifyCompressionProof(
                proof,
                publicInput: publicInput,
                verifierKey: fixture.key,
                policy: policy
            ),
            .valid
        )
    }

    func testSpartanFRICompressionRejectsMutatedSourceBeforeProving() throws {
        let fixture = try makeFoldFixture()
        let publicInput = SuperNeoPublicFoldInput(fixture.input)
        let statement = CCSStatement(
            shapeDigest: publicInput.shape.shapeDigest,
            ccsInstances: publicInput.instances,
            priorCEInstances: publicInput.priorClaims.map(CEInstance.init)
        )
        let context = ProofEnvelopeContext(
            profileID: SuperNeoParameters.goldilocks.profileID,
            kind: .terminalLocal,
            statement: statement,
            verifierKeyDigest: fixture.key.verifierKeyDigest
        )
        let envelope = try SuperNeoProver(key: fixture.key).terminalFoldEnvelopeDeterministic(
            fixture.input,
            context: context,
            ceRandomSeed: Array("spartan-fri-reject-ce".utf8)
        )
        var mutated = envelope.superNeoBytes
        mutated[mutated.count - 1] ^= 0x01

        XCTAssertThrowsError(
            try SuperNeoSpartanFRICompressor.compressAcceptedProof(
                publicInput: publicInput,
                proofBytes: mutated,
                verifierKey: fixture.key
            )
        )
    }

    func testSpartanFRIVerifierRejectsTamperedResidualOpening() throws {
        let fixture = try makeFoldFixture()
        let publicInput = SuperNeoPublicFoldInput(fixture.input)
        let statement = CCSStatement(
            shapeDigest: publicInput.shape.shapeDigest,
            ccsInstances: publicInput.instances,
            priorCEInstances: publicInput.priorClaims.map(CEInstance.init)
        )
        let context = ProofEnvelopeContext(
            profileID: SuperNeoParameters.goldilocks.profileID,
            kind: .terminalLocal,
            statement: statement,
            verifierKeyDigest: fixture.key.verifierKeyDigest
        )
        let envelope = try SuperNeoProver(key: fixture.key).terminalFoldEnvelopeDeterministic(
            fixture.input,
            context: context,
            ceRandomSeed: Array("spartan-fri-tamper-ce".utf8)
        )
        let policy = SuperNeoTerminalProofAcceptancePolicy(
            statement: statement,
            verifierKeyDigest: fixture.key.verifierKeyDigest,
            profileID: SuperNeoParameters.goldilocks.profileID,
            transcriptDomain: context.transcriptDomain
        )
        let proof = try SuperNeoSpartanFRICompressor.compressAcceptedProof(
            publicInput: publicInput,
            proofBytes: envelope.superNeoBytes,
            verifierKey: fixture.key,
            policy: policy
        )

        var queryProofs = proof.residualPCS.queryProofs
        var firstQuery = queryProofs[0]
        var layerOpenings = firstQuery.layerOpenings
        var firstLayer = layerOpenings[0]
        let opening = firstLayer[0]
        firstLayer[0] = SuperNeoFRIMerkleOpening(
            index: opening.index,
            leafCount: opening.leafCount,
            point: opening.point,
            value: .one,
            siblings: opening.siblings
        )
        layerOpenings[0] = firstLayer
        firstQuery = SuperNeoFRIQueryProof(
            initialIndex: firstQuery.initialIndex,
            layerOpenings: layerOpenings
        )
        queryProofs[0] = firstQuery
        let tamperedResidualPCS = try SuperNeoFRIProof(
            vectorLength: proof.residualPCS.vectorLength,
            paddedDomainSize: proof.residualPCS.paddedDomainSize,
            queryCount: proof.residualPCS.queryCount,
            blowupFactor: proof.residualPCS.blowupFactor,
            claimedDegreeBound: proof.residualPCS.claimedDegreeBound,
            domainRoot: proof.residualPCS.domainRoot,
            cosetGenerator: proof.residualPCS.cosetGenerator,
            baseCommitment: proof.residualPCS.baseCommitment,
            foldedCommitments: proof.residualPCS.foldedCommitments,
            foldingChallenges: proof.residualPCS.foldingChallenges,
            queryProofs: queryProofs,
            finalPolynomial: proof.residualPCS.finalPolynomial
        )
        let tamperedProof = try SuperNeoSpartanFRICompressionProof(
            statement: proof.statement,
            arithmetizationDigest: proof.arithmetizationDigest,
            traceVectorLength: proof.traceVectorLength,
            paddedDomainSize: proof.paddedDomainSize,
            terminalVerifierPCSProof: proof.terminalVerifierPCSProof,
            witnessPCS: proof.witnessPCS,
            residualPCS: tamperedResidualPCS
        )

        let result = SuperNeoSpartanFRICompressor.verifyCompressionProof(
            tamperedProof,
            sourceProofBytes: envelope.superNeoBytes,
            publicInput: publicInput,
            verifierKey: fixture.key,
            policy: policy
        )
        XCTAssertFalse(result.isValid)
    }

    func testSpartanFRIVerifierRejectsNonCanonicalMerkleOpeningShape() throws {
        let fixture = try makeFoldFixture()
        let publicInput = SuperNeoPublicFoldInput(fixture.input)
        let statement = CCSStatement(
            shapeDigest: publicInput.shape.shapeDigest,
            ccsInstances: publicInput.instances,
            priorCEInstances: publicInput.priorClaims.map(CEInstance.init)
        )
        let context = ProofEnvelopeContext(
            profileID: SuperNeoParameters.goldilocks.profileID,
            kind: .terminalLocal,
            statement: statement,
            verifierKeyDigest: fixture.key.verifierKeyDigest
        )
        let envelope = try SuperNeoProver(key: fixture.key).terminalFoldEnvelopeDeterministic(
            fixture.input,
            context: context,
            ceRandomSeed: Array("spartan-fri-shape-ce".utf8)
        )
        let policy = SuperNeoTerminalProofAcceptancePolicy(
            statement: statement,
            verifierKeyDigest: fixture.key.verifierKeyDigest,
            profileID: SuperNeoParameters.goldilocks.profileID,
            transcriptDomain: context.transcriptDomain
        )
        let proof = try SuperNeoSpartanFRICompressor.compressAcceptedProof(
            publicInput: publicInput,
            proofBytes: envelope.superNeoBytes,
            verifierKey: fixture.key,
            policy: policy
        )

        var queryProofs = proof.witnessPCS.queryProofs
        var firstQuery = queryProofs[0]
        var layerOpenings = firstQuery.layerOpenings
        var firstLayer = layerOpenings[0]
        let opening = firstLayer[0]
        firstLayer[0] = SuperNeoFRIMerkleOpening(
            index: opening.index,
            leafCount: opening.leafCount / 2,
            point: opening.point,
            value: opening.value,
            siblings: opening.siblings
        )
        layerOpenings[0] = firstLayer
        firstQuery = SuperNeoFRIQueryProof(
            initialIndex: firstQuery.initialIndex,
            layerOpenings: layerOpenings
        )
        queryProofs[0] = firstQuery
        let tamperedWitnessPCS = try SuperNeoFRIProof(
            vectorLength: proof.witnessPCS.vectorLength,
            paddedDomainSize: proof.witnessPCS.paddedDomainSize,
            queryCount: proof.witnessPCS.queryCount,
            blowupFactor: proof.witnessPCS.blowupFactor,
            claimedDegreeBound: proof.witnessPCS.claimedDegreeBound,
            domainRoot: proof.witnessPCS.domainRoot,
            cosetGenerator: proof.witnessPCS.cosetGenerator,
            baseCommitment: proof.witnessPCS.baseCommitment,
            foldedCommitments: proof.witnessPCS.foldedCommitments,
            foldingChallenges: proof.witnessPCS.foldingChallenges,
            queryProofs: queryProofs,
            finalPolynomial: proof.witnessPCS.finalPolynomial
        )
        let tamperedProof = try SuperNeoSpartanFRICompressionProof(
            statement: proof.statement,
            arithmetizationDigest: proof.arithmetizationDigest,
            traceVectorLength: proof.traceVectorLength,
            paddedDomainSize: proof.paddedDomainSize,
            terminalVerifierPCSProof: proof.terminalVerifierPCSProof,
            witnessPCS: tamperedWitnessPCS,
            residualPCS: proof.residualPCS
        )

        XCTAssertEqual(
            SuperNeoSpartanFRICompressor.verifyCompressionProof(
                tamperedProof,
                sourceProofBytes: envelope.superNeoBytes,
                publicInput: publicInput,
                verifierKey: fixture.key,
                policy: policy
            ),
            .invalid("verificationFailed(\"FRI Merkle opening leaf count mismatch\")")
        )
    }

    func testFRIProofRejectsZeroAndOversizedQueryCounts() throws {
        let commitment = SuperNeoFRICommitment(
            domainSize: 1,
            root: Digest384.shake256("spartan-fri-query-bound-root")
        )
        XCTAssertThrowsSuperNeoError(
            try SuperNeoFRIProof(
                vectorLength: 1,
                paddedDomainSize: 1,
                queryCount: 0,
                baseCommitment: commitment,
                foldedCommitments: [],
                foldingChallenges: [],
                queryProofs: []
            ),
            .invalidParameter("FRI query count must be positive")
        )
        XCTAssertThrowsSuperNeoError(
            try SuperNeoFRIProof(
                vectorLength: 1,
                paddedDomainSize: 1,
                queryCount: 2,
                baseCommitment: commitment,
                foldedCommitments: [],
                foldingChallenges: [],
                queryProofs: [
                    SuperNeoFRIQueryProof(initialIndex: 0, layerOpenings: []),
                    SuperNeoFRIQueryProof(initialIndex: 0, layerOpenings: [])
                ]
            ),
            .invalidParameter("FRI query count exceeds padded domain")
        )
    }

    func testTerminalVerifierAIRCEAjtaiRowsUsePrimitiveBatchedProvenance() throws {
        let fixture = try makeFoldFixture()
        let privateLength = fixture.input.shape.nField - fixture.input.shape.nPublicField
        let point = Array(
            repeating: GoldilocksExt2.zero,
            count: fixture.input.shape.m.trailingZeroBitCount
        )
        let claim = CCSEvaluationClaim(
            commitment: fixture.input.instances[0].commitment,
            publicInput: fixture.input.instances[0].publicInput,
            point: point,
            evaluations: [CyclotomicExt2Ring54.zero]
        )
        let statement = try TerminalCEStatement(
            profileID: SuperNeoParameters.goldilocks.profileID,
            shape: fixture.input.shape,
            key: fixture.key,
            claims: [claim]
        )
        let commitments = [
            CEOpeningProofCommitments(
                maskLinearDigest: Digest256.hash("air-ce-mask-linear"),
                permutedMaskDigest: Digest256.hash("air-ce-permuted-mask"),
                permutedMaskedWitnessDigest: Digest256.hash("air-ce-permuted-masked")
            )
        ]
        let response = CEOpeningProofResponse.permutedWitness([
            CEOpeningNormResponse(
                permutedMask: Array(repeating: .zero, count: privateLength),
                permutedWitness: Array(repeating: .zero, count: privateLength)
            )
        ])
        let proof = try CEOpeningProof(rounds: Array(
            repeating: CEOpeningProofRound(commitments: commitments, response: response),
            count: CEOpeningProof.roundCount
        ))

        let rows = try CEOpeningRelation.terminalVerifierAIRPrimitiveRows(
            proof: proof,
            statement: statement,
            shape: fixture.input.shape,
            key: fixture.key
        )
        let provenances = Set(rows.map(\.provenance))
        XCTAssertTrue(provenances.contains(.primitiveArithmetic))
        XCTAssertTrue(provenances.contains(.canonicalDecoding))
        XCTAssertTrue(provenances.contains(.hashSubrelation))
        XCTAssertTrue(provenances.contains(.publicCoinBinding))
        XCTAssertTrue(rows.allSatisfy { $0.kind == .terminalCEOpening })
        XCTAssertLessThan(rows.count, CEOpeningProof.roundCount)
    }

    func testTerminalVerifierAIRPrimitiveBatchCommitsFullRowsBeforeChallenges() throws {
        let rows = (0..<40).map { index in
            SuperNeoTerminalVerifierAIRConstraintRow(
                kind: .terminalCEOpening,
                provenance: index.isMultiple(of: 3) ? .canonicalDecoding : .primitiveArithmetic,
                label: "batch-row-\(index)",
                observed: GoldilocksField(UInt64(1_000 + index)),
                expected: GoldilocksField(UInt64(1_000 + index))
            )
        }
        try SuperNeoTerminalVerifierAIRPrimitiveBatch.validateCanonicalRowIndices(Array(rows.indices))
        XCTAssertThrowsError(
            try SuperNeoTerminalVerifierAIRPrimitiveBatch.validateCanonicalRowIndices([0, 1, 1, 3])
        )
        XCTAssertThrowsError(
            try SuperNeoTerminalVerifierAIRPrimitiveBatch.validateCanonicalRowIndices([0, 2, 3])
        )

        let base = SuperNeoTerminalVerifierAIRPrimitiveBatch.summarize(rows, label: "batch-test")
        XCTAssertEqual(base.rowCount, rows.count)
        XCTAssertEqual(base.aggregateResidual, .zero)

        let missing = SuperNeoTerminalVerifierAIRPrimitiveBatch.summarize(
            Array(rows.dropLast()),
            label: "batch-test"
        )
        XCTAssertNotEqual(base.observedTranscriptDigest, missing.observedTranscriptDigest)
        XCTAssertNotEqual(base.challengeDigest, missing.challengeDigest)

        let reordered = SuperNeoTerminalVerifierAIRPrimitiveBatch.summarize(
            [rows[1], rows[0]] + Array(rows.dropFirst(2)),
            label: "batch-test"
        )
        XCTAssertNotEqual(base.observedTranscriptDigest, reordered.observedTranscriptDigest)
        XCTAssertNotEqual(base.challengeDigest, reordered.challengeDigest)

        var mutatedRows = rows
        mutatedRows[25] = SuperNeoTerminalVerifierAIRConstraintRow(
            kind: .terminalCEOpening,
            provenance: .primitiveArithmetic,
            label: "batch-row-25",
            observed: GoldilocksField(2_025),
            expected: GoldilocksField(1_025)
        )
        let mutated = SuperNeoTerminalVerifierAIRPrimitiveBatch.summarize(
            mutatedRows,
            label: "batch-test"
        )
        XCTAssertNotEqual(base.observedTranscriptDigest, mutated.observedTranscriptDigest)
        XCTAssertNotEqual(base.challengeDigest, mutated.challengeDigest)
        XCTAssertNotEqual(base.coefficients[25], mutated.coefficients[25])
        XCTAssertNotEqual(mutated.aggregateResidual, .zero)
    }

    func testTerminalVerifierAIRPrimitiveBatchBindsPublicContext() throws {
        let rows = (0..<3).map { index in
            SuperNeoTerminalVerifierAIRConstraintRow(
                kind: .piRLCVerifier,
                provenance: .publicCoinBinding,
                label: "context-row-\(index)",
                observed: GoldilocksField(UInt64(index + 7)),
                expected: GoldilocksField(UInt64(index + 7))
            )
        }
        let relation = Digest256.hash("batch-context-relation")
        let recursive = Digest256.hash("batch-context-recursive")
        let source = Digest256.hash("batch-context-source")
        let publicInput = Digest256.hash("batch-context-public-input")
        let policy = Digest256.hash("batch-context-policy")
        let root = SuperNeoTerminalVerifierAIRPrimitiveBatch.contextRoot(
            rows: rows,
            label: "context-test",
            terminalVerifierRelationDigest: relation,
            recursiveRelationDigest: recursive,
            sourceDigest: source,
            sourceByteCount: 99,
            publicInputDigest: publicInput,
            compressionPolicyDigest: policy
        )

        func contextRoot(
            relationDigest: Digest256 = relation,
            recursiveDigest: Digest256 = recursive,
            sourceDigest: Digest256 = source,
            sourceByteCount: Int = 99,
            publicInputDigest: Digest256 = publicInput,
            policyDigest: Digest256 = policy
        ) -> Digest256 {
            SuperNeoTerminalVerifierAIRPrimitiveBatch.contextRoot(
                rows: rows,
                label: "context-test",
                terminalVerifierRelationDigest: relationDigest,
                recursiveRelationDigest: recursiveDigest,
                sourceDigest: sourceDigest,
                sourceByteCount: sourceByteCount,
                publicInputDigest: publicInputDigest,
                compressionPolicyDigest: policyDigest
            )
        }

        XCTAssertNotEqual(root, contextRoot(relationDigest: Digest256.hash("batch-context-relation-mutated")))
        XCTAssertNotEqual(root, contextRoot(recursiveDigest: Digest256.hash("batch-context-recursive-mutated")))
        XCTAssertNotEqual(root, contextRoot(sourceDigest: Digest256.hash("batch-context-source-mutated")))
        XCTAssertNotEqual(root, contextRoot(sourceByteCount: 100))
        XCTAssertNotEqual(root, contextRoot(publicInputDigest: Digest256.hash("batch-context-public-input-mutated")))
        XCTAssertNotEqual(root, contextRoot(policyDigest: Digest256.hash("batch-context-policy-mutated")))
    }

    func testTerminalVerifierAIRPrimitiveBatchRejectsShortcutProvenance() throws {
        let primitive = SuperNeoTerminalVerifierAIRConstraintRow(
            kind: .terminalCEOpening,
            provenance: .primitiveArithmetic,
            label: "primitive-row",
            observed: .one,
            expected: .one
        )
        XCTAssertNoThrow(try SuperNeoTerminalVerifierAIRPrimitiveBatch.validateRowsForBatching([primitive]))

        let pcsShortcut = SuperNeoTerminalVerifierAIRConstraintRow(
            kind: .terminalCEOpening,
            provenance: .friPCSVerifier,
            label: "digest-matches-shortcut",
            observed: .one,
            expected: .one
        )
        XCTAssertThrowsError(try SuperNeoTerminalVerifierAIRPrimitiveBatch.validateRowsForBatching([pcsShortcut]))

        let manualAcceptBit = SuperNeoTerminalVerifierAIRConstraintRow(
            kind: .acceptAggregation,
            provenance: .primitiveArithmetic,
            label: "manual-accept-bit-witness",
            observed: .one,
            expected: .one
        )
        XCTAssertThrowsError(try SuperNeoTerminalVerifierAIRPrimitiveBatch.validateRowsForBatching([manualAcceptBit]))
    }

    func testTerminalVerifierAIRFoldRowsRejectTamperedRLCChallengeByPrimitiveResidual() throws {
        let fixture = try makeFoldFixture()
        let proof = try SuperNeoProver(key: fixture.key)
            .foldWithOutput(fixture.input, transcriptSeed: fixture.seed)
            .proof
        var challenges = proof.randomLinearCombinationChallenges
        challenges[0] = challenges[0] + CyclotomicRing54.one
        let tampered = FoldProof(
            sumCheck: proof.sumCheck,
            randomLinearCombinationChallenges: challenges,
            piCCSClaims: proof.piCCSClaims,
            foldedClaim: proof.foldedClaim,
            decomposition: proof.decomposition,
            outputClaims: proof.outputClaims,
            auxiliaryPiCCSTapes: proof.auxiliaryPiCCSTapes,
            auxiliaryPiRLCBranches: proof.auxiliaryPiRLCBranches
        )

        let rows = try SuperNeoVerifier(key: fixture.key).terminalVerifierAIRPrimitiveRows(
            publicInput: SuperNeoPublicFoldInput(fixture.input),
            proof: tampered,
            transcriptSeed: fixture.seed
        )
        XCTAssertTrue(rows.piRLCRows.contains { $0.provenance == .publicCoinBinding && $0.residual != .zero })
        XCTAssertTrue(rows.piCCSRows.allSatisfy { $0.provenance != .friPCSVerifier })
        XCTAssertTrue(rows.piDECRows.allSatisfy { $0.provenance != .friPCSVerifier })
    }

    func testSpartanFRICompressionRejectsBelowMinimumQueryCount() throws {
        let fixture = try makeFoldFixture()
        let publicInput = SuperNeoPublicFoldInput(fixture.input)
        let statement = CCSStatement(
            shapeDigest: publicInput.shape.shapeDigest,
            ccsInstances: publicInput.instances,
            priorCEInstances: publicInput.priorClaims.map(CEInstance.init)
        )
        let context = ProofEnvelopeContext(
            profileID: SuperNeoParameters.goldilocks.profileID,
            kind: .terminalLocal,
            statement: statement,
            verifierKeyDigest: fixture.key.verifierKeyDigest
        )
        let envelope = try SuperNeoProver(key: fixture.key).terminalFoldEnvelopeDeterministic(
            fixture.input,
            context: context,
            ceRandomSeed: Array("spartan-fri-low-query-ce".utf8)
        )
        let policy = SuperNeoTerminalProofAcceptancePolicy(
            statement: statement,
            verifierKeyDigest: fixture.key.verifierKeyDigest,
            profileID: SuperNeoParameters.goldilocks.profileID,
            transcriptDomain: context.transcriptDomain,
            proofKindPolicy: .terminalOnly
        )

        XCTAssertThrowsSuperNeoError(
            try SuperNeoSpartanFRICompressor.compressAcceptedProof(
                publicInput: publicInput,
                proofBytes: envelope.superNeoBytes,
                verifierKey: fixture.key,
                policy: policy,
                queryCount: 1
            ),
            .invalidParameter("Spartan/FRI compression query count below selected minimum")
        )
    }

    func testSpartanFRIVerifierRejectsMaliciousLowDegreeProofShapes() throws {
        let fixture = try makeTerminalCompressionProof(seed: "spartan-fri-malicious-ce")
        let proof = fixture.proof

        func verify(
            witnessPCS: SuperNeoFRIProof? = nil,
            residualPCS: SuperNeoFRIProof? = nil
        ) throws -> VerificationResult {
            let tamperedProof = try SuperNeoSpartanFRICompressionProof(
                statement: proof.statement,
                arithmetizationDigest: proof.arithmetizationDigest,
                traceVectorLength: proof.traceVectorLength,
                paddedDomainSize: proof.paddedDomainSize,
                terminalVerifierPCSProof: proof.terminalVerifierPCSProof,
                witnessPCS: witnessPCS ?? proof.witnessPCS,
                residualPCS: residualPCS ?? proof.residualPCS
            )
            return SuperNeoSpartanFRICompressor.verifyCompressionProof(
                tamperedProof,
                sourceProofBytes: fixture.sourceProofBytes,
                publicInput: fixture.publicInput,
                verifierKey: fixture.verifierKey,
                policy: fixture.policy
            )
        }

        XCTAssertEqual(try verify(), .valid)

        var nonzeroResidual = Array(repeating: GoldilocksField.zero, count: proof.traceVectorLength)
        nonzeroResidual[0] = .one
        let inconsistentResidualPCS = try makeFRIProof(
            vector: nonzeroResidual,
            paddedDomainSize: proof.paddedDomainSize,
            queryCount: proof.residualPCS.queryCount,
            blowupFactor: proof.residualPCS.blowupFactor,
            claimedDegreeBound: proof.residualPCS.claimedDegreeBound,
            label: "r1cs-residual",
            bindingDigest: proof.arithmetizationDigest
        )
        XCTAssertEqual(
            try verify(residualPCS: inconsistentResidualPCS),
            .invalid("Spartan residual opening is nonzero")
        )

        var duplicatedQueries = proof.witnessPCS.queryProofs
        duplicatedQueries[1] = duplicatedQueries[0]
        let duplicatedQueryPCS = try rebuildFRIProof(proof.witnessPCS, queryProofs: duplicatedQueries)
        XCTAssertEqual(
            try verify(witnessPCS: duplicatedQueryPCS),
            .invalid("verificationFailed(\"FRI query indices must be unique\")")
        )

        var malformedPointQueries = proof.witnessPCS.queryProofs
        var malformedPointQuery = malformedPointQueries[0]
        var malformedPointLayers = malformedPointQuery.layerOpenings
        var malformedPointLayer = malformedPointLayers[0]
        let pointOpening = malformedPointLayer[0]
        malformedPointLayer[0] = SuperNeoFRIMerkleOpening(
            index: pointOpening.index,
            leafCount: pointOpening.leafCount,
            point: pointOpening.point + .one,
            value: pointOpening.value,
            siblings: pointOpening.siblings
        )
        malformedPointLayers[0] = malformedPointLayer
        malformedPointQuery = SuperNeoFRIQueryProof(
            initialIndex: malformedPointQuery.initialIndex,
            layerOpenings: malformedPointLayers
        )
        malformedPointQueries[0] = malformedPointQuery
        let malformedPointPCS = try rebuildFRIProof(proof.witnessPCS, queryProofs: malformedPointQueries)
        XCTAssertEqual(
            try verify(witnessPCS: malformedPointPCS),
            .invalid("verificationFailed(\"FRI domain point mismatch\")")
        )

        var inconsistentFoldQueries = proof.witnessPCS.queryProofs
        var inconsistentFoldQuery = inconsistentFoldQueries[0]
        var inconsistentFoldLayers = inconsistentFoldQuery.layerOpenings
        var inconsistentFoldLayer = inconsistentFoldLayers[0]
        let nextOpening = inconsistentFoldLayer[2]
        inconsistentFoldLayer[2] = SuperNeoFRIMerkleOpening(
            index: nextOpening.index,
            leafCount: nextOpening.leafCount,
            point: nextOpening.point,
            value: nextOpening.value + .one,
            siblings: nextOpening.siblings
        )
        inconsistentFoldLayers[0] = inconsistentFoldLayer
        inconsistentFoldQuery = SuperNeoFRIQueryProof(
            initialIndex: inconsistentFoldQuery.initialIndex,
            layerOpenings: inconsistentFoldLayers
        )
        inconsistentFoldQueries[0] = inconsistentFoldQuery
        let inconsistentFoldPCS = try rebuildFRIProof(proof.witnessPCS, queryProofs: inconsistentFoldQueries)
        XCTAssertEqual(
            try verify(witnessPCS: inconsistentFoldPCS),
            .invalid("verificationFailed(\"FRI Merkle opening mismatch\")")
        )

        let fakeFinalPCS = try rebuildFRIProof(
            proof.witnessPCS,
            finalPolynomial: [proof.witnessPCS.finalPolynomial[0] + .one]
        )
        XCTAssertEqual(
            try verify(witnessPCS: fakeFinalPCS),
            .invalid("verificationFailed(\"FRI final constant check mismatch\")")
        )
    }

    func testSpartanFRICosetNTTMatchesHornerEvaluation() throws {
        let root = try SuperNeoSpartanFRITestHooks.rootOfUnity(order: 8)
        let cosets: [GoldilocksField] = [
            .one,
            GoldilocksField(3),
            GoldilocksField(7)
        ]
        let polynomials: [[GoldilocksField]] = [
            [.zero],
            [GoldilocksField(5)],
            [.zero, .one, GoldilocksField(2), .zero],
            [GoldilocksField(9), .zero, .zero, GoldilocksField(4), GoldilocksField(11)],
            (0..<8).map { GoldilocksField(UInt64($0 + 1)) }
        ]
        for coset in cosets {
            for coefficients in polynomials {
                let horner = try SuperNeoSpartanFRITestHooks.hornerEvaluateOnDomain(
                    coefficients: coefficients,
                    size: 8,
                    root: root,
                    coset: coset
                )
                let ntt = try SuperNeoSpartanFRITestHooks.nttEvaluateOnDomain(
                    coefficients: coefficients,
                    size: 8,
                    root: root,
                    coset: coset
                )
                XCTAssertEqual(ntt, horner, "NTT domain evaluation must match Horner evaluation")
            }
        }
    }

    func testSpartanFRIPlanReuseMatchesFreshProofAndBindsJointQueries() throws {
        let vector = (0..<16).map { GoldilocksField(UInt64($0 * 3 + 1)) }
        let binding = Digest256.hash("fri-plan-reuse-test")
        let fresh = try SuperNeoSpartanFRITestHooks.freshFRIProof(
            vector: vector,
            paddedDomainSize: 32,
            queryCount: 4,
            blowupFactor: 2,
            claimedDegreeBound: vector.count,
            label: "plan-reuse",
            bindingDigest: binding
        )
        let planned = try SuperNeoSpartanFRITestHooks.plannedFRIProof(
            vector: vector,
            paddedDomainSize: 32,
            queryCount: 4,
            blowupFactor: 2,
            claimedDegreeBound: vector.count,
            label: "plan-reuse",
            bindingDigest: binding
        )
        XCTAssertEqual(planned.superNeoBytes, fresh.superNeoBytes)

        let residualVector = vector.map { $0 + GoldilocksField(1) }
        let residual = try SuperNeoSpartanFRITestHooks.plannedFRIProof(
            vector: residualVector,
            paddedDomainSize: 32,
            queryCount: 4,
            blowupFactor: 2,
            claimedDegreeBound: residualVector.count,
            label: "plan-reuse-residual",
            bindingDigest: binding
        )
        let jointA = SuperNeoSpartanFRITestHooks.jointAIRQueryIndices(
            traceCommitments: planned.commitments,
            residualCommitments: residual.commitments,
            relationDigest: binding,
            queryCount: 4,
            paddedDomainSize: 32
        )
        var mutatedResidualCommitments = residual.commitments
        mutatedResidualCommitments[0] = SuperNeoFRICommitment(
            domainSize: mutatedResidualCommitments[0].domainSize,
            root: Digest384.shake256("mutated-residual-root")
        )
        let jointB = SuperNeoSpartanFRITestHooks.jointAIRQueryIndices(
            traceCommitments: planned.commitments,
            residualCommitments: mutatedResidualCommitments,
            relationDigest: binding,
            queryCount: 4,
            paddedDomainSize: 32
        )
        XCTAssertNotEqual(jointA, jointB, "joint AIR query schedule must bind trace and residual commitments")
    }

    func testSourceFreePCSProductionSmokeIsPolicyBoundAndNotTinyPolicy() throws {
        let fixture = try makeMinimalSourceFreePCSFixture()
        let productionProof = try SuperNeoSpartanFRICompressor.makeSourceFreeCompressionProofForTesting(
            publicInput: fixture.publicInput,
            verifierKey: fixture.verifierKey,
            policy: fixture.productionPolicy
        )

        XCTAssertEqual(
            SuperNeoSpartanFRICompressor.verifyCompressionProof(
                proofBytes: productionProof.superNeoBytes,
                publicInput: fixture.publicInput,
                verifierKey: fixture.verifierKey,
                policy: fixture.productionPolicy
            ),
            .valid
        )

        let mutatedResidualCommitment = try mutateFirstOccurrence(
            proofBytes: productionProof.superNeoBytes,
            target: productionProof.terminalVerifierPCSProof.residualPCS.baseCommitment.root.superNeoBytes,
            label: "production terminal residual commitment"
        )
        XCTAssertFalse(SuperNeoSpartanFRICompressor.verifyCompressionProof(
            proofBytes: mutatedResidualCommitment,
            publicInput: fixture.publicInput,
            verifierKey: fixture.verifierKey,
            policy: fixture.productionPolicy
        ).isValid, "production residual commitment mutation")

        let wrongRecursiveInput = SuperNeoPublicFoldInput(
            shape: fixture.publicInput.shape,
            instances: fixture.publicInput.instances,
            priorClaims: fixture.publicInput.priorClaims,
            recursiveRelationDigest: Digest256.hash("minimal-source-free-pcs-recursive-relation-mutated")
        )
        XCTAssertFalse(SuperNeoSpartanFRICompressor.verifyCompressionProof(
            proofBytes: productionProof.superNeoBytes,
            publicInput: wrongRecursiveInput,
            verifierKey: fixture.verifierKey,
            policy: fixture.productionPolicy
        ).isValid, "production recursiveRelationDigest mutation")

        XCTAssertFalse(SuperNeoSpartanFRICompressor.verifyCompressionProof(
            proofBytes: productionProof.superNeoBytes,
            publicInput: fixture.publicInput,
            verifierKey: fixture.verifierKey,
            policy: fixture.tinyPolicy
        ).isValid, "production proof must reject under tiny PCS policy")

        let tinyProof = try SuperNeoSpartanFRICompressor.makeSourceFreeCompressionProofForTesting(
            publicInput: fixture.publicInput,
            verifierKey: fixture.verifierKey,
            policy: fixture.tinyPolicy,
            queryCount: 1
        )
        XCTAssertFalse(SuperNeoSpartanFRICompressor.verifyCompressionProof(
            proofBytes: tinyProof.superNeoBytes,
            publicInput: fixture.publicInput,
            verifierKey: fixture.verifierKey,
            policy: fixture.productionPolicy
        ).isValid, "tiny PCS proof must reject under production policy")
    }

    func testRealSourceTerminalEnvelopeFeedsSameTerminalAIRRelation() throws {
        let fixture = try makeMinimalTerminalSourceEnvelopeFixture()
        let material = try SuperNeoSpartanFRITestHooks.terminalAIRMaterialForSourceEnvelope(
            proofBytes: fixture.sourceProofBytes,
            publicInput: fixture.publicInput,
            verifierKey: fixture.verifierKey,
            policy: fixture.policy
        )
        XCTAssertGreaterThan(material.rowCount, 0)
        XCTAssertTrue(material.allResidualsZero)
        XCTAssertEqual(material.aggregateResidual, .zero)

        var mutatedSource = fixture.sourceProofBytes
        mutatedSource[mutatedSource.count - 1] ^= 0x01
        do {
            let mutated = try SuperNeoSpartanFRITestHooks.terminalAIRMaterialForSourceEnvelope(
                proofBytes: mutatedSource,
                publicInput: fixture.publicInput,
                verifierKey: fixture.verifierKey,
                policy: fixture.policy
            )
            XCTAssertFalse(
                mutated.allResidualsZero,
                "mutating the source envelope must produce a nonzero terminal AIR residual"
            )
            XCTAssertNotEqual(
                mutated.rowTranscriptDigest,
                material.rowTranscriptDigest,
                "source mutation must change the primitive-row transcript"
            )
        } catch {
            XCTAssertTrue("\(error)".contains("verification") || "\(error)".contains("invalid"))
        }
    }

    func testSourceFreePCSValidThenMutatedBindingsReject() throws {
        let fixture = try makeFoldFixture()
        let basePublicInput = SuperNeoPublicFoldInput(fixture.input)
        let publicInput = SuperNeoPublicFoldInput(
            shape: basePublicInput.shape,
            instances: basePublicInput.instances,
            priorClaims: basePublicInput.priorClaims,
            recursiveRelationDigest: Digest256.hash("tiny-source-free-pcs-recursive-relation")
        )
        let statement = CCSStatement(
            shapeDigest: publicInput.shape.shapeDigest,
            ccsInstances: publicInput.instances,
            priorCEInstances: publicInput.priorClaims.map(CEInstance.init),
            recursiveRelationDigest: publicInput.recursiveRelationDigest
        )
        let context = ProofEnvelopeContext(
            profileID: SuperNeoParameters.goldilocks.profileID,
            kind: .terminalLocal,
            statement: statement,
            verifierKeyDigest: fixture.key.verifierKeyDigest
        )
        let policy = SuperNeoTerminalProofAcceptancePolicy(
            statement: statement,
            verifierKeyDigest: fixture.key.verifierKeyDigest,
            profileID: SuperNeoParameters.goldilocks.profileID,
            transcriptDomain: context.transcriptDomain,
            proofKindPolicy: .terminalOnly,
            sourceFreePCSPolicy: .sourceFreeTinyPCSFixtureOnly
        )
        let proof = try SuperNeoSpartanFRICompressor.makeSourceFreeCompressionProofForTesting(
            publicInput: publicInput,
            verifierKey: fixture.key,
            policy: policy,
            queryCount: 1
        )

        XCTAssertEqual(
            SuperNeoSpartanFRICompressor.verifyCompressionProof(
                proofBytes: proof.superNeoBytes,
                publicInput: publicInput,
                verifierKey: fixture.key,
                policy: policy
            ),
            .valid
        )

        let productionPolicy = SuperNeoTerminalProofAcceptancePolicy(
            statement: statement,
            verifierKeyDigest: fixture.key.verifierKeyDigest,
            profileID: SuperNeoParameters.goldilocks.profileID,
            transcriptDomain: context.transcriptDomain,
            proofKindPolicy: .terminalOnly
        )
        XCTAssertFalse(SuperNeoSpartanFRICompressor.verifyCompressionProof(
            proofBytes: proof.superNeoBytes,
            publicInput: publicInput,
            verifierKey: fixture.key,
            policy: productionPolicy
        ).isValid, "tiny PCS proof must reject under production source-free PCS policy")

        func verifyBytes(_ bytes: [UInt8]) -> VerificationResult {
            SuperNeoSpartanFRICompressor.verifyCompressionProof(
                proofBytes: bytes,
                publicInput: publicInput,
                verifierKey: fixture.key,
                policy: policy
            )
        }

        func expectRejected(_ label: String, _ bytes: [UInt8]) {
            let result = verifyBytes(bytes)
            XCTAssertFalse(result.isValid, label)
        }

        expectRejected("sourceDigest changed", try mutateFirstOccurrence(
            proofBytes: proof.superNeoBytes,
            target: proof.statement.sourceProofDigest.superNeoBytes,
            label: "source digest"
        ))
        expectRejected("sourceByteCount changed", try mutateFirstOccurrence(
            proofBytes: proof.superNeoBytes,
            target: [proof.statement.sourceProofKind.rawValue]
                + spartanFRITestEncodeCount(proof.statement.sourceProofByteCount)
                + proof.statement.sourceProofDigest.superNeoBytes,
            byteOffset: 1,
            label: "source byte count"
        ))
        expectRejected("recursiveRelationDigest changed", try mutateFirstOccurrence(
            proofBytes: proof.superNeoBytes,
            target: try XCTUnwrap(proof.terminalVerifierPCSProof.recursiveRelationDigest).superNeoBytes,
            label: "recursive relation digest"
        ))
        expectRejected("terminalVerifierRelationDigest changed", try mutateFirstOccurrence(
            proofBytes: proof.superNeoBytes,
            target: proof.terminalVerifierPCSProof.relationDigest.superNeoBytes,
            label: "terminal verifier relation digest"
        ))
        expectRejected("verifier key digest changed", try mutateFirstOccurrence(
            proofBytes: proof.superNeoBytes,
            target: proof.statement.verifierKeyDigest.superNeoBytes,
            label: "verifier key digest"
        ))
        expectRejected("public input digest changed", try mutateFirstOccurrence(
            proofBytes: proof.superNeoBytes,
            target: proof.statement.publicInputDigest.superNeoBytes,
            label: "public input digest"
        ))
        expectRejected("policy digest changed", try mutateFirstOccurrence(
            proofBytes: proof.superNeoBytes,
            target: proof.terminalVerifierPCSProof.compressionPolicyDigest.superNeoBytes,
            label: "compression policy digest"
        ))
        expectRejected("residual commitment changed", try mutateFirstOccurrence(
            proofBytes: proof.superNeoBytes,
            target: proof.terminalVerifierPCSProof.residualPCS.baseCommitment.root.superNeoBytes,
            label: "terminal residual commitment"
        ))
        expectRejected("row transcript digest changed", try mutateFirstOccurrence(
            proofBytes: proof.superNeoBytes,
            target: proof.terminalVerifierPCSProof.tracePCS.baseCommitment.root.superNeoBytes,
            label: "terminal trace row transcript commitment"
        ))
        expectRejected("batching challenge seed changed", try mutateFirstOccurrence(
            proofBytes: proof.superNeoBytes,
            target: try XCTUnwrap(proof.terminalVerifierPCSProof.residualPCS.foldingChallenges.first).superNeoBytes,
            label: "terminal residual batching challenge"
        ))
        expectRejected("row context changed", try mutateFirstOccurrence(
            proofBytes: proof.superNeoBytes,
            target: try XCTUnwrap(proof.terminalVerifierPCSProof.tracePCS.foldedCommitments.first).root.superNeoBytes,
            label: "terminal trace row context commitment"
        ))

        let mutatedResidualOpening = try proofByMutatingTerminalResidualOpening(proof)
        let residualOpeningResult = SuperNeoSpartanFRICompressor.verifyCompressionProof(
            proofBytes: mutatedResidualOpening.superNeoBytes,
            publicInput: publicInput,
            verifierKey: fixture.key,
            policy: policy
        )
        XCTAssertFalse(residualOpeningResult.isValid, "residual opening changed")

        let mutatedAggregateResidual = try proofByMutatingTerminalResidualFinalPolynomial(proof)
        XCTAssertFalse(SuperNeoSpartanFRICompressor.verifyCompressionProof(
            proofBytes: mutatedAggregateResidual.superNeoBytes,
            publicInput: publicInput,
            verifierKey: fixture.key,
            policy: policy
        ).isValid, "aggregate residual changed")

        let wrongPublicInput = SuperNeoPublicFoldInput(
            shape: publicInput.shape,
            instances: publicInput.instances,
            priorClaims: publicInput.priorClaims,
            recursiveRelationDigest: Digest256.hash("tiny-source-free-pcs-recursive-relation-mutated")
        )
        XCTAssertFalse(SuperNeoSpartanFRICompressor.verifyCompressionProof(
            proofBytes: proof.superNeoBytes,
            publicInput: wrongPublicInput,
            verifierKey: fixture.key,
            policy: policy
        ).isValid, "recursiveRelationDigest changed through public input")

        let wrongPolicy = SuperNeoTerminalProofAcceptancePolicy(
            statement: statement,
            verifierKeyDigest: fixture.key.verifierKeyDigest,
            profileID: SuperNeoParameters.goldilocks.profileID,
            transcriptDomain: context.transcriptDomain,
            proofKindPolicy: .terminalOnly,
            sourceFreePCSPolicy: .sourceFreeTinyPCSFixtureOnly,
            maximumProofByteCount: proof.superNeoBytes.count - 1
        )
        XCTAssertFalse(SuperNeoSpartanFRICompressor.verifyCompressionProof(
            proofBytes: proof.superNeoBytes,
            publicInput: publicInput,
            verifierKey: fixture.key,
            policy: wrongPolicy
        ).isValid, "policy digest changed through policy")

        let wrongKey = try AjtaiCommitmentKey(
            columns: fixture.key.matrix.columns,
            seed: Array("tiny-source-free-pcs-wrong-key".utf8)
        )
        XCTAssertFalse(SuperNeoSpartanFRICompressor.verifyCompressionProof(
            proofBytes: proof.superNeoBytes,
            publicInput: publicInput,
            verifierKey: wrongKey,
            policy: policy
        ).isValid, "verifier key digest changed through verifier key")
    }

    func testTerminalVerifierPCSRejectsSourceDigestBindingMutation() throws {
        let fixture = try makeTerminalCompressionProof(seed: "terminal-verifier-pcs-source-digest")
        let proof = fixture.proof.terminalVerifierPCSProof

        XCTAssertThrowsError(
            try SuperNeoTerminalVerifierPCSProof(
                sourceProofKind: proof.sourceProofKind,
                sourceProofByteCount: proof.sourceProofByteCount,
                sourceProofDigest: Digest256.hash("terminal-verifier-pcs-source-digest-mutated"),
                profileID: proof.profileID,
                shapeDigest: proof.shapeDigest,
                statementDigest: proof.statementDigest,
                verifierKeyDigest: proof.verifierKeyDigest,
                transcriptDomain: proof.transcriptDomain,
                publicInputDigest: proof.publicInputDigest,
                recursiveRelationDigest: proof.recursiveRelationDigest,
                compressionPolicyDigest: proof.compressionPolicyDigest,
                terminalStatementDigest: proof.terminalStatementDigest,
                foldProofDigest: proof.foldProofDigest,
                ceOpeningProofDigest: proof.ceOpeningProofDigest,
                traceVectorLength: proof.traceVectorLength,
                paddedDomainSize: proof.paddedDomainSize,
                tracePCS: proof.tracePCS,
                residualPCS: proof.residualPCS
            )
        ) { error in
            XCTAssertTrue("\(error)".contains("joint AIR query schedule"))
        }
    }

    private func makeTerminalCompressionProof(
        seed: String
    ) throws -> (
        publicInput: SuperNeoPublicFoldInput,
        verifierKey: AjtaiCommitmentKey,
        sourceProofBytes: [UInt8],
        policy: SuperNeoTerminalProofAcceptancePolicy,
        proof: SuperNeoSpartanFRICompressionProof
    ) {
        let fixture = try makeFoldFixture()
        let publicInput = SuperNeoPublicFoldInput(fixture.input)
        let statement = CCSStatement(
            shapeDigest: publicInput.shape.shapeDigest,
            ccsInstances: publicInput.instances,
            priorCEInstances: publicInput.priorClaims.map(CEInstance.init)
        )
        let context = ProofEnvelopeContext(
            profileID: SuperNeoParameters.goldilocks.profileID,
            kind: .terminalLocal,
            statement: statement,
            verifierKeyDigest: fixture.key.verifierKeyDigest
        )
        let envelope = try SuperNeoProver(key: fixture.key).terminalFoldEnvelopeDeterministic(
            fixture.input,
            context: context,
            ceRandomSeed: Array(seed.utf8)
        )
        let policy = SuperNeoTerminalProofAcceptancePolicy(
            statement: statement,
            verifierKeyDigest: fixture.key.verifierKeyDigest,
            profileID: SuperNeoParameters.goldilocks.profileID,
            transcriptDomain: context.transcriptDomain,
            proofKindPolicy: .terminalOnly
        )
        let proof = try SuperNeoSpartanFRICompressor.compressAcceptedProof(
            publicInput: publicInput,
            proofBytes: envelope.superNeoBytes,
            verifierKey: fixture.key,
            policy: policy
        )
        return (publicInput, fixture.key, envelope.superNeoBytes, policy, proof)
    }

    private struct MinimalPCSFixture {
        let publicInput: SuperNeoPublicFoldInput
        let verifierKey: AjtaiCommitmentKey
        let productionPolicy: SuperNeoTerminalProofAcceptancePolicy
        let tinyPolicy: SuperNeoTerminalProofAcceptancePolicy
    }

    private func makeMinimalSourceFreePCSFixture() throws -> MinimalPCSFixture {
        let publicInput: [GoldilocksField] = []
        let privateWitness = [GoldilocksField.zero]
        let message = publicInput + privateWitness
        let matrix = try SparseFieldMatrix.identity(size: message.count)
        let structure = CCSStructure.hadamardProduct(matrices: [matrix])
        let backend = SuperNeoCPUBackend()
        let key = try AjtaiCommitmentKey(
            columns: SuperNeoEmbedding.paddedLength(forFieldElementCount: message.count) / CyclotomicRing54.degree,
            seed: Array("minimal-source-free-pcs-fixture-key".utf8)
        )
        let commitment = try backend.commit(key: key, message: message)
        let input = try SuperNeoFoldInput(
            structure: structure,
            instances: [CCSInstance(commitment: commitment, publicInput: publicInput)],
            witnesses: [CCSWitness(privateWitness)]
        )
        let recursiveRelationDigest = Digest256.hash("minimal-source-free-pcs-recursive-relation")
        let publicFoldInput = SuperNeoPublicFoldInput(
            shape: input.shape,
            instances: input.instances,
            priorClaims: input.priorClaims,
            recursiveRelationDigest: recursiveRelationDigest
        )
        let statement = CCSStatement(
            shapeDigest: publicFoldInput.shape.shapeDigest,
            ccsInstances: publicFoldInput.instances,
            priorCEInstances: publicFoldInput.priorClaims.map(CEInstance.init),
            recursiveRelationDigest: recursiveRelationDigest
        )
        let context = ProofEnvelopeContext(
            profileID: SuperNeoParameters.goldilocks.profileID,
            kind: .terminalLocal,
            statement: statement,
            verifierKeyDigest: key.verifierKeyDigest
        )
        let productionPolicy = SuperNeoTerminalProofAcceptancePolicy(
            statement: statement,
            verifierKeyDigest: key.verifierKeyDigest,
            profileID: SuperNeoParameters.goldilocks.profileID,
            transcriptDomain: context.transcriptDomain,
            proofKindPolicy: .terminalOnly
        )
        let tinyPolicy = SuperNeoTerminalProofAcceptancePolicy(
            statement: statement,
            verifierKeyDigest: key.verifierKeyDigest,
            profileID: SuperNeoParameters.goldilocks.profileID,
            transcriptDomain: context.transcriptDomain,
            proofKindPolicy: .terminalOnly,
            sourceFreePCSPolicy: .sourceFreeTinyPCSFixtureOnly
        )
        return MinimalPCSFixture(
            publicInput: publicFoldInput,
            verifierKey: key,
            productionPolicy: productionPolicy,
            tinyPolicy: tinyPolicy
        )
    }

    private struct MinimalTerminalSourceEnvelopeFixture {
        let sourceProofBytes: [UInt8]
        let publicInput: SuperNeoPublicFoldInput
        let verifierKey: AjtaiCommitmentKey
        let policy: SuperNeoTerminalProofAcceptancePolicy
    }

    private func makeMinimalTerminalSourceEnvelopeFixture() throws -> MinimalTerminalSourceEnvelopeFixture {
        let fixture = try makeFoldFixture()
        let publicInput = SuperNeoPublicFoldInput(fixture.input)
        let statement = CCSStatement(
            shapeDigest: publicInput.shape.shapeDigest,
            ccsInstances: publicInput.instances,
            priorCEInstances: publicInput.priorClaims.map(CEInstance.init)
        )
        let context = ProofEnvelopeContext(
            profileID: SuperNeoParameters.goldilocks.profileID,
            kind: .terminalLocal,
            statement: statement,
            verifierKeyDigest: fixture.key.verifierKeyDigest
        )
        let envelope = try SuperNeoProver(key: fixture.key).terminalFoldEnvelopeDeterministic(
            fixture.input,
            context: context,
            ceRandomSeed: Array("minimal-real-source-terminal-air".utf8)
        )
        let policy = SuperNeoTerminalProofAcceptancePolicy(
            statement: statement,
            verifierKeyDigest: fixture.key.verifierKeyDigest,
            profileID: SuperNeoParameters.goldilocks.profileID,
            transcriptDomain: context.transcriptDomain,
            proofKindPolicy: .terminalOnly
        )
        XCTAssertEqual(
            SuperNeoVerifier(key: fixture.key).verifyTerminalFoldEnvelope(
                publicInput: publicInput,
                proofBytes: envelope.superNeoBytes,
                context: context
            ),
            .valid
        )
        return MinimalTerminalSourceEnvelopeFixture(
            sourceProofBytes: envelope.superNeoBytes,
            publicInput: publicInput,
            verifierKey: fixture.key,
            policy: policy
        )
    }

    private func rebuildFRIProof(
        _ proof: SuperNeoFRIProof,
        queryProofs: [SuperNeoFRIQueryProof]? = nil,
        finalPolynomial: [GoldilocksField]? = nil
    ) throws -> SuperNeoFRIProof {
        try SuperNeoFRIProof(
            vectorLength: proof.vectorLength,
            paddedDomainSize: proof.paddedDomainSize,
            queryCount: proof.queryCount,
            blowupFactor: proof.blowupFactor,
            claimedDegreeBound: proof.claimedDegreeBound,
            domainRoot: proof.domainRoot,
            cosetGenerator: proof.cosetGenerator,
            baseCommitment: proof.baseCommitment,
            foldedCommitments: proof.foldedCommitments,
            foldingChallenges: proof.foldingChallenges,
            queryProofs: queryProofs ?? proof.queryProofs,
            finalPolynomial: finalPolynomial ?? proof.finalPolynomial
        )
    }

    private func proofByMutatingTerminalResidualOpening(
        _ proof: SuperNeoSpartanFRICompressionProof
    ) throws -> SuperNeoSpartanFRICompressionProof {
        let terminalPCS = proof.terminalVerifierPCSProof
        var residualQueries = terminalPCS.residualPCS.queryProofs
        var firstQuery = try XCTUnwrap(residualQueries.first)
        var layers = firstQuery.layerOpenings
        var firstLayer = try XCTUnwrap(layers.first)
        let opening = try XCTUnwrap(firstLayer.first)
        firstLayer[0] = SuperNeoFRIMerkleOpening(
            index: opening.index,
            leafCount: opening.leafCount,
            point: opening.point,
            value: opening.value + .one,
            siblings: opening.siblings
        )
        layers[0] = firstLayer
        firstQuery = SuperNeoFRIQueryProof(
            initialIndex: firstQuery.initialIndex,
            layerOpenings: layers
        )
        residualQueries[0] = firstQuery
        let malformedResidualPCS = try rebuildFRIProof(
            terminalPCS.residualPCS,
            queryProofs: residualQueries
        )
        let malformedTerminalPCS = try rebuildTerminalVerifierPCSProof(
            terminalPCS,
            residualPCS: malformedResidualPCS
        )
        return try SuperNeoSpartanFRICompressionProof(
            statement: proof.statement,
            arithmetizationDigest: SuperNeoSpartanFRICompressionProof.arithmetizationDigest(
                statement: proof.statement,
                terminalVerifierPCSProof: malformedTerminalPCS,
                traceLength: proof.traceVectorLength,
                paddedDomainSize: proof.paddedDomainSize,
                blowupFactor: proof.witnessPCS.blowupFactor,
                claimedDegreeBound: proof.witnessPCS.claimedDegreeBound
            ),
            traceVectorLength: proof.traceVectorLength,
            paddedDomainSize: proof.paddedDomainSize,
            terminalVerifierPCSProof: malformedTerminalPCS,
            witnessPCS: proof.witnessPCS,
            residualPCS: proof.residualPCS
        )
    }

    private func proofByMutatingTerminalResidualFinalPolynomial(
        _ proof: SuperNeoSpartanFRICompressionProof
    ) throws -> SuperNeoSpartanFRICompressionProof {
        let terminalPCS = proof.terminalVerifierPCSProof
        let malformedResidualPCS = try rebuildFRIProof(
            terminalPCS.residualPCS,
            finalPolynomial: [try XCTUnwrap(terminalPCS.residualPCS.finalPolynomial.first) + .one]
        )
        let malformedTerminalPCS = try rebuildTerminalVerifierPCSProof(
            terminalPCS,
            residualPCS: malformedResidualPCS
        )
        return try SuperNeoSpartanFRICompressionProof(
            statement: proof.statement,
            arithmetizationDigest: SuperNeoSpartanFRICompressionProof.arithmetizationDigest(
                statement: proof.statement,
                terminalVerifierPCSProof: malformedTerminalPCS,
                traceLength: proof.traceVectorLength,
                paddedDomainSize: proof.paddedDomainSize,
                blowupFactor: proof.witnessPCS.blowupFactor,
                claimedDegreeBound: proof.witnessPCS.claimedDegreeBound
            ),
            traceVectorLength: proof.traceVectorLength,
            paddedDomainSize: proof.paddedDomainSize,
            terminalVerifierPCSProof: malformedTerminalPCS,
            witnessPCS: proof.witnessPCS,
            residualPCS: proof.residualPCS
        )
    }

    private func mutateFirstOccurrence(
        proofBytes: [UInt8],
        target: [UInt8],
        byteOffset: Int = 0,
        label: String
    ) throws -> [UInt8] {
        XCTAssertFalse(target.isEmpty, "empty mutation target for \(label)")
        XCTAssertLessThan(byteOffset, target.count, "mutation offset out of target for \(label)")
        guard target.count <= proofBytes.count else {
            throw SuperNeoError.invalidParameter("mutation target \(label) longer than proof bytes")
        }
        let lastStart = proofBytes.count - target.count
        for start in 0...lastStart where Array(proofBytes[start..<(start + target.count)]) == target {
            var mutated = proofBytes
            mutated[start + byteOffset] ^= 0x01
            return mutated
        }
        throw SuperNeoError.invalidParameter("mutation target \(label) not found")
    }

    private func spartanFRITestEncodeCount(_ value: Int) -> [UInt8] {
        withUnsafeBytes(of: UInt64(value).littleEndian, Array.init)
    }

    private func rebuildTerminalVerifierPCSProof(
        _ proof: SuperNeoTerminalVerifierPCSProof,
        tracePCS: SuperNeoFRIProof? = nil,
        residualPCS: SuperNeoFRIProof? = nil
    ) throws -> SuperNeoTerminalVerifierPCSProof {
        try SuperNeoTerminalVerifierPCSProof(
            sourceProofKind: proof.sourceProofKind,
            sourceProofByteCount: proof.sourceProofByteCount,
            sourceProofDigest: proof.sourceProofDigest,
            profileID: proof.profileID,
            shapeDigest: proof.shapeDigest,
            statementDigest: proof.statementDigest,
            verifierKeyDigest: proof.verifierKeyDigest,
            transcriptDomain: proof.transcriptDomain,
            publicInputDigest: proof.publicInputDigest,
            recursiveRelationDigest: proof.recursiveRelationDigest,
            compressionPolicyDigest: proof.compressionPolicyDigest,
            terminalStatementDigest: proof.terminalStatementDigest,
            foldProofDigest: proof.foldProofDigest,
            ceOpeningProofDigest: proof.ceOpeningProofDigest,
            traceVectorLength: proof.traceVectorLength,
            paddedDomainSize: proof.paddedDomainSize,
            tracePCS: tracePCS ?? proof.tracePCS,
            residualPCS: residualPCS ?? proof.residualPCS
        )
    }
}
