// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TwinkleBulbs",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "TwinkleBulbsCore", targets: ["TwinkleBulbsCore"]),
        .executable(name: "TwinkleBulbs", targets: ["TwinkleBulbs"]),
        .executable(name: "TwinkleBulbsVerifier", targets: ["TwinkleBulbsVerifier"])
    ],
    targets: [
        .target(
            name: "TwinkleBulbsCore",
            path: "TwinkleBulbs",
            exclude: ["Info.plist", "main.swift", "TwinkleBulbs.entitlements"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "TwinkleBulbs",
            dependencies: ["TwinkleBulbsCore"],
            path: "SwiftPMEntry",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "TwinkleBulbsVerifier",
            dependencies: ["TwinkleBulbsCore"],
            path: "TwinkleBulbsVerifier",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
