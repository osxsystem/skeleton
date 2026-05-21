// swift-tools-version: 5.10
// SkylogKit — pure-Swift port of the Skylog engine.
// Has NO dependency on Kotlin/Native or SkylogCore. Distributable as source (this
// SPM package). Mirrors the NumberInputKit distribution shape.
import PackageDescription

let package = Package(
    name: "SkylogKit",
    platforms: [.iOS(.v16), .macOS(.v12)],
    products: [
        .library(name: "SkylogKit", targets: ["SkylogKit"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "SkylogKit",
            path: "Sources/SkylogKit"
        ),
        .testTarget(
            name: "SkylogKitTests",
            dependencies: ["SkylogKit"],
            path: "Tests/SkylogKitTests"
        )
    ]
)
