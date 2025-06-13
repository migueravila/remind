// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "remind",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "remind", targets: ["remind"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.0")
    ],
    targets: [
        .executableTarget(
            name: "remind",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        )
    ]
)

