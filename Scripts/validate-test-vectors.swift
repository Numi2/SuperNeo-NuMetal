import CryptoKit
import Foundation

struct Manifest: Decodable {
    let manifestVersion: UInt32
    let profile: String
    let schema: String
    let vectors: [ManifestVector]
}

struct ManifestVector: Decodable {
    let file: String
    let sha256: String
    let byteCount: Int
    let workload: String
    let proofKind: String
    let bitCount: Int
    let publicClaim: String
    let expectedKeySeedUTF8: String
    let expectedPublicInputs: [UInt64]
    let expectedShapeDigestHex: String
    let expectedStatementDigestHex: String
    let expectedVerifierKeyDigestHex: String
    let verifyCommand: String
}

struct Artifact: Decodable {
    let artifactVersion: UInt32
    let workload: String
    let profile: String
    let proofKind: String
    let bitCount: Int
    let keySeedUTF8: String
    let workloadParameters: [String: String]?
    let publicInputs: [UInt64]
    let commitmentBase64: String
    let proofEnvelopeBase64: String
    let shapeDigestHex: String
    let statementDigestHex: String
    let verifierKeyDigestHex: String
}

enum ValidationError: Error, CustomStringConvertible {
    case invalid(String)

    var description: String {
        switch self {
        case .invalid(let message): return message
        }
    }
}

let goldilocksModulus: UInt64 = 0xFFFF_FFFF_0000_0001
let proofEnvelopeMagic: UInt32 = 0x4E_55_4D_51
let proofEnvelopeVersion: UInt16 = 4
let proofEnvelopeHeaderByteCount = 141
let goldilocksProfileID: UInt16 = 1
let artifactTopLevelKeys: Set<String> = [
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

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data(("error: \(message)\n").utf8))
    exit(1)
}

func repositoryRoot() -> URL {
    let script = URL(fileURLWithPath: CommandLine.arguments[0])
    if script.pathComponents.contains("Scripts") {
        return script.deletingLastPathComponent().deletingLastPathComponent()
    }
    return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    guard condition() else { throw ValidationError.invalid(message) }
}

