import Foundation
import SuperNeo_NuMetal

private enum CLIError: Error, CustomStringConvertible {
    case usage(String)
    case invalidArgument(String)

    var description: String {
        switch self {
        case .usage(let message), .invalidArgument(let message):
            return message
        }
    }
}

private struct DemoProofArtifact: Codable {
    var artifactVersion: UInt32
    var workload: String
    var profile: String
    var proofKind: String
    var bitCount: Int
    var expectedSelectedCount: UInt64?
    var keySeedUTF8: String
    var workloadParameters: [String: String]?
    var publicInputs: [UInt64]
    var commitmentBase64: String
    var proofEnvelopeBase64: String
    var shapeDigestHex: String
    var statementDigestHex: String
    var verifierKeyDigestHex: String
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

private struct NumiSealVerificationMaterial {
    let shape: CCSShape
    let key: AjtaiCommitmentKey
    let obligations: [NumiSealObligation]
    let policy: NumiSealAcceptancePolicy
    let terminalPolicy: NumiSealTerminalProofAcceptancePolicy
    let aggregationLimits: NumiSealAggregationLimits
    let plan: NumiSealProvingPlan
}

private enum ProofArtifact {
    case demo(DemoProofArtifact)
    case numiSeal(NumiSealVectorArtifact)
}

private let demoProofArtifactTopLevelKeys: Set<String> = [
    "artifactVersion",
    "workload",
    "profile",
    "proofKind",
    "bitCount",
    "expectedSelectedCount",
    "keySeedUTF8",
    "workloadParameters",
    "publicInputs",
    "commitmentBase64",
    "proofEnvelopeBase64",
    "shapeDigestHex",
    "statementDigestHex",
    "verifierKeyDigestHex",
]

private let numiSealArtifactTopLevelKeys: Set<String> = [
    "aggregateDigestsHex",
    "artifactVersion",
    "ceRandomSeedsUTF8",
    "componentDigestRootHex",
    "foldTranscriptSeedUTF8",
    "keyColumnCount",
    "keySeedUTF8",
    "laneIDsUTF8",
    "laneSummaryRootHex",
    "maximumAggregatesPerLane",
    "maximumLaneCount",
    "maximumObligationsPerAggregate",
    "obligationRootHex",
    "privateWitnessCount",
    "profile",
    "proofEnvelopeBase64",
    "proofKind",
    "proofTranscriptDigestHex",
    "publicInputCount",
    "publicInputs",
    "publicStatementDigestHex",
    "residualMode",
    "shapeDigestHex",
    "sourceFoldDigestSeedsUTF8",
    "statementDigestHex",
    "transcriptDomainHex",
    "verifierKeyDigestHex",
    "workload",
]

private enum NumiSealArtifactDefaults {
    static let proofKind = "numiseal-terminal"
    static let residualMode = "immediate"
}

private enum DemoProofKind: String {
    case fold
    case terminal
    case compressedTerminal = "compressed-terminal"

    var envelopeKind: ProofEnvelopeKind {
        switch self {
        case .fold: return .foldReduction
        case .terminal: return .terminalLocal
        case .compressedTerminal: return .compressedPublic
        }
    }

