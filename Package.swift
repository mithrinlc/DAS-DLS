// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "DeviceAutoSetup",
    products: [
        .library(
            name: "DeviceAutoSetup",
            targets: ["DeviceAutoSetup"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "DeviceAutoSetup",
            dependencies: [])
    ]
)
