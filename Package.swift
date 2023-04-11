// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "simprokcache",
    products: [
        .library(
            name: "simprokcache",
            targets: ["simprokcache"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/simprok-dev/simproktools-ios.git",
            exact: .init(1, 2, 44)
        ),
    ],
    targets: [
        .target(
            name: "simprokcache",
            dependencies: [
                .product(
                    name: "simproktools",
                    package: "simproktools-ios"
                )
            ]
        ),
    ]
)
