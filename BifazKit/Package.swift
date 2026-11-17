// swift-tools-version: 6.2
import PackageDescription

/// Bifaz's shared code. Every module builds in Swift 6 language mode,
/// which turns on complete (strict) concurrency checking.
let package = Package(
    name: "BifazKit",
    defaultLocalization: "en",
    platforms: [.iOS(.v26)],
    products: [
        .library(name: "BifazModels", targets: ["BifazModels"]),
        .library(name: "BifazDesign", targets: ["BifazDesign"]),
        .library(name: "BifazReading", targets: ["BifazReading"]),
        .library(name: "BifazReports", targets: ["BifazReports"]),
        .library(name: "BifazSecurity", targets: ["BifazSecurity"]),
    ],
    targets: [
        // Data model (SwiftData) and persistence.
        .target(name: "BifazModels"),
        // Tokens, brand marks and reusable components.
        .target(
            name: "BifazDesign",
            dependencies: ["BifazModels"],
            resources: [.process("Resources")]
        ),
        // Phase 2: receipt reading. Placeholder only.
        .target(name: "BifazReading", dependencies: ["BifazModels"]),
        // Phase 5: PDF / CSV / ZIP reports. Placeholder only.
        .target(name: "BifazReports", dependencies: ["BifazModels"]),
        // Phase 6: Data Protection, Face ID, encrypted backup. Placeholder only.
        .target(name: "BifazSecurity", dependencies: ["BifazModels"]),

        .testTarget(name: "BifazModelsTests", dependencies: ["BifazModels"]),
        .testTarget(name: "BifazDesignTests", dependencies: ["BifazDesign"]),
    ],
    swiftLanguageModes: [.v6]
)
