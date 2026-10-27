// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "XM6Control",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "XM6Control",
            linkerSettings: [.linkedFramework("IOBluetooth"), .linkedFramework("ServiceManagement")]
        )
    ]
)
