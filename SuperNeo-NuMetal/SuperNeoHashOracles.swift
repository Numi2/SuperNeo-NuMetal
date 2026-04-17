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
        Digest256.shake256(framedBytes(domain: domain, frames: frames))
    }

    public static func hBind(domain: String = bindingDomain, frames: [[UInt8]]) -> Digest384 {
        Digest384.shake256(framedBytes(domain: domain, frames: frames))
    }

    public static func hMerkleNode(domain: String = merkleDomain, left: Digest384, right: Digest384) -> Digest384 {
        hBind(domain: domain, frames: [left.superNeoBytes, right.superNeoBytes])
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
        hChal(domain: "\(challengeDomain)/expand", frames: [
            [proofKind.rawValue],
            seed.superNeoBytes,
            Array(label.utf8),
            encodeUInt64(index)
        ])
    }

    public static func appendFrame(_ frame: [UInt8], to bytes: inout [UInt8]) {
        bytes.append(contentsOf: encodeUInt64(UInt64(frame.count)))
        bytes.append(contentsOf: frame)
    }

    public static func encodeUInt64(_ value: UInt64) -> [UInt8] {
        withUnsafeBytes(of: value.littleEndian, Array.init)
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

    public init(proofKind: ProofEnvelopeKind, contextBinder: Digest384, traceBlocks: [CTCOTraceBlock]) {
        self.proofKind = proofKind
        self.contextBinder = contextBinder
        self.root = SuperNeoSplitQRO.hBind(
            domain: "superneo/numiseal/ctco/root/\(proofKind.ctcoDomainComponent)/v2",
            frames: Self.rootFrames(proofKind: proofKind, contextBinder: contextBinder, traceBlocks: traceBlocks)
        )
    }

    private static func rootFrames(
        proofKind: ProofEnvelopeKind,
        contextBinder: Digest384,
        traceBlocks: [CTCOTraceBlock]
    ) -> [[UInt8]] {
        var frames: [[UInt8]] = [
            [proofKind.rawValue],
            contextBinder.superNeoBytes,
            SuperNeoSplitQRO.encodeUInt64(UInt64(traceBlocks.count))
        ]
        for block in traceBlocks {
            frames.append(Array(block.label.utf8))
            frames.append(block.bytes)
        }
        return frames
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

private enum SuperNeoSHAKE256 {
    private static let rate = 136
    private static let suffix: UInt8 = 0x1f

    static func squeeze(_ input: [UInt8], outputByteCount: Int) -> [UInt8] {
        precondition(outputByteCount >= 0, "outputByteCount must be non-negative")
        var state = [UInt64](repeating: 0, count: 25)
        var offset = 0
        while offset + rate <= input.count {
            xorBlock(Array(input[offset..<offset + rate]), into: &state)
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

        var output: [UInt8] = []
        output.reserveCapacity(outputByteCount)
        while output.count < outputByteCount {
            let block = stateRateBytes(state)
            let remaining = outputByteCount - output.count
            output.append(contentsOf: block.prefix(remaining))
            if output.count < outputByteCount {
                KeccakF1600.permute(&state)
            }
        }
        return output
    }

    private static func xorBlock(_ block: [UInt8], into state: inout [UInt64]) {
        precondition(block.count == rate, "SHAKE256 block must match rate")
        for laneIndex in 0..<(rate / 8) {
            var lane: UInt64 = 0
            let base = laneIndex * 8
            for byteIndex in 0..<8 {
                lane |= UInt64(block[base + byteIndex]) << (8 * byteIndex)
            }
            state[laneIndex] ^= lane
        }
    }

    private static func stateRateBytes(_ state: [UInt64]) -> [UInt8] {
        var bytes: [UInt8] = []
        bytes.reserveCapacity(rate)
        for lane in state.prefix(rate / 8) {
            bytes.append(contentsOf: withUnsafeBytes(of: lane.littleEndian, Array.init))
        }
        return bytes
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
        for roundConstant in roundConstants {
            var c = [UInt64](repeating: 0, count: 5)
            var d = [UInt64](repeating: 0, count: 5)
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

            var b = [UInt64](repeating: 0, count: 25)
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
