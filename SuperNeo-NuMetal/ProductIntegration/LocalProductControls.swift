import CryptoKit
import Darwin
import Foundation
import SQLite3

public enum SuperNeoProductProofKind: String, Codable, Equatable, Sendable {
    case terminal
    case compressedTerminal = "compressed-terminal"
    case numiSealTerminal = "numiseal-terminal"
    case numiSealZK = "numiseal-zk"

    public init(envelopeKind: ProofEnvelopeKind) throws {
        switch envelopeKind {
        case .terminalLocal:
            self = .terminal
        case .compressedPublic:
            self = .compressedTerminal
        case .numiSealTerminal:
            self = .numiSealTerminal
        case .numiSealZK:
            self = .numiSealZK
        case .foldReduction:
            throw SuperNeoProductIntegrationError.invalidRequest("fold reductions are not product-accepted proofs")
        }
    }
}

public struct SuperNeoProductSignature: Codable, Equatable, Sendable {
    public let algorithm: String
    public let publicKeyBase64: String
    public let publicKeyDigestHex: String
    public let signatureBase64: String

    public init(
        algorithm: String = "ed25519",
        publicKeyBase64: String,
        publicKeyDigestHex: String,
        signatureBase64: String
    ) {
        self.algorithm = algorithm
        self.publicKeyBase64 = publicKeyBase64
        self.publicKeyDigestHex = publicKeyDigestHex
        self.signatureBase64 = signatureBase64
    }
}

public struct SuperNeoTrustedContextKeyRotation: Codable, Equatable, Sendable {
    public let currentIssuerKeyDigestHex: String
    public let nextIssuerKeyDigestHex: String?
    public let previousIssuerKeyDigestsHex: [String]
    public let rotationNotAfterUTC: String?

    public init(
        currentIssuerKeyDigestHex: String,
        nextIssuerKeyDigestHex: String? = nil,
        previousIssuerKeyDigestsHex: [String] = [],
        rotationNotAfterUTC: String? = nil
    ) {
        self.currentIssuerKeyDigestHex = currentIssuerKeyDigestHex
        self.nextIssuerKeyDigestHex = nextIssuerKeyDigestHex
        self.previousIssuerKeyDigestsHex = previousIssuerKeyDigestsHex
        self.rotationNotAfterUTC = rotationNotAfterUTC
    }
}

public struct SuperNeoTrustedContextRevocation: Codable, Equatable, Sendable {
    public let revokedContextIDs: [String]
    public let revokedArtifactDigestHex: [String]
    public let revokedProofEnvelopeDigestHex: [String]
    public let revokedProvenanceDigestHex: [String]
    public let issuedAtUTC: String?

    public init(
        revokedContextIDs: [String] = [],
        revokedArtifactDigestHex: [String] = [],
        revokedProofEnvelopeDigestHex: [String] = [],
        revokedProvenanceDigestHex: [String] = [],
        issuedAtUTC: String? = nil
    ) {
        self.revokedContextIDs = revokedContextIDs
        self.revokedArtifactDigestHex = revokedArtifactDigestHex
        self.revokedProofEnvelopeDigestHex = revokedProofEnvelopeDigestHex
        self.revokedProvenanceDigestHex = revokedProvenanceDigestHex
        self.issuedAtUTC = issuedAtUTC
    }
}

public struct SuperNeoTrustedNumiSealContext: Codable, Equatable, Sendable {
    public let publicStatementDigestHex: String
    public let obligationRootHex: String
    public let laneSummaryRootHex: String
    public let aggregateDigestsHex: [String]
    public let componentDigestRootHex: String
    public let proofTranscriptDigestHex: String

    public init(
        publicStatementDigestHex: String,
        obligationRootHex: String,
        laneSummaryRootHex: String,
        aggregateDigestsHex: [String],
        componentDigestRootHex: String,
        proofTranscriptDigestHex: String
    ) {
        self.publicStatementDigestHex = publicStatementDigestHex
        self.obligationRootHex = obligationRootHex
        self.laneSummaryRootHex = laneSummaryRootHex
        self.aggregateDigestsHex = aggregateDigestsHex
        self.componentDigestRootHex = componentDigestRootHex
        self.proofTranscriptDigestHex = proofTranscriptDigestHex
    }
}

public struct SuperNeoTrustedContextPayload: Codable, Equatable, Sendable {
    public let formatVersion: Int
    public let contextID: String
    public let issuer: String
    public let validFromUTC: String
    public let validUntilUTC: String
    public let expectedKeySeedUTF8: String?
    public let expectedVerifierKeyDigestHex: String
    public let expectedShapeDigestHex: String
    public let expectedStatementDigestHex: String
    public let expectedTranscriptDomainDigestHex: String
    public let acceptedProofKinds: [SuperNeoProductProofKind]
    public let maximumArtifactByteCount: Int
    public let maximumProofEnvelopeByteCount: Int?
    public let allowedWorkloads: [String]
    public let publicInputs: [UInt64]?
    public let releaseBuildDigestHex: String
    public let numiSeal: SuperNeoTrustedNumiSealContext?
    public let numiSealZK: SuperNeoTrustedNumiSealZKContext?
    public let keyRotation: SuperNeoTrustedContextKeyRotation
    public let revocation: SuperNeoTrustedContextRevocation

    public init(
        formatVersion: Int = 1,
        contextID: String,
        issuer: String,
        validFromUTC: String,
        validUntilUTC: String,
        expectedKeySeedUTF8: String? = nil,
        expectedVerifierKeyDigestHex: String,
        expectedShapeDigestHex: String,
        expectedStatementDigestHex: String,
        expectedTranscriptDomainDigestHex: String,
        acceptedProofKinds: [SuperNeoProductProofKind],
        maximumArtifactByteCount: Int,
        maximumProofEnvelopeByteCount: Int? = nil,
        allowedWorkloads: [String],
        publicInputs: [UInt64]? = nil,
        releaseBuildDigestHex: String,
        numiSeal: SuperNeoTrustedNumiSealContext? = nil,
        numiSealZK: SuperNeoTrustedNumiSealZKContext? = nil,
        keyRotation: SuperNeoTrustedContextKeyRotation,
        revocation: SuperNeoTrustedContextRevocation = SuperNeoTrustedContextRevocation()
    ) {
        self.formatVersion = formatVersion
        self.contextID = contextID
        self.issuer = issuer
        self.validFromUTC = validFromUTC
        self.validUntilUTC = validUntilUTC
        self.expectedKeySeedUTF8 = expectedKeySeedUTF8
        self.expectedVerifierKeyDigestHex = expectedVerifierKeyDigestHex
        self.expectedShapeDigestHex = expectedShapeDigestHex
        self.expectedStatementDigestHex = expectedStatementDigestHex
        self.expectedTranscriptDomainDigestHex = expectedTranscriptDomainDigestHex
        self.acceptedProofKinds = acceptedProofKinds
        self.maximumArtifactByteCount = maximumArtifactByteCount
        self.maximumProofEnvelopeByteCount = maximumProofEnvelopeByteCount
        self.allowedWorkloads = allowedWorkloads
        self.publicInputs = publicInputs
        self.releaseBuildDigestHex = releaseBuildDigestHex
        self.numiSeal = numiSeal
        self.numiSealZK = numiSealZK
        self.keyRotation = keyRotation
        self.revocation = revocation
    }
}