    var satisfiesTerminalRequirement: Bool {
        switch self {
        case .fold: return false
        case .terminal, .compressedTerminal: return true
        }
    }
}

private enum DemoWorkload: String {
    case oneHot = "one-hot"
    case binaryAdd = "binary-add"
}

private struct ProveOptions {
    var outputPath = "superneo-one-hot-proof.json"
    var workload: DemoWorkload = .oneHot
    var bits = [false, false, true, false, false, false, false, false]
    var operandBits = 8
    var leftOperand: UInt64 = 13
    var rightOperand: UInt64 = 29
    var keySeed: String?
    var proofKind: DemoProofKind = .fold
}

private struct VerifyOptions {
    var path: String
    var trustedKeySeed: String?
    var expectedVerifierKeyDigestHex: String?
    var expectedShapeDigestHex: String?
    var expectedStatementDigestHex: String?
    var expectedTranscriptDomainDigestHex: String?
    var expectedPublicStatementDigestHex: String?
    var expectedObligationRootHex: String?
    var expectedLaneSummaryRootHex: String?
    var expectedAggregateDigestsHex: [String]?
    var expectedComponentDigestRootHex: String?
    var expectedProofTranscriptDigestHex: String?
    var expectedPublicInputs: [UInt64]?
    var requireTerminalProof = false
    var requireNumiSealProof = false
}

private func usage() -> String {
    """
    Usage:
      superneo prove [--workload one-hot] [--bits 0,0,1,0] [--kind fold|terminal|compressed-terminal] [--key-seed text] [--output proof.json]
      superneo prove --workload binary-add [--operand-bits 8] [--lhs 13] [--rhs 29] [--kind fold|terminal|compressed-terminal] [--output proof.json]
      superneo verify [--key-seed text] [--expected-verifier-key-digest hex] [--expected-shape-digest hex] [--expected-statement-digest hex] [--expected-public-inputs values] [--require-terminal|--require-numiseal] proof.json
      superneo inspect proof.json

    Workloads:
      one-hot: proves a committed private bit vector has exactly one selected bit.
      binary-add: proves two committed private integers add to public sum bits.

    The default proof kind is fold. Terminal proofs are complete but currently
    much larger and slower because they include the public CE opening proof.
    compressed-terminal proofs keep terminal acceptance while compressing public
    terminal statement material behind digest bindings.
    NumiSeal terminal artifacts are verifier-only in this CLI and require the
    explicit --require-numiseal policy gate. Strict NumiSeal verification also
    accepts --expected-transcript-domain-digest, --expected-public-statement-digest,
    --expected-obligation-root, --expected-lane-summary-root,
    --expected-aggregate-digests, --expected-component-digest-root, and
    --expected-proof-transcript-digest.
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
        throw CLIError.usage(usage())
    }
    switch command {
    case "prove":
        try prove(parseProveOptions(Array(arguments.dropFirst())))
    case "verify":
        try verify(options: parseVerifyOptions(Array(arguments.dropFirst())))
    case "inspect":
        guard arguments.count == 2 else {
            throw CLIError.usage("inspect expects exactly one proof artifact path")
        }
        try inspect(path: arguments[1])
    case "-h", "--help", "help":
        print(usage())
    default:
        throw CLIError.usage("unknown command: \(command)")
    }
}

private func parseProveOptions(_ arguments: [String]) throws -> ProveOptions {
    var options = ProveOptions()
    var index = 0
    while index < arguments.count {
        let argument = arguments[index]
        func requireValue() throws -> String {
            guard index + 1 < arguments.count else {
                throw CLIError.invalidArgument("\(argument) requires a value")
            }
            index += 1
            return arguments[index]
        }
        switch argument {
        case "--workload":
            let raw = try requireValue()
            guard let workload = DemoWorkload(rawValue: raw) else {
                throw CLIError.invalidArgument("--workload must be one-hot or binary-add")
            }
            options.workload = workload
        case "--output", "-o":
            options.outputPath = try requireValue()
        case "--bits":
            options.bits = try parseBits(try requireValue())
        case "--operand-bits":
            options.operandBits = try parsePositiveInt(try requireValue(), name: "--operand-bits")
        case "--lhs":
            options.leftOperand = try parseUInt64(try requireValue(), name: "--lhs")
        case "--rhs":
            options.rightOperand = try parseUInt64(try requireValue(), name: "--rhs")
        case "--key-seed":
            options.keySeed = try requireValue()
        case "--kind":
            let raw = try requireValue()
            guard let kind = DemoProofKind(rawValue: raw) else {
                throw CLIError.invalidArgument("--kind must be fold, terminal, or compressed-terminal")
            }
            options.proofKind = kind
        default:
            throw CLIError.invalidArgument("unknown prove option: \(argument)")
        }
        index += 1
    }
    guard !options.bits.isEmpty else {
        throw CLIError.invalidArgument("--bits must contain at least one bit")
    }
    guard options.operandBits > 0, options.operandBits <= 62 else {
        throw CLIError.invalidArgument("--operand-bits must be in 1...62")
    }
    return options
}

private func parseVerifyOptions(_ arguments: [String]) throws -> VerifyOptions {
    var path: String?
    var trustedKeySeed: String?
    var expectedVerifierKeyDigestHex: String?
    var expectedShapeDigestHex: String?
    var expectedStatementDigestHex: String?
    var expectedTranscriptDomainDigestHex: String?
    var expectedPublicStatementDigestHex: String?
    var expectedObligationRootHex: String?
    var expectedLaneSummaryRootHex: String?
    var expectedAggregateDigestsHex: [String]?
    var expectedComponentDigestRootHex: String?
    var expectedProofTranscriptDigestHex: String?
    var expectedPublicInputs: [UInt64]?
    var requireTerminalProof = false
    var requireNumiSealProof = false
    var index = 0
    while index < arguments.count {
        let argument = arguments[index]
        func requireValue() throws -> String {
            guard index + 1 < arguments.count else {
                throw CLIError.invalidArgument("\(argument) requires a value")
            }
            index += 1
            return arguments[index]
        }
        switch argument {
        case "--key-seed":
            trustedKeySeed = try requireValue()
        case "--expected-verifier-key-digest":
            expectedVerifierKeyDigestHex = try parseHexDigest(try requireValue(), name: argument)
        case "--expected-shape-digest":
            expectedShapeDigestHex = try parseHexDigest(try requireValue(), name: argument)
        case "--expected-statement-digest":
            expectedStatementDigestHex = try parseHexDigest(try requireValue(), name: argument)
        case "--expected-transcript-domain-digest":
            expectedTranscriptDomainDigestHex = try parseHexDigest(try requireValue(), name: argument)
        case "--expected-public-statement-digest":
            expectedPublicStatementDigestHex = try parseHexDigest(try requireValue(), name: argument)
        case "--expected-obligation-root":
            expectedObligationRootHex = try parseHexDigest(try requireValue(), name: argument)
        case "--expected-lane-summary-root":
            expectedLaneSummaryRootHex = try parseHexDigest(try requireValue(), name: argument)
        case "--expected-aggregate-digests":
            expectedAggregateDigestsHex = try parseHexDigestList(try requireValue(), name: argument)
        case "--expected-component-digest-root":
            expectedComponentDigestRootHex = try parseHexDigest(try requireValue(), name: argument)
        case "--expected-proof-transcript-digest":
            expectedProofTranscriptDigestHex = try parseHexDigest(try requireValue(), name: argument)
        case "--expected-public-inputs":
            expectedPublicInputs = try parsePublicInputList(try requireValue(), name: argument)
        case "--require-terminal":
            requireTerminalProof = true
        case "--require-numiseal":
            requireNumiSealProof = true
        default:
            guard !argument.hasPrefix("-") else {
                throw CLIError.invalidArgument("unknown verify option: \(argument)")
            }
            guard path == nil else {
                throw CLIError.usage("verify expects exactly one proof artifact path")
            }
            path = argument
        }
        index += 1
    }
    guard let path else {
        throw CLIError.usage("verify expects exactly one proof artifact path")
    }
    if requireTerminalProof && requireNumiSealProof {
        throw CLIError.invalidArgument("choose either --require-terminal or --require-numiseal, not both")
    }
    return VerifyOptions(
        path: path,
        trustedKeySeed: trustedKeySeed,
        expectedVerifierKeyDigestHex: expectedVerifierKeyDigestHex,
        expectedShapeDigestHex: expectedShapeDigestHex,
        expectedStatementDigestHex: expectedStatementDigestHex,
        expectedTranscriptDomainDigestHex: expectedTranscriptDomainDigestHex,
        expectedPublicStatementDigestHex: expectedPublicStatementDigestHex,
        expectedObligationRootHex: expectedObligationRootHex,
        expectedLaneSummaryRootHex: expectedLaneSummaryRootHex,
        expectedAggregateDigestsHex: expectedAggregateDigestsHex,
        expectedComponentDigestRootHex: expectedComponentDigestRootHex,
        expectedProofTranscriptDigestHex: expectedProofTranscriptDigestHex,
        expectedPublicInputs: expectedPublicInputs,
        requireTerminalProof: requireTerminalProof,
        requireNumiSealProof: requireNumiSealProof
    )
}

private func prove(_ options: ProveOptions) throws {
    let started = Date()
    let keySeed = try options.keySeed ?? defaultKeySeed(for: options)
    let prepared: SuperNeoPreparedR1CS
    let artifactWorkload: String
    let artifactBitCount: Int
    let artifactPublicInputs: [UInt64]
    let artifactParameters: [String: String]
    switch options.workload {
    case .oneHot:
        let workload = try SuperNeoOneHotVectorWorkload(bitCount: options.bits.count)
        prepared = try workload.prepareForFolding(
            bits: options.bits,
            keySeed: Array(keySeed.utf8)
        )
        artifactWorkload = "one-hot-vector-v1"
        artifactBitCount = options.bits.count
        artifactPublicInputs = [1]
        artifactParameters = [
            "selectedCount": "\(options.bits.filter { $0 }.count)"
        ]
    case .binaryAdd:
        let workload = try SuperNeoBinaryAdditionWorkload(bitCount: options.operandBits)
        let sum = try checkedSum(options.leftOperand, options.rightOperand)
        prepared = try workload.prepareForFolding(
            left: options.leftOperand,
            right: options.rightOperand,
            keySeed: Array(keySeed.utf8)
        )
        artifactWorkload = "binary-addition-v1"
        artifactBitCount = options.operandBits
        artifactPublicInputs = try workload.publicInput(sum: sum).map(\.rawValue)
        artifactParameters = [
            "leftBitCount": "\(options.operandBits)",
            "publicSum": "\(sum)"
        ]
    }
    let publicInput = prepared.publicFoldInput
    let statement = CCSStatement(
        shapeDigest: publicInput.shape.shapeDigest,
        ccsInstances: publicInput.instances,
        priorCEInstances: publicInput.priorClaims.map { CEInstance($0) }
    )
    let context = ProofEnvelopeContext(
        kind: options.proofKind.envelopeKind,
        statement: statement,
        verifierKeyDigest: prepared.key.verifierKeyDigest
    )
    let prover = SuperNeoCPUBackend().makeProver(key: prepared.key, executionPolicy: .highAssurance)
    let envelopeBytes: [UInt8]
    switch options.proofKind {
    case .fold:
        envelopeBytes = try prover.foldEnvelope(prepared.foldInput, context: context).superNeoBytes
    case .terminal:
        envelopeBytes = try prover.terminalFoldEnvelope(prepared.foldInput, context: context).superNeoBytes
    case .compressedTerminal:
        envelopeBytes = try prover.compressedTerminalFoldEnvelope(prepared.foldInput, context: context).superNeoBytes
    }
    let elapsed = Date().timeIntervalSince(started)
    let artifact = DemoProofArtifact(
        artifactVersion: 1,
        workload: artifactWorkload,
        profile: SuperNeoParameterProfile.goldilocksPhi81.name,
        proofKind: options.proofKind.rawValue,
        bitCount: artifactBitCount,
        expectedSelectedCount: options.workload == .oneHot ? 1 : nil,
        keySeedUTF8: keySeed,
        workloadParameters: artifactParameters,
        publicInputs: artifactPublicInputs,
        commitmentBase64: Data(prepared.publicFoldInput.instances[0].commitment.littleEndianBytes).base64EncodedString(),
        proofEnvelopeBase64: Data(envelopeBytes).base64EncodedString(),
        shapeDigestHex: publicInput.shape.shapeDigest.hexString,
        statementDigestHex: statement.statementDigest.hexString,
        verifierKeyDigestHex: prepared.key.verifierKeyDigest.hexString
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(artifact)
    try data.write(to: URL(fileURLWithPath: options.outputPath), options: Data.WritingOptions.atomic)
    print("wrote \(options.outputPath)")
    print("workload: \(artifact.workload)")
    print("profile: \(artifact.profile)")
    print("proof kind: \(artifact.proofKind)")
    print("bit count: \(artifact.bitCount)")
    print("proof envelope bytes: \(envelopeBytes.count)")
    print(String(format: "prove time: %.3f s", elapsed))
}

private func verify(options: VerifyOptions) throws {
    switch try readProofArtifact(path: options.path) {
    case .demo(let artifact):
        try verifyDemoArtifact(artifact, options: options)
    case .numiSeal(let artifact):
        try verifyNumiSealArtifact(artifact, options: options)
    }
}

private func verifyDemoArtifact(_ artifact: DemoProofArtifact, options: VerifyOptions) throws {
    if options.requireNumiSealProof {
        throw CLIError.invalidArgument("NumiSeal proof required, but artifact contains \(artifact.proofKind)")
    }
    if options.hasNumiSealExpectedContext {
        throw CLIError.invalidArgument("NumiSeal expected context options require a NumiSeal artifact")
    }
    let proofBytes = try artifact.proofEnvelopeBytes()
    let header = try parseEnvelopeHeader(proofBytes)
    let kind = try artifact.demoProofKind()
    try validateArtifactEnvelopeHeader(header, artifact: artifact, kind: kind)
    if let expectedPublicInputs = options.expectedPublicInputs {
        guard artifact.publicInputs == expectedPublicInputs else {
            throw CLIError.invalidArgument("artifact public inputs do not match expected public inputs")
        }
    }
    let publicInput = try makePublicInput(from: artifact)
    if let expectedShapeDigestHex = options.expectedShapeDigestHex {
        guard publicInput.shape.shapeDigest.hexString == expectedShapeDigestHex else {
            throw CLIError.invalidArgument("artifact shape digest does not match expected shape digest")
        }
    }
    let keySeed = options.trustedKeySeed ?? artifact.keySeedUTF8
    let key = try AjtaiCommitmentKey(columns: publicInput.shape.nRing, seed: Array(keySeed.utf8))
    if let expectedVerifierKeyDigestHex = options.expectedVerifierKeyDigestHex {
        guard key.verifierKeyDigest.hexString == expectedVerifierKeyDigestHex else {
            throw CLIError.invalidArgument("regenerated verifier key digest does not match expected verifier key digest")
        }
    }
    guard key.verifierKeyDigest.hexString == artifact.verifierKeyDigestHex else {
        throw CLIError.invalidArgument("artifact verifier key digest does not match regenerated key")
    }
    let statement = CCSStatement(
        shapeDigest: publicInput.shape.shapeDigest,
        ccsInstances: publicInput.instances,
        priorCEInstances: publicInput.priorClaims.map { CEInstance($0) }
    )
    guard statement.statementDigest.hexString == artifact.statementDigestHex else {
        throw CLIError.invalidArgument("artifact statement digest does not match reconstructed public input")
    }
    if let expectedStatementDigestHex = options.expectedStatementDigestHex {
        guard statement.statementDigest.hexString == expectedStatementDigestHex else {
            throw CLIError.invalidArgument("artifact statement digest does not match expected statement digest")
        }
    }
    let verifier = SuperNeoCPUBackend().makeVerifier(key: key)
    if options.requireTerminalProof, !kind.satisfiesTerminalRequirement {
        throw CLIError.invalidArgument("terminal proof required, but artifact contains a fold reduction")
    }
    let context = ProofEnvelopeContext(
        kind: kind.envelopeKind,
        statement: statement,
        verifierKeyDigest: key.verifierKeyDigest
    )
    let started = Date()
    switch kind {
    case .fold:
        let result = verifier.reduceFoldEnvelope(
            publicInput: publicInput,
            proofBytes: proofBytes,
            context: context
        )
        guard result.isReductionAccepted else {
            throw CLIError.invalidArgument("fold reduction rejected: \(result.reason ?? "unknown reason")")
        }
        print("valid fold reduction")
        print("terminal relation check: required")
        print("output CE claims: \(result.outputClaims.count)")
    case .terminal:
        let result = verifier.verifyTerminalFoldEnvelope(
            publicInput: publicInput,
            proofBytes: proofBytes,
            context: context
        )
        guard result.isValid else {
            throw CLIError.invalidArgument("terminal proof rejected: \(result.reason ?? "unknown reason")")
        }
        print("valid terminal proof")
    case .compressedTerminal:
        let result = verifier.verifyCompressedTerminalFoldEnvelope(
            publicInput: publicInput,
            proofBytes: proofBytes,
            context: context
        )
        guard result.isValid else {
            throw CLIError.invalidArgument("compressed terminal proof rejected: \(result.reason ?? "unknown reason")")
        }
        print("valid compressed terminal proof")
    }
    print(String(format: "verify time: %.3f s", Date().timeIntervalSince(started)))
}

private func inspect(path: String) throws {
    switch try readProofArtifact(path: path) {
    case .demo(let artifact):
        try inspectDemoArtifact(artifact)
    case .numiSeal(let artifact):
        try inspectNumiSealArtifact(artifact)
    }
}

private func inspectDemoArtifact(_ artifact: DemoProofArtifact) throws {
    let proofBytes = try artifact.proofEnvelopeBytes()
    let header = try parseEnvelopeHeader(proofBytes)
    print("artifact version: \(artifact.artifactVersion)")
    print("workload: \(artifact.workload)")
    print("profile: \(artifact.profile)")
    print("proof kind: \(artifact.proofKind)")
    print("bit count: \(artifact.bitCount)")
    if let expectedSelectedCount = artifact.expectedSelectedCount {
        print("expected selected count: \(expectedSelectedCount)")
    }
    if let workloadParameters = artifact.workloadParameters, !workloadParameters.isEmpty {
        for key in workloadParameters.keys.sorted() {
            print("\(key): \(workloadParameters[key] ?? "")")
        }
    }
    print("shape digest: \(artifact.shapeDigestHex)")
    print("statement digest: \(artifact.statementDigestHex)")
    print("verifier key digest: \(artifact.verifierKeyDigestHex)")
    print("envelope magic: \(header.magicHex)")
    print("envelope version: \(header.version)")
    print("envelope profile id: \(header.profileID)")
    print("envelope kind raw: \(header.kind)")
    print("envelope transcript domain: \(header.transcriptDomainHex)")
    print("envelope body bytes: \(header.bodyLength)")
    print("envelope total bytes: \(proofBytes.count)")
}

private func verifyNumiSealArtifact(_ artifact: NumiSealVectorArtifact, options: VerifyOptions) throws {
    if options.requireTerminalProof {
        throw CLIError.invalidArgument("legacy terminal proof required, but artifact contains a NumiSeal terminal proof")
    }
    guard options.requireNumiSealProof else {
        throw CLIError.invalidArgument("NumiSeal terminal proof requires --require-numiseal")
    }
    if let expectedPublicInputs = options.expectedPublicInputs {
        guard artifact.publicInputs == expectedPublicInputs else {
            throw CLIError.invalidArgument("artifact public inputs do not match expected public inputs")
        }
    }
    try validateNumiSealArtifactMetadata(artifact)

    let proofBytes = try artifact.proofEnvelopeBytes()
    let parsedEnvelope = try NumiSealProofEnvelope(bytes: proofBytes)
    let keySeed = options.trustedKeySeed ?? artifact.keySeedUTF8
    let material = try makeNumiSealVerificationMaterial(from: artifact, keySeed: keySeed)
    try validateNumiSealMaterial(material, against: artifact)
    try validateNumiSealEnvelope(parsedEnvelope, artifact: artifact)
    try validateNumiSealExpectedContext(artifact: artifact, material: material, options: options)

    let verifier = NumiSealVerifier(
        shape: material.shape,
        key: material.key,
        executionPolicy: .highAssurance
    )
    let started = Date()
    let result = verifier.verify(
        proofBytes: proofBytes,
        obligations: material.obligations,
        policy: material.terminalPolicy,
        aggregationLimits: material.aggregationLimits
    )
    guard result.isValid else {
        throw CLIError.invalidArgument("NumiSeal terminal proof rejected: \(result.reason ?? "unknown reason")")
    }
    guard result.envelope == parsedEnvelope else {
        throw CLIError.invalidArgument("NumiSeal verifier returned a different envelope")
    }
    print("valid NumiSeal terminal proof")
    print("lanes: \(Set(artifact.laneIDsUTF8).count)")
    print("aggregates: \(artifact.aggregateDigestsHex.count)")
    print("residual mode: \(artifact.residualMode)")
    print(String(format: "verify time: %.3f s", Date().timeIntervalSince(started)))
}

private func inspectNumiSealArtifact(_ artifact: NumiSealVectorArtifact) throws {
    try validateNumiSealArtifactMetadata(artifact)
    let proofBytes = try artifact.proofEnvelopeBytes()
    let header = try parseEnvelopeHeader(proofBytes)
    let envelope = try NumiSealProofEnvelope(bytes: proofBytes)
    try validateNumiSealEnvelope(envelope, artifact: artifact)

    print("artifact version: \(artifact.artifactVersion)")
    print("workload: \(artifact.workload)")
    print("profile: \(artifact.profile)")
    print("proof kind: \(artifact.proofKind)")
    print("residual mode: \(artifact.residualMode)")
    print("key columns: \(artifact.keyColumnCount)")
    print("public input count: \(artifact.publicInputCount)")
    print("private witness count: \(artifact.privateWitnessCount)")
    print("lane ids: \(artifact.laneIDsUTF8.joined(separator: ","))")
    print("maximum obligations per aggregate: \(artifact.maximumObligationsPerAggregate)")
    print("maximum lane count: \(artifact.maximumLaneCount)")
    print("maximum aggregates per lane: \(artifact.maximumAggregatesPerLane)")
    print("shape digest: \(artifact.shapeDigestHex)")
    print("statement digest: \(artifact.statementDigestHex)")
    print("verifier key digest: \(artifact.verifierKeyDigestHex)")
    print("transcript domain: \(artifact.transcriptDomainHex)")
    print("public statement digest: \(artifact.publicStatementDigestHex)")
    print("obligation root: \(artifact.obligationRootHex)")
    print("lane summary root: \(artifact.laneSummaryRootHex)")
    print("aggregate count: \(artifact.aggregateDigestsHex.count)")
    for (index, digest) in artifact.aggregateDigestsHex.enumerated() {
        print("aggregate digest \(index): \(digest)")
    }
    print("component digest root: \(artifact.componentDigestRootHex)")
    print("proof transcript digest: \(artifact.proofTranscriptDigestHex)")
    print("parsed lane proof count: \(envelope.proof.laneProofs.count)")
    print("parsed public statement digest: \(envelope.proof.publicStatement.digest.hexString)")
    print("envelope magic: \(header.magicHex)")
    print("envelope version: \(header.version)")
    print("envelope profile id: \(header.profileID)")
    print("envelope kind raw: \(header.kind)")
    print("envelope transcript domain: \(header.transcriptDomainHex)")
    print("envelope body bytes: \(header.bodyLength)")
    print("envelope total bytes: \(proofBytes.count)")
}

private func makePublicInput(from artifact: DemoProofArtifact) throws -> SuperNeoPublicFoldInput {
    guard artifact.artifactVersion == 1 else {
        throw CLIError.invalidArgument("unsupported artifact version")
    }
    guard artifact.profile == SuperNeoParameterProfile.goldilocksPhi81.name else {
        throw CLIError.invalidArgument("unsupported profile: \(artifact.profile)")
    }
    guard artifact.bitCount > 0 else {
        throw CLIError.invalidArgument("artifact bit count must be positive")
    }
    let commitment = try parseCommitment(
        Data(base64Encoded: artifact.commitmentBase64),
        parameters: .goldilocks
    )
    let publicInput: SuperNeoPublicFoldInput
    switch artifact.workload {
    case "one-hot-vector-v1":
        guard artifact.publicInputs == [1] else {
            throw CLIError.invalidArgument("one-hot artifact public inputs must be [1]")
        }
        guard artifact.expectedSelectedCount == 1 else {
            throw CLIError.invalidArgument("one-hot artifact expected selected count must be 1")
        }
        let parameters = try requireWorkloadParameters(
            artifact.workloadParameters,
            allowedKeys: ["selectedCount"],
            workload: "one-hot"
        )
        guard parseCanonicalUInt64Decimal(parameters["selectedCount"] ?? "") == 1 else {
            throw CLIError.invalidArgument("one-hot artifact must include canonical selectedCount parameter")
        }
        let workload = try SuperNeoOneHotVectorWorkload(bitCount: artifact.bitCount)
        publicInput = try workload.publicFoldInput(commitment: commitment)
    case "binary-addition-v1":
        let parameters = try requireWorkloadParameters(
            artifact.workloadParameters,
            allowedKeys: ["leftBitCount", "publicSum"],
            workload: "binary-addition"
        )
        let workload = try SuperNeoBinaryAdditionWorkload(bitCount: artifact.bitCount)
        let publicFields = try parsePublicFields(artifact.publicInputs)
        publicInput = try workload.publicFoldInput(
            commitment: commitment,
            publicInput: publicFields
        )
        guard let leftBitCount = parseCanonicalUInt64Decimal(parameters["leftBitCount"] ?? ""),
              leftBitCount == UInt64(artifact.bitCount) else {
            throw CLIError.invalidArgument("binary-addition artifact must include canonical leftBitCount parameter")
        }
        guard let publicSum = parseCanonicalUInt64Decimal(parameters["publicSum"] ?? "") else {
            throw CLIError.invalidArgument("binary-addition artifact must include canonical publicSum parameter")
        }
        guard try workload.publicInput(sum: publicSum).map(\.rawValue) == artifact.publicInputs else {
            throw CLIError.invalidArgument("binary-addition public sum parameter does not match public input bits")
        }
    default:
        throw CLIError.invalidArgument("unsupported workload: \(artifact.workload)")
    }
    guard publicInput.shape.shapeDigest.hexString == artifact.shapeDigestHex else {
        throw CLIError.invalidArgument("artifact shape digest does not match reconstructed workload")
    }
    return publicInput
}

private func requireWorkloadParameters(
    _ parameters: [String: String]?,
    allowedKeys: Set<String>,
    workload: String
) throws -> [String: String] {
    guard let parameters else {
        throw CLIError.invalidArgument("\(workload) artifact must include workloadParameters")
    }
    let actualKeys = Set(parameters.keys)
    let missingKeys = allowedKeys.subtracting(actualKeys).sorted()
    guard missingKeys.isEmpty else {
        throw CLIError.invalidArgument("\(workload) artifact missing workload parameter(s): \(missingKeys.joined(separator: ","))")
    }
    let unknownKeys = actualKeys.subtracting(allowedKeys).sorted()
    guard unknownKeys.isEmpty else {
        throw CLIError.invalidArgument("\(workload) artifact contains unknown workload parameter(s): \(unknownKeys.joined(separator: ","))")
    }
    return parameters
}

private func validateNumiSealArtifactMetadata(_ artifact: NumiSealVectorArtifact) throws {
    guard artifact.artifactVersion == 1 else {
        throw CLIError.invalidArgument("unsupported NumiSeal artifact version")
    }
    guard artifact.profile == SuperNeoParameterProfile.goldilocksPhi81.name else {
        throw CLIError.invalidArgument("unsupported NumiSeal profile: \(artifact.profile)")
    }
    guard artifact.proofKind == NumiSealArtifactDefaults.proofKind else {
        throw CLIError.invalidArgument("unsupported NumiSeal proof kind: \(artifact.proofKind)")
    }
    guard artifact.residualMode == NumiSealArtifactDefaults.residualMode else {
        throw CLIError.invalidArgument("unsupported NumiSeal residual mode: \(artifact.residualMode)")
    }
    guard artifact.publicInputCount > 0 else {
        throw CLIError.invalidArgument("NumiSeal public input count must be positive")
    }
    guard artifact.privateWitnessCount >= 0 else {
        throw CLIError.invalidArgument("NumiSeal private witness count cannot be negative")
    }
    guard artifact.publicInputs.count == artifact.publicInputCount else {
        throw CLIError.invalidArgument("NumiSeal public input count mismatch")
    }
    _ = try parsePublicFields(artifact.publicInputs)
    guard artifact.keyColumnCount == expectedNumiSealKeyColumnCount(artifact) else {
        throw CLIError.invalidArgument("NumiSeal key column count mismatch")
    }
    guard !artifact.laneIDsUTF8.isEmpty else {
        throw CLIError.invalidArgument("NumiSeal artifact must include at least one lane ID")
    }
    guard artifact.laneIDsUTF8.count == artifact.sourceFoldDigestSeedsUTF8.count else {
        throw CLIError.invalidArgument("NumiSeal lane/source seed count mismatch")
    }
    guard artifact.maximumObligationsPerAggregate > 0 else {
        throw CLIError.invalidArgument("NumiSeal maximum obligations per aggregate must be positive")
    }
    guard artifact.maximumLaneCount > 0 else {
        throw CLIError.invalidArgument("NumiSeal maximum lane count must be positive")
    }
    guard artifact.maximumAggregatesPerLane > 0 else {
        throw CLIError.invalidArgument("NumiSeal maximum aggregates per lane must be positive")
    }
    guard !artifact.aggregateDigestsHex.isEmpty else {
        throw CLIError.invalidArgument("NumiSeal artifact must include aggregate digests")
    }
    guard artifact.ceRandomSeedsUTF8.count == artifact.aggregateDigestsHex.count else {
        throw CLIError.invalidArgument("NumiSeal CE seed count must match aggregate digest count")
    }

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
        _ = try parseHexDigest(digest, name: "NumiSeal \(name)")
    }
    for digest in artifact.aggregateDigestsHex {
        _ = try parseHexDigest(digest, name: "NumiSeal aggregate digest")
    }
}

private func makeNumiSealVerificationMaterial(
    from artifact: NumiSealVectorArtifact,
    keySeed: String
) throws -> NumiSealVerificationMaterial {
    let publicInput = try parsePublicFields(artifact.publicInputs)
    let privateWitness = Array(repeating: GoldilocksField.zero, count: artifact.privateWitnessCount)
    let matrix = try SparseFieldMatrix.identity(size: publicInput.count + privateWitness.count)
    let structure = CCSStructure.hadamardProduct(matrices: [matrix])
    let backend = SuperNeoCPUBackend()
    let key = try AjtaiCommitmentKey(
        columns: artifact.keyColumnCount,
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
    ).foldWithOutput(input, transcriptSeed: Array(artifact.foldTranscriptSeedUTF8.utf8))
    let publicFoldInput = SuperNeoPublicFoldInput(input)
    let statement = CCSStatement(
        shapeDigest: publicFoldInput.shape.shapeDigest,
        ccsInstances: publicFoldInput.instances
    )
    let claims = Array(fold.outputClaims.prefix(artifact.laneIDsUTF8.count))
    guard claims.count == artifact.laneIDsUTF8.count else {
        throw CLIError.invalidArgument("NumiSeal fold did not produce enough output claims")
    }
    let laneIDs = try artifact.laneIDsUTF8.map(NumiSealLaneID.init)
    let obligations = zip(zip(laneIDs, claims), artifact.sourceFoldDigestSeedsUTF8).map { pair, sourceSeed in
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
    let transcriptDomain = try parseDigest256(artifact.transcriptDomainHex, name: "NumiSeal transcript domain")
    let policy = NumiSealAcceptancePolicy(
        statement: statement,
        verifierKeyDigest: key.verifierKeyDigest,
        transcriptDomain: transcriptDomain,
        acceptedLaneIDs: Set(laneIDs)
    )
    let aggregationLimits = try NumiSealAggregationLimits(
        maximumObligationsPerAggregate: artifact.maximumObligationsPerAggregate
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
    let terminalPolicy = NumiSealTerminalProofAcceptancePolicy(
        profileID: policy.profileID,
        shapeDigest: policy.shapeDigest,
        statementDigest: policy.statementDigest,
        verifierKeyDigest: policy.verifierKeyDigest,
        transcriptDomain: policy.transcriptDomain,
        acceptedLaneIDs: policy.acceptedLaneIDs,
        maximumLaneCount: artifact.maximumLaneCount,
        maximumAggregatesPerLane: artifact.maximumAggregatesPerLane,
        acceptedResidualMode: .immediate,
        acceptedCarryMode: .none
    )
    return NumiSealVerificationMaterial(
        shape: input.shape,
        key: key,
        obligations: obligations,
        policy: policy,
        terminalPolicy: terminalPolicy,
        aggregationLimits: aggregationLimits,
        plan: plan
    )
}

private func validateNumiSealMaterial(
    _ material: NumiSealVerificationMaterial,
    against artifact: NumiSealVectorArtifact
) throws {
    guard material.shape.shapeDigest.hexString == artifact.shapeDigestHex else {
        throw CLIError.invalidArgument("NumiSeal artifact shape digest does not match reconstructed material")
    }
    guard material.policy.statementDigest.hexString == artifact.statementDigestHex else {
        throw CLIError.invalidArgument("NumiSeal artifact statement digest does not match reconstructed material")
    }
    guard material.key.verifierKeyDigest.hexString == artifact.verifierKeyDigestHex else {
        throw CLIError.invalidArgument("NumiSeal artifact verifier key digest does not match regenerated key")
    }
    guard material.policy.transcriptDomain.hexString == artifact.transcriptDomainHex else {
        throw CLIError.invalidArgument("NumiSeal artifact transcript domain does not match verification policy")
    }
    guard material.plan.publicStatement.digest.hexString == artifact.publicStatementDigestHex else {
        throw CLIError.invalidArgument("NumiSeal public statement digest does not match reconstructed obligations")
    }
    guard material.plan.publicStatement.obligationRoot.hexString == artifact.obligationRootHex else {
        throw CLIError.invalidArgument("NumiSeal obligation root does not match reconstructed obligations")
    }
    guard material.plan.publicStatement.laneSummaryRoot.hexString == artifact.laneSummaryRootHex else {
        throw CLIError.invalidArgument("NumiSeal lane summary root does not match reconstructed obligations")
    }
    guard material.plan.aggregateDigests.map(\.hexString) == artifact.aggregateDigestsHex else {
        throw CLIError.invalidArgument("NumiSeal aggregate digests do not match reconstructed obligations")
    }
    guard material.plan.aggregateCount == artifact.ceRandomSeedsUTF8.count else {
        throw CLIError.invalidArgument("NumiSeal CE seed count does not match reconstructed aggregate count")
    }
}

private func validateNumiSealEnvelope(
    _ envelope: NumiSealProofEnvelope,
    artifact: NumiSealVectorArtifact
) throws {
    guard envelope.header.kind == .numiSealTerminal else {
        throw CLIError.invalidArgument("NumiSeal proof envelope kind mismatch")
    }
    guard envelope.header.profileID == SuperNeoParameterProfile.goldilocksPhi81.profileID else {
        throw CLIError.invalidArgument("NumiSeal proof envelope profile mismatch")
    }
    guard envelope.header.shapeDigest.hexString == artifact.shapeDigestHex else {
        throw CLIError.invalidArgument("NumiSeal proof envelope shape digest mismatch")
    }
    guard envelope.header.statementDigest.hexString == artifact.statementDigestHex else {
        throw CLIError.invalidArgument("NumiSeal proof envelope statement digest mismatch")
    }
    guard envelope.header.verifierKeyDigest.hexString == artifact.verifierKeyDigestHex else {
        throw CLIError.invalidArgument("NumiSeal proof envelope verifier key digest mismatch")
    }
    guard envelope.header.transcriptDomain.hexString == artifact.transcriptDomainHex else {
        throw CLIError.invalidArgument("NumiSeal proof envelope transcript domain mismatch")
    }
    guard envelope.proof.publicStatement.digest.hexString == artifact.publicStatementDigestHex else {
        throw CLIError.invalidArgument("NumiSeal proof public statement digest mismatch")
    }
    guard envelope.proof.publicStatement.obligationRoot.hexString == artifact.obligationRootHex else {
        throw CLIError.invalidArgument("NumiSeal proof obligation root mismatch")
    }
    guard envelope.proof.publicStatement.laneSummaryRoot.hexString == artifact.laneSummaryRootHex else {
        throw CLIError.invalidArgument("NumiSeal proof lane summary root mismatch")
    }
    guard envelope.proof.laneProofs.map(\.aggregateDigest.hexString) == artifact.aggregateDigestsHex else {
        throw CLIError.invalidArgument("NumiSeal proof aggregate digest mismatch")
    }
    guard envelope.proof.componentDigestRoot.hexString == artifact.componentDigestRootHex else {
        throw CLIError.invalidArgument("NumiSeal proof component digest root mismatch")
    }
    guard envelope.proof.transcriptDigest.hexString == artifact.proofTranscriptDigestHex else {
        throw CLIError.invalidArgument("NumiSeal proof transcript digest mismatch")
    }
}

private func validateNumiSealExpectedContext(
    artifact: NumiSealVectorArtifact,
    material: NumiSealVerificationMaterial,
    options: VerifyOptions
) throws {
    if let expectedShapeDigestHex = options.expectedShapeDigestHex {
        guard material.shape.shapeDigest.hexString == expectedShapeDigestHex else {
            throw CLIError.invalidArgument("NumiSeal shape digest does not match expected shape digest")
        }
    }
    if let expectedStatementDigestHex = options.expectedStatementDigestHex {
        guard material.policy.statementDigest.hexString == expectedStatementDigestHex else {
            throw CLIError.invalidArgument("NumiSeal statement digest does not match expected statement digest")
        }
    }
    if let expectedVerifierKeyDigestHex = options.expectedVerifierKeyDigestHex {
        guard material.key.verifierKeyDigest.hexString == expectedVerifierKeyDigestHex else {
            throw CLIError.invalidArgument("NumiSeal verifier key digest does not match expected verifier key digest")
        }
    }
    if let expectedTranscriptDomainDigestHex = options.expectedTranscriptDomainDigestHex {
        guard material.policy.transcriptDomain.hexString == expectedTranscriptDomainDigestHex else {
            throw CLIError.invalidArgument("NumiSeal transcript domain does not match expected transcript domain")
        }
    }
    if let expectedPublicStatementDigestHex = options.expectedPublicStatementDigestHex {
        guard artifact.publicStatementDigestHex == expectedPublicStatementDigestHex else {
            throw CLIError.invalidArgument("NumiSeal public statement digest does not match expected public statement digest")
        }
    }
    if let expectedObligationRootHex = options.expectedObligationRootHex {
        guard artifact.obligationRootHex == expectedObligationRootHex else {
            throw CLIError.invalidArgument("NumiSeal obligation root does not match expected obligation root")
        }
    }
    if let expectedLaneSummaryRootHex = options.expectedLaneSummaryRootHex {
        guard artifact.laneSummaryRootHex == expectedLaneSummaryRootHex else {
            throw CLIError.invalidArgument("NumiSeal lane summary root does not match expected lane summary root")
        }
    }
    if let expectedAggregateDigestsHex = options.expectedAggregateDigestsHex {
        guard artifact.aggregateDigestsHex == expectedAggregateDigestsHex else {
            throw CLIError.invalidArgument("NumiSeal aggregate digests do not match expected aggregate digests")
        }
    }
    if let expectedComponentDigestRootHex = options.expectedComponentDigestRootHex {
        guard artifact.componentDigestRootHex == expectedComponentDigestRootHex else {
            throw CLIError.invalidArgument("NumiSeal component digest root does not match expected component digest root")
        }
    }
    if let expectedProofTranscriptDigestHex = options.expectedProofTranscriptDigestHex {
        guard artifact.proofTranscriptDigestHex == expectedProofTranscriptDigestHex else {
            throw CLIError.invalidArgument("NumiSeal proof transcript digest does not match expected proof transcript digest")
        }
    }
}

private func expectedNumiSealKeyColumnCount(_ artifact: NumiSealVectorArtifact) -> Int {
    SuperNeoEmbedding.paddedLength(forFieldElementCount: artifact.publicInputCount + artifact.privateWitnessCount)
        / CyclotomicRing54.degree
}

private func readProofArtifact(path: String) throws -> ProofArtifact {
    let data = try Data(contentsOf: URL(fileURLWithPath: path))
    try validateNoDuplicateJSONKeys(data: data)
    let object = try parseTopLevelJSONObject(data)
    guard let proofKind = object["proofKind"] as? String else {
        throw CLIError.invalidArgument("proof artifact must include proofKind")
    }
    if proofKind == NumiSealArtifactDefaults.proofKind {
        try validateKnownArtifactTopLevelKeys(
            object: object,
            allowedKeys: numiSealArtifactTopLevelKeys,
            artifactName: "NumiSeal proof artifact"
        )
        return .numiSeal(try JSONDecoder().decode(NumiSealVectorArtifact.self, from: data))
    }
    try validateKnownArtifactTopLevelKeys(
        object: object,
        allowedKeys: demoProofArtifactTopLevelKeys,
        artifactName: "proof artifact"
    )
    return .demo(try JSONDecoder().decode(DemoProofArtifact.self, from: data))
}

private func validateNoDuplicateJSONKeys(data: Data) throws {
    var scanner = JSONDuplicateKeyScanner(data: data) { path, key in
        throw CLIError.invalidArgument("proof artifact contains duplicate JSON object key '\(key)' at \(path)")
    }
    try scanner.validate()
}

private func parseTopLevelJSONObject(_ data: Data) throws -> [String: Any] {
    let json = try JSONSerialization.jsonObject(with: data)
    guard let object = json as? [String: Any] else {
        throw CLIError.invalidArgument("proof artifact JSON must be an object")
    }
    return object
}

private func validateKnownArtifactTopLevelKeys(
    object: [String: Any],
    allowedKeys: Set<String>,
    artifactName: String
) throws {
    let unknownKeys = Set(object.keys).subtracting(allowedKeys).sorted()
    guard unknownKeys.isEmpty else {
        throw CLIError.invalidArgument("\(artifactName) contains unknown top-level fields: \(unknownKeys.joined(separator: ","))")
    }
}

private struct JSONDuplicateKeyScanner {
    typealias DuplicateHandler = (String, String) throws -> Void

    private let bytes: [UInt8]
    private let onDuplicate: DuplicateHandler
    private var index = 0

    init(data: Data, onDuplicate: @escaping DuplicateHandler) {
        self.bytes = Array(data)
        self.onDuplicate = onDuplicate
    }

    mutating func validate() throws {
        try parseValue(path: "$")
        skipWhitespace()
        guard index == bytes.count else {
            throw CLIError.invalidArgument("proof artifact JSON contains trailing data")
        }
    }

    private mutating func parseValue(path: String) throws {
        skipWhitespace()
        guard let byte = peek() else {
            throw CLIError.invalidArgument("proof artifact JSON ended unexpectedly")
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
            throw CLIError.invalidArgument("proof artifact JSON contains an invalid value at \(path)")
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
                throw CLIError.invalidArgument("proof artifact JSON object key must be a string at \(path)")
            }
            let key = try parseString()
            if !seen.insert(key).inserted {
                try onDuplicate(path, key)
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
                    throw CLIError.invalidArgument("proof artifact JSON string has an unterminated escape")
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
                        throw CLIError.invalidArgument("proof artifact JSON string contains an invalid unicode scalar")
                    }
                    scalars.append(scalar)
                default:
                    throw CLIError.invalidArgument("proof artifact JSON string contains an invalid escape")
                }
            case 0x00...0x1F:
                throw CLIError.invalidArgument("proof artifact JSON string contains an unescaped control character")
            case 0x00...0x7F:
                scalars.append(UnicodeScalar(Int(byte))!)
            default:
                let start = index - 1
                while let next = peek(), next >= 0x80 {
                    index += 1
                }
                guard let value = String(data: Data(bytes[start..<index]), encoding: .utf8) else {
                    throw CLIError.invalidArgument("proof artifact JSON string is not valid UTF-8")
                }
                scalars.append(contentsOf: value.unicodeScalars)
            }
        }
        throw CLIError.invalidArgument("proof artifact JSON string is unterminated")
    }

    private mutating func parseUnicodeEscape() throws -> UInt32 {
        let high = try parseFourHexDigits()
        guard (0xD800...0xDBFF).contains(high) else {
            if (0xDC00...0xDFFF).contains(high) {
                throw CLIError.invalidArgument("proof artifact JSON string contains an unpaired low surrogate")
            }
            return high
        }
        guard consumeIfPresent(UInt8(ascii: "\\")), consumeIfPresent(UInt8(ascii: "u")) else {
            throw CLIError.invalidArgument("proof artifact JSON string contains an unpaired high surrogate")
        }
        let low = try parseFourHexDigits()
        guard (0xDC00...0xDFFF).contains(low) else {
            throw CLIError.invalidArgument("proof artifact JSON string contains an invalid surrogate pair")
        }
        return 0x10000 + ((high - 0xD800) << 10) + (low - 0xDC00)
    }

    private mutating func parseFourHexDigits() throws -> UInt32 {
        var value: UInt32 = 0
        for _ in 0..<4 {
            guard let byte = peek(), let digit = hexValue(byte) else {
                throw CLIError.invalidArgument("proof artifact JSON string contains an invalid unicode escape")
            }
            index += 1
            value = (value << 4) | digit
        }
        return value
    }

    private mutating func consumeNumber() throws {
        if consumeIfPresent(UInt8(ascii: "-")) {
            guard let byte = peek(), (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte) else {
                throw CLIError.invalidArgument("proof artifact JSON number is invalid")
            }
        }
        if consumeIfPresent(UInt8(ascii: "0")) {
            if let byte = peek(), (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte) {
                throw CLIError.invalidArgument("proof artifact JSON number has a leading zero")
            }
        } else {
            guard let byte = peek(), (UInt8(ascii: "1")...UInt8(ascii: "9")).contains(byte) else {
                throw CLIError.invalidArgument("proof artifact JSON number is invalid")
            }
            while isDigit(peek()) {
                index += 1
            }
        }
        if consumeIfPresent(UInt8(ascii: ".")) {
            guard let byte = peek(), (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte) else {
                throw CLIError.invalidArgument("proof artifact JSON fractional number is invalid")
            }
            while isDigit(peek()) {
                index += 1
            }
        }
        if consumeIfPresent(UInt8(ascii: "e")) || consumeIfPresent(UInt8(ascii: "E")) {
            _ = consumeIfPresent(UInt8(ascii: "+")) || consumeIfPresent(UInt8(ascii: "-"))
            guard let byte = peek(), (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte) else {
                throw CLIError.invalidArgument("proof artifact JSON exponent is invalid")
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
            throw CLIError.invalidArgument("proof artifact JSON syntax error")
        }
    }

    private mutating func consumeIfPresent(_ expected: UInt8) -> Bool {
        guard peek() == expected else { return false }
        index += 1
        return true
    }

    private mutating func skipWhitespace() {
        while let byte = peek(), byte == UInt8(ascii: " ") || byte == UInt8(ascii: "\n") || byte == UInt8(ascii: "\r") || byte == UInt8(ascii: "\t") {
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

private func parseBits(_ raw: String) throws -> [Bool] {
    try raw.split(separator: ",", omittingEmptySubsequences: false).map { token in
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        switch trimmed {
        case "0": return false
        case "1": return true
        default: throw CLIError.invalidArgument("--bits must be a comma-separated list of 0 and 1")
        }
    }
}

private func parsePositiveInt(_ raw: String, name: String) throws -> Int {
    guard let value = Int(raw), value > 0 else {
        throw CLIError.invalidArgument("\(name) must be a positive integer")
    }
    return value
}

private func parseUInt64(_ raw: String, name: String) throws -> UInt64 {
    guard let value = UInt64(raw) else {
        throw CLIError.invalidArgument("\(name) must be a non-negative integer")
    }
    return value
}

private func parseCanonicalUInt64Decimal(_ raw: String) -> UInt64? {
    guard raw.range(of: #"^(0|[1-9][0-9]*)$"#, options: .regularExpression) != nil else {
        return nil
    }
    return UInt64(raw)
}

private func parsePublicInputList(_ raw: String, name: String) throws -> [UInt64] {
    let values = try raw.split(separator: ",", omittingEmptySubsequences: false).map { token in
        try parseUInt64(token.trimmingCharacters(in: .whitespacesAndNewlines), name: name)
    }
    guard !values.isEmpty else {
        throw CLIError.invalidArgument("\(name) must contain at least one value")
    }
    return values
}

private func parseHexDigest(_ raw: String, name: String) throws -> String {
    let value = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard value.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil else {
        throw CLIError.invalidArgument("\(name) must be a 64-character lowercase or uppercase hex digest")
    }
    return value
}

private func parseHexDigestList(_ raw: String, name: String) throws -> [String] {
    let values = try raw.split(separator: ",", omittingEmptySubsequences: false).map { token in
        try parseHexDigest(token.trimmingCharacters(in: .whitespacesAndNewlines), name: name)
    }
    guard !values.isEmpty else {
        throw CLIError.invalidArgument("\(name) must contain at least one digest")
    }
    return values
}

private func parseDigest256(_ raw: String, name: String) throws -> Digest256 {
    let hex = try parseHexDigest(raw, name: name)
    var bytes: [UInt8] = []
    bytes.reserveCapacity(Digest256.byteCount)
    var index = hex.startIndex
    while index < hex.endIndex {
        let next = hex.index(index, offsetBy: 2)
        guard let byte = UInt8(hex[index..<next], radix: 16) else {
            throw CLIError.invalidArgument("\(name) must be a valid hex digest")
        }
        bytes.append(byte)
        index = next
    }
    return try Digest256(bytes)
}

private func defaultKeySeed(for options: ProveOptions) throws -> String {
    switch options.workload {
    case .oneHot:
        return try SuperNeoWorkloadKeySeed.oneHotVector(bitCount: options.bits.count)
    case .binaryAdd:
        return try SuperNeoWorkloadKeySeed.binaryAddition(operandBits: options.operandBits)
    }
}

private func parsePublicFields(_ values: [UInt64]) throws -> [GoldilocksField] {
    try values.map { value in
        guard value < GoldilocksField.modulus else {
            throw CLIError.invalidArgument("public input field element is not canonical")
        }
        return GoldilocksField(value)
    }
}

private func checkedSum(_ left: UInt64, _ right: UInt64) throws -> UInt64 {
    let addition = left.addingReportingOverflow(right)
    guard !addition.overflow else {
        throw CLIError.invalidArgument("binary-add operands overflow UInt64")
    }
    return addition.partialValue
}

private func parseCommitment(_ data: Data?, parameters: SuperNeoParameters) throws -> AjtaiCommitment {
    guard let data else {
        throw CLIError.invalidArgument("commitment is not valid base64")
    }
    let ringByteCount = CyclotomicRing54.degree * 8
    let expected = parameters.kappa * ringByteCount
    guard data.count == expected else {
        throw CLIError.invalidArgument("commitment byte length mismatch")
    }
    var elements: [CyclotomicRing54] = []
    elements.reserveCapacity(parameters.kappa)
    let bytes = [UInt8](data)
    for offset in stride(from: 0, to: expected, by: ringByteCount) {
        elements.append(try CyclotomicRing54(littleEndianBytes: Array(bytes[offset..<offset + ringByteCount])))
    }
    return AjtaiCommitment(elements)
}

private struct EnvelopeHeader {
    let magic: UInt32
    let version: UInt16
    let profileID: UInt16
    let kind: UInt8
    let shapeDigestHex: String
    let statementDigestHex: String
    let verifierKeyDigestHex: String
    let transcriptDomainHex: String
    let bodyLength: UInt32

    var magicHex: String {
        "0x" + String(magic, radix: 16, uppercase: true)
    }
}

private func validateArtifactEnvelopeHeader(
    _ header: EnvelopeHeader,
    artifact: DemoProofArtifact,
    kind: DemoProofKind
) throws {
    guard header.profileID == SuperNeoParameterProfile.goldilocksPhi81.profileID else {
        throw CLIError.invalidArgument("proof envelope profile id does not match supported profile")
    }
    guard header.kind == kind.envelopeKind.rawValue else {
        throw CLIError.invalidArgument("artifact proof kind does not match proof envelope kind")
    }
    guard header.shapeDigestHex == artifact.shapeDigestHex else {
        throw CLIError.invalidArgument("artifact shape digest does not match proof envelope header")
    }
    guard header.statementDigestHex == artifact.statementDigestHex else {
        throw CLIError.invalidArgument("artifact statement digest does not match proof envelope header")
    }
    guard header.verifierKeyDigestHex == artifact.verifierKeyDigestHex else {
        throw CLIError.invalidArgument("artifact verifier key digest does not match proof envelope header")
    }
}

private func parseEnvelopeHeader(_ bytes: [UInt8]) throws -> EnvelopeHeader {
    let header = try ProofEnvelopeHeader.parsePrefix(from: bytes)
    try header.validateEnvelopeLength(totalByteCount: bytes.count)
    return EnvelopeHeader(
        magic: header.magic,
        version: header.version,
        profileID: header.profileID,
        kind: header.kind.rawValue,
        shapeDigestHex: header.shapeDigest.hexString,
        statementDigestHex: header.statementDigest.hexString,
        verifierKeyDigestHex: header.verifierKeyDigest.hexString,
        transcriptDomainHex: header.transcriptDomain.hexString,
        bodyLength: header.bodyLength
    )
}

private extension VerifyOptions {
    var hasNumiSealExpectedContext: Bool {
        expectedTranscriptDomainDigestHex != nil
            || expectedPublicStatementDigestHex != nil
            || expectedObligationRootHex != nil
            || expectedLaneSummaryRootHex != nil
            || expectedAggregateDigestsHex != nil
            || expectedComponentDigestRootHex != nil
            || expectedProofTranscriptDigestHex != nil
    }
}

private extension DemoProofArtifact {
    func proofEnvelopeBytes() throws -> [UInt8] {
        guard let data = Data(base64Encoded: proofEnvelopeBase64) else {
            throw CLIError.invalidArgument("proof envelope is not valid base64")
        }
        return [UInt8](data)
    }

    func demoProofKind() throws -> DemoProofKind {
        guard let kind = DemoProofKind(rawValue: proofKind) else {
            throw CLIError.invalidArgument("unsupported proof kind in artifact: \(proofKind)")
        }
        return kind
    }
}

private extension NumiSealVectorArtifact {
    func proofEnvelopeBytes() throws -> [UInt8] {
        guard let data = Data(base64Encoded: proofEnvelopeBase64) else {
            throw CLIError.invalidArgument("NumiSeal proof envelope is not valid base64")
        }
        return [UInt8](data)
    }
}

private extension Digest256 {
    var hexString: String {
        bytes.map { String(format: "%02x", $0) }.joined()
    }
}
