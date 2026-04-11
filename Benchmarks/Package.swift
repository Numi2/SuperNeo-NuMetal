// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "SuperNeoNuMetalBenchmarks",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(path: ".."),
        .package(url: "https://github.com/ordo-one/package-benchmark", from: "1.31.0", traits: [])
    ],
    targets: [
        .executableTarget(
            name: "SuperNeoBenchmarks",
            dependencies: [
                .product(name: "SuperNeo_NuMetal", package: "SuperNeo-NuMetal"),
                .product(name: "Benchmark", package: "package-benchmark")
            ],
            path: "SuperNeoBenchmarks",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ],
            plugins: [
                .plugin(name: "BenchmarkPlugin", package: "package-benchmark")
            ]
        )
    ]
)
