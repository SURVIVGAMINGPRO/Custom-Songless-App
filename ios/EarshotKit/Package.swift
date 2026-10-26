// swift-tools-version: 6.0
import PackageDescription

// The game logic shared by the iPhone app: models, rules, alphabets, guess
// search, imports, the Deezer client, the clip player and the saved library.
// Run its tests on a Mac with `swift test`.
let package = Package(
	name: "EarshotKit",
	platforms: [.iOS(.v18), .macOS(.v14)],
	products: [.library(name: "EarshotCore", targets: ["EarshotCore"])],
	targets: [
		.target(name: "EarshotCore"),
		.testTarget(name: "EarshotCoreTests", dependencies: ["EarshotCore"])
	]
)
