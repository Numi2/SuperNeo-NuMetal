import XCTest
@_spi(Benchmarking) @testable import SuperNeo_NuMetal

final class PayPerBitDecompositionProfileTests: XCTestCase {
    func testDefaultPayPerBitProfileUsesConstantScheduleForPrivateFoldOutputs() throws {
        let fixture = try makeFixture(label: "constant-fold")
        let fixed = try SuperNeoProver(
            key: fixture.key,
            decompositionProfile: .fixedMaximum
        ).foldWithOutput(
            fixture.input,
            transcriptSeed: fixture.seed
        )
        let defaultProver = SuperNeoProver(key: fixture.key)
        XCTAssertEqual(defaultProver.decompositionProfile, .payPerBit)
        XCTAssertTrue(defaultProver.executionPolicy.usesConstantWorkCPU)
        let constantSchedule = try defaultProver.foldWithOutput(
            fixture.input,
            transcriptSeed: fixture.seed
        )

        XCTAssertEqual(fixed.outputClaims.count, fixture.parameters.decompositionLength)
        XCTAssertEqual(constantSchedule.outputClaims.count, fixture.parameters.decompositionLength)
        XCTAssertEqual(constantSchedule.proof.outputClaims.count, constantSchedule.outputClaims.count)
        XCTAssertEqual(constantSchedule.proof.decomposition.commitments.count, constantSchedule.outputClaims.count)
        XCTAssertEqual(constantSchedule.proof.decomposition.evaluations.count, constantSchedule.outputClaims.count)

        let verifier = SuperNeoVerifier(key: fixture.key)
        let reduction = verifier.reduceFold(
            input: fixture.input,
            proof: constantSchedule.proof,
            transcriptSeed: fixture.seed
        )
        XCTAssertTrue(reduction.isReductionAccepted, reduction.reason ?? "fold reduction rejected")
        XCTAssertEqual(reduction.outputClaims.count, constantSchedule.outputClaims.count)
        XCTAssertEqual(
            verifier.verifyFold(
                input: fixture.input,
                proof: constantSchedule.proof,
                outputClaims: constantSchedule.outputClaims,
                transcriptSeed: fixture.seed
            ),
            .valid
        )
    }

    func testPayPerBitProofEnvelopesRoundTripWithVariableOpeningCount() throws {
        let fixture = try makeFixture(label: "envelope")
        let prover = SuperNeoProver(
            key: fixture.key,
            executionPolicy: SuperNeoExecutionPolicy(secretArithmetic: .optimized),
            decompositionProfile: .payPerBit
        )
        let verifier = SuperNeoVerifier(key: fixture.key)

        let foldContext = ProofEnvelopeContext(
            profileID: fixture.parameters.profileID,
            statement: fixture.statement,
            verifierKeyDigest: fixture.key.verifierKeyDigest
        )
        let fold = try prover.foldWithOutput(
            fixture.input,
            transcriptSeed: foldContext.transcriptBindingBytes
        )
        let foldEnvelope = try FoldProofEnvelope(context: foldContext, proof: fold.proof)
        let reparsedFold = try FoldProofEnvelope(bytes: foldEnvelope.superNeoBytes)

        XCTAssertLessThan(reparsedFold.proof.outputClaims.count, fixture.parameters.decompositionLength)
        XCTAssertEqual(
            verifier.verifyFoldEnvelope(
                input: fixture.input,
                proofBytes: reparsedFold.superNeoBytes,
                context: foldContext,
                outputClaims: fold.outputClaims
            ),
            .valid
        )

        let terminalContext = ProofEnvelopeContext(
            profileID: fixture.parameters.profileID,
            kind: .terminalLocal,
            statement: fixture.statement,
            verifierKeyDigest: fixture.key.verifierKeyDigest
        )
        let terminalEnvelope = try prover.terminalFoldEnvelopeDeterministic(
            fixture.input,
            context: terminalContext,
            ceRandomSeed: Array("pay-per-bit-terminal-ce-seed".utf8)
        )
        let reparsedTerminal = try TerminalFoldProofEnvelope(bytes: terminalEnvelope.superNeoBytes)

        XCTAssertLessThan(reparsedTerminal.proof.outputClaims.count, fixture.parameters.decompositionLength)
        XCTAssertEqual(
            reparsedTerminal.proof.terminalStatement.openings.count,
            reparsedTerminal.proof.outputClaims.count
        )
        XCTAssertEqual(
            verifier.verifyTerminalFoldEnvelope(
                input: fixture.input,
                proofBytes: reparsedTerminal.superNeoBytes,
                context: terminalContext
            ),
            .valid
        )
    }

    func testOptimizedPayPerBitFoldUsesVerifiableVariableOpenings() throws {
        let fixture = try makeFixture(label: "optimized-path")
        let optimizedPolicy = SuperNeoExecutionPolicy(secretArithmetic: .optimized)
        let prover = SuperNeoProver(
            key: fixture.key,
            executionPolicy: optimizedPolicy,
            decompositionProfile: .payPerBit
        )
        let output = try prover.foldWithOutput(
            fixture.input,
            transcriptSeed: fixture.seed
        )

        XCTAssertLessThan(output.outputClaims.count, fixture.parameters.decompositionLength)
        let verifier = SuperNeoVerifier(key: fixture.key)
        let reduction = verifier.reduceFold(
            input: fixture.input,
            proof: output.proof,
            transcriptSeed: fixture.seed
        )
        XCTAssertTrue(reduction.isReductionAccepted, reduction.reason ?? "")
        XCTAssertEqual(
            verifier.verifyFold(
                input: fixture.input,
                proof: output.proof,
                outputClaims: output.outputClaims,
                transcriptSeed: fixture.seed
            ),
            .valid
        )
    }

