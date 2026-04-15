import CryptoKit
import Foundation
@_spi(Benchmarking) import SuperNeo_NuMetal

private enum VectorCLIError: Error, CustomStringConvertible {
    case usage(String)
    case invalid(String)

    var description: String {
        switch self {
        case .usage(let message), .invalid(let message):
            return message
        }
    }
}

private struct NumiSealVectorManifest: Codable {
    let manifestVersion: UInt32
    let profile: String
    let schema: String
    let vectors: [NumiSealManifestVector]
}

private struct NumiSealManifestVector: Codable {
    let file: String
    let sha256: String
    let byteCount: Int
    let workload: String
    let proofKind: String
    let residualMode: String
    let publicClaim: String
    let expectedKeySeedUTF8: String
    let expectedShapeDigestHex: String
    let expectedStatementDigestHex: String
    let expectedVerifierKeyDigestHex: String
    let expectedTranscriptDomainHex: String
    let expectedPublicStatementDigestHex: String
    let expectedAggregateDigestsHex: [String]
    let expectedComponentDigestRootHex: String
    let expectedProofTranscriptDigestHex: String
    let verifyCommand: String
}

private struct NumiSealVectorArtifact: Codable {
    let artifactVersion: UInt32
    let workload: String
    let profile: String
    let proofKind: String
    let residualMode: String
    let keySeedUTF8: String
    let keyColumnCount: Int
    let foldTranscriptSeedUTF8: String
    let laneIDsUTF8: [String]
    let sourceFoldDigestSeedsUTF8: [String]
    let ceRandomSeedsUTF8: [String]
    let maximumObligationsPerAggregate: Int
    let maximumLaneCount: Int
    let maximumAggregatesPerLane: Int
    let publicInputCount: Int
    let privateWitnessCount: Int
    let publicInputs: [UInt64]
    let shapeDigestHex: String
    let statementDigestHex: String
    let verifierKeyDigestHex: String
    let transcriptDomainHex: String
    let publicStatementDigestHex: String
    let obligationRootHex: String
    let laneSummaryRootHex: String
    let aggregateDigestsHex: [String]
    let componentDigestRootHex: String
    let proofTranscriptDigestHex: String
    let proofEnvelopeBase64: String
}

private struct NumiSealVectorMaterial {
    let shape: CCSShape
    let key: AjtaiCommitmentKey
    let obligations: [NumiSealObligation]
    let policy: NumiSealAcceptancePolicy
    let terminalPolicy: NumiSealTerminalProofAcceptancePolicy
    let plan: NumiSealProvingPlan
    let envelope: NumiSealProofEnvelope
}

private enum Defaults {
    static let artifactFile = "numiseal-terminal-single-aggregate-v1.json"
    static let manifestFile = "numiseal-manifest.json"
    static let schemaFile = "numiseal-artifact.schema.json"
    static let workload = "numiseal-terminal-single-aggregate-v1"
    static let proofKind = "numiseal-terminal"
    static let residualMode = "immediate"
    static let publicClaim = "single immediate-residual NumiSeal aggregate over a fold output claim"
    static let profile = SuperNeoParameterProfile.goldilocksPhi81.name
    static let keySeed = "SuperNeoNumiSeal.vector.single-aggregate.key.v1"
    static let foldTranscriptSeed = "SuperNeoNumiSeal.vector.single-aggregate.fold.v1"
    static let laneID = "numiseal-vector-main"
    static let sourceFoldDigestSeed = "SuperNeoNumiSeal.vector.single-aggregate.source.0.v1"
    static let ceRandomSeed = "SuperNeoNumiSeal.vector.single-aggregate.ce.0.v1"
    static let publicInputCount = CyclotomicRing54.degree
    static let privateWitnessCount = 10
    static let maximumObligationsPerAggregate = 1
    static let maximumLaneCount = 1
    static let maximumAggregatesPerLane = 1
}

private let manifestTopLevelKeys: Set<String> = [
    "manifestVersion",
    "profile",
    "schema",
    "vectors",
]

private let manifestVectorKeys: Set<String> = [
    "file",
    "sha256",
    "byteCount",
    "workload",
    "proofKind",
    "residualMode",
    "publicClaim",
    "expectedKeySeedUTF8",
    "expectedShapeDigestHex",
    "expectedStatementDigestHex",
    "expectedVerifierKeyDigestHex",
    "expectedTranscriptDomainHex",
    "expectedPublicStatementDigestHex",
    "expectedAggregateDigestsHex",
    "expectedComponentDigestRootHex",
    "expectedProofTranscriptDigestHex",
    "verifyCommand",
]

private let artifactTopLevelKeys: Set<String> = [
    "artifactVersion",
    "workload",
    "profile",
    "proofKind",
    "residualMode",
    "keySeedUTF8",
    "keyColumnCount",
    "foldTranscriptSeedUTF8",
    "laneIDsUTF8",
    "sourceFoldDigestSeedsUTF8",
    "ceRandomSeedsUTF8",
    "maximumObligationsPerAggregate",
    "maximumLaneCount",
    "maximumAggregatesPerLane",
    "publicInputCount",
    "privateWitnessCount",
    "publicInputs",
    "shapeDigestHex",
    "statementDigestHex",
    "verifierKeyDigestHex",
    "transcriptDomainHex",
    "publicStatementDigestHex",
    "obligationRootHex",
    "laneSummaryRootHex",
    "aggregateDigestsHex",
    "componentDigestRootHex",
    "proofTranscriptDigestHex",
    "proofEnvelopeBase64",
]

