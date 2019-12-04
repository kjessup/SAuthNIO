
import Foundation
import PerfectCloudFormation
import PerfectNIO
import PerfectPostgreSQL
import PerfectCRUD
import PerfectLib
import PerfectCrypto
import PerfectSMTP
import PerfectMustache
import SAuthNIOLib
import SAuthCodables

let globalConfig = try Config.get()
let serverPublicKeyStr = try File("\(configDir)\(globalConfig.server.publicKeyName)").readString()
let serverPublicKey = try PEMKey(source: serverPublicKeyStr)
let serverPrivateKey = try PEMKey(pemPath: "\(configDir)\(globalConfig.server.privateKeyName)")

private extension Config.SMTP {
	func email(subject: String, to: [Recipient], from: Recipient) -> EMail {
		let client = SMTPClient(url: "smtp://\(host):\(port)",
			username: user,
			password: password,
			requiresTLSUpgrade: true)
		let email = EMail(client: client)
		email.connectTimeoutSeconds = 7
		email.subject = subject
		email.to = to
		email.from = from
		return email
	}
}

struct AccountPublicMeta: Codable {
	let fullName: String?
}

extension Account: TableNameProvider {
	public static var tableName: String {
		"account"
	}
}

struct SAuthConfigProvider: SAuthNIOLib.SAuthConfigProvider {
	typealias DBConfig = PostgresDatabaseConfiguration
	
	typealias MetaType = AccountPublicMeta
	
	func sendEmailValidation(authToken: String, account: Account<MetaType>, alias: AliasBrief) throws {
		guard let smtp = globalConfig.smtp else {
			throw SAuthError(description: "SMTP is not configured.")
		}
		guard let uri = globalConfig.uris.accountValidate else {
			throw SAuthError(description: "Account validation is not configured.")
		}
		let address = alias.address
		let email = smtp.email(subject: "Account Validation",
							   to: [.init(address: address)],
							   from: .init(name: smtp.fromName, address: smtp.fromAddress))
		if let emailTemplate = globalConfig.templates?.accountValidationEmail {
			do {
				let map: [String:Any] = ["address":address, "uri":uri, "authToken":authToken]
				let ctx = MustacheEvaluationContext(templatePath: emailTemplate, map: map)
				let collector = MustacheEvaluationOutputCollector()
				email.text = try ctx.formulateResponse(withCollector: collector)
			} catch {
				email.text = plainValidateAccountBody(address: address, uri: uri, authToken: authToken)
			}
		} else {
			email.text = plainValidateAccountBody(address: address, uri: uri, authToken: authToken)
		}
		try email.send()
	}
	
