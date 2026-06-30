import Foundation

public enum SuperNeoRevenueSKU: String, Codable, Equatable, Sendable {
    case acceptedNumiSealZKVerification = "accepted-numiseal-zk-verification"
    case issuedQROChallenge = "issued-qro-challenge"
    case verifierSeatMonthly = "verifier-seat-monthly"
    case supportContractMonthly = "support-contract-monthly"
}

public struct SuperNeoRevenueRateCard: Codable, Equatable, Sendable {
    public let acceptedNumiSealZKVerificationMicrosUSD: Int64
    public let issuedQROChallengeMicrosUSD: Int64
    public let verifierSeatMonthlyMicrosUSD: Int64
    public let supportContractMonthlyMicrosUSD: Int64
    public let targetGrossMarginBasisPoints: Int

    public init(
        acceptedNumiSealZKVerificationMicrosUSD: Int64,
        issuedQROChallengeMicrosUSD: Int64,
        verifierSeatMonthlyMicrosUSD: Int64,
        supportContractMonthlyMicrosUSD: Int64,
        targetGrossMarginBasisPoints: Int = 7_000
    ) throws {
        guard acceptedNumiSealZKVerificationMicrosUSD > 0 else {
            throw SuperNeoProductIntegrationError.invalidRequest("accepted verification unit price must be positive")
        }
        guard issuedQROChallengeMicrosUSD >= 0,
              verifierSeatMonthlyMicrosUSD >= 0,
              supportContractMonthlyMicrosUSD >= 0 else {
            throw SuperNeoProductIntegrationError.invalidRequest("non-verification unit prices must not be negative")
        }
        guard (0...10_000).contains(targetGrossMarginBasisPoints) else {
            throw SuperNeoProductIntegrationError.invalidRequest("target gross margin basis points must be between 0 and 10000")
        }
        self.acceptedNumiSealZKVerificationMicrosUSD = acceptedNumiSealZKVerificationMicrosUSD
        self.issuedQROChallengeMicrosUSD = issuedQROChallengeMicrosUSD
        self.verifierSeatMonthlyMicrosUSD = verifierSeatMonthlyMicrosUSD
        self.supportContractMonthlyMicrosUSD = supportContractMonthlyMicrosUSD
        self.targetGrossMarginBasisPoints = targetGrossMarginBasisPoints
    }

    public func unitPriceMicrosUSD(for sku: SuperNeoRevenueSKU) -> Int64 {
        switch sku {
        case .acceptedNumiSealZKVerification:
            return acceptedNumiSealZKVerificationMicrosUSD
        case .issuedQROChallenge:
            return issuedQROChallengeMicrosUSD
        case .verifierSeatMonthly:
            return verifierSeatMonthlyMicrosUSD
        case .supportContractMonthly:
            return supportContractMonthlyMicrosUSD
        }
    }
}

public struct SuperNeoRevenueCostBasis: Codable, Equatable, Sendable {
    public let verificationComputeMicrosUSD: Int64
    public let artifactStorageMicrosUSD: Int64
    public let artifactEgressMicrosUSD: Int64
    public let qroServiceMicrosUSD: Int64
    public let totalMicrosUSD: Int64

    public init(
        verificationComputeMicrosUSD: Int64,
        artifactStorageMicrosUSD: Int64,
        artifactEgressMicrosUSD: Int64,
        qroServiceMicrosUSD: Int64
    ) throws {
        guard verificationComputeMicrosUSD >= 0,
              artifactStorageMicrosUSD >= 0,
              artifactEgressMicrosUSD >= 0,
              qroServiceMicrosUSD >= 0 else {
            throw SuperNeoProductIntegrationError.invalidRequest("revenue cost basis values must not be negative")
        }
        self.verificationComputeMicrosUSD = verificationComputeMicrosUSD
        self.artifactStorageMicrosUSD = artifactStorageMicrosUSD
        self.artifactEgressMicrosUSD = artifactEgressMicrosUSD
        self.qroServiceMicrosUSD = qroServiceMicrosUSD
        self.totalMicrosUSD = try Self.checkedTotalMicrosUSD([
            verificationComputeMicrosUSD,
            artifactStorageMicrosUSD,
            artifactEgressMicrosUSD,
            qroServiceMicrosUSD
        ])
    }

