import XCTest
@testable import SuperNeo_NuMetal

final class SuperNeoIVCPCDCompilerTests: SuperNeoTestCase {
    func testIVCCompilerInjectsAccumulatorAndVerifierStateAdvances() throws {
        let fixture = try makeFoldFixture()
        let prover = SuperNeoProver(key: fixture.key)
        let requests = [
            SuperNeoIVCStepRequest(input: fixture.input, transcriptSeed: Array("ivc-step-0".utf8)),
            SuperNeoIVCStepRequest(input: fixture.input, transcriptSeed: Array("ivc-step-1".utf8))
        ]

        let run = try SuperNeoFoldingCompiler.proveIVC(requests: requests, prover: prover)

        XCTAssertEqual(run.steps.count, 2)
        XCTAssertEqual(run.steps[0].statement.priorCEInstances, [])
        XCTAssertEqual(
            run.steps[1].statement.priorCEInstances,
            run.steps[0].outputAccumulator.claims.map(CEInstance.init)
        )
        XCTAssertTrue(run.steps.flatMap(\.outputAccumulator.claims).allSatisfy { $0.witness == nil })
        XCTAssertEqual(run.finalState, run.steps[1].verifierState)
        XCTAssertEqual(
            SuperNeoFoldingCompiler.verifyIVC(run, shape: fixture.input.shape, key: fixture.key),
            .valid
        )
    }

    func testIVCVerifierRejectsTamperedOutputAccumulator() throws {
        let fixture = try makeFoldFixture()
        let prover = SuperNeoProver(key: fixture.key)
        let run = try SuperNeoFoldingCompiler.proveIVC(
            requests: [
                SuperNeoIVCStepRequest(input: fixture.input, transcriptSeed: Array("ivc-tamper-0".utf8))
            ],
            prover: prover
        )
        let originalStep = try XCTUnwrap(run.steps.first)
        let tamperedAccumulator = SuperNeoAccumulator(
            profileID: prover.parameters.profileID,
            shape: fixture.input.shape,
            key: fixture.key,
            claims: Array(originalStep.outputAccumulator.claims.dropLast())
        )
        let tamperedStep = SuperNeoRecursiveCompilerStep(
            compilerKind: originalStep.compilerKind,
            nodeIndex: originalStep.nodeIndex,
            depth: originalStep.depth,
            parentNodeIndices: originalStep.parentNodeIndices,
            statement: originalStep.statement,
            transcriptSeed: originalStep.transcriptSeed,
            proof: originalStep.proof,
            outputAccumulator: tamperedAccumulator,
            reductionBoundaryReport: originalStep.reductionBoundaryReport,
            foldRelation: originalStep.foldRelation,
            verifierState: originalStep.verifierState
        )
        let tamperedRun = SuperNeoIVCRun(
            initialState: run.initialState,
            steps: [tamperedStep],
            finalState: run.finalState
        )

        XCTAssertEqual(
            SuperNeoFoldingCompiler.verifyIVC(tamperedRun, shape: fixture.input.shape, key: fixture.key),
            .invalid("verificationFailed(\"recursive compiler output accumulator mismatch\")")
        )
    }

    func testIVCVerifierRejectsDepthRollback() throws {
        let fixture = try makeFoldFixture()
        let prover = SuperNeoProver(key: fixture.key)
        let run = try SuperNeoFoldingCompiler.proveIVC(
            requests: [
                SuperNeoIVCStepRequest(input: fixture.input, transcriptSeed: Array("ivc-depth-0".utf8))
            ],
            prover: prover
        )
        let originalStep = try XCTUnwrap(run.steps.first)
        let tamperedStep = SuperNeoRecursiveCompilerStep(
            compilerKind: originalStep.compilerKind,
            nodeIndex: originalStep.nodeIndex,
            depth: 0,
            parentNodeIndices: originalStep.parentNodeIndices,
            statement: originalStep.statement,
            transcriptSeed: originalStep.transcriptSeed,
            proof: originalStep.proof,
            outputAccumulator: originalStep.outputAccumulator,
            reductionBoundaryReport: originalStep.reductionBoundaryReport,
            foldRelation: originalStep.foldRelation,
            verifierState: originalStep.verifierState
        )
        let tamperedRun = SuperNeoIVCRun(
            initialState: run.initialState,
            steps: [tamperedStep],
            finalState: run.finalState
        )

        XCTAssertEqual(
            SuperNeoFoldingCompiler.verifyIVC(tamperedRun, shape: fixture.input.shape, key: fixture.key),
            .invalid("IVC step depth mismatch")
        )
    }

