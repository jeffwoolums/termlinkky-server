// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TermLinkky",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "TermLinkky", targets: ["TermLinkky"])
    ],
    dependencies: [
        .package(url: "https://github.com/Nirma/SFSymbol", from: "2.3.0")
    ],
    targets: [
        .target(
            name: "TermLinkky",
            dependencies: ["SFSymbol"],
            path: "TermLinkky/Sources"
        )
    ]
)
