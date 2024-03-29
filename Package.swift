// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftSpellbook_macOS",
    platforms: [
        .macOS(.v10_15),
    ],
    products: [
        .library(name: "Spellbook_macOS", targets: ["Spellbook_macOS"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Alkenso/SwiftSpellbook.git", from: "0.4.2"),
    ],
    targets: [
        .target(
            name: "Spellbook_macOS",
            dependencies: [
                "Spellbook_macOSObjc",
                .product(name: "SpellbookFoundation", package: "SwiftSpellbook")
            ]
        ),
        .systemLibrary(name: "Spellbook_macOSObjc"),
        .testTarget(
            name: "SpellbookmacOSTests",
            dependencies: [
                "Spellbook_macOS",
                .product(name: "SpellbookFoundation", package: "SwiftSpellbook"),
                .product(name: "SpellbookTestUtils", package: "SwiftSpellbook"),
            ],
            path: "Tests/Spellbook_macOSTests"
        ),
    ]
)
