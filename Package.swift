// swift-tools-version:5.1

import PackageDescription

let package = Package(
  name: "verse",
  platforms: [
    .iOS(.v13),
    .macOS(.v10_15),
    .tvOS(.v13),
    .watchOS(.v6),
  ],
  products: [
    .library(
      name: "VERSE",
      targets: ["VERSE"]
    )
  ],
  dependencies: [
    .package(url: "https://github.com/Incetro/combine-schedulers", .branch("master")),
    .package(url: "https://github.com/Incetro/enum-key-paths", .branch("master")),
    .package(url: "https://github.com/Incetro/xctest-interface-adapter", .branch("master"))
  ],
  targets: [
    .target(
      name: "VERSE",
      dependencies: [
        "EnumKeyPaths",
        "CombineSchedulers",
        "XCTestInterfaceAdapter",
      ]
    ),
    .testTarget(
      name: "VERSETests",
      dependencies: [
        "VERSE"
      ]
    ),
  ]
)
