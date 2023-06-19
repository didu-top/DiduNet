// swift-tools-version: 5.7
import PackageDescription

let package = Package(
  name: "DiduNet",
  platforms: [
    .iOS(.v14),
    .macOS(.v13)
  ],
  products: [
    // Products define the executables and libraries a package produces, and make them visible to other packages.
    .library(
      name: "DiduNet",
      targets: ["DiduNet"]
    )
  ],
  dependencies: [
    // Dependencies declare other packages that this package depends on.
    // .package(url: /* package url */, from: "1.0.0"),
    .package(url: "https://github.com/Moya/Moya.git", .upToNextMajor(from: "15.0.0")),
    .package(url: "https://github.com/ashleymills/Reachability.swift", from: "5.1.0"),
    .package(url: "https://github.com/didu-top/DiduFoundation.git", from: "0.0.2"),
    .package(url: "https://github.com/ReactiveX/RxSwift.git", from: "6.6.0")
  ],
  targets: [
    // Targets are the basic building blocks of a package. A target can define a module or a test suite.
    // Targets can depend on other targets in this package, and on products in packages this package depends on.
    .target(
      name: "DiduNet",
      dependencies: [
        "Moya",
        "DiduFoundation",
        "RxSwift",
        .product(name: "Reachability", package: "Reachability.swift")
      ]),
    .testTarget(
      name: "DiduNetTests",
      dependencies: [
        "DiduNet",
        "Moya",
        "RxSwift",
        "DiduFoundation",
        .product(name: "Reachability", package: "Reachability.swift")
      ]),
  ],
  swiftLanguageVersions: [.v5]
)
