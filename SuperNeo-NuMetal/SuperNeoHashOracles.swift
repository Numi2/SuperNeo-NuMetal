import Foundation

public struct Digest384: Equatable, Hashable, Sendable, SuperNeoByteEncodable {
    public static let byteCount = 48
    public let bytes: [UInt8]

    public init(_ bytes: [UInt8]) throws {
        guard bytes.count == Self.byteCount else {
            throw SuperNeoError.invalidEncoding("Digest384 must be 48 bytes")
        }
        self.bytes = bytes
    }

    private init(unchecked bytes: [UInt8]) {
        precondition(bytes.count == Self.byteCount, "SHAKE256-384 digest must be 48 bytes")
        self.bytes = bytes
    }

    public static func shake256(_ bytes: [UInt8]) -> Self {
        Self(unchecked: SuperNeoSHAKE256.squeeze(bytes, outputByteCount: Self.byteCount))
    }

    public static func shake256(_ string: String) -> Self {
        shake256(Array(string.utf8))
    }

    static func shake256Framed(domain: String, frames: [[UInt8]]) -> Self {
        Self(unchecked: SuperNeoSHAKE256.squeezeFramed(
            domain: domain,
            frames: frames,
            outputByteCount: Self.byteCount
        ))
    }

    public init(hexDigest raw: String, name: String = "digest") throws {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard value.range(of: "^[0-9a-f]{96}$", options: .regularExpression) != nil else {
            throw SuperNeoError.invalidEncoding("\(name) must be a 96-character lowercase or uppercase hex digest")
        }
        var bytes: [UInt8] = []
        bytes.reserveCapacity(Self.byteCount)
        var index = value.startIndex
        while index < value.endIndex {
            let next = value.index(index, offsetBy: 2)
            guard let byte = UInt8(value[index..<next], radix: 16) else {
                throw SuperNeoError.invalidEncoding("\(name) must be a valid hex digest")
            }
            bytes.append(byte)
            index = next
        }
        try self.init(bytes)
    }

    public var superNeoBytes: [UInt8] { bytes }

    public var hexString: String {
        bytes.map { String(format: "%02x", $0) }.joined()
    }
}

public extension Digest256 {
    static func shake256(_ bytes: [UInt8]) -> Self {
        try! Self(SuperNeoSHAKE256.squeeze(bytes, outputByteCount: Self.byteCount))
    }

    static func shake256(_ string: String) -> Self {
        shake256(Array(string.utf8))
    }

    static func shake256Framed(domain: String, frames: [[UInt8]]) -> Self {
        try! Self(SuperNeoSHAKE256.squeezeFramed(
            domain: domain,
            frames: frames,
            outputByteCount: Self.byteCount
        ))
    }
}

public enum SuperNeoSplitQRO {
    public static let challengeDomain = "superneo/numiseal/chal/v2"
    public static let bindingDomain = "superneo/numiseal/bind/v2"
    public static let merkleDomain = "superneo/numiseal/merkle/v2"

    public static func framedBytes(domain: String, frames: [[UInt8]]) -> [UInt8] {
        var bytes: [UInt8] = []
        appendFrame(Array(domain.utf8), to: &bytes)
        for frame in frames {
            appendFrame(frame, to: &bytes)
        }
        return bytes
    }

    public static func hChal(domain: String = challengeDomain, frames: [[UInt8]]) -> Digest256 {
        Digest256.shake256Framed(domain: domain, frames: frames)
    }

    public static func hBind(domain: String = bindingDomain, frames: [[UInt8]]) -> Digest384 {
        Digest384.shake256Framed(domain: domain, frames: frames)
    }

    public static func hMerkleLeaf(domain: String = merkleDomain, frames: [[UInt8]]) -> Digest384 {
        hBind(domain: "\(domain)/leaf", frames: frames)
    }

    public static func hMerkleNode(domain: String = merkleDomain, left: Digest384, right: Digest384) -> Digest384 {
        hBind(domain: "\(domain)/node", frames: [left.superNeoBytes, right.superNeoBytes])
    }

    public static func challengeTapeSeed(
        proofKind: ProofEnvelopeKind,
        contextBinder: Digest384,
        root: Digest384,
        label: String
    ) -> Digest256 {
        hChal(frames: [
            [proofKind.rawValue],
            contextBinder.superNeoBytes,
            root.superNeoBytes,
            Array(label.utf8)
        ])
    }

