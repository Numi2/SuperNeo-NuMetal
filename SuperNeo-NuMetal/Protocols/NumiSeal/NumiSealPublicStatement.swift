import Foundation

public struct NumiSealPublicStatement: Equatable, Sendable, SuperNeoByteEncodable {
    public static let domain = Digest256.hash("SuperNeo-NuMetal.numiseal.public-statement.v1")
    public static let version: UInt16 = 10

    public let version: UInt16
    public let profileID: UInt16
    public let shapeDigest: Digest256
    public let statementDigest: Digest256
    public let verifierKeyDigest: Digest256
    public let transcriptDomain: Digest256
    public let obligationCount: Int
    public let obligationRoot: Digest256
    public let laneSummaryRoot: Digest256
    public let laneSummaries: [NumiSealLaneSummary]

    public init(
        canonicalization: NumiSealCanonicalizationResult,
        policy: NumiSealAcceptancePolicy
    ) throws {
        try Self.validate(canonicalization: canonicalization, policy: policy)
        self.version = Self.version
        self.profileID = policy.profileID
        self.shapeDigest = policy.shapeDigest
        self.statementDigest = policy.statementDigest
        self.verifierKeyDigest = policy.verifierKeyDigest
        self.transcriptDomain = policy.transcriptDomain
        self.obligationCount = canonicalization.obligations.count
        self.obligationRoot = canonicalization.obligationRoot
        self.laneSummaryRoot = canonicalization.laneSummaryRoot
        self.laneSummaries = canonicalization.laneSummaries
    }

    public init(bytes: [UInt8]) throws {
        var reader = ByteReader(bytes)
        let domain = try Digest256(reader.readData(count: Digest256.byteCount))
        guard domain == Self.domain else {
            throw SuperNeoError.invalidEncoding("NumiSeal public statement domain mismatch")
        }
        let version = try reader.readUInt16()
        guard version == Self.version else {
            throw SuperNeoError.invalidEncoding("unsupported NumiSeal public statement version")
        }
        let profileID = try reader.readUInt16()
        let shapeDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        let statementDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        let verifierKeyDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        let transcriptDomain = try Digest256(reader.readData(count: Digest256.byteCount))
        let obligationCount = try reader.readCount(
            maximum: NumiSealWireLimits.maximumObligationCount,
            name: "NumiSeal obligation"
        )
        let obligationRoot = try Digest256(reader.readData(count: Digest256.byteCount))
        let laneSummaryRoot = try Digest256(reader.readData(count: Digest256.byteCount))
        let laneCount = try reader.readCount(
            maximum: NumiSealWireLimits.maximumLaneCount,
            name: "NumiSeal lane summary"
        )
        let laneSummaries = try (0..<laneCount).map { _ in
            try reader.readNumiSealLaneSummary()
        }
        try reader.finish()

        try Self.validate(
            profileID: profileID,
            shapeDigest: shapeDigest,
            verifierKeyDigest: verifierKeyDigest,
            obligationCount: obligationCount,
            laneSummaryRoot: laneSummaryRoot,
            laneSummaries: laneSummaries
        )

        self.version = version
        self.profileID = profileID
        self.shapeDigest = shapeDigest
        self.statementDigest = statementDigest
        self.verifierKeyDigest = verifierKeyDigest
        self.transcriptDomain = transcriptDomain
        self.obligationCount = obligationCount
        self.obligationRoot = obligationRoot
        self.laneSummaryRoot = laneSummaryRoot
        self.laneSummaries = laneSummaries
    }

    public var superNeoBytes: [UInt8] {
        Self.domain.superNeoBytes
            + numiSealEncodeUInt16(version)
            + numiSealEncodeUInt16(profileID)
            + shapeDigest.superNeoBytes
            + statementDigest.superNeoBytes
            + verifierKeyDigest.superNeoBytes
            + transcriptDomain.superNeoBytes
            + numiSealEncodeCount(obligationCount)
            + obligationRoot.superNeoBytes
            + laneSummaryRoot.superNeoBytes
            + numiSealEncodeCount(laneSummaries.count)
            + laneSummaries.flatMap(\.superNeoBytes)
    }

    public var digest: Digest256 {
        NumiSealEncoding.digest(
            label: "numiseal.public-statement.v1",
            bytes: superNeoBytes
        )
    }

    public func validate(against policy: NumiSealAcceptancePolicy) throws {
        guard profileID == policy.profileID else {
            throw SuperNeoError.verificationFailed("NumiSeal public statement profile mismatch")
        }
        guard shapeDigest == policy.shapeDigest else {
            throw SuperNeoError.verificationFailed("NumiSeal public statement shape mismatch")
        }
        guard statementDigest == policy.statementDigest else {
            throw SuperNeoError.verificationFailed("NumiSeal public statement statement mismatch")
        }
        guard verifierKeyDigest == policy.verifierKeyDigest else {
            throw SuperNeoError.verificationFailed("NumiSeal public statement verifier key mismatch")
        }
        guard transcriptDomain == policy.transcriptDomain else {
            throw SuperNeoError.verificationFailed("NumiSeal public statement transcript domain mismatch")
        }
        for summary in laneSummaries {
            guard policy.acceptedLaneIDs.contains(summary.laneKey.laneID) else {
                throw SuperNeoError.verificationFailed("NumiSeal public statement lane is not accepted by policy")
            }
        }
    }