public struct SuperNeoSignedTrustedContextPack: Codable, Equatable, Sendable {
    public let payload: SuperNeoTrustedContextPayload
    public let signature: SuperNeoProductSignature

    public init(payload: SuperNeoTrustedContextPayload, signature: SuperNeoProductSignature) {
        self.payload = payload
        self.signature = signature
    }

    public static func loadVerified(
        from url: URL,
        trustedIssuerKeyDigestsHex: Set<String>,
        now: Date = Date()
    ) throws -> SuperNeoVerifiedTrustedContextPack {
        try SuperNeoLocalFileSecurity.requireSecureRegularFile(url, description: "trusted context pack")
        let data = try Data(contentsOf: url)
        try SuperNeoJSONDuplicateKeyValidator.validate(data: data, artifactName: "trusted context pack")
        let pack = try JSONDecoder().decode(Self.self, from: data)
        return try pack.verified(trustedIssuerKeyDigestsHex: trustedIssuerKeyDigestsHex, now: now)
    }

    public func verified(
        trustedIssuerKeyDigestsHex: Set<String>,
        now: Date = Date()
    ) throws -> SuperNeoVerifiedTrustedContextPack {
        let payloadBytes = try SuperNeoCanonicalJSON.encode(payload)
        let issuerKeyDigest = try SuperNeoProductSignatureVerifier.verify(
            signature: signature,
            payload: payloadBytes,
            trustedKeyDigestsHex: trustedIssuerKeyDigestsHex,
            description: "trusted context pack"
        )
        try payload.validate(now: now, issuerKeyDigestHex: issuerKeyDigest.hexString)
        return SuperNeoVerifiedTrustedContextPack(
            payload: payload,
            payloadDigest: Digest256.hash([UInt8](payloadBytes)),
            issuerKeyDigest: issuerKeyDigest
        )
    }
}

public struct SuperNeoVerifiedTrustedContextPack: Equatable, Sendable {
    public let payload: SuperNeoTrustedContextPayload
    public let payloadDigest: Digest256
    public let issuerKeyDigest: Digest256

    public init(
        payload: SuperNeoTrustedContextPayload,
        payloadDigest: Digest256,
        issuerKeyDigest: Digest256
    ) {
        self.payload = payload
        self.payloadDigest = payloadDigest
        self.issuerKeyDigest = issuerKeyDigest
    }
}

public struct SuperNeoArtifactProvenancePayload: Codable, Equatable, Sendable {
    public let formatVersion: Int
    public let issuer: String
    public let contextID: String
    public let artifactDigestHex: String
    public let proofEnvelopeDigestHex: String
    public let statementDigestHex: String
    public let releaseBuildDigestHex: String
    public let issuedAtUTC: String

    public init(
        formatVersion: Int = 1,
        issuer: String,
        contextID: String,
        artifactDigestHex: String,
        proofEnvelopeDigestHex: String,
        statementDigestHex: String,
        releaseBuildDigestHex: String,
        issuedAtUTC: String
    ) {
        self.formatVersion = formatVersion
        self.issuer = issuer
        self.contextID = contextID
        self.artifactDigestHex = artifactDigestHex
        self.proofEnvelopeDigestHex = proofEnvelopeDigestHex
        self.statementDigestHex = statementDigestHex
        self.releaseBuildDigestHex = releaseBuildDigestHex
        self.issuedAtUTC = issuedAtUTC
    }
}

public struct SuperNeoSignedArtifactProvenanceManifest: Codable, Equatable, Sendable {
    public let payload: SuperNeoArtifactProvenancePayload
    public let signature: SuperNeoProductSignature

    public init(payload: SuperNeoArtifactProvenancePayload, signature: SuperNeoProductSignature) {
        self.payload = payload
        self.signature = signature
    }

    public static func loadVerified(
        from url: URL,
        trustedIssuerKeyDigestsHex: Set<String>
    ) throws -> SuperNeoVerifiedArtifactProvenanceManifest {
        try SuperNeoLocalFileSecurity.requireSecureRegularFile(url, description: "artifact provenance manifest")
        let data = try Data(contentsOf: url)
        try SuperNeoJSONDuplicateKeyValidator.validate(data: data, artifactName: "artifact provenance manifest")
        let manifest = try JSONDecoder().decode(Self.self, from: data)
        return try manifest.verified(trustedIssuerKeyDigestsHex: trustedIssuerKeyDigestsHex)
    }

    public func verified(
        trustedIssuerKeyDigestsHex: Set<String>
    ) throws -> SuperNeoVerifiedArtifactProvenanceManifest {
        let payloadBytes = try SuperNeoCanonicalJSON.encode(payload)
        let issuerKeyDigest = try SuperNeoProductSignatureVerifier.verify(
            signature: signature,
            payload: payloadBytes,
            trustedKeyDigestsHex: trustedIssuerKeyDigestsHex,
            description: "artifact provenance manifest"
        )
        try payload.validate()
        return SuperNeoVerifiedArtifactProvenanceManifest(
            payload: payload,
            provenanceDigest: Digest256.hash([UInt8](payloadBytes)),
            issuerKeyDigest: issuerKeyDigest
        )
    }
}

public struct SuperNeoVerifiedArtifactProvenanceManifest: Equatable, Sendable {
    public let payload: SuperNeoArtifactProvenancePayload
    public let provenanceDigest: Digest256
    public let issuerKeyDigest: Digest256

    public init(
        payload: SuperNeoArtifactProvenancePayload,
        provenanceDigest: Digest256,
        issuerKeyDigest: Digest256
    ) {
        self.payload = payload
        self.provenanceDigest = provenanceDigest
        self.issuerKeyDigest = issuerKeyDigest
    }

    public func validateBinding(
        artifactDigest: Digest256,
        proofEnvelopeDigest: Digest256,
        contextID: String,
        statementDigest: Digest256,
        releaseBuildDigest: Digest256
    ) throws {
        guard payload.artifactDigestHex == artifactDigest.hexString else {
            throw SuperNeoProductIntegrationError.provenanceRejected("artifact digest does not match provenance")
        }
        guard payload.proofEnvelopeDigestHex == proofEnvelopeDigest.hexString else {
            throw SuperNeoProductIntegrationError.provenanceRejected("proof envelope digest does not match provenance")
        }
        guard payload.contextID == contextID else {
            throw SuperNeoProductIntegrationError.provenanceRejected("context ID does not match provenance")
        }
        guard payload.statementDigestHex == statementDigest.hexString else {
            throw SuperNeoProductIntegrationError.provenanceRejected("statement digest does not match provenance")
        }
        guard payload.releaseBuildDigestHex == releaseBuildDigest.hexString else {
            throw SuperNeoProductIntegrationError.provenanceRejected("release build digest does not match provenance")
        }
    }
}

