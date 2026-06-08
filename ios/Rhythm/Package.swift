// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Rhythm",
    platforms: [.iOS(.v17), .watchOS(.v10)],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", exact: "1.17.0"),
    ],
    targets: [
        .target(
            name: "Rhythm",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),
    ]
)