    func testPCDCompilerBindsParentAccumulatorFanIn() throws {
        let fixture = try makeFoldFixture()
        let prover = SuperNeoProver(
            key: fixture.key,
            executionPolicy: SuperNeoExecutionPolicy(secretArithmetic: .optimized)
        )
        let run = try SuperNeoFoldingCompiler.provePCD(
            requests: [
                SuperNeoPCDNodeRequest(input: fixture.input, transcriptSeed: Array("pcd-common-root".utf8)),
                SuperNeoPCDNodeRequest(input: fixture.input, transcriptSeed: Array("pcd-common-root".utf8)),
                SuperNeoPCDNodeRequest(
                    input: fixture.input,
                    parentNodeIndices: [0, 1],
                    transcriptSeed: Array("pcd-join-2".utf8)
                )
            ],
            prover: prover,
            maximumFanIn: 2
        )

        XCTAssertEqual(run.nodes.count, 3)
        XCTAssertEqual(run.nodes[2].parentSetBinding?.parentNodeIndices, [0, 1])
        XCTAssertEqual(
            run.nodes[2].step.statement.priorCEInstances,
            (run.nodes[0].step.outputAccumulator.claims + run.nodes[1].step.outputAccumulator.claims)
                .map(CEInstance.init)
        )
        XCTAssertEqual(run.terminalNodeIndices, [2])
        XCTAssertEqual(
            SuperNeoFoldingCompiler.verifyPCD(
                run,
                shape: fixture.input.shape,
                key: fixture.key,
                maximumFanIn: 2
            ),
            .valid
        )
    }

    func testPCDVerifierRejectsTamperedParentOrder() throws {
        let fixture = try makeFoldFixture()
        let prover = SuperNeoProver(
            key: fixture.key,
            executionPolicy: SuperNeoExecutionPolicy(secretArithmetic: .optimized)
        )
        let run = try SuperNeoFoldingCompiler.provePCD(
            requests: [
                SuperNeoPCDNodeRequest(input: fixture.input, transcriptSeed: Array("pcd-order-common-root".utf8)),
                SuperNeoPCDNodeRequest(input: fixture.input, transcriptSeed: Array("pcd-order-common-root".utf8)),
                SuperNeoPCDNodeRequest(
                    input: fixture.input,
                    parentNodeIndices: [0, 1],
                    transcriptSeed: Array("pcd-order-join".utf8)
                )
            ],
            prover: prover,
            maximumFanIn: 2
        )
        let join = run.nodes[2]
        let originalStep = join.step
        let tamperedStep = SuperNeoRecursiveCompilerStep(
            compilerKind: originalStep.compilerKind,
            nodeIndex: originalStep.nodeIndex,
            depth: originalStep.depth,
            parentNodeIndices: [1, 0],
            statement: originalStep.statement,
            transcriptSeed: originalStep.transcriptSeed,
            proof: originalStep.proof,
            outputAccumulator: originalStep.outputAccumulator,
            reductionBoundaryReport: originalStep.reductionBoundaryReport,
            foldRelation: originalStep.foldRelation,
            verifierState: originalStep.verifierState
        )
        var nodes = run.nodes
        nodes[2] = SuperNeoPCDNodeResult(
            nodeIndex: join.nodeIndex,
            parentSetBinding: join.parentSetBinding,
            step: tamperedStep
        )
        let tamperedRun = SuperNeoPCDRun(
            initialState: run.initialState,
            nodes: nodes,
            terminalNodeIndices: run.terminalNodeIndices,
            finalPCDRoot: run.finalPCDRoot
        )

        XCTAssertEqual(
            SuperNeoFoldingCompiler.verifyPCD(
                tamperedRun,
                shape: fixture.input.shape,
                key: fixture.key,
                maximumFanIn: 2
            ),
            .invalid("verificationFailed(\"recursive compiler folded relation input mismatch\")")
        )
    }

