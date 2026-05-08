import ProjectDescription
import ProjectDescriptionHelpers

let project = Module(
    name: "ThumbnailKit",
    kind: .data,
    dependencies: [.project(target: "Domain", path: "../../Domain")],
    hasTests: true
).project()
