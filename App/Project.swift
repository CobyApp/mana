import ProjectDescription

let project = Project(
    name: "App",
    targets: [
        .target(
            name: "Mana",
            destinations: .iOS,
            product: .app,
            bundleId: "com.example.mana",
            deploymentTargets: .iOS("26.0"),
            infoPlist: .file(path: "Resources/Info.plist"),
            sources: ["Sources/**"],
            resources: [
                .glob(pattern: "Resources/**", excluding: ["Resources/Info.plist"])
            ],
            dependencies: [
                .project(target: "AppFeature", path: "../Features/AppFeature"),
                .project(target: "LibraryFeature", path: "../Features/LibraryFeature"),
                .project(target: "ReaderFeature", path: "../Features/ReaderFeature"),
                .project(target: "ArchiveKit", path: "../Data/ArchiveKit"),
                .project(target: "PersistenceKit", path: "../Data/PersistenceKit"),
                .project(target: "ImageCacheKit", path: "../Data/ImageCacheKit"),
                .project(target: "Domain", path: "../Domain"),
                .external(name: "ComposableArchitecture")
            ],
            settings: .settings(base: [
                "TARGETED_DEVICE_FAMILY": "1,2",
                "SUPPORTS_MACCATALYST": "NO"
            ])
        )
    ]
)
