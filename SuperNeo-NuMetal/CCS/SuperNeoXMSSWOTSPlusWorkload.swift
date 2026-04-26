import Foundation

public enum SuperNeoXMSSWOTSPlusHashMode: UInt8, Equatable, Sendable {
    case algebraicToy = 0
    case sha256OneBlock = 1

    public var canonicalName: String {
        switch self {
        case .algebraicToy:
            return "algebraic-toy-v1"
        case .sha256OneBlock:
            return "sha256-one-block-v1"
        }
    }
}

public struct SuperNeoXMSSWOTSPlusParameters: Equatable, Sendable, SuperNeoByteEncodable {
    public let baseW: Int
    public let messageDigitCount: Int
    public let treeHeight: Int
    public let hashRoundCount: Int
    public let hashMode: SuperNeoXMSSWOTSPlusHashMode

    public init(
        baseW: Int = 4,
        messageDigitCount: Int,
        treeHeight: Int,
        hashRoundCount: Int = 32,
        hashMode: SuperNeoXMSSWOTSPlusHashMode = .algebraicToy
    ) throws {
        guard baseW >= 2, baseW <= 16, baseW.nonzeroBitCount == 1 else {
            throw SuperNeoError.invalidParameter("XMSS/WOTS+ base_w must be a power of two between 2 and 16")
        }
        guard messageDigitCount > 0, messageDigitCount <= 256 else {
            throw SuperNeoError.invalidParameter("XMSS/WOTS+ message digit count is out of range")
        }
        guard treeHeight > 0, treeHeight <= 16 else {
            throw SuperNeoError.invalidParameter("XMSS tree height is out of range")
        }
        guard hashRoundCount >= 8, hashRoundCount <= 64 else {
            throw SuperNeoError.invalidParameter("XMSS/WOTS+ binary hash round count is out of range")
        }
        self.baseW = baseW
        self.messageDigitCount = messageDigitCount
        self.treeHeight = treeHeight
        self.hashRoundCount = hashRoundCount
        self.hashMode = hashMode
    }

    public var logW: Int {
        var value = baseW
        var result = 0
        while value > 1 {
            value >>= 1
            result += 1
        }
        return result
    }

    public var checksumDigitCount: Int {
        let maximumChecksum = messageDigitCount * (baseW - 1)
        var count = 1
        var capacity = baseW
        while capacity <= maximumChecksum {
            count += 1
            capacity *= baseW
        }
        return count
    }

    public var wotsLength: Int {
        messageDigitCount + checksumDigitCount
    }

    public var leafCount: Int {
        1 << treeHeight
    }

    public var wotsChainHashInvocationCount: Int {
        wotsLength * (baseW - 1)
    }

    public var lTreeHashInvocationCount: Int {
        max(0, wotsLength - 1)
    }

    public var authenticationPathHashInvocationCount: Int {
        treeHeight
    }

    public var hashInvocationCountPerSignature: Int {
        wotsChainHashInvocationCount
            + lTreeHashInvocationCount
            + authenticationPathHashInvocationCount
    }

    public var hashProductWitnessCountPerSignature: Int {
        hashInvocationCountPerSignature * hashRoundCount
    }

    public var superNeoBytes: [UInt8] {
        xmssEncodeCount(baseW)
            + xmssEncodeCount(messageDigitCount)
            + xmssEncodeCount(treeHeight)
            + xmssEncodeCount(hashRoundCount)
            + [hashMode.rawValue]
    }

    public func checksumDigits(for messageDigits: [Int]) throws -> [Int] {
        try validateMessageDigits(messageDigits)
        var checksum = messageDigits.reduce(0) { partial, digit in
            partial + (baseW - 1 - digit)
        }
        var digits: [Int] = []
        digits.reserveCapacity(checksumDigitCount)
        for _ in 0..<checksumDigitCount {
            digits.append(checksum % baseW)
            checksum /= baseW
        }
        guard checksum == 0 else {
            throw SuperNeoError.invalidParameter("XMSS/WOTS+ checksum does not fit checksum digit count")
        }
        return digits
    }

    public func validateMessageDigits(_ digits: [Int]) throws {
        guard digits.count == messageDigitCount else {
            throw SuperNeoError.invalidParameter("XMSS/WOTS+ message digit count mismatch")
        }
        guard digits.allSatisfy({ $0 >= 0 && $0 < baseW }) else {
            throw SuperNeoError.invalidParameter("XMSS/WOTS+ message digit is out of range")
        }
    }
}

public struct SuperNeoXMSSWOTSPlusSignatureInstance: Equatable, Sendable {
    public let parameters: SuperNeoXMSSWOTSPlusParameters
    public let root: GoldilocksField
    public let messageDigits: [Int]
    public let leafIndex: Int
    public let signatureElements: [GoldilocksField]
    public let authenticationPath: [GoldilocksField]

    public init(
        parameters: SuperNeoXMSSWOTSPlusParameters,
        root: GoldilocksField,
        messageDigits: [Int],
        leafIndex: Int,
        signatureElements: [GoldilocksField],
        authenticationPath: [GoldilocksField]
    ) throws {
        guard parameters.hashMode == .algebraicToy else {
            throw SuperNeoError.invalidParameter("XMSS/WOTS+ algebraic-toy signature instance requires algebraic-toy hash mode")
        }
        try parameters.validateMessageDigits(messageDigits)
        guard leafIndex >= 0, leafIndex < parameters.leafCount else {
            throw SuperNeoError.invalidParameter("XMSS leaf index is out of range")
        }
        guard signatureElements.count == parameters.wotsLength else {
            throw SuperNeoError.invalidParameter("XMSS/WOTS+ signature element count mismatch")
        }
        guard authenticationPath.count == parameters.treeHeight else {
            throw SuperNeoError.invalidParameter("XMSS authentication path height mismatch")
        }
        guard ([root] + signatureElements + authenticationPath).allSatisfy({ $0 == .zero || $0 == .one }) else {
            throw SuperNeoError.invalidParameter("XMSS/WOTS+ bit-sliced signature values must be Boolean")
        }
        let reconstructedRoot = try SuperNeoXMSSWOTSPlusReference.reconstructRoot(
            parameters: parameters,
            messageDigits: messageDigits,
            leafIndex: leafIndex,
            signatureElements: signatureElements,
            authenticationPath: authenticationPath
        )
        guard reconstructedRoot == root else {
            throw SuperNeoError.invalidParameter("XMSS/WOTS+ signature does not reconstruct the supplied root")
        }
        self.parameters = parameters
        self.root = root
        self.messageDigits = messageDigits
        self.leafIndex = leafIndex
        self.signatureElements = signatureElements
        self.authenticationPath = authenticationPath
    }

