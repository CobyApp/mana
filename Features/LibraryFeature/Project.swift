import ProjectDescription
import ProjectDescriptionHelpers

let project = Module(
    name: "LibraryFeature",
    kind: .feature,
    dependencies: [
        .project(target: "Domain", path: "../../Domain"),
        .project(target: "DesignSystem", path: "../../DesignSystem")
    ],
    externalDependencies: ["ComposableArchitecture"],
    hasResources: true,
    hasTests: true
).project()