private func usage() -> String {
    """
    Usage:
      superneo-numiseal-vectors generate [repository-root]
      superneo-numiseal-vectors validate [repository-root]
      superneo-numiseal-vectors validate TestVectors/numiseal-terminal-single-aggregate-v1.json [repository-root]

    The generator emits deterministic NumiSeal test-vector artifacts only. It is
    not a production proving interface.
    """
}

do {
    try run(Array(CommandLine.arguments.dropFirst()))
} catch {
    fputs("error: \(error)\n\n\(usage())\n", stderr)
    exit(1)
}

private func run(_ arguments: [String]) throws {
    guard let command = arguments.first else {
        throw VectorCLIError.usage(usage())
    }
    switch command {
    case "generate":
        let root = try repositoryRoot(from: Array(arguments.dropFirst()))
        try generate(root: root)
    case "validate":
        try validate(arguments: Array(arguments.dropFirst()))
    case "-h", "--help", "help":
        print(usage())
    default:
        throw VectorCLIError.usage("unknown command: \(command)")
    }
}

private func repositoryRoot(from arguments: [String]) throws -> URL {
    guard arguments.count <= 1 else {
        throw VectorCLIError.usage("expected at most one repository root")
    }
    if let root = arguments.first {
        return URL(fileURLWithPath: root).standardizedFileURL
    }
    return URL(fileURLWithPath: FileManager.default.currentDirectoryPath).standardizedFileURL
}

private func validate(arguments: [String]) throws {
    switch arguments.count {
    case 0:
        try validateManifest(root: repositoryRoot(from: []))
    case 1:
        if arguments[0].hasSuffix(".json") {
            let root = try repositoryRoot(from: [])
            try validateSingleVector(path: vectorURL(arguments[0], root: root), root: root)
        } else {
            try validateManifest(root: repositoryRoot(from: arguments))
        }
    case 2:
        let root = try repositoryRoot(from: [arguments[1]])
        try validateSingleVector(path: vectorURL(arguments[0], root: root), root: root)
    default:
        throw VectorCLIError.usage("validate accepts an optional vector path and optional repository root")
    }
}

private func generate(root: URL) throws {
    let vectorsDirectory = root.appendingPathComponent("TestVectors", isDirectory: true)
    let artifact = try makeArtifact()
    let artifactData = try encodeJSON(artifact)
    let artifactURL = vectorsDirectory.appendingPathComponent(Defaults.artifactFile)
    try artifactData.write(to: artifactURL, options: .atomic)

    let manifest = NumiSealVectorManifest(
        manifestVersion: 1,
        profile: Defaults.profile,
        schema: Defaults.schemaFile,
        vectors: [
            NumiSealManifestVector(
                file: Defaults.artifactFile,
                sha256: sha256Hex(artifactData),
                byteCount: artifactData.count,
                workload: artifact.workload,
                proofKind: artifact.proofKind,
                residualMode: artifact.residualMode,
                publicClaim: Defaults.publicClaim,
                expectedKeySeedUTF8: artifact.keySeedUTF8,
                expectedShapeDigestHex: artifact.shapeDigestHex,
                expectedStatementDigestHex: artifact.statementDigestHex,
                expectedVerifierKeyDigestHex: artifact.verifierKeyDigestHex,
                expectedTranscriptDomainHex: artifact.transcriptDomainHex,
                expectedPublicStatementDigestHex: artifact.publicStatementDigestHex,
                expectedAggregateDigestsHex: artifact.aggregateDigestsHex,
                expectedComponentDigestRootHex: artifact.componentDigestRootHex,
                expectedProofTranscriptDigestHex: artifact.proofTranscriptDigestHex,
                verifyCommand: strictVerifyCommand(file: Defaults.artifactFile)
            )
        ]
    )
    let manifestData = try encodeJSON(manifest)
    try manifestData.write(
        to: vectorsDirectory.appendingPathComponent(Defaults.manifestFile),
        options: .atomic
    )

    print("wrote TestVectors/\(Defaults.artifactFile)")
    print("wrote TestVectors/\(Defaults.manifestFile)")
}

