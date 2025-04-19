// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "PostalgicPackages",
    platforms: [
        .iOS(.v16),
    ],
    dependencies: [
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.0"),
    ],
    targets: [
        .target(
            name: "PostalgicPackages",
            dependencies: ["ZIPFoundation"]
        ),
    ]
)