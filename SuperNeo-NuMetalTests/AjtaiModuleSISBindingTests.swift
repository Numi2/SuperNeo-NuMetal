import XCTest
@_spi(Benchmarking) @testable import SuperNeo_NuMetal

final class AjtaiModuleSISBindingTests: SuperNeoTestCase {
    func testModuleSISBindingProfileMaterializesSelectedAjtaiBounds() throws {
        let key = try AjtaiCommitmentKey(columns: 2, seed: Array("module-sis-profile-key".utf8))
        let profile = try key.moduleSISBindingSecurityProfile()

        XCTAssertEqual(profile.profileID, SuperNeoParameters.goldilocks.profileID)
        XCTAssertEqual(profile.ringDegree, CyclotomicRing54.degree)
        XCTAssertEqual(profile.moduleRank, SuperNeoParameters.goldilocks.kappa)
        XCTAssertEqual(profile.matrixColumns, 2)
        XCTAssertEqual(profile.modulusBitWidth, 64)
        XCTAssertEqual(profile.normBound, 2)
        XCTAssertEqual(profile.decompositionLength, 14)
        XCTAssertEqual(profile.challengeExpansionFactor, 216)
        XCTAssertEqual(profile.claimedSecurityBits, 129)
        XCTAssertEqual(profile.decomposedOpeningMagnitudeBound, 1 << 14)
        XCTAssertEqual(profile.relaxedBindingInfinityNormBound, UInt64(4 * 216 * (1 << 14)))
        XCTAssertEqual(profile.profileDigest, try key.moduleSISBindingSecurityProfile().profileDigest)

        XCTAssertTrue(profile.containsLowNormFieldOpening([.zero, .one, -GoldilocksField.one]))
        XCTAssertFalse(profile.containsLowNormFieldOpening([GoldilocksField(2)]))
        XCTAssertTrue(profile.containsDecomposableCoefficient(GoldilocksField(UInt64((1 << 14) - 1))))
        XCTAssertFalse(profile.containsDecomposableCoefficient(GoldilocksField(UInt64(1 << 14))))
        XCTAssertTrue(profile.isValidDecompositionLimbCount(14))
        XCTAssertFalse(profile.isValidDecompositionLimbCount(15))

        XCTAssertThrowsSuperNeoError(
            try key.moduleSISBindingSecurityProfile(minimumSecurityBits: 130),
            .invalidParameter("Module-SIS claimed security below required minimum")
        )
        XCTAssertThrowsSuperNeoError(
            try ModuleSISBindingSecurityProfile(matrixColumns: 0),
            .invalidParameter("Module-SIS binding profile requires at least one matrix column")
        )
    }

    func testAjtaiOpeningBoundaryRejectsHighNormAndMalformedOpenings() throws {
        let workload = try SuperNeoOneHotVectorWorkload(bitCount: 4)
        let prepared = try workload.prepareForFolding(
            bits: [false, true, false, false],
            keySeed: Array("module-sis-opening-source".utf8)
        )
        let keyPair = try AjtaiSuperNeoCommitment.setup(
            shape: prepared.publicFoldInput.shape,
            seed: Array("module-sis-opening-key".utf8)
        )
        let instance = prepared.foldInput.instances[0]
        let opening = prepared.foldInput.witnesses[0].fullZ(for: instance)
        let commitment = try AjtaiSuperNeoCommitment.commit(
            proverKey: keyPair.proverKey,
            shape: prepared.publicFoldInput.shape,
            message: opening,
            executionPolicy: .highAssurance
        )

        XCTAssertTrue(try AjtaiSuperNeoCommitment.verifyOpening(
            verifierKey: keyPair.verifierKey,
            shape: prepared.publicFoldInput.shape,
            message: opening,
            commitment: commitment,
            executionPolicy: .highAssurance
        ))

        var highNormOpening = opening
        highNormOpening[0] = GoldilocksField(UInt64(SuperNeoParameters.goldilocks.normBound))
        XCTAssertThrowsSuperNeoError(
            try AjtaiSuperNeoCommitment.commit(
                proverKey: keyPair.proverKey,
                shape: prepared.publicFoldInput.shape,
                message: highNormOpening,
                executionPolicy: .highAssurance
            ),
            .invalidParameter("Ajtai opening coefficient exceeds Module-SIS low-norm bound")
        )
        XCTAssertFalse(try AjtaiSuperNeoCommitment.verifyOpening(
            verifierKey: keyPair.verifierKey,
            shape: prepared.publicFoldInput.shape,
            message: highNormOpening,
            commitment: commitment,
            executionPolicy: .highAssurance
        ))

        let malformedCommitment = AjtaiCommitment(Array(commitment.elements.dropLast()))
        XCTAssertFalse(try AjtaiSuperNeoCommitment.verifyOpening(
            verifierKey: keyPair.verifierKey,
            shape: prepared.publicFoldInput.shape,
            message: opening,
            commitment: malformedCommitment,
            executionPolicy: .highAssurance
        ))

        XCTAssertFalse(try AjtaiSuperNeoCommitment.verifyOpening(
            verifierKey: keyPair.verifierKey,
            shape: prepared.publicFoldInput.shape,
            message: Array(opening.dropLast()),
            commitment: commitment,
            executionPolicy: .highAssurance
        ))
    }

