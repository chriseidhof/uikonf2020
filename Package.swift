// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "uikonf2020",
    dependencies: [
        .package(name: "LineNoise", url: "https://github.com/andybest/linenoise-swift", from: "0.0.3"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "uikonf2020",
            dependencies: ["Template", "LineNoise"]),
        .target(
            name: "Template",
            dependencies: []),
        .testTarget(
            name: "uikonf2020Tests",
            dependencies: ["uikonf2020"]),
        .testTarget(
            name: "TemplateTests",
            dependencies: ["Template"]),
    ]
)
