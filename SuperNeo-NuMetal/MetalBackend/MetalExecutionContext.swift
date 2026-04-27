import Foundation
import Dispatch
import Metal

@_spi(Benchmarking) public struct MetalCommandBufferTiming: Equatable, Sendable {
    public let commandCount: Int
    public let elementCount: Int
    public let encodeWallTimeSeconds: Double
    public let commitWallTimeSeconds: Double
    public let waitWallTimeSeconds: Double
    public let gpuTimeSeconds: Double?

    public init(
        commandCount: Int,
        elementCount: Int,
        encodeWallTimeSeconds: Double,
        commitWallTimeSeconds: Double,
        waitWallTimeSeconds: Double,
        gpuTimeSeconds: Double?
    ) {
        self.commandCount = commandCount
        self.elementCount = elementCount
        self.encodeWallTimeSeconds = encodeWallTimeSeconds
        self.commitWallTimeSeconds = commitWallTimeSeconds
        self.waitWallTimeSeconds = waitWallTimeSeconds
        self.gpuTimeSeconds = gpuTimeSeconds
    }
}

public struct MetalInlineUInt32Buffer {
    public let index: Int
    public let values: [UInt32]

    public init(index: Int, values: [UInt32]) {
        self.index = index
        self.values = values
    }
}

public struct MetalDispatchCommand {
    public let pipelineName: String
    public let buffers: [MTLBuffer]
    public let inlineUInt32Buffers: [MetalInlineUInt32Buffer]
    public let elementCount: Int
    public let threadsPerThreadgroup: Int?
    public let countBufferIndex: Int?
    public let barrierAfter: Bool

    public init(
        pipelineName: String,
        buffers: [MTLBuffer],
        inlineUInt32Buffers: [MetalInlineUInt32Buffer] = [],
        elementCount: Int,
        threadsPerThreadgroup: Int? = nil,
        countBufferIndex: Int? = nil,
        barrierAfter: Bool = true
    ) {
        self.pipelineName = pipelineName
        self.buffers = buffers
        self.inlineUInt32Buffers = inlineUInt32Buffers
        self.elementCount = elementCount
        self.threadsPerThreadgroup = threadsPerThreadgroup
        self.countBufferIndex = countBufferIndex
        self.barrierAfter = barrierAfter
    }
}

struct MetalTemporaryBufferRequest {
    let byteLength: Int
    let role: String

    init(byteLength: Int, role: String) {
        self.byteLength = byteLength
        self.role = role
    }
}

public struct MetalPipelineStoreConfiguration: Equatable, Sendable {
    public static let `default` = MetalPipelineStoreConfiguration()

    public let archiveURL: URL?
    public let fallbackLibraryURLs: [URL]
    public let recordPipelineData: Bool

    public init(
        archiveURL: URL? = nil,
        fallbackLibraryURLs: [URL] = [],
        recordPipelineData: Bool = false
    ) {
        self.archiveURL = archiveURL
        self.fallbackLibraryURLs = fallbackLibraryURLs
        self.recordPipelineData = recordPipelineData
    }
}

public final class MetalExecutionContext: @unchecked Sendable {
    public let device: MTLDevice
    public let commandQueue: MTLCommandQueue
    public let features: SuperNeoMetalFeatures
    @_spi(Benchmarking) public var lastCommandBufferGPUTimeSeconds: Double? {
        lock.lock()
        defer { lock.unlock() }
        return lastCommandBufferTimingStorage?.gpuTimeSeconds
    }
    @_spi(Benchmarking) public var lastCommandBufferTiming: MetalCommandBufferTiming? {
        lock.lock()
        defer { lock.unlock() }
        return lastCommandBufferTimingStorage
    }
    private let pipelineStore: MetalPipelineStore
    private var pipelineCache: [String: MTLComputePipelineState] = [:]
    private var temporaryBufferPool: [Int: [MTLBuffer]] = [:]
    private var lastCommandBufferTimingStorage: MetalCommandBufferTiming?
    private let lock = NSLock()
    private static let temporaryBufferBucketSize = 4_096
    private static let maximumTemporaryBuffersPerBucket = 4
    private static let maximumPooledTemporaryBufferLength = 64 * 1_024 * 1_024

