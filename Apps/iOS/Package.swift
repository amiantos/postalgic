// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "PostalgicPackages",
    platforms: [
        .iOS(.v16),
    ],
    dependencies: [
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.0"),
        .package(url: "https://github.com/aws-amplify/aws-sdk-swift.git", from: "0.19.0"),
    ],
    targets: [
        .target(
            name: "PostalgicPackages",
            dependencies: [
                "ZIPFoundation",
                .product(name: "AWSS3", package: "aws-sdk-swift"),
                .product(name: "AWSCloudFront", package: "aws-sdk-swift")
            ]
        ),
    ]
)