// swift-tools-version: 6.0
import Foundation
import PackageDescription

// Keep the Xcode lockfile authoritative for both build entry points.
struct DependencyLock: Decodable {
    struct Pin: Decodable {
        struct State: Decodable { let revision: String }
        let location: String
        let state: State
    }
    let pins: [Pin]
}
let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let lockURL = root.appendingPathComponent("Ice.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved")
let lock = try JSONDecoder().decode(DependencyLock.self, from: Data(contentsOf: lockURL))

let package = Package(
    name: "Ice",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Ice", targets: ["Ice"])],
    dependencies: lock.pins.map { .package(url: $0.location, revision: $0.state.revision) },
    targets: [
        .executableTarget(
            name: "Ice",
            dependencies: [
                .product(name: "AXSwift", package: "AXSwift"),
                .product(name: "CompactSlider", package: "CompactSlider"),
                .product(name: "IfritStatic", package: "Ifrit"),
                .product(name: "LaunchAtLogin", package: "LaunchAtLogin-Modern"),
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Ice",
            exclude: ["Info.plist", "Ice.entitlements", "Resources/Acknowledgements.rtf"],
            resources: [.copy("Assets.xcassets"), .process("Resources")],
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]
        ),
    ],
    swiftLanguageModes: [.v5]
)