func sha256Hex(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

func validatedVectorFileName(_ file: String) throws -> String {
    guard !file.isEmpty,
          file.hasSuffix(".json"),
          file == URL(fileURLWithPath: file).lastPathComponent,
          !file.contains("..")
    else {
        throw ValidationError.invalid("unsafe vector file path in manifest: \(file)")
    }
    return file
}

func publicInputList(_ values: [UInt64]) -> String {
    values.map(String.init).joined(separator: ",")
}

func validateKnownArtifactTopLevelKeys(_ data: Data, file: String) throws {
    let json = try JSONSerialization.jsonObject(with: data)
    guard let object = json as? [String: Any] else {
        throw ValidationError.invalid("\(file) artifact JSON must be an object")
    }
    let unknownKeys = Set(object.keys).subtracting(artifactTopLevelKeys).sorted()
    try require(
        unknownKeys.isEmpty,
        "\(file) artifact contains unknown top-level fields: \(unknownKeys.joined(separator: ","))"
    )
}

struct EnvelopeHeader {
    let profileID: UInt16
    let kind: UInt8
    let shapeDigestHex: String
    let statementDigestHex: String
    let verifierKeyDigestHex: String
    let bodyLength: UInt32
}

func readUInt16(_ bytes: [UInt8], at offset: Int) -> UInt16 {
    UInt16(bytes[offset]) | (UInt16(bytes[offset + 1]) << 8)
}

func readUInt32(_ bytes: [UInt8], at offset: Int) -> UInt32 {
    UInt32(bytes[offset])
        | (UInt32(bytes[offset + 1]) << 8)
        | (UInt32(bytes[offset + 2]) << 16)
        | (UInt32(bytes[offset + 3]) << 24)
}

func hexDigest(_ bytes: ArraySlice<UInt8>) -> String {
    bytes.map { String(format: "%02x", $0) }.joined()
}

func parseEnvelopeHeader(_ data: Data, file: String) throws -> EnvelopeHeader {
    let bytes = [UInt8](data)
    try require(bytes.count >= proofEnvelopeHeaderByteCount, "\(file) proof envelope is shorter than its header")
    try require(readUInt32(bytes, at: 0) == proofEnvelopeMagic, "\(file) wrong proof envelope magic")
    try require(readUInt16(bytes, at: 4) == proofEnvelopeVersion, "\(file) unsupported proof envelope version")
    let profileID = readUInt16(bytes, at: 6)
    let kind = bytes[8]
    try require(kind == 1 || kind == 2 || kind == 3, "\(file) unsupported proof envelope kind")
    let bodyLength = readUInt32(bytes, at: 137)
    try require(
        bytes.count == proofEnvelopeHeaderByteCount + Int(bodyLength),
        "\(file) proof envelope body length mismatch"
    )
    return EnvelopeHeader(
        profileID: profileID,
        kind: kind,
        shapeDigestHex: hexDigest(bytes[9..<41]),
        statementDigestHex: hexDigest(bytes[41..<73]),
        verifierKeyDigestHex: hexDigest(bytes[73..<105]),
        bodyLength: bodyLength
    )
}

func requireWorkloadParameters(
    _ parameters: [String: String]?,
    allowedKeys: Set<String>,
    file: String,
    workload: String
) throws -> [String: String] {
    guard let parameters else {
        throw ValidationError.invalid("\(file) \(workload) artifact must include workloadParameters")
    }
    let actualKeys = Set(parameters.keys)
    let missingKeys = allowedKeys.subtracting(actualKeys).sorted()
    try require(
        missingKeys.isEmpty,
        "\(file) \(workload) artifact missing workload parameter(s): \(missingKeys.joined(separator: ","))"
    )
    let unknownKeys = actualKeys.subtracting(allowedKeys).sorted()
    try require(
        unknownKeys.isEmpty,
        "\(file) \(workload) artifact contains unknown workload parameter(s): \(unknownKeys.joined(separator: ","))"
    )
    return parameters
}

func parseCanonicalUInt64Decimal(_ raw: String) -> UInt64? {
    guard raw.range(of: #"^(0|[1-9][0-9]*)$"#, options: .regularExpression) != nil else {
        return nil
    }
    return UInt64(raw)
}

func expectedEnvelopeKind(_ proofKind: String) -> UInt8? {
    switch proofKind {
    case "fold": return 1
    case "terminal": return 2
    default: return nil
    }
}

func strictVerifyArguments(file: String, vector: ManifestVector) -> [String] {
    var arguments = [
        "swift",
        "run",
        "superneo",
        "verify",
        "--key-seed",
        vector.expectedKeySeedUTF8,
        "--expected-verifier-key-digest",
        vector.expectedVerifierKeyDigestHex,
        "--expected-shape-digest",
        vector.expectedShapeDigestHex,
        "--expected-statement-digest",
        vector.expectedStatementDigestHex,
        "--expected-public-inputs",
        publicInputList(vector.expectedPublicInputs),
    ]
    if vector.proofKind == "terminal" {
        arguments.append("--require-terminal")
    }
    arguments.append("TestVectors/\(file)")
    return arguments
}

func expectedVerifyCommand(file: String, vector: ManifestVector) -> String {
    strictVerifyArguments(file: file, vector: vector).joined(separator: " ")
}

func runVerify(file: String, vector: ManifestVector, root: URL) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = strictVerifyArguments(file: file, vector: vector)
    process.currentDirectoryURL = root
    let output = Pipe()
    process.standardOutput = output
    process.standardError = output
    try process.run()
    process.waitUntilExit()
    let data = output.fileHandleForReading.readDataToEndOfFile()
    if process.terminationStatus != 0 {
        let text = String(data: data, encoding: .utf8) ?? ""
        throw ValidationError.invalid("vector verification failed for \(file)\n\(text)")
    }
}