    public static func expandChallenge(
        seed: Digest256,
        proofKind: ProofEnvelopeKind,
        label: String,
        index: UInt64
    ) -> Digest256 {
        try! Digest256(SuperNeoSHAKE256.squeezeFramedFast(
            domain: "\(challengeDomain)/expand",
            frames: [
                .byte(proofKind.rawValue),
                .bytes(seed.superNeoBytes),
                .utf8(label),
                .uint64LE(index)
            ],
            outputByteCount: Digest256.byteCount
        ))
    }

    static func expandChallengeField(
        seed: Digest256,
        proofKind: ProofEnvelopeKind,
        label: String
    ) -> GoldilocksField {
        var digestIndex = UInt64(0)
        while true {
            let bytes = SuperNeoSHAKE256.squeezeFramedFast(
                domain: "\(challengeDomain)/expand",
                frames: [
                    .byte(proofKind.rawValue),
                    .bytes(seed.superNeoBytes),
                    .utf8(label),
                    .uint64LE(digestIndex)
                ],
                outputByteCount: Digest256.byteCount
            )
            digestIndex &+= 1
            for offset in stride(from: 0, to: bytes.count, by: 8) {
                let value = SuperNeoSHAKE256.loadUInt64LE(bytes, offset: offset)
                if value < GoldilocksField.modulus {
                    return GoldilocksField(value)
                }
            }
        }
    }

    static func sumCheckTranscriptChallenge(
        label: String,
        proofKind: ProofEnvelopeKind,
        challengeTapeSeed: Digest256,
        stateDigest: Digest256,
        challengeCounter: UInt64
    ) -> Digest256 {
        try! Digest256(SuperNeoSHAKE256.squeezeFramedFast(
            domain: "\(challengeDomain)/sumcheck-transcript-challenge/\(label)",
            frames: [
                .byte(proofKind.rawValue),
                .bytes(challengeTapeSeed.superNeoBytes),
                .bytes(stateDigest.superNeoBytes),
                .uint64LE(challengeCounter)
            ],
            outputByteCount: Digest256.byteCount
        ))
    }

    static func sumCheckTranscriptSeed(
        domainSeparator: String,
        seed: [UInt8],
        proofKind: ProofEnvelopeKind
    ) -> Digest256 {
        try! Digest256(SuperNeoSHAKE256.squeezeFramedFast(
            domain: "\(challengeDomain)/sumcheck-transcript-seed",
            frames: [
                .byte(proofKind.rawValue),
                .utf8(domainSeparator),
                .bytes(seed)
            ],
            outputByteCount: Digest256.byteCount
        ))
    }

    static func sumCheckTranscriptInitialState(
        proofKind: ProofEnvelopeKind,
        seedDigest: Digest256
    ) -> Digest256 {
        try! Digest256(SuperNeoSHAKE256.squeezeFramedFast(
            domain: "\(challengeDomain)/sumcheck-transcript-state/init",
            frames: [
                .byte(proofKind.rawValue),
                .bytes(seedDigest.superNeoBytes)
            ],
            outputByteCount: Digest256.byteCount
        ))
    }

    static func sumCheckTranscriptAbsorbState(
        proofKind: ProofEnvelopeKind,
        stateDigest: Digest256,
        bytes: [UInt8]
    ) -> Digest256 {
        try! Digest256(SuperNeoSHAKE256.squeezeFramedFast(
            domain: "\(challengeDomain)/sumcheck-transcript-state/absorb",
            frames: [
                .byte(proofKind.rawValue),
                .bytes(stateDigest.superNeoBytes),
                .uint64LE(UInt64(bytes.count)),
                .bytes(bytes)
            ],
            outputByteCount: Digest256.byteCount
        ))
    }

    public static func appendFrame(_ frame: [UInt8], to bytes: inout [UInt8]) {
        bytes.append(contentsOf: encodeUInt64(UInt64(frame.count)))
        bytes.append(contentsOf: frame)
    }

    public static func encodeUInt64(_ value: UInt64) -> [UInt8] {
        withUnsafeBytes(of: value.littleEndian, Array.init)
    }
}

public struct SuperNeoChallengeTape: Sendable {
    public let seed: Digest256
    public let proofKind: ProofEnvelopeKind
    public let label: String

    private var digestIndex: UInt64
    private var buffer: [UInt8]
    private var offset: Int

    public init(seed: Digest256, proofKind: ProofEnvelopeKind, label: String) {
        self.seed = seed
        self.proofKind = proofKind
        self.label = label
        self.digestIndex = 0
        self.buffer = []
        self.offset = 0
    }