    public var leafIndexBits: [Bool] {
        (0..<parameters.treeHeight).map { bit in
            ((leafIndex >> bit) & 1) == 1
        }
    }

    public var publicDigest: Digest256 {
        Digest256.hash(
            Array("SuperNeo-NuMetal.xmss-wots-plus.public.v1".utf8)
                + parameters.superNeoBytes
                + root.superNeoBytes
                + xmssEncodeCount(leafIndex)
                + messageDigits.flatMap(xmssEncodeCount)
        )
    }

    public var signatureDigest: Digest256 {
        Digest256.hash(
            Array("SuperNeo-NuMetal.xmss-wots-plus.signature.v1".utf8)
                + parameters.superNeoBytes
                + signatureElements.flatMap(\.superNeoBytes)
                + authenticationPath.flatMap(\.superNeoBytes)
        )
    }

    public var instanceDigest: Digest256 {
        Digest256.hash(
            Array("SuperNeo-NuMetal.xmss-wots-plus.instance.v1".utf8)
                + publicDigest.superNeoBytes
                + signatureDigest.superNeoBytes
        )
    }
}

public enum SuperNeoXMSSWOTSPlusReference {
    public static func sign(
        seed: [UInt8],
        parameters: SuperNeoXMSSWOTSPlusParameters,
        messageDigits: [Int],
        leafIndex: Int
    ) throws -> SuperNeoXMSSWOTSPlusSignatureInstance {
        try requireAlgebraicToy(parameters)
        try parameters.validateMessageDigits(messageDigits)
        guard leafIndex >= 0, leafIndex < parameters.leafCount else {
            throw SuperNeoError.invalidParameter("XMSS leaf index is out of range")
        }
        let allDigits = try messageDigits + parameters.checksumDigits(for: messageDigits)
        let signature = try allDigits.enumerated().map { pair in
            try chain(
                start: secretElement(seed: seed, parameters: parameters, leafIndex: leafIndex, chainIndex: pair.offset),
                parameters: parameters,
                leafIndex: leafIndex,
                chainIndex: pair.offset,
                fromStep: 0,
                stepCount: pair.element
            )
        }
        let tree = try merkleTree(seed: seed, parameters: parameters)
        var path: [GoldilocksField] = []
        path.reserveCapacity(parameters.treeHeight)
        var nodeIndex = leafIndex
        for height in 0..<parameters.treeHeight {
            path.append(tree[height][nodeIndex ^ 1])
            nodeIndex >>= 1
        }
        return try SuperNeoXMSSWOTSPlusSignatureInstance(
            parameters: parameters,
            root: tree[parameters.treeHeight][0],
            messageDigits: messageDigits,
            leafIndex: leafIndex,
            signatureElements: signature,
            authenticationPath: path
        )
    }

    public static func reconstructRoot(
        parameters: SuperNeoXMSSWOTSPlusParameters,
        messageDigits: [Int],
        leafIndex: Int,
        signatureElements: [GoldilocksField],
        authenticationPath: [GoldilocksField]
    ) throws -> GoldilocksField {
        try requireAlgebraicToy(parameters)
        try parameters.validateMessageDigits(messageDigits)
        guard signatureElements.count == parameters.wotsLength else {
            throw SuperNeoError.invalidParameter("XMSS/WOTS+ signature element count mismatch")
        }
        guard authenticationPath.count == parameters.treeHeight else {
            throw SuperNeoError.invalidParameter("XMSS authentication path height mismatch")
        }
        let allDigits = try messageDigits + parameters.checksumDigits(for: messageDigits)
        let publicKey = try allDigits.enumerated().map { pair in
            try chain(
                start: signatureElements[pair.offset],
                parameters: parameters,
                leafIndex: leafIndex,
                chainIndex: pair.offset,
                fromStep: pair.element,
                stepCount: parameters.baseW - 1 - pair.element
            )
        }
        var node = try lTree(publicKey, parameters: parameters, leafIndex: leafIndex)
        var nodeIndex = leafIndex
        for height in 0..<parameters.treeHeight {
            let sibling = authenticationPath[height]
            if (nodeIndex & 1) == 0 {
                node = binaryNodeHash(
                    node,
                    sibling,
                    parameters: parameters,
                    context: "xmss-node-\(height)"
                )
            } else {
                node = binaryNodeHash(
                    sibling,
                    node,
                    parameters: parameters,
                    context: "xmss-node-\(height)"
                )
            }
            nodeIndex >>= 1
        }
        return node
    }

    static func secretElement(
        seed: [UInt8],
        parameters: SuperNeoXMSSWOTSPlusParameters,
        leafIndex: Int,
        chainIndex: Int
    ) -> GoldilocksField {
        let field = fieldFromDigest(
            Digest256.hash(
                Array("SuperNeo-NuMetal.xmss-wots-plus.secret.v1".utf8)
                    + parameters.superNeoBytes
                    + xmssEncodeCount(seed.count)
                    + seed
                    + xmssEncodeCount(leafIndex)
                    + xmssEncodeCount(chainIndex)
            )
        )
        return GoldilocksField(field.rawValue & 1)
    }

