import CryptoKit
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
    var decompositionProfile: String?
    var publicInputs: [UInt64]
    var commitmentBase64: String
    var proofEnvelopeBase64: String
    var shapeDigestHex: String
    var statementDigestHex: String
    var verifierKeyDigestHex: String
}

private enum ProofArtifact {
    case demo(DemoProofArtifact)
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
    "decompositionProfile",
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
    var decompositionProfile: SuperNeoDecompositionProfile = .payPerBit
    var sealMode: ProveSealMode?
    var numiSealExecutionPolicy: NumiSealProvingExecutionPolicy = .defaultProduct
    var numiSealZKMode: String = NumiSealZK.maskedDigitTensorMode
    var maximumObligationsPerAggregate: Int?
    var sourceApplicationPath: String?
    var operatorProfilePath: String?
    var qroChallengePackPath: String?
    var trustedQROChallengeIssuerKeyDigestsHex: [String] = []
    var qroSessionID: String?
    var qroPublicCoinHex: String?
    var qroDomainSeparator: String?
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
    var qroChallengePackPath: String?
    var revocationFeedPath: String?
    var sideChannelCertificatePath: String?
    var recursiveCarryParentPath: String?
    var recursiveCarryParentProvenancePath: String?
    var useProductControls = false
    var qroSessionID: String?
    var qroPublicCoinHex: String?
    var qroDomainSeparator: String?
}

private struct ProductControlOptions {
    var operatorProfilePath: String?
    var contextPackPath: String?
    var revocationFeedPath: String?
    var sideChannelCertificatePath: String?
    var outputPath: String?
    var outputFormat: ProductOutputFormat = .text
}

private struct QROIssueOptions {
    var outputPath = "superneo-issued-qro.json"
    var workload: DemoWorkload = .oneHot
    var bits = [false, false, true, false, false, false, false, false]
    var operandBits = 8
    var leftOperand: UInt64 = 13
    var rightOperand: UInt64 = 29
    var keySeed: String?
    var sourceApplicationPath: String?
    var contextID: String?
    var issuer = "SuperNeo QRO Issuer"
    var signingKeyPath: String?
    var qroSessionID: String?
    var qroPublicCoinHex: String?
    var qroDomainSeparator: String?
    var validFromUTC: String?
    var validUntilUTC: String?
}

private let defaultOperatorProfileEnvironmentKey = "SUPERNEO_OPERATOR_PROFILE"
private let defaultOperatorProfileRelativePath = ".superneo/operator-profile.json"

private enum ProductOutputFormat: String {
    case text
    case json
}

private struct LoadedProductControls {
    let profile: SuperNeoLocalOperatorProfile
    let context: SuperNeoVerifiedTrustedContextPack
    let revocationFeed: SuperNeoVerifiedRevocationFeed
    let effectiveRevocation: SuperNeoTrustedContextRevocation
    let sideChannelCertificate: SuperNeoVerifiedNumiSealZKSideChannelCertificate?
    let replayLedger: SuperNeoSQLiteReplayLedger
    let auditLog: SuperNeoJSONLAuditLog
}

private struct ProductArtifactMaterial {
    let proofKind: SuperNeoProductProofKind
    let workload: String
    let carryMode: String?
    let recursiveCarryReplayBinding: NumiSealProductRecursiveCarryReplayBinding?
    let issuedQROChallengeDigest: Digest256?
    let qroChallengeDigest: Digest384?
    let proofEnvelopeBytes: [UInt8]
    let proofEnvelopeDigest: Digest256
    let statementDigest: Digest256
    let verify: () throws -> ProductArtifactVerificationOutput
}

private enum ProductArtifactVerificationOutput {
    case accepted
    case numiSealProduct(NumiSealProductVerificationResult)
}

private struct ProductRecursiveCarryParentResolution {
    let parent: NumiSealProductRecursiveCarryParent
    let acceptedIdentity: SuperNeoProductProofIdentity
    let provenanceDigest: Digest256

    var acceptedReplayDigest: Digest256 {
        acceptedIdentity.localReplayDigest
    }
}

private struct ProductAuditExportDocument: Codable {
    let formatVersion: Int
    let exportedAtUTC: String
    let callerID: String
    let contextID: String
    let contextPayloadDigestHex: String
    let issuerKeyDigestHex: String
    let replayDatabasePath: String
    let acceptedReplayCount: Int
    let auditLogPath: String
    let revocationFeedID: String
    let revocationFeedSequence: UInt64
    let revocationFeedDigestHex: String
    let revocationFeedIssuerKeyDigestHex: String
    let auditLogDigestHex: String
    let auditStatus: SuperNeoAuditLogChainStatus
    let operationsStatus: SuperNeoProductOperationsStatus
    let records: [SuperNeoAuditLogRecord]
}

private let productToolVersion = "superneo-cli-product-controls-v1"

