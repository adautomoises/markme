// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "markme",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "MarkmeCore", targets: ["MarkmeCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-cmark.git", exact: "0.9.0"),
    ],
    targets: [
        .target(
            name: "MarkmeCore",
            dependencies: [
                .product(name: "cmark-gfm", package: "swift-cmark"),
                .product(name: "cmark-gfm-extensions", package: "swift-cmark"),
            ]
        ),
        .testTarget(name: "MarkmeCoreTests", dependencies: ["MarkmeCore"]),
        .executableTarget(name: "Markme", dependencies: ["MarkmeCore"]),
    ]
)
