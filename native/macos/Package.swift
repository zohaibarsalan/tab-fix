// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "TabFixNative",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .executable(name: "TabFixNative", targets: ["TabFixNative"])
  ],
  targets: [
    .executableTarget(
      name: "TabFixNative",
      path: "Sources/TabFixNative"
    )
  ]
)

