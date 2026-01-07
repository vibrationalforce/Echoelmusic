import ProjectDescription

/// Tuist Configuration for Echoelmusic
/// Defines global settings for project generation
let config = Config(
    compatibleXcodeVersions: [
        "15.0",
        "15.1",
        "15.2"
    ],
    swiftVersion: "5.9",
    generationOptions: .options(
        resolveDependenciesWithSystemScm: true,
        disablePackageVersionLocking: false,
        clonedSourcePackagesDirPath: nil,
        staticSideEffectsWarningTargets: .all,
        enforceExplicitDependencies: true,
        defaultConfiguration: "Debug"
    ),
    plugins: [],
    cache: .cache(
        profiles: [
            .profile(
                name: "Development",
                configuration: "Debug"
            ),
            .profile(
                name: "Release",
                configuration: "Release"
            )
        ],
        path: nil
    )
)
