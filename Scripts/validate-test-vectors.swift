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
    let verifyCommand: String
}

struct Artifact: Decodable {
    let artifactVersion: UInt32
    let workload: String
    let profile: String
    let proofKind: String
    let bitCount: Int
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

func expectedVerifyCommand(file: String) -> String {
    "swift run superneo verify TestVectors/\(file)"
}

func runVerify(file: String, root: URL) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["swift", "run", "superneo", "verify", "TestVectors/\(file)"]
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
        try require(vector.verifyCommand == expectedVerifyCommand(file: vectorFile), "\(vector.file) verify command mismatch")

        let url = vectorsDirectory.appendingPathComponent(vectorFile)
        let data = try Data(contentsOf: url)
        try require(data.count == vector.byteCount, "\(vector.file) byte count mismatch")
        try require(sha256Hex(data) == vector.sha256, "\(vector.file) SHA-256 mismatch")

        let artifact = try JSONDecoder().decode(Artifact.self, from: data)
        try require(artifact.artifactVersion == 1, "\(vector.file) artifact version mismatch")
        try require(artifact.profile == manifest.profile, "\(vector.file) profile mismatch")
        try require(artifact.workload == vector.workload, "\(vector.file) workload mismatch")
        try require(artifact.proofKind == vector.proofKind, "\(vector.file) proof kind mismatch")
        try require(artifact.bitCount == vector.bitCount, "\(vector.file) bit count mismatch")
        try require(artifact.publicInputs.allSatisfy { $0 < goldilocksModulus }, "\(vector.file) public input contains a non-canonical Goldilocks element")
        try require(Data(base64Encoded: artifact.commitmentBase64) != nil, "\(vector.file) commitment is not base64")
        try require(Data(base64Encoded: artifact.proofEnvelopeBase64) != nil, "\(vector.file) proof envelope is not base64")
        try require(artifact.shapeDigestHex.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil, "\(vector.file) invalid shape digest")
        try require(artifact.statementDigestHex.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil, "\(vector.file) invalid statement digest")
        try require(artifact.verifierKeyDigestHex.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil, "\(vector.file) invalid verifier key digest")

        if artifact.workload == "binary-addition-v1" {
            try require(artifact.publicInputs.count == artifact.bitCount + 2, "\(vector.file) binary-add public input length mismatch")
            try require(artifact.publicInputs.first == 1, "\(vector.file) binary-add public input 0 must be one")
            try require(artifact.publicInputs.dropFirst().allSatisfy { $0 == 0 || $0 == 1 }, "\(vector.file) binary-add public sum bits must be binary")
        }
        if artifact.workload == "one-hot-vector-v1" {
            try require(artifact.publicInputs == [1], "\(vector.file) one-hot public inputs must be [1]")
        }

        try runVerify(file: vectorFile, root: root)
        print("validated \(vector.file)")
    }
} catch {
    fail("\(error)")
}
