// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "remind",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "remind", targets: ["remind"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.0"),
        .package(url: "https://github.com/jpsim/Yams", from: "5.0.0")
    ],
    targets: [
        .target(
            name: "core",
            dependencies: [
                .product(name: "Yams", package: "Yams")
            ]
        ),
        .executableTarget(
            name: "remind",
            dependencies: [
                "core",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        )
    ]
)

