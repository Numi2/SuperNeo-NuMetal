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

    var envelopeKind: ProofEnvelopeKind {
        switch self {
        case .fold: return .foldReduction
        case .terminal: return .terminalLocal
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
    var expectedPublicInputs: [UInt64]?
    var requireTerminalProof = false
}

private func usage() -> String {
    """
    Usage:
      superneo prove [--workload one-hot] [--bits 0,0,1,0] [--kind fold|terminal] [--key-seed text] [--output proof.json]
      superneo prove --workload binary-add [--operand-bits 8] [--lhs 13] [--rhs 29] [--kind fold|terminal] [--output proof.json]
      superneo verify [--key-seed text] [--expected-verifier-key-digest hex] [--expected-shape-digest hex] [--expected-statement-digest hex] [--expected-public-inputs values] [--require-terminal] proof.json
      superneo inspect proof.json

    Workloads:
      one-hot: proves a committed private bit vector has exactly one selected bit.
      binary-add: proves two committed private integers add to public sum bits.

    The default proof kind is fold. Terminal proofs are complete but currently
    much larger and slower because they include the public CE opening proof.
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
                throw CLIError.invalidArgument("--kind must be terminal or fold")
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
    var expectedPublicInputs: [UInt64]?
    var requireTerminalProof = false
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
        case "--expected-public-inputs":
            expectedPublicInputs = try parsePublicInputList(try requireValue(), name: argument)
        case "--require-terminal":
            requireTerminalProof = true
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
    return VerifyOptions(
        path: path,
        trustedKeySeed: trustedKeySeed,
        expectedVerifierKeyDigestHex: expectedVerifierKeyDigestHex,
        expectedShapeDigestHex: expectedShapeDigestHex,
        expectedStatementDigestHex: expectedStatementDigestHex,
        expectedPublicInputs: expectedPublicInputs,
        requireTerminalProof: requireTerminalProof
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
    let artifact = try readArtifact(path: options.path)
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
    if options.requireTerminalProof, kind != .terminal {
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
    }
    print(String(format: "verify time: %.3f s", Date().timeIntervalSince(started)))
}

private func inspect(path: String) throws {
    let artifact = try readArtifact(path: path)
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

private func readArtifact(path: String) throws -> DemoProofArtifact {
    let data = try Data(contentsOf: URL(fileURLWithPath: path))
    try validateKnownArtifactTopLevelKeys(data: data)
    return try JSONDecoder().decode(DemoProofArtifact.self, from: data)
}

private func validateKnownArtifactTopLevelKeys(data: Data) throws {
    let json = try JSONSerialization.jsonObject(with: data)
    guard let object = json as? [String: Any] else {
        throw CLIError.invalidArgument("proof artifact JSON must be an object")
    }
    let unknownKeys = Set(object.keys).subtracting(demoProofArtifactTopLevelKeys).sorted()
    guard unknownKeys.isEmpty else {
        throw CLIError.invalidArgument("proof artifact contains unknown top-level fields: \(unknownKeys.joined(separator: ","))")
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
        bodyLength: header.bodyLength
    )
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

private extension Digest256 {
    var hexString: String {
        bytes.map { String(format: "%02x", $0) }.joined()
    }
}