private func validateManifest(root: URL) throws {
    let vectorsDirectory = root.appendingPathComponent("TestVectors", isDirectory: true)
    let manifestURL = vectorsDirectory.appendingPathComponent(Defaults.manifestFile)
    let manifestData = try Data(contentsOf: manifestURL)
    try validateNoDuplicateJSONKeys(manifestData, file: Defaults.manifestFile)
    try validateKnownManifestKeys(manifestData)
    let manifest = try JSONDecoder().decode(NumiSealVectorManifest.self, from: manifestData)

    try require(manifest.manifestVersion == 1, "unsupported NumiSeal vector manifest version")
    try require(manifest.profile == Defaults.profile, "unexpected NumiSeal vector manifest profile")
    try require(manifest.schema == Defaults.schemaFile, "unexpected NumiSeal vector schema path")
    try require(
        FileManager.default.fileExists(atPath: vectorsDirectory.appendingPathComponent(manifest.schema).path),
        "NumiSeal vector schema file is missing"
    )

    var manifestedFiles = Set<String>()
    var coverage = Set<String>()
    var verifyCommands = Set<String>()
    for vector in manifest.vectors {
        let file = try validatedVectorFileName(vector.file)
        try require(manifestedFiles.insert(file).inserted, "\(vector.file) appears more than once in NumiSeal manifest")
        try require(verifyCommands.insert(vector.verifyCommand).inserted, "\(vector.file) verify command duplicates another vector")
        coverage.insert("\(vector.workload):\(vector.proofKind):\(vector.residualMode)")
        try require(vector.workload == Defaults.workload, "\(vector.file) unsupported NumiSeal workload")
        try require(vector.proofKind == Defaults.proofKind, "\(vector.file) unsupported NumiSeal proof kind")
        try require(vector.residualMode == Defaults.residualMode, "\(vector.file) unsupported NumiSeal residual mode")
        try require(vector.expectedKeySeedUTF8 == Defaults.keySeed, "\(vector.file) key seed mismatch")
        try validateHexDigest(vector.expectedShapeDigestHex, name: "\(vector.file) expected shape digest")
        try validateHexDigest(vector.expectedStatementDigestHex, name: "\(vector.file) expected statement digest")
        try validateHexDigest(vector.expectedVerifierKeyDigestHex, name: "\(vector.file) expected verifier-key digest")
        try validateHexDigest(vector.expectedTranscriptDomainHex, name: "\(vector.file) expected transcript domain")
        try validateHexDigest(vector.expectedPublicStatementDigestHex, name: "\(vector.file) expected public statement digest")
        try validateHexDigest(vector.expectedComponentDigestRootHex, name: "\(vector.file) expected component digest root")
        try validateHexDigest(vector.expectedProofTranscriptDigestHex, name: "\(vector.file) expected proof transcript digest")
        try require(vector.verifyCommand == strictVerifyCommand(file: file), "\(vector.file) verify command mismatch")

        let url = vectorsDirectory.appendingPathComponent(file)
        let data = try Data(contentsOf: url)
        try require(data.count == vector.byteCount, "\(vector.file) byte count mismatch")
        try require(sha256Hex(data) == vector.sha256, "\(vector.file) SHA-256 mismatch")

        let artifact = try validateSingleVector(path: url, root: root, expected: vector)
        try require(artifact.shapeDigestHex == vector.expectedShapeDigestHex, "\(vector.file) shape digest mismatch")
        try require(artifact.statementDigestHex == vector.expectedStatementDigestHex, "\(vector.file) statement digest mismatch")
        try require(artifact.verifierKeyDigestHex == vector.expectedVerifierKeyDigestHex, "\(vector.file) verifier-key digest mismatch")
        try require(artifact.transcriptDomainHex == vector.expectedTranscriptDomainHex, "\(vector.file) transcript domain mismatch")
        try require(artifact.publicStatementDigestHex == vector.expectedPublicStatementDigestHex, "\(vector.file) public statement digest mismatch")
        try require(artifact.aggregateDigestsHex == vector.expectedAggregateDigestsHex, "\(vector.file) aggregate digest mismatch")
        try require(artifact.componentDigestRootHex == vector.expectedComponentDigestRootHex, "\(vector.file) component digest root mismatch")
        try require(artifact.proofTranscriptDigestHex == vector.expectedProofTranscriptDigestHex, "\(vector.file) proof transcript digest mismatch")
    }

    let requiredCoverage: Set<String> = [
        "\(Defaults.workload):\(Defaults.proofKind):\(Defaults.residualMode)"
    ]
    let missingCoverage = requiredCoverage.subtracting(coverage).sorted()
    try require(
        missingCoverage.isEmpty,
        "NumiSeal manifest missing required vector coverage: \(missingCoverage.joined(separator: ","))"
    )

    print("validated \(Defaults.manifestFile)")
}

@discardableResult
private func validateSingleVector(
    path: URL,
    root: URL,
    expected: NumiSealManifestVector? = nil
) throws -> NumiSealVectorArtifact {
    let file = path.lastPathComponent
    let data = try Data(contentsOf: path)
    try validateNoDuplicateJSONKeys(data, file: file)
    try validateKnownArtifactKeys(data, file: file)
    let artifact = try JSONDecoder().decode(NumiSealVectorArtifact.self, from: data)
    try validateArtifactMetadata(artifact, file: file)

    if let expected {
        try require(artifact.workload == expected.workload, "\(file) workload mismatch")
        try require(artifact.proofKind == expected.proofKind, "\(file) proof kind mismatch")
        try require(artifact.residualMode == expected.residualMode, "\(file) residual mode mismatch")
        try require(artifact.keySeedUTF8 == expected.expectedKeySeedUTF8, "\(file) key seed mismatch")
    }

    guard let proofEnvelopeData = Data(base64Encoded: artifact.proofEnvelopeBase64) else {
        throw VectorCLIError.invalid("\(file) proof envelope is not base64")
    }
    let proofBytes = [UInt8](proofEnvelopeData)
    let parsedEnvelope = try NumiSealProofEnvelope(bytes: proofBytes)
    try validateParsedEnvelope(parsedEnvelope, artifact: artifact, file: file)

    let material = try makeMaterial(from: artifact)
    try require(
        material.envelope.superNeoBytes == proofBytes,
        "\(file) regenerated deterministic NumiSeal envelope does not match checked-in bytes"
    )

    let verifier = NumiSealVerifier(
        shape: material.shape,
        key: material.key,
        executionPolicy: .highAssurance
    )
    let result = verifier.verify(
        proofBytes: proofBytes,
        obligations: material.obligations,
        policy: material.terminalPolicy,
        aggregationLimits: try NumiSealAggregationLimits(
            maximumObligationsPerAggregate: artifact.maximumObligationsPerAggregate
        )
    )
    try require(result.isValid, "\(file) NumiSeal verifier rejected vector: \(result.reason ?? "unknown reason")")
    try require(result.envelope == parsedEnvelope, "\(file) verifier returned a different envelope")

    print("validated \(file)")
    return artifact
}