    static func wotsPublicKey(
        seed: [UInt8],
        parameters: SuperNeoXMSSWOTSPlusParameters,
        leafIndex: Int
    ) throws -> [GoldilocksField] {
        try (0..<parameters.wotsLength).map { chainIndex in
            try chain(
                start: secretElement(seed: seed, parameters: parameters, leafIndex: leafIndex, chainIndex: chainIndex),
                parameters: parameters,
                leafIndex: leafIndex,
                chainIndex: chainIndex,
                fromStep: 0,
                stepCount: parameters.baseW - 1
            )
        }
    }

    static func merkleTree(
        seed: [UInt8],
        parameters: SuperNeoXMSSWOTSPlusParameters
    ) throws -> [[GoldilocksField]] {
        var levels: [[GoldilocksField]] = [
            try (0..<parameters.leafCount).map { leafIndex in
                try lTree(
                    wotsPublicKey(seed: seed, parameters: parameters, leafIndex: leafIndex),
                    parameters: parameters,
                    leafIndex: leafIndex
                )
            }
        ]
        for height in 0..<parameters.treeHeight {
            let previous = levels[height]
            var next: [GoldilocksField] = []
            next.reserveCapacity(previous.count / 2)
            for index in stride(from: 0, to: previous.count, by: 2) {
                next.append(
                    binaryNodeHash(
                        previous[index],
                        previous[index + 1],
                        parameters: parameters,
                        context: "xmss-node-\(height)"
                    )
                )
            }
            levels.append(next)
        }
        return levels
    }

    static func lTree(
        _ publicKey: [GoldilocksField],
        parameters: SuperNeoXMSSWOTSPlusParameters,
        leafIndex: Int
    ) throws -> GoldilocksField {
        guard publicKey.count == parameters.wotsLength else {
            throw SuperNeoError.invalidParameter("XMSS L-tree public key length mismatch")
        }
        var layer = publicKey
        var level = 0
        while layer.count > 1 {
            var next: [GoldilocksField] = []
            next.reserveCapacity((layer.count + 1) / 2)
            for index in stride(from: 0, to: layer.count - 1, by: 2) {
                next.append(
                    binaryNodeHash(
                        layer[index],
                        layer[index + 1],
                        parameters: parameters,
                        context: "wots-ltree-\(level)-\(index / 2)"
                    )
                )
            }
            if layer.count % 2 == 1 {
                next.append(layer[layer.count - 1])
            }
            layer = next
            level += 1
        }
        return layer[0]
    }

    static func chain(
        start: GoldilocksField,
        parameters: SuperNeoXMSSWOTSPlusParameters,
        leafIndex: Int,
        chainIndex: Int,
        fromStep: Int,
        stepCount: Int
    ) throws -> GoldilocksField {
        guard fromStep >= 0, stepCount >= 0, fromStep + stepCount <= parameters.baseW - 1 else {
            throw SuperNeoError.invalidParameter("XMSS/WOTS+ chain step range is out of bounds")
        }
        var state = start
        for step in fromStep..<(fromStep + stepCount) {
            state = binaryAddressHash(
                state,
                addressBit: addressBitField(leafIndex: leafIndex, treeHeight: parameters.treeHeight, selector: chainIndex + step),
                parameters: parameters,
                context: "wots-chain-\(chainIndex)-\(step)"
            )
        }
        return state
    }

    static func binaryAddressHash(
        _ state: GoldilocksField,
        addressBit: GoldilocksField,
        parameters: SuperNeoXMSSWOTSPlusParameters,
        context: String
    ) -> GoldilocksField {
        binaryHashTrace(
            state,
            addressBit,
            parameters: parameters,
            context: context
        ).digest
    }

    static func binaryNodeHash(
        _ left: GoldilocksField,
        _ right: GoldilocksField,
        parameters: SuperNeoXMSSWOTSPlusParameters,
        context: String
    ) -> GoldilocksField {
        binaryHashTrace(
            left,
            right,
            parameters: parameters,
            context: context
        ).digest
    }

    static func binaryHashTrace(
        _ lhs: GoldilocksField,
        _ rhs: GoldilocksField,
        parameters: SuperNeoXMSSWOTSPlusParameters,
        context: String
    ) -> (digest: GoldilocksField, products: [GoldilocksField]) {
        var state = lhs
        var products: [GoldilocksField] = []
        products.reserveCapacity(parameters.hashRoundCount)
        for round in 0..<parameters.hashRoundCount {
            let roundOther = round == 0
                ? rhs
                : (binaryRoundOtherConstant(parameters: parameters, context: context, round: round) ? GoldilocksField.one : .zero)
            let product = state * roundOther
            products.append(product)
            var next = state + roundOther - GoldilocksField(2) * product
            if binaryRoundConstant(parameters: parameters, context: context, round: round) {
                next = .one - next
            }
            state = next
        }
        return (state, products)
    }

    static func binaryRoundConstant(
        parameters: SuperNeoXMSSWOTSPlusParameters,
        context: String,
        round: Int
    ) -> Bool {
        Digest256.hash(
            Array("SuperNeo-NuMetal.xmss-wots-plus.binary-hash.v1".utf8)
                + parameters.superNeoBytes
                + xmssEncodeString(context)
                + xmssEncodeCount(round)
        ).bytes[0] & 1 == 1
    }

    static func binaryRoundOtherConstant(
        parameters: SuperNeoXMSSWOTSPlusParameters,
        context: String,
        round: Int
    ) -> Bool {
        Digest256.hash(
            Array("SuperNeo-NuMetal.xmss-wots-plus.binary-hash-round-input.v1".utf8)
                + parameters.superNeoBytes
                + xmssEncodeString(context)
                + xmssEncodeCount(round)
        ).bytes[0] & 1 == 1
    }

    private static func requireAlgebraicToy(_ parameters: SuperNeoXMSSWOTSPlusParameters) throws {
        guard parameters.hashMode == .algebraicToy else {
            throw SuperNeoError.invalidParameter("XMSS/WOTS+ algebraic-toy reference requires algebraic-toy hash mode")
        }
    }
}