public struct SuperNeoLocalOperatorProfile: Codable, Equatable, Sendable {
    public let formatVersion: Int
    public let callerID: String
    public let contextPackPath: String?
    public let artifactProvenancePath: String?
    public let sideChannelCertificatePath: String?
    public let replayDatabasePath: String
    public let auditLogPath: String
    public let trustedContextIssuerKeyDigestsHex: [String]
    public let trustedProvenanceIssuerKeyDigestsHex: [String]?
    public let trustedSideChannelIssuerKeyDigestsHex: [String]?
    public let releaseBuildDigestHex: String

    public init(
        formatVersion: Int = 1,
        callerID: String,
        contextPackPath: String? = nil,
        artifactProvenancePath: String? = nil,
        sideChannelCertificatePath: String? = nil,
        replayDatabasePath: String,
        auditLogPath: String,
        trustedContextIssuerKeyDigestsHex: [String],
        trustedProvenanceIssuerKeyDigestsHex: [String]? = nil,
        trustedSideChannelIssuerKeyDigestsHex: [String]? = nil,
        releaseBuildDigestHex: String
    ) {
        self.formatVersion = formatVersion
        self.callerID = callerID
        self.contextPackPath = contextPackPath
        self.artifactProvenancePath = artifactProvenancePath
        self.sideChannelCertificatePath = sideChannelCertificatePath
        self.replayDatabasePath = replayDatabasePath
        self.auditLogPath = auditLogPath
        self.trustedContextIssuerKeyDigestsHex = trustedContextIssuerKeyDigestsHex
        self.trustedProvenanceIssuerKeyDigestsHex = trustedProvenanceIssuerKeyDigestsHex
        self.trustedSideChannelIssuerKeyDigestsHex = trustedSideChannelIssuerKeyDigestsHex
        self.releaseBuildDigestHex = releaseBuildDigestHex
    }

    public static func load(from url: URL) throws -> Self {
        try SuperNeoLocalFileSecurity.requireSecureRegularFile(url, description: "operator profile")
        let data = try Data(contentsOf: url)
        try SuperNeoJSONDuplicateKeyValidator.validate(data: data, artifactName: "operator profile")
        let profile = try JSONDecoder().decode(Self.self, from: data)
        try profile.validate()
        return profile
    }

    public func trustedContextIssuerKeyDigestSet() throws -> Set<String> {
        try validateDigestList(trustedContextIssuerKeyDigestsHex, name: "trusted context issuer key digest")
    }

    public func trustedProvenanceIssuerKeyDigestSet() throws -> Set<String> {
        try validateDigestList(
            trustedProvenanceIssuerKeyDigestsHex ?? trustedContextIssuerKeyDigestsHex,
            name: "trusted provenance issuer key digest"
        )
    }

    public func trustedSideChannelIssuerKeyDigestSet() throws -> Set<String> {
        try validateDigestList(
            trustedSideChannelIssuerKeyDigestsHex
                ?? trustedProvenanceIssuerKeyDigestsHex
                ?? trustedContextIssuerKeyDigestsHex,
            name: "trusted side-channel issuer key digest"
        )
    }

    public var releaseBuildDigest: Digest256 {
        get throws {
            try Digest256(hexDigest: releaseBuildDigestHex, name: "release build digest")
        }
    }

    private func validate() throws {
        guard formatVersion == 1 else {
            throw SuperNeoProductIntegrationError.invalidRequest("unsupported operator profile version")
        }
        guard !callerID.isEmpty else {
            throw SuperNeoProductIntegrationError.invalidRequest("operator profile callerID is required")
        }
        guard !replayDatabasePath.isEmpty else {
            throw SuperNeoProductIntegrationError.invalidRequest("operator profile replay database path is required")
        }
        guard !auditLogPath.isEmpty else {
            throw SuperNeoProductIntegrationError.invalidRequest("operator profile audit log path is required")
        }
        _ = try trustedContextIssuerKeyDigestSet()
        _ = try trustedProvenanceIssuerKeyDigestSet()
        _ = try trustedSideChannelIssuerKeyDigestSet()
        _ = try releaseBuildDigest
    }
}

public enum SuperNeoLocalFileSecurity {
    public static func requireSecureRegularFile(_ url: URL, description: String) throws {
        let path = url.path
        var info = stat()
        guard lstat(path, &info) == 0 else {
            throw SuperNeoProductIntegrationError.invalidRequest("\(description) is missing: \(path)")
        }
        guard (info.st_mode & S_IFMT) != S_IFLNK else {
            throw SuperNeoProductIntegrationError.unauthorized("\(description) must not be a symlink: \(path)")
        }
        guard (info.st_mode & S_IFMT) == S_IFREG else {
            throw SuperNeoProductIntegrationError.invalidRequest("\(description) must be a regular file: \(path)")
        }
        guard info.st_uid == geteuid() else {
            throw SuperNeoProductIntegrationError.unauthorized("\(description) must be owned by the current OS user: \(path)")
        }
        guard (info.st_mode & (S_IWGRP | S_IWOTH)) == 0 else {
            throw SuperNeoProductIntegrationError.unauthorized("\(description) must not be group- or world-writable: \(path)")
        }
    }

    public static func requireLockableSecureRegularFile(_ url: URL, description: String) throws {
        try requireSecureRegularFile(url, description: description)
        let fd = open(url.path, O_RDWR | O_CLOEXEC)
        guard fd >= 0 else {
            throw SuperNeoProductIntegrationError.invalidRequest("\(description) is not openable for locking: \(url.path)")
        }
        defer { close(fd) }
        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else {
            throw SuperNeoProductIntegrationError.unauthorized("\(description) is not lockable: \(url.path)")
        }
        flock(fd, LOCK_UN)
    }

    public static func createSecureFileIfMissing(_ url: URL, description: String) throws {
        let path = url.path
        if FileManager.default.fileExists(atPath: path) {
            try requireSecureRegularFile(url, description: description)
            return
        }
        let fd = open(path, O_CREAT | O_EXCL | O_RDWR | O_CLOEXEC, S_IRUSR | S_IWUSR)
        guard fd >= 0 else {
            throw SuperNeoProductIntegrationError.invalidRequest("could not create \(description): \(path)")
        }
        close(fd)
    }
}

public final class SuperNeoSQLiteReplayLedger: SuperNeoReplayLedger {
    private let databaseURL: URL
    private var database: OpaquePointer?