do {
    let root = repositoryRoot()
    let vectorsDirectory = root.appendingPathComponent("TestVectors", isDirectory: true)
    let manifestURL = vectorsDirectory.appendingPathComponent("manifest.json")
    let manifestData = try Data(contentsOf: manifestURL)
    let manifest = try JSONDecoder().decode(Manifest.self, from: manifestData)

    try require(manifest.manifestVersion == 1, "unsupported manifest version")
    try require(manifest.profile == "Goldilocks/Phi81(d=54)", "unexpected manifest profile")
    try require(
        FileManager.default.fileExists(atPath: vectorsDirectory.appendingPathComponent(manifest.schema).path),
        "manifest schema file is missing"
    )

    for vector in manifest.vectors {
        let vectorFile = try validatedVectorFileName(vector.file)
        try require(vector.expectedPublicInputs.allSatisfy { $0 < goldilocksModulus }, "\(vector.file) expected public input contains a non-canonical Goldilocks element")
        try require(vector.expectedShapeDigestHex.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil, "\(vector.file) invalid expected shape digest")
        try require(vector.expectedStatementDigestHex.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil, "\(vector.file) invalid expected statement digest")
        try require(vector.expectedVerifierKeyDigestHex.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil, "\(vector.file) invalid expected verifier key digest")
        try require(vector.proofKind == "fold" || vector.proofKind == "terminal", "\(vector.file) unsupported proof kind")
        try require(vector.verifyCommand == expectedVerifyCommand(file: vectorFile, vector: vector), "\(vector.file) verify command mismatch")

        let url = vectorsDirectory.appendingPathComponent(vectorFile)
        let data = try Data(contentsOf: url)
        try require(data.count == vector.byteCount, "\(vector.file) byte count mismatch")
        try require(sha256Hex(data) == vector.sha256, "\(vector.file) SHA-256 mismatch")

        try validateKnownArtifactTopLevelKeys(data, file: vector.file)
        let artifact = try JSONDecoder().decode(Artifact.self, from: data)
        try require(artifact.artifactVersion == 1, "\(vector.file) artifact version mismatch")
        try require(artifact.profile == manifest.profile, "\(vector.file) profile mismatch")
        try require(artifact.workload == vector.workload, "\(vector.file) workload mismatch")
        try require(artifact.proofKind == vector.proofKind, "\(vector.file) proof kind mismatch")
        try require(artifact.bitCount == vector.bitCount, "\(vector.file) bit count mismatch")
        try require(artifact.keySeedUTF8 == vector.expectedKeySeedUTF8, "\(vector.file) key seed mismatch")
        try require(artifact.publicInputs == vector.expectedPublicInputs, "\(vector.file) public inputs mismatch")
        try require(artifact.publicInputs.allSatisfy { $0 < goldilocksModulus }, "\(vector.file) public input contains a non-canonical Goldilocks element")
        try require(Data(base64Encoded: artifact.commitmentBase64) != nil, "\(vector.file) commitment is not base64")
        guard let proofEnvelopeData = Data(base64Encoded: artifact.proofEnvelopeBase64) else {
            throw ValidationError.invalid("\(vector.file) proof envelope is not base64")
        }
        let envelopeHeader = try parseEnvelopeHeader(proofEnvelopeData, file: vector.file)
        try require(artifact.shapeDigestHex.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil, "\(vector.file) invalid shape digest")
        try require(artifact.statementDigestHex.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil, "\(vector.file) invalid statement digest")
        try require(artifact.verifierKeyDigestHex.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil, "\(vector.file) invalid verifier key digest")
        try require(artifact.shapeDigestHex == vector.expectedShapeDigestHex, "\(vector.file) shape digest mismatch")
        try require(artifact.statementDigestHex == vector.expectedStatementDigestHex, "\(vector.file) statement digest mismatch")
        try require(artifact.verifierKeyDigestHex == vector.expectedVerifierKeyDigestHex, "\(vector.file) verifier key digest mismatch")
        try require(envelopeHeader.profileID == goldilocksProfileID, "\(vector.file) proof envelope profile id mismatch")
        try require(envelopeHeader.kind == expectedEnvelopeKind(vector.proofKind) ?? 0, "\(vector.file) proof envelope kind mismatch")
        try require(envelopeHeader.shapeDigestHex == artifact.shapeDigestHex, "\(vector.file) proof envelope shape digest mismatch")
        try require(envelopeHeader.statementDigestHex == artifact.statementDigestHex, "\(vector.file) proof envelope statement digest mismatch")
        try require(envelopeHeader.verifierKeyDigestHex == artifact.verifierKeyDigestHex, "\(vector.file) proof envelope verifier key digest mismatch")

        if artifact.workload == "binary-addition-v1" {
            let parameters = try requireWorkloadParameters(
                artifact.workloadParameters,
                allowedKeys: ["leftBitCount", "publicSum"],
                file: vector.file,
                workload: "binary-addition"
            )
            try require(artifact.bitCount <= 62, "\(vector.file) binary-add bit count exceeds supported range")
            try require(artifact.publicInputs.count == artifact.bitCount + 2, "\(vector.file) binary-add public input length mismatch")
            try require(artifact.publicInputs.first == 1, "\(vector.file) binary-add public input 0 must be one")
            try require(artifact.publicInputs.dropFirst().allSatisfy { $0 == 0 || $0 == 1 }, "\(vector.file) binary-add public sum bits must be binary")
            guard let leftBitCount = parseCanonicalUInt64Decimal(parameters["leftBitCount"] ?? ""),
                  leftBitCount == UInt64(artifact.bitCount) else {
                throw ValidationError.invalid("\(vector.file) binary-add leftBitCount parameter missing or non-canonical")
            }
            guard let publicSum = parseCanonicalUInt64Decimal(parameters["publicSum"] ?? "") else {
                throw ValidationError.invalid("\(vector.file) binary-add publicSum parameter missing or non-canonical")
            }
            let encodedPublicSum = artifact.publicInputs.dropFirst().enumerated().reduce(UInt64(0)) { partial, pair in
                pair.element == 0 ? partial : partial | (UInt64(1) << UInt64(pair.offset))
            }
            try require(publicSum == encodedPublicSum, "\(vector.file) binary-add publicSum parameter mismatch")
        }
        if artifact.workload == "one-hot-vector-v1" {
            let parameters = try requireWorkloadParameters(
                artifact.workloadParameters,
                allowedKeys: ["selectedCount"],
                file: vector.file,
                workload: "one-hot"
            )
            try require(artifact.publicInputs == [1], "\(vector.file) one-hot public inputs must be [1]")
            try require(
                parseCanonicalUInt64Decimal(parameters["selectedCount"] ?? "") == 1,
                "\(vector.file) one-hot selectedCount parameter missing or non-canonical"
            )
        }

        try runVerify(file: vectorFile, vector: vector, root: root)
        print("validated \(vector.file)")
    }
} catch {
    fail("\(error)")
}
