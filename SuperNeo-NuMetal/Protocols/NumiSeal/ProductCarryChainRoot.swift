import Foundation

public struct ProductSelectedDepthModel: Equatable, Sendable, SuperNeoByteEncodable {
    public static let domain = Digest256.hash("SUPERNEO/PRODUCT/SELECTED_DEPTH_MODEL/v1")

    public let baseAcceptedLayerDepth: Int
    public let recursiveChildDepths: [Int]
    public let selectedMaximumDepth: Int
    public let selectedRecursiveCarryHops: Int
    public let depthZeroArtifactAccepted: Bool

    public init(
        baseAcceptedLayerDepth: Int = 1,
        recursiveChildDepths: [Int] = [2, 3],
        selectedMaximumDepth: Int = 3,
        selectedRecursiveCarryHops: Int = 2,
        depthZeroArtifactAccepted: Bool = false
    ) throws {
        guard baseAcceptedLayerDepth == 1 else {
            throw SuperNeoError.invalidParameter("selected-depth base accepted layer depth must be 1")
        }
        guard recursiveChildDepths == [2, 3] else {
            throw SuperNeoError.invalidParameter("selected-depth recursive child depths must be [2, 3]")
        }
        guard selectedMaximumDepth == 3 else {
            throw SuperNeoError.invalidParameter("selected-depth maximum depth must be 3")
        }
        guard selectedRecursiveCarryHops == 2 else {
            throw SuperNeoError.invalidParameter("selected-depth recursive carry hops must be 2")
        }
        guard depthZeroArtifactAccepted == false else {
            throw SuperNeoError.invalidParameter("selected-depth depth zero product artifacts are not accepted")
        }
        self.baseAcceptedLayerDepth = baseAcceptedLayerDepth
        self.recursiveChildDepths = recursiveChildDepths
        self.selectedMaximumDepth = selectedMaximumDepth
        self.selectedRecursiveCarryHops = selectedRecursiveCarryHops
        self.depthZeroArtifactAccepted = depthZeroArtifactAccepted
    }

    public var superNeoBytes: [UInt8] {
        Self.domain.superNeoBytes
            + numiSealEncodeCount(baseAcceptedLayerDepth)
            + numiSealEncodeCount(recursiveChildDepths.count)
            + recursiveChildDepths.flatMap(numiSealEncodeCount)
            + numiSealEncodeCount(selectedMaximumDepth)
            + numiSealEncodeCount(selectedRecursiveCarryHops)
            + [depthZeroArtifactAccepted ? 1 : 0]
    }

    public var policyDigest: Digest256 {
        Digest256.hash(superNeoBytes)
    }

    public static let defaultPolicyDigest: Digest256 = try! ProductSelectedDepthModel().policyDigest
}

public enum ProductCarryChainRootLayout {
    public static let version: UInt16 = 1
    public static let baseDomainTag = "SUPERNEO/PRODUCT/CARRY_CHAIN/BASE/v1"
    public static let stepDomainTag = "SUPERNEO/PRODUCT/CARRY_CHAIN/STEP/v1"
    public static let absentDigest = Digest256.hash("SUPERNEO/PRODUCT/CARRY_CHAIN/ABSENT_FIELD/v1")
    public static let baseFieldOrder = [
        "domainTag",
        "version",
        "profileID",
        "selectedDepthPolicyDigest",
        "depthIndex",
        "parentChainRoot",
        "artifactDigest",
        "sourceFoldEnvelopeDigest",
        "productProofEnvelopeDigest",
        "producerEnvelopeDigest",
        "publicStatementDigest",
        "consumerSessionDigest",
        "contextRoot",
        "replayRoot",
        "typedCarryStatementDigest",
        "recursiveRelationDigest",
        "orderedPCDParentTupleRoot"
    ]
    public static let stepFieldOrder = baseFieldOrder

    static func encodeFieldLayout(
        domainTag: String,
        profileID: UInt16,
        selectedDepthPolicyDigest: Digest256,
        depthIndex: Int,
        parentChainRoot: Digest256?,
        artifactDigest: Digest256,
        sourceFoldEnvelopeDigest: Digest256,
        productProofEnvelopeDigest: Digest256,
        producerEnvelopeDigest: Digest256,
        publicStatementDigest: Digest256,
        consumerSessionDigest: Digest256?,
        contextRoot: Digest256?,
        replayRoot: Digest256?,
        typedCarryStatementDigest: Digest256?,
        recursiveRelationDigest: Digest256?,
        orderedPCDParentTupleRoot: Digest256?
    ) -> [UInt8] {
        Array(domainTag.utf8)
            + numiSealEncodeUInt16(version)
            + numiSealEncodeUInt16(profileID)
            + selectedDepthPolicyDigest.superNeoBytes
            + numiSealEncodeCount(depthIndex)
            + encodeOptionalDigest(parentChainRoot)
            + artifactDigest.superNeoBytes
            + sourceFoldEnvelopeDigest.superNeoBytes
            + productProofEnvelopeDigest.superNeoBytes
            + producerEnvelopeDigest.superNeoBytes
            + publicStatementDigest.superNeoBytes
            + encodeOptionalDigest(consumerSessionDigest)
            + encodeOptionalDigest(contextRoot)
            + encodeOptionalDigest(replayRoot)
            + encodeOptionalDigest(typedCarryStatementDigest)
            + encodeOptionalDigest(recursiveRelationDigest)
            + encodeOptionalDigest(orderedPCDParentTupleRoot)
    }

