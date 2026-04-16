// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "SuperNeoNuMetal",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "SuperNeo_NuMetal", targets: ["SuperNeo_NuMetal"]),
        .executable(name: "superneo", targets: ["SuperNeoCLI"]),
        .executable(name: "superneo-formal-vectors", targets: ["SuperNeoFormalVectors"]),
        .executable(name: "superneo-numiseal-vectors", targets: ["SuperNeoNumiSealVectors"]),
        .executable(name: "superneo-ct-observe", targets: ["SuperNeoConstantTimeObservation"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "SuperNeo_NuMetal",
            path: "SuperNeo-NuMetal",
            exclude: [
                "NumiSeal-v10-design.md",
                "SuperNeo_NuMetal.docc"
            ],
            resources: [
                .process("MetalBackend/SuperNeoKernels.metal")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ],
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        ),
        .executableTarget(
            name: "SuperNeoCLI",
            dependencies: ["SuperNeo_NuMetal"],
            path: "SuperNeoCLI",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .executableTarget(
            name: "SuperNeoFormalVectors",
            dependencies: ["SuperNeo_NuMetal"],
            path: "Tools/FormalVectorCLI",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .executableTarget(
            name: "SuperNeoNumiSealVectors",
            dependencies: ["SuperNeo_NuMetal"],
            path: "Tools/NumiSealVectorCLI",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .executableTarget(
            name: "SuperNeoConstantTimeObservation",
            dependencies: ["SuperNeo_NuMetal"],
            path: "Tools/ConstantTimeObservationCLI",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .testTarget(
            name: "SuperNeo_NuMetalTests",
            dependencies: ["SuperNeo_NuMetal"],
            path: "SuperNeo-NuMetalTests",
            exclude: [
                "README.md"
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
