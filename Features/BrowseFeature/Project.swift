import ProjectDescription
import ProjectDescriptionHelpers

let project = Module(
    name: "BrowseFeature",
    kind: .feature,
    dependencies: [
        .project(target: "Domain", path: "../../Domain"),
        .project(target: "DesignSystem", path: "../../DesignSystem"),
        .project(target: "SourceKit", path: "../../Data/SourceKit"),
        .project(target: "ReaderFeature", path: "../ReaderFeature")
    ],
    externalDependencies: ["ComposableArchitecture"],
    hasResources: true,
    hasTests: false
).project()
