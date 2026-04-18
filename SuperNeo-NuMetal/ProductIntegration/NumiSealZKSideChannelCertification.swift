import Foundation

public enum NumiSealZKSideChannelCertificationLevel: String, Codable, Equatable, Sendable, Comparable {
    case correctnessOnly = "correctness-only"
    case constantTraceReviewed = "constant-trace-reviewed"
    case productionSideChannelCleared = "production-side-channel-cleared"

    public static func < (
        lhs: NumiSealZKSideChannelCertificationLevel,
        rhs: NumiSealZKSideChannelCertificationLevel
    ) -> Bool {
        lhs.rank < rhs.rank
    }

    private var rank: Int {
        switch self {
        case .correctnessOnly:
            return 0
        case .constantTraceReviewed:
            return 1
        case .productionSideChannelCleared:
            return 2
        }
    }
}

public struct SuperNeoTrustedNumiSealZKContext: Codable, Equatable, Sendable {
    public let acceptedZKModes: [String]
    public let acceptedSealModes: [String]
    public let acceptedMetalModes: [String]
    public let acceptedExecutionPolicies: [String]
    public let allowedLeakageDigestsHex: [String]
    public let allowedProofBodyVersions: [UInt16]
    public let allowedMaskedResidualStatementVersions: [UInt16]
    public let minimumSideChannelCertificationLevel: NumiSealZKSideChannelCertificationLevel

    public init(
        acceptedZKModes: [String] = [NumiSealZK.maskedDigitTensorMode],
        acceptedSealModes: [String] = [NumiSealZK.sealMode],
        acceptedMetalModes: [String] = [
            "cpu-reference",
            "secret-bearing-metal-cpu-redundant",
            "secret-bearing-metal-accelerated"
        ],
        acceptedExecutionPolicies: [String] = [
            NumiSealProvingExecutionPolicy.zkHighAssuranceCPU.rawValue,
            NumiSealProvingExecutionPolicy.zkRedundantMetal.rawValue,
            NumiSealProvingExecutionPolicy.defaultProduct.rawValue
        ],
        allowedLeakageDigestsHex: [String],
        allowedProofBodyVersions: [UInt16] = [NumiSealZKProof.bodyVersion],
        allowedMaskedResidualStatementVersions: [UInt16] = [NumiSealZKMaskedResidualStatement.version],
        minimumSideChannelCertificationLevel: NumiSealZKSideChannelCertificationLevel = .correctnessOnly
    ) {
        self.acceptedZKModes = acceptedZKModes
        self.acceptedSealModes = acceptedSealModes
        self.acceptedMetalModes = acceptedMetalModes
        self.acceptedExecutionPolicies = acceptedExecutionPolicies
        self.allowedLeakageDigestsHex = allowedLeakageDigestsHex
        self.allowedProofBodyVersions = allowedProofBodyVersions
        self.allowedMaskedResidualStatementVersions = allowedMaskedResidualStatementVersions
        self.minimumSideChannelCertificationLevel = minimumSideChannelCertificationLevel
    }

    private enum CodingKeys: String, CodingKey {
        case acceptedZKModes
        case acceptedSealModes
        case acceptedMetalModes
        case acceptedExecutionPolicies
        case allowedLeakageDigestsHex
        case allowedProofBodyVersions
        case allowedMaskedResidualStatementVersions
        case minimumSideChannelCertificationLevel
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.acceptedZKModes = try container.decode([String].self, forKey: .acceptedZKModes)
        self.acceptedSealModes = try container.decode([String].self, forKey: .acceptedSealModes)
        self.acceptedMetalModes = try container.decode([String].self, forKey: .acceptedMetalModes)
        self.acceptedExecutionPolicies = try container.decode([String].self, forKey: .acceptedExecutionPolicies)
        self.allowedLeakageDigestsHex = try container.decode([String].self, forKey: .allowedLeakageDigestsHex)
        self.allowedProofBodyVersions = try container.decode([UInt16].self, forKey: .allowedProofBodyVersions)
        self.allowedMaskedResidualStatementVersions = try container.decode(
            [UInt16].self,
            forKey: .allowedMaskedResidualStatementVersions
        )
        self.minimumSideChannelCertificationLevel = try container.decodeIfPresent(
            NumiSealZKSideChannelCertificationLevel.self,
            forKey: .minimumSideChannelCertificationLevel
        ) ?? .correctnessOnly
    }
}

