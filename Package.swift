// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "RazerMonWidget",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "RazerMonWidget", targets: ["RazerMonWidget"])],
    targets: [
        .executableTarget(name: "RazerMonWidget", linkerSettings: [.linkedFramework("IOKit")]),
        .testTarget(name: "RazerMonWidgetTests", dependencies: ["RazerMonWidget"]),
    ],
    swiftLanguageModes: [.v5]
)
