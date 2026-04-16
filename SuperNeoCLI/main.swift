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

private enum ProofArtifact {
    case demo(DemoProofArtifact)
    case numiSeal(NumiSealArtifact)
    case numiSealProduct(NumiSealProductArtifact)
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

private enum ProveSealMode: String {
    case numiSeal = "numiseal"
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
    var sealMode: ProveSealMode?
    var numiSealExecutionPolicy: NumiSealProvingExecutionPolicy = .defaultProduct
    var maximumObligationsPerAggregate: Int?
    var sourceApplicationPath: String?
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
    var operatorProfilePath: String?
    var contextPackPath: String?
    var artifactProvenancePath: String?
    var useProductControls = false
}

private struct ProductControlOptions {
    var operatorProfilePath: String?
    var contextPackPath: String?
}

private struct LoadedProductControls {
    let profile: SuperNeoLocalOperatorProfile
    let context: SuperNeoVerifiedTrustedContextPack
    let replayLedger: SuperNeoSQLiteReplayLedger
    let auditLog: SuperNeoJSONLAuditLog
}

private struct ProductArtifactMaterial {
    let proofKind: SuperNeoProductProofKind
    let workload: String
    let proofEnvelopeBytes: [UInt8]
    let proofEnvelopeDigest: Digest256
    let statementDigest: Digest256
    let verify: () throws -> Void
}

private let productToolVersion = "superneo-cli-product-controls-v1"

private func usage() -> String {
    """
    Usage:
      superneo prove [--workload one-hot] [--bits 0,0,1,0] [--kind fold|terminal|compressed-terminal] [--key-seed text] [--output proof.json]
      superneo prove --seal numiseal [--workload one-hot] [--bits 0,0,1,0] [--numiseal-execution-policy default-product|zk-redundant-metal|zk-metal-accelerated|zk-high-assurance-cpu] [--max-obligations-per-aggregate n] [--output proof.json]
      superneo prove --workload binary-add [--operand-bits 8] [--lhs 13] [--rhs 29] [--kind fold|terminal|compressed-terminal] [--output proof.json]
      superneo verify [--key-seed text] [--expected-verifier-key-digest hex] [--expected-shape-digest hex] [--expected-statement-digest hex] [--expected-public-inputs values] [--require-terminal|--require-numiseal] proof.json
      superneo verify --product --operator-profile profile.json [--context-pack context.json] [--artifact-provenance provenance.json] proof.json
      superneo inspect proof.json
      superneo product-init-storage --operator-profile profile.json
      superneo product-status --operator-profile profile.json [--context-pack context.json]

    Workloads:
      one-hot: proves a committed private bit vector has exactly one selected bit.
      binary-add: proves two committed private integers add to public sum bits.

    The default proof kind is fold. Terminal proofs are complete but currently
    much larger and slower because they include the public CE opening proof.
    compressed-terminal proofs keep terminal acceptance while compressing public
    terminal statement material behind digest bindings.
    NumiSeal product artifacts are emitted with --seal numiseal and require the
    explicit --require-numiseal policy gate during verification. Strict NumiSeal verification also
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
    case "product-init-storage":
        try productInitStorage(parseProductControlOptions(Array(arguments.dropFirst())))
    case "product-status":
        try productStatus(parseProductControlOptions(Array(arguments.dropFirst())))
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
        case "--seal":
            let raw = try requireValue()
            guard let sealMode = ProveSealMode(rawValue: raw) else {
                throw CLIError.invalidArgument("--seal must be numiseal")
            }
            options.sealMode = sealMode
        case "--numiseal-execution-policy", "--zk-policy":
            let raw = try requireValue()
            guard let policy = NumiSealProvingExecutionPolicy(rawValue: raw) else {
                throw CLIError.invalidArgument(
                    "\(argument) must be default-product, zk-redundant-metal, zk-metal-accelerated, or zk-high-assurance-cpu"
                )
            }
            options.numiSealExecutionPolicy = policy
        case "--max-obligations-per-aggregate":
            options.maximumObligationsPerAggregate = try parsePositiveInt(
                try requireValue(),
                name: "--max-obligations-per-aggregate"
            )
        case "--source-app":
            options.sourceApplicationPath = try requireValue()
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
    var operatorProfilePath: String?
    var contextPackPath: String?
    var artifactProvenancePath: String?
    var useProductControls = false
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
        case "--product":
            useProductControls = true
        case "--operator-profile":
            operatorProfilePath = try requireValue()
            useProductControls = true
        case "--context-pack":
            contextPackPath = try requireValue()
            useProductControls = true
        case "--artifact-provenance":
            artifactProvenancePath = try requireValue()
            useProductControls = true
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
        requireNumiSealProof: requireNumiSealProof,
        operatorProfilePath: operatorProfilePath,
        contextPackPath: contextPackPath,
        artifactProvenancePath: artifactProvenancePath,
        useProductControls: useProductControls
    )
}

private func parseProductControlOptions(_ arguments: [String]) throws -> ProductControlOptions {
    var options = ProductControlOptions()
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
        case "--operator-profile":
            options.operatorProfilePath = try requireValue()
        case "--context-pack":
            options.contextPackPath = try requireValue()
        default:
            throw CLIError.invalidArgument("unknown product option: \(argument)")
        }
        index += 1
    }
    guard options.operatorProfilePath != nil else {
        throw CLIError.invalidArgument("--operator-profile is required")
    }
    return options
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
    if options.sealMode == .numiSeal {
        try proveNumiSealProduct(
            options: options,
            prepared: prepared,
            keySeed: keySeed,
            workload: artifactWorkload,
            bitCount: artifactBitCount,
            publicInputs: artifactPublicInputs,
            workloadParameters: artifactParameters,
            started: started
        )
        return
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

private func proveNumiSealProduct(
    options: ProveOptions,
    prepared: SuperNeoPreparedR1CS,
    keySeed: String,
    workload: String,
    bitCount: Int,
    publicInputs: [UInt64],
    workloadParameters: [String: String],
    started: Date
) throws {
    let metalContext = try makeNumiSealMetalContext(policy: options.numiSealExecutionPolicy)
    let aggregationLimits = try NumiSealAggregationLimits(
        maximumObligationsPerAggregate: options.maximumObligationsPerAggregate
            ?? NumiSealAggregationLimits.defaultLimits().maximumObligationsPerAggregate
    )
    let artifact = try NumiSealProductProver().prove(
        NumiSealProvingRequest(
            preparedR1CS: prepared,
            workload: workload,
            bitCount: bitCount,
            publicInputs: publicInputs,
            keySeedUTF8: keySeed,
            workloadParameters: workloadParameters,
            sourceApplicationPathUTF8: options.sourceApplicationPath ?? FileManager.default.currentDirectoryPath,
            laneID: try NumiSealLaneID("product"),
            executionPolicy: options.numiSealExecutionPolicy,
            aggregationLimits: aggregationLimits,
            metalContext: metalContext
        )
    )
    let envelopeBytes = try artifact.proofEnvelopeBytes()
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(artifact)
    try data.write(to: URL(fileURLWithPath: options.outputPath), options: Data.WritingOptions.atomic)
    print("wrote \(options.outputPath)")
    print("workload: \(artifact.workload)")
    print("profile: \(artifact.profile)")
    print("proof kind: \(artifact.proofKind)")
    print("seal mode: \(artifact.sealMode)")
    print("carry mode: \(artifact.carryMode)")
    print("zk mode: \(artifact.zkMode)")
    print("metal mode: \(artifact.metalMode)")
    print("source fold output claims: \(artifact.sourceFoldOutputClaimCount)")
    print("aggregates: \(artifact.aggregateDigestsHex.count)")
    print("proof envelope bytes: \(envelopeBytes.count)")
    print(String(format: "prove time: %.3f s", Date().timeIntervalSince(started)))
}

private func makeNumiSealMetalContext(policy: NumiSealProvingExecutionPolicy) throws -> MetalExecutionContext? {
    switch policy {
    case .zkHighAssuranceCPU:
        return nil
    case .defaultProduct:
        return try? MetalExecutionContext()
    case .zkMetalAccelerated, .zkRedundantMetal:
        do {
            return try MetalExecutionContext()
        } catch {
            throw CLIError.invalidArgument("\(policy.rawValue) requires an available Metal device: \(error)")
        }
    }
}

private func verify(options: VerifyOptions) throws {
    if options.useProductControls {
        try verifyWithProductControls(options: options)
        return
    }
    switch try readProofArtifact(path: options.path) {
    case .demo(let artifact):
        try verifyDemoArtifact(artifact, options: options)
    case .numiSeal(let artifact):
        try verifyNumiSealArtifact(artifact, options: options)
    case .numiSealProduct(let artifact):
        try verifyNumiSealProductArtifact(artifact, options: options)
    }
}

private func verifyWithProductControls(options: VerifyOptions) throws {
    try rejectLegacyVerifierOptionsInProductMode(options)
    let controls = try loadProductControls(
        operatorProfilePath: options.operatorProfilePath,
        contextPackPath: options.contextPackPath
    )
    let context = controls.context.payload
    var artifactDigest: Digest256?
    var proofEnvelopeDigest: Digest256?
    var provenanceDigest: Digest256?
    var proofKind: SuperNeoProductProofKind?
    var statementDigest: Digest256?

    do {
        let artifactData = try Data(contentsOf: URL(fileURLWithPath: options.path))
        artifactDigest = Digest256.hash([UInt8](artifactData))
        guard artifactData.count <= context.maximumArtifactByteCount else {
            throw SuperNeoProductIntegrationError.invalidRequest("artifact byte count exceeds trusted context maximum")
        }
        try context.requireNotRevoked(
            artifactDigest: artifactDigest,
            proofEnvelopeDigest: nil,
            provenanceDigest: nil
        )
        let artifact = try readProofArtifact(data: artifactData)
        let material = try makeProductArtifactMaterial(artifact, context: context)
        proofEnvelopeDigest = material.proofEnvelopeDigest
        proofKind = material.proofKind
        statementDigest = material.statementDigest
        try context.requireNotRevoked(
            artifactDigest: artifactDigest,
            proofEnvelopeDigest: material.proofEnvelopeDigest,
            provenanceDigest: nil
        )

        let provenancePath = try productArtifactProvenancePath(options: options, profile: controls.profile)
        let provenance = try SuperNeoSignedArtifactProvenanceManifest.loadVerified(
            from: URL(fileURLWithPath: provenancePath),
            trustedIssuerKeyDigestsHex: try controls.profile.trustedProvenanceIssuerKeyDigestSet()
        )
        provenanceDigest = provenance.provenanceDigest
        try provenance.validateBinding(
            artifactDigest: artifactDigest!,
            proofEnvelopeDigest: material.proofEnvelopeDigest,
            contextID: context.contextID,
            statementDigest: material.statementDigest,
            releaseBuildDigest: try context.releaseBuildDigest
        )
        try context.requireNotRevoked(
            artifactDigest: artifactDigest,
            proofEnvelopeDigest: material.proofEnvelopeDigest,
            provenanceDigest: provenance.provenanceDigest
        )

        let identity = SuperNeoProductProofIdentity(
            expectedContextID: context.contextID,
            statementDigest: material.statementDigest,
            proofEnvelopeDigest: material.proofEnvelopeDigest,
            artifactDigest: artifactDigest!,
            provenanceDigest: provenance.provenanceDigest
        )
        guard try !controls.replayLedger.hasAccepted(identity) else {
            throw SuperNeoProductIntegrationError.replayDetected("proof identity has already been accepted")
        }

        try material.verify()
        try controls.replayLedger.recordAccepted(identity)
        try appendProductAudit(
            auditLog: controls.auditLog,
            profile: controls.profile,
            context: context,
            decision: "accepted",
            artifactDigest: artifactDigest,
            proofEnvelopeDigest: proofEnvelopeDigest,
            provenanceDigest: provenanceDigest,
            proofKind: proofKind,
            statementDigest: statementDigest,
            error: nil
        )
        print("valid product proof")
        print("context: \(context.contextID)")
        print("proof kind: \(material.proofKind.rawValue)")
        print("artifact digest: \(artifactDigest!.hexString)")
        print("proof envelope digest: \(material.proofEnvelopeDigest.hexString)")
        print("provenance digest: \(provenance.provenanceDigest.hexString)")
    } catch {
        try appendProductAudit(
            auditLog: controls.auditLog,
            profile: controls.profile,
            context: context,
            decision: "rejected",
            artifactDigest: artifactDigest,
            proofEnvelopeDigest: proofEnvelopeDigest,
            provenanceDigest: provenanceDigest,
            proofKind: proofKind,
            statementDigest: statementDigest,
            error: error
        )
        throw error
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
    case .numiSealProduct(let artifact):
        try inspectNumiSealProductArtifact(artifact)
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

private func verifyNumiSealArtifact(_ artifact: NumiSealArtifact, options: VerifyOptions) throws {
    if options.requireTerminalProof {
        throw CLIError.invalidArgument("legacy terminal proof required, but artifact contains a NumiSeal terminal proof")
    }
    guard options.requireNumiSealProof else {
        throw CLIError.invalidArgument("NumiSeal terminal proof requires --require-numiseal")
    }
    let expectedContext = try makeNumiSealExpectedContext(options: options)
    let started = Date()
    _ = try NumiSealArtifactVerifier.verify(
        artifact: artifact,
        expectedContext: expectedContext,
        executionPolicy: .highAssurance
    )
    print("valid NumiSeal terminal proof")
    print("lanes: \(Set(artifact.laneIDsUTF8).count)")
    print("aggregates: \(artifact.aggregateDigestsHex.count)")
    print("residual mode: \(artifact.residualMode)")
    print(String(format: "verify time: %.3f s", Date().timeIntervalSince(started)))
}

private func inspectNumiSealArtifact(_ artifact: NumiSealArtifact) throws {
    try NumiSealArtifactVerifier.validateMetadata(artifact)
    let proofBytes = try artifact.proofEnvelopeBytes()
    let header = try parseEnvelopeHeader(proofBytes)
    let envelope = try NumiSealArtifactVerifier.validatedEnvelope(from: artifact)

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

private func verifyNumiSealProductArtifact(_ artifact: NumiSealProductArtifact, options: VerifyOptions) throws {
    if options.requireTerminalProof {
        throw CLIError.invalidArgument("legacy terminal proof required, but artifact contains a NumiSeal product proof")
    }
    guard options.requireNumiSealProof else {
        throw CLIError.invalidArgument("NumiSeal product proof requires --require-numiseal")
    }
    try validateNumiSealProductExpectedOptions(artifact: artifact, options: options)
    let publicInput = try makePublicInput(from: artifact)
    let keySeed: String
    if let trustedKeySeed = options.trustedKeySeed {
        keySeed = trustedKeySeed
    } else if let artifactKeySeed = artifact.keySeedUTF8 {
        keySeed = artifactKeySeed
    } else {
        throw CLIError.invalidArgument("NumiSeal product verification requires --key-seed when artifact omits keySeedUTF8")
    }
    let key = try AjtaiCommitmentKey(columns: publicInput.shape.nRing, seed: Array(keySeed.utf8))
    let started = Date()
    let result = try NumiSealProductVerifier().verify(
        artifact: artifact,
        sourcePublicInput: publicInput,
        key: key,
        executionPolicy: .highAssurance
    )
    print("valid NumiSeal product proof")
    print("source output CE claims: \(result.sourceFoldResult.outputClaims.count)")
    print("aggregates: \(artifact.aggregateDigestsHex.count)")
    print("seal mode: \(artifact.sealMode)")
    print("carry mode: \(artifact.carryMode)")
    print("zk mode: \(artifact.zkMode)")
    print("metal mode: \(artifact.metalMode)")
    print(String(format: "verify time: %.3f s", Date().timeIntervalSince(started)))
}

private func inspectNumiSealProductArtifact(_ artifact: NumiSealProductArtifact) throws {
    try NumiSealProductVerifier.validateMetadata(artifact)
    let sourceBytes = try artifact.sourceFoldEnvelopeBytes()
    let proofBytes = try artifact.proofEnvelopeBytes()
    let sourceHeader = try parseEnvelopeHeader(sourceBytes)
    let proofHeader = try parseEnvelopeHeader(proofBytes)

    print("artifact version: \(artifact.artifactVersion)")
    print("workload: \(artifact.workload)")
    print("profile: \(artifact.profile)")
    print("proof kind: \(artifact.proofKind)")
    print("seal mode: \(artifact.sealMode)")
    print("carry mode: \(artifact.carryMode)")
    print("zk mode: \(artifact.zkMode)")
    print("metal mode: \(artifact.metalMode)")
    print("execution policy: \(artifact.executionPolicy)")
    print("bit count: \(artifact.bitCount)")
    if let sourceApplicationPath = artifact.sourceApplicationPathUTF8 {
        print("source application path: \(sourceApplicationPath)")
    }
    if !artifact.workloadParameters.isEmpty {
        for key in artifact.workloadParameters.keys.sorted() {
            print("\(key): \(artifact.workloadParameters[key] ?? "")")
        }
    }
    print("public inputs: \(artifact.publicInputs.map(String.init).joined(separator: ","))")
    print("shape digest: \(artifact.shapeDigestHex)")
    print("source statement digest: \(artifact.sourceStatementDigestHex)")
    print("statement digest: \(artifact.statementDigestHex)")
    print("verifier key digest: \(artifact.verifierKeyDigestHex)")
    print("transcript domain: \(artifact.transcriptDomainHex)")
    print("public statement digest: \(artifact.publicStatementDigestHex)")
    print("obligation root: \(artifact.obligationRootHex)")
    print("lane summary root: \(artifact.laneSummaryRootHex)")
    print("lane ids: \(artifact.laneIDsUTF8.joined(separator: ","))")
    print("maximum obligations per aggregate: \(artifact.maximumObligationsPerAggregate)")
    print("maximum lane count: \(artifact.maximumLaneCount)")
    print("maximum aggregates per lane: \(artifact.maximumAggregatesPerLane)")
    print("source fold digest: \(artifact.sourceFoldEnvelopeDigestHex)")
    print("source fold output claim count: \(artifact.sourceFoldOutputClaimCount)")
    for (index, digest) in artifact.sourceFoldOutputClaimDigestsHex.enumerated() {
        print("source output claim digest \(index): \(digest)")
    }
    print("aggregate count: \(artifact.aggregateDigestsHex.count)")
    for (index, digest) in artifact.aggregateDigestsHex.enumerated() {
        print("aggregate digest \(index): \(digest)")
    }
    print("component digest root: \(artifact.componentDigestRootHex)")
    print("proof transcript digest: \(artifact.proofTranscriptDigestHex)")
    print("proof envelope digest: \(artifact.proofEnvelopeDigestHex)")
    print("source envelope kind raw: \(sourceHeader.kind)")
    print("source envelope transcript domain: \(sourceHeader.transcriptDomainHex)")
    print("source envelope body bytes: \(sourceHeader.bodyLength)")
    print("source envelope total bytes: \(sourceBytes.count)")
    print("numiseal envelope kind raw: \(proofHeader.kind)")
    print("numiseal envelope transcript domain: \(proofHeader.transcriptDomainHex)")
    print("numiseal envelope body bytes: \(proofHeader.bodyLength)")
    print("numiseal envelope total bytes: \(proofBytes.count)")
}

private func productInitStorage(_ options: ProductControlOptions) throws {
    guard let operatorProfilePath = options.operatorProfilePath else {
        throw CLIError.invalidArgument("--operator-profile is required")
    }
    let profile = try SuperNeoLocalOperatorProfile.load(from: URL(fileURLWithPath: operatorProfilePath))
    try SuperNeoSQLiteReplayLedger.bootstrap(databaseURL: URL(fileURLWithPath: profile.replayDatabasePath))
    try SuperNeoJSONLAuditLog.bootstrap(url: URL(fileURLWithPath: profile.auditLogPath))
    print("initialized product replay database: \(profile.replayDatabasePath)")
    print("initialized product audit log: \(profile.auditLogPath)")
}

private func productStatus(_ options: ProductControlOptions) throws {
    let controls = try loadProductControls(
        operatorProfilePath: options.operatorProfilePath,
        contextPackPath: options.contextPackPath
    )
    let context = controls.context.payload
    let auditStatus = try controls.auditLog.validateChain()
    print("trusted context: \(context.contextID)")
    print("issuer: \(context.issuer)")
    print("valid from: \(context.validFromUTC)")
    print("valid until: \(context.validUntilUTC)")
    print("accepted proof kinds: \(context.acceptedProofKinds.map(\.rawValue).joined(separator: ","))")
    print("allowed workloads: \(context.allowedWorkloads.joined(separator: ","))")
    print("context payload digest: \(controls.context.payloadDigest.hexString)")
    print("issuer key digest: \(controls.context.issuerKeyDigest.hexString)")
    print("revoked context ids: \(context.revocation.revokedContextIDs.joined(separator: ","))")
    print("revoked artifact digests: \(context.revocation.revokedArtifactDigestHex.count)")
    print("revoked proof envelope digests: \(context.revocation.revokedProofEnvelopeDigestHex.count)")
    print("revoked provenance digests: \(context.revocation.revokedProvenanceDigestHex.count)")
    print("accepted replay count: \(try controls.replayLedger.acceptedReplayCount())")
    print("audit log valid: \(auditStatus.isValid)")
    print("audit log records: \(auditStatus.recordCount)")
    print("audit log last sequence: \(auditStatus.lastSequence)")
    print("audit log last digest: \(auditStatus.lastRecordDigestHex)")
    if let reason = auditStatus.reason {
        print("audit log reason: \(reason)")
    }
}

private func loadProductControls(
    operatorProfilePath: String?,
    contextPackPath: String?
) throws -> LoadedProductControls {
    guard let operatorProfilePath else {
        throw CLIError.invalidArgument("--operator-profile is required for product controls")
    }
    let profile = try SuperNeoLocalOperatorProfile.load(from: URL(fileURLWithPath: operatorProfilePath))
    let contextPath = try productContextPackPath(contextPackPath, profile: profile)
    let context = try SuperNeoSignedTrustedContextPack.loadVerified(
        from: URL(fileURLWithPath: contextPath),
        trustedIssuerKeyDigestsHex: try profile.trustedContextIssuerKeyDigestSet()
    )
    guard context.payload.releaseBuildDigestHex == profile.releaseBuildDigestHex else {
        throw SuperNeoProductIntegrationError.unauthorized("operator profile release build digest does not match trusted context")
    }
    let replayLedger = try SuperNeoSQLiteReplayLedger(
        databaseURL: URL(fileURLWithPath: profile.replayDatabasePath)
    )
    let auditLog = try SuperNeoJSONLAuditLog(url: URL(fileURLWithPath: profile.auditLogPath))
    return LoadedProductControls(
        profile: profile,
        context: context,
        replayLedger: replayLedger,
        auditLog: auditLog
    )
}

private func productContextPackPath(
    _ explicitPath: String?,
    profile: SuperNeoLocalOperatorProfile
) throws -> String {
    if let explicitPath {
        return explicitPath
    }
    if let profilePath = profile.contextPackPath {
        return profilePath
    }
    throw CLIError.invalidArgument("--context-pack is required when operator profile does not include contextPackPath")
}

private func productArtifactProvenancePath(
    options: VerifyOptions,
    profile: SuperNeoLocalOperatorProfile
) throws -> String {
    if let explicitPath = options.artifactProvenancePath {
        return explicitPath
    }
    if let profilePath = profile.artifactProvenancePath {
        return profilePath
    }
    throw CLIError.invalidArgument("--artifact-provenance is required when operator profile does not include artifactProvenancePath")
}

private func rejectLegacyVerifierOptionsInProductMode(_ options: VerifyOptions) throws {
    if options.trustedKeySeed != nil
        || options.expectedVerifierKeyDigestHex != nil
        || options.expectedShapeDigestHex != nil
        || options.expectedStatementDigestHex != nil
        || options.expectedTranscriptDomainDigestHex != nil
        || options.expectedPublicStatementDigestHex != nil
        || options.expectedObligationRootHex != nil
        || options.expectedLaneSummaryRootHex != nil
        || options.expectedAggregateDigestsHex != nil
        || options.expectedComponentDigestRootHex != nil
        || options.expectedProofTranscriptDigestHex != nil
        || options.expectedPublicInputs != nil
        || options.requireTerminalProof
        || options.requireNumiSealProof {
        throw CLIError.invalidArgument("product verification must take expected context only from the signed context pack")
    }
}

private func makeProductArtifactMaterial(
    _ artifact: ProofArtifact,
    context: SuperNeoTrustedContextPayload
) throws -> ProductArtifactMaterial {
    switch artifact {
    case .demo(let artifact):
        return try makeProductDemoArtifactMaterial(artifact, context: context)
    case .numiSeal(let artifact):
        return try makeProductNumiSealArtifactMaterial(artifact, context: context)
    case .numiSealProduct(let artifact):
        return try makeProductNumiSealProductArtifactMaterial(artifact, context: context)
    }
}

private func makeProductDemoArtifactMaterial(
    _ artifact: DemoProofArtifact,
    context: SuperNeoTrustedContextPayload
) throws -> ProductArtifactMaterial {
    let demoKind = try artifact.demoProofKind()
    let productKind = try SuperNeoProductProofKind(envelopeKind: demoKind.envelopeKind)
    guard context.accepts(productKind) else {
        throw SuperNeoProductIntegrationError.missingExpectedContext("trusted context does not accept \(productKind.rawValue)")
    }
    guard context.allowedWorkloads.contains(artifact.workload) else {
        throw SuperNeoProductIntegrationError.missingExpectedContext("artifact workload is not allowed by trusted context")
    }
    if let expectedPublicInputs = context.publicInputs {
        guard artifact.publicInputs == expectedPublicInputs else {
            throw SuperNeoProductIntegrationError.missingExpectedContext("artifact public inputs do not match trusted context")
        }
    }
    let proofBytes = try artifact.proofEnvelopeBytes()
    let header = try ProofEnvelopeHeader.parsePrefix(from: proofBytes)
    let policy = try context.terminalPolicy()
    let envelopeContext = try policy.context(for: header, totalByteCount: proofBytes.count)
    try validateArtifactEnvelopeHeader(try parseEnvelopeHeader(proofBytes), artifact: artifact, kind: demoKind)

    let publicInput = try makePublicInput(from: artifact)
    let expectedShapeDigest = try context.expectedShapeDigest
    let expectedVerifierKeyDigest = try context.expectedVerifierKeyDigest
    let expectedStatementDigest = try context.expectedStatementDigest
    guard publicInput.shape.shapeDigest == expectedShapeDigest else {
        throw SuperNeoProductIntegrationError.missingExpectedContext("artifact shape digest does not match trusted context")
    }
    let keySeed = context.expectedKeySeedUTF8 ?? artifact.keySeedUTF8
    let key = try AjtaiCommitmentKey(columns: publicInput.shape.nRing, seed: Array(keySeed.utf8))
    guard key.verifierKeyDigest == expectedVerifierKeyDigest else {
        throw SuperNeoProductIntegrationError.missingExpectedContext("regenerated verifier key digest does not match trusted context")
    }
    guard key.verifierKeyDigest.hexString == artifact.verifierKeyDigestHex else {
        throw SuperNeoProductIntegrationError.missingExpectedContext("artifact verifier key digest does not match regenerated key")
    }
    let statement = CCSStatement(
        shapeDigest: publicInput.shape.shapeDigest,
        ccsInstances: publicInput.instances,
        priorCEInstances: publicInput.priorClaims.map { CEInstance($0) }
    )
    guard statement.statementDigest == expectedStatementDigest else {
        throw SuperNeoProductIntegrationError.missingExpectedContext("artifact statement digest does not match trusted context")
    }
    let verifier = SuperNeoCPUBackend().makeVerifier(key: key)
    return ProductArtifactMaterial(
        proofKind: productKind,
        workload: artifact.workload,
        proofEnvelopeBytes: proofBytes,
        proofEnvelopeDigest: Digest256.hash(proofBytes),
        statementDigest: statement.statementDigest,
        verify: {
            switch demoKind {
            case .fold:
                throw SuperNeoProductIntegrationError.invalidRequest("fold reductions are not product-accepted proofs")
            case .terminal:
                let result = verifier.verifyTerminalFoldEnvelope(
                    publicInput: publicInput,
                    proofBytes: proofBytes,
                    context: envelopeContext
                )
                guard result.isValid else {
                    throw SuperNeoProductIntegrationError.verificationFailed(
                        "terminal proof rejected: \(result.reason ?? "unknown reason")"
                    )
                }
            case .compressedTerminal:
                let result = verifier.verifyCompressedTerminalFoldEnvelope(
                    publicInput: publicInput,
                    proofBytes: proofBytes,
                    context: envelopeContext
                )
                guard result.isValid else {
                    throw SuperNeoProductIntegrationError.verificationFailed(
                        "compressed terminal proof rejected: \(result.reason ?? "unknown reason")"
                    )
                }
            }
        }
    )
}

private func makeProductNumiSealArtifactMaterial(
    _ artifact: NumiSealArtifact,
    context: SuperNeoTrustedContextPayload
) throws -> ProductArtifactMaterial {
    let productKind = SuperNeoProductProofKind.numiSealTerminal
    guard context.accepts(productKind) else {
        throw SuperNeoProductIntegrationError.missingExpectedContext("trusted context does not accept \(productKind.rawValue)")
    }
    guard context.allowedWorkloads.contains(artifact.workload) else {
        throw SuperNeoProductIntegrationError.missingExpectedContext("artifact workload is not allowed by trusted context")
    }
    let proofBytes = try artifact.proofEnvelopeBytes()
    if let maximumProofEnvelopeByteCount = context.maximumProofEnvelopeByteCount {
        guard proofBytes.count <= maximumProofEnvelopeByteCount else {
            throw SuperNeoProductIntegrationError.invalidRequest("proof envelope byte count exceeds trusted context maximum")
        }
    }
    let header = try ProofEnvelopeHeader.parsePrefix(from: proofBytes)
    try header.validateEnvelopeLength(totalByteCount: proofBytes.count)
    guard header.kind == .numiSealTerminal else {
        throw SuperNeoProductIntegrationError.invalidRequest("NumiSeal product context requires a NumiSeal terminal proof")
    }
    let expectedShapeDigest = try context.expectedShapeDigest
    let expectedStatementDigest = try context.expectedStatementDigest
    let expectedVerifierKeyDigest = try context.expectedVerifierKeyDigest
    let expectedTranscriptDomainDigest = try context.expectedTranscriptDomainDigest
    guard header.shapeDigest == expectedShapeDigest else {
        throw SuperNeoProductIntegrationError.missingExpectedContext("NumiSeal shape digest does not match trusted context")
    }
    guard header.statementDigest == expectedStatementDigest else {
        throw SuperNeoProductIntegrationError.missingExpectedContext("NumiSeal statement digest does not match trusted context")
    }
    guard header.verifierKeyDigest == expectedVerifierKeyDigest else {
        throw SuperNeoProductIntegrationError.missingExpectedContext("NumiSeal verifier key digest does not match trusted context")
    }
    guard header.transcriptDomain == expectedTranscriptDomainDigest else {
        throw SuperNeoProductIntegrationError.missingExpectedContext("NumiSeal transcript domain does not match trusted context")
    }
    let expectedContext = try context.numiSealExpectedContext()
    return ProductArtifactMaterial(
        proofKind: productKind,
        workload: artifact.workload,
        proofEnvelopeBytes: proofBytes,
        proofEnvelopeDigest: Digest256.hash(proofBytes),
        statementDigest: try Digest256(hexDigest: artifact.statementDigestHex, name: "NumiSeal statement digest"),
        verify: {
            _ = try NumiSealArtifactVerifier.verify(
                artifact: artifact,
                expectedContext: expectedContext,
                executionPolicy: .highAssurance
            )
        }
    )
}

private func makeProductNumiSealProductArtifactMaterial(
    _ artifact: NumiSealProductArtifact,
    context: SuperNeoTrustedContextPayload
) throws -> ProductArtifactMaterial {
    let productKind = SuperNeoProductProofKind.numiSealTerminal
    guard context.accepts(productKind) else {
        throw SuperNeoProductIntegrationError.missingExpectedContext("trusted context does not accept \(productKind.rawValue)")
    }
    guard context.allowedWorkloads.contains(artifact.workload) else {
        throw SuperNeoProductIntegrationError.missingExpectedContext("artifact workload is not allowed by trusted context")
    }
    if let expectedPublicInputs = context.publicInputs {
        guard artifact.publicInputs == expectedPublicInputs else {
            throw SuperNeoProductIntegrationError.missingExpectedContext("artifact public inputs do not match trusted context")
        }
    }
    let proofBytes = try artifact.proofEnvelopeBytes()
    if let maximumProofEnvelopeByteCount = context.maximumProofEnvelopeByteCount {
        guard proofBytes.count <= maximumProofEnvelopeByteCount else {
            throw SuperNeoProductIntegrationError.invalidRequest("proof envelope byte count exceeds trusted context maximum")
        }
    }
    let expectedShapeDigest = try context.expectedShapeDigest
    let expectedStatementDigest = try context.expectedStatementDigest
    let expectedVerifierKeyDigest = try context.expectedVerifierKeyDigest
    let expectedTranscriptDomainDigest = try context.expectedTranscriptDomainDigest
    guard artifact.shapeDigestHex == expectedShapeDigest.hexString else {
        throw SuperNeoProductIntegrationError.missingExpectedContext("NumiSeal product shape digest does not match trusted context")
    }
    guard artifact.statementDigestHex == expectedStatementDigest.hexString else {
        throw SuperNeoProductIntegrationError.missingExpectedContext("NumiSeal product statement digest does not match trusted context")
    }
    guard artifact.verifierKeyDigestHex == expectedVerifierKeyDigest.hexString else {
        throw SuperNeoProductIntegrationError.missingExpectedContext("NumiSeal product verifier key digest does not match trusted context")
    }
    guard artifact.transcriptDomainHex == expectedTranscriptDomainDigest.hexString else {
        throw SuperNeoProductIntegrationError.missingExpectedContext("NumiSeal product transcript domain does not match trusted context")
    }
    let publicInput = try makePublicInput(from: artifact)
    let keySeed = context.expectedKeySeedUTF8 ?? artifact.keySeedUTF8
    guard let keySeed else {
        throw SuperNeoProductIntegrationError.missingExpectedContext("NumiSeal product verification requires key seed from context or artifact")
    }
    let key = try AjtaiCommitmentKey(columns: publicInput.shape.nRing, seed: Array(keySeed.utf8))
    guard key.verifierKeyDigest == expectedVerifierKeyDigest else {
        throw SuperNeoProductIntegrationError.missingExpectedContext("regenerated verifier key digest does not match trusted context")
    }
    return ProductArtifactMaterial(
        proofKind: productKind,
        workload: artifact.workload,
        proofEnvelopeBytes: proofBytes,
        proofEnvelopeDigest: Digest256.hash(proofBytes),
        statementDigest: try Digest256(hexDigest: artifact.statementDigestHex, name: "NumiSeal product statement digest"),
        verify: {
            _ = try NumiSealProductVerifier().verify(
                artifact: artifact,
                sourcePublicInput: publicInput,
                key: key,
                executionPolicy: .highAssurance
            )
        }
    )
}

private func appendProductAudit(
    auditLog: SuperNeoJSONLAuditLog,
    profile: SuperNeoLocalOperatorProfile,
    context: SuperNeoTrustedContextPayload,
    decision: String,
    artifactDigest: Digest256?,
    proofEnvelopeDigest: Digest256?,
    provenanceDigest: Digest256?,
    proofKind: SuperNeoProductProofKind?,
    statementDigest: Digest256?,
    error: Error?
) throws {
    try auditLog.append(
        SuperNeoAuditLogEvent(
            decision: decision,
            errorClass: error.map(productErrorClass),
            errorMessage: error.map { String(describing: $0) },
            artifactDigestHex: artifactDigest?.hexString,
            proofEnvelopeDigestHex: proofEnvelopeDigest?.hexString,
            provenanceDigestHex: provenanceDigest?.hexString,
            proofKind: proofKind?.rawValue,
            contextID: context.contextID,
            statementDigestHex: statementDigest?.hexString,
            toolVersion: productToolVersion,
            releaseBuildDigestHex: profile.releaseBuildDigestHex
        )
    )
}

private func productErrorClass(_ error: Error) -> String {
    switch error {
    case let productError as SuperNeoProductIntegrationError:
        switch productError {
        case .invalidRequest: return "invalid_request"
        case .unauthorized: return "unauthorized"
        case .missingExpectedContext: return "missing_expected_context"
        case .provenanceRejected: return "provenance_rejected"
        case .replayDetected: return "replay_detected"
        case .verificationFailed: return "verification_failed"
        }
    case let cliError as CLIError:
        switch cliError {
        case .usage: return "usage"
        case .invalidArgument: return "invalid_argument"
        }
    default:
        return "unexpected_error"
    }
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

private func makePublicInput(from artifact: NumiSealProductArtifact) throws -> SuperNeoPublicFoldInput {
    guard artifact.artifactVersion == NumiSealProductArtifact.artifactVersion else {
        throw CLIError.invalidArgument("unsupported NumiSeal product artifact version")
    }
    guard artifact.profile == SuperNeoParameterProfile.goldilocksPhi81.name else {
        throw CLIError.invalidArgument("unsupported profile: \(artifact.profile)")
    }
    guard artifact.bitCount > 0 else {
        throw CLIError.invalidArgument("NumiSeal product bit count must be positive")
    }
    let commitment = try parseCommitment(
        Data(base64Encoded: artifact.commitmentBase64),
        parameters: .goldilocks
    )
    let publicInput: SuperNeoPublicFoldInput
    switch artifact.workload {
    case "one-hot-vector-v1":
        guard artifact.publicInputs == [1] else {
            throw CLIError.invalidArgument("one-hot NumiSeal product public inputs must be [1]")
        }
        let parameters = try requireWorkloadParameters(
            artifact.workloadParameters,
            allowedKeys: ["selectedCount"],
            workload: "one-hot"
        )
        guard parseCanonicalUInt64Decimal(parameters["selectedCount"] ?? "") == 1 else {
            throw CLIError.invalidArgument("one-hot NumiSeal product must include canonical selectedCount parameter")
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
            throw CLIError.invalidArgument("binary-addition NumiSeal product must include canonical leftBitCount parameter")
        }
        guard let publicSum = parseCanonicalUInt64Decimal(parameters["publicSum"] ?? "") else {
            throw CLIError.invalidArgument("binary-addition NumiSeal product must include canonical publicSum parameter")
        }
        guard try workload.publicInput(sum: publicSum).map(\.rawValue) == artifact.publicInputs else {
            throw CLIError.invalidArgument("binary-addition NumiSeal product public sum parameter does not match public input bits")
        }
    default:
        throw CLIError.invalidArgument("unsupported workload: \(artifact.workload)")
    }
    guard publicInput.shape.shapeDigest.hexString == artifact.shapeDigestHex else {
        throw CLIError.invalidArgument("NumiSeal product shape digest does not match reconstructed workload")
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

private func makeNumiSealExpectedContext(options: VerifyOptions) throws -> NumiSealArtifactExpectedContext {
    try NumiSealArtifactExpectedContext(
        trustedKeySeedUTF8: options.trustedKeySeed,
        verifierKeyDigest: options.expectedVerifierKeyDigestHex.map {
            try parseDigest256($0, name: "--expected-verifier-key-digest")
        },
        shapeDigest: options.expectedShapeDigestHex.map {
            try parseDigest256($0, name: "--expected-shape-digest")
        },
        statementDigest: options.expectedStatementDigestHex.map {
            try parseDigest256($0, name: "--expected-statement-digest")
        },
        transcriptDomainDigest: options.expectedTranscriptDomainDigestHex.map {
            try parseDigest256($0, name: "--expected-transcript-domain-digest")
        },
        publicStatementDigest: options.expectedPublicStatementDigestHex.map {
            try parseDigest256($0, name: "--expected-public-statement-digest")
        },
        obligationRoot: options.expectedObligationRootHex.map {
            try parseDigest256($0, name: "--expected-obligation-root")
        },
        laneSummaryRoot: options.expectedLaneSummaryRootHex.map {
            try parseDigest256($0, name: "--expected-lane-summary-root")
        },
        aggregateDigests: options.expectedAggregateDigestsHex.map { values in
            try values.map {
                try parseDigest256($0, name: "--expected-aggregate-digests")
            }
        },
        componentDigestRoot: options.expectedComponentDigestRootHex.map {
            try parseDigest256($0, name: "--expected-component-digest-root")
        },
        proofTranscriptDigest: options.expectedProofTranscriptDigestHex.map {
            try parseDigest256($0, name: "--expected-proof-transcript-digest")
        },
        publicInputs: options.expectedPublicInputs
    )
}

private func validateNumiSealProductExpectedOptions(
    artifact: NumiSealProductArtifact,
    options: VerifyOptions
) throws {
    if let expectedVerifierKeyDigestHex = options.expectedVerifierKeyDigestHex {
        guard artifact.verifierKeyDigestHex == expectedVerifierKeyDigestHex else {
            throw CLIError.invalidArgument("NumiSeal product verifier key digest does not match expected digest")
        }
    }
    if let expectedShapeDigestHex = options.expectedShapeDigestHex {
        guard artifact.shapeDigestHex == expectedShapeDigestHex else {
            throw CLIError.invalidArgument("NumiSeal product shape digest does not match expected digest")
        }
    }
    if let expectedStatementDigestHex = options.expectedStatementDigestHex {
        guard artifact.statementDigestHex == expectedStatementDigestHex else {
            throw CLIError.invalidArgument("NumiSeal product statement digest does not match expected digest")
        }
    }
    if let expectedTranscriptDomainDigestHex = options.expectedTranscriptDomainDigestHex {
        guard artifact.transcriptDomainHex == expectedTranscriptDomainDigestHex else {
            throw CLIError.invalidArgument("NumiSeal product transcript domain does not match expected digest")
        }
    }
    if let expectedPublicStatementDigestHex = options.expectedPublicStatementDigestHex {
        guard artifact.publicStatementDigestHex == expectedPublicStatementDigestHex else {
            throw CLIError.invalidArgument("NumiSeal product public statement digest does not match expected digest")
        }
    }
    if let expectedObligationRootHex = options.expectedObligationRootHex {
        guard artifact.obligationRootHex == expectedObligationRootHex else {
            throw CLIError.invalidArgument("NumiSeal product obligation root does not match expected digest")
        }
    }
    if let expectedLaneSummaryRootHex = options.expectedLaneSummaryRootHex {
        guard artifact.laneSummaryRootHex == expectedLaneSummaryRootHex else {
            throw CLIError.invalidArgument("NumiSeal product lane summary root does not match expected digest")
        }
    }
    if let expectedAggregateDigestsHex = options.expectedAggregateDigestsHex {
        guard artifact.aggregateDigestsHex == expectedAggregateDigestsHex else {
            throw CLIError.invalidArgument("NumiSeal product aggregate digests do not match expected digests")
        }
    }
    if let expectedComponentDigestRootHex = options.expectedComponentDigestRootHex {
        guard artifact.componentDigestRootHex == expectedComponentDigestRootHex else {
            throw CLIError.invalidArgument("NumiSeal product component root does not match expected digest")
        }
    }
    if let expectedProofTranscriptDigestHex = options.expectedProofTranscriptDigestHex {
        guard artifact.proofTranscriptDigestHex == expectedProofTranscriptDigestHex else {
            throw CLIError.invalidArgument("NumiSeal product transcript digest does not match expected digest")
        }
    }
    if let expectedPublicInputs = options.expectedPublicInputs {
        guard artifact.publicInputs == expectedPublicInputs else {
            throw CLIError.invalidArgument("NumiSeal product public inputs do not match expected public inputs")
        }
    }
}

private func readProofArtifact(path: String) throws -> ProofArtifact {
    let data = try Data(contentsOf: URL(fileURLWithPath: path))
    return try readProofArtifact(data: data)
}

private func readProofArtifact(data: Data) throws -> ProofArtifact {
    try validateNoDuplicateJSONKeys(data: data)
    let object = try parseTopLevelJSONObject(data)
    guard let proofKind = object["proofKind"] as? String else {
        throw CLIError.invalidArgument("proof artifact must include proofKind")
    }
    if proofKind == NumiSealArtifact.proofKind {
        if let artifactVersion = object["artifactVersion"] as? NSNumber,
           artifactVersion.uint32Value == NumiSealProductArtifact.artifactVersion {
            try validateKnownArtifactTopLevelKeys(
                object: object,
                allowedKeys: NumiSealProductArtifact.topLevelKeys,
                artifactName: "NumiSeal product proof artifact"
            )
            return .numiSealProduct(try JSONDecoder().decode(NumiSealProductArtifact.self, from: data))
        }
        try validateKnownArtifactTopLevelKeys(
            object: object,
            allowedKeys: NumiSealArtifact.topLevelKeys,
            artifactName: "NumiSeal proof artifact"
        )
        return .numiSeal(try JSONDecoder().decode(NumiSealArtifact.self, from: data))
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