public struct SuperNeoSHA256WOTSPlusChainHashCall: Equatable, Sendable {
    public let parameters: SuperNeoXMSSWOTSPlusParameters
    public let leafIndex: Int
    public let chainIndex: Int
    public let step: Int
    public let inputDigest: Digest256
    public let outputDigest: Digest256
    public let message: [UInt8]

    public var callDigest: Digest256 {
        Digest256.hash(
            Array("SuperNeo-NuMetal.sha256-wots-plus.chain-call.v1".utf8)
                + parameters.superNeoBytes
                + xmssEncodeCount(leafIndex)
                + xmssEncodeCount(chainIndex)
                + xmssEncodeCount(step)
                + inputDigest.superNeoBytes
                + outputDigest.superNeoBytes
                + xmssEncodeCount(message.count)
                + message
        )
    }
}

public struct SuperNeoSHA256WOTSPlusChainInstance: Equatable, Sendable {
    public let parameters: SuperNeoXMSSWOTSPlusParameters
    public let messageDigits: [Int]
    public let leafIndex: Int
    public let signatureElements: [Digest256]
    public let publicKey: [Digest256]

    public init(
        parameters: SuperNeoXMSSWOTSPlusParameters,
        messageDigits: [Int],
        leafIndex: Int,
        signatureElements: [Digest256],
        publicKey: [Digest256]
    ) throws {
        try SuperNeoSHA256WOTSPlusReference.validateSHA256OneBlockParameters(parameters)
        try parameters.validateMessageDigits(messageDigits)
        guard leafIndex >= 0, leafIndex < parameters.leafCount else {
            throw SuperNeoError.invalidParameter("SHA-256 WOTS+ leaf index is out of range")
        }
        guard signatureElements.count == parameters.wotsLength,
              publicKey.count == parameters.wotsLength else {
            throw SuperNeoError.invalidParameter("SHA-256 WOTS+ chain element count mismatch")
        }
        let expectedPublicKey = try SuperNeoSHA256WOTSPlusReference.publicKey(
            parameters: parameters,
            messageDigits: messageDigits,
            leafIndex: leafIndex,
            signatureElements: signatureElements
        )
        guard expectedPublicKey == publicKey else {
            throw SuperNeoError.invalidParameter("SHA-256 WOTS+ chain signature does not reconstruct the supplied public key")
        }
        self.parameters = parameters
        self.messageDigits = messageDigits
        self.leafIndex = leafIndex
        self.signatureElements = signatureElements
        self.publicKey = publicKey
    }

    public var instanceDigest: Digest256 {
        Digest256.hash(
            Array("SuperNeo-NuMetal.sha256-wots-plus.chain-instance.v1".utf8)
                + parameters.superNeoBytes
                + xmssEncodeCount(leafIndex)
                + messageDigits.flatMap(xmssEncodeCount)
                + signatureElements.flatMap(\.superNeoBytes)
                + publicKey.flatMap(\.superNeoBytes)
        )
    }
}

public enum SuperNeoSHA256WOTSPlusReference {
    public static let chainMessageByteCount = 52

    public static func validateSHA256OneBlockParameters(_ parameters: SuperNeoXMSSWOTSPlusParameters) throws {
        guard parameters.hashMode == .sha256OneBlock else {
            throw SuperNeoError.invalidParameter("SHA-256 WOTS+ reference requires sha256-one-block hash mode")
        }
        guard parameters.baseW <= 16 else {
            throw SuperNeoError.invalidParameter("SHA-256 WOTS+ base_w is out of range")
        }
        guard parameters.wotsLength <= UInt16.max else {
            throw SuperNeoError.invalidParameter("SHA-256 WOTS+ chain count exceeds one-block address encoding")
        }
        guard parameters.leafCount <= Int(UInt16.max) + 1 else {
            throw SuperNeoError.invalidParameter("SHA-256 WOTS+ leaf count exceeds one-block address encoding")
        }
    }

    public static func chainStepMessage(
        inputDigest: Digest256,
        parameters: SuperNeoXMSSWOTSPlusParameters,
        leafIndex: Int,
        chainIndex: Int,
        step: Int
    ) throws -> [UInt8] {
        try validateSHA256OneBlockParameters(parameters)
        guard leafIndex >= 0, leafIndex < parameters.leafCount else {
            throw SuperNeoError.invalidParameter("SHA-256 WOTS+ leaf index is out of range")
        }
        guard chainIndex >= 0, chainIndex < parameters.wotsLength else {
            throw SuperNeoError.invalidParameter("SHA-256 WOTS+ chain index is out of range")
        }
        guard step >= 0, step < parameters.baseW - 1 else {
            throw SuperNeoError.invalidParameter("SHA-256 WOTS+ chain step is out of range")
        }
        let message = Array("SNWOTS1\0".utf8)
            + xmssEncodeUInt16(parameters.baseW)
            + xmssEncodeUInt16(parameters.messageDigitCount)
            + xmssEncodeUInt16(parameters.treeHeight)
            + xmssEncodeUInt16(leafIndex)
            + xmssEncodeUInt16(chainIndex)
            + xmssEncodeUInt16(step)
            + inputDigest.superNeoBytes
        guard message.count == chainMessageByteCount else {
            throw SuperNeoError.invalidParameter("SHA-256 WOTS+ chain message length mismatch")
        }
        return message
    }

    public static func chainStep(
        inputDigest: Digest256,
        parameters: SuperNeoXMSSWOTSPlusParameters,
        leafIndex: Int,
        chainIndex: Int,
        step: Int
    ) throws -> SuperNeoSHA256WOTSPlusChainHashCall {
        let message = try chainStepMessage(
            inputDigest: inputDigest,
            parameters: parameters,
            leafIndex: leafIndex,
            chainIndex: chainIndex,
            step: step
        )
        return SuperNeoSHA256WOTSPlusChainHashCall(
            parameters: parameters,
            leafIndex: leafIndex,
            chainIndex: chainIndex,
            step: step,
            inputDigest: inputDigest,
            outputDigest: Digest256.hash(message),
            message: message
        )
    }

