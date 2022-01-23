// swift-tools-version:5.5

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
    .package(name: "combine-schedulers", url: "https://github.com/Incetro/combine-schedulers", .branch("master")),
    .package(name: "enum-key-paths", url: "https://github.com/Incetro/enum-key-paths", .branch("master")),
    .package(name: "xctest-interface-adapter", url: "https://github.com/Incetro/xctest-interface-adapter", .branch("master"))
  ],
  targets: [
    .target(
      name: "VERSE",
      dependencies: [
        .product(name: "EnumKeyPaths", package: "enum-key-paths"),
        .product(name: "CombineSchedulers", package: "combine-schedulers"),
        .product(name: "XCTestInterfaceAdapter", package: "xctest-interface-adapter")
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