public struct NumiSealZKSideChannelCertificationPayload: Codable, Equatable, Sendable {
    public let formatVersion: Int
    public let certificateID: String
    public let issuer: String
    public let contextID: String
    public let releaseBuildDigestHex: String
    public let certifiedLevel: NumiSealZKSideChannelCertificationLevel
    public let proofKind: String
    public let sealMode: String
    public let zkMode: String
    public let metalMode: String
    public let executionPolicy: String
    public let leakageDigestHex: String
    public let zkProofBodyVersion: UInt16
    public let zkMaskedResidualStatementVersion: UInt16
    public let metalWorkspaceFeatureDigestHex: String
    public let reviewedKernelNames: [String]
    public let reviewedStageNames: [String]
    public let evidenceDigestsHex: [String]
    public let benchmarkReportDigestHex: String?
    public let issuedAtUTC: String
    public let validUntilUTC: String

    public init(
        formatVersion: Int = 1,
        certificateID: String,
        issuer: String,
        contextID: String,
        releaseBuildDigestHex: String,
        certifiedLevel: NumiSealZKSideChannelCertificationLevel,
        proofKind: String = NumiSealProductArtifact.zkProofKind,
        sealMode: String = NumiSealZK.sealMode,
        zkMode: String = NumiSealZK.maskedDigitTensorMode,
        metalMode: String,
        executionPolicy: String,
        leakageDigestHex: String,
        zkProofBodyVersion: UInt16 = NumiSealZKProof.bodyVersion,
        zkMaskedResidualStatementVersion: UInt16 = NumiSealZKMaskedResidualStatement.version,
        metalWorkspaceFeatureDigestHex: String,
        reviewedKernelNames: [String],
        reviewedStageNames: [String],
        evidenceDigestsHex: [String],
        benchmarkReportDigestHex: String? = nil,
        issuedAtUTC: String,
        validUntilUTC: String
    ) {
        self.formatVersion = formatVersion
        self.certificateID = certificateID
        self.issuer = issuer
        self.contextID = contextID
        self.releaseBuildDigestHex = releaseBuildDigestHex
        self.certifiedLevel = certifiedLevel
        self.proofKind = proofKind
        self.sealMode = sealMode
        self.zkMode = zkMode
        self.metalMode = metalMode
        self.executionPolicy = executionPolicy
        self.leakageDigestHex = leakageDigestHex
        self.zkProofBodyVersion = zkProofBodyVersion
        self.zkMaskedResidualStatementVersion = zkMaskedResidualStatementVersion
        self.metalWorkspaceFeatureDigestHex = metalWorkspaceFeatureDigestHex
        self.reviewedKernelNames = reviewedKernelNames
        self.reviewedStageNames = reviewedStageNames
        self.evidenceDigestsHex = evidenceDigestsHex
        self.benchmarkReportDigestHex = benchmarkReportDigestHex
        self.issuedAtUTC = issuedAtUTC
        self.validUntilUTC = validUntilUTC
    }
}

public struct SuperNeoSignedNumiSealZKSideChannelCertificate: Codable, Equatable, Sendable {
    public let payload: NumiSealZKSideChannelCertificationPayload
    public let signature: SuperNeoProductSignature

    public init(
        payload: NumiSealZKSideChannelCertificationPayload,
        signature: SuperNeoProductSignature
    ) {
        self.payload = payload
        self.signature = signature
    }

    public static func loadVerified(
        from url: URL,
        trustedIssuerKeyDigestsHex: Set<String>,
        now: Date = Date()
    ) throws -> SuperNeoVerifiedNumiSealZKSideChannelCertificate {
        let data = try SuperNeoLocalFileSecurity.readSecureRegularFile(
            url,
            description: "NumiSealZK side-channel certificate"
        )
        try SuperNeoJSONDuplicateKeyValidator.validate(
            data: data,
            artifactName: "NumiSealZK side-channel certificate"
        )
        let certificate = try JSONDecoder().decode(Self.self, from: data)
        return try certificate.verified(
            trustedIssuerKeyDigestsHex: trustedIssuerKeyDigestsHex,
            now: now
        )
    }

