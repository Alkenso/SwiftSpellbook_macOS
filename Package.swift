// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftSpellbook_macOS",
    platforms: [
        .macOS(.v11),
    ],
    products: [
        .library(name: "SpellbookMac", targets: ["SpellbookMac"]),
        .library(name: "SpellbookEndpointSecurity", targets: ["SpellbookEndpointSecurity"]),
        .library(name: "SpellbookEndpointSecurityXPC", targets: ["SpellbookEndpointSecurityXPC"]),
        .library(name: "SpellbookHDIUtil", targets: ["SpellbookHDIUtil"]),
        .library(name: "SpellbookLaunchctl", targets: ["SpellbookLaunchctl"]),
        .library(name: "SpellbookXPC", targets: ["SpellbookXPC"]),
        
        .library(name: "xar", targets: ["xar"]),
        .library(name: "membership", targets: ["membership"]),
        .library(name: "libproc", targets: ["libproc"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Alkenso/SwiftSpellbook.git", from: "1.0.2"),
    ],
    targets: [
        // MacShims.
        .systemLibrary(name: "xar", path: "MacShims/xar"),
        .systemLibrary(name: "membership", path: "MacShims/membership"),
        .systemLibrary(name: "libproc", path: "MacShims/libproc"),
        
        // Mac.
        .target(
            name: "SpellbookMac",
            dependencies: [
                "membership",
                .product(name: "SpellbookFoundation", package: "SwiftSpellbook")
            ],
            path: "Mac/Sources/SpellbookMac"
        ),
        .testTarget(
            name: "SpellbookMacTests",
            dependencies: [
                "SpellbookMac",
                .product(name: "SpellbookFoundation", package: "SwiftSpellbook"),
                .product(name: "SpellbookTestUtils", package: "SwiftSpellbook"),
            ],
            path: "Mac/Tests/SpellbookMacTests"
        ),
        
        // EndpointSecurity.
        .target(
            name: "SpellbookEndpointSecurity",
            dependencies: [
                .product(name: "SpellbookFoundation", package: "SwiftSpellbook")
            ],
            path: "EndpointSecurity/Sources/SpellbookEndpointSecurity",
            linkerSettings: [.linkedLibrary("EndpointSecurity")]
        ),
        .target(
            name: "SpellbookEndpointSecurityXPC",
            dependencies: [
                "SpellbookEndpointSecurity",
                .product(name: "SpellbookFoundation", package: "SwiftSpellbook")
            ],
            path: "EndpointSecurity/Sources/SpellbookEndpointSecurityXPC"
        ),
        .testTarget(
            name: "SpellbookEndpointSecurityTests",
            dependencies: [
                "SpellbookEndpointSecurity",
                .product(name: "SpellbookFoundation", package: "SwiftSpellbook"),
                .product(name: "SpellbookTestUtils", package: "SwiftSpellbook"),
            ],
            path: "EndpointSecurity/Tests/SpellbookEndpointSecurityTests"
        ),
        
        // HDIUtil.
        .target(
            name: "SpellbookHDIUtil",
            dependencies: [
                "SpellbookMac",
                .product(name: "SpellbookFoundation", package: "SwiftSpellbook"),
            ],
            path: "HDIUtil/Sources/SpellbookHDIUtil"
        ),
        .testTarget(
            name: "SpellbookHDIUtilTests",
            dependencies: [
                "SpellbookHDIUtil",
                .product(name: "SpellbookFoundation", package: "SwiftSpellbook"),
            ],
            path: "HDIUtil/Tests/SpellbookHDIUtilTests"
        ),
        
        // Launchctl.
        .target(
            name: "SpellbookLaunchctl",
            dependencies: [
                "SpellbookMac",
                .product(name: "SpellbookFoundation", package: "SwiftSpellbook"),
            ],
            path: "Launchctl/Sources/SpellbookLaunchctl"
        ),
        .testTarget(
            name: "SpellbookLaunchctlTests",
            dependencies: [
                "SpellbookLaunchctl",
                .product(name: "SpellbookFoundation", package: "SwiftSpellbook"),
            ],
            path: "Launchctl/Tests/SpellbookLaunchctlTests"
        ),
        
        // XPC.
        .target(
            name: "SpellbookXPC",
            dependencies: [
                "SpellbookMac",
                .product(name: "SpellbookFoundation", package: "SwiftSpellbook"),
                .product(name: "SpellbookBinaryParsing", package: "SwiftSpellbook"),
            ],
            path: "XPC/Sources/SpellbookXPC"
        ),
        .testTarget(
            name: "SpellbookXPCTests",
            dependencies: [
                "SpellbookXPC",
                .product(name: "SpellbookFoundation", package: "SwiftSpellbook"),
                .product(name: "SpellbookTestUtils", package: "SwiftSpellbook"),
            ],
            path: "XPC/Tests/SpellbookXPCTests"
        ),
    ]
)