	func sendEmailPasswordReset(authToken: String, account: Account<MetaType>, alias: AliasBrief) throws {
		guard let smtp = globalConfig.smtp else {
			throw SAuthError(description: "SMTP is not configured.")
		}
		guard let uri = globalConfig.uris.passwordReset else {
			throw SAuthError(description: "Password reset is not configured.")
		}
		let fullName = account.meta?.fullName ?? ""
		let email = smtp.email(subject: "Password Reset",
							   to: [.init(name: fullName, address: alias.address)],
							   from: .init(name: smtp.fromName, address: smtp.fromAddress))
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
	
	func plainValidateAccountBody(address: String, uri: String, authToken: String) -> String {
		return """
		Hello, an account was created for this address "\(address)". Follow this link to validate your account:
		\(uri)/\(authToken)
		
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
		case .passwordResetEmail:
			path = globalConfig.templates?.passwordResetEmail
		case .accountValidationEmail:
			path = globalConfig.templates?.accountValidationEmail
		case .accountValidationError:
			path = globalConfig.templates?.accountValidationError
		case .accountValidationOk:
			path = globalConfig.templates?.accountValidationOk
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
		case .passwordReset:
			path = globalConfig.uris.passwordReset
		case .accountValidate:
			path = globalConfig.uris.accountValidate
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

let apiRoutes: Routes<HTTPRequest, HTTPOutput>
do {
	let apiGetRoutes = try root().GET.dir{[
		
		$0.login.decode(AuthAPI.LoginRequest.self, sAuthHandlers.login).json(),
		$0.passreset.decode(AuthAPI.PasswordResetRequest.self, sAuthHandlers.initiatePasswordReset).json()
		
		] as [Routes<HTTPRequest, HTTPOutput>]}

	let apiPostRoutes = try root().POST.dir{[
		
		$0.register.decode(AuthAPI.RegisterRequest.self, sAuthHandlers.register).json(),
		$0.passreset.decode(AuthAPI.PasswordResetCompleteRequest.self, sAuthHandlers.completePasswordReset).json()
		
		] as [Routes<HTTPRequest, HTTPOutput>]}

	let apiOAuthRoutes = try root().GET.oauth.dir{[
		
		$0.upgrade.wild(name: "provider").wild(name: "token").decode(OAuthProviderAndToken.self, oauthHandlers.oauthLoginHandler).json(),
		$0.return.wild(name: "provider").decode(AuthAPI.PasswordResetCompleteRequest.self, sAuthHandlers.completePasswordReset).json()
		
		] as [Routes<HTTPRequest, HTTPOutput>]}

	let apiPublicKeyRoutes: Routes<HTTPRequest, HTTPOutput> = root().key { return TextOutput(serverPublicKeyStr) }

	let authenticatedRoutes = try root().a(sAuthHandlers.authenticated).dir{[
		
		$0.GET.mydata(sAuthHandlers.getMeMeta).json(),
		$0.POST.mydata.decode(AccountPublicMeta.self, sAuthHandlers.setMeMeta).json(),
		$0.GET.me(sAuthHandlers.getMe).json(),
		$0.POST.mobile.add.decode(AuthAPI.AddMobileDeviceRequest.self, sAuthHandlers.addMobileDevice).json()
		
		] as [Routes<AuthenticatedRequest, HTTPOutput>]}

	apiRoutes = try root().api.v1.dir(apiGetRoutes, apiPostRoutes, apiOAuthRoutes, apiPublicKeyRoutes, authenticatedRoutes)
}
let pwResetWebRoutes = try root().pwreset.dir{[
	
	$0.GET.wild(name: "token").map(sAuthHandlers.pwResetWeb),
	$0.POST.complete.decode(AuthAPI.PasswordResetCompleteRequest.self, sAuthHandlers.pwResetWebComplete)
	
	] as [Routes<HTTPRequest, HTTPOutput>]}

let accountValidateRoutes = root().validate.wild(name: "token").map(sAuthHandlers.accountValidateWeb) as Routes<HTTPRequest, HTTPOutput>

let healthCheckRoutes = root().healthcheck(healthCheck).json()

let routes = try root().dir(apiRoutes, pwResetWebRoutes, accountValidateRoutes, healthCheckRoutes)



try routes.bind(port: globalConfig.server.port).listen().wait()


//var routes = Routes()
//routes.add(TRoute(method: .post, uri: "/api/v1/register", handler: sAuthHandlers.register))
//routes.add(TRoute(method: .get, uri: "/api/v1/login", handler: sAuthHandlers.login))
//routes.add(TRoute(method: .get, uri: "/api/v1/passreset", handler: sAuthHandlers.initiatePasswordReset))
//routes.add(TRoute(method: .post, uri: "/api/v1/passreset", handler: sAuthHandlers.completePasswordReset))

//routes.add(TRoute(method: .get, uri: "/api/v1/oauth/upgrade/{provider}/{token}", handler: oauthHandlers.oauthLoginHandler))
//routes.add(method: .get, uri: "/api/v1/oauth/return/{provider}", handler: oauthHandlers.oauthReturnHandler)
//
//var authRoutes = TRoutes(baseUri: "/api/v1/a/", handler: sAuthHandlers.authenticated)
//authRoutes.add(method: .get, uri: "mydata", handler: sAuthHandlers.getMeMeta)
//authRoutes.add(method: .post, uri: "mydata", handler: sAuthHandlers.setMeMeta)
//authRoutes.add(method: .get, uri: "me", handler: sAuthHandlers.getMe)
//authRoutes.add(method: .post, uri: "mobile/add", handler: sAuthHandlers.addMobileDevice)
//
//routes.add(method: .get, uri: "/pwreset/{token}", handler: sAuthHandlers.pwResetWeb)
//routes.add(method: .post, uri: "/pwreset/complete", handler: sAuthHandlers.pwResetWebComplete)
//
//routes.add(method: .get, uri: "/validate/{token}", handler: sAuthHandlers.accountValidateWeb)
//
//routes.add(authRoutes)
//routes.add(TRoute(method: .get, uri: "/healthcheck", handler: healthCheck))
//routes.add(method: .get, uri: "/api/v1/key") {
//	req, resp in
//	resp.addHeader(.contentType, value: "text/plain")
//	resp.setBody(string: serverPublicKeyStr)
//		.completed(status: .ok)
//}
//func fileNotFound(req: HTTPRequest, resp: HTTPResponse) {
//	print("404 " + req.path)
//	resp.completed(status: .notFound)
//}
//routes.add(uri: "/**", handler: fileNotFound)
//
//try HTTPServer.launch(.server(name: globalConfig.server.name, port: globalConfig.server.port, routes: routes))

