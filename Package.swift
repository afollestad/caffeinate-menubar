// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "caffeinate-menubar",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "Caffeinate", targets: ["Caffeinate"])
    ],
    targets: [
        .target(
            name: "CaffeinateKit",
            exclude: ["AGENTS.md", "CLAUDE.md"]
        ),
        .executableTarget(
            name: "Caffeinate",
            dependencies: ["CaffeinateKit"],
            exclude: ["AGENTS.md", "CLAUDE.md"]
        ),
        .testTarget(
            name: "CaffeinateKitTests",
            dependencies: ["CaffeinateKit"]
        )
    ]
)