    public init(databaseURL: URL) throws {
        self.databaseURL = databaseURL
        try SuperNeoLocalFileSecurity.requireLockableSecureRegularFile(databaseURL, description: "replay database")
        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(databaseURL.path, &handle, flags, nil) == SQLITE_OK, let handle else {
            throw SuperNeoProductIntegrationError.invalidRequest(
                "could not open replay database: \(String(cString: sqlite3_errmsg(handle)))"
            )
        }
        self.database = handle
        try execute("PRAGMA busy_timeout = 5000")
        try execute("PRAGMA journal_mode = DELETE")
        try requireSchema()
    }

    deinit {
        if let database {
            sqlite3_close(database)
        }
    }

    public static func bootstrap(databaseURL: URL) throws {
        try SuperNeoLocalFileSecurity.createSecureFileIfMissing(databaseURL, description: "replay database")
        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(databaseURL.path, &handle, flags, nil) == SQLITE_OK, let handle else {
            throw SuperNeoProductIntegrationError.invalidRequest("could not create replay database")
        }
        defer { sqlite3_close(handle) }
        try execute(
            on: handle,
            sql: """
            CREATE TABLE IF NOT EXISTS accepted_replays (
              identity_digest TEXT PRIMARY KEY NOT NULL,
              expected_context_id TEXT NOT NULL,
              statement_digest TEXT NOT NULL,
              proof_envelope_digest TEXT NOT NULL,
              artifact_digest TEXT NOT NULL,
              provenance_digest TEXT NOT NULL,
              accepted_at_utc TEXT NOT NULL,
              UNIQUE(expected_context_id, statement_digest, proof_envelope_digest, artifact_digest, provenance_digest)
            );
            """
        )
        try execute(on: handle, sql: "PRAGMA journal_mode = DELETE")
    }

    public func hasAccepted(_ identity: SuperNeoProductProofIdentity) throws -> Bool {
        let sql = "SELECT 1 FROM accepted_replays WHERE identity_digest = ? LIMIT 1"
        var statement: OpaquePointer?
        try prepare(sql, statement: &statement)
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, identity.localReplayDigest.hexString, -1, sqliteTransient)
        return sqlite3_step(statement) == SQLITE_ROW
    }

    public func recordAccepted(_ identity: SuperNeoProductProofIdentity) throws {
        try execute("BEGIN IMMEDIATE")
        do {
            let sql = """
            INSERT INTO accepted_replays (
              identity_digest,
              expected_context_id,
              statement_digest,
              proof_envelope_digest,
              artifact_digest,
              provenance_digest,
              accepted_at_utc
            ) VALUES (?, ?, ?, ?, ?, ?, ?)
            """
            var statement: OpaquePointer?
            try prepare(sql, statement: &statement)
            defer { sqlite3_finalize(statement) }
            sqlite3_bind_text(statement, 1, identity.localReplayDigest.hexString, -1, sqliteTransient)
            sqlite3_bind_text(statement, 2, identity.expectedContextID, -1, sqliteTransient)
            sqlite3_bind_text(statement, 3, identity.statementDigest.hexString, -1, sqliteTransient)
            sqlite3_bind_text(statement, 4, identity.proofEnvelopeDigest.hexString, -1, sqliteTransient)
            sqlite3_bind_text(statement, 5, identity.artifactDigest.hexString, -1, sqliteTransient)
            sqlite3_bind_text(statement, 6, identity.provenanceDigest.hexString, -1, sqliteTransient)
            sqlite3_bind_text(statement, 7, SuperNeoProductTime.nowUTCString(), -1, sqliteTransient)
            let step = sqlite3_step(statement)
            guard step == SQLITE_DONE else {
                if step == SQLITE_CONSTRAINT {
                    throw SuperNeoProductIntegrationError.replayDetected("proof identity has already been accepted")
                }
                throw sqliteError("could not record replay identity")
            }
            try execute("COMMIT")
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
    }

    public func acceptedReplayCount() throws -> Int {
        let sql = "SELECT COUNT(*) FROM accepted_replays"
        var statement: OpaquePointer?
        try prepare(sql, statement: &statement)
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw sqliteError("could not count replay ledger rows")
        }
        return Int(sqlite3_column_int64(statement, 0))
    }

    private func requireSchema() throws {
        let sql = "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'accepted_replays'"
        var statement: OpaquePointer?
        try prepare(sql, statement: &statement)
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw SuperNeoProductIntegrationError.invalidRequest("replay database schema is missing")
        }
    }

    private func prepare(_ sql: String, statement: inout OpaquePointer?) throws {
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw sqliteError("could not prepare replay ledger statement")
        }
    }

    private func execute(_ sql: String) throws {
        guard let database else {
            throw SuperNeoProductIntegrationError.invalidRequest("replay database is closed")
        }
        try Self.execute(on: database, sql: sql)
    }

    private static func execute(on database: OpaquePointer, sql: String) throws {
        var message: UnsafeMutablePointer<CChar>?
        let code = sqlite3_exec(database, sql, nil, nil, &message)
        guard code == SQLITE_OK else {
            let detail = message.map { String(cString: $0) } ?? "unknown SQLite error"
            sqlite3_free(message)
            throw SuperNeoProductIntegrationError.invalidRequest(detail)
        }
    }

    private func sqliteError(_ message: String) -> SuperNeoProductIntegrationError {
        let detail = database.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown SQLite error"
        return SuperNeoProductIntegrationError.invalidRequest("\(message): \(detail)")
    }
}

public struct SuperNeoAuditLogEvent: Codable, Equatable, Sendable {
    public let decision: String
    public let errorClass: String?
    public let errorMessage: String?
    public let artifactDigestHex: String?
    public let proofEnvelopeDigestHex: String?
    public let provenanceDigestHex: String?
    public let sideChannelCertificateDigestHex: String?
    public let proofKind: String?
    public let contextID: String
    public let statementDigestHex: String?
    public let toolVersion: String
    public let releaseBuildDigestHex: String

    public init(
        decision: String,
        errorClass: String? = nil,
        errorMessage: String? = nil,
        artifactDigestHex: String? = nil,
        proofEnvelopeDigestHex: String? = nil,
        provenanceDigestHex: String? = nil,
        sideChannelCertificateDigestHex: String? = nil,
        proofKind: String? = nil,
        contextID: String,
        statementDigestHex: String? = nil,
        toolVersion: String,
        releaseBuildDigestHex: String
    ) {
        self.decision = decision
        self.errorClass = errorClass
        self.errorMessage = errorMessage
        self.artifactDigestHex = artifactDigestHex
        self.proofEnvelopeDigestHex = proofEnvelopeDigestHex
        self.provenanceDigestHex = provenanceDigestHex
        self.sideChannelCertificateDigestHex = sideChannelCertificateDigestHex
        self.proofKind = proofKind
        self.contextID = contextID
        self.statementDigestHex = statementDigestHex
        self.toolVersion = toolVersion
        self.releaseBuildDigestHex = releaseBuildDigestHex
    }
}

public struct SuperNeoAuditLogRecordPayload: Codable, Equatable, Sendable {
    public let formatVersion: Int
    public let sequence: UInt64
    public let timestampUTC: String
    public let previousRecordDigestHex: String
    public let event: SuperNeoAuditLogEvent
}