    public mutating func nextDigest(label elementLabel: String? = nil) -> Digest256 {
        let digest = SuperNeoSplitQRO.expandChallenge(
            seed: seed,
            proofKind: proofKind,
            label: Self.composedLabel(base: label, element: elementLabel),
            index: digestIndex
        )
        digestIndex &+= 1
        buffer = []
        offset = 0
        return digest
    }

    public mutating func nextField() -> GoldilocksField {
        var value = nextUInt64()
        while value >= GoldilocksField.modulus {
            value = nextUInt64()
        }
        return GoldilocksField(value)
    }

    public mutating func nextExt2() -> GoldilocksExt2 {
        GoldilocksExt2(nextField(), nextField())
    }

    public mutating func nextRing(parameters: SuperNeoParameters = .goldilocks) -> CyclotomicRing54 {
        let choices = parameters.challengeCoefficients
        var coeffs = Array(repeating: GoldilocksField.zero, count: CyclotomicRing54.degree)
        for coefficientIndex in 0..<CyclotomicRing54.degree {
            let index = nextUniformIndex(upperBound: choices.count)
            let value = choices[index]
            coeffs[coefficientIndex] = value >= 0
                ? GoldilocksField(UInt64(value))
                : -GoldilocksField(UInt64(-value))
        }
        return CyclotomicRing54(coeffs)
    }

    public static func expansionDigest(
        seed: Digest256,
        proofKind: ProofEnvelopeKind,
        label: String,
        digestCount: Int
    ) -> Digest256 {
        precondition(digestCount >= 0, "challenge tape digest count must be nonnegative")
        var bytes = SuperNeoSplitQRO.encodeUInt64(UInt64(digestCount))
        for index in 0..<digestCount {
            bytes.append(
                contentsOf: SuperNeoSplitQRO.expandChallenge(
                    seed: seed,
                    proofKind: proofKind,
                    label: label,
                    index: UInt64(index)
                ).superNeoBytes
            )
        }
        return SuperNeoSplitQRO.hChal(
            domain: "\(SuperNeoSplitQRO.challengeDomain)/tape-digest",
            frames: [[proofKind.rawValue], seed.superNeoBytes, Array(label.utf8), bytes]
        )
    }

    private mutating func nextUInt64() -> UInt64 {
        var value = UInt64(0)
        var shift = UInt64(0)
        var remaining = 8
        while remaining > 0 {
            if offset == buffer.count {
                refill()
            }
            let take = min(remaining, buffer.count - offset)
            for byteIndex in 0..<take {
                value |= UInt64(buffer[offset + byteIndex]) << shift
                shift += 8
            }
            offset += take
            remaining -= take
        }
        return value
    }

    private mutating func refill() {
        buffer = nextDigest().superNeoBytes
        offset = 0
    }

    private mutating func nextUniformIndex(upperBound: Int) -> Int {
        guard upperBound > 1 else { return 0 }
        let bound = UInt64(upperBound)
        let limit = UInt64.max - (UInt64.max % bound)
        while true {
            let value = nextUInt64()
            if value < limit {
                return Int(value % bound)
            }
        }
    }

    private static func composedLabel(base: String, element: String?) -> String {
        guard let element, !element.isEmpty else {
            return base
        }
        return "\(base)/\(element)"
    }
}

public struct CTCOTraceBlock: Equatable, Sendable {
    public let label: String
    public let bytes: [UInt8]

    public init(label: String, bytes: [UInt8]) {
        self.label = label
        self.bytes = bytes
    }
}

public struct CTCOMoveOneCommitment: Equatable, Sendable {
    public let proofKind: ProofEnvelopeKind
    public let contextBinder: Digest384
    public let root: Digest384
    public let leafCount: Int

    public init(proofKind: ProofEnvelopeKind, contextBinder: Digest384, traceBlocks: [CTCOTraceBlock]) {
        self.proofKind = proofKind
        self.contextBinder = contextBinder
        self.root = Self.root(proofKind: proofKind, contextBinder: contextBinder, traceBlocks: traceBlocks)
        self.leafCount = traceBlocks.count
    }

