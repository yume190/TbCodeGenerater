// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TbCodeGenerater",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(name: "tbCodeGenerater", targets: ["TbCodeGenerater"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "TbCodeGenerater",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                "TbParser",
            ],
            exclude: [
                "tds",
            ],
            resources: [
                .copy("tds"),
            ]
        ),
        .target(name: "TbParser"),
        
        .plugin(
            name: "GenerateTbTestCode",
            capability: .buildTool(),
            dependencies: [
                "TbCodeGenerater",
            ]
        ),
        .testTarget(
            name: "TbParserTests",
            dependencies: [
                "TbParser"
            ],
            plugins: [
                "GenerateTbTestCode",
            ]
        )
    ]
)
