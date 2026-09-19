// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Pasteback",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Pasteback", targets: ["Pasteback"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.7.0"),
    ],
    targets: [
        .target(
            name: "PastebackCore"
        ),
        .executableTarget(
            name: "Pasteback",
            dependencies: ["PastebackCore", .product(name: "Sparkle", package: "Sparkle")]
        ),
        .executableTarget(
            name: "pasteback-cli",
            dependencies: ["PastebackCore"]
        ),
        .testTarget(
            name: "PastebackCoreTests",
            dependencies: ["PastebackCore"]
        ),
    ]
)