    public static func root(
        proofKind: ProofEnvelopeKind,
        contextBinder: Digest384,
        traceBlocks: [CTCOTraceBlock]
    ) -> Digest384 {
        guard !traceBlocks.isEmpty else {
            return SuperNeoSplitQRO.hMerkleLeaf(
                domain: merkleDomain(proofKind: proofKind),
                frames: [
                    [proofKind.rawValue],
                    contextBinder.superNeoBytes,
                    SuperNeoSplitQRO.encodeUInt64(0)
                ]
            )
        }
        var level = traceBlocks.enumerated().map { index, block in
            leafDigest(
                proofKind: proofKind,
                contextBinder: contextBinder,
                leafIndex: index,
                leafCount: traceBlocks.count,
                block: block
            )
        }
        while level.count > 1 {
            var next: [Digest384] = []
            next.reserveCapacity((level.count + 1) / 2)
            var index = 0
            while index < level.count {
                let left = level[index]
                let right = index + 1 < level.count ? level[index + 1] : left
                next.append(
                    SuperNeoSplitQRO.hMerkleNode(
                        domain: merkleDomain(proofKind: proofKind),
                        left: left,
                        right: right
                    )
                )
                index += 2
            }
            level = next
        }
        return level[0]
    }

    public static func leafDigest(
        proofKind: ProofEnvelopeKind,
        contextBinder: Digest384,
        leafIndex: Int,
        leafCount: Int,
        block: CTCOTraceBlock
    ) -> Digest384 {
        SuperNeoSplitQRO.hMerkleLeaf(
            domain: merkleDomain(proofKind: proofKind),
            frames: [
                [proofKind.rawValue],
                contextBinder.superNeoBytes,
                SuperNeoSplitQRO.encodeUInt64(UInt64(leafIndex)),
                SuperNeoSplitQRO.encodeUInt64(UInt64(leafCount)),
                Array(block.label.utf8),
                block.bytes
            ]
        )
    }

    public static func merkleOpening(
        proofKind: ProofEnvelopeKind,
        contextBinder: Digest384,
        traceBlocks: [CTCOTraceBlock],
        leafIndex: Int
    ) throws -> CTCOMerkleOpening {
        guard traceBlocks.indices.contains(leafIndex) else {
            throw SuperNeoError.invalidParameter("CTCO Merkle opening index out of range")
        }
        var level = traceBlocks.enumerated().map { index, block in
            leafDigest(
                proofKind: proofKind,
                contextBinder: contextBinder,
                leafIndex: index,
                leafCount: traceBlocks.count,
                block: block
            )
        }
        var index = leafIndex
        var siblings: [CTCOMerkleSibling] = []
        while level.count > 1 {
            if index % 2 == 0 {
                let siblingIndex = index + 1 < level.count ? index + 1 : index
                siblings.append(CTCOMerkleSibling(position: .right, digest: level[siblingIndex]))
            } else {
                siblings.append(CTCOMerkleSibling(position: .left, digest: level[index - 1]))
            }
            var next: [Digest384] = []
            next.reserveCapacity((level.count + 1) / 2)
            var pair = 0
            while pair < level.count {
                let left = level[pair]
                let right = pair + 1 < level.count ? level[pair + 1] : left
                next.append(
                    SuperNeoSplitQRO.hMerkleNode(
                        domain: merkleDomain(proofKind: proofKind),
                        left: left,
                        right: right
                    )
                )
                pair += 2
            }
            index /= 2
            level = next
        }
        return CTCOMerkleOpening(
            proofKind: proofKind,
            contextBinder: contextBinder,
            leafIndex: leafIndex,
            leafCount: traceBlocks.count,
            block: traceBlocks[leafIndex],
            siblings: siblings
        )
    }

    private static func merkleDomain(proofKind: ProofEnvelopeKind) -> String {
        "superneo/numiseal/ctco/root/\(proofKind.ctcoDomainComponent)/v2"
    }
}

public struct CTCOMerkleSibling: Equatable, Sendable {
    public enum Position: UInt8, Equatable, Sendable {
        case left = 0
        case right = 1
    }

    public let position: Position
    public let digest: Digest384

    public init(position: Position, digest: Digest384) {
        self.position = position
        self.digest = digest
    }
}

public struct CTCOMerkleOpening: Equatable, Sendable {
    public let proofKind: ProofEnvelopeKind
    public let contextBinder: Digest384
    public let leafIndex: Int
    public let leafCount: Int
    public let block: CTCOTraceBlock
    public let siblings: [CTCOMerkleSibling]

    public init(
        proofKind: ProofEnvelopeKind,
        contextBinder: Digest384,
        leafIndex: Int,
        leafCount: Int,
        block: CTCOTraceBlock,
        siblings: [CTCOMerkleSibling]
    ) {
        self.proofKind = proofKind
        self.contextBinder = contextBinder
        self.leafIndex = leafIndex
        self.leafCount = leafCount
        self.block = block
        self.siblings = siblings
    }

