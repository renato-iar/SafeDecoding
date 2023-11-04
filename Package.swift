// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

var package = Package(
    name: "SafeDecoding",
    platforms: [
        .macOS(.v13),
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v6),
        .macCatalyst(.v13)
    ],
    dependencies: [
        // Depend on the Swift 5.9 release of SwiftSyntax
        .package(
            url: "https://github.com/apple/swift-syntax.git",
            from: "509.0.0"
        )
    ]
)

// MARK: - SafeDecoding

package.targets.append(contentsOf: [
    .macro(
        name: "SafeDecodingMacros",
        dependencies: [
            .product(
                name: "SwiftSyntaxMacros",
                package: "swift-syntax"
            ),
            .product(
                name: "SwiftCompilerPlugin",
                package: "swift-syntax"
            )
        ],
        path: "Sources/SafeDecoding/Macros"
    ),

    .target(
        name: "SafeDecoding",
        dependencies: [
            "SafeDecodingMacros"
        ],
        path: "Sources/SafeDecoding/PlugIn"
    ),

    .executableTarget(
        name: "SafeDecodingClient",
        dependencies: [
            "SafeDecoding"
        ],
        path: "Sources/SafeDecoding/ExampleClient"
    ),

    .testTarget(
        name: "SafeDecodingMacrosTests",
        dependencies: [
            "SafeDecodingMacros",
            .product(
                name: "SwiftSyntaxMacrosTestSupport",
                package: "swift-syntax"
            )
        ]
    ),

    .testTarget(
        name: "SafeDecodingTests",
        dependencies: [
            "SafeDecoding",
            .product(
                name: "SwiftSyntaxMacrosTestSupport",
                package: "swift-syntax"
            )
        ]
    )
])

package.products.append(contentsOf: [
    .library(
        name: "SafeDecoding",
        targets: [
            "SafeDecoding"
        ]
    )
])
