// swift-tools-version: 5.9
// Package.swift — used during early development so SourceKit can resolve
// cross-file references before the Claudex.xcodeproj is generated.
//
// To build the actual menu bar .app bundle, open Claudex.xcodeproj in Xcode
// (see docs/xcode-setup.md). SwiftPM cannot produce a macOS .app bundle with
// Info.plist + LSUIElement directly.

import PackageDescription

let package = Package(
    name: "Claudex",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "Claudex", targets: ["Claudex"]),
    ],
    targets: [
        // Module name matches the Xcode app target so the same `@testable
        // import Claudex` works in both SPM and Xcode contexts.
        .target(
            name: "Claudex",
            path: "Claudex",
            exclude: [
                "Resources",
                // ClaudexApp.swift declares @main; it must only be linked into
                // the actual .app bundle built by Xcode, never into the SPM
                // library or test runner (would conflict with XCTest's main).
                "ClaudexApp.swift",
            ]
        ),
        .testTarget(
            name: "ClaudexTests",
            dependencies: ["Claudex"],
            path: "ClaudexTests"
        ),
    ]
)