    public func verified(
        trustedIssuerKeyDigestsHex: Set<String>,
        now: Date = Date()
    ) throws -> SuperNeoVerifiedNumiSealZKSideChannelCertificate {
        let payloadBytes = try SuperNeoCanonicalJSON.encode(payload)
        let issuerKeyDigest = try SuperNeoProductSignatureVerifier.verify(
            signature: signature,
            payload: payloadBytes,
            trustedKeyDigestsHex: trustedIssuerKeyDigestsHex,
            description: "NumiSealZK side-channel certificate"
        )
        try payload.validate(now: now)
        return SuperNeoVerifiedNumiSealZKSideChannelCertificate(
            payload: payload,
            certificateDigest: Digest256.hash([UInt8](payloadBytes)),
            issuerKeyDigest: issuerKeyDigest
        )
    }
}

public struct SuperNeoVerifiedNumiSealZKSideChannelCertificate: Equatable, Sendable {
    public let payload: NumiSealZKSideChannelCertificationPayload
    public let certificateDigest: Digest256
    public let issuerKeyDigest: Digest256

    public init(
        payload: NumiSealZKSideChannelCertificationPayload,
        certificateDigest: Digest256,
        issuerKeyDigest: Digest256
    ) {
        self.payload = payload
        self.certificateDigest = certificateDigest
        self.issuerKeyDigest = issuerKeyDigest
    }
}

public extension NumiSealZKSideChannelCertificationPayload {
    func validate(now: Date = Date()) throws {
        guard formatVersion == 1 else {
            throw SuperNeoProductIntegrationError.invalidRequest(
                "unsupported NumiSealZK side-channel certificate version"
            )
        }
        guard !certificateID.isEmpty else {
            throw SuperNeoProductIntegrationError.invalidRequest(
                "NumiSealZK side-channel certificate ID is required"
            )
        }
        guard !issuer.isEmpty else {
            throw SuperNeoProductIntegrationError.invalidRequest(
                "NumiSealZK side-channel certificate issuer is required"
            )
        }
        guard !contextID.isEmpty else {
            throw SuperNeoProductIntegrationError.invalidRequest(
                "NumiSealZK side-channel certificate context ID is required"
            )
        }
        guard proofKind == NumiSealProductArtifact.zkProofKind else {
            throw SuperNeoProductIntegrationError.invalidRequest(
                "NumiSealZK side-channel certificate must bind numiseal-zk proof kind"
            )
        }
        guard sealMode == NumiSealZK.sealMode else {
            throw SuperNeoProductIntegrationError.invalidRequest(
                "NumiSealZK side-channel certificate seal mode is unsupported"
            )
        }
        guard zkMode == NumiSealZK.maskedDigitTensorMode else {
            throw SuperNeoProductIntegrationError.invalidRequest(
                "NumiSealZK side-channel certificate ZK mode is unsupported"
            )
        }
        guard !reviewedKernelNames.isEmpty else {
            throw SuperNeoProductIntegrationError.invalidRequest(
                "NumiSealZK side-channel certificate must list reviewed kernels"
            )
        }
        guard !reviewedStageNames.isEmpty else {
            throw SuperNeoProductIntegrationError.invalidRequest(
                "NumiSealZK side-channel certificate must list reviewed stages"
            )
        }
        guard !evidenceDigestsHex.isEmpty else {
            throw SuperNeoProductIntegrationError.invalidRequest(
                "NumiSealZK side-channel certificate must include evidence digests"
            )
        }
        _ = try Digest256(hexDigest: releaseBuildDigestHex, name: "side-channel release build digest")
        _ = try Digest256(hexDigest: leakageDigestHex, name: "side-channel leakage digest")
        if metalWorkspaceFeatureDigestHex != "none" {
            _ = try Digest256(
                hexDigest: metalWorkspaceFeatureDigestHex,
                name: "side-channel Metal workspace feature digest"
            )
        }
        for digest in evidenceDigestsHex {
            _ = try Digest256(hexDigest: digest, name: "side-channel evidence digest")
        }
        if let benchmarkReportDigestHex {
            _ = try Digest256(hexDigest: benchmarkReportDigestHex, name: "side-channel benchmark report digest")
        }
        let issuedAt = try SuperNeoProductTime.parseUTC(
            issuedAtUTC,
            name: "side-channel certificate issuedAtUTC"
        )
        let validUntil = try SuperNeoProductTime.parseUTC(
            validUntilUTC,
            name: "side-channel certificate validUntilUTC"
        )
        guard issuedAt <= now else {
            throw SuperNeoProductIntegrationError.unauthorized(
                "NumiSealZK side-channel certificate is not valid yet"
            )
        }
        guard now <= validUntil else {
            throw SuperNeoProductIntegrationError.unauthorized(
                "NumiSealZK side-channel certificate has expired"
            )
        }
    }
}

