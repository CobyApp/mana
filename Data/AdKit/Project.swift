import ProjectDescription
import ProjectDescriptionHelpers

let project = Module(
    name: "AdKit",
    kind: .data,
    // Product/library name is "GoogleUserMessagingPlatform"; the importable module
    // it vends is "UserMessagingPlatform".
    externalDependencies: ["GoogleMobileAds", "GoogleUserMessagingPlatform"]
).project()
