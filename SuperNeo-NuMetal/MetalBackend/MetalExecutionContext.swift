import Foundation
import Metal

public struct MetalDispatchCommand {
    public let pipelineName: String
    public let buffers: [MTLBuffer]
    public let elementCount: Int
    public let threadsPerThreadgroup: Int?

    public init(
        pipelineName: String,
        buffers: [MTLBuffer],
        elementCount: Int,
        threadsPerThreadgroup: Int? = nil
    ) {
        self.pipelineName = pipelineName
        self.buffers = buffers
        self.elementCount = elementCount
        self.threadsPerThreadgroup = threadsPerThreadgroup
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
    @_spi(Benchmarking) public private(set) var lastCommandBufferGPUTimeSeconds: Double?
    private let pipelineStore: MetalPipelineStore
    private var pipelineCache: [String: MTLComputePipelineState] = [:]
    private let lock = NSLock()

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

    public func writeCapturedPipelineScript(to url: URL) throws {
        try pipelineStore.writeCapturedPipelineScript(to: url)
    }

    public func writeCapturedPipelineArchive(to url: URL) throws {
        try pipelineStore.writeCapturedPipelineArchive(to: url)
    }

    public func makeBuffer<T>(_ values: [T]) throws -> MTLBuffer {
        let length = MemoryLayout<T>.stride * values.count
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
        guard let buffer = device.makeBuffer(length: MemoryLayout<T>.stride * count) else {
            throw SuperNeoError.metalFailure("failed to allocate Metal output buffer")
        }
        return buffer
    }

    public func dispatch1D(
        pipelineName: String,
        buffers: [MTLBuffer],
        elementCount: Int
    ) throws {
        try dispatch1DSequence([
            MetalDispatchCommand(pipelineName: pipelineName, buffers: buffers, elementCount: elementCount)
        ])
    }

    public func dispatch1DSequence(_ commands: [MetalDispatchCommand]) throws {
        let commands = commands.filter { $0.elementCount > 0 }
        guard !commands.isEmpty else { return }
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
            guard var count = UInt32(exactly: command.elementCount) else {
                throw SuperNeoError.metalFailure("\(command.pipelineName) element count exceeds UInt32")
            }
            encoder.setBytes(&count, length: MemoryLayout<UInt32>.stride, index: command.buffers.count)
            let requestedWidth = command.threadsPerThreadgroup ?? 256
            let width = min(pipeline.maxTotalThreadsPerThreadgroup, max(1, requestedWidth))
            let groups = MTLSize(width: (command.elementCount + width - 1) / width, height: 1, depth: 1)
            let threads = MTLSize(width: width, height: 1, depth: 1)
            encoder.dispatchThreadgroups(groups, threadsPerThreadgroup: threads)
            if commandIndex < commands.index(before: commands.endIndex) {
                encoder.memoryBarrier(scope: .buffers)
            }
        }

        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        if commandBuffer.gpuEndTime >= commandBuffer.gpuStartTime, commandBuffer.gpuEndTime > 0 {
            lastCommandBufferGPUTimeSeconds = commandBuffer.gpuEndTime - commandBuffer.gpuStartTime
        } else {
            lastCommandBufferGPUTimeSeconds = nil
        }
        if let error = commandBuffer.error {
            throw SuperNeoError.metalFailure(error.localizedDescription)
        }
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