    public func verifies(root: Digest384) -> Bool {
        guard leafIndex >= 0, leafIndex < leafCount else {
            return false
        }
        var digest = CTCOMoveOneCommitment.leafDigest(
            proofKind: proofKind,
            contextBinder: contextBinder,
            leafIndex: leafIndex,
            leafCount: leafCount,
            block: block
        )
        for sibling in siblings {
            switch sibling.position {
            case .left:
                digest = SuperNeoSplitQRO.hMerkleNode(
                    domain: "superneo/numiseal/ctco/root/\(proofKind.ctcoDomainComponent)/v2",
                    left: sibling.digest,
                    right: digest
                )
            case .right:
                digest = SuperNeoSplitQRO.hMerkleNode(
                    domain: "superneo/numiseal/ctco/root/\(proofKind.ctcoDomainComponent)/v2",
                    left: digest,
                    right: sibling.digest
                )
            }
        }
        return digest == root
    }
}

public struct ProofEnvelopeCTCOReport: Equatable, Sendable {
    public let proofKind: ProofEnvelopeKind
    public let contextBinder: Digest384
    public let root: Digest384
    public let challengeTapeSeed: Digest256
    public let bodyDigest: Digest256
    public let traceBlockCount: Int
}

public enum ProofEnvelopeCTCOVerifier {
    public static let challengeTapeLabel = "proof-envelope-body"

    public static func verify(
        envelopeBytes: [UInt8],
        expectedRoot: Digest384? = nil,
        expectedChallengeTapeSeed: Digest256? = nil
    ) throws -> ProofEnvelopeCTCOReport {
        let header = try ProofEnvelopeHeader.parsePrefix(from: envelopeBytes)
        try header.validateEnvelopeLength(totalByteCount: envelopeBytes.count)
        let body = Array(envelopeBytes.dropFirst(ProofEnvelopeHeader.byteCount))
        let traceBlocks = traceBlocks(header: header, body: body)
        let commitment = CTCOMoveOneCommitment(
            proofKind: header.kind,
            contextBinder: header.ctcoContextBinder,
            traceBlocks: traceBlocks
        )
        for index in traceBlocks.indices {
            let opening = try CTCOMoveOneCommitment.merkleOpening(
                proofKind: header.kind,
                contextBinder: header.ctcoContextBinder,
                traceBlocks: traceBlocks,
                leafIndex: index
            )
            guard opening.verifies(root: commitment.root) else {
                throw SuperNeoError.verificationFailed("proof envelope CTCO Merkle opening mismatch")
            }
        }
        if let expectedRoot, expectedRoot != commitment.root {
            throw SuperNeoError.verificationFailed("proof envelope CTCO root mismatch")
        }
        let challengeTapeSeed = SuperNeoSplitQRO.challengeTapeSeed(
            proofKind: header.kind,
            contextBinder: header.ctcoContextBinder,
            root: commitment.root,
            label: challengeTapeLabel
        )
        if let expectedChallengeTapeSeed, expectedChallengeTapeSeed != challengeTapeSeed {
            throw SuperNeoError.verificationFailed("proof envelope CTCO challenge seed mismatch")
        }
        return ProofEnvelopeCTCOReport(
            proofKind: header.kind,
            contextBinder: header.ctcoContextBinder,
            root: commitment.root,
            challengeTapeSeed: challengeTapeSeed,
            bodyDigest: Digest256.hash(body),
            traceBlockCount: traceBlocks.count
        )
    }

    public static func traceBlocks(header: ProofEnvelopeHeader, body: [UInt8]) -> [CTCOTraceBlock] {
        [
            CTCOTraceBlock(label: "envelope-transcript-prefix", bytes: header.transcriptBindingBytes),
            CTCOTraceBlock(label: "envelope-body-length", bytes: SuperNeoSplitQRO.encodeUInt64(UInt64(body.count))),
            CTCOTraceBlock(label: "envelope-body-digest", bytes: Digest256.hash(body).superNeoBytes),
            CTCOTraceBlock(label: "\(header.kind.ctcoDomainComponent)-body-commitment", bytes: bodyCommitment(header: header, body: body).superNeoBytes)
        ]
    }

    private static func bodyCommitment(header: ProofEnvelopeHeader, body: [UInt8]) -> Digest384 {
        SuperNeoSplitQRO.hMerkleLeaf(
            domain: "superneo/numiseal/ctco/body/\(header.kind.ctcoDomainComponent)/v2",
            frames: [
                [header.kind.rawValue],
                header.ctcoContextBinder.superNeoBytes,
                SuperNeoSplitQRO.encodeUInt64(UInt64(body.count)),
                body
            ]
        )
    }
}