private func validateArtifactMetadata(_ artifact: NumiSealVectorArtifact, file: String) throws {
    try require(artifact.artifactVersion == 1, "\(file) artifact version mismatch")
    try require(artifact.workload == Defaults.workload, "\(file) unsupported workload")
    try require(artifact.profile == Defaults.profile, "\(file) unsupported profile")
    try require(artifact.proofKind == Defaults.proofKind, "\(file) unsupported proof kind")
    try require(artifact.residualMode == Defaults.residualMode, "\(file) unsupported residual mode")
    try require(artifact.keySeedUTF8 == Defaults.keySeed, "\(file) key seed mismatch")
    try require(artifact.foldTranscriptSeedUTF8 == Defaults.foldTranscriptSeed, "\(file) fold transcript seed mismatch")
    try require(artifact.laneIDsUTF8 == [Defaults.laneID], "\(file) lane IDs mismatch")
    try require(artifact.sourceFoldDigestSeedsUTF8 == [Defaults.sourceFoldDigestSeed], "\(file) source digest seeds mismatch")
    try require(artifact.ceRandomSeedsUTF8 == [Defaults.ceRandomSeed], "\(file) CE random seeds mismatch")
    try require(
        artifact.maximumObligationsPerAggregate == Defaults.maximumObligationsPerAggregate,
        "\(file) aggregate limit mismatch"
    )
    try require(artifact.maximumLaneCount == Defaults.maximumLaneCount, "\(file) lane limit mismatch")
    try require(artifact.maximumAggregatesPerLane == Defaults.maximumAggregatesPerLane, "\(file) aggregate policy limit mismatch")
    try require(artifact.publicInputCount == Defaults.publicInputCount, "\(file) public input count mismatch")
    try require(artifact.privateWitnessCount == Defaults.privateWitnessCount, "\(file) private witness count mismatch")
    try require(artifact.publicInputs == Array(repeating: 0, count: Defaults.publicInputCount), "\(file) public inputs mismatch")
    try require(artifact.keyColumnCount == expectedKeyColumnCount(artifact), "\(file) key column count mismatch")
    try require(artifact.aggregateDigestsHex.count == 1, "\(file) aggregate digest count mismatch")
    for (name, digest) in [
        ("shapeDigestHex", artifact.shapeDigestHex),
        ("statementDigestHex", artifact.statementDigestHex),
        ("verifierKeyDigestHex", artifact.verifierKeyDigestHex),
        ("transcriptDomainHex", artifact.transcriptDomainHex),
        ("publicStatementDigestHex", artifact.publicStatementDigestHex),
        ("obligationRootHex", artifact.obligationRootHex),
        ("laneSummaryRootHex", artifact.laneSummaryRootHex),
        ("componentDigestRootHex", artifact.componentDigestRootHex),
        ("proofTranscriptDigestHex", artifact.proofTranscriptDigestHex),
    ] {
        try validateHexDigest(digest, name: "\(file) \(name)")
    }
    for digest in artifact.aggregateDigestsHex {
        try validateHexDigest(digest, name: "\(file) aggregate digest")
    }
}

private func validateParsedEnvelope(
    _ envelope: NumiSealProofEnvelope,
    artifact: NumiSealVectorArtifact,
    file: String
) throws {
    try require(envelope.header.kind == .numiSealTerminal, "\(file) proof envelope kind mismatch")
    try require(envelope.header.profileID == SuperNeoParameterProfile.goldilocksPhi81.profileID, "\(file) profile id mismatch")
    try require(envelope.header.shapeDigest.hexString == artifact.shapeDigestHex, "\(file) header shape digest mismatch")
    try require(envelope.header.statementDigest.hexString == artifact.statementDigestHex, "\(file) header statement digest mismatch")
    try require(envelope.header.verifierKeyDigest.hexString == artifact.verifierKeyDigestHex, "\(file) header verifier-key digest mismatch")
    try require(envelope.header.transcriptDomain.hexString == artifact.transcriptDomainHex, "\(file) header transcript domain mismatch")
    try require(envelope.proof.publicStatement.digest.hexString == artifact.publicStatementDigestHex, "\(file) public statement digest mismatch")
    try require(envelope.proof.publicStatement.obligationRoot.hexString == artifact.obligationRootHex, "\(file) obligation root mismatch")
    try require(envelope.proof.publicStatement.laneSummaryRoot.hexString == artifact.laneSummaryRootHex, "\(file) lane summary root mismatch")
    try require(envelope.proof.laneProofs.map(\.aggregateDigest.hexString) == artifact.aggregateDigestsHex, "\(file) aggregate digest mismatch")
    try require(envelope.proof.componentDigestRoot.hexString == artifact.componentDigestRootHex, "\(file) component digest root mismatch")
    try require(envelope.proof.transcriptDigest.hexString == artifact.proofTranscriptDigestHex, "\(file) proof transcript digest mismatch")
}

