import Foundation

public enum NumiSealCanonicalization {
    public static func canonicalize(
        obligations: [NumiSealObligation],
        policy: NumiSealAcceptancePolicy
    ) throws -> NumiSealCanonicalizationResult {
        guard !obligations.isEmpty else {
            throw SuperNeoError.invalidParameter("NumiSeal requires at least one obligation")
        }
        if let maximumProofByteCount = policy.maximumProofByteCount {
            guard maximumProofByteCount > 0 else {
                throw SuperNeoError.invalidParameter("NumiSeal maximum proof byte count must be positive")
            }
        }
        guard !policy.acceptedLaneIDs.isEmpty else {
            throw SuperNeoError.invalidParameter("NumiSeal policy must accept at least one lane ID")
        }

        let canonical = try obligations.map { obligation in
            try validate(obligation, against: policy)
            let laneKey = NumiSealLaneKey(
                profileID: obligation.profileID,
                shapeDigest: obligation.shapeDigest,
                verifierKeyDigest: obligation.verifierKeyDigest,
                evalPointDigest: evalPointDigest(obligation.evalPoint),
                laneID: obligation.laneID
            )
            return NumiSealCanonicalObligation(
                obligation: obligation,
                laneKey: laneKey,
                obligationDigest: obligationDigest(obligation)
            )
        }
        .sorted { lhs, rhs in
            sortKey(lhs).lexicographicallyPrecedes(sortKey(rhs))
        }

        let obligationRoot = NumiSealEncoding.root(
            label: "numiseal.obligation-root.v1",
            leaves: canonical.map(\.obligationDigest)
        )
        let laneSummaries = makeLaneSummaries(canonical)
        let laneSummaryRoot = NumiSealEncoding.root(
            label: "numiseal.lane-summary-root.v1",
            leaves: laneSummaries.map(\.laneSummaryDigest)
        )
        return NumiSealCanonicalizationResult(
            obligations: canonical,
            laneSummaries: laneSummaries,
            obligationRoot: obligationRoot,
            laneSummaryRoot: laneSummaryRoot
        )
    }

    public static func evalPointDigest(_ evalPoint: [GoldilocksExt2]) -> Digest256 {
        NumiSealEncoding.digest(
            label: "numiseal.eval-point.v1",
            bytes: numiSealEncodeCount(evalPoint.count) + evalPoint.flatMap(\.superNeoBytes)
        )
    }

    public static func obligationDigest(_ obligation: NumiSealObligation) -> Digest256 {
        NumiSealEncoding.digest(
            label: "numiseal.obligation.v1",
            bytes: obligation.superNeoBytes
        )
    }

    private static func validate(
        _ obligation: NumiSealObligation,
        against policy: NumiSealAcceptancePolicy
    ) throws {
        guard obligation.profileID == policy.profileID else {
            throw SuperNeoError.verificationFailed("NumiSeal obligation profile mismatch")
        }
        guard obligation.shapeDigest == policy.shapeDigest else {
            throw SuperNeoError.verificationFailed("NumiSeal obligation shape mismatch")
        }
        guard obligation.statementDigest == policy.statementDigest else {
            throw SuperNeoError.verificationFailed("NumiSeal obligation statement mismatch")
        }
        guard obligation.verifierKeyDigest == policy.verifierKeyDigest else {
            throw SuperNeoError.verificationFailed("NumiSeal obligation verifier key mismatch")
        }
        guard policy.acceptedLaneIDs.contains(obligation.laneID) else {
            throw SuperNeoError.verificationFailed("NumiSeal obligation lane is not accepted by policy")
        }
        guard !obligation.matrixEvaluations.isEmpty else {
            throw SuperNeoError.invalidParameter("NumiSeal obligation requires matrix evaluations")
        }
        guard obligation.commitment.elements.count == SuperNeoParameters.goldilocks.kappa else {
            throw SuperNeoError.invalidParameter("NumiSeal obligation commitment has wrong length")
        }
    }

    private static func makeLaneSummaries(
        _ canonical: [NumiSealCanonicalObligation]
    ) -> [NumiSealLaneSummary] {
        var summaries: [NumiSealLaneSummary] = []
        var start = 0
        while start < canonical.count {
            var end = start + 1
            while end < canonical.count, canonical[end].laneKey == canonical[start].laneKey {
                end += 1
            }
            let laneKey = canonical[start].laneKey
            let laneRoot = NumiSealEncoding.root(
                label: "numiseal.lane-obligation-root.v1",
                leaves: canonical[start..<end].map(\.obligationDigest)
            )
            let summaryBytes = laneKey.superNeoBytes
                + numiSealEncodeCount(end - start)
                + laneRoot.superNeoBytes
            summaries.append(
                NumiSealLaneSummary(
                    laneKey: laneKey,
                    obligationCount: end - start,
                    laneObligationRoot: laneRoot,
                    laneSummaryDigest: NumiSealEncoding.digest(
                        label: "numiseal.lane-summary.v1",
                        bytes: summaryBytes
                    )
                )
            )
            start = end
        }
        return summaries
    }

    private static func sortKey(_ obligation: NumiSealCanonicalObligation) -> [UInt8] {
        obligation.laneKey.superNeoBytes
            + Digest256.hash(obligation.obligation.commitment.superNeoBytes).superNeoBytes
            + Digest256.hash(obligation.obligation.publicInputEncoding.superNeoBytes).superNeoBytes
            + Digest256.hash(
                numiSealEncodeCount(obligation.obligation.matrixEvaluations.count)
                    + obligation.obligation.matrixEvaluations.flatMap(\.superNeoBytes)
            ).superNeoBytes
            + obligation.obligation.sourceFoldDigest.superNeoBytes
    }
}
