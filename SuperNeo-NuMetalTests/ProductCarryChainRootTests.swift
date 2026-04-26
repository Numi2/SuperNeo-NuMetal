import XCTest
@testable import SuperNeo_NuMetal

final class ProductCarryChainRootTests: XCTestCase {
    func testProductCarryChainRootVectorsAreByteExact() throws {
        let vector = try loadVector()
        XCTAssertEqual(vector.layout.baseDomainTag, ProductCarryChainRootLayout.baseDomainTag)
        XCTAssertEqual(vector.layout.stepDomainTag, ProductCarryChainRootLayout.stepDomainTag)
        XCTAssertEqual(vector.layout.version, Int(ProductCarryChainRootLayout.version))
        XCTAssertEqual(vector.layout.profileID, Int(SuperNeoParameters.goldilocks.profileID))
        XCTAssertEqual(vector.layout.selectedDepthPolicyDigest, ProductSelectedDepthModel.defaultPolicyDigest.hexString)
        XCTAssertEqual(vector.layout.fieldOrder, ProductCarryChainRootLayout.baseFieldOrder)

        let base = try ProductCarryChainRootBase(
            artifactDigest: digest(vector.base.artifactDigest),
            sourceFoldEnvelopeDigest: digest(vector.base.sourceFoldEnvelopeDigest),
            productProofEnvelopeDigest: digest(vector.base.productProofEnvelopeDigest),
            producerEnvelopeDigest: digest(vector.base.producerEnvelopeDigest),
            publicStatementDigest: digest(vector.base.publicStatementDigest)
        )
        XCTAssertEqual(base.depthIndex, 1)
        XCTAssertEqual(base.rootDigest.hexString, vector.base.rootDigest)

        var parentRoot = base.rootDigest
        for stepVector in vector.steps {
            let step = try ProductCarryChainRootStep(
                depthIndex: stepVector.depthIndex,
                parentChainRoot: parentRoot,
                artifactDigest: digest(stepVector.artifactDigest),
                sourceFoldEnvelopeDigest: digest(stepVector.sourceFoldEnvelopeDigest),
                productProofEnvelopeDigest: digest(stepVector.productProofEnvelopeDigest),
                producerEnvelopeDigest: digest(stepVector.producerEnvelopeDigest),
                publicStatementDigest: digest(stepVector.publicStatementDigest),
                consumerSessionDigest: digest(stepVector.consumerSessionDigest),
                contextRoot: digest(stepVector.contextRoot),
                replayRoot: digest(stepVector.replayRoot),
                typedCarryStatementDigest: digest(stepVector.typedCarryStatementDigest),
                recursiveRelationDigest: digest(stepVector.recursiveRelationDigest),
                orderedPCDParentTupleRoot: digest(stepVector.orderedPCDParentTupleRoot)
            )
            XCTAssertEqual(step.parentChainRoot.hexString, stepVector.parentChainRoot)
            XCTAssertEqual(step.rootDigest.hexString, stepVector.rootDigest)
            parentRoot = step.rootDigest
        }
    }