private func makeArtifact() throws -> NumiSealVectorArtifact {
    let material = try makeMaterial(
        keySeed: Defaults.keySeed,
        keyColumnCount: expectedKeyColumnCount(
            publicInputCount: Defaults.publicInputCount,
            privateWitnessCount: Defaults.privateWitnessCount
        ),
        foldTranscriptSeed: Defaults.foldTranscriptSeed,
        laneIDs: [Defaults.laneID],
        sourceFoldDigestSeeds: [Defaults.sourceFoldDigestSeed],
        ceRandomSeeds: [Defaults.ceRandomSeed],
        publicInputCount: Defaults.publicInputCount,
        privateWitnessCount: Defaults.privateWitnessCount,
        maximumObligationsPerAggregate: Defaults.maximumObligationsPerAggregate,
        maximumLaneCount: Defaults.maximumLaneCount,
        maximumAggregatesPerLane: Defaults.maximumAggregatesPerLane
    )
    return NumiSealVectorArtifact(
        artifactVersion: 1,
        workload: Defaults.workload,
        profile: Defaults.profile,
        proofKind: Defaults.proofKind,
        residualMode: Defaults.residualMode,
        keySeedUTF8: Defaults.keySeed,
        keyColumnCount: material.key.matrix.columns,
        foldTranscriptSeedUTF8: Defaults.foldTranscriptSeed,
        laneIDsUTF8: [Defaults.laneID],
        sourceFoldDigestSeedsUTF8: [Defaults.sourceFoldDigestSeed],
        ceRandomSeedsUTF8: [Defaults.ceRandomSeed],
        maximumObligationsPerAggregate: Defaults.maximumObligationsPerAggregate,
        maximumLaneCount: Defaults.maximumLaneCount,
        maximumAggregatesPerLane: Defaults.maximumAggregatesPerLane,
        publicInputCount: Defaults.publicInputCount,
        privateWitnessCount: Defaults.privateWitnessCount,
        publicInputs: Array(repeating: 0, count: Defaults.publicInputCount),
        shapeDigestHex: material.policy.shapeDigest.hexString,
        statementDigestHex: material.policy.statementDigest.hexString,
        verifierKeyDigestHex: material.policy.verifierKeyDigest.hexString,
        transcriptDomainHex: material.policy.transcriptDomain.hexString,
        publicStatementDigestHex: material.plan.publicStatement.digest.hexString,
        obligationRootHex: material.plan.publicStatement.obligationRoot.hexString,
        laneSummaryRootHex: material.plan.publicStatement.laneSummaryRoot.hexString,
        aggregateDigestsHex: material.plan.aggregateDigests.map(\.hexString),
        componentDigestRootHex: material.envelope.proof.componentDigestRoot.hexString,
        proofTranscriptDigestHex: material.envelope.proof.transcriptDigest.hexString,
        proofEnvelopeBase64: Data(material.envelope.superNeoBytes).base64EncodedString()
    )
}

private func makeMaterial(from artifact: NumiSealVectorArtifact) throws -> NumiSealVectorMaterial {
    try makeMaterial(
        keySeed: artifact.keySeedUTF8,
        keyColumnCount: artifact.keyColumnCount,
        foldTranscriptSeed: artifact.foldTranscriptSeedUTF8,
        laneIDs: artifact.laneIDsUTF8,
        sourceFoldDigestSeeds: artifact.sourceFoldDigestSeedsUTF8,
        ceRandomSeeds: artifact.ceRandomSeedsUTF8,
        publicInputCount: artifact.publicInputCount,
        privateWitnessCount: artifact.privateWitnessCount,
        maximumObligationsPerAggregate: artifact.maximumObligationsPerAggregate,
        maximumLaneCount: artifact.maximumLaneCount,
        maximumAggregatesPerLane: artifact.maximumAggregatesPerLane
    )
}

