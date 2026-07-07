// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Swiftty",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Swiftty", targets: ["Swiftty"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/migueldeicaza/SwiftTerm.git",
            revision: "75d0fd92e0374c054ff1cea349fc88f9fdee03a5"
        ),
        .package(url: "https://github.com/soffes/HotKey.git", from: "0.2.0"),
        .package(url: "https://github.com/sparkle-project/Sparkle.git", from: "2.9.0"),
    ],
    targets: [
        .executableTarget(
            name: "Swiftty",
            dependencies: [
                .product(name: "SwiftTerm", package: "SwiftTerm"),
                .product(name: "HotKey", package: "HotKey"),
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Sources/Swiftty",
            exclude: ["Info.plist"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/Swiftty/Info.plist",
                    "-Xlinker", "-rpath",
                    "-Xlinker", "@executable_path/../Frameworks",
                    "-Xlinker", "-rpath",
                    "-Xlinker", "@executable_path",
                ])
            ]
        )
    ]
)
