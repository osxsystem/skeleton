// swift-tools-version: 5.10
// NumberInputKit — pure-Swift port of the Number Input component.
// Has NO dependency on Kotlin/Native or SkeletonKit. Distributable as source (this
// SPM package) or as a binary XCFramework (see scripts/build-numberinput-xcframework.sh).
import PackageDescription

let package = Package(
    name: "NumberInputKit",
    // macOS is declared so `swift test` can build and run the platform-free logic layer on the
    // host. Everything that touches UIKit is behind `#if canImport(UIKit)`.
    platforms: [.iOS(.v15), .macOS(.v12)],
    products: [
        .library(name: "NumberInputKit", targets: ["NumberInputKit"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "NumberInputKit",
            path: "Sources/NumberInputKit"
        ),
        .testTarget(
            name: "NumberInputKitTests",
            dependencies: ["NumberInputKit"],
            path: "Tests/NumberInputKitTests"
        )
    ]
)
