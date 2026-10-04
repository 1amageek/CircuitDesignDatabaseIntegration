// swift-tools-version: 6.4
import PackageDescription

func releasedDependency(named name: String, exactVersion: Version) -> Package.Dependency {
    .package(
        url: "https://github.com/1amageek/\(name).git",
        exact: exactVersion
    )
}

let package = Package(
    name: "CircuitDesignDatabaseIntegration",
    platforms: [.macOS(.v26)],
    products: [
        .library(
            name: "CircuitDesignDatabaseSchema",
            targets: ["CircuitDesignDatabaseSchema"]
        ),
        .library(
            name: "CircuitDesignDatabaseRuntimeAdapter",
            targets: ["CircuitDesignDatabaseRuntimeAdapter"]
        ),
    ],
    dependencies: [
        releasedDependency(
            named: "CircuiteFoundation",
            exactVersion: "26.812.0"
        ),
        releasedDependency(
            named: "DesignDatabase",
            exactVersion: "26.812.1"
        ),
        .package(url: "https://github.com/1amageek/CoreSpice.git", revision: "8fbcee58575b37a01795e11110731cfc16566520"),
        .package(
            url: "https://github.com/1amageek/database-kit.git",
            exact: "26.0809.4"
        ),
        .package(
            url: "https://github.com/1amageek/database-types.git",
            exact: "26.0730.0"
        ),
        .package(
            url: "https://github.com/1amageek/database-framework.git",
            exact: "26.0809.1",
            traits: ["SQLite"]
        ),
    ],
    targets: [
        .target(
            name: "CircuitDesignDatabaseSchema",
            dependencies: [
                .product(name: "CircuiteFoundation", package: "CircuiteFoundation"),
                .product(name: "CircuiteFoundationCrypto", package: "CircuiteFoundation"),
                .product(name: "DesignDatabaseCore", package: "DesignDatabase"),
                .product(name: "CoreSpiceIR", package: "CoreSpice"),
                .product(name: "DatabaseKit", package: "database-kit"),
                .product(name: "DatabaseTypes", package: "database-types"),
                .product(name: "DatabaseTypesFoundation", package: "database-types"),
            ]
        ),
        .target(
            name: "CircuitDesignDatabaseRuntimeAdapter",
            dependencies: [
                "CircuitDesignDatabaseSchema",
                .product(name: "CircuiteFoundation", package: "CircuiteFoundation"),
                .product(name: "CircuiteFoundationCrypto", package: "CircuiteFoundation"),
                .product(name: "DesignDatabaseCore", package: "DesignDatabase"),
                .product(name: "DesignDatabaseRuntime", package: "DesignDatabase"),
                .product(name: "Database", package: "database-framework"),
            ]
        ),
        .testTarget(
            name: "CircuitDesignDatabaseIntegrationTests",
            dependencies: [
                "CircuitDesignDatabaseSchema",
                "CircuitDesignDatabaseRuntimeAdapter",
                .product(name: "CircuiteFoundation", package: "CircuiteFoundation"),
                .product(name: "CircuiteFoundationCrypto", package: "CircuiteFoundation"),
                .product(name: "DesignDatabaseCore", package: "DesignDatabase"),
                .product(name: "DesignDatabaseRuntime", package: "DesignDatabase"),
                .product(name: "CoreSpiceIR", package: "CoreSpice"),
                .product(name: "Database", package: "database-framework"),
            ]
        ),
    ]
)