    public static func publicKey(
        parameters: SuperNeoXMSSWOTSPlusParameters,
        messageDigits: [Int],
        leafIndex: Int,
        signatureElements: [Digest256]
    ) throws -> [Digest256] {
        try validateSHA256OneBlockParameters(parameters)
        try parameters.validateMessageDigits(messageDigits)
        guard signatureElements.count == parameters.wotsLength else {
            throw SuperNeoError.invalidParameter("SHA-256 WOTS+ chain element count mismatch")
        }
        let allDigits = try messageDigits + parameters.checksumDigits(for: messageDigits)
        return try allDigits.enumerated().map { pair in
            var state = signatureElements[pair.offset]
            for step in pair.element..<(parameters.baseW - 1) {
                let call = try chainStep(
                    inputDigest: state,
                    parameters: parameters,
                    leafIndex: leafIndex,
                    chainIndex: pair.offset,
                    step: step
                )
                state = call.outputDigest
            }
            return state
        }
    }

    public static func hashCalls(
        for instance: SuperNeoSHA256WOTSPlusChainInstance
    ) throws -> [SuperNeoSHA256WOTSPlusChainHashCall] {
        let allDigits = try instance.messageDigits + instance.parameters.checksumDigits(for: instance.messageDigits)
        var calls: [SuperNeoSHA256WOTSPlusChainHashCall] = []
        for (chainIndex, digit) in allDigits.enumerated() {
            var state = instance.signatureElements[chainIndex]
            for step in digit..<(instance.parameters.baseW - 1) {
                let call = try chainStep(
                    inputDigest: state,
                    parameters: instance.parameters,
                    leafIndex: instance.leafIndex,
                    chainIndex: chainIndex,
                    step: step
                )
                calls.append(call)
                state = call.outputDigest
            }
            guard state == instance.publicKey[chainIndex] else {
                throw SuperNeoError.invalidParameter("SHA-256 WOTS+ chain trace does not end at the public key")
            }
        }
        return calls
    }
}

public enum SuperNeoSHA256WOTSPlusChainWorkload {
    public static func hashCalls(
        instances: [SuperNeoSHA256WOTSPlusChainInstance]
    ) throws -> [SuperNeoSHA256WOTSPlusChainHashCall] {
        guard let first = instances.first else {
            throw SuperNeoError.invalidParameter("SHA-256 WOTS+ hash-call workload requires at least one signature")
        }
        try SuperNeoSHA256WOTSPlusReference.validateSHA256OneBlockParameters(first.parameters)
        var calls: [SuperNeoSHA256WOTSPlusChainHashCall] = []
        for instance in instances {
            guard instance.parameters == first.parameters else {
                throw SuperNeoError.invalidParameter("SHA-256 WOTS+ hash-call workload requires uniform parameters")
            }
            calls.append(contentsOf: try SuperNeoSHA256WOTSPlusReference.hashCalls(for: instance))
        }
        guard !calls.isEmpty else {
            throw SuperNeoError.invalidParameter("SHA-256 WOTS+ hash-call workload requires at least one chain hash")
        }
        return calls
    }

    public static func prepareHashCallsForFolding(
        instances: [SuperNeoSHA256WOTSPlusChainInstance],
        keySeed: [UInt8],
        parameters superNeoParameters: SuperNeoParameters = .goldilocks,
        executionPolicy: SuperNeoExecutionPolicy = .default
    ) throws -> SuperNeoPreparedR1CS {
        let calls = try hashCalls(instances: instances)
        let workload = try SuperNeoSHA256OneBlockPublicMessageHashWorkload(
            messageByteCount: SuperNeoSHA256WOTSPlusReference.chainMessageByteCount
        )
        let publicInputs = try calls.map {
            try workload.publicInput(message: $0.message, digest: $0.outputDigest)
        }
        let privateWitnesses = try calls.map {
            try workload.privateWitness(message: $0.message)
        }
        let prepared = try SuperNeoCCSNormalizer.prepareForFolding(
            structure: workload.builder.buildStructure(),
            publicInputs: publicInputs,
            privateWitnesses: privateWitnesses,
            keySeed: keySeed,
            parameters: superNeoParameters,
            executionPolicy: executionPolicy
        )
        return SuperNeoPreparedR1CS(
            structure: try workload.builder.buildStructure(),
            preparedFoldInput: prepared
        )
    }
}

public struct SuperNeoXMSSWOTSPlusAggregationWorkload: Sendable {
    public let signatureCount: Int
    public let parameters: SuperNeoXMSSWOTSPlusParameters
    public let builder: SuperNeoR1CSBuilder