    func testProductCarryChainRootRejectsFieldMutations() throws {
        let vector = try loadVector()
        let base = try ProductCarryChainRootBase(
            artifactDigest: digest(vector.base.artifactDigest),
            sourceFoldEnvelopeDigest: digest(vector.base.sourceFoldEnvelopeDigest),
            productProofEnvelopeDigest: digest(vector.base.productProofEnvelopeDigest),
            producerEnvelopeDigest: digest(vector.base.producerEnvelopeDigest),
            publicStatementDigest: digest(vector.base.publicStatementDigest)
        )
        let stepVector = try XCTUnwrap(vector.steps.first)
        let expected = try digest(stepVector.rootDigest)

        let wrongDepth = try ProductCarryChainRootStep(
            depthIndex: stepVector.depthIndex + 1,
            parentChainRoot: base.rootDigest,
            artifactDigest: digest(stepVector.artifactDigest),
            sourceFoldEnvelopeDigest: digest(stepVector.sourceFoldEnvelopeDigest),
            productProofEnvelopeDigest: digest(stepVector.productProofEnvelopeDigest),
            producerEnvelopeDigest: digest(stepVector.producerEnvelopeDigest),
            publicStatementDigest: digest(stepVector.publicStatementDigest),
            consumerSessionDigest: digest(stepVector.consumerSessionDigest),
            contextRoot: digest(stepVector.contextRoot),
            replayRoot: digest(stepVector.replayRoot),
            typedCarryStatementDigest: digest(stepVector.typedCarryStatementDigest),
            recursiveRelationDigest: digest(stepVector.recursiveRelationDigest),
            orderedPCDParentTupleRoot: digest(stepVector.orderedPCDParentTupleRoot)
        )
        XCTAssertNotEqual(wrongDepth.rootDigest, expected)

        let wrongParent = try ProductCarryChainRootStep(
            depthIndex: stepVector.depthIndex,
            parentChainRoot: Digest256.hash("wrong-parent-chain-root"),
            artifactDigest: digest(stepVector.artifactDigest),
            sourceFoldEnvelopeDigest: digest(stepVector.sourceFoldEnvelopeDigest),
            productProofEnvelopeDigest: digest(stepVector.productProofEnvelopeDigest),
            producerEnvelopeDigest: digest(stepVector.producerEnvelopeDigest),
            publicStatementDigest: digest(stepVector.publicStatementDigest),
            consumerSessionDigest: digest(stepVector.consumerSessionDigest),
            contextRoot: digest(stepVector.contextRoot),
            replayRoot: digest(stepVector.replayRoot),
            typedCarryStatementDigest: digest(stepVector.typedCarryStatementDigest),
            recursiveRelationDigest: digest(stepVector.recursiveRelationDigest),
            orderedPCDParentTupleRoot: digest(stepVector.orderedPCDParentTupleRoot)
        )
        XCTAssertNotEqual(wrongParent.rootDigest, expected)

        let wrongContext = try ProductCarryChainRootStep(
            depthIndex: stepVector.depthIndex,
            parentChainRoot: base.rootDigest,
            artifactDigest: digest(stepVector.artifactDigest),
            sourceFoldEnvelopeDigest: digest(stepVector.sourceFoldEnvelopeDigest),
            productProofEnvelopeDigest: digest(stepVector.productProofEnvelopeDigest),
            producerEnvelopeDigest: digest(stepVector.producerEnvelopeDigest),
            publicStatementDigest: digest(stepVector.publicStatementDigest),
            consumerSessionDigest: digest(stepVector.consumerSessionDigest),
            contextRoot: Digest256.hash("wrong-context-root"),
            replayRoot: digest(stepVector.replayRoot),
            typedCarryStatementDigest: digest(stepVector.typedCarryStatementDigest),
            recursiveRelationDigest: digest(stepVector.recursiveRelationDigest),
            orderedPCDParentTupleRoot: digest(stepVector.orderedPCDParentTupleRoot)
        )
        XCTAssertNotEqual(wrongContext.rootDigest, expected)

        let wrongReplay = try ProductCarryChainRootStep(
            depthIndex: stepVector.depthIndex,
            parentChainRoot: base.rootDigest,
            artifactDigest: digest(stepVector.artifactDigest),
            sourceFoldEnvelopeDigest: digest(stepVector.sourceFoldEnvelopeDigest),
            productProofEnvelopeDigest: digest(stepVector.productProofEnvelopeDigest),
            producerEnvelopeDigest: digest(stepVector.producerEnvelopeDigest),
            publicStatementDigest: digest(stepVector.publicStatementDigest),
            consumerSessionDigest: digest(stepVector.consumerSessionDigest),
            contextRoot: digest(stepVector.contextRoot),
            replayRoot: Digest256.hash("wrong-replay-root"),
            typedCarryStatementDigest: digest(stepVector.typedCarryStatementDigest),
            recursiveRelationDigest: digest(stepVector.recursiveRelationDigest),
            orderedPCDParentTupleRoot: digest(stepVector.orderedPCDParentTupleRoot)
        )
        XCTAssertNotEqual(wrongReplay.rootDigest, expected)

        let wrongRecursiveRelation = try ProductCarryChainRootStep(
            depthIndex: stepVector.depthIndex,
            parentChainRoot: base.rootDigest,
            artifactDigest: digest(stepVector.artifactDigest),
            sourceFoldEnvelopeDigest: digest(stepVector.sourceFoldEnvelopeDigest),
            productProofEnvelopeDigest: digest(stepVector.productProofEnvelopeDigest),
            producerEnvelopeDigest: digest(stepVector.producerEnvelopeDigest),
            publicStatementDigest: digest(stepVector.publicStatementDigest),
            consumerSessionDigest: digest(stepVector.consumerSessionDigest),
            contextRoot: digest(stepVector.contextRoot),
            replayRoot: digest(stepVector.replayRoot),
            typedCarryStatementDigest: digest(stepVector.typedCarryStatementDigest),
            recursiveRelationDigest: Digest256.hash("wrong-recursive-relation"),
            orderedPCDParentTupleRoot: digest(stepVector.orderedPCDParentTupleRoot)
        )
        XCTAssertNotEqual(wrongRecursiveRelation.rootDigest, expected)
    }

    private struct CarryChainVector: Decodable {
        let layout: Layout
        let base: Base
        let steps: [Step]
    }

    private struct Layout: Decodable {
        let baseDomainTag: String
        let stepDomainTag: String
        let version: Int
        let profileID: Int
        let selectedDepthPolicyDigest: String
        let fieldOrder: [String]
    }

    private struct Base: Decodable {
        let artifactDigest: String
        let sourceFoldEnvelopeDigest: String
        let productProofEnvelopeDigest: String
        let producerEnvelopeDigest: String
        let publicStatementDigest: String
        let rootDigest: String
    }

    private struct Step: Decodable {
        let depthIndex: Int
        let parentChainRoot: String
        let artifactDigest: String
        let sourceFoldEnvelopeDigest: String
        let productProofEnvelopeDigest: String
        let producerEnvelopeDigest: String
        let publicStatementDigest: String
        let consumerSessionDigest: String
        let contextRoot: String
        let replayRoot: String
        let typedCarryStatementDigest: String
        let recursiveRelationDigest: String
        let orderedPCDParentTupleRoot: String
        let rootDigest: String
    }

    private func loadVector() throws -> CarryChainVector {
        let testFile = URL(fileURLWithPath: #filePath)
        let repositoryRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = repositoryRoot
            .appendingPathComponent("TestVectors")
            .appendingPathComponent("product-carry-chain-root-v1.json")
        return try JSONDecoder().decode(CarryChainVector.self, from: Data(contentsOf: url))
    }

    private func digest(_ hex: String) throws -> Digest256 {
        try Digest256(hexDigest: hex)
    }
}