public struct SuperNeoAuditLogRecord: Codable, Equatable, Sendable {
    public let payload: SuperNeoAuditLogRecordPayload
    public let recordDigestHex: String
}

public struct SuperNeoAuditLogChainStatus: Codable, Equatable, Sendable {
    public let isValid: Bool
    public let recordCount: Int
    public let lastSequence: UInt64
    public let lastRecordDigestHex: String
    public let reason: String?

    public init(
        isValid: Bool,
        recordCount: Int,
        lastSequence: UInt64,
        lastRecordDigestHex: String,
        reason: String? = nil
    ) {
        self.isValid = isValid
        self.recordCount = recordCount
        self.lastSequence = lastSequence
        self.lastRecordDigestHex = lastRecordDigestHex
        self.reason = reason
    }
}

public struct SuperNeoAuditLogExportSnapshot: Codable, Equatable, Sendable {
    public let formatVersion: Int
    public let exportedAtUTC: String
    public let auditLogDigestHex: String
    public let chainStatus: SuperNeoAuditLogChainStatus
    public let records: [SuperNeoAuditLogRecord]

    public init(
        formatVersion: Int = 1,
        exportedAtUTC: String,
        auditLogDigestHex: String,
        chainStatus: SuperNeoAuditLogChainStatus,
        records: [SuperNeoAuditLogRecord]
    ) {
        self.formatVersion = formatVersion
        self.exportedAtUTC = exportedAtUTC
        self.auditLogDigestHex = auditLogDigestHex
        self.chainStatus = chainStatus
        self.records = records
    }
}

public final class SuperNeoJSONLAuditLog {
    public static let genesisDigestHex = String(repeating: "0", count: 64)

    private let url: URL

    public init(url: URL) throws {
        self.url = url
        try SuperNeoLocalFileSecurity.requireLockableSecureRegularFile(url, description: "audit log")
    }

    public static func bootstrap(url: URL) throws {
        try SuperNeoLocalFileSecurity.createSecureFileIfMissing(url, description: "audit log")
    }

    public func append(_ event: SuperNeoAuditLogEvent) throws {
        try withExclusiveAuditLogLock(flags: O_RDWR | O_APPEND | O_CLOEXEC) { fd in
            let status = try validateChainUnlocked(fd: fd)
            guard status.isValid else {
                throw SuperNeoProductIntegrationError.verificationFailed(status.reason ?? "audit log chain is invalid")
            }
            let payload = SuperNeoAuditLogRecordPayload(
                formatVersion: 1,
                sequence: status.lastSequence + 1,
                timestampUTC: SuperNeoProductTime.nowUTCString(),
                previousRecordDigestHex: status.lastRecordDigestHex,
                event: event
            )
            let digest = Digest256.hash([UInt8](try SuperNeoCanonicalJSON.encode(payload))).hexString
            let record = SuperNeoAuditLogRecord(payload: payload, recordDigestHex: digest)
            var line = try SuperNeoCanonicalJSON.encode(record)
            line.append(UInt8(ascii: "\n"))
            let wrote = line.withUnsafeBytes { buffer in
                write(fd, buffer.baseAddress, buffer.count)
            }
            guard wrote == line.count else {
                throw SuperNeoProductIntegrationError.invalidRequest("could not append audit log record")
            }
        }
    }

    public func validateChain() throws -> SuperNeoAuditLogChainStatus {
        try withExclusiveAuditLogLock(flags: O_RDWR | O_CLOEXEC) { fd in
            try validateChainUnlocked(fd: fd)
        }
    }

    public func exportSnapshot(
        exportedAtUTC: String = SuperNeoProductTime.nowUTCString()
    ) throws -> SuperNeoAuditLogExportSnapshot {
        try withExclusiveAuditLogLock(flags: O_RDWR | O_CLOEXEC) { fd in
            let result = try readRecordsUnlocked(fd: fd)
            guard result.status.isValid else {
                throw SuperNeoProductIntegrationError.verificationFailed(result.status.reason ?? "audit log chain is invalid")
            }
            return SuperNeoAuditLogExportSnapshot(
                exportedAtUTC: exportedAtUTC,
                auditLogDigestHex: result.auditLogDigestHex,
                chainStatus: result.status,
                records: result.records
            )
        }
    }

    public func records() throws -> [SuperNeoAuditLogRecord] {
        try exportSnapshot().records
    }

    private func validateChainUnlocked(fd: Int32) throws -> SuperNeoAuditLogChainStatus {
        try readRecordsUnlocked(fd: fd).status
    }

    private func withExclusiveAuditLogLock<T>(
        flags: Int32,
        _ body: (Int32) throws -> T
    ) throws -> T {
        try SuperNeoLocalFileSecurity.requireSecureRegularFile(url, description: "audit log")
        let fd = open(url.path, flags)
        guard fd >= 0 else {
            throw SuperNeoProductIntegrationError.invalidRequest("could not open audit log")
        }
        defer { close(fd) }
        guard flock(fd, LOCK_EX) == 0 else {
            throw SuperNeoProductIntegrationError.unauthorized("audit log is not lockable")
        }
        defer { flock(fd, LOCK_UN) }
        return try body(fd)
    }

    private func readRecordsUnlocked(fd: Int32) throws -> AuditLogReadResult {
        let data = try readDataUnlocked(fd: fd)
        let auditLogDigestHex = Digest256.hash([UInt8](data)).hexString
        guard !data.isEmpty else {
            return AuditLogReadResult(
                status: SuperNeoAuditLogChainStatus(
                    isValid: true,
                    recordCount: 0,
                    lastSequence: 0,
                    lastRecordDigestHex: Self.genesisDigestHex
                ),
                records: [],
                auditLogDigestHex: auditLogDigestHex
            )
        }
        guard let text = String(data: data, encoding: .utf8) else {
            return invalidAuditResult("audit log is not UTF-8", auditLogDigestHex: auditLogDigestHex)
        }
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        var expectedSequence: UInt64 = 1
        var previousDigest = Self.genesisDigestHex
        var count = 0
        var records: [SuperNeoAuditLogRecord] = []
        for line in lines {
            guard !line.isEmpty else {
                continue
            }
            guard let lineData = String(line).data(using: .utf8) else {
                return invalidAuditResult("audit log line is not UTF-8", auditLogDigestHex: auditLogDigestHex)
            }
            let record: SuperNeoAuditLogRecord
            do {
                record = try JSONDecoder().decode(SuperNeoAuditLogRecord.self, from: lineData)
            } catch {
                return invalidAuditResult("audit log line is not valid JSON", auditLogDigestHex: auditLogDigestHex)
            }
            guard record.payload.formatVersion == 1 else {
                return invalidAuditResult("audit log record version is unsupported", auditLogDigestHex: auditLogDigestHex)
            }
            guard record.payload.sequence == expectedSequence else {
                return invalidAuditResult("audit log sequence is not monotonic", auditLogDigestHex: auditLogDigestHex)
            }
            guard record.payload.previousRecordDigestHex == previousDigest else {
                return invalidAuditResult("audit log hash chain is broken", auditLogDigestHex: auditLogDigestHex)
            }
            let digest = Digest256.hash([UInt8](try SuperNeoCanonicalJSON.encode(record.payload))).hexString
            guard record.recordDigestHex == digest else {
                return invalidAuditResult("audit log record digest mismatch", auditLogDigestHex: auditLogDigestHex)
            }
            previousDigest = record.recordDigestHex
            expectedSequence += 1
            count += 1
            records.append(record)
        }
        return AuditLogReadResult(
            status: SuperNeoAuditLogChainStatus(
                isValid: true,
                recordCount: count,
                lastSequence: expectedSequence - 1,
                lastRecordDigestHex: previousDigest
            ),
            records: records,
            auditLogDigestHex: auditLogDigestHex
        )
    }