    public init(
        device: MTLDevice? = MTLCreateSystemDefaultDevice(),
        pipelineStoreConfiguration: MetalPipelineStoreConfiguration = .default
    ) throws {
        guard let device else { throw SuperNeoError.metalUnavailable }
        guard let queue = device.makeCommandQueue() else {
            throw SuperNeoError.metalFailure("failed to create command queue")
        }
        self.device = device
        self.commandQueue = queue
        self.features = SuperNeoMetalFeatures(device: device)
        do {
            let defaultLibrary = try Self.makeDefaultLibrary(device: device)
            self.pipelineStore = try MetalPipelineStore(
                device: device,
                defaultLibrary: defaultLibrary,
                configuration: pipelineStoreConfiguration
            )
        } catch {
            throw SuperNeoError.metalFailure("failed to load default Metal library: \(error)")
        }
    }

    private static func makeDefaultLibrary(device: MTLDevice) throws -> MTLLibrary {
#if SWIFT_PACKAGE
        if let url = Bundle.module.url(forResource: "SuperNeoKernels", withExtension: "metal") {
            let source = try String(contentsOf: url, encoding: .utf8)
            return try device.makeLibrary(source: source, options: nil)
        }
        if let url = Bundle.module.urls(forResourcesWithExtension: "metal", subdirectory: nil)?.first {
            let source = try String(contentsOf: url, encoding: .utf8)
            return try device.makeLibrary(source: source, options: nil)
        }
#endif
        let bundle = Bundle(for: BundleToken.self)
        return try device.makeDefaultLibrary(bundle: bundle)
    }

    public func pipeline(named name: String) throws -> MTLComputePipelineState {
        lock.lock()
        if let cached = pipelineCache[name] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let pipeline = try pipelineStore.makeComputePipeline(named: name)

        lock.lock()
        if let cached = pipelineCache[name] {
            lock.unlock()
            return cached
        }
        pipelineCache[name] = pipeline
        lock.unlock()
        return pipeline
    }

    public func prewarmPipelines(named names: [String]) -> [String: Error] {
        guard !names.isEmpty else { return [:] }
        var failures: [String: Error] = [:]
        let failureLock = NSLock()
        DispatchQueue.concurrentPerform(iterations: names.count) { index in
            let name = names[index]
            do {
                _ = try pipeline(named: name)
            } catch {
                failureLock.lock()
                failures[name] = error
                failureLock.unlock()
            }
        }
        return failures
    }

    @_spi(Benchmarking) public func prewarmSuperNeoPipelines() throws {
        let failures = prewarmPipelines(named: [
            "goldilocks_add_kernel",
            "goldilocks_sub_kernel",
            "goldilocks_mul_kernel",
            "ring_add_kernel",
            "ring_scalar_mul_kernel",
            "ring_mul_kernel",
            "numiseal_apply_mask_kernel",
            "numiseal_dense_fold_kernel",
            "numiseal_eq_weight_kernel",
            "numiseal_sumcheck_accumulate_kernel",
            "shake256_digest384_preframed_kernel",
            "transformed_matvec_kernel",
            "transformed_matvec_sparse_aware_kernel",
            "sparse_transformed_matvec_kernel",
            "transformed_eval_dot_kernel",
            "sparse_transformed_eval_fused_kernel",
            "sparse_transformed_eval_block_partial_kernel",
            "sparse_transformed_eval_block_reduce_kernel",
            "sparse_transformed_eval_row_partial_kernel",
            "sparse_transformed_eval_row_reduce_kernel",
            "ajtai_matvec_ring_batch_coeff_kernel",
            "ajtai_matvec_ring_batch_coeff_small_message_kernel",
            "ajtai_matvec_tile_kernel",
            "ajtai_matvec_reduce_kernel",
            "fri_bit_reverse_permute_kernel",
            "fri_ntt_stage_kernel"
        ])
        guard failures.isEmpty else {
            let message = failures
                .map { "\($0.key): \($0.value.localizedDescription)" }
                .sorted()
                .joined(separator: "; ")
            throw SuperNeoError.metalFailure("failed to prewarm Metal pipelines: \(message)")
        }
    }

    public func writeCapturedPipelineScript(to url: URL) throws {
        try pipelineStore.writeCapturedPipelineScript(to: url)
    }