    static func encodeOptionalDigest(_ digest: Digest256?) -> [UInt8] {
        [digest == nil ? 0 : 1] + (digest ?? absentDigest).superNeoBytes
    }
}

public struct ProductCarryChainRootBase: Equatable, Sendable, SuperNeoByteEncodable {
    public let profileID: UInt16
    public let selectedDepthPolicyDigest: Digest256
    public let depthIndex: Int
    public let artifactDigest: Digest256
    public let sourceFoldEnvelopeDigest: Digest256
    public let productProofEnvelopeDigest: Digest256
    public let producerEnvelopeDigest: Digest256
    public let publicStatementDigest: Digest256
    public let consumerSessionDigest: Digest256?
    public let contextRoot: Digest256?
    public let replayRoot: Digest256?
    public let typedCarryStatementDigest: Digest256?
    public let recursiveRelationDigest: Digest256?
    public let orderedPCDParentTupleRoot: Digest256?
    public let rootDigest: Digest256

    public init(
        profileID: UInt16 = SuperNeoParameters.goldilocks.profileID,
        selectedDepthPolicyDigest: Digest256 = ProductSelectedDepthModel.defaultPolicyDigest,
        depthIndex: Int = 1,
        artifactDigest: Digest256,
        sourceFoldEnvelopeDigest: Digest256,
        productProofEnvelopeDigest: Digest256,
        producerEnvelopeDigest: Digest256,
        publicStatementDigest: Digest256,
        consumerSessionDigest: Digest256? = nil,
        contextRoot: Digest256? = nil,
        replayRoot: Digest256? = nil,
        typedCarryStatementDigest: Digest256? = nil,
        recursiveRelationDigest: Digest256? = nil,
        orderedPCDParentTupleRoot: Digest256? = nil
    ) throws {
        guard depthIndex == 1 else {
            throw SuperNeoError.invalidParameter("ProductCarryChainRootBase depth index must be 1")
        }
        self.profileID = profileID
        self.selectedDepthPolicyDigest = selectedDepthPolicyDigest
        self.depthIndex = depthIndex
        self.artifactDigest = artifactDigest
        self.sourceFoldEnvelopeDigest = sourceFoldEnvelopeDigest
        self.productProofEnvelopeDigest = productProofEnvelopeDigest
        self.producerEnvelopeDigest = producerEnvelopeDigest
        self.publicStatementDigest = publicStatementDigest
        self.consumerSessionDigest = consumerSessionDigest
        self.contextRoot = contextRoot
        self.replayRoot = replayRoot
        self.typedCarryStatementDigest = typedCarryStatementDigest
        self.recursiveRelationDigest = recursiveRelationDigest
        self.orderedPCDParentTupleRoot = orderedPCDParentTupleRoot
        self.rootDigest = Digest256.hash(
            ProductCarryChainRootLayout.encodeFieldLayout(
                domainTag: ProductCarryChainRootLayout.baseDomainTag,
                profileID: profileID,
                selectedDepthPolicyDigest: selectedDepthPolicyDigest,
                depthIndex: depthIndex,
                parentChainRoot: nil,
                artifactDigest: artifactDigest,
                sourceFoldEnvelopeDigest: sourceFoldEnvelopeDigest,
                productProofEnvelopeDigest: productProofEnvelopeDigest,
                producerEnvelopeDigest: producerEnvelopeDigest,
                publicStatementDigest: publicStatementDigest,
                consumerSessionDigest: consumerSessionDigest,
                contextRoot: contextRoot,
                replayRoot: replayRoot,
                typedCarryStatementDigest: typedCarryStatementDigest,
                recursiveRelationDigest: recursiveRelationDigest,
                orderedPCDParentTupleRoot: orderedPCDParentTupleRoot
            )
        )
    }

    public var superNeoBytes: [UInt8] {
        ProductCarryChainRootLayout.encodeFieldLayout(
            domainTag: ProductCarryChainRootLayout.baseDomainTag,
            profileID: profileID,
            selectedDepthPolicyDigest: selectedDepthPolicyDigest,
            depthIndex: depthIndex,
            parentChainRoot: nil,
            artifactDigest: artifactDigest,
            sourceFoldEnvelopeDigest: sourceFoldEnvelopeDigest,
            productProofEnvelopeDigest: productProofEnvelopeDigest,
            producerEnvelopeDigest: producerEnvelopeDigest,
            publicStatementDigest: publicStatementDigest,
            consumerSessionDigest: consumerSessionDigest,
            contextRoot: contextRoot,
            replayRoot: replayRoot,
            typedCarryStatementDigest: typedCarryStatementDigest,
            recursiveRelationDigest: recursiveRelationDigest,
            orderedPCDParentTupleRoot: orderedPCDParentTupleRoot
        ) + rootDigest.superNeoBytes
    }
}

