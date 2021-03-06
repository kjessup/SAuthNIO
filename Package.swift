// swift-tools-version:5.1
import PackageDescription

let package = Package(
	name: "SAuthNIO",
	platforms: [
		.macOS(.v10_15)
	],
	products: [
		.executable(name: "SAuthNIO", targets: ["SAuthNIO"]),
		.library(name: "SAuthConfig", targets: ["SAuthConfig"]),
		.library(name: "SAuthRoutes", targets: ["SAuthRoutes"])
	],
	dependencies: [
		.package(url: "https://github.com/PerfectlySoft/Perfect-NIO.git", .branch("master")),
		.package(url: "https://github.com/PerfectlySoft/Perfect-Notifications.git", from: "5.0.0"),
		.package(url: "https://github.com/PerfectlySoft/Perfect-PostgreSQL.git", from: "4.0.0"),
		.package(url: "https://github.com/kjessup/SAuthNIOLib.git", .branch("master")),
	],
	targets: [
		.target(name: "SAuthNIO", dependencies: [
			"PerfectNIO",
			"PerfectNotifications",
			"SAuthRoutes",
			"SAuthConfig"]),
		.target(name: "SAuthRoutes", dependencies: [
			"SAuthConfig",
			"SAuthNIOLib",
			"PerfectPostgreSQL"]),
		.target(name: "SAuthConfig", dependencies: [
			"PerfectNIO",
			"SAuthNIOLib",
			"PerfectPostgreSQL"]),
		.testTarget(name: "SAuthNIOTests", dependencies: ["SAuthNIO", "SAuthNIOLib"])
	]
)