    static func validate(
        canonicalization: NumiSealCanonicalizationResult,
        policy: NumiSealAcceptancePolicy
    ) throws {
        guard !canonicalization.obligations.isEmpty else {
            throw SuperNeoError.invalidParameter("NumiSeal public statement requires obligations")
        }
        guard !canonicalization.laneSummaries.isEmpty else {
            throw SuperNeoError.invalidParameter("NumiSeal public statement requires lane summaries")
        }
        let expectedObligationRoot = NumiSealEncoding.root(
            label: "numiseal.obligation-root.v1",
            leaves: canonicalization.obligations.map(\.obligationDigest)
        )
        guard canonicalization.obligationRoot == expectedObligationRoot else {
            throw SuperNeoError.invalidParameter("NumiSeal obligation root mismatch")
        }
        try validate(
            profileID: policy.profileID,
            shapeDigest: policy.shapeDigest,
            verifierKeyDigest: policy.verifierKeyDigest,
            obligationCount: canonicalization.obligations.count,
            laneSummaryRoot: canonicalization.laneSummaryRoot,
            laneSummaries: canonicalization.laneSummaries
        )
        let statement = NumiSealPublicStatement(
            uncheckedProfileID: policy.profileID,
            shapeDigest: policy.shapeDigest,
            statementDigest: policy.statementDigest,
            verifierKeyDigest: policy.verifierKeyDigest,
            transcriptDomain: policy.transcriptDomain,
            obligationCount: canonicalization.obligations.count,
            obligationRoot: canonicalization.obligationRoot,
            laneSummaryRoot: canonicalization.laneSummaryRoot,
            laneSummaries: canonicalization.laneSummaries
        )
        try statement.validate(against: policy)
    }

    private init(
        uncheckedProfileID profileID: UInt16,
        shapeDigest: Digest256,
        statementDigest: Digest256,
        verifierKeyDigest: Digest256,
        transcriptDomain: Digest256,
        obligationCount: Int,
        obligationRoot: Digest256,
        laneSummaryRoot: Digest256,
        laneSummaries: [NumiSealLaneSummary]
    ) {
        self.version = Self.version
        self.profileID = profileID
        self.shapeDigest = shapeDigest
        self.statementDigest = statementDigest
        self.verifierKeyDigest = verifierKeyDigest
        self.transcriptDomain = transcriptDomain
        self.obligationCount = obligationCount
        self.obligationRoot = obligationRoot
        self.laneSummaryRoot = laneSummaryRoot
        self.laneSummaries = laneSummaries
    }

    private static func validate(
        profileID: UInt16,
        shapeDigest: Digest256,
        verifierKeyDigest: Digest256,
        obligationCount: Int,
        laneSummaryRoot: Digest256,
        laneSummaries: [NumiSealLaneSummary]
    ) throws {
        guard obligationCount > 0 else {
            throw SuperNeoError.invalidEncoding("NumiSeal public statement cannot be empty")
        }
        guard !laneSummaries.isEmpty else {
            throw SuperNeoError.invalidEncoding("NumiSeal public statement requires lane summaries")
        }
        guard laneSummaries.count <= obligationCount else {
            throw SuperNeoError.invalidEncoding("NumiSeal lane summary count exceeds obligation count")
        }

        var summedObligations = 0
        var previousKeyBytes: [UInt8]?
        for summary in laneSummaries {
            guard summary.laneKey.profileID == profileID else {
                throw SuperNeoError.invalidEncoding("NumiSeal lane summary profile mismatch")
            }
            guard summary.laneKey.shapeDigest == shapeDigest else {
                throw SuperNeoError.invalidEncoding("NumiSeal lane summary shape mismatch")
            }
            guard summary.laneKey.verifierKeyDigest == verifierKeyDigest else {
                throw SuperNeoError.invalidEncoding("NumiSeal lane summary verifier key mismatch")
            }
            if let previousKeyBytes {
                guard previousKeyBytes.lexicographicallyPrecedes(summary.laneKey.superNeoBytes) else {
                    throw SuperNeoError.invalidEncoding("NumiSeal lane summaries must be strictly sorted")
                }
            }
            let summaryBytes = summary.laneKey.superNeoBytes
                + numiSealEncodeCount(summary.obligationCount)
                + summary.laneObligationRoot.superNeoBytes
            guard summary.laneSummaryDigest == NumiSealEncoding.digest(
                label: "numiseal.lane-summary.v1",
                bytes: summaryBytes
            ) else {
                throw SuperNeoError.invalidEncoding("NumiSeal lane summary digest mismatch")
            }
            summedObligations += summary.obligationCount
            previousKeyBytes = summary.laneKey.superNeoBytes
        }
        guard summedObligations == obligationCount else {
            throw SuperNeoError.invalidEncoding("NumiSeal lane summaries do not cover all obligations")
        }
        let expectedLaneSummaryRoot = NumiSealEncoding.root(
            label: "numiseal.lane-summary-root.v1",
            leaves: laneSummaries.map(\.laneSummaryDigest)
        )
        guard laneSummaryRoot == expectedLaneSummaryRoot else {
            throw SuperNeoError.invalidEncoding("NumiSeal lane summary root mismatch")
        }
    }
}
