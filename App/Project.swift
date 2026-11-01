import ProjectDescription

private let appBaseSettings: [String: SettingValue] = [
    "TARGETED_DEVICE_FAMILY": "1,2",
    "SUPPORTS_MACCATALYST": "NO",
    "CODE_SIGN_STYLE": "Automatic",
    "DEVELOPMENT_TEAM": "3Y8YH8GWMM",
    "MARKETING_VERSION": "1.0.2",
    "CURRENT_PROJECT_VERSION": "1",
    "SWIFT_VERSION": "6.0"
]

let project = Project(
    name: "App",
    organizationName: "com.coby",
    options: .options(
        defaultKnownRegions: ["ko", "ja", "en", "Base"],
        developmentRegion: "ko"
    ),
    targets: [
        .target(
            name: "Mana",
            destinations: .iOS,
            product: .app,
            bundleId: "com.coby.mana",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .file(path: "Resources/Info.plist"),
            sources: ["Sources/**"],
            resources: [
                .glob(pattern: "Resources/**", excluding: ["Resources/Info.plist"])
            ],
            entitlements: .file(path: "Mana.entitlements"),
            dependencies: [
                .target(name: "ManaWidget"),
                .project(target: "AppFeature", path: "../Features/AppFeature"),
                .project(target: "BrowseFeature", path: "../Features/BrowseFeature"),
                .project(target: "LibraryFeature", path: "../Features/LibraryFeature"),
                .project(target: "ReaderFeature", path: "../Features/ReaderFeature"),
                .project(target: "SettingsFeature", path: "../Features/SettingsFeature"),
                .project(target: "AdKit", path: "../Data/AdKit"),
                .project(target: "SourceKit", path: "../Data/SourceKit"),
                .project(target: "ArchiveKit", path: "../Data/ArchiveKit"),
                .project(target: "PersistenceKit", path: "../Data/PersistenceKit"),
                .project(target: "ImageCacheKit", path: "../Data/ImageCacheKit"),
                .project(target: "ThumbnailKit", path: "../Data/ThumbnailKit"),
                .project(target: "Domain", path: "../Domain"),
                .project(target: "DesignSystem", path: "../DesignSystem"),
                .external(name: "ComposableArchitecture"),
                .external(name: "ZIPFoundation")
            ],
            settings: .settings(base: appBaseSettings)
        ),
        .target(
            name: "ManaWidget",
            destinations: .iOS,
            product: .appExtension,
            bundleId: "com.coby.mana.widget",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .extendingDefault(with: [
                "CFBundleDisplayName": "NOIZ",
                "CFBundleShortVersionString": "$(MARKETING_VERSION)",
                "CFBundleVersion": "$(CURRENT_PROJECT_VERSION)",
                "CFBundleDevelopmentRegion": "ko",
                "CFBundleLocalizations": ["ko", "ja", "en"],
                "NSExtension": [
                    "NSExtensionPointIdentifier": "com.apple.widgetkit-extension"
                ]
            ]),
            sources: ["Widget/Sources/**"],
            resources: ["Widget/Resources/**"],
            entitlements: .file(path: "Widget/ManaWidget.entitlements"),
            dependencies: [
                .sdk(name: "WidgetKit", type: .framework),
                .sdk(name: "SwiftUI", type: .framework)
            ],
            settings: .settings(base: appBaseSettings)
        ),
        .target(
            name: "ManaTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "com.coby.mana.tests",
            deploymentTargets: .iOS("17.0"),
            sources: ["Tests/**"],
            resources: ["Tests/Resources/**"],
            dependencies: [
                .target(name: "Mana"),
                .project(target: "Domain", path: "../Domain"),
                .project(target: "ArchiveKit", path: "../Data/ArchiveKit"),
                .project(target: "PersistenceKit", path: "../Data/PersistenceKit"),
                .project(target: "ImageCacheKit", path: "../Data/ImageCacheKit"),
                .project(target: "ThumbnailKit", path: "../Data/ThumbnailKit"),
                .project(target: "LibraryFeature", path: "../Features/LibraryFeature"),
                .project(target: "SettingsFeature", path: "../Features/SettingsFeature"),
                .project(target: "ReaderFeature", path: "../Features/ReaderFeature"),
            ],
            settings: .settings(base: [
                "CODE_SIGN_STYLE": "Automatic",
                "DEVELOPMENT_TEAM": "3Y8YH8GWMM",
                "SWIFT_VERSION": "6.0"
            ])
        )
    ]
)