    private func readDataUnlocked(fd: Int32) throws -> Data {
        guard lseek(fd, 0, SEEK_SET) >= 0 else {
            throw SuperNeoProductIntegrationError.invalidRequest("could not seek audit log")
        }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 64 * 1024)
        while true {
            let byteCount = buffer.withUnsafeMutableBytes { rawBuffer in
                read(fd, rawBuffer.baseAddress, rawBuffer.count)
            }
            if byteCount < 0 {
                throw SuperNeoProductIntegrationError.invalidRequest("could not read audit log")
            }
            if byteCount == 0 {
                return data
            }
            data.append(buffer, count: byteCount)
        }
    }

    private func invalidAuditResult(_ reason: String, auditLogDigestHex: String) -> AuditLogReadResult {
        AuditLogReadResult(
            status: SuperNeoAuditLogChainStatus(
                isValid: false,
                recordCount: 0,
                lastSequence: 0,
                lastRecordDigestHex: Self.genesisDigestHex,
                reason: reason
            ),
            records: [],
            auditLogDigestHex: auditLogDigestHex
        )
    }

    private struct AuditLogReadResult {
        let status: SuperNeoAuditLogChainStatus
        let records: [SuperNeoAuditLogRecord]
        let auditLogDigestHex: String
    }
}

public extension SuperNeoTrustedContextPayload {
    var expectedVerifierKeyDigest: Digest256 {
        get throws {
            try Digest256(hexDigest: expectedVerifierKeyDigestHex, name: "expected verifier key digest")
        }
    }

    var expectedShapeDigest: Digest256 {
        get throws {
            try Digest256(hexDigest: expectedShapeDigestHex, name: "expected shape digest")
        }
    }

    var expectedStatementDigest: Digest256 {
        get throws {
            try Digest256(hexDigest: expectedStatementDigestHex, name: "expected statement digest")
        }
    }

    var expectedTranscriptDomainDigest: Digest256 {
        get throws {
            try Digest256(hexDigest: expectedTranscriptDomainDigestHex, name: "expected transcript domain digest")
        }
    }

    var releaseBuildDigest: Digest256 {
        get throws {
            try Digest256(hexDigest: releaseBuildDigestHex, name: "release build digest")
        }
    }

    func accepts(_ proofKind: SuperNeoProductProofKind) -> Bool {
        acceptedProofKinds.contains(proofKind)
    }

    func requireNotRevoked(
        artifactDigest: Digest256?,
        proofEnvelopeDigest: Digest256?,
        provenanceDigest: Digest256?
    ) throws {
        guard !revocation.revokedContextIDs.contains(contextID) else {
            throw SuperNeoProductIntegrationError.unauthorized("trusted context has been revoked")
        }
        if let artifactDigest {
            guard !revocation.revokedArtifactDigestHex.contains(artifactDigest.hexString) else {
                throw SuperNeoProductIntegrationError.provenanceRejected("artifact digest has been revoked")
            }
        }
        if let proofEnvelopeDigest {
            guard !revocation.revokedProofEnvelopeDigestHex.contains(proofEnvelopeDigest.hexString) else {
                throw SuperNeoProductIntegrationError.provenanceRejected("proof envelope digest has been revoked")
            }
        }
        if let provenanceDigest {
            guard !revocation.revokedProvenanceDigestHex.contains(provenanceDigest.hexString) else {
                throw SuperNeoProductIntegrationError.provenanceRejected("provenance digest has been revoked")
            }
        }
    }

    func terminalPolicy() throws -> SuperNeoTerminalProofAcceptancePolicy {
        let terminalAccepted = acceptedProofKinds.contains(.terminal)
        let compressedAccepted = acceptedProofKinds.contains(.compressedTerminal)
        let proofPolicy: SuperNeoTerminalProofAcceptancePolicy.ProofKindPolicy
        switch (terminalAccepted, compressedAccepted) {
        case (true, true):
            proofPolicy = .terminalOrCompressed
        case (true, false):
            proofPolicy = .terminalOnly
        case (false, true):
            proofPolicy = .compressedOnly
        case (false, false):
            throw SuperNeoProductIntegrationError.invalidRequest("trusted context does not accept terminal verifier surfaces")
        }
        return SuperNeoTerminalProofAcceptancePolicy(
            shapeDigest: try expectedShapeDigest,
            statementDigest: try expectedStatementDigest,
            verifierKeyDigest: try expectedVerifierKeyDigest,
            transcriptDomain: try expectedTranscriptDomainDigest,
            proofKindPolicy: proofPolicy,
            maximumProofByteCount: maximumProofEnvelopeByteCount
        )
    }

    func numiSealExpectedContext() throws -> NumiSealArtifactExpectedContext {
        guard let numiSeal else {
            throw SuperNeoProductIntegrationError.missingExpectedContext("trusted context does not include NumiSeal policy")
        }
        return NumiSealArtifactExpectedContext(
            trustedKeySeedUTF8: expectedKeySeedUTF8,
            verifierKeyDigest: try expectedVerifierKeyDigest,
            shapeDigest: try expectedShapeDigest,
            statementDigest: try expectedStatementDigest,
            transcriptDomainDigest: try expectedTranscriptDomainDigest,
            publicStatementDigest: try Digest256(hexDigest: numiSeal.publicStatementDigestHex, name: "public statement digest"),
            obligationRoot: try Digest256(hexDigest: numiSeal.obligationRootHex, name: "obligation root"),
            laneSummaryRoot: try Digest256(hexDigest: numiSeal.laneSummaryRootHex, name: "lane summary root"),
            aggregateDigests: try numiSeal.aggregateDigestsHex.map {
                try Digest256(hexDigest: $0, name: "aggregate digest")
            },
            componentDigestRoot: try Digest256(hexDigest: numiSeal.componentDigestRootHex, name: "component digest root"),
            proofTranscriptDigest: try Digest256(hexDigest: numiSeal.proofTranscriptDigestHex, name: "proof transcript digest"),
            publicInputs: publicInputs
        )
    }

