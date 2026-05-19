// swift-tools-version: 5.10
// PREREQUISITE: Build the XCFramework before resolving this package:
//   ./gradlew :shared-components:assembleSkeletonKitReleaseXCFramework
// The XCFramework is referenced via a relative path from this Package.swift location.
import PackageDescription

let package = Package(
    name: "NumberInput",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "NumberInput", targets: ["NumberInput"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "NumberInput",
            dependencies: ["SkeletonKit"]
        ),
        .binaryTarget(
            name: "SkeletonKit",
            path: "../../shared-components/build/XCFrameworks/release/SkeletonKit.xcframework"
        ),
        .testTarget(
            name: "NumberInputTests",
            dependencies: ["NumberInput", "SkeletonKit"]
        )
    ]
)
