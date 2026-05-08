// swift-tools-version: 6.0
import PackageDescription

#if TUIST
import struct ProjectDescription.PackageSettings
let packageSettings = PackageSettings(
    productTypes: [
        "ComposableArchitecture": .framework,
        "ZIPFoundation": .framework
    ]
)
#endif

let package = Package(
    name: "ManaDeps",
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.15.0"),
        .package(url: "https://github.com/weichsel/ZIPFoundation", from: "0.9.19")
    ]
)
