import ProjectDescription
import ProjectDescriptionHelpers

let project = Module(
    name: "ReaderFeature",
    kind: .feature,
    dependencies: [
        .project(target: "Domain", path: "../../Domain"),
        .project(target: "ImageCacheKit", path: "../../Data/ImageCacheKit"),
        .project(target: "DesignSystem", path: "../../DesignSystem"),
        .project(target: "SharedUI", path: "../../SharedUI"),
        .project(target: "LibraryFeature", path: "../LibraryFeature"),
        .project(target: "SettingsFeature", path: "../SettingsFeature")
    ],
    externalDependencies: ["ComposableArchitecture"],
    hasResources: true,
    hasTests: true
).project()
