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

private func usage() -> String {
    """
    Usage:
      superneo prove [--workload one-hot] [--bits 0,0,1,0] [--kind fold|terminal] [--key-seed text] [--output proof.json]
      superneo prove --workload binary-add [--operand-bits 8] [--lhs 13] [--rhs 29] [--kind fold|terminal] [--output proof.json]
      superneo verify proof.json
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
        guard arguments.count == 2 else {
            throw CLIError.usage("verify expects exactly one proof artifact path")
        }
        try verify(path: arguments[1])
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

private func prove(_ options: ProveOptions) throws {
    let started = Date()
    let keySeed = options.keySeed ?? defaultKeySeed(for: options.workload)
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
    let prover = SuperNeoCPUBackend().makeProver(key: prepared.key)
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

private func verify(path: String) throws {
    let artifact = try readArtifact(path: path)
    let publicInput = try makePublicInput(from: artifact)
    let key = try AjtaiCommitmentKey(columns: publicInput.shape.nRing, seed: Array(artifact.keySeedUTF8.utf8))
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
    let proofBytes = try artifact.proofEnvelopeBytes()
    let verifier = SuperNeoCPUBackend().makeVerifier(key: key)
    let kind = try artifact.demoProofKind()
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
        let workload = try SuperNeoOneHotVectorWorkload(bitCount: artifact.bitCount)
        publicInput = try workload.publicFoldInput(commitment: commitment)
    case "binary-addition-v1":
        let workload = try SuperNeoBinaryAdditionWorkload(bitCount: artifact.bitCount)
        let publicFields = try parsePublicFields(artifact.publicInputs)
        publicInput = try workload.publicFoldInput(
            commitment: commitment,
            publicInput: publicFields
        )
        if let publicSum = artifact.workloadParameters?["publicSum"].flatMap(UInt64.init) {
            guard try workload.publicInput(sum: publicSum).map(\.rawValue) == artifact.publicInputs else {
                throw CLIError.invalidArgument("binary-addition public sum parameter does not match public input bits")
            }
        }
    default:
        throw CLIError.invalidArgument("unsupported workload: \(artifact.workload)")
    }
    guard publicInput.shape.shapeDigest.hexString == artifact.shapeDigestHex else {
        throw CLIError.invalidArgument("artifact shape digest does not match reconstructed workload")
    }
    return publicInput
}

private func readArtifact(path: String) throws -> DemoProofArtifact {
    let data = try Data(contentsOf: URL(fileURLWithPath: path))
    return try JSONDecoder().decode(DemoProofArtifact.self, from: data)
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

private func defaultKeySeed(for workload: DemoWorkload) -> String {
    switch workload {
    case .oneHot:
        return "SuperNeoCLI.one-hot-vector.v1"
    case .binaryAdd:
        return "SuperNeoCLI.binary-addition.u8.v1"
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
    let bodyLength: UInt32

    var magicHex: String {
        "0x" + String(magic, radix: 16, uppercase: true)
    }
}

private func parseEnvelopeHeader(_ bytes: [UInt8]) throws -> EnvelopeHeader {
    guard bytes.count >= ProofEnvelopeHeader.byteCount else {
        throw CLIError.invalidArgument("proof envelope is shorter than its header")
    }
    let magic = readUInt32(bytes, at: 0)
    let version = readUInt16(bytes, at: 4)
    let profileID = readUInt16(bytes, at: 6)
    let kind = bytes[8]
    let bodyLength = readUInt32(bytes, at: 137)
    guard bytes.count == ProofEnvelopeHeader.byteCount + Int(bodyLength) else {
        throw CLIError.invalidArgument("proof envelope body length mismatch")
    }
    return EnvelopeHeader(
        magic: magic,
        version: version,
        profileID: profileID,
        kind: kind,
        bodyLength: bodyLength
    )
}

private func readUInt16(_ bytes: [UInt8], at offset: Int) -> UInt16 {
    UInt16(bytes[offset]) | (UInt16(bytes[offset + 1]) << 8)
}

private func readUInt32(_ bytes: [UInt8], at offset: Int) -> UInt32 {
    UInt32(bytes[offset])
        | (UInt32(bytes[offset + 1]) << 8)
        | (UInt32(bytes[offset + 2]) << 16)
        | (UInt32(bytes[offset + 3]) << 24)
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
