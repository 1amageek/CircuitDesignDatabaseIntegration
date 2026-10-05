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
        .package(url: "https://github.com/1amageek/DesignDatabase.git", revision: "78f1c2e28e804e7c750014827e9f18c88c2272e3"),
        .package(url: "https://github.com/1amageek/CoreSpice.git", revision: "305d0933018f8a987c73c5186f53740ca315a516"),
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
            ],
            exclude: ["DESIGN.md"]
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
