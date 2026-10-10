// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BilbyKit",
    platforms: [.macOS("26.0"), .iOS("26.0")],
    products: [
        .library(name: "BilbyKit", targets: ["BilbyKit"]),
    ],
    targets: [
        .target(name: "BilbyKit"),
        .testTarget(name: "BilbyKitTests", dependencies: ["BilbyKit"]),
    ]
)
