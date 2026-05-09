import ProjectDescription
import ProjectDescriptionHelpers

let project = Module(
    name: "BookmarksFeature",
    kind: .feature,
    dependencies: [.project(target: "Domain", path: "../../Domain")],
    externalDependencies: ["ComposableArchitecture"],
    hasResources: true,
    hasTests: true
).project()
