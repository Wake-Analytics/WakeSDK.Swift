// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Wake",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
    ],
    products: [
        .library(name: "Wake", targets: ["Wake"]),
    ],
    targets: [
        .target(
            name: "Wake",
            resources: [.copy("PrivacyInfo.xcprivacy")]
        ),
        .testTarget(name: "WakeTests", dependencies: ["Wake"]),
    ]
)
