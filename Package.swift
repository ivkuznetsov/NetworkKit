// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NetworkKit",
    platforms: [
        .iOS(.v11)
    ],
    products: [
        .library(name: "NetworkKit", targets: ["NetworkKit"])
    ],
    dependencies: [
      .package(
        name: "AFNetworking",
        url: "https://github.com/AFNetworking/AFNetworking.git",
        "4.0.1" ..< "5.0.0"
      ),
    ],
    targets: [
        .target(name: "NetworkKit", path: "./NetworkKit", exclude: ["NetworkKit.h", "Info.plist"])
    ]
)