private func usage() -> String {
    """
    Usage:
      superneo prove [--workload one-hot] [--bits 0,0,1,0] [--kind fold|terminal|compressed-terminal] [--decomposition-profile pay-per-bit] [--key-seed text] [--output proof.json]
      superneo prove --seal numiseal (--qro-challenge-pack qro.json --trusted-qro-issuer-key-digest hex | --qro-session-id id --qro-public-coin-hex hex) [--workload one-hot] [--bits 0,0,1,0] [--numiseal-zk-mode masked-digit-tensor-v1|none] [--numiseal-execution-policy default-product|zk-redundant-metal|zk-metal-accelerated|zk-high-assurance-cpu] [--max-obligations-per-aggregate n] [--output proof.json]
      superneo prove --workload binary-add [--operand-bits 8] [--lhs 13] [--rhs 29] [--kind fold|terminal|compressed-terminal] [--decomposition-profile pay-per-bit] [--output proof.json]
      superneo verify [--key-seed text] [--qro-session-id id --qro-public-coin-hex hex] [--expected-verifier-key-digest hex] [--expected-shape-digest hex] [--expected-statement-digest hex] [--expected-public-inputs values] [--require-terminal|--require-numiseal] proof.json
      superneo verify --product --operator-profile profile.json [--context-pack context.json] [--artifact-provenance provenance.json] --qro-challenge-pack qro.json [--revocation-feed revocations.json] [--side-channel-certificate certificate.json] [--recursive-carry-parent parent-proof.json --recursive-carry-parent-provenance parent-provenance.json] proof.json
      superneo inspect proof.json
      superneo product-init-storage --operator-profile profile.json
      superneo product-status --operator-profile profile.json [--context-pack context.json] [--revocation-feed revocations.json] [--side-channel-certificate certificate.json] [--format text|json]
      superneo product-export-audit --operator-profile profile.json [--context-pack context.json] [--revocation-feed revocations.json] [--output audit-export.json]
      superneo product-issue-qro --context-id id --signing-key-file ed25519-private.b64 --valid-until utc [--workload one-hot] [--bits 0,0,1,0] [--qro-session-id id] [--output qro.json]

    Workloads:
      one-hot: proves a committed private bit vector has exactly one selected bit.
      binary-add: proves two committed private integers add to public sum bits.

    The default proof kind is fold. Terminal proofs are complete but currently
    much larger and slower because they include the public CE opening proof.
    compressed-terminal proofs keep terminal acceptance while compressing public
    terminal statement material behind digest bindings.
    NumiSeal product artifacts are emitted with --seal numiseal and verify through
    strict NumiSeal handling by default. --require-numiseal is accepted as a
    compatibility no-op. Strict NumiSeal verification also
    accepts --expected-transcript-domain-digest, --expected-public-statement-digest,
    --expected-obligation-root, --expected-lane-summary-root,
    --expected-aggregate-digests, --expected-component-digest-root, and
    --expected-proof-transcript-digest. Product controls auto-enable for product
    artifacts when SUPERNEO_OPERATOR_PROFILE or .superneo/operator-profile.json
    is present. Product-control verification accepts only NumiSealZK product
    artifacts with signed issued-QRO, provenance, context, and replay-ledger
    material. Side-channel certificates are accepted when supplied and required
    only by stricter trusted contexts. Pass --numiseal-zk-mode none only for
    local/dev non-product verification experiments. For product issuance, prove
    --seal numiseal can take a signed
    --qro-challenge-pack and validates it against --trusted-qro-issuer-key-digest
    or --operator-profile before proving.
    The source fold uses the pay-per-bit decomposition/opening profile. The
    CLI no longer emits fixed-maximum proofs; use library-level diagnostics for
    historical profile comparisons.
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
    case "product-export-audit":
        try productExportAudit(parseProductControlOptions(Array(arguments.dropFirst())))
    case "product-issue-qro":
        try productIssueQRO(parseQROIssueOptions(Array(arguments.dropFirst())))
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
        case "--decomposition-profile":
            let raw = try requireValue()
            guard let profile = SuperNeoDecompositionProfile(canonicalName: raw),
                  profile == .payPerBit else {
                throw CLIError.invalidArgument("--decomposition-profile must be pay-per-bit")
            }
            options.decompositionProfile = profile
        case "--seal":
            let raw = try requireValue()
            guard let sealMode = ProveSealMode(rawValue: raw) else {
                throw CLIError.invalidArgument("--seal must be numiseal")
            }
            options.sealMode = sealMode
        case "--numiseal-execution-policy":
            let raw = try requireValue()
            guard let policy = NumiSealProvingExecutionPolicy(rawValue: raw) else {
                throw CLIError.invalidArgument(
                    "\(argument) must be default-product, zk-redundant-metal, zk-metal-accelerated, or zk-high-assurance-cpu"
                )
            }
            options.numiSealExecutionPolicy = policy
        case "--numiseal-zk-mode":
            let raw = try requireValue()
            guard raw == NumiSealZK.nonZKMode || raw == NumiSealZK.maskedDigitTensorMode else {
                throw CLIError.invalidArgument("\(argument) must be none or masked-digit-tensor-v1")
            }
            options.numiSealZKMode = raw
        case "--max-obligations-per-aggregate":
            options.maximumObligationsPerAggregate = try parsePositiveInt(
                try requireValue(),
                name: "--max-obligations-per-aggregate"
            )
        case "--source-app":
            options.sourceApplicationPath = try requireValue()
        case "--operator-profile":
            options.operatorProfilePath = try requireValue()
        case "--qro-challenge-pack":
            options.qroChallengePackPath = try requireValue()
        case "--trusted-qro-issuer-key-digest":
            options.trustedQROChallengeIssuerKeyDigestsHex.append(
                contentsOf: try parseHexDigestList(
                    try requireValue(),
                    name: "--trusted-qro-issuer-key-digest"
                )
            )
        case "--qro-session-id":
            options.qroSessionID = try requireValue()
        case "--qro-public-coin-hex":
            options.qroPublicCoinHex = try requireValue()
        case "--qro-domain":
            options.qroDomainSeparator = try requireValue()
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
    if options.sealMode == .numiSeal, options.decompositionProfile != .payPerBit {
        throw CLIError.invalidArgument("NumiSeal product proving requires --decomposition-profile pay-per-bit")
    }
    if options.qroChallengePackPath != nil,
       options.qroSessionID != nil || options.qroPublicCoinHex != nil || options.qroDomainSeparator != nil {
        throw CLIError.invalidArgument("--qro-challenge-pack cannot be combined with raw QRO challenge options")
    }
    if options.sealMode == .numiSeal,
       options.qroChallengePackPath != nil,
       options.numiSealZKMode != NumiSealZK.maskedDigitTensorMode {
        throw CLIError.invalidArgument("signed-QRO product proving requires --numiseal-zk-mode masked-digit-tensor-v1")
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
    var qroChallengePackPath: String?
    var revocationFeedPath: String?
    var sideChannelCertificatePath: String?
    var recursiveCarryParentPath: String?
    var recursiveCarryParentProvenancePath: String?
    var useProductControls = false
    var qroSessionID: String?
    var qroPublicCoinHex: String?
    var qroDomainSeparator: String?
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
        case "--qro-challenge-pack":
            qroChallengePackPath = try requireValue()
            useProductControls = true
        case "--revocation-feed":
            revocationFeedPath = try requireValue()
            useProductControls = true
        case "--side-channel-certificate":
            sideChannelCertificatePath = try requireValue()
            useProductControls = true
        case "--recursive-carry-parent":
            recursiveCarryParentPath = try requireValue()
            useProductControls = true
        case "--recursive-carry-parent-provenance":
            recursiveCarryParentProvenancePath = try requireValue()
            useProductControls = true
        case "--qro-session-id":
            qroSessionID = try requireValue()
        case "--qro-public-coin-hex":
            qroPublicCoinHex = try requireValue()
        case "--qro-domain":
            qroDomainSeparator = try requireValue()
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
        qroChallengePackPath: qroChallengePackPath,
        revocationFeedPath: revocationFeedPath,
        sideChannelCertificatePath: sideChannelCertificatePath,
        recursiveCarryParentPath: recursiveCarryParentPath,
        recursiveCarryParentProvenancePath: recursiveCarryParentProvenancePath,
        useProductControls: useProductControls,
        qroSessionID: qroSessionID,
        qroPublicCoinHex: qroPublicCoinHex,
        qroDomainSeparator: qroDomainSeparator
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
        case "--revocation-feed":
            options.revocationFeedPath = try requireValue()
        case "--side-channel-certificate":
            options.sideChannelCertificatePath = try requireValue()
        case "--output", "-o":
            options.outputPath = try requireValue()
        case "--format":
            let rawFormat = try requireValue()
            guard let format = ProductOutputFormat(rawValue: rawFormat) else {
                throw CLIError.invalidArgument("--format must be text or json")
            }
            options.outputFormat = format
        case "--json":
            options.outputFormat = .json
        default:
            throw CLIError.invalidArgument("unknown product option: \(argument)")
        }
        index += 1
    }
    return options
}

private func parseQROIssueOptions(_ arguments: [String]) throws -> QROIssueOptions {
    var options = QROIssueOptions()
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
        case "--source-app":
            options.sourceApplicationPath = try requireValue()
        case "--context-id":
            options.contextID = try requireValue()
        case "--issuer":
            options.issuer = try requireValue()
        case "--signing-key-file":
            options.signingKeyPath = try requireValue()
        case "--qro-session-id":
            options.qroSessionID = try requireValue()
        case "--qro-public-coin-hex":
            options.qroPublicCoinHex = try requireValue()
        case "--qro-domain":
            options.qroDomainSeparator = try requireValue()
        case "--valid-from":
            options.validFromUTC = try requireValue()
        case "--valid-until":
            options.validUntilUTC = try requireValue()
        case "--output", "-o":
            options.outputPath = try requireValue()
        default:
            throw CLIError.invalidArgument("unknown product-issue-qro option: \(argument)")
        }
        index += 1
    }
    guard !options.bits.isEmpty else {
        throw CLIError.invalidArgument("--bits must contain at least one bit")
    }
    guard options.operandBits > 0, options.operandBits <= 62 else {
        throw CLIError.invalidArgument("--operand-bits must be in 1...62")
    }
    guard options.contextID?.isEmpty == false else {
        throw CLIError.invalidArgument("product-issue-qro requires --context-id")
    }
    guard options.signingKeyPath?.isEmpty == false else {
        throw CLIError.invalidArgument("product-issue-qro requires --signing-key-file")
    }
    guard options.validUntilUTC?.isEmpty == false else {
        throw CLIError.invalidArgument("product-issue-qro requires --valid-until")
    }
    return options
}

private func productIssueQRO(_ options: QROIssueOptions) throws {
    let signingKeyPath = try requireOption(options.signingKeyPath, name: "--signing-key-file")
    let contextID = try requireOption(options.contextID, name: "--context-id")
    let validUntilUTC = try requireOption(options.validUntilUTC, name: "--valid-until")
    let signingKey = try loadQROSigningKey(path: signingKeyPath)
    let keySeed = try options.keySeed ?? defaultKeySeed(
        workload: options.workload,
        bitCount: options.bits.count,
        operandBits: options.operandBits
    )
    let prepared: SuperNeoPreparedR1CS
    let workload: String
    let bitCount: Int
    let publicInputs: [UInt64]
    let workloadParameters: [String: String]
    switch options.workload {
    case .oneHot:
        let oneHot = try SuperNeoOneHotVectorWorkload(bitCount: options.bits.count)
        prepared = try oneHot.prepareForFolding(bits: options.bits, keySeed: Array(keySeed.utf8))
        workload = "one-hot-vector-v1"
        bitCount = options.bits.count
        publicInputs = [1]
        workloadParameters = [
            "selectedCount": "\(options.bits.filter { $0 }.count)"
        ]
    case .binaryAdd:
        let binaryAdd = try SuperNeoBinaryAdditionWorkload(bitCount: options.operandBits)
        let sum = try checkedSum(options.leftOperand, options.rightOperand)
        prepared = try binaryAdd.prepareForFolding(
            left: options.leftOperand,
            right: options.rightOperand,
            keySeed: Array(keySeed.utf8)
        )
        workload = "binary-addition-v1"
        bitCount = options.operandBits
        publicInputs = try binaryAdd.publicInput(sum: sum).map(\.rawValue)
        workloadParameters = [
            "leftBitCount": "\(options.operandBits)",
            "publicSum": "\(sum)"
        ]
    }
    let productContext = try NumiSealProductTrustedContext(
        workload: workload,
        bitCount: bitCount,
        publicInputs: publicInputs,
        workloadParameters: workloadParameters,
        sourceApplicationPathUTF8: options.sourceApplicationPath ?? FileManager.default.currentDirectoryPath,
        laneID: .product
    )
    let publicInput = prepared.publicFoldInput
    let statement = CCSStatement(
        shapeDigest: publicInput.shape.shapeDigest,
        ccsInstances: publicInput.instances,
        priorCEInstances: publicInput.priorClaims.map { CEInstance($0) }
    )
    let publicCoin = try options.qroPublicCoinHex.map {
        try parseHexBytes($0, name: "--qro-public-coin-hex")
    } ?? secureRandomBytes(count: Digest256.byteCount)
    let qroChallenge = try SuperNeoQROChallenge(
        domainSeparator: options.qroDomainSeparator ?? SuperNeoQROChallenge.defaultDomainSeparator,
        sessionID: options.qroSessionID ?? "issued-qro-\(UUID().uuidString)",
        verifierPublicCoin: publicCoin,
        transcriptContext: SuperNeoSplitQRO.framedBytes(
            domain: "superneo/cli/numiseal-product/qro-context/v1",
            frames: [productContext.contextDigest.superNeoBytes]
        )
    )
    let issuedAtUTC = options.validFromUTC ?? SuperNeoProductTime.nowUTCString()
    let transcriptDomainDigest = try qroChallenge.transcriptDomainDigest(label: "numiseal-product-terminal")
    let payload = SuperNeoIssuedQROChallengePayload(
        issuer: options.issuer,
        contextID: contextID,
        qroSessionID: qroChallenge.sessionID,
        qroDomainSeparator: qroChallenge.domainSeparator,
        qroVerifierPublicCoinHex: hex(publicCoin),
        frontendContextDigestHex: productContext.contextDigest.hexString,
        expectedVerifierKeyDigestHex: prepared.key.verifierKeyDigest.hexString,
        expectedShapeDigestHex: publicInput.shape.shapeDigest.hexString,
        expectedStatementDigestHex: statement.statementDigest.hexString,
        expectedTranscriptDomainDigestHex: transcriptDomainDigest.hexString,
        expectedPublicInputs: publicInputs,
        qroChallengeDigest384Hex: qroChallenge.challengeDigest.hexString,
        issuedAtUTC: issuedAtUTC,
        validUntilUTC: validUntilUTC
    )
    let pack = SuperNeoSignedQROChallengePack(
        payload: payload,
        signature: try productSignature(for: payload, signingKey: signingKey)
    )
    let issuerKeyDigest = Digest256.hash([UInt8](signingKey.publicKey.rawRepresentation))
    let issueNow = try SuperNeoProductTime.parseUTC(issuedAtUTC, name: "QRO issuedAtUTC")
    _ = try pack.verified(
        trustedIssuerKeyDigestsHex: [issuerKeyDigest.hexString],
        expectedContext: SuperNeoIssuedQROChallengeExpectedContext(
            contextID: contextID,
            validFromUTC: issuedAtUTC,
            validUntilUTC: validUntilUTC,
            frontendContextDigest: productContext.contextDigest,
            expectedVerifierKeyDigestHex: prepared.key.verifierKeyDigest.hexString,
            expectedShapeDigestHex: publicInput.shape.shapeDigest.hexString,
            expectedStatementDigestHex: statement.statementDigest.hexString,
            expectedTranscriptDomainDigestHex: transcriptDomainDigest.hexString,
            expectedPublicInputs: publicInputs
        ),
        now: issueNow
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(pack)
    try data.write(to: URL(fileURLWithPath: options.outputPath), options: Data.WritingOptions.atomic)
    print("wrote \(options.outputPath)")
    print("context id: \(contextID)")
    print("workload: \(workload)")
    print("frontend context digest: \(productContext.contextDigest.hexString)")
    print("statement digest: \(statement.statementDigest.hexString)")
    print("transcript domain digest: \(transcriptDomainDigest.hexString)")
    print("qro challenge digest: \(qroChallenge.challengeDigest.hexString)")
    print("qro issuer key digest: \(issuerKeyDigest.hexString)")
}

private func requireOption(_ value: String?, name: String) throws -> String {
    guard let value, !value.isEmpty else {
        throw CLIError.invalidArgument("product-issue-qro requires \(name)")
    }
    return value
}

private func loadQROSigningKey(path: String) throws -> Curve25519.Signing.PrivateKey {
    let data = try SuperNeoLocalFileSecurity.readSecureRegularFile(
        URL(fileURLWithPath: path),
        description: "QRO signing private key"
    )
    guard let raw = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
          !raw.isEmpty else {
        throw CLIError.invalidArgument("QRO signing private key file must contain base64 or hex raw Ed25519 private key bytes")
    }
    let keyData: Data
    if raw.range(of: "^[0-9a-fA-F]+$", options: .regularExpression) != nil, raw.count % 2 == 0 {
        keyData = Data(try parseHexBytes(raw, name: "QRO signing private key"))
    } else if let decoded = Data(base64Encoded: raw) {
        keyData = decoded
    } else {
        throw CLIError.invalidArgument("QRO signing private key file must contain base64 or hex raw Ed25519 private key bytes")
    }
    do {
        return try Curve25519.Signing.PrivateKey(rawRepresentation: keyData)
    } catch {
        throw CLIError.invalidArgument("QRO signing private key is not a valid raw Ed25519 private key: \(error)")
    }
}

private func productSignature<T: Encodable>(
    for payload: T,
    signingKey: Curve25519.Signing.PrivateKey
) throws -> SuperNeoProductSignature {
    let payloadData = try SuperNeoCanonicalJSON.encode(payload)
    let signature = try signingKey.signature(for: payloadData)
    let publicKey = signingKey.publicKey.rawRepresentation
    return SuperNeoProductSignature(
        publicKeyBase64: publicKey.base64EncodedString(),
        publicKeyDigestHex: Digest256.hash([UInt8](publicKey)).hexString,
        signatureBase64: signature.base64EncodedString()
    )
}

private func secureRandomBytes(count: Int) -> [UInt8] {
    var bytes: [UInt8] = []
    bytes.reserveCapacity(count)
    while bytes.count < count {
        let key = SymmetricKey(size: .bits256)
        bytes.append(contentsOf: key.withUnsafeBytes { Array($0) })
    }
    return Array(bytes.prefix(count))
}

private func hex(_ bytes: [UInt8]) -> String {
    bytes.map { String(format: "%02x", $0) }.joined()
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
    let prover = SuperNeoCPUBackend().makeProver(
        key: prepared.key,
        executionPolicy: .highAssurance,
        decompositionProfile: options.decompositionProfile
    )
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
        decompositionProfile: options.decompositionProfile.canonicalName,
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
    print("decomposition profile: \(options.decompositionProfile.canonicalName)")
    print("bit count: \(artifact.bitCount)")
    print("proof envelope bytes: \(envelopeBytes.count)")
    print("artifact bytes: \(data.count)")
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
    let trustedContext = try NumiSealProductTrustedContext(
        workload: workload,
        bitCount: bitCount,
        publicInputs: publicInputs,
        workloadParameters: workloadParameters,
        sourceApplicationPathUTF8: options.sourceApplicationPath ?? FileManager.default.currentDirectoryPath,
        laneID: .product
    )
    let qroChallenge = try makeProvingQROChallenge(
        options: options,
        prepared: prepared,
        publicInputs: publicInputs,
        frontendContextDigest: trustedContext.contextDigest
    )
    let output = try NumiSealProductAPI.provePreparedR1CS(
        preparedR1CS: prepared,
        trustedContext: trustedContext,
        qroChallenge: qroChallenge,
        keySeedUTF8: keySeed,
        executionPolicy: options.numiSealExecutionPolicy,
        zkMode: options.numiSealZKMode,
        aggregationLimits: aggregationLimits,
        metalContext: metalContext,
        sourceDecompositionProfile: options.decompositionProfile
    )
    let artifact = output.artifact
    let envelopeBytes = try artifact.proofEnvelopeBytes()
    let sourceFoldBytes = try artifact.sourceFoldEnvelopeBytes()
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
    print("source decomposition profile: \(artifact.executionPolicyMetadata["sourceDecompositionProfile"] ?? "missing")")
    print("source fold output claims: \(artifact.sourceFoldOutputClaimCount)")
    print("aggregates: \(artifact.aggregateDigestsHex.count)")
    print("source fold envelope bytes: \(sourceFoldBytes.count)")
    print("proof envelope bytes: \(envelopeBytes.count)")
    print("product artifact bytes: \(data.count)")
    print("proof envelope digest: \(artifact.proofEnvelopeDigestHex)")
    print("frontend context digest: \(output.trustedContext.contextDigest.hexString)")
    print("qro challenge digest: \(qroChallenge.challengeDigest.hexString)")
    print("trace extractor evidence digest: \(output.traceExtractorEvidence.evidenceDigest.hexString)")
    print("qrom evidence digest: \(output.qromEvidence.evidenceDigest.hexString)")
    print(String(format: "prove time: %.3f s", Date().timeIntervalSince(started)))
}

private func makeProvingQROChallenge(
    options: ProveOptions,
    prepared: SuperNeoPreparedR1CS,
    publicInputs: [UInt64],
    frontendContextDigest: Digest256
) throws -> SuperNeoQROChallenge {
    if let qroChallengePackPath = options.qroChallengePackPath {
        let pack = try SuperNeoSignedQROChallengePack.load(from: URL(fileURLWithPath: qroChallengePackPath))
        let publicInput = prepared.publicFoldInput
        let statement = CCSStatement(
            shapeDigest: publicInput.shape.shapeDigest,
            ccsInstances: publicInput.instances,
            priorCEInstances: publicInput.priorClaims.map { CEInstance($0) }
        )
        let expectedContext = SuperNeoIssuedQROChallengeExpectedContext(
            contextID: pack.payload.contextID,
            validFromUTC: pack.payload.issuedAtUTC,
            validUntilUTC: pack.payload.validUntilUTC,
            frontendContextDigest: frontendContextDigest,
            expectedVerifierKeyDigestHex: prepared.key.verifierKeyDigest.hexString,
            expectedShapeDigestHex: publicInput.shape.shapeDigest.hexString,
            expectedStatementDigestHex: statement.statementDigest.hexString,
            expectedTranscriptDomainDigestHex: pack.payload.expectedTranscriptDomainDigestHex,
            expectedPublicInputs: publicInputs
        )
        return try pack.verified(
            trustedIssuerKeyDigestsHex: try trustedQROIssuerDigestsForProving(options),
            expectedContext: expectedContext
        ).qroChallenge
    }
    return try makeNumiSealProductQROChallenge(
        sessionID: options.qroSessionID,
        publicCoinHex: options.qroPublicCoinHex,
        domainSeparator: options.qroDomainSeparator,
        frontendContextDigest: frontendContextDigest
    )
}

private func trustedQROIssuerDigestsForProving(_ options: ProveOptions) throws -> Set<String> {
    var digests = Set(options.trustedQROChallengeIssuerKeyDigestsHex)
    if let operatorProfilePath = options.operatorProfilePath {
        let profile = try SuperNeoLocalOperatorProfile.load(from: URL(fileURLWithPath: operatorProfilePath))
        digests.formUnion(try profile.trustedQROChallengeIssuerKeyDigestSet())
    }
    guard !digests.isEmpty else {
        throw CLIError.invalidArgument(
            "--qro-challenge-pack requires --trusted-qro-issuer-key-digest or --operator-profile"
        )
    }
    return digests
}

private func makeNumiSealMetalContext(policy: NumiSealProvingExecutionPolicy) throws -> MetalExecutionContext? {
    switch policy {
    case .zkHighAssuranceCPU:
        return nil
    case .defaultProduct:
        return nil
    case .zkMetalAccelerated, .zkRedundantMetal:
        do {
            return try MetalExecutionContext()
        } catch {
            throw CLIError.invalidArgument("\(policy.rawValue) requires an available Metal device: \(error)")
        }
    }
}

private func verify(options: VerifyOptions) throws {
    var resolvedOptions = options
    let artifact = try readProofArtifact(path: resolvedOptions.path)
    if try shouldUseProductControls(options: &resolvedOptions, artifact: artifact) {
        try verifyWithProductControls(options: resolvedOptions)
        return
    }
    switch artifact {
    case .demo(let artifact):
        try verifyDemoArtifact(artifact, options: resolvedOptions)
    case .numiSealProduct(let artifact):
        try verifyNumiSealProductArtifact(artifact, options: resolvedOptions)
    }
}

private func shouldUseProductControls(options: inout VerifyOptions, artifact: ProofArtifact) throws -> Bool {
    if options.useProductControls {
        options.operatorProfilePath = try resolvedProductOperatorProfilePath(options.operatorProfilePath)
        return true
    }
    guard case .numiSealProduct = artifact else {
        return false
    }
    guard !options.hasLegacyExpectedContext else {
        return false
    }
    guard let operatorProfilePath = discoveredProductOperatorProfilePath() else {
        return false
    }
    options.operatorProfilePath = operatorProfilePath
    options.useProductControls = true
    return true
}

private func verifyWithProductControls(options: VerifyOptions) throws {
    try rejectLegacyVerifierOptionsInProductMode(options)
    let controls = try loadProductControls(
        operatorProfilePath: options.operatorProfilePath,
        contextPackPath: options.contextPackPath,
        revocationFeedPath: options.revocationFeedPath,
        sideChannelCertificatePath: options.sideChannelCertificatePath
    )
    let context = controls.context.payload
    var artifactDigest: Digest256?
    var proofEnvelopeDigest: Digest256?
    var provenanceDigest: Digest256?
    var proofKind: SuperNeoProductProofKind?
    var statementDigest: Digest256?
    var carryMode: String?
    var recursiveCarryReplayBinding: NumiSealProductRecursiveCarryReplayBinding?
    var recursiveCarryParentResolution: ProductRecursiveCarryParentResolution?
    var issuedQROChallengeDigest: Digest256?
    var qroChallengeDigest: Digest384?

    do {
        let artifactData = try readProofArtifactData(
            path: options.path,
            maximumByteCount: context.maximumArtifactByteCount
        )
        artifactDigest = Digest256.hash([UInt8](artifactData))
        try controls.effectiveRevocation.requireNotRevoked(
            contextID: context.contextID,
            artifactDigest: artifactDigest,
            proofEnvelopeDigest: nil,
            provenanceDigest: nil
        )
        let artifact = try readProofArtifact(data: artifactData)
        if case .numiSealProduct(let productArtifact) = artifact {
            carryMode = productArtifact.carryMode
            recursiveCarryReplayBinding = try? productArtifact.recursiveCarryReplayBinding()
        }
        recursiveCarryParentResolution = try makeProductRecursiveCarryParentIfNeeded(
            artifact: artifact,
            options: options,
            controls: controls
        )
    let material = try makeProductArtifactMaterial(
            artifact,
            context: context,
            profile: controls.profile,
            options: options,
            sideChannelCertificate: controls.sideChannelCertificate,
            recursiveCarryParent: recursiveCarryParentResolution?.parent
        )
        proofEnvelopeDigest = material.proofEnvelopeDigest
        proofKind = material.proofKind
        statementDigest = material.statementDigest
        carryMode = material.carryMode
        recursiveCarryReplayBinding = material.recursiveCarryReplayBinding
        issuedQROChallengeDigest = material.issuedQROChallengeDigest
        qroChallengeDigest = material.qroChallengeDigest
        try controls.effectiveRevocation.requireNotRevoked(
            contextID: context.contextID,
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
        try controls.effectiveRevocation.requireNotRevoked(
            contextID: context.contextID,
            artifactDigest: artifactDigest,
            proofEnvelopeDigest: material.proofEnvelopeDigest,
            provenanceDigest: provenance.provenanceDigest
        )

        let identity = SuperNeoProductProofIdentity(
            expectedContextID: context.contextID,
            statementDigest: material.statementDigest,
            proofEnvelopeDigest: material.proofEnvelopeDigest,
            artifactDigest: artifactDigest!,
            provenanceDigest: provenance.provenanceDigest,
            issuedQROChallengeDigest: material.issuedQROChallengeDigest,
            recursiveCarryReplayBindingDigest: material.recursiveCarryReplayBinding?.bindingDigest
        )
        guard try !controls.replayLedger.hasAccepted(identity) else {
            throw SuperNeoProductIntegrationError.replayDetected("proof identity has already been accepted")
        }

        _ = try material.verify()
        try controls.replayLedger.recordAccepted(identity)
        try appendProductAudit(
            auditLog: controls.auditLog,
            profile: controls.profile,
            context: context,
            decision: "accepted",
            artifactDigest: artifactDigest,
            proofEnvelopeDigest: proofEnvelopeDigest,
            provenanceDigest: provenanceDigest,
            revocationFeedDigest: controls.revocationFeed.feedDigest,
            sideChannelCertificateDigest: controls.sideChannelCertificate?.certificateDigest,
            issuedQROChallengeDigest: material.issuedQROChallengeDigest,
            qroChallengeDigest: material.qroChallengeDigest,
            proofKind: proofKind,
            carryMode: carryMode,
            recursiveCarryReplayBinding: recursiveCarryReplayBinding,
            recursiveCarryParentResolution: recursiveCarryParentResolution,
            statementDigest: statementDigest,
            error: nil
        )
        print("valid product proof")
        print("context: \(context.contextID)")
        print("proof kind: \(material.proofKind.rawValue)")
        if let carryMode = material.carryMode {
            print("carry mode: \(carryMode)")
        }
        if let recursiveCarryReplayBinding = material.recursiveCarryReplayBinding {
            print("recursive carry replay binding digest: \(recursiveCarryReplayBinding.bindingDigest.hexString)")
        }
        if let recursiveCarryParentResolution {
            print("recursive carry parent accepted replay digest: \(recursiveCarryParentResolution.acceptedReplayDigest.hexString)")
            print("recursive carry parent provenance digest: \(recursiveCarryParentResolution.provenanceDigest.hexString)")
        }
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
            revocationFeedDigest: controls.revocationFeed.feedDigest,
            sideChannelCertificateDigest: controls.sideChannelCertificate?.certificateDigest,
            issuedQROChallengeDigest: issuedQROChallengeDigest,
            qroChallengeDigest: qroChallengeDigest,
            proofKind: proofKind,
            carryMode: carryMode,
            recursiveCarryReplayBinding: recursiveCarryReplayBinding,
            recursiveCarryParentResolution: recursiveCarryParentResolution,
            statementDigest: statementDigest,
            error: error
        )
        throw error
    }
}

private func makeProductRecursiveCarryParentIfNeeded(
    artifact: ProofArtifact,
    options: VerifyOptions,
    controls: LoadedProductControls
) throws -> ProductRecursiveCarryParentResolution? {
    let context = controls.context.payload
    guard case .numiSealProduct(let childArtifact) = artifact else {
        guard options.recursiveCarryParentPath == nil,
              options.recursiveCarryParentProvenancePath == nil else {
            throw SuperNeoProductIntegrationError.invalidRequest(
                "recursive carry parent is only valid for NumiSeal product artifacts"
            )
        }
        return nil
    }

    guard let childBinding = try childArtifact.recursiveCarryReplayBinding() else {
        guard options.recursiveCarryParentPath == nil,
              options.recursiveCarryParentProvenancePath == nil else {
            throw SuperNeoProductIntegrationError.invalidRequest(
                "recursive carry parent supplied for a non-recursive NumiSeal product artifact"
            )
        }
        return nil
    }
    guard let parentPath = options.recursiveCarryParentPath else {
        throw SuperNeoProductIntegrationError.missingExpectedContext(
            "typed-required NumiSeal product artifact requires --recursive-carry-parent"
        )
    }
    guard let parentProvenancePath = options.recursiveCarryParentProvenancePath else {
        throw SuperNeoProductIntegrationError.missingExpectedContext(
            "typed-required NumiSeal product artifact requires --recursive-carry-parent-provenance"
        )
    }

    let parentData = try readProofArtifactData(
        path: parentPath,
        maximumByteCount: context.maximumArtifactByteCount
    )
    let parentRawArtifactDigest = Digest256.hash([UInt8](parentData))
    try controls.effectiveRevocation.requireNotRevoked(
        contextID: context.contextID,
        artifactDigest: parentRawArtifactDigest,
        proofEnvelopeDigest: nil,
        provenanceDigest: nil
    )
    let parentArtifactContainer = try readProofArtifact(data: parentData)
    guard case .numiSealProduct(let parentArtifact) = parentArtifactContainer else {
        throw SuperNeoProductIntegrationError.invalidRequest(
            "recursive carry parent must be a NumiSeal product artifact"
        )
    }
    let parentMaterial = try makeProductNumiSealProductArtifactMaterial(
        parentArtifact,
        context: context,
        profile: controls.profile,
        options: options,
        sideChannelCertificate: controls.sideChannelCertificate,
        recursiveCarryParent: nil,
        allowAcceptedRecursiveParentWithoutContext: true
    )
    try controls.effectiveRevocation.requireNotRevoked(
        contextID: context.contextID,
        artifactDigest: parentRawArtifactDigest,
        proofEnvelopeDigest: parentMaterial.proofEnvelopeDigest,
        provenanceDigest: nil
    )
    let parentProvenance = try SuperNeoSignedArtifactProvenanceManifest.loadVerified(
        from: URL(fileURLWithPath: parentProvenancePath),
        trustedIssuerKeyDigestsHex: try controls.profile.trustedProvenanceIssuerKeyDigestSet()
    )
    try parentProvenance.validateBinding(
        artifactDigest: parentRawArtifactDigest,
        proofEnvelopeDigest: parentMaterial.proofEnvelopeDigest,
        contextID: context.contextID,
        statementDigest: parentMaterial.statementDigest,
        releaseBuildDigest: try context.releaseBuildDigest
    )
    try controls.effectiveRevocation.requireNotRevoked(
        contextID: context.contextID,
        artifactDigest: parentRawArtifactDigest,
        proofEnvelopeDigest: parentMaterial.proofEnvelopeDigest,
        provenanceDigest: parentProvenance.provenanceDigest
    )
    let parentIdentity = SuperNeoProductProofIdentity(
        expectedContextID: context.contextID,
        statementDigest: parentMaterial.statementDigest,
        proofEnvelopeDigest: parentMaterial.proofEnvelopeDigest,
        artifactDigest: parentRawArtifactDigest,
        provenanceDigest: parentProvenance.provenanceDigest,
        issuedQROChallengeDigest: parentMaterial.issuedQROChallengeDigest
    )
    guard try controls.replayLedger.hasAccepted(parentIdentity) else {
        throw SuperNeoProductIntegrationError.verificationFailed(
            "recursive carry parent proof identity must be accepted before child verification"
        )
    }
    let parent: NumiSealProductRecursiveCarryParent
    if parentMaterial.recursiveCarryReplayBinding == nil {
        let parentOutput = try parentMaterial.verify()
        guard case .numiSealProduct(let parentResult) = parentOutput else {
            throw SuperNeoProductIntegrationError.verificationFailed(
                "recursive carry parent verification did not produce a NumiSeal product result"
            )
        }
        parent = try NumiSealProductRecursiveCarryParent(
            artifact: parentArtifact,
            verificationResult: parentResult,
            consumerSessionDigest: childBinding.consumerSessionDigest,
            nextRecursionLevel: childBinding.nextRecursionLevel
        )
    } else {
        let parentEnvelope = try NumiSealProductRecursiveCarryParent.acceptedProducerEnvelope(from: parentArtifact)
        parent = try NumiSealProductRecursiveCarryParent(
            acceptedArtifact: parentArtifact,
            acceptedProducerEnvelope: parentEnvelope,
            consumerSessionDigest: childBinding.consumerSessionDigest,
            nextRecursionLevel: childBinding.nextRecursionLevel
        )
    }
    guard parent.parentProductArtifactDigest == childBinding.parentArtifactDigest else {
        throw SuperNeoProductIntegrationError.verificationFailed(
            "recursive carry parent artifact digest does not match child metadata"
        )
    }
    return ProductRecursiveCarryParentResolution(
        parent: parent,
        acceptedIdentity: parentIdentity,
        provenanceDigest: parentProvenance.provenanceDigest
    )
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
    if let decompositionProfile = artifact.decompositionProfile,
       SuperNeoDecompositionProfile(canonicalName: decompositionProfile) == nil {
        throw CLIError.invalidArgument("artifact decomposition profile is not recognized")
    }
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

private func verifyNumiSealProductArtifact(_ artifact: NumiSealProductArtifact, options: VerifyOptions) throws {
    if options.requireTerminalProof {
        throw CLIError.invalidArgument("legacy terminal proof required, but artifact contains a NumiSeal product proof")
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
    let trustedContext = try makeNumiSealProductTrustedContext(from: artifact)
    let qroChallenge = try makeNumiSealProductQROChallenge(
        sessionID: options.qroSessionID,
        publicCoinHex: options.qroPublicCoinHex,
        domainSeparator: options.qroDomainSeparator,
        frontendContextDigest: trustedContext.contextDigest
    )
    let started = Date()
    let result = try NumiSealProductVerifier().verify(
        artifact: artifact,
        sourcePublicInput: publicInput,
        key: key,
        qroChallenge: qroChallenge,
        executionPolicy: .highAssurance
    )
    let sourceBytes = try artifact.sourceFoldEnvelopeBytes()
    let proofBytes = try artifact.proofEnvelopeBytes()
    print("valid NumiSeal product proof")
    print("source output CE claims: \(result.sourceFoldResult.outputClaims.count)")
    print("aggregates: \(artifact.aggregateDigestsHex.count)")
    print("seal mode: \(artifact.sealMode)")
    print("carry mode: \(artifact.carryMode)")
    print("zk mode: \(artifact.zkMode)")
    print("metal mode: \(artifact.metalMode)")
    print("source fold envelope bytes: \(sourceBytes.count)")
    print("proof envelope bytes: \(proofBytes.count)")
    print("qro challenge digest: \(qroChallenge.challengeDigest.hexString)")
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
    if !artifact.executionPolicyMetadata.isEmpty {
        for key in artifact.executionPolicyMetadata.keys.sorted() {
            print("\(key): \(artifact.executionPolicyMetadata[key] ?? "")")
        }
    }
}

private func productInitStorage(_ options: ProductControlOptions) throws {
    let operatorProfilePath = try resolvedProductOperatorProfilePath(options.operatorProfilePath)
    let profile = try SuperNeoLocalOperatorProfile.load(from: URL(fileURLWithPath: operatorProfilePath))
    try SuperNeoSQLiteReplayLedger.bootstrap(databaseURL: URL(fileURLWithPath: profile.replayDatabasePath))
    try SuperNeoJSONLAuditLog.bootstrap(url: URL(fileURLWithPath: profile.auditLogPath))
    print("initialized product replay database: \(profile.replayDatabasePath)")
    print("initialized product audit log: \(profile.auditLogPath)")
}

private func productStatus(_ options: ProductControlOptions) throws {
    let controls = try loadProductControls(
        operatorProfilePath: options.operatorProfilePath,
        contextPackPath: options.contextPackPath,
        revocationFeedPath: options.revocationFeedPath,
        sideChannelCertificatePath: options.sideChannelCertificatePath
    )
    let context = controls.context.payload
    let auditStatus = try controls.auditLog.statusSnapshot()
    let operationsStatus = try makeOperationsStatus(controls: controls, auditStatus: auditStatus)
    if options.outputFormat == .json {
        try writePrettyJSON(operationsStatus, outputPath: options.outputPath)
        return
    }
    print("trusted context: \(context.contextID)")
    print("operations readiness: \(operationsStatus.readiness.rawValue)")
    print("issuer: \(context.issuer)")
    print("valid from: \(context.validFromUTC)")
    print("valid until: \(context.validUntilUTC)")
    print("accepted proof kinds: \(context.acceptedProofKinds.map(\.rawValue).joined(separator: ","))")
    if let numiSealZK = context.numiSealZK {
        print("numiseal zk accepted metal modes: \(numiSealZK.acceptedMetalModes.joined(separator: ","))")
        print("numiseal zk allowed leakage digests: \(numiSealZK.allowedLeakageDigestsHex.joined(separator: ","))")
        print("numiseal zk minimum side-channel level: \(numiSealZK.minimumSideChannelCertificationLevel.rawValue)")
    }
    if let certificate = controls.sideChannelCertificate {
        print("side-channel certificate digest: \(certificate.certificateDigest.hexString)")
        print("side-channel certificate level: \(certificate.payload.certifiedLevel.rawValue)")
        print("side-channel certificate issuer: \(certificate.payload.issuer)")
        print("side-channel certificate valid until: \(certificate.payload.validUntilUTC)")
    } else {
        print("side-channel certificate: none")
    }
    print("allowed workloads: \(context.allowedWorkloads.joined(separator: ","))")
    print("context payload digest: \(controls.context.payloadDigest.hexString)")
    print("issuer key digest: \(controls.context.issuerKeyDigest.hexString)")
    print("revocation feed: \(controls.revocationFeed.payload.feedID)")
    print("revocation feed sequence: \(controls.revocationFeed.payload.sequence)")
    print("revocation feed digest: \(controls.revocationFeed.feedDigest.hexString)")
    print("revocation feed issuer key digest: \(controls.revocationFeed.issuerKeyDigest.hexString)")
    print("revoked context ids: \(controls.effectiveRevocation.revokedContextIDs.joined(separator: ","))")
    print("revoked artifact digests: \(controls.effectiveRevocation.revokedArtifactDigestHex.count)")
    print("revoked proof envelope digests: \(controls.effectiveRevocation.revokedProofEnvelopeDigestHex.count)")
    print("revoked provenance digests: \(controls.effectiveRevocation.revokedProvenanceDigestHex.count)")
    print("accepted replay count: \(operationsStatus.acceptedReplayCount)")
    print("audit log digest: \(operationsStatus.auditLogDigestHex)")
    print("audit log valid: \(auditStatus.chainStatus.isValid)")
    print("audit log records: \(auditStatus.chainStatus.recordCount)")
    print("audit log last sequence: \(auditStatus.chainStatus.lastSequence)")
    print("audit log last digest: \(auditStatus.chainStatus.lastRecordDigestHex)")
    print("audit retention policy: \(operationsStatus.auditRetentionPolicy)")
    print("retry policy: \(operationsStatus.retryPolicy)")
    if let reason = auditStatus.chainStatus.reason {
        print("audit log reason: \(reason)")
    }
    for check in operationsStatus.checks {
        print("check \(check.id): \(check.status.rawValue) - \(check.detail)")
        if let remediation = check.remediation {
            print("check \(check.id) remediation: \(remediation)")
        }
    }
}

private func productExportAudit(_ options: ProductControlOptions) throws {
    let controls = try loadProductControls(
        operatorProfilePath: options.operatorProfilePath,
        contextPackPath: options.contextPackPath,
        revocationFeedPath: options.revocationFeedPath,
        sideChannelCertificatePath: options.sideChannelCertificatePath
    )
    let snapshot = try controls.auditLog.exportSnapshot()
    let operationsStatus = try makeOperationsStatus(
        controls: controls,
        auditStatus: SuperNeoAuditLogStatusSnapshot(
            auditLogDigestHex: snapshot.auditLogDigestHex,
            chainStatus: snapshot.chainStatus
        )
    )
    let document = ProductAuditExportDocument(
        formatVersion: 1,
        exportedAtUTC: snapshot.exportedAtUTC,
        callerID: controls.profile.callerID,
        contextID: controls.context.payload.contextID,
        contextPayloadDigestHex: controls.context.payloadDigest.hexString,
        issuerKeyDigestHex: controls.context.issuerKeyDigest.hexString,
        replayDatabasePath: controls.profile.replayDatabasePath,
        acceptedReplayCount: try controls.replayLedger.acceptedReplayCount(),
        auditLogPath: controls.profile.auditLogPath,
        revocationFeedID: controls.revocationFeed.payload.feedID,
        revocationFeedSequence: controls.revocationFeed.payload.sequence,
        revocationFeedDigestHex: controls.revocationFeed.feedDigest.hexString,
        revocationFeedIssuerKeyDigestHex: controls.revocationFeed.issuerKeyDigest.hexString,
        auditLogDigestHex: snapshot.auditLogDigestHex,
        auditStatus: snapshot.chainStatus,
        operationsStatus: operationsStatus,
        records: snapshot.records
    )
    try writePrettyJSON(document, outputPath: options.outputPath)
    if let outputPath = options.outputPath {
        print("wrote product audit export: \(outputPath)")
    }
}

private func makeOperationsStatus(
    controls: LoadedProductControls,
    auditStatus: SuperNeoAuditLogStatusSnapshot
) throws -> SuperNeoProductOperationsStatus {
    try SuperNeoProductOperationsStatus.make(
        profile: controls.profile,
        context: controls.context,
        revocationFeed: controls.revocationFeed,
        effectiveRevocation: controls.effectiveRevocation,
        sideChannelCertificate: controls.sideChannelCertificate,
        acceptedReplayCount: try controls.replayLedger.acceptedReplayCount(),
        auditStatus: auditStatus
    )
}

private func writePrettyJSON<T: Encodable>(_ value: T, outputPath: String?) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(value)
    if let outputPath {
        try data.write(to: URL(fileURLWithPath: outputPath), options: Data.WritingOptions.atomic)
    } else {
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data([UInt8(ascii: "\n")]))
    }
}

private func resolvedProductOperatorProfilePath(_ explicitPath: String?) throws -> String {
    if let explicitPath {
        return explicitPath
    }
    if let discoveredPath = discoveredProductOperatorProfilePath() {
        return discoveredPath
    }
    throw CLIError.invalidArgument(
        "--operator-profile is required unless \(defaultOperatorProfileEnvironmentKey) or \(defaultOperatorProfileRelativePath) is present"
    )
}

private func discoveredProductOperatorProfilePath() -> String? {
    if let environmentPath = ProcessInfo.processInfo.environment[defaultOperatorProfileEnvironmentKey],
       !environmentPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return environmentPath
    }
    let candidate = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent(defaultOperatorProfileRelativePath)
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: candidate.path, isDirectory: &isDirectory),
          !isDirectory.boolValue else {
        return nil
    }
    return candidate.path
}

private func loadProductControls(
    operatorProfilePath: String?,
    contextPackPath: String?,
    revocationFeedPath: String?,
    sideChannelCertificatePath: String?
) throws -> LoadedProductControls {
    let operatorProfilePath = try resolvedProductOperatorProfilePath(operatorProfilePath)
    let profile = try SuperNeoLocalOperatorProfile.load(from: URL(fileURLWithPath: operatorProfilePath))
    let contextPath = try productContextPackPath(contextPackPath, profile: profile)
    let context = try SuperNeoSignedTrustedContextPack.loadVerified(
        from: URL(fileURLWithPath: contextPath),
        trustedIssuerKeyDigestsHex: try profile.trustedContextIssuerKeyDigestSet()
    )
    guard context.payload.releaseBuildDigestHex == profile.releaseBuildDigestHex else {
        throw SuperNeoProductIntegrationError.unauthorized("operator profile release build digest does not match trusted context")
    }
    let revocationPath = try productRevocationFeedPath(revocationFeedPath, profile: profile)
    let revocationFeed = try SuperNeoSignedRevocationFeed.loadVerified(
        from: URL(fileURLWithPath: revocationPath),
        trustedIssuerKeyDigestsHex: try profile.trustedRevocationIssuerKeyDigestSet(),
        context: context.payload
    )
    let effectiveRevocation = context.payload.revocation.merged(with: revocationFeed.payload.revocation)
    let certificatePath = sideChannelCertificatePath ?? profile.sideChannelCertificatePath
    let sideChannelCertificate = try certificatePath.map {
        try SuperNeoSignedNumiSealZKSideChannelCertificate.loadVerified(
            from: URL(fileURLWithPath: $0),
            trustedIssuerKeyDigestsHex: try profile.trustedSideChannelIssuerKeyDigestSet()
        )
    }
    let replayLedger = try SuperNeoSQLiteReplayLedger(
        databaseURL: URL(fileURLWithPath: profile.replayDatabasePath)
    )
    let auditLog = try SuperNeoJSONLAuditLog(url: URL(fileURLWithPath: profile.auditLogPath))
    return LoadedProductControls(
        profile: profile,
        context: context,
        revocationFeed: revocationFeed,
        effectiveRevocation: effectiveRevocation,
        sideChannelCertificate: sideChannelCertificate,
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

private func productRevocationFeedPath(
    _ explicitPath: String?,
    profile: SuperNeoLocalOperatorProfile
) throws -> String {
    explicitPath ?? profile.revocationFeedPath
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

private func productQROChallengePackPath(
    options: VerifyOptions,
    profile: SuperNeoLocalOperatorProfile
) throws -> String {
    if let explicitPath = options.qroChallengePackPath {
        return explicitPath
    }
    if let profilePath = profile.qroChallengePackPath {
        return profilePath
    }
    throw CLIError.invalidArgument(
        "NumiSeal product-control verification requires --qro-challenge-pack or operator-profile qroChallengePackPath"
    )
}

private func loadProductQROChallengePack(
    options: VerifyOptions,
    profile: SuperNeoLocalOperatorProfile,
    context: SuperNeoTrustedContextPayload,
    frontendContextDigest: Digest256
) throws -> SuperNeoVerifiedQROChallengePack {
    let path = try productQROChallengePackPath(options: options, profile: profile)
    guard options.qroSessionID == nil,
          options.qroPublicCoinHex == nil,
          options.qroDomainSeparator == nil else {
        throw CLIError.invalidArgument("product-control verification rejects raw QRO challenge options; use a signed --qro-challenge-pack")
    }
    return try SuperNeoSignedQROChallengePack.loadVerified(
        from: URL(fileURLWithPath: path),
        trustedIssuerKeyDigestsHex: try profile.trustedQROChallengeIssuerKeyDigestSet(),
        context: context,
        frontendContextDigest: frontendContextDigest
    )
}

private func rejectLegacyVerifierOptionsInProductMode(_ options: VerifyOptions) throws {
    if options.hasLegacyExpectedContext || options.requireTerminalProof {
        throw CLIError.invalidArgument("product verification must take expected context only from the signed context pack")
    }
    if options.qroSessionID != nil || options.qroPublicCoinHex != nil || options.qroDomainSeparator != nil {
        throw CLIError.invalidArgument("product verification must take QRO public coins only from a signed --qro-challenge-pack")
    }
}

private func makeProductArtifactMaterial(
    _ artifact: ProofArtifact,
    context: SuperNeoTrustedContextPayload,
    profile: SuperNeoLocalOperatorProfile,
    options: VerifyOptions,
    sideChannelCertificate: SuperNeoVerifiedNumiSealZKSideChannelCertificate?,
    recursiveCarryParent: NumiSealProductRecursiveCarryParent?
) throws -> ProductArtifactMaterial {
    switch artifact {
    case .demo:
        guard recursiveCarryParent == nil else {
            throw SuperNeoProductIntegrationError.invalidRequest(
                "recursive carry parent is only valid for typed-required NumiSeal product artifacts"
            )
        }
        throw SuperNeoProductIntegrationError.invalidRequest(
            "product verification accepts only NumiSealZK product artifacts"
        )
    case .numiSealProduct(let artifact):
        return try makeProductNumiSealProductArtifactMaterial(
            artifact,
            context: context,
            profile: profile,
            options: options,
            sideChannelCertificate: sideChannelCertificate,
            recursiveCarryParent: recursiveCarryParent
        )
    }
}

private func makeProductNumiSealProductArtifactMaterial(
    _ artifact: NumiSealProductArtifact,
    context: SuperNeoTrustedContextPayload,
    profile: SuperNeoLocalOperatorProfile,
    options: VerifyOptions,
    sideChannelCertificate: SuperNeoVerifiedNumiSealZKSideChannelCertificate?,
    recursiveCarryParent: NumiSealProductRecursiveCarryParent?,
    allowAcceptedRecursiveParentWithoutContext: Bool = false
) throws -> ProductArtifactMaterial {
    let productKind: SuperNeoProductProofKind
    let expectedEnvelopeKind: ProofEnvelopeKind
    switch artifact.proofKind {
    case NumiSealProductArtifact.proofKind:
        productKind = .numiSealTerminal
        expectedEnvelopeKind = .numiSealTerminal
    case NumiSealProductArtifact.zkProofKind:
        productKind = .numiSealZK
        expectedEnvelopeKind = .numiSealZK
    default:
        throw SuperNeoProductIntegrationError.invalidRequest("unsupported NumiSeal product proof kind")
    }
    guard productKind == .numiSealZK else {
        throw SuperNeoProductIntegrationError.invalidRequest(
            "product-control verification requires NumiSealZK product artifacts"
        )
    }
    guard context.accepts(productKind) else {
        throw SuperNeoProductIntegrationError.missingExpectedContext("trusted context does not accept \(productKind.rawValue)")
    }
    if productKind == .numiSealZK {
        guard let zkPolicy = context.numiSealZK else {
            throw SuperNeoProductIntegrationError.missingExpectedContext(
                "trusted context does not include NumiSealZK policy"
            )
        }
        try zkPolicy.validate(
            artifact: artifact,
            contextID: context.contextID,
            releaseBuildDigest: try context.releaseBuildDigest,
            certificate: sideChannelCertificate
        )
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
    _ = try ProofEnvelopeCTCOVerifier.verify(envelopeBytes: artifact.sourceFoldEnvelopeBytes())
    _ = try ProofEnvelopeCTCOVerifier.verify(envelopeBytes: proofBytes)
    if let maximumProofEnvelopeByteCount = context.maximumProofEnvelopeByteCount {
        guard proofBytes.count <= maximumProofEnvelopeByteCount else {
            throw SuperNeoProductIntegrationError.invalidRequest("proof envelope byte count exceeds trusted context maximum")
        }
    }
    let header = try ProofEnvelopeHeader.parsePrefix(from: proofBytes)
    try header.validateEnvelopeLength(totalByteCount: proofBytes.count)
    guard header.kind == expectedEnvelopeKind else {
        throw SuperNeoProductIntegrationError.invalidRequest(
            "NumiSeal product artifact expected \(expectedEnvelopeKind) envelope, got \(header.kind)"
        )
    }
    let expectedShapeDigest = try context.expectedShapeDigest
    let expectedStatementDigest = try context.expectedStatementDigest
    let expectedVerifierKeyDigest = try context.expectedVerifierKeyDigest
    let expectedTranscriptDomainDigest = try context.expectedTranscriptDomainDigest
    let expectedContext = ProofEnvelopeContext(
        profileID: SuperNeoParameterProfile.goldilocksPhi81.profileID,
        kind: expectedEnvelopeKind,
        shapeDigest: expectedShapeDigest,
        statementDigest: expectedStatementDigest,
        verifierKeyDigest: expectedVerifierKeyDigest,
        transcriptDomain: expectedTranscriptDomainDigest
    )
    guard header.ctcoContextBinder == expectedContext.ctcoContextBinder else {
        throw SuperNeoProductIntegrationError.missingExpectedContext(
            "NumiSeal product CTCO context binder does not match trusted context"
        )
    }
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
    try validateNumiSealProductArtifactPins(
        artifact: artifact,
        expectedPolicy: try context.requiredNumiSealPolicy()
    )
    let publicInput = try makePublicInput(from: artifact)
    guard let keySeed = context.expectedKeySeedUTF8, !keySeed.isEmpty else {
        throw SuperNeoProductIntegrationError.missingExpectedContext(
            "NumiSeal product verification requires key seed from signed trusted context"
        )
    }
    let key = try AjtaiCommitmentKey(columns: publicInput.shape.nRing, seed: Array(keySeed.utf8))
    guard key.verifierKeyDigest == expectedVerifierKeyDigest else {
        throw SuperNeoProductIntegrationError.missingExpectedContext("regenerated verifier key digest does not match trusted context")
    }
    let productTrustedContext = try makeNumiSealProductTrustedContext(from: artifact)
    let issuedQROChallengePack = try loadProductQROChallengePack(
        options: options,
        profile: profile,
        context: context,
        frontendContextDigest: productTrustedContext.contextDigest
    )
    let qroChallenge = issuedQROChallengePack.qroChallenge
    let recursiveCarryBinding = try artifact.recursiveCarryReplayBinding()
    if recursiveCarryBinding == nil, recursiveCarryParent != nil {
        throw SuperNeoProductIntegrationError.invalidRequest(
            "recursive carry parent supplied for a non-recursive NumiSeal product artifact"
        )
    }
    if recursiveCarryBinding != nil, recursiveCarryParent == nil, !allowAcceptedRecursiveParentWithoutContext {
        throw SuperNeoProductIntegrationError.missingExpectedContext(
            "typed-required NumiSeal product artifact requires --recursive-carry-parent"
        )
    }
    return ProductArtifactMaterial(
        proofKind: productKind,
        workload: artifact.workload,
        carryMode: artifact.carryMode,
        recursiveCarryReplayBinding: recursiveCarryBinding,
        issuedQROChallengeDigest: issuedQROChallengePack.payloadDigest,
        qroChallengeDigest: qroChallenge.challengeDigest,
        proofEnvelopeBytes: proofBytes,
        proofEnvelopeDigest: Digest256.hash(proofBytes),
        statementDigest: try Digest256(hexDigest: artifact.statementDigestHex, name: "NumiSeal product statement digest"),
        verify: {
            let result = try NumiSealProductVerifier().verify(
                artifact: artifact,
                sourcePublicInput: publicInput,
                key: key,
                qroChallenge: qroChallenge,
                executionPolicy: .highAssurance,
                recursiveCarryParent: recursiveCarryParent
            )
            return .numiSealProduct(result)
        }
    )
}

private func validateNumiSealProductArtifactPins(
    artifact: NumiSealProductArtifact,
    expectedPolicy: SuperNeoTrustedNumiSealContext
) throws {
    guard artifact.publicStatementDigestHex == expectedPolicy.publicStatementDigestHex else {
        throw SuperNeoProductIntegrationError.missingExpectedContext(
            "NumiSeal product public statement digest does not match trusted context"
        )
    }
    guard artifact.obligationRootHex == expectedPolicy.obligationRootHex else {
        throw SuperNeoProductIntegrationError.missingExpectedContext(
            "NumiSeal product obligation root does not match trusted context"
        )
    }
    guard artifact.laneSummaryRootHex == expectedPolicy.laneSummaryRootHex else {
        throw SuperNeoProductIntegrationError.missingExpectedContext(
            "NumiSeal product lane summary root does not match trusted context"
        )
    }
    guard artifact.aggregateDigestsHex == expectedPolicy.aggregateDigestsHex else {
        throw SuperNeoProductIntegrationError.missingExpectedContext(
            "NumiSeal product aggregate digests do not match trusted context"
        )
    }
    guard artifact.componentDigestRootHex == expectedPolicy.componentDigestRootHex else {
        throw SuperNeoProductIntegrationError.missingExpectedContext(
            "NumiSeal product component digest root does not match trusted context"
        )
    }
    guard artifact.proofTranscriptDigestHex == expectedPolicy.proofTranscriptDigestHex else {
        throw SuperNeoProductIntegrationError.missingExpectedContext(
            "NumiSeal product proof transcript digest does not match trusted context"
        )
    }
}

private func appendProductAudit(
    auditLog: SuperNeoJSONLAuditLog,
    profile: SuperNeoLocalOperatorProfile,
    context: SuperNeoTrustedContextPayload,
    decision: String,
    artifactDigest: Digest256?,
    proofEnvelopeDigest: Digest256?,
    provenanceDigest: Digest256?,
    revocationFeedDigest: Digest256?,
    sideChannelCertificateDigest: Digest256?,
    issuedQROChallengeDigest: Digest256?,
    qroChallengeDigest: Digest384?,
    proofKind: SuperNeoProductProofKind?,
    carryMode: String?,
    recursiveCarryReplayBinding: NumiSealProductRecursiveCarryReplayBinding?,
    recursiveCarryParentResolution: ProductRecursiveCarryParentResolution?,
    statementDigest: Digest256?,
    error: Error?
) throws {
    try auditLog.append(
        SuperNeoAuditLogEvent(
            decision: decision,
            errorClass: error.map(productErrorClass),
            errorMessage: error.map(productAuditErrorMessage),
            artifactDigestHex: artifactDigest?.hexString,
            proofEnvelopeDigestHex: proofEnvelopeDigest?.hexString,
            provenanceDigestHex: provenanceDigest?.hexString,
            revocationFeedDigestHex: revocationFeedDigest?.hexString,
            sideChannelCertificateDigestHex: sideChannelCertificateDigest?.hexString,
            issuedQROChallengeDigestHex: issuedQROChallengeDigest?.hexString,
            qroChallengeDigest384Hex: qroChallengeDigest?.hexString,
            proofKind: proofKind?.rawValue,
            carryMode: carryMode,
            recursiveCarryReplayBindingDigestHex: recursiveCarryReplayBinding?.bindingDigest.hexString,
            recursiveCarryContextRootHex: recursiveCarryReplayBinding?.contextRoot.hexString,
            recursiveCarryReplayRootHex: recursiveCarryReplayBinding?.replayRoot.hexString,
            recursiveCarryParentArtifactDigestHex: recursiveCarryReplayBinding?.parentArtifactDigest.hexString,
            recursiveCarryParentProofEnvelopeDigestHex: recursiveCarryReplayBinding?.parentProductProofEnvelopeDigest.hexString,
            recursiveCarryParentProvenanceDigestHex: recursiveCarryParentResolution?.provenanceDigest.hexString,
            recursiveCarryParentAcceptedReplayDigestHex: recursiveCarryParentResolution?.acceptedReplayDigest.hexString,
            recursiveCarryConsumerSessionDigestHex: recursiveCarryReplayBinding?.consumerSessionDigest.hexString,
            recursiveCarryNextRecursionLevel: recursiveCarryReplayBinding?.nextRecursionLevel,
            recursiveCarryClaimCount: recursiveCarryReplayBinding?.claimCount,
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

private func productAuditErrorMessage(_ error: Error) -> String {
    "redacted:\(productErrorClass(error))"
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
    let data = try readProofArtifactData(path: path)
    return try readProofArtifact(data: data)
}

private func readProofArtifactData(
    path: String,
    maximumByteCount: Int? = nil
) throws -> Data {
    if let maximumByteCount, maximumByteCount < 0 {
        throw CLIError.invalidArgument("artifact byte count limit must be non-negative")
    }
    let handle = try FileHandle(forReadingFrom: URL(fileURLWithPath: path))
    defer { try? handle.close() }

    let chunkSize = 64 * 1024
    var data = Data()
    while true {
        let chunk = try handle.read(upToCount: chunkSize) ?? Data()
        guard !chunk.isEmpty else {
            return data
        }
        if let maximumByteCount,
           (chunk.count > maximumByteCount || data.count > maximumByteCount - chunk.count) {
            throw SuperNeoProductIntegrationError.invalidRequest(
                "artifact byte count exceeds trusted context maximum"
            )
        }
        data.append(chunk)
    }
}

private func readProofArtifact(data: Data) throws -> ProofArtifact {
    try validateNoDuplicateJSONKeys(data: data)
    let object = try parseTopLevelJSONObject(data)
    guard let proofKind = object["proofKind"] as? String else {
        throw CLIError.invalidArgument("proof artifact must include proofKind")
    }
    if proofKind == NumiSealProductArtifact.proofKind || proofKind == NumiSealProductArtifact.zkProofKind {
        if let artifactVersion = object["artifactVersion"] as? NSNumber,
           artifactVersion.uint32Value == NumiSealProductArtifact.artifactVersion {
            try validateKnownArtifactTopLevelKeys(
                object: object,
                allowedKeys: NumiSealProductArtifact.topLevelKeys,
                artifactName: "NumiSeal product proof artifact"
            )
            return .numiSealProduct(try JSONDecoder().decode(NumiSealProductArtifact.self, from: data))
        }
        guard proofKind == NumiSealProductArtifact.proofKind else {
            throw CLIError.invalidArgument("NumiSealZK product artifacts require artifactVersion \(NumiSealProductArtifact.artifactVersion)")
        }
        throw CLIError.invalidArgument(
            "legacy NumiSeal artifactVersion 1 is no longer accepted by the product CLI; use NumiSealProductArtifact artifactVersion \(NumiSealProductArtifact.artifactVersion)"
        )
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

private func parseHexBytes(_ raw: String, name: String) throws -> [UInt8] {
    let hex = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard hex.count % 2 == 0, hex.range(of: "^[0-9a-f]+$", options: .regularExpression) != nil else {
        throw CLIError.invalidArgument("\(name) must be even-length lowercase or uppercase hex")
    }
    var bytes: [UInt8] = []
    bytes.reserveCapacity(hex.count / 2)
    var index = hex.startIndex
    while index < hex.endIndex {
        let next = hex.index(index, offsetBy: 2)
        guard let byte = UInt8(hex[index..<next], radix: 16) else {
            throw CLIError.invalidArgument("\(name) must be valid hex")
        }
        bytes.append(byte)
        index = next
    }
    return bytes
}

private func makeNumiSealProductQROChallenge(
    sessionID: String?,
    publicCoinHex: String?,
    domainSeparator: String?,
    frontendContextDigest: Digest256
) throws -> SuperNeoQROChallenge {
    guard let sessionID, !sessionID.isEmpty else {
        throw CLIError.invalidArgument("NumiSeal product QRO verification requires --qro-session-id")
    }
    guard let publicCoinHex else {
        throw CLIError.invalidArgument("NumiSeal product QRO verification requires --qro-public-coin-hex")
    }
    return try SuperNeoQROChallenge(
        domainSeparator: domainSeparator ?? SuperNeoQROChallenge.defaultDomainSeparator,
        sessionID: sessionID,
        verifierPublicCoin: parseHexBytes(publicCoinHex, name: "--qro-public-coin-hex"),
        transcriptContext: SuperNeoSplitQRO.framedBytes(
            domain: "superneo/cli/numiseal-product/qro-context/v1",
            frames: [frontendContextDigest.superNeoBytes]
        )
    )
}

private func makeNumiSealProductTrustedContext(from artifact: NumiSealProductArtifact) throws -> NumiSealProductTrustedContext {
    guard let laneIDValue = artifact.laneIDsUTF8.first, artifact.laneIDsUTF8.count == 1 else {
        throw CLIError.invalidArgument("NumiSeal product artifact must carry exactly one lane id")
    }
    guard let sourceApplicationPath = artifact.sourceApplicationPathUTF8,
          !sourceApplicationPath.isEmpty,
          sourceApplicationPath != "unbound" else {
        throw SuperNeoProductIntegrationError.missingExpectedContext(
            "NumiSeal product verification requires bound source application provenance"
        )
    }
    return try NumiSealProductTrustedContext(
        workload: artifact.workload,
        bitCount: artifact.bitCount,
        publicInputs: artifact.publicInputs,
        workloadParameters: artifact.workloadParameters,
        sourceApplicationPathUTF8: sourceApplicationPath,
        laneID: NumiSealLaneID(laneIDValue)
    )
}

private func defaultKeySeed(for options: ProveOptions) throws -> String {
    try defaultKeySeed(
        workload: options.workload,
        bitCount: options.bits.count,
        operandBits: options.operandBits
    )
}

private func defaultKeySeed(
    workload: DemoWorkload,
    bitCount: Int,
    operandBits: Int
) throws -> String {
    switch workload {
    case .oneHot:
        return try SuperNeoWorkloadKeySeed.oneHotVector(bitCount: bitCount)
    case .binaryAdd:
        return try SuperNeoWorkloadKeySeed.binaryAddition(operandBits: operandBits)
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
    var hasLegacyExpectedContext: Bool {
        trustedKeySeed != nil
            || expectedVerifierKeyDigestHex != nil
            || expectedShapeDigestHex != nil
            || expectedStatementDigestHex != nil
            || expectedPublicInputs != nil
            || hasNumiSealExpectedContext
    }

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
