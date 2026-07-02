// swift-tools-version: 6.0
import PackageDescription

#if TUIST
import struct ProjectDescription.PackageSettings
let packageSettings = PackageSettings(
    productTypes: [
        "ComposableArchitecture": .framework,
        "ZIPFoundation": .framework,
        "UnrarKit": .framework
    ]
)
#endif

let package = Package(
    name: "ManaDeps",
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.15.0"),
        .package(url: "https://github.com/weichsel/ZIPFoundation", from: "0.9.19"),
        .package(url: "https://github.com/ZHK1024/UnrarKit-Swift-Package", from: "2.10.1"),
        .package(url: "https://github.com/googleads/swift-package-manager-google-mobile-ads.git", from: "13.6.0"),
        .package(url: "https://github.com/googleads/swift-package-manager-google-user-messaging-platform.git", from: "3.1.0")
    ]
)
