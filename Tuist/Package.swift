// swift-tools-version: 6.0
import PackageDescription

#if TUIST
import struct ProjectDescription.PackageSettings
let packageSettings = PackageSettings(
    productTypes: [
        "ComposableArchitecture": .framework,
        "ZIPFoundation": .framework,
        "UnrarKit": .framework,
        "SwiftSoup": .framework
    ],
    // Several external packages declare deployment targets (iOS 12/13,
    // macOS 10.15) below the floor the current Xcode toolchain accepts
    // (iOS 15, macOS 12). Raise the floor for all generated dependency
    // projects. We use iOS 16 rather than 15 because TCA's dependencies need
    // iOS 16 APIs; 16 is also the ceiling for swift-perception, whose
    // `Perception.Bindable` backport is marked `obsoleted: 17` and fails to
    // compile at a 17 deployment target. ComposableArchitecture itself needs
    // iOS 17 (its UIKit NavigationStackController) and is bumped to 17
    // separately in Scripts/setup.sh after generation.
    baseSettings: .settings(base: [
        "IPHONEOS_DEPLOYMENT_TARGET": "16.0",
        "MACOSX_DEPLOYMENT_TARGET": "12.0"
    ])
)
#endif

let package = Package(
    name: "ManaDeps",
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.26.2"),
        // Point-Free split `IssueReporting` out of `xctest-dynamic-overlay` into
        // the standalone `swift-issue-reporting` package. Older transitive pins
        // (swift-dependencies/navigation/sharing) still referenced the old repo
        // URL, so SPM pulled BOTH packages and Tuist generated two targets that
        // each produce `IssueReporting.framework` ("Multiple commands produce…").
        // Pinning these ecosystem packages to versions that use the new URL
        // collapses the graph onto a single IssueReporting.
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.17.1"),
        .package(url: "https://github.com/pointfreeco/swift-navigation", from: "2.11.2"),
        .package(url: "https://github.com/pointfreeco/swift-sharing", from: "2.10.1"),
        // These four also still pointed at the old xctest-dynamic-overlay URL in
        // their previously-resolved versions; their latest releases moved to
        // swift-issue-reporting. Pinning them here drops the old package entirely.
        .package(url: "https://github.com/pointfreeco/combine-schedulers", from: "1.2.2"),
        .package(url: "https://github.com/pointfreeco/swift-clocks", from: "1.1.1"),
        .package(url: "https://github.com/pointfreeco/swift-custom-dump", from: "1.7.3"),
        .package(url: "https://github.com/pointfreeco/swift-perception", from: "2.0.12"),
        .package(url: "https://github.com/scinfu/SwiftSoup", from: "2.7.0"),
        .package(url: "https://github.com/weichsel/ZIPFoundation", from: "0.9.19"),
        .package(url: "https://github.com/ZHK1024/UnrarKit-Swift-Package", from: "2.10.1"),
        .package(url: "https://github.com/googleads/swift-package-manager-google-mobile-ads.git", from: "13.6.0"),
        .package(url: "https://github.com/googleads/swift-package-manager-google-user-messaging-platform.git", from: "3.1.0")
    ]
)
