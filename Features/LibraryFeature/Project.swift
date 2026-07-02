import ProjectDescription
import ProjectDescriptionHelpers

let project = Module(
    name: "LibraryFeature",
    kind: .feature,
    dependencies: [
        .project(target: "Domain", path: "../../Domain"),
        .project(target: "DesignSystem", path: "../../DesignSystem"),
        .project(target: "AdKit", path: "../../Data/AdKit")
    ],
    externalDependencies: ["ComposableArchitecture"],
    hasResources: true,
    hasTests: true
).project()