    public init(signatureCount: Int, parameters: SuperNeoXMSSWOTSPlusParameters) throws {
        guard parameters.hashMode == .algebraicToy else {
            throw SuperNeoError.invalidParameter("XMSS/WOTS+ aggregation circuit uses the algebraic-toy hash mode")
        }
        guard signatureCount > 0 else {
            throw SuperNeoError.invalidParameter("XMSS/WOTS+ aggregation requires at least one signature")
        }
        guard signatureCount <= 256 else {
            throw SuperNeoError.invalidParameter("XMSS/WOTS+ aggregation workload is too large")
        }
        var builder = SuperNeoR1CSBuilder()
        for _ in 0..<signatureCount {
            let root = builder.addPublicInput()
            builder.enforceBoolean(root)
            let messageDigits = (0..<parameters.messageDigitCount).map { _ in builder.addPublicInput() }
            let leafIndexBits = (0..<parameters.treeHeight).map { _ in builder.addPublicInput() }
            for bit in leafIndexBits {
                builder.enforceBoolean(bit)
            }

            let messageSelectors = messageDigits.map { digit in
                Self.constrainBaseWDigit(digit, parameters: parameters, builder: &builder)
            }
            var checksumDigits: [SuperNeoR1CSVariable] = []
            var checksumSelectors: [[SuperNeoR1CSLinearCombination]] = []
            checksumDigits.reserveCapacity(parameters.checksumDigitCount)
            checksumSelectors.reserveCapacity(parameters.checksumDigitCount)
            for _ in 0..<parameters.checksumDigitCount {
                let digit = builder.addPrivateWitness()
                checksumDigits.append(digit)
                checksumSelectors.append(
                    Self.constrainBaseWDigit(digit, parameters: parameters, builder: &builder)
                )
            }
            Self.constrainChecksum(
                messageDigits: messageDigits,
                checksumDigits: checksumDigits,
                parameters: parameters,
                builder: &builder
            )

            let allSelectors = messageSelectors + checksumSelectors
            let wotsPublicKey = try (0..<parameters.wotsLength).map { chainIndex in
                let signatureElement = builder.addPrivateWitness()
                builder.enforceBoolean(signatureElement)
                return try Self.constrainWOTSChain(
                    signatureElement: signatureElement,
                    digitSelectors: allSelectors[chainIndex],
                    leafIndexBits: leafIndexBits,
                    chainIndex: chainIndex,
                    parameters: parameters,
                    builder: &builder
                )
            }
            var node = try Self.constrainLTree(
                publicKey: wotsPublicKey,
                leafIndexBits: leafIndexBits,
                parameters: parameters,
                builder: &builder
            )
            for height in 0..<parameters.treeHeight {
                let sibling = builder.addPrivateWitness()
                let left = builder.addPrivateWitness()
                let right = builder.addPrivateWitness()
                builder.enforceBoolean(sibling)
                builder.enforceBoolean(left)
                builder.enforceBoolean(right)
                let directionBit = SuperNeoR1CSLinearCombination.variable(leafIndexBits[height])
                builder.enforce(
                    SuperNeoR1CSLinearCombination.variable(sibling).subtracting(node),
                    times: directionBit,
                    equals: SuperNeoR1CSLinearCombination.variable(left).subtracting(node)
                )
                builder.enforce(
                    node.subtracting(.variable(sibling)),
                    times: directionBit,
                    equals: SuperNeoR1CSLinearCombination.variable(right).subtracting(.variable(sibling))
                )
                node = Self.constrainBinaryHash(
                    .variable(left),
                    other: .variable(right),
                    parameters: parameters,
                    context: "xmss-node-\(height)",
                    builder: &builder
                )
            }
            builder.enforce(
                node.subtracting(.variable(root)),
                times: .constant(.one, one: builder.one),
                equals: .zero()
            )
        }
        self.signatureCount = signatureCount
        self.parameters = parameters
        self.builder = builder
    }

    public func publicInput(instances: [SuperNeoXMSSWOTSPlusSignatureInstance]) throws -> [GoldilocksField] {
        try validate(instances)
        var values: [GoldilocksField] = [.one]
        for instance in instances {
            values.append(instance.root)
            values.append(contentsOf: instance.messageDigits.map { GoldilocksField(UInt64($0)) })
            values.append(contentsOf: instance.leafIndexBits.map { $0 ? .one : .zero })
        }
        return values
    }

    public func privateWitness(instances: [SuperNeoXMSSWOTSPlusSignatureInstance]) throws -> [GoldilocksField] {
        try validate(instances)
        var witness: [GoldilocksField] = []
        for instance in instances {
            try appendWitness(for: instance, to: &witness)
        }
        return witness
    }

    public func prepareForFolding(
        instances: [SuperNeoXMSSWOTSPlusSignatureInstance],
        keySeed: [UInt8],
        parameters superNeoParameters: SuperNeoParameters = .goldilocks,
        executionPolicy: SuperNeoExecutionPolicy = .default
    ) throws -> SuperNeoPreparedR1CS {
        try validateFoldableSmallNormParameters()
        return try builder.prepareForFolding(
            publicInput: publicInput(instances: instances),
            privateWitness: privateWitness(instances: instances),
            keySeed: keySeed,
            parameters: superNeoParameters,
            executionPolicy: executionPolicy
        )
    }

    public static func prepareManyForFolding(
        instances: [SuperNeoXMSSWOTSPlusSignatureInstance],
        keySeed: [UInt8],
        parameters superNeoParameters: SuperNeoParameters = .goldilocks,
        executionPolicy: SuperNeoExecutionPolicy = .default
    ) throws -> SuperNeoPreparedR1CS {
        guard let first = instances.first else {
            throw SuperNeoError.invalidParameter("XMSS/WOTS+ many-signature folding requires at least one signature")
        }
        try validateFoldableSmallNormParameters(first.parameters)
        let workload = try Self(signatureCount: 1, parameters: first.parameters)
        let publicInputs = try instances.map { instance in
            try workload.publicInput(instances: [instance])
        }
        let privateWitnesses = try instances.map { instance in
            try workload.privateWitness(instances: [instance])
        }
        for instance in instances where instance.parameters != first.parameters {
            throw SuperNeoError.invalidParameter("XMSS/WOTS+ many-signature folding requires uniform parameters")
        }
        let prepared = try SuperNeoCCSNormalizer.prepareForFolding(
            structure: workload.builder.buildStructure(),
            publicInputs: publicInputs,
            privateWitnesses: privateWitnesses,
            keySeed: keySeed,
            parameters: superNeoParameters,
            executionPolicy: executionPolicy
        )
        return SuperNeoPreparedR1CS(
            structure: try workload.builder.buildStructure(),
            preparedFoldInput: prepared
        )
    }

    public func aggregationDigest(instances: [SuperNeoXMSSWOTSPlusSignatureInstance]) throws -> Digest256 {
        try validate(instances)
        return Digest256.hash(
            Array("SuperNeo-NuMetal.xmss-wots-plus.signature-aggregation.v1".utf8)
                + parameters.superNeoBytes
                + xmssEncodeCount(signatureCount)
                + instances.flatMap { $0.instanceDigest.superNeoBytes }
        )
    }

