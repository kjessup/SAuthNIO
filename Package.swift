// swift-tools-version:4.0
// Generated automatically by Perfect Assistant
// Date: 2018-04-27 13:55:57 +0000
import PackageDescription

let package = Package(
	name: "SAuth",
	products: [
		.executable(name: "SAuth", targets: ["SAuth"])
	],
	dependencies: [
		.package(url: "https://github.com/PerfectlySoft/Perfect-PostgreSQL.git", "3.1.0"..<"4.0.0"),
		.package(url: "https://github.com/kjessup/SAuthCodables.git", .branch("master")),
		.package(url: "https://github.com/kjessup/SAuthLib.git", .branch("master")),
		.package(url: "https://github.com/PerfectlySoft/Perfect-HTTPServer.git", "3.0.10"..<"4.0.0"),
		.package(url: "https://github.com/PerfectlySoft/Perfect-CloudFormation.git", "0.0.0"..<"1.0.0"),
		.package(url: "https://github.com/PerfectlySoft/Perfect-Notifications.git", "3.0.0"..<"4.0.0"),
		.package(url: "https://github.com/PerfectlySoft/Perfect-SMTP.git", "3.2.0"..<"4.0.0"),
		.package(url: "https://github.com/PerfectlySoft/Perfect-Mustache.git", "3.0.1"..<"4.0.0")
	],
	targets: [
		.target(name: "SAuth", dependencies: ["SAuthLib", "PerfectNotifications", "PerfectPostgreSQL", "PerfectMustache", "SAuthCodables", "PerfectHTTPServer", "PerfectCloudFormation"]),
		.testTarget(name: "SAuthTests", dependencies: ["SAuth", "SAuthLib"])
	]
)