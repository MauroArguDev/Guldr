// swift-tools-version: 6.2
// 6.2 is the newest tools version supported by Xcode 26.6 on the CI runners.

import PackageDescription

// Domain layer shared by the app and the widget (ADR 006). macOS is listed only so the
// tests run with `swift test` on the Mac and on CI, without an iOS simulator.
// Unlike the app targets, the package keeps Swift's default nonisolated isolation:
// its value types are Sendable and callable from any context.
let package = Package(
    name: "GuldrCore",
    platforms: [
        .iOS(.v26),
        .macOS(.v26)
    ],
    products: [
        .library(name: "GuldrCore", targets: ["GuldrCore"])
    ],
    dependencies: [
        .package(url: "https://github.com/SimplyDanny/SwiftLintPlugins", exact: "0.65.1")
    ],
    targets: [
        .target(
            name: "GuldrCore",
            plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")]
        ),
        .testTarget(
            name: "GuldrCoreTests",
            dependencies: ["GuldrCore"],
            plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")]
        )
    ],
    swiftLanguageModes: [.v6]
)
