// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "TabFix",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .executable(name: "TabFix", targets: ["TabFix"])
  ],
  targets: [
    .executableTarget(
      name: "TabFix",
      path: "Sources/TabFix"
    )
  ]
)