    func testPCDVerifierRejectsParentSetChangesInsideFoldRelation() throws {
        let fixture = try makeFoldFixture()
        let prover = SuperNeoProver(
            key: fixture.key,
            executionPolicy: SuperNeoExecutionPolicy(secretArithmetic: .optimized)
        )
        let run = try SuperNeoFoldingCompiler.provePCD(
            requests: [
                SuperNeoPCDNodeRequest(input: fixture.input, transcriptSeed: Array("pcd-relation-root".utf8)),
                SuperNeoPCDNodeRequest(input: fixture.input, transcriptSeed: Array("pcd-relation-root".utf8)),
                SuperNeoPCDNodeRequest(
                    input: fixture.input,
                    parentNodeIndices: [0, 1],
                    transcriptSeed: Array("pcd-relation-join-2".utf8)
                ),
                SuperNeoPCDNodeRequest(
                    input: fixture.input,
                    parentNodeIndices: [0, 1],
                    transcriptSeed: Array("pcd-relation-join-3".utf8)
                )
            ],
            prover: prover,
            maximumFanIn: 2
        )

        func verify(nodes: [SuperNeoPCDNodeResult]) -> VerificationResult {
            SuperNeoFoldingCompiler.verifyPCD(
                SuperNeoPCDRun(
                    initialState: run.initialState,
                    nodes: nodes,
                    terminalNodeIndices: run.terminalNodeIndices,
                    finalPCDRoot: run.finalPCDRoot
                ),
                shape: fixture.input.shape,
                key: fixture.key,
                maximumFanIn: 2
            )
        }

        let join = run.nodes[2]
        let removedParentStep = SuperNeoRecursiveCompilerStep(
            compilerKind: join.step.compilerKind,
            nodeIndex: join.step.nodeIndex,
            depth: join.step.depth,
            parentNodeIndices: [0],
            statement: join.step.statement,
            transcriptSeed: join.step.transcriptSeed,
            proof: join.step.proof,
            outputAccumulator: join.step.outputAccumulator,
            reductionBoundaryReport: join.step.reductionBoundaryReport,
            foldRelation: join.step.foldRelation,
            verifierState: join.step.verifierState
        )
        var removedParentNodes = run.nodes
        removedParentNodes[2] = SuperNeoPCDNodeResult(
            nodeIndex: join.nodeIndex,
            parentSetBinding: join.parentSetBinding,
            step: removedParentStep
        )
        XCTAssertEqual(
            verify(nodes: removedParentNodes),
            .invalid("verificationFailed(\"recursive compiler folded relation input mismatch\")")
        )

        let replaySource = run.nodes[2].step
        let replayTarget = run.nodes[3]
        let replayedStep = SuperNeoRecursiveCompilerStep(
            compilerKind: replaySource.compilerKind,
            nodeIndex: replayTarget.nodeIndex,
            depth: replaySource.depth,
            parentNodeIndices: replaySource.parentNodeIndices,
            statement: replaySource.statement,
            transcriptSeed: replaySource.transcriptSeed,
            proof: replaySource.proof,
            outputAccumulator: replaySource.outputAccumulator,
            reductionBoundaryReport: replaySource.reductionBoundaryReport,
            foldRelation: replaySource.foldRelation,
            verifierState: replaySource.verifierState
        )
        var replayedNodes = run.nodes
        replayedNodes[3] = SuperNeoPCDNodeResult(
            nodeIndex: replayTarget.nodeIndex,
            parentSetBinding: replayTarget.parentSetBinding,
            step: replayedStep
        )
        XCTAssertEqual(
            verify(nodes: replayedNodes),
            .invalid("verificationFailed(\"recursive compiler folded relation input mismatch\")")
        )

        var replacedPriorCEs = join.step.statement.priorCEInstances
        let originalPrior = replacedPriorCEs[0]
        let shiftedCommitment = AjtaiCommitment(
            originalPrior.commitment.elements.enumerated().map { offset, element in
                offset == 0 ? element + CyclotomicRing54([.one]) : element
            }
        )
        replacedPriorCEs[0] = CEInstance(
            commitment: shiftedCommitment,
            publicInputEncoding: originalPrior.publicInputEncoding,
            evalPoint: originalPrior.evalPoint,
            matrixEvals: originalPrior.matrixEvals
        )
        let replacedStatement = CCSStatement(
            shapeDigest: join.step.statement.shapeDigest,
            ccsInstances: join.step.statement.ccsInstances,
            priorCEInstances: replacedPriorCEs,
            recursiveRelationDigest: join.step.statement.recursiveRelationDigest
        )
        let replacedAccumulatorStep = SuperNeoRecursiveCompilerStep(
            compilerKind: join.step.compilerKind,
            nodeIndex: join.step.nodeIndex,
            depth: join.step.depth,
            parentNodeIndices: join.step.parentNodeIndices,
            statement: replacedStatement,
            transcriptSeed: join.step.transcriptSeed,
            proof: join.step.proof,
            outputAccumulator: join.step.outputAccumulator,
            reductionBoundaryReport: join.step.reductionBoundaryReport,
            foldRelation: join.step.foldRelation,
            verifierState: join.step.verifierState
        )
        var replacedAccumulatorNodes = run.nodes
        replacedAccumulatorNodes[2] = SuperNeoPCDNodeResult(
            nodeIndex: join.nodeIndex,
            parentSetBinding: join.parentSetBinding,
            step: replacedAccumulatorStep
        )
        XCTAssertEqual(
            verify(nodes: replacedAccumulatorNodes),
            .invalid("verificationFailed(\"recursive compiler prior accumulator mismatch\")")
        )
    }