    private static func checkedTotalMicrosUSD(_ values: [Int64]) throws -> Int64 {
        try values.reduce(0) { partial, value in
            let result = partial.addingReportingOverflow(value)
            guard !result.overflow else {
                throw SuperNeoProductIntegrationError.invalidRequest("revenue cost basis overflows Int64 micros")
            }
            return result.partialValue
        }
    }
}

public struct SuperNeoBillableUsageEvent: Codable, Equatable, Sendable {
    public let formatVersion: Int
    public let eventDigestHex: String
    public let customerID: String
    public let sku: SuperNeoRevenueSKU
    public let quantity: UInt64
    public let unitRevenueMicrosUSD: Int64
    public let totalRevenueMicrosUSD: Int64
    public let estimatedUnitCostMicrosUSD: Int64
    public let estimatedTotalCostMicrosUSD: Int64
    public let grossMarginBasisPoints: Int
    public let targetGrossMarginBasisPoints: Int
    public let contextID: String
    public let artifactDigestHex: String
    public let proofEnvelopeDigestHex: String
    public let provenanceDigestHex: String
    public let statementDigestHex: String
    public let issuedQROChallengeDigestHex: String
    public let releaseBuildDigestHex: String

    public init(
        formatVersion: Int = 1,
        eventDigestHex: String,
        customerID: String,
        sku: SuperNeoRevenueSKU,
        quantity: UInt64,
        unitRevenueMicrosUSD: Int64,
        totalRevenueMicrosUSD: Int64,
        estimatedUnitCostMicrosUSD: Int64,
        estimatedTotalCostMicrosUSD: Int64,
        grossMarginBasisPoints: Int,
        targetGrossMarginBasisPoints: Int,
        contextID: String,
        artifactDigestHex: String,
        proofEnvelopeDigestHex: String,
        provenanceDigestHex: String,
        statementDigestHex: String,
        issuedQROChallengeDigestHex: String,
        releaseBuildDigestHex: String
    ) {
        self.formatVersion = formatVersion
        self.eventDigestHex = eventDigestHex
        self.customerID = customerID
        self.sku = sku
        self.quantity = quantity
        self.unitRevenueMicrosUSD = unitRevenueMicrosUSD
        self.totalRevenueMicrosUSD = totalRevenueMicrosUSD
        self.estimatedUnitCostMicrosUSD = estimatedUnitCostMicrosUSD
        self.estimatedTotalCostMicrosUSD = estimatedTotalCostMicrosUSD
        self.grossMarginBasisPoints = grossMarginBasisPoints
        self.targetGrossMarginBasisPoints = targetGrossMarginBasisPoints
        self.contextID = contextID
        self.artifactDigestHex = artifactDigestHex
        self.proofEnvelopeDigestHex = proofEnvelopeDigestHex
        self.provenanceDigestHex = provenanceDigestHex
        self.statementDigestHex = statementDigestHex
        self.issuedQROChallengeDigestHex = issuedQROChallengeDigestHex
        self.releaseBuildDigestHex = releaseBuildDigestHex
    }

    public var clearsTargetGrossMargin: Bool {
        grossMarginBasisPoints >= targetGrossMarginBasisPoints
    }
}

