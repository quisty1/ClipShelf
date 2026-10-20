// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ClipShelf",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "ClipShelf", targets: ["ClipShelf"])],
    targets: [
        .target(name: "ClipShelfCore", resources: [.process("Resources")]),
        .executableTarget(name: "ClipShelf", dependencies: ["ClipShelfCore"],
                          swiftSettings: [.defaultIsolation(MainActor.self)]),
        .executableTarget(name: "ClipShelfChecks", dependencies: ["ClipShelfCore"], path: "Tests/ClipShelfCoreTests")
    ]
)
