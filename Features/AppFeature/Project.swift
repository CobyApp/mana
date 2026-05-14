import ProjectDescription
import ProjectDescriptionHelpers

let project = Module(
    name: "AppFeature",
    kind: .feature,
    dependencies: [
        .project(target: "Domain", path: "../../Domain"),
        .project(target: "IntelligenceKit", path: "../../Data/IntelligenceKit"),
        .project(target: "LibraryFeature", path: "../LibraryFeature"),
        .project(target: "ReaderFeature", path: "../ReaderFeature"),
        .project(target: "SettingsFeature", path: "../SettingsFeature")
    ],
    externalDependencies: ["ComposableArchitecture"]
).project()