    func testPCDVerifierRejectsRootProofReplayUnderDifferentNode() throws {
        let fixture = try makeFoldFixture()
        let prover = SuperNeoProver(key: fixture.key)
        let run = try SuperNeoFoldingCompiler.provePCD(
            requests: [
                SuperNeoPCDNodeRequest(input: fixture.input, transcriptSeed: Array("pcd-root-replay".utf8)),
                SuperNeoPCDNodeRequest(input: fixture.input, transcriptSeed: Array("pcd-root-replay".utf8))
            ],
            prover: prover
        )
        let replaySource = run.nodes[0].step
        let replayTarget = run.nodes[1]
        let childTransitionStatement = CCSStatement(
            shapeDigest: fixture.input.shape.shapeDigest,
            ccsInstances: replaySource.statement.ccsInstances,
            priorCEInstances: []
        )
        let replayRelationInput = try SuperNeoRecursiveFoldRelationInput(
            compilerKind: .pcd,
            nodeIndex: replayTarget.nodeIndex,
            depth: replaySource.depth,
            parentNodeIndices: [],
            parentStates: [],
            parentStatements: [],
            childTransitionStatement: childTransitionStatement,
            parentSetRoot: nil
        )
        let replayedStep = SuperNeoRecursiveCompilerStep(
            compilerKind: replaySource.compilerKind,
            nodeIndex: replayTarget.nodeIndex,
            depth: replaySource.depth,
            parentNodeIndices: [],
            statement: CCSStatement(
                shapeDigest: fixture.input.shape.shapeDigest,
                ccsInstances: replaySource.statement.ccsInstances,
                priorCEInstances: [],
                recursiveRelationDigest: replayRelationInput.relationInputDigest
            ),
            transcriptSeed: replaySource.transcriptSeed,
            proof: replaySource.proof,
            outputAccumulator: replaySource.outputAccumulator,
            reductionBoundaryReport: replaySource.reductionBoundaryReport,
            foldRelation: SuperNeoRecursiveFoldRelation(
                input: replayRelationInput,
                outputAccumulator: replaySource.outputAccumulator
            ),
            verifierState: replaySource.verifierState
        )
        var nodes = run.nodes
        nodes[1] = SuperNeoPCDNodeResult(
            nodeIndex: replayTarget.nodeIndex,
            parentSetBinding: nil,
            step: replayedStep
        )
        let replayedRun = SuperNeoPCDRun(
            initialState: run.initialState,
            nodes: nodes,
            terminalNodeIndices: run.terminalNodeIndices,
            finalPCDRoot: run.finalPCDRoot
        )

        XCTAssertNotEqual(
            SuperNeoFoldingCompiler.verifyPCD(replayedRun, shape: fixture.input.shape, key: fixture.key),
            .valid
        )
    }

