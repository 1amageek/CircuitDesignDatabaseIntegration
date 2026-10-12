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
    platforms: [.macOS("27.0")],
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
        .package(url: "https://github.com/1amageek/CircuiteFoundation.git", revision: "ae88104c556f5802819713ed741f5b2fffffc2d9"),
        .package(url: "https://github.com/1amageek/DesignDatabase.git", revision: "11df4ff7d905d642b5935defb3bc1fbcfefda038"),
        .package(url: "https://github.com/1amageek/CoreSpice.git", revision: "f2bd5861610cfc10aae2395d287b0c6a5789c6ed"),
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
