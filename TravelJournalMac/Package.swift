// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TravelJournalMac",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "TravelJournalMac", targets: ["TravelJournalMac"])
    ],
    targets: [
        .executableTarget(
            name: "TravelJournalMac",
            path: "Sources/TravelJournalMac"
        )
    ]
)