    public func writeCapturedPipelineArchive(to url: URL) throws {
        try pipelineStore.writeCapturedPipelineArchive(to: url)
    }

    public func makeBuffer<T>(_ values: [T]) throws -> MTLBuffer {
        let length = try checkedBufferLength(
            count: values.count,
            stride: MemoryLayout<T>.stride,
            role: "Metal input buffer"
        )
        guard length > 0 else {
            return try makeEmptyBuffer(count: 1, as: T.self)
        }
        return try values.withUnsafeBytes { bytes in
            guard let baseAddress = bytes.baseAddress,
                  let buffer = device.makeBuffer(bytes: baseAddress, length: length) else {
                throw SuperNeoError.metalFailure("failed to allocate Metal buffer")
            }
            return buffer
        }
    }

    public func makeEmptyBuffer<T>(count: Int, as _: T.Type) throws -> MTLBuffer {
        let length = try checkedBufferLength(
            count: count,
            stride: MemoryLayout<T>.stride,
            role: "Metal output buffer"
        )
        let allocatedLength = max(length, MemoryLayout<T>.stride)
        guard let buffer = device.makeBuffer(length: allocatedLength) else {
            throw SuperNeoError.metalFailure("failed to allocate Metal output buffer")
        }
        return buffer
    }

    func temporaryBufferByteLength<T>(count: Int, as _: T.Type, role: String) throws -> Int {
        try checkedBufferLength(count: count, stride: MemoryLayout<T>.stride, role: role)
    }

    func copyValues<T>(_ values: [T], to buffer: MTLBuffer, role: String) throws {
        let length = try checkedBufferLength(count: values.count, stride: MemoryLayout<T>.stride, role: role)
        guard length <= buffer.length else {
            throw SuperNeoError.metalFailure("\(role) does not fit in temporary Metal buffer")
        }
        guard length > 0 else { return }
        try values.withUnsafeBytes { bytes in
            guard let baseAddress = bytes.baseAddress else {
                throw SuperNeoError.invalidParameter("\(role) has no source bytes")
            }
            memcpy(buffer.contents(), baseAddress, length)
            buffer.didModifyRange(0..<length)
        }
    }

    func withTemporaryBuffers<Result>(
        _ requests: [MetalTemporaryBufferRequest],
        _ body: ([MTLBuffer]) throws -> Result
    ) throws -> Result {
        var leasedCapacities: [Int] = []
        var leasedBuffers: [MTLBuffer] = []
        leasedCapacities.reserveCapacity(requests.count)
        leasedBuffers.reserveCapacity(requests.count)
        defer {
            returnTemporaryBuffers(capacities: leasedCapacities, buffers: leasedBuffers)
        }
        for request in requests {
            guard request.byteLength >= 0 else {
                throw SuperNeoError.invalidParameter("\(request.role) has invalid byte length")
            }
            let capacity = Self.temporaryBufferCapacity(for: request.byteLength)
            let buffer = try leaseTemporaryBuffer(capacity: capacity, role: request.role)
            leasedCapacities.append(capacity)
            leasedBuffers.append(buffer)
        }
        return try body(leasedBuffers)
    }

    public func dispatch1D(
        pipelineName: String,
        buffers: [MTLBuffer],
        inlineUInt32Buffers: [MetalInlineUInt32Buffer] = [],
        countBufferIndex: Int? = nil,
        elementCount: Int
    ) throws {
        try dispatch1DSequence([
            MetalDispatchCommand(
                pipelineName: pipelineName,
                buffers: buffers,
                inlineUInt32Buffers: inlineUInt32Buffers,
                elementCount: elementCount,
                countBufferIndex: countBufferIndex
            )
        ])
    }

    public func dispatch1DSequence(_ commands: [MetalDispatchCommand]) throws {
        setLastCommandBufferTiming(nil)
        let commands = commands.filter { $0.elementCount > 0 }
        guard !commands.isEmpty else { return }
        let encodeStart = Self.nowNanoseconds()
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw SuperNeoError.metalFailure("failed to create command encoder")
        }

