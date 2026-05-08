import ProjectDescription

public enum ModuleKind { case feature, domain, data, designSystem, sharedUI, app }

public struct Module {
    public let name: String
    public let kind: ModuleKind
    public let dependencies: [TargetDependency]
    public let externalDependencies: [String]
    public let hasResources: Bool
    public let hasTests: Bool

    public init(
        name: String,
        kind: ModuleKind,
        dependencies: [TargetDependency] = [],
        externalDependencies: [String] = [],
        hasResources: Bool = false,
        hasTests: Bool = false
    ) {
        self.name = name
        self.kind = kind
        self.dependencies = dependencies
        self.externalDependencies = externalDependencies
        self.hasResources = hasResources
        self.hasTests = hasTests
    }

    public func project() -> Project {
        let bundleId = "com.example.mana.\(name.lowercased())"
        let externalDeps: [TargetDependency] = externalDependencies.map { .external(name: $0) }
        let deploymentTargets: DeploymentTargets = .iOS("26.0")

        let frameworkTarget = Target.target(
            name: name,
            destinations: .iOS,
            product: .framework,
            bundleId: bundleId,
            deploymentTargets: deploymentTargets,
            sources: ["Sources/**"],
            resources: hasResources ? ["Resources/**"] : nil,
            dependencies: dependencies + externalDeps
        )

        var targets: [Target] = [frameworkTarget]
        if hasTests {
            let testTarget = Target.target(
                name: "\(name)Tests",
                destinations: .iOS,
                product: .unitTests,
                bundleId: "\(bundleId).tests",
                deploymentTargets: deploymentTargets,
                sources: ["Tests/**"],
                dependencies: [.target(name: name)]
            )
            targets.append(testTarget)
        }
        return Project(name: name, targets: targets)
    }
}
