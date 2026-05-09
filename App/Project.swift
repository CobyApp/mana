import ProjectDescription

private let appBaseSettings: [String: SettingValue] = [
    "TARGETED_DEVICE_FAMILY": "1,2",
    "SUPPORTS_MACCATALYST": "NO",
    "CODE_SIGN_STYLE": "Automatic",
    "DEVELOPMENT_TEAM": "3Y8YH8GWMM",
    "MARKETING_VERSION": "1.0.0",
    "CURRENT_PROJECT_VERSION": "1",
    "SWIFT_VERSION": "6.0"
]

let project = Project(
    name: "App",
    organizationName: "com.coby",
    options: .options(
        defaultKnownRegions: ["en", "ja", "ko", "Base"],
        developmentRegion: "en"
    ),
    targets: [
        .target(
            name: "Mana",
            destinations: .iOS,
            product: .app,
            bundleId: "com.coby.mana",
            deploymentTargets: .iOS("26.0"),
            infoPlist: .file(path: "Resources/Info.plist"),
            sources: ["Sources/**"],
            resources: [
                .glob(pattern: "Resources/**", excluding: ["Resources/Info.plist", "Resources/Mana.entitlements"])
            ],
            entitlements: .file(path: "Resources/Mana.entitlements"),
            dependencies: [
                .project(target: "AppFeature", path: "../Features/AppFeature"),
                .project(target: "LibraryFeature", path: "../Features/LibraryFeature"),
                .project(target: "ReaderFeature", path: "../Features/ReaderFeature"),
                .project(target: "SettingsFeature", path: "../Features/SettingsFeature"),
                .project(target: "ArchiveKit", path: "../Data/ArchiveKit"),
                .project(target: "PersistenceKit", path: "../Data/PersistenceKit"),
                .project(target: "ImageCacheKit", path: "../Data/ImageCacheKit"),
                .project(target: "ThumbnailKit", path: "../Data/ThumbnailKit"),
                .project(target: "CloudSyncKit", path: "../Data/CloudSyncKit"),
                .project(target: "Domain", path: "../Domain"),
                .external(name: "ComposableArchitecture")
            ],
            settings: .settings(base: appBaseSettings)
        ),
        .target(
            name: "ManaTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "com.coby.mana.tests",
            deploymentTargets: .iOS("26.0"),
            sources: ["Tests/**"],
            resources: ["Tests/Resources/**"],
            dependencies: [
                .target(name: "Mana"),
                .project(target: "Domain", path: "../Domain"),
                .project(target: "ArchiveKit", path: "../Data/ArchiveKit"),
                .project(target: "PersistenceKit", path: "../Data/PersistenceKit"),
                .project(target: "ImageCacheKit", path: "../Data/ImageCacheKit"),
                .project(target: "ThumbnailKit", path: "../Data/ThumbnailKit"),
                .project(target: "CloudSyncKit", path: "../Data/CloudSyncKit"),
                .project(target: "LibraryFeature", path: "../Features/LibraryFeature"),
                .project(target: "SettingsFeature", path: "../Features/SettingsFeature")
            ],
            settings: .settings(base: [
                "CODE_SIGN_STYLE": "Automatic",
                "DEVELOPMENT_TEAM": "3Y8YH8GWMM",
                "SWIFT_VERSION": "6.0"
            ])
        )
    ]
)