private func makeMaterial(
    keySeed: String,
    keyColumnCount: Int,
    foldTranscriptSeed: String,
    laneIDs: [String],
    sourceFoldDigestSeeds: [String],
    ceRandomSeeds: [String],
    publicInputCount: Int,
    privateWitnessCount: Int,
    maximumObligationsPerAggregate: Int,
    maximumLaneCount: Int,
    maximumAggregatesPerLane: Int
) throws -> NumiSealVectorMaterial {
    try require(!laneIDs.isEmpty, "NumiSeal vector must include at least one lane ID")
    try require(laneIDs.count == sourceFoldDigestSeeds.count, "NumiSeal vector lane/source seed count mismatch")
    try require(laneIDs.count == ceRandomSeeds.count, "NumiSeal vector lane/CE seed count mismatch")
    try require(keyColumnCount == expectedKeyColumnCount(
        publicInputCount: publicInputCount,
        privateWitnessCount: privateWitnessCount
    ), "NumiSeal vector key column count mismatch")

    let publicInput = Array(repeating: GoldilocksField.zero, count: publicInputCount)
    let privateWitness = Array(repeating: GoldilocksField.zero, count: privateWitnessCount)
    let matrix = try SparseFieldMatrix.identity(size: publicInput.count + privateWitness.count)
    let structure = CCSStructure.hadamardProduct(matrices: [matrix])
    let backend = SuperNeoCPUBackend()
    let key = try AjtaiCommitmentKey(
        columns: keyColumnCount,
        seed: Array(keySeed.utf8)
    )
    let commitment = try backend.commit(key: key, message: publicInput + privateWitness)
    let input = try SuperNeoFoldInput(
        structure: structure,
        instances: [CCSInstance(commitment: commitment, publicInput: publicInput)],
        witnesses: [CCSWitness(privateWitness)]
    )
    let fold = try backend.makeProver(
        key: key,
        executionPolicy: .highAssurance
    ).foldWithOutput(input, transcriptSeed: Array(foldTranscriptSeed.utf8))
    let publicFoldInput = SuperNeoPublicFoldInput(input)
    let statement = CCSStatement(
        shapeDigest: publicFoldInput.shape.shapeDigest,
        ccsInstances: publicFoldInput.instances
    )
    let claims = Array(fold.outputClaims.prefix(laneIDs.count))
    try require(claims.count == laneIDs.count, "NumiSeal vector fold did not produce enough output claims")
    let laneIDs = try laneIDs.map(NumiSealLaneID.init)
    let obligations = zip(zip(laneIDs, claims), sourceFoldDigestSeeds).map { pair, sourceSeed in
        let (laneID, claim) = pair
        return NumiSealObligation(
            laneID: laneID,
            profileID: key.parameters.profileID,
            statement: statement,
            verifierKeyDigest: key.verifierKeyDigest,
            instance: CEInstance(claim),
            sourceFoldDigest: Digest256.hash(sourceSeed)
        )
    }
    let witnessed = try zip(obligations, claims).map { obligation, claim in
        try NumiSealWitnessedObligation(obligation: obligation, claim: claim)
    }
    let policy = NumiSealAcceptancePolicy(
        statement: statement,
        verifierKeyDigest: key.verifierKeyDigest,
        acceptedLaneIDs: Set(laneIDs)
    )
    let aggregationLimits = try NumiSealAggregationLimits(
        maximumObligationsPerAggregate: maximumObligationsPerAggregate
    )
    let prover = NumiSealProver(
        shape: input.shape,
        key: key,
        executionPolicy: .highAssurance
    )
    let plan = try prover.provingPlan(
        obligations: obligations,
        policy: policy,
        aggregationLimits: aggregationLimits
    )
    try require(plan.aggregateCount == ceRandomSeeds.count, "NumiSeal vector CE seed count does not match aggregate count")
    let digitTensorInputs = try plan.aggregates.map { _ in
        try NumiSealAggregateDigitTensorInput(message: makeTernaryMessage())
    }
    let envelope = try prover.proveDeterministic(
        witnessedObligations: witnessed,
        policy: policy,
        digitTensorInputs: digitTensorInputs,
        ceRandomSeeds: ceRandomSeeds.map { Array($0.utf8) },
        aggregationLimits: aggregationLimits
    )
    let terminalPolicy = NumiSealTerminalProofAcceptancePolicy(
        profileID: policy.profileID,
        shapeDigest: policy.shapeDigest,
        statementDigest: policy.statementDigest,
        verifierKeyDigest: policy.verifierKeyDigest,
        transcriptDomain: policy.transcriptDomain,
        acceptedLaneIDs: policy.acceptedLaneIDs,
        maximumLaneCount: maximumLaneCount,
        maximumAggregatesPerLane: maximumAggregatesPerLane
    )
    return NumiSealVectorMaterial(
        shape: input.shape,
        key: key,
        obligations: obligations,
        policy: policy,
        terminalPolicy: terminalPolicy,
        plan: plan,
        envelope: envelope
    )
}

private func makeTernaryMessage() -> [CyclotomicRing54] {
    [
        CyclotomicRing54([
            .one,
            -GoldilocksField.one,
            .zero,
            .one,
            .zero,
            -GoldilocksField.one
        ])
    ]
}

private func validateKnownManifestKeys(_ data: Data) throws {
    let json = try JSONSerialization.jsonObject(with: data)
    guard let object = json as? [String: Any] else {
        throw VectorCLIError.invalid("\(Defaults.manifestFile) JSON must be an object")
    }
    let unknownTopLevelKeys = Set(object.keys).subtracting(manifestTopLevelKeys).sorted()
    try require(
        unknownTopLevelKeys.isEmpty,
        "\(Defaults.manifestFile) contains unknown top-level fields: \(unknownTopLevelKeys.joined(separator: ","))"
    )
    guard let vectors = object["vectors"] as? [Any] else {
        throw VectorCLIError.invalid("\(Defaults.manifestFile) vectors must be an array")
    }
    for (index, rawVector) in vectors.enumerated() {
        guard let vectorObject = rawVector as? [String: Any] else {
            throw VectorCLIError.invalid("\(Defaults.manifestFile) vectors[\(index)] must be an object")
        }
        let unknownVectorKeys = Set(vectorObject.keys).subtracting(manifestVectorKeys).sorted()
        try require(
            unknownVectorKeys.isEmpty,
            "\(Defaults.manifestFile) vectors[\(index)] contains unknown fields: \(unknownVectorKeys.joined(separator: ","))"
        )
    }
}