public extension SuperNeoTrustedNumiSealZKContext {
    func validate() throws {
        guard !acceptedZKModes.isEmpty else {
            throw SuperNeoProductIntegrationError.invalidRequest(
                "trusted context NumiSealZK policy must accept at least one ZK mode"
            )
        }
        guard !acceptedSealModes.isEmpty else {
            throw SuperNeoProductIntegrationError.invalidRequest(
                "trusted context NumiSealZK policy must accept at least one seal mode"
            )
        }
        guard !acceptedMetalModes.isEmpty else {
            throw SuperNeoProductIntegrationError.invalidRequest(
                "trusted context NumiSealZK policy must accept at least one Metal mode"
            )
        }
        guard !acceptedExecutionPolicies.isEmpty else {
            throw SuperNeoProductIntegrationError.invalidRequest(
                "trusted context NumiSealZK policy must accept at least one execution policy"
            )
        }
        guard !allowedLeakageDigestsHex.isEmpty else {
            throw SuperNeoProductIntegrationError.invalidRequest(
                "trusted context NumiSealZK policy must pin at least one leakage digest"
            )
        }
        guard !allowedProofBodyVersions.isEmpty else {
            throw SuperNeoProductIntegrationError.invalidRequest(
                "trusted context NumiSealZK policy must pin proof body versions"
            )
        }
        guard !allowedMaskedResidualStatementVersions.isEmpty else {
            throw SuperNeoProductIntegrationError.invalidRequest(
                "trusted context NumiSealZK policy must pin masked residual statement versions"
            )
        }
        for digest in allowedLeakageDigestsHex {
            _ = try Digest256(hexDigest: digest, name: "trusted NumiSealZK leakage digest")
        }
    }

    func validate(
        artifact: NumiSealProductArtifact,
        contextID: String,
        releaseBuildDigest: Digest256,
        certificate: SuperNeoVerifiedNumiSealZKSideChannelCertificate?
    ) throws {
        guard artifact.proofKind == NumiSealProductArtifact.zkProofKind,
              artifact.sealMode == NumiSealZK.sealMode,
              artifact.zkMode == NumiSealZK.maskedDigitTensorMode else {
            throw SuperNeoProductIntegrationError.missingExpectedContext(
                "trusted NumiSealZK policy requires a masked NumiSealZK product artifact"
            )
        }
        guard acceptedZKModes.contains(artifact.zkMode) else {
            throw SuperNeoProductIntegrationError.missingExpectedContext(
                "NumiSealZK mode is not accepted by trusted context"
            )
        }
        guard acceptedSealModes.contains(artifact.sealMode) else {
            throw SuperNeoProductIntegrationError.missingExpectedContext(
                "NumiSealZK seal mode is not accepted by trusted context"
            )
        }
        guard acceptedMetalModes.contains(artifact.metalMode) else {
            throw SuperNeoProductIntegrationError.missingExpectedContext(
                "NumiSealZK Metal mode is not accepted by trusted context"
            )
        }
        guard acceptedExecutionPolicies.contains(artifact.executionPolicy) else {
            throw SuperNeoProductIntegrationError.missingExpectedContext(
                "NumiSealZK execution policy is not accepted by trusted context"
            )
        }
        guard allowedLeakageDigestsHex.contains(try artifact.requiredExecutionMetadata("zkLeakageDigest")) else {
            throw SuperNeoProductIntegrationError.missingExpectedContext(
                "NumiSealZK leakage digest is not accepted by trusted context"
            )
        }
        let proofBodyVersion = try artifact.requiredUInt16ExecutionMetadata("zkProofBodyVersion")
        guard allowedProofBodyVersions.contains(proofBodyVersion) else {
            throw SuperNeoProductIntegrationError.missingExpectedContext(
                "NumiSealZK proof body version is not accepted by trusted context"
            )
        }
        let maskedResidualVersion = try artifact.requiredUInt16ExecutionMetadata(
            "zkMaskedResidualStatementVersion"
        )
        guard allowedMaskedResidualStatementVersions.contains(maskedResidualVersion) else {
            throw SuperNeoProductIntegrationError.missingExpectedContext(
                "NumiSealZK masked residual statement version is not accepted by trusted context"
            )
        }
        guard let certificate else { return }
        try validateCertificate(
            certificate,
            artifact: artifact,
            contextID: contextID,
            releaseBuildDigest: releaseBuildDigest
        )
    }