public enum SuperNeoTheoremBinding {
    public static func digestBinder(
        kind: ProofEnvelopeKind,
        label: String,
        digest: Digest256
    ) -> Digest384 {
        SuperNeoSplitQRO.hBind(
            domain: "superneo/numiseal/bind/target/\(kind.ctcoDomainComponent)/v2",
            frames: [
                [kind.rawValue],
                Array(label.utf8),
                digest.superNeoBytes
            ]
        )
    }

    public static func digestListBinder(
        kind: ProofEnvelopeKind,
        label: String,
        digests: [Digest256]
    ) -> Digest384 {
        SuperNeoSplitQRO.hBind(
            domain: "superneo/numiseal/bind/target-list/\(kind.ctcoDomainComponent)/v2",
            frames: [
                [kind.rawValue],
                Array(label.utf8),
                SuperNeoSplitQRO.encodeUInt64(UInt64(digests.count)),
                digests.flatMap(\.superNeoBytes)
            ]
        )
    }
}

public extension ProofEnvelopeContext {
    var ctcoContextBinder: Digest384 {
        SuperNeoSplitQRO.hBind(
            domain: "superneo/numiseal/ctco/ctx/\(kind.ctcoDomainComponent)/v2",
            frames: [
                [kind.rawValue],
                transcriptBindingBytes
            ]
        )
    }
}

public extension ProofEnvelopeHeader {
    var contextForBinding: ProofEnvelopeContext {
        ProofEnvelopeContext(
            profileID: profileID,
            kind: kind,
            shapeDigest: shapeDigest,
            statementDigest: statementDigest,
            verifierKeyDigest: verifierKeyDigest,
            transcriptDomain: transcriptDomain
        )
    }

    var ctcoContextBinder: Digest384 {
        contextForBinding.ctcoContextBinder
    }
}

public extension ProofEnvelopeKind {
    var ctcoDomainComponent: String {
        switch self {
        case .foldReduction:
            return "fold"
        case .terminalLocal:
            return "terminal"
        case .compressedPublic:
            return "compressed-terminal"
        case .numiSealTerminal:
            return "numiseal-terminal"
        case .numiSealZK:
            return "numiseal-zk-product"
        }
    }
}

private enum SuperNeoSHAKEFrame {
    case bytes([UInt8])
    case utf8(String)
    case byte(UInt8)
    case uint64LE(UInt64)
}

private enum SuperNeoSHAKE256 {
    private static let rate = 136
    private static let suffix: UInt8 = 0x1f

    static func squeeze(_ input: [UInt8], outputByteCount: Int) -> [UInt8] {
        precondition(outputByteCount >= 0, "outputByteCount must be non-negative")
        var state = [UInt64](repeating: 0, count: 25)
        var offset = 0
        while offset + rate <= input.count {
            xorRateBytes(input, offset: offset, into: &state)
            KeccakF1600.permute(&state)
            offset += rate
        }

        var finalBlock = [UInt8](repeating: 0, count: rate)
        if offset < input.count {
            finalBlock.replaceSubrange(0..<(input.count - offset), with: input[offset..<input.count])
        }
        finalBlock[input.count - offset] ^= suffix
        finalBlock[rate - 1] ^= 0x80
        xorBlock(finalBlock, into: &state)
        KeccakF1600.permute(&state)

        return squeezeOutput(from: &state, outputByteCount: outputByteCount)
    }

    static func squeezeFramed(domain: String, frames: [[UInt8]], outputByteCount: Int) -> [UInt8] {
        precondition(outputByteCount >= 0, "outputByteCount must be non-negative")
        var state = [UInt64](repeating: 0, count: 25)
        var block = [UInt8](repeating: 0, count: rate)
        var blockByteCount = 0

        func absorb(_ bytes: [UInt8]) {
            var offset = 0
            while offset < bytes.count {
                if blockByteCount == 0, bytes.count - offset >= rate {
                    SuperNeoSHAKE256.xorRateBytes(bytes, offset: offset, into: &state)
                    KeccakF1600.permute(&state)
                    offset += rate
                    continue
                }
                let take = min(rate - blockByteCount, bytes.count - offset)
                for byteIndex in 0..<take {
                    block[blockByteCount + byteIndex] = bytes[offset + byteIndex]
                }
                blockByteCount += take
                offset += take
                if blockByteCount == rate {
                    xorBlock(block, into: &state)
                    KeccakF1600.permute(&state)
                    zeroRateBlock(&block)
                    blockByteCount = 0
                }
            }
        }

        func absorbByte(_ byte: UInt8) {
            block[blockByteCount] = byte
            blockByteCount += 1
            if blockByteCount == rate {
                SuperNeoSHAKE256.xorBlock(block, into: &state)
                KeccakF1600.permute(&state)
                SuperNeoSHAKE256.zeroRateBlock(&block)
                blockByteCount = 0
            }
        }

        func absorbLength(_ value: UInt64) {
            for byteIndex in 0..<8 {
                absorbByte(UInt8(truncatingIfNeeded: value >> UInt64(byteIndex * 8)))
            }
        }

        func absorbFrame(_ bytes: [UInt8]) {
            absorbLength(UInt64(bytes.count))
            absorb(bytes)
        }

        absorbLength(UInt64(domain.utf8.count))
        for byte in domain.utf8 {
            absorbByte(byte)
        }
        for frame in frames {
            absorbFrame(frame)
        }
        block[blockByteCount] ^= suffix
        block[rate - 1] ^= 0x80
        xorBlock(block, into: &state)
        KeccakF1600.permute(&state)
        return squeezeOutput(from: &state, outputByteCount: outputByteCount)
    }

