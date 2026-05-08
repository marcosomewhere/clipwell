// swift-tools-version: 5.9
// Clipwell v1.2
//
// Zero external dependencies. All functionality uses Apple-native frameworks only.
//
// Info.plist note: SPM forbids Info.plist inside the Resources/ directory for
// executable targets. Instead, Info.plist lives at Sources/Clipwell/Info.plist
// and is embedded into the binary via the -sectcreate linker flag.
// This is the standard pattern for SPM-based macOS menu bar apps.

import PackageDescription

let package = Package(
    name: "Clipwell",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Clipwell", targets: ["Clipwell"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "Clipwell",
            dependencies: [],
            path: "Sources/Clipwell",
            exclude: [
                "Info.plist"   // handled via -sectcreate below, not as a resource
            ],
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .linkedFramework("Carbon"),
                .linkedFramework("Vision"),
                .linkedFramework("ServiceManagement"),
                // Embed Info.plist into the __TEXT/__info_plist section of the binary.
                // macOS reads bundle metadata from here when running as an .app.
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/Clipwell/Info.plist"
                ])
            ]
        )
    ]
)
