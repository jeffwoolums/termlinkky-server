// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TermLinky",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "TermLinky", targets: ["TermLinky"])
    ],
    dependencies: [
        .package(url: "https://github.com/Nirma/SFSymbol", from: "2.3.0")
    ],
    targets: [
        .target(
            name: "TermLinky",
            dependencies: ["SFSymbol"],
            path: "TermLinky/Sources"
        )
    ]
)
