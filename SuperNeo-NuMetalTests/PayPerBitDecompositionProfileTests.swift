import XCTest
@_spi(Benchmarking) @testable import SuperNeo_NuMetal

final class PayPerBitDecompositionProfileTests: XCTestCase {
    func testPayPerBitProfileProducesShorterVerifiedFoldOutputs() throws {
        let fixture = try makeFixture(label: "shorter-fold")
        let fixed = try SuperNeoProver(
            key: fixture.key,
            decompositionProfile: .fixedMaximum
        ).foldWithOutput(
            fixture.input,
            transcriptSeed: fixture.seed
        )
        let defaultProver = SuperNeoProver(key: fixture.key)
        XCTAssertEqual(defaultProver.decompositionProfile, .payPerBit)
        let adaptive = try defaultProver.foldWithOutput(
            fixture.input,
            transcriptSeed: fixture.seed
        )

        XCTAssertEqual(fixed.outputClaims.count, fixture.parameters.decompositionLength)
        XCTAssertGreaterThan(adaptive.outputClaims.count, 0)
        XCTAssertLessThan(adaptive.outputClaims.count, fixture.parameters.decompositionLength)
        XCTAssertEqual(adaptive.proof.outputClaims.count, adaptive.outputClaims.count)
        XCTAssertEqual(adaptive.proof.decomposition.commitments.count, adaptive.outputClaims.count)
        XCTAssertEqual(adaptive.proof.decomposition.evaluations.count, adaptive.outputClaims.count)

        let verifier = SuperNeoVerifier(key: fixture.key)
        let reduction = verifier.reduceFold(
            input: fixture.input,
            proof: adaptive.proof,
            transcriptSeed: fixture.seed
        )
        XCTAssertTrue(reduction.isReductionAccepted, reduction.reason ?? "fold reduction rejected")
        XCTAssertEqual(reduction.outputClaims.count, adaptive.outputClaims.count)
        XCTAssertEqual(
            verifier.verifyFold(
                input: fixture.input,
                proof: adaptive.proof,
                outputClaims: adaptive.outputClaims,
                transcriptSeed: fixture.seed
            ),
            .valid
        )
    }

    func testPayPerBitProofEnvelopesRoundTripWithVariableOpeningCount() throws {
        let fixture = try makeFixture(label: "envelope")
        let prover = SuperNeoProver(key: fixture.key, decompositionProfile: .payPerBit)
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
