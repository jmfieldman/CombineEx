// swift-tools-version:5.9

import PackageDescription

let package = Package(
  name: "CombineEx",
  platforms: [.iOS(.v16), .macOS(.v13), .tvOS(.v17), .watchOS(.v7)],
  products: [
    .library(name: "CombineEx", targets: ["CombineEx"]),
  ],
  dependencies: [],
  targets: [
    .target(
      name: "CombineEx",
      dependencies: [],
      path: "Sources"
    ),
    .testTarget(
      name: "CombineExTests",
      dependencies: ["CombineEx"],
      path: "Tests"
    ),
  ]
)
