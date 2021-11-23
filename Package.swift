// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "LunchOnUsDownloader",
    platforms: [
        .macOS(.v12), .iOS(.v15), .watchOS(.v8), .tvOS(.v15)
    ],
    products: [
        .library(
            name: "LunchOnUsDownloader",
            targets: ["LunchOnUsDownloader"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/Nef10/SwiftBeanCountParserUtils.git",
            .exact("0.0.1")
        ),
    ],
    targets: [
        .target(
            name: "LunchOnUsDownloader",
            dependencies: [
                "SwiftBeanCountParserUtils",
            ]),
        .testTarget(
            name: "LunchOnUsDownloaderTests",
            dependencies: ["LunchOnUsDownloader"]),
    ]
)
