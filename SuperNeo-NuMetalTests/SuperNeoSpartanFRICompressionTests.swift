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
}