public struct ProductCarryChainRootStep: Equatable, Sendable, SuperNeoByteEncodable {
    public let profileID: UInt16
    public let selectedDepthPolicyDigest: Digest256
    public let depthIndex: Int
    public let parentChainRoot: Digest256
    public let artifactDigest: Digest256
    public let sourceFoldEnvelopeDigest: Digest256
    public let productProofEnvelopeDigest: Digest256
    public let producerEnvelopeDigest: Digest256
    public let publicStatementDigest: Digest256
    public let consumerSessionDigest: Digest256
    public let contextRoot: Digest256
    public let replayRoot: Digest256
    public let typedCarryStatementDigest: Digest256
    public let recursiveRelationDigest: Digest256?
    public let orderedPCDParentTupleRoot: Digest256?
    public let rootDigest: Digest256

    public init(
        profileID: UInt16 = SuperNeoParameters.goldilocks.profileID,
        selectedDepthPolicyDigest: Digest256 = ProductSelectedDepthModel.defaultPolicyDigest,
        depthIndex: Int,
        parentChainRoot: Digest256,
        artifactDigest: Digest256,
        sourceFoldEnvelopeDigest: Digest256,
        productProofEnvelopeDigest: Digest256,
        producerEnvelopeDigest: Digest256,
        publicStatementDigest: Digest256,
        consumerSessionDigest: Digest256,
        contextRoot: Digest256,
        replayRoot: Digest256,
        typedCarryStatementDigest: Digest256,
        recursiveRelationDigest: Digest256? = nil,
        orderedPCDParentTupleRoot: Digest256? = nil
    ) throws {
        guard depthIndex > 0 else {
            throw SuperNeoError.invalidParameter("ProductCarryChainRootStep depth index must be positive")
        }
        self.profileID = profileID
        self.selectedDepthPolicyDigest = selectedDepthPolicyDigest
        self.depthIndex = depthIndex
        self.parentChainRoot = parentChainRoot
        self.artifactDigest = artifactDigest
        self.sourceFoldEnvelopeDigest = sourceFoldEnvelopeDigest
        self.productProofEnvelopeDigest = productProofEnvelopeDigest
        self.producerEnvelopeDigest = producerEnvelopeDigest
        self.publicStatementDigest = publicStatementDigest
        self.consumerSessionDigest = consumerSessionDigest
        self.contextRoot = contextRoot
        self.replayRoot = replayRoot
        self.typedCarryStatementDigest = typedCarryStatementDigest
        self.recursiveRelationDigest = recursiveRelationDigest
        self.orderedPCDParentTupleRoot = orderedPCDParentTupleRoot
        self.rootDigest = Digest256.hash(
            ProductCarryChainRootLayout.encodeFieldLayout(
                domainTag: ProductCarryChainRootLayout.stepDomainTag,
                profileID: profileID,
                selectedDepthPolicyDigest: selectedDepthPolicyDigest,
                depthIndex: depthIndex,
                parentChainRoot: parentChainRoot,
                artifactDigest: artifactDigest,
                sourceFoldEnvelopeDigest: sourceFoldEnvelopeDigest,
                productProofEnvelopeDigest: productProofEnvelopeDigest,
                producerEnvelopeDigest: producerEnvelopeDigest,
                publicStatementDigest: publicStatementDigest,
                consumerSessionDigest: consumerSessionDigest,
                contextRoot: contextRoot,
                replayRoot: replayRoot,
                typedCarryStatementDigest: typedCarryStatementDigest,
                recursiveRelationDigest: recursiveRelationDigest,
                orderedPCDParentTupleRoot: orderedPCDParentTupleRoot
            )
        )
    }

    public var superNeoBytes: [UInt8] {
        ProductCarryChainRootLayout.encodeFieldLayout(
            domainTag: ProductCarryChainRootLayout.stepDomainTag,
            profileID: profileID,
            selectedDepthPolicyDigest: selectedDepthPolicyDigest,
            depthIndex: depthIndex,
            parentChainRoot: parentChainRoot,
            artifactDigest: artifactDigest,
            sourceFoldEnvelopeDigest: sourceFoldEnvelopeDigest,
            productProofEnvelopeDigest: productProofEnvelopeDigest,
            producerEnvelopeDigest: producerEnvelopeDigest,
            publicStatementDigest: publicStatementDigest,
            consumerSessionDigest: consumerSessionDigest,
            contextRoot: contextRoot,
            replayRoot: replayRoot,
            typedCarryStatementDigest: typedCarryStatementDigest,
            recursiveRelationDigest: recursiveRelationDigest,
            orderedPCDParentTupleRoot: orderedPCDParentTupleRoot
        ) + rootDigest.superNeoBytes
    }
}
