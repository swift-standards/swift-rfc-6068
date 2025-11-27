// swift-tools-version: 6.2

import PackageDescription

extension String {
    static let rfc6068: Self = "RFC 6068"
}

extension Target.Dependency {
    static var rfc6068: Self { .target(name: .rfc6068) }
    static var incits41986: Self { .product(name: "INCITS 4 1986", package: "swift-incits-4-1986") }
    static var rfc3986: Self { .product(name: "RFC 3986", package: "swift-rfc-3986") }
    static var rfc5322: Self { .product(name: "RFC 5322", package: "swift-rfc-5322") }
}

let package = Package(
    name: "swift-rfc-6068",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
        .tvOS(.v18),
        .watchOS(.v11),
    ],
    products: [
        .library(name: .rfc6068, targets: [.rfc6068])
    ],
    dependencies: [
        .package(url: "https://github.com/swift-standards/swift-incits-4-1986", from: "0.5.0"),
        .package(path: "../swift-rfc-3986"),
        .package(path: "../swift-rfc-5322"),
    ],
    targets: [
        .target(
            name: .rfc6068,
            dependencies: [
                .incits41986,
                .rfc3986,
                .rfc5322,
            ]
        ),
        .testTarget(
            name: .rfc6068.tests,
            dependencies: [.rfc6068]
        ),
    ],
    swiftLanguageModes: [.v6]
)

extension String {
    var tests: Self { self + " Tests" }
}

for target in package.targets where ![.system, .binary, .plugin].contains(target.type) {
    let existing = target.swiftSettings ?? []
    target.swiftSettings =
        existing + [
            .enableUpcomingFeature("ExistentialAny"),
            .enableUpcomingFeature("InternalImportsByDefault"),
            .enableUpcomingFeature("MemberImportVisibility"),
        ]
}
