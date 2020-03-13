
import Foundation
import PerfectNotifications
import PerfectNIO
import NIO
import SAuthNIOLib
import PerfectLib
import PerfectCrypto
import PerfectMustache
import SAuthConfig
import SAuthRoutes

try initializeConfig()
try initializeNotifications()

let sauthConfigProvider = SAuthConfig.SAuthConfigProvider()
let sauth = SAuth(sauthConfigProvider)
try sauth.initialize()

let sRoutes = try root().sauth.dir(try sauthRoutes(sauth))

let administrationFiles = try root().GET.dir(type: HTTPOutput.self) {
	$0.path("profile-pics").trailing {
		return try FileOutput(localPath: "./webroot/profile-pics/" + $1) as HTTPOutput
	}
}

let tls: TLSConfiguration?

if let privateKey = Config.globalConfig.server.privateKeyPath {
	let chain: [NIOSSLCertificateSource]
	if let chainPath = Config.globalConfig.server.certificateChainPath {
		chain = [.file(chainPath)]
	} else {
		chain = []
	}
	tls = TLSConfiguration.forServer(
		certificateChain: chain,
		privateKey: .file(privateKey))
} else {
	tls = nil
}

let allRoutes = try root().dir(sRoutes, administrationFiles)
let server = try allRoutes.bind(port: Config.globalConfig.server.port, tls: tls).listen()
print("Bound and listening on \(Config.globalConfig.server.port)")
print("Serving routes:")
print("\(allRoutes.description)")

try server.wait()
