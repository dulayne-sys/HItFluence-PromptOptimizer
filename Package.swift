// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PromptStudioCore",
    platforms: [.macOS("27.0")],
    products: [.library(name: "PromptStudioCore", targets: ["PromptStudioCore"])],
    targets: [
        .target(name: "PromptStudioCore", path: "Sources/PromptStudioCore"),
        .testTarget(name: "PromptStudioCoreTests", dependencies: ["PromptStudioCore"], path: "Tests/PromptStudioCoreTests")
    ]
)