        for commandIndex in commands.indices {
            let command = commands[commandIndex]
            let pipeline = try pipeline(named: command.pipelineName)
            encoder.setComputePipelineState(pipeline)
            for (index, buffer) in command.buffers.enumerated() {
                encoder.setBuffer(buffer, offset: 0, index: index)
            }
            for inlineBuffer in command.inlineUInt32Buffers {
                try setInlineUInt32Buffer(inlineBuffer, encoder: encoder, pipelineName: command.pipelineName)
            }
            guard var count = UInt32(exactly: command.elementCount) else {
                throw SuperNeoError.metalFailure("\(command.pipelineName) element count exceeds UInt32")
            }
            encoder.setBytes(
                &count,
                length: MemoryLayout<UInt32>.stride,
                index: command.countBufferIndex ?? command.buffers.count
            )
            let requestedWidth = command.threadsPerThreadgroup ?? 256
            let width = min(pipeline.maxTotalThreadsPerThreadgroup, max(1, requestedWidth))
            let threads = MTLSize(width: width, height: 1, depth: 1)
            if features.supportsNonuniformThreadgroups {
                encoder.dispatchThreads(
                    MTLSize(width: command.elementCount, height: 1, depth: 1),
                    threadsPerThreadgroup: threads
                )
            } else {
                let groups = MTLSize(width: (command.elementCount + width - 1) / width, height: 1, depth: 1)
                encoder.dispatchThreadgroups(groups, threadsPerThreadgroup: threads)
            }
            if command.barrierAfter, commandIndex < commands.index(before: commands.endIndex) {
                encoder.memoryBarrier(scope: .buffers)
            }
        }

        encoder.endEncoding()
        let encodeEnd = Self.nowNanoseconds()
        let commitStart = Self.nowNanoseconds()
        commandBuffer.commit()
        let commitEnd = Self.nowNanoseconds()
        commandBuffer.waitUntilCompleted()
        let waitEnd = Self.nowNanoseconds()
        let gpuTimeSeconds = commandBuffer.gpuEndTime >= commandBuffer.gpuStartTime && commandBuffer.gpuEndTime > 0
            ? commandBuffer.gpuEndTime - commandBuffer.gpuStartTime
            : nil
        setLastCommandBufferTiming(MetalCommandBufferTiming(
            commandCount: commands.count,
            elementCount: commands.reduce(0) { $0 + $1.elementCount },
            encodeWallTimeSeconds: Self.seconds(from: encodeStart, to: encodeEnd),
            commitWallTimeSeconds: Self.seconds(from: commitStart, to: commitEnd),
            waitWallTimeSeconds: Self.seconds(from: commitEnd, to: waitEnd),
            gpuTimeSeconds: gpuTimeSeconds
        ))
        if let error = commandBuffer.error {
            throw SuperNeoError.metalFailure(error.localizedDescription)
        }
    }

    private func setInlineUInt32Buffer(
        _ inlineBuffer: MetalInlineUInt32Buffer,
        encoder: MTLComputeCommandEncoder,
        pipelineName: String
    ) throws {
        guard !inlineBuffer.values.isEmpty else {
            throw SuperNeoError.invalidParameter("\(pipelineName) inline parameter buffer cannot be empty")
        }
        try inlineBuffer.values.withUnsafeBytes { bytes in
            guard let baseAddress = bytes.baseAddress else {
                throw SuperNeoError.invalidParameter("\(pipelineName) inline parameter buffer is empty")
            }
            encoder.setBytes(baseAddress, length: bytes.count, index: inlineBuffer.index)
        }
    }

    private func checkedBufferLength(count: Int, stride: Int, role: String) throws -> Int {
        guard count >= 0, stride > 0 else {
            throw SuperNeoError.invalidParameter("\(role) has invalid size")
        }
        let (length, overflow) = count.multipliedReportingOverflow(by: stride)
        guard !overflow else {
            throw SuperNeoError.invalidParameter("\(role) byte length overflow")
        }
        return length
    }

    private func setLastCommandBufferTiming(_ value: MetalCommandBufferTiming?) {
        lock.lock()
        lastCommandBufferTimingStorage = value
        lock.unlock()
    }

    private static func nowNanoseconds() -> UInt64 {
        DispatchTime.now().uptimeNanoseconds
    }

    private static func seconds(from start: UInt64, to end: UInt64) -> Double {
        guard end >= start else { return 0 }
        return Double(end - start) / 1_000_000_000
    }

    private static func temporaryBufferCapacity(for byteLength: Int) -> Int {
        let requestedLength = max(byteLength, 1)
        let bucketSize = temporaryBufferBucketSize
        guard requestedLength <= Int.max - (bucketSize - 1) else {
            return requestedLength
        }
        return ((requestedLength + bucketSize - 1) / bucketSize) * bucketSize
    }

    private func leaseTemporaryBuffer(capacity: Int, role: String) throws -> MTLBuffer {
        if capacity <= Self.maximumPooledTemporaryBufferLength {
            lock.lock()
            if var buffers = temporaryBufferPool[capacity], let buffer = buffers.popLast() {
                temporaryBufferPool[capacity] = buffers
                lock.unlock()
                return buffer
            }
            lock.unlock()
        }
        guard let buffer = device.makeBuffer(length: capacity, options: .storageModeShared) else {
            throw SuperNeoError.metalFailure("failed to allocate temporary Metal buffer for \(role)")
        }
        return buffer
    }

    private func returnTemporaryBuffers(capacities: [Int], buffers: [MTLBuffer]) {
        guard !buffers.isEmpty else { return }
        lock.lock()
        for index in buffers.indices {
            let capacity = capacities[index]
            guard capacity <= Self.maximumPooledTemporaryBufferLength else { continue }
            let buffer = buffers[index]
            var bucket = temporaryBufferPool[capacity] ?? []
            if bucket.count < Self.maximumTemporaryBuffersPerBucket {
                bucket.append(buffer)
                temporaryBufferPool[capacity] = bucket
            }
        }
        lock.unlock()
    }
}