    static func squeezeFramedFast(domain: String, frames: [SuperNeoSHAKEFrame], outputByteCount: Int) -> [UInt8] {
        precondition(outputByteCount >= 0, "outputByteCount must be non-negative")
        var state = [UInt64](repeating: 0, count: 25)
        var block = [UInt8](repeating: 0, count: rate)
        var blockByteCount = 0

        func absorb(_ bytes: [UInt8]) {
            var offset = 0
            while offset < bytes.count {
                if blockByteCount == 0, bytes.count - offset >= rate {
                    SuperNeoSHAKE256.xorRateBytes(bytes, offset: offset, into: &state)
                    KeccakF1600.permute(&state)
                    offset += rate
                    continue
                }
                let take = min(rate - blockByteCount, bytes.count - offset)
                for byteIndex in 0..<take {
                    block[blockByteCount + byteIndex] = bytes[offset + byteIndex]
                }
                blockByteCount += take
                offset += take
                if blockByteCount == rate {
                    SuperNeoSHAKE256.xorBlock(block, into: &state)
                    KeccakF1600.permute(&state)
                    SuperNeoSHAKE256.zeroRateBlock(&block)
                    blockByteCount = 0
                }
            }
        }

        func absorbByte(_ byte: UInt8) {
            block[blockByteCount] = byte
            blockByteCount += 1
            if blockByteCount == rate {
                SuperNeoSHAKE256.xorBlock(block, into: &state)
                KeccakF1600.permute(&state)
                SuperNeoSHAKE256.zeroRateBlock(&block)
                blockByteCount = 0
            }
        }

        func absorbLength(_ value: UInt64) {
            for byteIndex in 0..<8 {
                absorbByte(UInt8(truncatingIfNeeded: value >> UInt64(byteIndex * 8)))
            }
        }

        func absorbUTF8(_ string: String) {
            absorbLength(UInt64(string.utf8.count))
            for byte in string.utf8 {
                absorbByte(byte)
            }
        }

        func absorbFrame(_ frame: SuperNeoSHAKEFrame) {
            switch frame {
            case .bytes(let bytes):
                absorbLength(UInt64(bytes.count))
                absorb(bytes)
            case .utf8(let string):
                absorbUTF8(string)
            case .byte(let byte):
                absorbLength(1)
                absorbByte(byte)
            case .uint64LE(let value):
                absorbLength(8)
                for byteIndex in 0..<8 {
                    absorbByte(UInt8(truncatingIfNeeded: value >> UInt64(byteIndex * 8)))
                }
            }
        }

        absorbUTF8(domain)
        for frame in frames {
            absorbFrame(frame)
        }
        block[blockByteCount] ^= suffix
        block[rate - 1] ^= 0x80
        xorBlock(block, into: &state)
        KeccakF1600.permute(&state)
        return squeezeOutput(from: &state, outputByteCount: outputByteCount)
    }

    private static func xorBlock(_ block: [UInt8], into state: inout [UInt64]) {
        precondition(block.count == rate, "SHAKE256 block must match rate")
        xorRateBytes(block, offset: 0, into: &state)
    }

    private static func xorRateBytes(_ bytes: [UInt8], offset: Int, into state: inout [UInt64]) {
        precondition(offset >= 0 && offset + rate <= bytes.count, "SHAKE256 block range must match rate")
        bytes.withUnsafeBytes { rawBytes in
            for laneIndex in 0..<(rate / 8) {
                let lane = rawBytes.loadUnaligned(
                    fromByteOffset: offset + laneIndex * MemoryLayout<UInt64>.size,
                    as: UInt64.self
                ).littleEndian
                state[laneIndex] ^= lane
            }
        }
    }