    func validate(now: Date, issuerKeyDigestHex: String) throws {
        guard formatVersion == 1 else {
            throw SuperNeoProductIntegrationError.invalidRequest("unsupported trusted context pack version")
        }
        guard !contextID.isEmpty else {
            throw SuperNeoProductIntegrationError.invalidRequest("trusted context ID is required")
        }
        guard !issuer.isEmpty else {
            throw SuperNeoProductIntegrationError.invalidRequest("trusted context issuer is required")
        }
        guard !acceptedProofKinds.isEmpty else {
            throw SuperNeoProductIntegrationError.invalidRequest("trusted context must accept at least one proof kind")
        }
        guard maximumArtifactByteCount > 0 else {
            throw SuperNeoProductIntegrationError.invalidRequest("trusted context artifact byte limit must be positive")
        }
        if let maximumProofEnvelopeByteCount {
            guard maximumProofEnvelopeByteCount > 0 else {
                throw SuperNeoProductIntegrationError.invalidRequest("trusted context proof byte limit must be positive")
            }
        }
        guard !allowedWorkloads.isEmpty else {
            throw SuperNeoProductIntegrationError.invalidRequest("trusted context must name at least one allowed workload")
        }
        _ = try expectedVerifierKeyDigest
        _ = try expectedShapeDigest
        _ = try expectedStatementDigest
        _ = try expectedTranscriptDomainDigest
        _ = try releaseBuildDigest
        if acceptedProofKinds.contains(.numiSealTerminal) || acceptedProofKinds.contains(.numiSealZK) {
            guard numiSeal != nil else {
                throw SuperNeoProductIntegrationError.invalidRequest(
                    "trusted context accepting NumiSeal proofs must include NumiSeal public-root policy"
                )
            }
            _ = try numiSealExpectedContext()
        } else if numiSeal != nil {
            _ = try numiSealExpectedContext()
        }
        if acceptedProofKinds.contains(.numiSealZK) {
            guard let numiSealZK else {
                throw SuperNeoProductIntegrationError.invalidRequest(
                    "trusted context accepting numiseal-zk must include NumiSealZK policy"
                )
            }
            try numiSealZK.validate()
        } else if let numiSealZK {
            try numiSealZK.validate()
        }
        _ = try Digest256(hexDigest: keyRotation.currentIssuerKeyDigestHex, name: "current issuer key digest")
        guard keyRotation.currentIssuerKeyDigestHex == issuerKeyDigestHex
                || keyRotation.previousIssuerKeyDigestsHex.contains(issuerKeyDigestHex) else {
            throw SuperNeoProductIntegrationError.unauthorized("trusted context signature key is outside rotation metadata")
        }
        if let next = keyRotation.nextIssuerKeyDigestHex {
            _ = try Digest256(hexDigest: next, name: "next issuer key digest")
        }
        for previous in keyRotation.previousIssuerKeyDigestsHex {
            _ = try Digest256(hexDigest: previous, name: "previous issuer key digest")
        }
        let validFrom = try SuperNeoProductTime.parseUTC(validFromUTC, name: "context validFromUTC")
        let validUntil = try SuperNeoProductTime.parseUTC(validUntilUTC, name: "context validUntilUTC")
        guard validFrom <= now else {
            throw SuperNeoProductIntegrationError.unauthorized("trusted context is not valid yet")
        }
        guard now <= validUntil else {
            throw SuperNeoProductIntegrationError.unauthorized("trusted context has expired")
        }
        try requireNotRevoked(artifactDigest: nil, proofEnvelopeDigest: nil, provenanceDigest: nil)
    }
}

public extension SuperNeoArtifactProvenancePayload {
    func validate() throws {
        guard formatVersion == 1 else {
            throw SuperNeoProductIntegrationError.provenanceRejected("unsupported provenance manifest version")
        }
        guard !issuer.isEmpty else {
            throw SuperNeoProductIntegrationError.provenanceRejected("provenance issuer is required")
        }
        guard !contextID.isEmpty else {
            throw SuperNeoProductIntegrationError.provenanceRejected("provenance context ID is required")
        }
        _ = try Digest256(hexDigest: artifactDigestHex, name: "provenance artifact digest")
        _ = try Digest256(hexDigest: proofEnvelopeDigestHex, name: "provenance proof envelope digest")
        _ = try Digest256(hexDigest: statementDigestHex, name: "provenance statement digest")
        _ = try Digest256(hexDigest: releaseBuildDigestHex, name: "provenance release build digest")
        _ = try SuperNeoProductTime.parseUTC(issuedAtUTC, name: "provenance issuedAtUTC")
    }
}

public extension SuperNeoProductProofIdentity {
    var localReplayDigest: Digest256 {
        var bytes: [UInt8] = []
        appendLengthPrefixedString(expectedContextID, to: &bytes)
        bytes += statementDigest.bytes
        bytes += proofEnvelopeDigest.bytes
        bytes += artifactDigest.bytes
        bytes += provenanceDigest.bytes
        return Digest256.hash(bytes)
    }
}

public enum SuperNeoCanonicalJSON {
    public static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }
}

public enum SuperNeoProductTime {
    public static func nowUTCString() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: Date())
    }

    public static func parseUTC(_ raw: String, name: String) throws -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: raw) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: raw) {
            return date
        }
        throw SuperNeoProductIntegrationError.invalidRequest("\(name) must be an ISO-8601 UTC timestamp")
    }
}

enum SuperNeoProductSignatureVerifier {
    static func verify(
        signature: SuperNeoProductSignature,
        payload: Data,
        trustedKeyDigestsHex: Set<String>,
        description: String
    ) throws -> Digest256 {
        guard signature.algorithm == "ed25519" else {
            throw SuperNeoProductIntegrationError.unauthorized("\(description) signature algorithm is unsupported")
        }
        guard let publicKeyData = Data(base64Encoded: signature.publicKeyBase64),
              let signatureData = Data(base64Encoded: signature.signatureBase64) else {
            throw SuperNeoProductIntegrationError.unauthorized("\(description) signature is not valid base64")
        }
        let publicKeyDigest = Digest256.hash([UInt8](publicKeyData))
        guard signature.publicKeyDigestHex == publicKeyDigest.hexString else {
            throw SuperNeoProductIntegrationError.unauthorized("\(description) public key digest mismatch")
        }
        guard trustedKeyDigestsHex.contains(publicKeyDigest.hexString) else {
            throw SuperNeoProductIntegrationError.unauthorized("\(description) signer is not trusted")
        }
        let publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: publicKeyData)
        guard publicKey.isValidSignature(signatureData, for: payload) else {
            throw SuperNeoProductIntegrationError.unauthorized("\(description) signature is invalid")
        }
        return publicKeyDigest
    }
}

enum SuperNeoJSONDuplicateKeyValidator {
    static func validate(data: Data, artifactName: String) throws {
        var scanner = Scanner(bytes: [UInt8](data), artifactName: artifactName)
        try scanner.validate()
    }

