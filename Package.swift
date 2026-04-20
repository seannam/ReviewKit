// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ReviewKit",
    platforms: [.iOS(.v16), .macOS(.v14), .tvOS(.v16)],
    products: [
        .library(name: "ReviewKit", targets: ["ReviewKit"])
    ],
    targets: [
        .target(name: "ReviewKit")
    ]
)