    func testAjtaiVerifierRejectsAlternativeLowNormOpeningsForSameCommitment() throws {
        let workload = try SuperNeoOneHotVectorWorkload(bitCount: 4)
        let prepared = try workload.prepareForFolding(
            bits: [false, true, false, false],
            keySeed: Array("module-sis-alt-opening-source".utf8)
        )
        let keyPair = try AjtaiSuperNeoCommitment.setup(
            shape: prepared.publicFoldInput.shape,
            seed: Array("module-sis-alt-opening-key".utf8)
        )
        let instance = prepared.foldInput.instances[0]
        let opening = prepared.foldInput.witnesses[0].fullZ(for: instance)
        let commitment = try AjtaiSuperNeoCommitment.commit(
            proverKey: keyPair.proverKey,
            shape: prepared.publicFoldInput.shape,
            message: opening,
            executionPolicy: .highAssurance
        )
        let profile = try keyPair.verifierKey.moduleSISBindingSecurityProfile()

        XCTAssertTrue(profile.containsLowNormFieldOpening(opening))
        XCTAssertTrue(try AjtaiSuperNeoCommitment.verifyOpening(
            verifierKey: keyPair.verifierKey,
            shape: prepared.publicFoldInput.shape,
            message: opening,
            commitment: commitment,
            executionPolicy: .highAssurance
        ))

        for index in 0..<min(opening.count, 16) {
            var alternative = opening
            alternative[index] = opening[index] == .zero ? .one : -opening[index]
            guard alternative != opening else { continue }
            XCTAssertTrue(profile.containsLowNormFieldOpening(alternative))
            XCTAssertFalse(try AjtaiSuperNeoCommitment.verifyOpening(
                verifierKey: keyPair.verifierKey,
                shape: prepared.publicFoldInput.shape,
                message: alternative,
                commitment: commitment,
                executionPolicy: .highAssurance
            ))
        }

        var signAmbiguousOpening = opening
        signAmbiguousOpening[0] = -GoldilocksField.one
        XCTAssertTrue(profile.containsLowNormFieldOpening(signAmbiguousOpening))
        XCTAssertFalse(try AjtaiSuperNeoCommitment.verifyOpening(
            verifierKey: keyPair.verifierKey,
            shape: prepared.publicFoldInput.shape,
            message: signAmbiguousOpening,
            commitment: commitment,
            executionPolicy: .highAssurance
        ))

        let wrongShape = try SuperNeoOneHotVectorWorkload(bitCount: 80).prepareForFolding(
            bits: [true] + Array(repeating: false, count: 79),
            keySeed: Array("module-sis-alt-opening-wrong-shape".utf8)
        ).publicFoldInput.shape
        XCTAssertThrowsSuperNeoError(
            try AjtaiSuperNeoCommitment.verifyOpening(
                verifierKey: keyPair.verifierKey,
                shape: wrongShape,
                message: opening,
                commitment: commitment,
                executionPolicy: .highAssurance
            ),
            .invalidParameter("Ajtai verifier key column count must match shape.nRing")
        )
    }

    func testAjtaiWireDecodingRejectsNonCanonicalCoefficientsBeforeArithmetic() throws {
        let nonCanonicalField = withUnsafeBytes(of: GoldilocksField.modulus.littleEndian, Array.init)
        XCTAssertThrowsSuperNeoError(
            try GoldilocksField(littleEndianBytes: nonCanonicalField[...]),
            .invalidEncoding("non-canonical Goldilocks element")
        )

        var nonCanonicalRing = CyclotomicRing54.zero.littleEndianBytes
        nonCanonicalRing.replaceSubrange(0..<8, with: nonCanonicalField)
        XCTAssertThrowsSuperNeoError(
            try CyclotomicRing54(littleEndianBytes: nonCanonicalRing),
            .invalidEncoding("non-canonical Goldilocks element")
        )

        var truncatedRing = CyclotomicRing54.zero.littleEndianBytes
        truncatedRing.removeLast()
        XCTAssertThrowsSuperNeoError(
            try CyclotomicRing54(littleEndianBytes: truncatedRing),
            .invalidEncoding("ring element must be 432 bytes")
        )
    }

    func testFoldInputRejectsHighNormWitnessBeforeSumcheck() throws {
        let workload = try SuperNeoOneHotVectorWorkload(bitCount: 4)
        let prepared = try workload.prepareForFolding(
            bits: [true, false, false, false],
            keySeed: Array("module-sis-fold-bound-source".utf8)
        )
        var witnesses = prepared.foldInput.witnesses
        var values = witnesses[0].values
        values[0] = GoldilocksField(UInt64(SuperNeoParameters.goldilocks.normBound))
        witnesses[0] = CCSWitness(values)
        let malformed = SuperNeoFoldInput(
            shape: prepared.foldInput.shape,
            instances: prepared.foldInput.instances,
            witnesses: witnesses,
            priorClaims: prepared.foldInput.priorClaims
        )

        XCTAssertThrowsSuperNeoError(
            try SuperNeoProver(key: prepared.key).fold(malformed),
            .invalidParameter("fold witness exceeds Module-SIS low-norm opening bound")
        )
    }
}
