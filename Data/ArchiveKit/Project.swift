import ProjectDescription
import ProjectDescriptionHelpers

// ArchiveKit uses a custom project definition so that the test bundle includes
// the binary fixture (Tests/Resources/sample.cbz) needed by ZipArchiveReaderTests.
private let bundleId = "com.example.mana.archivekit"
private let deploymentTargets: DeploymentTargets = .iOS("26.0")

private let externalDeps: [TargetDependency] = [.external(name: "ZIPFoundation")]
private let domainDep: TargetDependency = .project(target: "Domain", path: "../../Domain")

private let frameworkTarget = Target.target(
    name: "ArchiveKit",
    destinations: .iOS,
    product: .framework,
    bundleId: bundleId,
    deploymentTargets: deploymentTargets,
    sources: ["Sources/**"],
    dependencies: [domainDep] + externalDeps
)

private let testTarget = Target.target(
    name: "ArchiveKitTests",
    destinations: .iOS,
    product: .unitTests,
    bundleId: "\(bundleId).tests",
    deploymentTargets: deploymentTargets,
    sources: ["Tests/**"],
    resources: ["Tests/Resources/**"],
    dependencies: [.target(name: "ArchiveKit")]
)

let project = Project(name: "ArchiveKit", targets: [frameworkTarget, testTarget])
