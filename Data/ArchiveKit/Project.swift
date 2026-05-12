import ProjectDescription
import ProjectDescriptionHelpers

// ArchiveKit uses a custom project definition so that the test bundle includes
// the binary fixture (Tests/Resources/sample.cbz) needed by ZipArchiveReaderTests.
private let bundleId = "com.coby.mana.archivekit"
private let deploymentTargets: DeploymentTargets = .iOS("17.0")

private let externalDeps: [TargetDependency] = [.external(name: "ZIPFoundation"), .external(name: "UnrarKit")]
private let domainDep: TargetDependency = .project(target: "Domain", path: "../../Domain")
private let frameworkSettings: Settings = .settings(base: [
    "CODE_SIGN_STYLE": "Automatic",
    "DEVELOPMENT_TEAM": "3Y8YH8GWMM",
    "MARKETING_VERSION": "1.0.0",
    "CURRENT_PROJECT_VERSION": "1",
    "SWIFT_VERSION": "6.0"
])

private let frameworkTarget = Target.target(
    name: "ArchiveKit",
    destinations: .iOS,
    product: .framework,
    bundleId: bundleId,
    deploymentTargets: deploymentTargets,
    sources: ["Sources/**"],
    dependencies: [domainDep] + externalDeps,
    settings: frameworkSettings
)

private let testTarget = Target.target(
    name: "ArchiveKitTests",
    destinations: .iOS,
    product: .unitTests,
    bundleId: "\(bundleId).tests",
    deploymentTargets: deploymentTargets,
    sources: ["Tests/**"],
    resources: ["Tests/Resources/**"],
    dependencies: [.target(name: "ArchiveKit")],
    settings: frameworkSettings
)

let project = Project(name: "ArchiveKit", targets: [frameworkTarget, testTarget])