    func testPCDVerifierRejectsWrongCompilerKind() throws {
        let fixture = try makeFoldFixture()
        let prover = SuperNeoProver(key: fixture.key)
        let run = try SuperNeoFoldingCompiler.provePCD(
            requests: [
                SuperNeoPCDNodeRequest(input: fixture.input, transcriptSeed: Array("pcd-kind-root".utf8))
            ],
            prover: prover
        )
        let originalNode = try XCTUnwrap(run.nodes.first)
        let originalStep = originalNode.step
        let tamperedStep = SuperNeoRecursiveCompilerStep(
            compilerKind: .ivc,
            nodeIndex: originalStep.nodeIndex,
            depth: originalStep.depth,
            parentNodeIndices: originalStep.parentNodeIndices,
            statement: originalStep.statement,
            transcriptSeed: originalStep.transcriptSeed,
            proof: originalStep.proof,
            outputAccumulator: originalStep.outputAccumulator,
            reductionBoundaryReport: originalStep.reductionBoundaryReport,
            foldRelation: originalStep.foldRelation,
            verifierState: originalStep.verifierState
        )
        let tamperedRun = SuperNeoPCDRun(
            initialState: run.initialState,
            nodes: [
                SuperNeoPCDNodeResult(
                    nodeIndex: originalNode.nodeIndex,
                    parentSetBinding: originalNode.parentSetBinding,
                    step: tamperedStep
                )
            ],
            terminalNodeIndices: run.terminalNodeIndices,
            finalPCDRoot: run.finalPCDRoot
        )

        XCTAssertEqual(
            SuperNeoFoldingCompiler.verifyPCD(
                tamperedRun,
                shape: fixture.input.shape,
                key: fixture.key
            ),
            .invalid("PCD compiler kind mismatch")
        )
    }

    func testPCDCompilerAcceptsDistinctParentAccumulatorPointsInsideFoldRelation() throws {
        let fixture = try makeFoldFixture()
        let prover = SuperNeoProver(
            key: fixture.key,
            executionPolicy: SuperNeoExecutionPolicy(secretArithmetic: .optimized)
        )
        let run = try SuperNeoFoldingCompiler.provePCD(
            requests: [
                SuperNeoPCDNodeRequest(input: fixture.input, transcriptSeed: Array("pcd-distinct-root-0".utf8)),
                SuperNeoPCDNodeRequest(input: fixture.input, transcriptSeed: Array("pcd-distinct-root-1".utf8)),
                SuperNeoPCDNodeRequest(
                    input: fixture.input,
                    parentNodeIndices: [0, 1],
                    transcriptSeed: Array("pcd-distinct-join".utf8)
                )
            ],
            prover: prover,
            maximumFanIn: 2
        )

        XCTAssertNotEqual(
            run.nodes[0].step.outputAccumulator.claims.first?.point,
            run.nodes[1].step.outputAccumulator.claims.first?.point
        )
        XCTAssertEqual(run.nodes[2].step.parentNodeIndices, [0, 1])
        XCTAssertEqual(
            run.nodes[2].step.statement.priorCEInstances,
            (run.nodes[0].step.outputAccumulator.claims + run.nodes[1].step.outputAccumulator.claims)
                .map(CEInstance.init)
        )
        XCTAssertEqual(
            SuperNeoFoldingCompiler.verifyPCD(
                run,
                shape: fixture.input.shape,
                key: fixture.key,
                maximumFanIn: 2
            ),
            .valid
        )
    }
}
