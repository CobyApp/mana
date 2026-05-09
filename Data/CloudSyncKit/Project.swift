import ProjectDescription
import ProjectDescriptionHelpers

let project = Module(
    name: "CloudSyncKit",
    kind: .data,
    dependencies: [.project(target: "Domain", path: "../../Domain")],
    externalDependencies: ["ComposableArchitecture"],
    hasTests: true
).project()
