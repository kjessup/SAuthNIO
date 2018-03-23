// swift-tools-version:4.0
// Generated automatically by Perfect Assistant 2
// Date: 2018-03-02 17:48:07 +0000
import PackageDescription

let package = Package(
	name: "SAuth",
	products: [
		.executable(name: "SAuth", targets: ["SAuth"])
	],
	dependencies: [
		.package(url: "https://github.com/kjessup/Perfect-PostgreSQL.git", .branch("master")),
		.package(url: "https://github.com/kjessup/SAuthCodables.git", .branch("master")),
		.package(url: "https://github.com/kjessup/SAuthLib.git", .branch("master")),
		.package(url: "https://github.com/PerfectlySoft/Perfect-HTTPServer.git", from: "3.0.10"),
		.package(url: "https://github.com/PerfectlySoft/Perfect-CloudFormation.git", from: "0.0.0"),
		.package(url: "https://github.com/PerfectlySoft/Perfect-Notifications.git", from: "3.0.0"),
		.package(url: "https://github.com/PerfectlySoft/Perfect-SMTP.git", from: "3.2.0")
	],
	targets: [
		.target(name: "SAuth", dependencies: ["SAuthLib", "PerfectNotifications", "PerfectPostgreSQL", "SAuthCodables", "PerfectHTTPServer", "PerfectCloudFormation"]),
		.testTarget(name: "SAuthTests", dependencies: ["SAuth", "SAuthLib"])
	]
)