    private struct Scanner {
        let bytes: [UInt8]
        let artifactName: String
        var index = 0

        mutating func validate() throws {
            try parseValue(path: "$")
            skipWhitespace()
            guard index == bytes.count else {
                throw SuperNeoProductIntegrationError.invalidRequest("\(artifactName) JSON contains trailing data")
            }
        }

        private mutating func parseValue(path: String) throws {
            skipWhitespace()
            guard let byte = peek() else {
                throw SuperNeoProductIntegrationError.invalidRequest("\(artifactName) JSON ended unexpectedly")
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
                throw SuperNeoProductIntegrationError.invalidRequest("\(artifactName) JSON contains an invalid value at \(path)")
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
                    throw SuperNeoProductIntegrationError.invalidRequest("\(artifactName) JSON object key must be a string at \(path)")
                }
                let key = try parseString()
                guard seen.insert(key).inserted else {
                    throw SuperNeoProductIntegrationError.invalidRequest("\(artifactName) contains duplicate JSON key '\(key)' at \(path)")
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
            var result = ""
            while let byte = peek() {
                index += 1
                switch byte {
                case UInt8(ascii: "\""):
                    return result
                case UInt8(ascii: "\\"):
                    guard let escaped = peek() else {
                        throw SuperNeoProductIntegrationError.invalidRequest("\(artifactName) JSON string has an unterminated escape")
                    }
                    index += 1
                    switch escaped {
                    case UInt8(ascii: "\""): result.append("\"")
                    case UInt8(ascii: "\\"): result.append("\\")
                    case UInt8(ascii: "/"): result.append("/")
                    case UInt8(ascii: "b"): result.append("\u{08}")
                    case UInt8(ascii: "f"): result.append("\u{0C}")
                    case UInt8(ascii: "n"): result.append("\n")
                    case UInt8(ascii: "r"): result.append("\r")
                    case UInt8(ascii: "t"): result.append("\t")
                    case UInt8(ascii: "u"):
                        let scalarValue = try parseUnicodeEscape()
                        guard let scalar = UnicodeScalar(scalarValue) else {
                            throw SuperNeoProductIntegrationError.invalidRequest("\(artifactName) JSON string contains an invalid unicode scalar")
                        }
                        result.unicodeScalars.append(scalar)
                    default:
                        throw SuperNeoProductIntegrationError.invalidRequest("\(artifactName) JSON string contains an invalid escape")
                    }
                case 0x00...0x1F:
                    throw SuperNeoProductIntegrationError.invalidRequest("\(artifactName) JSON string contains an unescaped control character")
                case 0x00...0x7F:
                    result.unicodeScalars.append(UnicodeScalar(Int(byte))!)
                default:
                    let start = index - 1
                    while let next = peek(), next >= 0x80 {
                        index += 1
                    }
                    guard let value = String(data: Data(bytes[start..<index]), encoding: .utf8) else {
                        throw SuperNeoProductIntegrationError.invalidRequest("\(artifactName) JSON string is not valid UTF-8")
                    }
                    result += value
                }
            }
            throw SuperNeoProductIntegrationError.invalidRequest("\(artifactName) JSON string is unterminated")
        }

        private mutating func parseUnicodeEscape() throws -> UInt32 {
            let high = try parseFourHexDigits()
            guard (0xD800...0xDBFF).contains(high) else {
                if (0xDC00...0xDFFF).contains(high) {
                    throw SuperNeoProductIntegrationError.invalidRequest("\(artifactName) JSON string contains an unpaired low surrogate")
                }
                return high
            }
            guard consumeIfPresent(UInt8(ascii: "\\")), consumeIfPresent(UInt8(ascii: "u")) else {
                throw SuperNeoProductIntegrationError.invalidRequest("\(artifactName) JSON string contains an unpaired high surrogate")
            }
            let low = try parseFourHexDigits()
            guard (0xDC00...0xDFFF).contains(low) else {
                throw SuperNeoProductIntegrationError.invalidRequest("\(artifactName) JSON string contains an invalid surrogate pair")
            }
            return 0x10000 + ((high - 0xD800) << 10) + (low - 0xDC00)
        }

        private mutating func parseFourHexDigits() throws -> UInt32 {
            var value: UInt32 = 0
            for _ in 0..<4 {
                guard let byte = peek(), let digit = hexValue(byte) else {
                    throw SuperNeoProductIntegrationError.invalidRequest("\(artifactName) JSON string contains an invalid unicode escape")
                }
                index += 1
                value = (value << 4) | digit
            }
            return value
        }

        private mutating func consumeNumber() throws {
            if consumeIfPresent(UInt8(ascii: "-")) {
                guard let byte = peek(), (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte) else {
                    throw SuperNeoProductIntegrationError.invalidRequest("\(artifactName) JSON number is invalid")
                }
            }
            if consumeIfPresent(UInt8(ascii: "0")) {
                if let byte = peek(), (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte) {
                    throw SuperNeoProductIntegrationError.invalidRequest("\(artifactName) JSON number has a leading zero")
                }
            } else {
                guard let byte = peek(), (UInt8(ascii: "1")...UInt8(ascii: "9")).contains(byte) else {
                    throw SuperNeoProductIntegrationError.invalidRequest("\(artifactName) JSON number is invalid")
                }
                while isDigit(peek()) {
                    index += 1
                }
            }
            if consumeIfPresent(UInt8(ascii: ".")) {
                guard let byte = peek(), (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte) else {
                    throw SuperNeoProductIntegrationError.invalidRequest("\(artifactName) JSON fractional number is invalid")
                }
                while isDigit(peek()) {
                    index += 1
                }
            }
            if consumeIfPresent(UInt8(ascii: "e")) || consumeIfPresent(UInt8(ascii: "E")) {
                _ = consumeIfPresent(UInt8(ascii: "+")) || consumeIfPresent(UInt8(ascii: "-"))
                guard let byte = peek(), (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte) else {
                    throw SuperNeoProductIntegrationError.invalidRequest("\(artifactName) JSON exponent is invalid")
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
                throw SuperNeoProductIntegrationError.invalidRequest("\(artifactName) JSON syntax error")
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
                    || byte == UInt8(ascii: "\t") {
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
}

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

private func validateDigestList(_ values: [String], name: String) throws -> Set<String> {
    guard !values.isEmpty else {
        throw SuperNeoProductIntegrationError.invalidRequest("\(name) list must not be empty")
    }
    var result = Set<String>()
    for value in values {
        let digest = try Digest256(hexDigest: value, name: name).hexString
        result.insert(digest)
    }
    return result
}

private func appendLengthPrefixedString(_ value: String, to bytes: inout [UInt8]) {
    let utf8 = Array(value.utf8)
    var length = UInt64(utf8.count).littleEndian
    withUnsafeBytes(of: &length) {
        bytes.append(contentsOf: $0)
    }
    bytes.append(contentsOf: utf8)
}