    private func validateCertificate(
        _ certificate: SuperNeoVerifiedNumiSealZKSideChannelCertificate,
        artifact: NumiSealProductArtifact,
        contextID: String,
        releaseBuildDigest: Digest256
    ) throws {
        guard certificate.payload.contextID == contextID else {
            throw SuperNeoProductIntegrationError.missingExpectedContext(
                "NumiSealZK side-channel certificate context does not match trusted context"
            )
        }
        guard certificate.payload.releaseBuildDigestHex == releaseBuildDigest.hexString else {
            throw SuperNeoProductIntegrationError.missingExpectedContext(
                "NumiSealZK side-channel certificate release build digest mismatch"
            )
        }
        guard certificate.payload.proofKind == artifact.proofKind,
              certificate.payload.sealMode == artifact.sealMode,
              certificate.payload.zkMode == artifact.zkMode,
              certificate.payload.metalMode == artifact.metalMode,
              certificate.payload.executionPolicy == artifact.executionPolicy else {
            throw SuperNeoProductIntegrationError.missingExpectedContext(
                "NumiSealZK side-channel certificate does not bind artifact proof policy"
            )
        }
        let artifactLeakageDigest = try artifact.requiredExecutionMetadata("zkLeakageDigest")
        guard certificate.payload.leakageDigestHex == artifactLeakageDigest else {
            throw SuperNeoProductIntegrationError.missingExpectedContext(
                "NumiSealZK side-channel certificate leakage digest mismatch"
            )
        }
        let artifactProofBodyVersion = try artifact.requiredUInt16ExecutionMetadata("zkProofBodyVersion")
        let artifactMaskedResidualStatementVersion = try artifact.requiredUInt16ExecutionMetadata(
            "zkMaskedResidualStatementVersion"
        )
        guard certificate.payload.zkProofBodyVersion == artifactProofBodyVersion,
              certificate.payload.zkMaskedResidualStatementVersion == artifactMaskedResidualStatementVersion else {
            throw SuperNeoProductIntegrationError.missingExpectedContext(
                "NumiSealZK side-channel certificate proof body version mismatch"
            )
        }
        let artifactMetalWorkspaceFeatureDigest = try artifact.requiredExecutionMetadata(
            "metalWorkspaceFeatureDigest"
        )
        guard certificate.payload.metalWorkspaceFeatureDigestHex == artifactMetalWorkspaceFeatureDigest else {
            throw SuperNeoProductIntegrationError.missingExpectedContext(
                "NumiSealZK side-channel certificate Metal workspace digest mismatch"
            )
        }
    }
}

extension NumiSealProductArtifact {
    func requiredExecutionMetadata(_ key: String) throws -> String {
        guard let value = executionPolicyMetadata[key], !value.isEmpty else {
            throw SuperNeoProductIntegrationError.missingExpectedContext(
                "NumiSeal product artifact is missing execution metadata: \(key)"
            )
        }
        return value
    }

    func requiredUInt16ExecutionMetadata(_ key: String) throws -> UInt16 {
        let raw = try requiredExecutionMetadata(key)
        guard let value = UInt16(raw) else {
            throw SuperNeoProductIntegrationError.missingExpectedContext(
                "NumiSeal product artifact execution metadata is not a UInt16: \(key)"
            )
        }
        return value
    }
}