private func validateKnownArtifactKeys(_ data: Data, file: String) throws {
    let json = try JSONSerialization.jsonObject(with: data)
    guard let object = json as? [String: Any] else {
        throw VectorCLIError.invalid("\(file) JSON must be an object")
    }
    let unknownKeys = Set(object.keys).subtracting(artifactTopLevelKeys).sorted()
    try require(
        unknownKeys.isEmpty,
        "\(file) contains unknown top-level fields: \(unknownKeys.joined(separator: ","))"
    )
}

private func validatedVectorFileName(_ file: String) throws -> String {
    guard !file.isEmpty,
          file.hasSuffix(".json"),
          file == URL(fileURLWithPath: file).lastPathComponent,
          !file.contains("..")
    else {
        throw VectorCLIError.invalid("unsafe NumiSeal vector file path in manifest: \(file)")
    }
    return file
}

private func strictVerifyCommand(file: String) -> String {
    "swift run superneo-numiseal-vectors validate TestVectors/\(file)"
}

private func vectorURL(_ path: String, root: URL) -> URL {
    let url = URL(fileURLWithPath: path)
    if url.path.hasPrefix("/") {
        return url.standardizedFileURL
    }
    return root.appendingPathComponent(path).standardizedFileURL
}

private func expectedKeyColumnCount(_ artifact: NumiSealVectorArtifact) -> Int {
    expectedKeyColumnCount(
        publicInputCount: artifact.publicInputCount,
        privateWitnessCount: artifact.privateWitnessCount
    )
}

private func expectedKeyColumnCount(publicInputCount: Int, privateWitnessCount: Int) -> Int {
    SuperNeoEmbedding.paddedLength(forFieldElementCount: publicInputCount + privateWitnessCount)
        / CyclotomicRing54.degree
}

private func encodeJSON<T: Encodable>(_ value: T) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return try encoder.encode(value)
}

private func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    guard condition() else {
        throw VectorCLIError.invalid(message)
    }
}

private func validateHexDigest(_ digest: String, name: String) throws {
    try require(
        digest.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil,
        "\(name) must be a lowercase 64-character hex digest"
    )
}