    private func validate(_ instances: [SuperNeoXMSSWOTSPlusSignatureInstance]) throws {
        guard instances.count == signatureCount else {
            throw SuperNeoError.invalidParameter("XMSS/WOTS+ aggregation signature count mismatch")
        }
        for instance in instances where instance.parameters != parameters {
            throw SuperNeoError.invalidParameter("XMSS/WOTS+ aggregation parameter mismatch")
        }
    }

    private func validateFoldableSmallNormParameters() throws {
        try Self.validateFoldableSmallNormParameters(parameters)
    }

    private static func validateFoldableSmallNormParameters(_ parameters: SuperNeoXMSSWOTSPlusParameters) throws {
        guard parameters.baseW == 2 else {
            throw SuperNeoError.invalidParameter("XMSS/WOTS+ folding under the current small-norm profile requires base_w = 2")
        }
    }

    private func appendWitness(
        for instance: SuperNeoXMSSWOTSPlusSignatureInstance,
        to witness: inout [GoldilocksField]
    ) throws {
        let checksumDigits = try parameters.checksumDigits(for: instance.messageDigits)
        for digit in instance.messageDigits {
            appendDigitWitness(digit, to: &witness)
        }
        for digit in checksumDigits {
            witness.append(GoldilocksField(UInt64(digit)))
            appendDigitWitness(digit, to: &witness)
        }

        let allDigits = instance.messageDigits + checksumDigits
        var publicKey: [GoldilocksField] = []
        publicKey.reserveCapacity(parameters.wotsLength)
        for chainIndex in 0..<parameters.wotsLength {
            var state = instance.signatureElements[chainIndex]
            witness.append(state)
            let digit = allDigits[chainIndex]
            for step in 0..<(parameters.baseW - 1) {
                let hashed = SuperNeoXMSSWOTSPlusReference.binaryHashTrace(
                    state,
                    addressBitField(
                        leafIndex: instance.leafIndex,
                        treeHeight: parameters.treeHeight,
                        selector: chainIndex + step
                    ),
                    parameters: parameters,
                    context: "wots-chain-\(chainIndex)-\(step)"
                )
                witness.append(contentsOf: hashed.products)
                let next = digit <= step ? hashed.digest : state
                witness.append(next)
                state = next
            }
            publicKey.append(state)
        }

        var layer = publicKey
        var level = 0
        while layer.count > 1 {
            var next: [GoldilocksField] = []
            for index in stride(from: 0, to: layer.count - 1, by: 2) {
                let hashed = SuperNeoXMSSWOTSPlusReference.binaryHashTrace(
                    layer[index],
                    layer[index + 1],
                    parameters: parameters,
                    context: "wots-ltree-\(level)-\(index / 2)"
                )
                witness.append(contentsOf: hashed.products)
                next.append(hashed.digest)
            }
            if layer.count % 2 == 1 {
                next.append(layer[layer.count - 1])
            }
            layer = next
            level += 1
        }

        var node = layer[0]
        for height in 0..<parameters.treeHeight {
            let sibling = instance.authenticationPath[height]
            witness.append(sibling)
            let bit = instance.leafIndexBits[height]
            let left = bit ? sibling : node
            let right = bit ? node : sibling
            witness.append(left)
            witness.append(right)
            let hashed = SuperNeoXMSSWOTSPlusReference.binaryHashTrace(
                left,
                right,
                parameters: parameters,
                context: "xmss-node-\(height)"
            )
            witness.append(contentsOf: hashed.products)
            node = hashed.digest
        }
    }

    private func appendDigitWitness(_ digit: Int, to witness: inout [GoldilocksField]) {
        let bits = (0..<parameters.logW).map { bit in
            ((digit >> bit) & 1) == 1
        }
        witness.append(contentsOf: bits.map { $0 ? .one : .zero })
        for value in 0..<parameters.baseW {
            var factors = bits.indices.map { bit -> GoldilocksField in
                let bitValue = bits[bit] ? GoldilocksField.one : .zero
                return ((value >> bit) & 1) == 1 ? bitValue : .one - bitValue
            }
            if factors.count > 1 {
                var product = factors.removeFirst() * factors.removeFirst()
                witness.append(product)
                for factor in factors {
                    product = product * factor
                    witness.append(product)
                }
            }
        }
    }

    private static func constrainBaseWDigit(
        _ digit: SuperNeoR1CSVariable,
        parameters: SuperNeoXMSSWOTSPlusParameters,
        builder: inout SuperNeoR1CSBuilder
    ) -> [SuperNeoR1CSLinearCombination] {
        let bits = (0..<parameters.logW).map { _ -> SuperNeoR1CSVariable in
            let bit = builder.addPrivateWitness()
            builder.enforceBoolean(bit)
            return bit
        }
        var reconstructed = SuperNeoR1CSLinearCombination.zero()
        for (index, bit) in bits.enumerated() {
            reconstructed = reconstructed.adding(.variable(bit, coefficient: GoldilocksField(UInt64(1 << index))))
        }
        builder.enforce(
            reconstructed.subtracting(.variable(digit)),
            times: .constant(.one, one: builder.one),
            equals: .zero()
        )

        let selectors = (0..<parameters.baseW).map { value -> SuperNeoR1CSLinearCombination in
            let factors = bits.enumerated().map { pair -> SuperNeoR1CSLinearCombination in
                let bit = SuperNeoR1CSLinearCombination.variable(pair.element)
                return ((value >> pair.offset) & 1) == 1
                    ? bit
                    : SuperNeoR1CSLinearCombination.constant(.one, one: builder.one).subtracting(bit)
            }
            guard factors.count > 1 else {
                return factors[0]
            }
            var product = builder.addPrivateWitness()
            builder.enforce(factors[0], times: factors[1], equals: .variable(product))
            for factor in factors.dropFirst(2) {
                let next = builder.addPrivateWitness()
                builder.enforce(.variable(product), times: factor, equals: .variable(next))
                product = next
            }
            return .variable(product)
        }
        let selectorSum = selectors.reduce(SuperNeoR1CSLinearCombination.zero()) { $0.adding($1) }
        builder.enforce(
            selectorSum.subtracting(.constant(.one, one: builder.one)),
            times: .constant(.one, one: builder.one),
            equals: .zero()
        )
        return selectors
    }