private final class MetalPipelineStore: @unchecked Sendable {
    private let device: MTLDevice
    private let defaultLibrary: MTLLibrary
    private let fallbackLibraries: [MTLLibrary]
    private let metal4Runtime: MetalPipelineArchiveRuntime?

    init(
        device: MTLDevice,
        defaultLibrary: MTLLibrary,
        configuration: MetalPipelineStoreConfiguration
    ) throws {
        self.device = device
        self.defaultLibrary = defaultLibrary
        self.fallbackLibraries = try configuration.fallbackLibraryURLs.map { try device.makeLibrary(URL: $0) }
#if compiler(>=6.2) && !targetEnvironment(simulator) && (os(macOS) || os(iOS) || os(tvOS) || os(visionOS))
        if #available(macOS 26.0, iOS 26.0, tvOS 26.0, visionOS 26.0, *) {
            self.metal4Runtime = try Metal4PipelineRuntime(
                device: device,
                archiveURL: configuration.archiveURL,
                recordPipelineData: configuration.recordPipelineData
            )
        } else {
            self.metal4Runtime = nil
        }
#else
        self.metal4Runtime = nil
#endif
    }

    func makeComputePipeline(named name: String) throws -> MTLComputePipelineState {
        let candidateLibraries = fallbackLibraries + [defaultLibrary]
        if let runtime = metal4Runtime {
            for library in candidateLibraries where library.makeFunction(name: name) != nil {
                if let pipeline = try runtime.makeArchivedPipeline(named: name, library: library) {
                    return pipeline
                }
            }
        }

        for library in candidateLibraries {
            guard library.makeFunction(name: name) != nil else { continue }
            if let runtime = metal4Runtime {
                return try runtime.makeCompiledPipeline(named: name, library: library)
            }
            guard let function = library.makeFunction(name: name) else { continue }
            return try device.makeComputePipelineState(function: function)
        }

        throw SuperNeoError.metalFailure("missing Metal function \(name)")
    }

    func writeCapturedPipelineScript(to url: URL) throws {
        if let runtime = metal4Runtime {
            try runtime.writeCapturedPipelineScript(to: url)
            return
        }
        throw SuperNeoError.metalFailure("Metal 4 pipeline capture is unavailable on this platform or OS version")
    }

    func writeCapturedPipelineArchive(to url: URL) throws {
        if let runtime = metal4Runtime {
            try runtime.writeCapturedPipelineArchive(to: url)
            return
        }
        throw SuperNeoError.metalFailure("Metal 4 pipeline capture is unavailable on this platform or OS version")
    }
}