    private static func zeroRateBlock(_ block: inout [UInt8]) {
        for index in block.indices {
            block[index] = 0
        }
    }

    static func loadUInt64LE(_ bytes: [UInt8], offset: Int) -> UInt64 {
        precondition(offset >= 0 && offset + MemoryLayout<UInt64>.size <= bytes.count, "UInt64 byte range out of bounds")
        return bytes.withUnsafeBytes {
            $0.loadUnaligned(fromByteOffset: offset, as: UInt64.self).littleEndian
        }
    }

    private static func appendStateRateBytes(
        _ state: [UInt64],
        to output: inout [UInt8],
        maxByteCount: Int
    ) {
        var remaining = maxByteCount
        for lane in state.prefix(rate / 8) {
            guard remaining > 0 else { return }
            var littleEndianLane = lane.littleEndian
            withUnsafeBytes(of: &littleEndianLane) { laneBytes in
                let count = min(remaining, laneBytes.count)
                output.append(contentsOf: laneBytes.prefix(count))
                remaining -= count
            }
        }
    }

    private static func squeezeOutput(from state: inout [UInt64], outputByteCount: Int) -> [UInt8] {
        var output: [UInt8] = []
        output.reserveCapacity(outputByteCount)
        while output.count < outputByteCount {
            let remaining = outputByteCount - output.count
            appendStateRateBytes(state, to: &output, maxByteCount: remaining)
            if output.count < outputByteCount {
                KeccakF1600.permute(&state)
            }
        }
        return output
    }
}

private enum KeccakF1600 {
    private static let roundConstants: [UInt64] = [
        0x0000_0000_0000_0001, 0x0000_0000_0000_8082,
        0x8000_0000_0000_808a, 0x8000_0000_8000_8000,
        0x0000_0000_0000_808b, 0x0000_0000_8000_0001,
        0x8000_0000_8000_8081, 0x8000_0000_0000_8009,
        0x0000_0000_0000_008a, 0x0000_0000_0000_0088,
        0x0000_0000_8000_8009, 0x0000_0000_8000_000a,
        0x0000_0000_8000_808b, 0x8000_0000_0000_008b,
        0x8000_0000_0000_8089, 0x8000_0000_0000_8003,
        0x8000_0000_0000_8002, 0x8000_0000_0000_0080,
        0x0000_0000_0000_800a, 0x8000_0000_8000_000a,
        0x8000_0000_8000_8081, 0x8000_0000_0000_8080,
        0x0000_0000_8000_0001, 0x8000_0000_8000_8008
    ]

    private static let rotationOffsets: [Int] = [
        0, 1, 62, 28, 27,
        36, 44, 6, 55, 20,
        3, 10, 43, 25, 39,
        41, 45, 15, 21, 8,
        18, 2, 61, 56, 14
    ]

    static func permute(_ state: inout [UInt64]) {
        precondition(state.count == 25, "Keccak-f[1600] state must have 25 lanes")
        var c = [UInt64](repeating: 0, count: 5)
        var d = [UInt64](repeating: 0, count: 5)
        var b = [UInt64](repeating: 0, count: 25)
        for roundConstant in roundConstants {
            for x in 0..<5 {
                c[x] = state[x] ^ state[x + 5] ^ state[x + 10] ^ state[x + 15] ^ state[x + 20]
            }
            for x in 0..<5 {
                d[x] = c[(x + 4) % 5] ^ rotateLeft(c[(x + 1) % 5], by: 1)
            }
            for x in 0..<5 {
                for y in 0..<5 {
                    state[x + 5 * y] ^= d[x]
                }
            }

            for x in 0..<5 {
                for y in 0..<5 {
                    let destination = y + 5 * ((2 * x + 3 * y) % 5)
                    b[destination] = rotateLeft(state[x + 5 * y], by: rotationOffsets[x + 5 * y])
                }
            }

            for x in 0..<5 {
                for y in 0..<5 {
                    state[x + 5 * y] = b[x + 5 * y] ^ ((~b[((x + 1) % 5) + 5 * y]) & b[((x + 2) % 5) + 5 * y])
                }
            }
            state[0] ^= roundConstant
        }
    }

    private static func rotateLeft(_ value: UInt64, by amount: Int) -> UInt64 {
        amount == 0 ? value : (value << amount) | (value >> (64 - amount))
    }
}
