import ProjectDescription
import ProjectDescriptionHelpers

let project = Module(
    name: "AdKit",
    kind: .data,
    externalDependencies: ["GoogleMobileAds"]
).project()