private protocol MetalPipelineArchiveRuntime: AnyObject {
    func makeArchivedPipeline(named name: String, library: MTLLibrary) throws -> MTLComputePipelineState?
    func makeCompiledPipeline(named name: String, library: MTLLibrary) throws -> MTLComputePipelineState
    func writeCapturedPipelineScript(to url: URL) throws
    func writeCapturedPipelineArchive(to url: URL) throws
}

#if compiler(>=6.2) && !targetEnvironment(simulator) && (os(macOS) || os(iOS) || os(tvOS) || os(visionOS))
@available(macOS 26.0, iOS 26.0, tvOS 26.0, visionOS 26.0, *)
private final class Metal4PipelineRuntime: MetalPipelineArchiveRuntime {
    private let archive: (any MTL4Archive)?
    private let compiler: any MTL4Compiler
    private let serializer: (any MTL4PipelineDataSetSerializer)?

    init(device: MTLDevice, archiveURL: URL?, recordPipelineData: Bool) throws {
        if let archiveURL {
            self.archive = try? device.makeArchive(url: archiveURL)
        } else {
            self.archive = nil
        }

        let compilerDescriptor = MTL4CompilerDescriptor()
        if recordPipelineData {
            let serializerDescriptor = MTL4PipelineDataSetSerializerDescriptor()
            serializerDescriptor.configuration = MTL4PipelineDataSetSerializerConfiguration(rawValue: 0b11)
            let serializer = device.makePipelineDataSetSerializer(descriptor: serializerDescriptor)
            compilerDescriptor.pipelineDataSetSerializer = serializer
            self.serializer = serializer
        } else {
            self.serializer = nil
        }
        self.compiler = try device.makeCompiler(descriptor: compilerDescriptor)
    }

    func makeArchivedPipeline(named name: String, library: MTLLibrary) throws -> MTLComputePipelineState? {
        guard let archive else { return nil }
        let descriptor = makeDescriptor(named: name, library: library)
        return try? archive.makeComputePipelineState(descriptor: descriptor)
    }

    func makeCompiledPipeline(named name: String, library: MTLLibrary) throws -> MTLComputePipelineState {
        let descriptor = makeDescriptor(named: name, library: library)
        let taskOptions = MTL4CompilerTaskOptions()
        if let archive {
            taskOptions.lookupArchives = [archive]
        }
        return try compiler.makeComputePipelineState(
            descriptor: descriptor,
            dynamicLinkingDescriptor: nil,
            compilerTaskOptions: taskOptions
        )
    }

    func writeCapturedPipelineScript(to url: URL) throws {
        guard let serializer else {
            throw SuperNeoError.metalFailure("Metal 4 pipeline data recording was not enabled")
        }
        let data = try serializer.serializeAsPipelinesScript()
        try data.write(to: url, options: .atomic)
    }

    func writeCapturedPipelineArchive(to url: URL) throws {
        guard let serializer else {
            throw SuperNeoError.metalFailure("Metal 4 pipeline data recording was not enabled")
        }
        try serializer.serializeAsArchiveAndFlush(url: url)
    }

    private func makeDescriptor(named name: String, library: MTLLibrary) -> MTL4ComputePipelineDescriptor {
        let functionDescriptor = MTL4LibraryFunctionDescriptor()
        functionDescriptor.library = library
        functionDescriptor.name = name

        let descriptor = MTL4ComputePipelineDescriptor()
        descriptor.label = name
        descriptor.computeFunctionDescriptor = functionDescriptor
        return descriptor
    }
}
#endif

public struct SuperNeoMetalFeatures: Equatable, Sendable {
    public let supportsApple9FastPath: Bool
    public let supportsNonuniformThreadgroups: Bool
    public let supportsSIMDScopedReductions: Bool
    public let supports64BitAtomics: Bool

    public init(device: MTLDevice) {
        self.supportsApple9FastPath = device.supportsFamily(.apple9)
        self.supportsNonuniformThreadgroups = device.supportsFamily(.apple4)
        self.supportsSIMDScopedReductions = device.supportsFamily(.apple7)
        self.supports64BitAtomics = device.supportsFamily(.apple9)
    }
}

private final class BundleToken {}

extension MTLBuffer {
    func array<T>(of _: T.Type, count: Int) -> [T] {
        let pointer = contents().bindMemory(to: T.self, capacity: count)
        return Array(UnsafeBufferPointer(start: pointer, count: count))
    }
}
