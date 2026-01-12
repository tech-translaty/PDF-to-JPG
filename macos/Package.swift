// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PDFtoJPG",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "PDFtoJPG",
            path: "Sources"
        )
    ]
)
