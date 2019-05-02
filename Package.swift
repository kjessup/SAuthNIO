// swift-tools-version:5.0
import PackageDescription

let package = Package(
	name: "SAuthNIO",
	products: [
		.executable(name: "SAuthNIO", targets: ["SAuthNIO"])
	],
	dependencies: [
		.package(url: "https://github.com/PerfectlySoft/Perfect-PostgreSQL.git", from: "3.1.0"),
		.package(url: "https://github.com/kjessup/SAuthCodables.git", .branch("master")),
		.package(url: "https://github.com/kjessup/SAuthNIOLib.git", .branch("master")),
		.package(url: "https://github.com/PerfectlySoft/Perfect-NIO.git", .branch("master")),
		.package(url: "https://github.com/PerfectlySoft/Perfect-Notifications.git", from: "4.0.0"),
		.package(url: "https://github.com/PerfectlySoft/Perfect-SMTP.git", from: "4.0.0"),
	],
	targets: [
		.target(name: "SAuthNIO", dependencies: ["SAuthNIOLib",
											  "PerfectNotifications",
											  "PerfectPostgreSQL",
											  "SAuthCodables",
											  "PerfectNIO"]),
		.testTarget(name: "SAuthNIOTests", dependencies: ["SAuthNIO", "SAuthNIOLib"])
	]
)