    func testPayPerBitVerifierRejectsMismatchedVariableOpeningCount() throws {
        let fixture = try makeFixture(label: "mismatched-count")
        let output = try SuperNeoProver(
            key: fixture.key,
            decompositionProfile: .payPerBit
        ).foldWithOutput(
            fixture.input,
            transcriptSeed: fixture.seed
        )
        XCTAssertGreaterThan(output.proof.decomposition.commitments.count, 1)

        let truncatedDecomposition = DecompositionProof(
            commitments: Array(output.proof.decomposition.commitments.dropLast()),
            evaluations: output.proof.decomposition.evaluations
        )
        let tamperedProof = FoldProof(
            piCCS: output.proof.piCCS,
            piRLC: output.proof.piRLC,
            piDEC: PiDECSection(
                decomposition: truncatedDecomposition,
                outputClaims: output.proof.outputClaims
            ),
            auxiliaryPiCCSTapes: output.proof.auxiliaryPiCCSTapes,
            auxiliaryPiRLCBranches: output.proof.auxiliaryPiRLCBranches
        )

        let reduction = SuperNeoVerifier(key: fixture.key).reduceFold(
            input: fixture.input,
            proof: tamperedProof,
            transcriptSeed: fixture.seed
        )
        XCTAssertFalse(reduction.isReductionAccepted)
        XCTAssertEqual(
            reduction.reason,
            "invalidParameter(\"decomposition proof count must match output claims\")"
        )
    }

    func testPayPerBitRecompositionRejectsMalformedDecompositionPlan() throws {
        let plan = try SuperNeoPayPerBitCommitter.decompositionPlan(
            fieldVector: [.one, .zero, -GoldilocksField.one]
        )
        let extraLimbPlan = SuperNeoPayPerBitDecompositionPlan(
            fieldElementCount: plan.fieldElementCount,
            paddedFieldSlotCount: plan.paddedFieldSlotCount,
            ringColumnCount: plan.ringColumnCount,
            activeLimbCount: plan.activeLimbCount,
            fixedLimbCount: plan.fixedLimbCount,
            activeDigitSlotCount: plan.activeDigitSlotCount,
            limbs: plan.limbs + [Array(repeating: .zero, count: plan.fieldElementCount)]
        )

        XCTAssertThrowsError(try SuperNeoPayPerBitCommitter.recomposeFieldVector(extraLimbPlan)) { error in
            XCTAssertEqual(error as? SuperNeoError, .invalidParameter("pay-per-bit decomposition limb count mismatch"))
        }

        var malformedDigits = plan.limbs
        malformedDigits[0][0] = GoldilocksField(2)
        let malformedDigitPlan = SuperNeoPayPerBitDecompositionPlan(
            fieldElementCount: plan.fieldElementCount,
            paddedFieldSlotCount: plan.paddedFieldSlotCount,
            ringColumnCount: plan.ringColumnCount,
            activeLimbCount: plan.activeLimbCount,
            fixedLimbCount: plan.fixedLimbCount,
            activeDigitSlotCount: plan.activeDigitSlotCount,
            limbs: malformedDigits
        )

        XCTAssertThrowsError(try SuperNeoPayPerBitCommitter.recomposeFieldVector(malformedDigitPlan)) { error in
            XCTAssertEqual(
                error as? SuperNeoError,
                .invalidParameter("pay-per-bit decomposition digit outside signed binary domain")
            )
        }
    }

    func testPayPerBitRecompositionRejectsMismatchedCommitmentRows() throws {
        let parameters = SuperNeoParameters.goldilocks
        let first = AjtaiCommitment(Array(repeating: CyclotomicRing54.zero, count: parameters.kappa))
        let second = AjtaiCommitment(Array(repeating: CyclotomicRing54.zero, count: parameters.kappa - 1))

        XCTAssertThrowsError(
            try SuperNeoPayPerBitCommitter.recomposeCommitment([first, second], parameters: parameters)
        ) { error in
            XCTAssertEqual(error as? SuperNeoError, .invalidParameter("pay-per-bit commitment row count mismatch"))
        }
    }

    private struct Fixture {
        let parameters: SuperNeoParameters
        let key: AjtaiCommitmentKey
        let input: SuperNeoFoldInput
        let statement: CCSStatement
        let seed: [UInt8]
    }

    private func makeFixture(label: String) throws -> Fixture {
        let parameters = SuperNeoParameters.goldilocks
        let shape = try SuperNeoBenchmarkFixtures.makeShape(rowCount: 64)
        let key = try AjtaiCommitmentKey(
            parameters: parameters,
            columns: shape.nRing,
            seed: Array("pay-per-bit-key-\(label)".utf8)
        )
        let (instances, witnesses, _) = try SuperNeoBenchmarkFixtures.makeInstances(
            count: 1,
            shape: shape,
            key: key,
            kind: .binary,
            seedPrefix: "pay-per-bit-fixture-\(label)"
        )
        let input = SuperNeoFoldInput(
            shape: shape,
            instances: instances,
            witnesses: witnesses
        )
        let statement = CCSStatement(
            shapeDigest: shape.shapeDigest,
            ccsInstances: input.instances
        )
        return Fixture(
            parameters: parameters,
            key: key,
            input: input,
            statement: statement,
            seed: Array("pay-per-bit-fold-\(label)".utf8)
        )
    }
}
