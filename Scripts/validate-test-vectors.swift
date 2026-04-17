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
let manifestTopLevelKeys: Set<String> = [
    "manifestVersion",
    "profile",
    "schema",
    "vectors",
]
let manifestVectorKeys: Set<String> = [
    "file",
    "sha256",
    "byteCount",
    "workload",
    "proofKind",
    "bitCount",
    "publicClaim",
    "expectedKeySeedUTF8",
    "expectedPublicInputs",
    "expectedShapeDigestHex",
    "expectedStatementDigestHex",
    "expectedVerifierKeyDigestHex",
    "verifyCommand",
]

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data(("error: \(message)\n").utf8))
    exit(1)
}

func repositoryRoot() -> URL {
    let arguments = Array(CommandLine.arguments.dropFirst())
    guard arguments.count <= 1 else {
        fail("usage: swift Scripts/validate-test-vectors.swift [repository-root]")
    }
    if let root = arguments.first {
        return URL(fileURLWithPath: root).standardizedFileURL
    }
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

func validateKnownManifestKeys(_ data: Data) throws {
    let json = try JSONSerialization.jsonObject(with: data)
    guard let object = json as? [String: Any] else {
        throw ValidationError.invalid("manifest.json JSON must be an object")
    }
    let unknownTopLevelKeys = Set(object.keys).subtracting(manifestTopLevelKeys).sorted()
    try require(
        unknownTopLevelKeys.isEmpty,
        "manifest.json contains unknown top-level fields: \(unknownTopLevelKeys.joined(separator: ","))"
    )
    guard let vectors = object["vectors"] as? [Any] else {
        throw ValidationError.invalid("manifest.json vectors must be an array")
    }
    for (index, rawVector) in vectors.enumerated() {
        guard let vectorObject = rawVector as? [String: Any] else {
            throw ValidationError.invalid("manifest.json vectors[\(index)] must be an object")
        }
        let unknownVectorKeys = Set(vectorObject.keys).subtracting(manifestVectorKeys).sorted()
        try require(
            unknownVectorKeys.isEmpty,
            "manifest.json vectors[\(index)] contains unknown fields: \(unknownVectorKeys.joined(separator: ","))"
        )
    }
}

func validateNoDuplicateJSONKeys(_ data: Data, file: String) throws {
    var scanner = JSONDuplicateKeyScanner(data: data, file: file)
    try scanner.validate()
}

struct JSONDuplicateKeyScanner {
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

    private func invalid(_ message: String) -> ValidationError {
        ValidationError.invalid("\(file) \(message)")
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
                throw ValidationError.invalid("\(file) contains duplicate JSON object key '\(key)' at \(path)")
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
    case "compressed-terminal": return 3
    default: return nil
    }
}

func satisfiesTerminalRequirement(_ proofKind: String) -> Bool {
    proofKind == "terminal" || proofKind == "compressed-terminal"
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
    if satisfiesTerminalRequirement(vector.proofKind) {
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
    try validateNoDuplicateJSONKeys(manifestData, file: "manifest.json")
    try validateKnownManifestKeys(manifestData)
    let manifest = try JSONDecoder().decode(Manifest.self, from: manifestData)

    try require(manifest.manifestVersion == 1, "unsupported manifest version")
    try require(manifest.profile == "Goldilocks/Phi81(d=54)", "unexpected manifest profile")
    try require(
        FileManager.default.fileExists(atPath: vectorsDirectory.appendingPathComponent(manifest.schema).path),
        "manifest schema file is missing"
    )

    var manifestedFiles = Set<String>()
    var manifestCoverage = Set<String>()
    var verifyCommands = Set<String>()

    for vector in manifest.vectors {
        let vectorFile = try validatedVectorFileName(vector.file)
        try require(manifestedFiles.insert(vectorFile).inserted, "\(vector.file) appears more than once in manifest")
        try require(verifyCommands.insert(vector.verifyCommand).inserted, "\(vector.file) verify command duplicates another vector")
        manifestCoverage.insert("\(vector.workload):\(vector.proofKind)")
        try require(vector.expectedPublicInputs.allSatisfy { $0 < goldilocksModulus }, "\(vector.file) expected public input contains a non-canonical Goldilocks element")
        try require(vector.expectedShapeDigestHex.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil, "\(vector.file) invalid expected shape digest")
        try require(vector.expectedStatementDigestHex.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil, "\(vector.file) invalid expected statement digest")
        try require(vector.expectedVerifierKeyDigestHex.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil, "\(vector.file) invalid expected verifier key digest")
        try require(expectedEnvelopeKind(vector.proofKind) != nil, "\(vector.file) unsupported proof kind")
        try require(vector.verifyCommand == expectedVerifyCommand(file: vectorFile, vector: vector), "\(vector.file) verify command mismatch")

        let url = vectorsDirectory.appendingPathComponent(vectorFile)
        let data = try Data(contentsOf: url)
        try require(data.count == vector.byteCount, "\(vector.file) byte count mismatch")
        try require(sha256Hex(data) == vector.sha256, "\(vector.file) SHA-256 mismatch")

        try validateNoDuplicateJSONKeys(data, file: vector.file)
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

    }

    let requiredCoverage: Set<String> = [
        "one-hot-vector-v1:fold",
        "one-hot-vector-v1:terminal",
        "one-hot-vector-v1:compressed-terminal",
        "binary-addition-v1:fold",
        "binary-addition-v1:terminal",
    ]
    let missingCoverage = requiredCoverage.subtracting(manifestCoverage).sorted()
    try require(
        missingCoverage.isEmpty,
        "manifest missing required vector coverage: \(missingCoverage.joined(separator: ","))"
    )
    let checkedVectorFiles = try FileManager.default.contentsOfDirectory(atPath: vectorsDirectory.path)
        .filter {
            $0.hasSuffix("-v1.json")
                && !$0.hasPrefix("numiseal-")
                && !$0.hasSuffix("-scope-v1.json")
                && !$0.hasPrefix("constant-time-lowering-evidence-")
                && $0 != "product-crypto-security-dossier-v1.json"
                && $0 != "product-selected-depth-loss-accounting-v1.json"
                && $0 != "product-extractor-loss-accounting-v1.json"
                && $0 != "product-qrom-fiat-shamir-accounting-v1.json"
                && $0 != "e2e-proof-metrics-v1.json"
                && $0 != "benchmark-coverage-v1.json"
        }
    let unmanifestedFiles = Set(checkedVectorFiles).subtracting(manifestedFiles).sorted()
    try require(
        unmanifestedFiles.isEmpty,
        "checked vector file(s) missing from manifest: \(unmanifestedFiles.joined(separator: ","))"
    )

    for vector in manifest.vectors {
        let vectorFile = try validatedVectorFileName(vector.file)
        try runVerify(file: vectorFile, vector: vector, root: root)
        print("validated \(vector.file)")
    }
} catch {
    fail("\(error)")
}
