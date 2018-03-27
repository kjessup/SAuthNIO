
import Foundation
import PerfectCloudFormation
import PerfectHTTPServer
import PerfectHTTP
import PerfectPostgreSQL
import PerfectCRUD
import PerfectLib
import PerfectCrypto
import PerfectSMTP
import PerfectMustache
import SAuthLib
import SAuthCodables

let globalConfig = try Config.get()
let serverPublicKeyStr = try File("\(configDir)\(globalConfig.server.publicKeyName)").readString()
let serverPublicKey = try PEMKey(source: serverPublicKeyStr)
let serverPrivateKey = try PEMKey(pemPath: "\(configDir)\(globalConfig.server.privateKeyName)")

struct SAuthConfigProvider: SAuthLib.SAuthConfigProvider {
	func sendEmailPasswordReset(authToken: String, account: Account, alias: AliasBrief) throws {
		guard let smtp = globalConfig.smtp else {
			throw SAuthError(description: "SMTP is not configured.")
		}
		guard let uri = globalConfig.uris.passwordReset else {
			throw SAuthError(description: "Password reset is not configured.")
		}
		let fullName = account.meta?.fullName ?? ""
		let client = SMTPClient(url: "smtp://\(smtp.host):\(smtp.port)",
			username: smtp.user,
			password: smtp.password,
			requiresTLSUpgrade: true)
		let email = EMail(client: client)
		email.connectTimeoutSeconds = 7
		email.subject = "Password Reset"
		email.to = [.init(name: fullName, address: alias.address)]
		email.from = .init(name: smtp.fromName, address: smtp.fromAddress)
		if let emailTemplate = globalConfig.templates?.passwordResetEmail {
			do {
				let map: [String:Any] = ["fullName":fullName, "uri":uri, "authToken":authToken]
				let ctx = MustacheEvaluationContext(templatePath: emailTemplate, map: map)
				let collector = MustacheEvaluationOutputCollector()
				email.text = try ctx.formulateResponse(withCollector: collector)
			} catch {
				email.text = plainResetEmailBody(fullName: fullName, uri: uri, authToken: authToken)
			}
		} else {
			email.text = plainResetEmailBody(fullName: fullName, uri: uri, authToken: authToken)
		}
		try email.send()
	}
	
	func plainResetEmailBody(fullName: String, uri: String, authToken: String) -> String {
		return """
		Hello, \(fullName). Here is your requested password reset link:
		\(uri)/\(authToken)
		
		This link will expire in fifteen minutes.
		
		Sincerely,
		Authentication Server
		"""
	}
	
	func getDB() throws -> Database<PostgresDatabaseConfiguration> {
		guard let db = try globalConfig.database?.crud() else {
			throw SAuthError(description: "Database is not configured.")
		}
		return db
	}
	func getServerPublicKey() throws -> PEMKey {
		return serverPublicKey
	}
	func getServerPrivateKey() throws -> PEMKey {
		return serverPrivateKey
	}
	func getPushConfigurationName(forType: String) throws -> String {
		guard let _ = globalConfig.notifications else {
			throw SAuthError(description: "iOS notifications are not configured.")
		}
		return sauthNotificationsConfigurationName
	}
	func getPushConfigurationTopic(forType: String) throws -> String {
		guard let topic = globalConfig.notifications?.topic else {
			throw SAuthError(description: "iOS notifications are not configured.")
		}
		return topic
	}
	
	func getTemplatePath(_ key: TemplateKey) throws -> String {
		var path: String?
		switch key {
		case .passwordResetForm:
			path = globalConfig.templates?.passwordResetForm
		case .passwordResetOk:
			path = globalConfig.templates?.passwordResetOk
		case .passwordResetError:
			path = globalConfig.templates?.passwordResetError
		}
		guard let p = path else {
			throw SAuthError(description: "The template \(key) is not defined.")
		}
		return "\(templatesDir)\(p)"
	}
	
	func getURI(_ key: URIKey) throws -> String {
		var path: String?
		switch key {
		case .oauthRedirect:
			path = globalConfig.uris.oauthRedirect
		}
		guard let p = path else {
			throw SAuthError(description: "The URI \(key) is not defined.")
		}
		return p
	}
}

try initializeNotifications()

let sauth = SAuth(SAuthConfigProvider())
try sauth.initialize()

let oauthHandlers = OAuthHandlers(SAuthConfigProvider())
let sAuthHandlers = SAuthHandlers(SAuthConfigProvider())

func healthCheck(request: HTTPRequest) throws -> HealthCheckResponse {
	return HealthCheckResponse(health: "OK")
}

var routes = Routes()
routes.add(TRoute(method: .post, uri: "/api/v1/register", handler: sAuthHandlers.register))
routes.add(TRoute(method: .get, uri: "/api/v1/login", handler: sAuthHandlers.login))
routes.add(TRoute(method: .get, uri: "/api/v1/passreset", handler: sAuthHandlers.initiatePasswordReset))
routes.add(TRoute(method: .post, uri: "/api/v1/passreset", handler: sAuthHandlers.completePasswordReset))
routes.add(TRoute(method: .get, uri: "/api/v1/oauth/upgrade/{provider}/{token}", handler: oauthHandlers.oauthLoginHandler))
routes.add(method: .get, uri: "/api/v1/oauth/return/{provider}", handler: oauthHandlers.oauthReturnHandler)

var authRoutes = TRoutes(baseUri: "/api/v1/a/", handler: sAuthHandlers.authenticated)
authRoutes.add(method: .get, uri: "mydata", handler: sAuthHandlers.getMeMeta)
authRoutes.add(method: .post, uri: "mydata", handler: sAuthHandlers.setMeMeta)
authRoutes.add(method: .get, uri: "me", handler: sAuthHandlers.getMe)
authRoutes.add(method: .post, uri: "mobile/add", handler: sAuthHandlers.addMobileDevice)

routes.add(method: .get, uri: "/pwreset/{token}", handler: sAuthHandlers.pwResetWeb)
routes.add(method: .post, uri: "/pwreset/complete", handler: sAuthHandlers.pwResetWebComplete)

routes.add(authRoutes)
routes.add(TRoute(method: .get, uri: "/healthcheck", handler: healthCheck))
routes.add(method: .get, uri: "/api/v1/key") {
	req, resp in
	resp.addHeader(.contentType, value: "text/plain")
	resp.setBody(string: serverPublicKeyStr)
		.completed(status: .ok)
}
func fileNotFound(req: HTTPRequest, resp: HTTPResponse) {
	print("404 " + req.path)
	resp.completed(status: .notFound)
}
routes.add(uri: "/**", handler: fileNotFound)

try HTTPServer.launch(.server(name: globalConfig.server.name, port: globalConfig.server.port, routes: routes))


