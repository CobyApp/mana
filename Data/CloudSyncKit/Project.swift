import ProjectDescription
import ProjectDescriptionHelpers

let project = Module(
    name: "CloudSyncKit",
    kind: .data,
    dependencies: [.project(target: "Domain", path: "../../Domain")],
    hasTests: true
).project()
