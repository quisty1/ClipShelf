// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ClipShelf",
    platforms: [.macOS("15.4")],
    products: [.executable(name: "ClipShelf", targets: ["ClipShelf"])],
    targets: [
        .target(name: "ClipShelfCore"),
        .executableTarget(name: "ClipShelf", dependencies: ["ClipShelfCore"],
                          swiftSettings: [.defaultIsolation(MainActor.self)]),
        .executableTarget(name: "ClipShelfChecks", dependencies: ["ClipShelfCore"], path: "Tests/ClipShelfCoreTests")
    ]
)
