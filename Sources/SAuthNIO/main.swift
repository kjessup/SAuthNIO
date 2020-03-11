
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

SAuthConfig.globalConfig = try Config.get()
try initializeNotifications()

let serverPrivateKey = try PEMKey(pemPath: "\(globalConfig.server.privateKeyName)")
let serverPublicKeyStr = try File("\(globalConfig.server.publicKeyName)").readString()
let serverPublicKey = try PEMKey(source: serverPublicKeyStr)
let serverPublicKeyJWT = try JWK(key: serverPublicKey)
let serverPublicKeyJWKStr = String(data: try JSONEncoder().encode(serverPublicKeyJWT), encoding: .utf8)

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

if let privateKey = globalConfig.server.privateKeyPath {
	let chain: [NIOSSLCertificateSource]
	if let chainPath = globalConfig.server.certificateChainPath {
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
let server = try allRoutes.bind(port: globalConfig.server.port, tls: tls).listen()
print("Bound and listening on \(globalConfig.server.port)")
print("Serving routes:")
print("\(allRoutes.description)")

try server.wait()