public enum SuperNeoRevenueLogic {
    public static func billableAcceptedVerificationEvent(
        customerID: String,
        auditEvent: SuperNeoAuditLogEvent,
        rateCard: SuperNeoRevenueRateCard,
        costBasis: SuperNeoRevenueCostBasis,
        quantity: UInt64 = 1
    ) throws -> SuperNeoBillableUsageEvent {
        guard !customerID.isEmpty else {
            throw SuperNeoProductIntegrationError.invalidRequest("billable customer ID is required")
        }
        guard quantity > 0 else {
            throw SuperNeoProductIntegrationError.invalidRequest("billable quantity must be positive")
        }
        guard auditEvent.decision == "accepted" else {
            throw SuperNeoProductIntegrationError.invalidRequest("only accepted product verifications are billable")
        }
        guard auditEvent.errorClass == nil, auditEvent.errorMessage == nil else {
            throw SuperNeoProductIntegrationError.invalidRequest("rejected or error-bearing audit events are not billable")
        }
        guard auditEvent.proofKind == SuperNeoProductProofKind.numiSealZK.rawValue else {
            throw SuperNeoProductIntegrationError.invalidRequest("only accepted numiseal-zk product verifications are billable")
        }
        let artifactDigestHex = try requiredDigestHex(auditEvent.artifactDigestHex, name: "billable artifact digest")
        let proofEnvelopeDigestHex = try requiredDigestHex(
            auditEvent.proofEnvelopeDigestHex,
            name: "billable proof envelope digest"
        )
        let provenanceDigestHex = try requiredDigestHex(
            auditEvent.provenanceDigestHex,
            name: "billable provenance digest"
        )
        let statementDigestHex = try requiredDigestHex(auditEvent.statementDigestHex, name: "billable statement digest")
        let issuedQROChallengeDigestHex = try requiredDigestHex(
            auditEvent.issuedQROChallengeDigestHex,
            name: "billable issued QRO challenge digest"
        )
        _ = try Digest256(hexDigest: auditEvent.releaseBuildDigestHex, name: "billable release build digest")
        let sku = SuperNeoRevenueSKU.acceptedNumiSealZKVerification
        let unitRevenue = rateCard.unitPriceMicrosUSD(for: sku)
        let totalRevenue = try multiplyMicros(unitRevenue, quantity, name: "billable revenue")
        let unitCost = costBasis.totalMicrosUSD
        let totalCost = try multiplyMicros(unitCost, quantity, name: "billable cost")
        guard totalRevenue > 0 else {
            throw SuperNeoProductIntegrationError.invalidRequest("billable revenue must be positive")
        }
        let margin = totalRevenue - totalCost
        let scaledMargin = margin.multipliedReportingOverflow(by: 10_000)
        guard !scaledMargin.overflow else {
            throw SuperNeoProductIntegrationError.invalidRequest("billable gross margin overflows Int64 micros")
        }
        let marginBasisPoints = Int(scaledMargin.partialValue / totalRevenue)
        let eventDigestHex = Digest256.hash(
            SuperNeoSplitQRO.framedBytes(
                domain: "superneo/revenue/billable-usage-event/v1",
                frames: [
                    Array(customerID.utf8),
                    Array(sku.rawValue.utf8),
                    Array(auditEvent.contextID.utf8),
                    Array(artifactDigestHex.utf8),
                    Array(proofEnvelopeDigestHex.utf8),
                    Array(provenanceDigestHex.utf8),
                    Array(statementDigestHex.utf8),
                    Array(issuedQROChallengeDigestHex.utf8),
                    Array(auditEvent.releaseBuildDigestHex.utf8),
                    Array(String(quantity).utf8),
                    Array(String(unitRevenue).utf8),
                    Array(String(unitCost).utf8)
                ]
            )
        ).hexString
        return SuperNeoBillableUsageEvent(
            eventDigestHex: eventDigestHex,
            customerID: customerID,
            sku: sku,
            quantity: quantity,
            unitRevenueMicrosUSD: unitRevenue,
            totalRevenueMicrosUSD: totalRevenue,
            estimatedUnitCostMicrosUSD: unitCost,
            estimatedTotalCostMicrosUSD: totalCost,
            grossMarginBasisPoints: marginBasisPoints,
            targetGrossMarginBasisPoints: rateCard.targetGrossMarginBasisPoints,
            contextID: auditEvent.contextID,
            artifactDigestHex: artifactDigestHex,
            proofEnvelopeDigestHex: proofEnvelopeDigestHex,
            provenanceDigestHex: provenanceDigestHex,
            statementDigestHex: statementDigestHex,
            issuedQROChallengeDigestHex: issuedQROChallengeDigestHex,
            releaseBuildDigestHex: auditEvent.releaseBuildDigestHex
        )
    }

    private static func requiredDigestHex(_ value: String?, name: String) throws -> String {
        guard let value else {
            throw SuperNeoProductIntegrationError.invalidRequest("\(name) is required")
        }
        _ = try Digest256(hexDigest: value, name: name)
        return value
    }

    private static func multiplyMicros(_ unit: Int64, _ quantity: UInt64, name: String) throws -> Int64 {
        guard quantity <= UInt64(Int64.max) else {
            throw SuperNeoProductIntegrationError.invalidRequest("\(name) quantity is too large")
        }
        let result = unit.multipliedReportingOverflow(by: Int64(quantity))
        guard !result.overflow else {
            throw SuperNeoProductIntegrationError.invalidRequest("\(name) overflows Int64 micros")
        }
        return result.partialValue
    }
}