    private static func constrainChecksum(
        messageDigits: [SuperNeoR1CSVariable],
        checksumDigits: [SuperNeoR1CSVariable],
        parameters: SuperNeoXMSSWOTSPlusParameters,
        builder: inout SuperNeoR1CSBuilder
    ) {
        var lhs = SuperNeoR1CSLinearCombination.constant(
            GoldilocksField(UInt64(messageDigits.count * (parameters.baseW - 1))),
            one: builder.one
        )
        for digit in messageDigits {
            lhs = lhs.subtracting(.variable(digit))
        }
        var rhs = SuperNeoR1CSLinearCombination.zero()
        var weight = 1
        for digit in checksumDigits {
            rhs = rhs.adding(.variable(digit, coefficient: GoldilocksField(UInt64(weight))))
            weight *= parameters.baseW
        }
        builder.enforce(
            lhs.subtracting(rhs),
            times: .constant(.one, one: builder.one),
            equals: .zero()
        )
    }

    private static func constrainWOTSChain(
        signatureElement: SuperNeoR1CSVariable,
        digitSelectors: [SuperNeoR1CSLinearCombination],
        leafIndexBits: [SuperNeoR1CSVariable],
        chainIndex: Int,
        parameters: SuperNeoXMSSWOTSPlusParameters,
        builder: inout SuperNeoR1CSBuilder
    ) throws -> SuperNeoR1CSLinearCombination {
        guard digitSelectors.count == parameters.baseW else {
            throw SuperNeoError.invalidParameter("XMSS/WOTS+ digit selector count mismatch")
        }
        var state = SuperNeoR1CSLinearCombination.variable(signatureElement)
        for step in 0..<(parameters.baseW - 1) {
            let hashed = constrainBinaryHash(
                state,
                other: .variable(leafIndexBits[(chainIndex + step) % leafIndexBits.count]),
                parameters: parameters,
                context: "wots-chain-\(chainIndex)-\(step)",
                builder: &builder
            )
            let apply = (0...step).reduce(SuperNeoR1CSLinearCombination.zero()) { partial, value in
                partial.adding(digitSelectors[value])
            }
            let output = builder.addPrivateWitness()
            builder.enforce(
                hashed.subtracting(state),
                times: apply,
                equals: SuperNeoR1CSLinearCombination.variable(output).subtracting(state)
            )
            builder.enforceBoolean(output)
            state = .variable(output)
        }
        return state
    }

    private static func constrainLTree(
        publicKey: [SuperNeoR1CSLinearCombination],
        leafIndexBits: [SuperNeoR1CSVariable],
        parameters: SuperNeoXMSSWOTSPlusParameters,
        builder: inout SuperNeoR1CSBuilder
    ) throws -> SuperNeoR1CSLinearCombination {
        guard publicKey.count == parameters.wotsLength else {
            throw SuperNeoError.invalidParameter("XMSS L-tree public key length mismatch")
        }
        var layer = publicKey
        var level = 0
        while layer.count > 1 {
            var next: [SuperNeoR1CSLinearCombination] = []
            for index in stride(from: 0, to: layer.count - 1, by: 2) {
                next.append(
                    constrainBinaryHash(
                        layer[index],
                        other: layer[index + 1],
                        parameters: parameters,
                        context: "wots-ltree-\(level)-\(index / 2)",
                        builder: &builder
                    )
                )
            }
            if layer.count % 2 == 1 {
                next.append(layer[layer.count - 1])
            }
            layer = next
            level += 1
        }
        return layer[0]
    }

    private static func constrainBinaryHash(
        _ stateInput: SuperNeoR1CSLinearCombination,
        other: SuperNeoR1CSLinearCombination,
        parameters: SuperNeoXMSSWOTSPlusParameters,
        context: String,
        builder: inout SuperNeoR1CSBuilder
    ) -> SuperNeoR1CSLinearCombination {
        var state = stateInput
        for round in 0..<parameters.hashRoundCount {
            let roundOther = round == 0
                ? other
                : SuperNeoR1CSLinearCombination.constant(
                    SuperNeoXMSSWOTSPlusReference.binaryRoundOtherConstant(
                        parameters: parameters,
                        context: context,
                        round: round
                    ) ? .one : .zero,
                    one: builder.one
                )
            let product = builder.addPrivateWitness()
            builder.enforce(state, times: roundOther, equals: .variable(product))
            state = state
                .adding(roundOther)
                .subtracting(.variable(product, coefficient: GoldilocksField(2)))
            if SuperNeoXMSSWOTSPlusReference.binaryRoundConstant(
                parameters: parameters,
                context: context,
                round: round
            ) {
                state = SuperNeoR1CSLinearCombination.constant(.one, one: builder.one).subtracting(state)
            }
        }
        return state
    }
}

private func fieldFromDigest(_ digest: Digest256) -> GoldilocksField {
    var value = UInt64(0)
    for (offset, byte) in digest.bytes.prefix(8).enumerated() {
        value |= UInt64(byte) << UInt64(offset * 8)
    }
    return GoldilocksField(value)
}

private func addressBitField(leafIndex: Int, treeHeight: Int, selector: Int) -> GoldilocksField {
    ((leafIndex >> (selector % treeHeight)) & 1) == 1 ? .one : .zero
}

private func xmssEncodeString(_ value: String) -> [UInt8] {
    let bytes = Array(value.utf8)
    return xmssEncodeCount(bytes.count) + bytes
}

private func xmssEncodeCount(_ value: Int) -> [UInt8] {
    withUnsafeBytes(of: UInt64(value).littleEndian, Array.init)
}

private func xmssEncodeUInt16(_ value: Int) -> [UInt8] {
    precondition(value >= 0 && value <= Int(UInt16.max), "XMSS UInt16 encoding out of range")
    return withUnsafeBytes(of: UInt16(value).littleEndian, Array.init)
}
