// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "OfficeAssassinsClient",
    platforms: [
        .macOS(.v15),   // SPM floor; Xcode target bumps to 26.0
        .iOS(.v18),
        .tvOS(.v18)
    ],
    products: [
        .executable(
            name: "OfficeAssassinsClient",
            targets: ["OfficeAssassinsClient"]
        ),
        .executable(
            name: "SoakRunner",
            targets: ["SoakRunner"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/avias8/spacetimedb-swift.git", from: "0.21.0")
    ],
    targets: [
        .executableTarget(
            name: "OfficeAssassinsClient",
            dependencies: [
                .product(name: "SpacetimeDB", package: "spacetimedb-swift")
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .executableTarget(
            name: "SoakRunner",
            dependencies: [
                .product(name: "SpacetimeDB", package: "spacetimedb-swift")
            ]
        )
    ]
)
