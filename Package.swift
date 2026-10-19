// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Altdock",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "Altdock", targets: ["Altdock"])],
    targets: [
        .target(name: "AltdockCore"),
        .executableTarget(name: "Altdock", dependencies: ["AltdockCore"]),
        .testTarget(name: "AltdockCoreTests", dependencies: ["AltdockCore"]),
        .testTarget(name: "AltdockTests", dependencies: ["Altdock", "AltdockCore"])
    ]
)