private func sha256Hex(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func validateNoDuplicateJSONKeys(_ data: Data, file: String) throws {
    var scanner = JSONDuplicateKeyScanner(data: data, file: file)
    try scanner.validate()
}

private struct JSONDuplicateKeyScanner {
    private let bytes: [UInt8]
    private let file: String
    private var index = 0

    init(data: Data, file: String) {
        self.bytes = Array(data)
        self.file = file
    }

    mutating func validate() throws {
        try parseValue(path: "$")
        skipWhitespace()
        guard index == bytes.count else {
            throw invalid("JSON contains trailing data")
        }
    }

    private func invalid(_ message: String) -> VectorCLIError {
        .invalid("\(file) \(message)")
    }

    private mutating func parseValue(path: String) throws {
        skipWhitespace()
        guard let byte = peek() else {
            throw invalid("JSON ended unexpectedly")
        }
        switch byte {
        case UInt8(ascii: "{"):
            try parseObject(path: path)
        case UInt8(ascii: "["):
            try parseArray(path: path)
        case UInt8(ascii: "\""):
            _ = try parseString()
        case UInt8(ascii: "t"):
            try consumeLiteral("true")
        case UInt8(ascii: "f"):
            try consumeLiteral("false")
        case UInt8(ascii: "n"):
            try consumeLiteral("null")
        case UInt8(ascii: "-"), UInt8(ascii: "0")...UInt8(ascii: "9"):
            try consumeNumber()
        default:
            throw invalid("JSON contains an invalid value at \(path)")
        }
    }

    private mutating func parseObject(path: String) throws {
        try consume(UInt8(ascii: "{"))
        skipWhitespace()
        var seen = Set<String>()
        if consumeIfPresent(UInt8(ascii: "}")) {
            return
        }
        while true {
            skipWhitespace()
            guard peek() == UInt8(ascii: "\"") else {
                throw invalid("JSON object key must be a string at \(path)")
            }
            let key = try parseString()
            if !seen.insert(key).inserted {
                throw VectorCLIError.invalid("\(file) contains duplicate JSON object key '\(key)' at \(path)")
            }
            skipWhitespace()
            try consume(UInt8(ascii: ":"))
            try parseValue(path: "\(path).\(key)")
            skipWhitespace()
            if consumeIfPresent(UInt8(ascii: "}")) {
                return
            }
            try consume(UInt8(ascii: ","))
        }
    }

    private mutating func parseArray(path: String) throws {
        try consume(UInt8(ascii: "["))
        skipWhitespace()
        if consumeIfPresent(UInt8(ascii: "]")) {
            return
        }
        var elementIndex = 0
        while true {
            try parseValue(path: "\(path)[\(elementIndex)]")
            elementIndex += 1
            skipWhitespace()
            if consumeIfPresent(UInt8(ascii: "]")) {
                return
            }
            try consume(UInt8(ascii: ","))
        }
    }

    private mutating func parseString() throws -> String {
        try consume(UInt8(ascii: "\""))
        var scalars = String.UnicodeScalarView()
        while let byte = peek() {
            index += 1
            switch byte {
            case UInt8(ascii: "\""):
                return String(scalars)
            case UInt8(ascii: "\\"):
                guard let escaped = peek() else {
                    throw invalid("JSON string has an unterminated escape")
                }
                index += 1
                switch escaped {
                case UInt8(ascii: "\""): scalars.append("\"")
                case UInt8(ascii: "\\"): scalars.append("\\")
                case UInt8(ascii: "/"): scalars.append("/")
                case UInt8(ascii: "b"): scalars.append("\u{08}")
                case UInt8(ascii: "f"): scalars.append("\u{0C}")
                case UInt8(ascii: "n"): scalars.append("\n")
                case UInt8(ascii: "r"): scalars.append("\r")
                case UInt8(ascii: "t"): scalars.append("\t")
                case UInt8(ascii: "u"):
                    let scalarValue = try parseUnicodeEscape()
                    guard let scalar = UnicodeScalar(scalarValue) else {
                        throw invalid("JSON string contains an invalid unicode scalar")
                    }
                    scalars.append(scalar)
                default:
                    throw invalid("JSON string contains an invalid escape")
                }
            case 0x00...0x1F:
                throw invalid("JSON string contains an unescaped control character")
            case 0x00...0x7F:
                scalars.append(UnicodeScalar(Int(byte))!)
            default:
                let start = index - 1
                while let next = peek(), next >= 0x80 {
                    index += 1
                }
                guard let value = String(data: Data(bytes[start..<index]), encoding: .utf8) else {
                    throw invalid("JSON string is not valid UTF-8")
                }
                scalars.append(contentsOf: value.unicodeScalars)
            }
        }
        throw invalid("JSON string is unterminated")
    }

    private mutating func parseUnicodeEscape() throws -> UInt32 {
        let high = try parseFourHexDigits()
        guard (0xD800...0xDBFF).contains(high) else {
            if (0xDC00...0xDFFF).contains(high) {
                throw invalid("JSON string contains an unpaired low surrogate")
            }
            return high
        }
        guard consumeIfPresent(UInt8(ascii: "\\")), consumeIfPresent(UInt8(ascii: "u")) else {
            throw invalid("JSON string contains an unpaired high surrogate")
        }
        let low = try parseFourHexDigits()
        guard (0xDC00...0xDFFF).contains(low) else {
            throw invalid("JSON string contains an invalid surrogate pair")
        }
        return 0x10000 + ((high - 0xD800) << 10) + (low - 0xDC00)
    }

    private mutating func parseFourHexDigits() throws -> UInt32 {
        var value: UInt32 = 0
        for _ in 0..<4 {
            guard let byte = peek(), let digit = hexValue(byte) else {
                throw invalid("JSON string contains an invalid unicode escape")
            }
            index += 1
            value = (value << 4) | digit
        }
        return value
    }

    private mutating func consumeNumber() throws {
        if consumeIfPresent(UInt8(ascii: "-")) {
            guard let byte = peek(), (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte) else {
                throw invalid("JSON number is invalid")
            }
        }
        if consumeIfPresent(UInt8(ascii: "0")) {
            if let byte = peek(), (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte) {
                throw invalid("JSON number has a leading zero")
            }
        } else {
            guard let byte = peek(), (UInt8(ascii: "1")...UInt8(ascii: "9")).contains(byte) else {
                throw invalid("JSON number is invalid")
            }
            while isDigit(peek()) {
                index += 1
            }
        }
        if consumeIfPresent(UInt8(ascii: ".")) {
            guard let byte = peek(), (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte) else {
                throw invalid("JSON fractional number is invalid")
            }
            while isDigit(peek()) {
                index += 1
            }
        }
        if consumeIfPresent(UInt8(ascii: "e")) || consumeIfPresent(UInt8(ascii: "E")) {
            _ = consumeIfPresent(UInt8(ascii: "+")) || consumeIfPresent(UInt8(ascii: "-"))
            guard let byte = peek(), (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte) else {
                throw invalid("JSON exponent is invalid")
            }
            while isDigit(peek()) {
                index += 1
            }
        }
    }

    private mutating func consumeLiteral(_ literal: String) throws {
        for byte in literal.utf8 {
            try consume(byte)
        }
    }

    private mutating func consume(_ expected: UInt8) throws {
        guard consumeIfPresent(expected) else {
            throw invalid("JSON syntax error")
        }
    }

    private mutating func consumeIfPresent(_ expected: UInt8) -> Bool {
        guard peek() == expected else { return false }
        index += 1
        return true
    }

    private mutating func skipWhitespace() {
        while let byte = peek(),
              byte == UInt8(ascii: " ")
                || byte == UInt8(ascii: "\n")
                || byte == UInt8(ascii: "\r")
                || byte == UInt8(ascii: "\t")
        {
            index += 1
        }
    }

    private func peek() -> UInt8? {
        index < bytes.count ? bytes[index] : nil
    }

    private func isDigit(_ byte: UInt8?) -> Bool {
        guard let byte else { return false }
        return (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte)
    }

    private func hexValue(_ byte: UInt8) -> UInt32? {
        switch byte {
        case UInt8(ascii: "0")...UInt8(ascii: "9"):
            return UInt32(byte - UInt8(ascii: "0"))
        case UInt8(ascii: "a")...UInt8(ascii: "f"):
            return UInt32(byte - UInt8(ascii: "a") + 10)
        case UInt8(ascii: "A")...UInt8(ascii: "F"):
            return UInt32(byte - UInt8(ascii: "A") + 10)
        default:
            return nil
        }
    }
}

private extension Digest256 {
    var hexString: String {
        bytes.map { String(format: "%02x", $0) }.joined()
    }
}
