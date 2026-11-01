import ProjectDescription
import ProjectDescriptionHelpers

let project = Module(
    name: "SourceKit",
    kind: .data,
    dependencies: [.project(target: "Domain", path: "../../Domain")],
    externalDependencies: ["SwiftSoup"],
    hasTests: false
).project()
