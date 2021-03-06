//
//  SAuthConfig.swift
//
//  Created by Kyle Jessup on 2019-12-02.
//

import SAuthNIOLib
import SAuthCodables
import PerfectCRUD
import PerfectSMTP
import PerfectMustache
import PerfectPostgreSQL
import PerfectCrypto
import PerfectLib
import PerfectMIME
import PerfectNIO
import Foundation
import struct Foundation.UUID

let sauthNotificationsConfigurationName = "sauth"

public struct AccountMetaData: Codable {
	public var fullName: String? = nil
	// ...
	public init() {}
}

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

extension Config.Database {
	func initialize() throws {
		let postgresConfig = try PostgresDatabaseConfiguration(database: "postgres", host: host, port: port, username: user, password: password)
		let db = Database(configuration: postgresConfig)
		struct PGDatabase: Codable, TableNameProvider {
			static var tableName = "pg_database"
			let datname: String
		}
		let count = try db.table(PGDatabase.self).where(\PGDatabase.datname == name).count()
		if count == 0 {
			try db.sql("CREATE DATABASE \(name)")
		}
	}
	func configuration() throws -> PostgresDatabaseConfiguration {
		return try PostgresDatabaseConfiguration(database: name, host: host, port: port, username: user, password: password)
	}
	public func crud() throws -> Database<PostgresDatabaseConfiguration> {
		return Database(configuration: try configuration())
	}
}

extension Account: TableNameProvider {
	public static var tableName: String {
		"account"
	}
}

extension Account {
	var isAdmin: Bool { return 0 != (flags & sauthAdminFlag) }
}

// !FIX! config
let tokenExpirationSeconds = 31536000

open class SAuthConfigProvider: SAuthNIOLib.SAuthConfigProvider {
	
	public typealias DBConfig = PostgresDatabaseConfiguration
	public typealias MetaType = AccountMetaData
	
	public init() {
		
	}
	
	open func created(account: Account<AccountMetaData>, alias: AliasBrief) {
		//nop
	}

	open func makeClaim(_ address: String, accountId: UUID?) -> TokenClaim {
		var roles = ["user"]
		do {
			let db = try getDB()
			if let accountId = accountId,
				let account = try db.table(Account<MetaType>.self).where(\Account<MetaType>.id == accountId).first() {
				if account.isAdmin {
					roles.append("admin")
				}
			}
		} catch {
			
		}
		let now = Date().sauthTimeInterval
		let extra: [String:Any] = [
			"https://hasura.io/jwt/claims": [
			  "x-hasura-allowed-roles": roles,
			  "x-hasura-default-role": "user",
			  "x-hasura-user-id": accountId?.uuidString ?? address
			]
		]
		return TokenClaim(issuer: "sauth",
						   subject: address,
						   expiration: now + tokenExpirationSeconds,
						   issuedAt: now,
						   accountId: accountId,
						   extra: extra)
	}
	
	open func sendEmailValidation(authToken: String, account: Account<MetaType>, alias: AliasBrief) throws {
		guard let smtp = Config.globalConfig.smtp else {
			throw SAuthError(description: "SMTP is not configured.")
		}
		guard let uri = Config.globalConfig.uris.accountValidate else {
			throw SAuthError(description: "Account validation is not configured.")
		}
		let address = alias.address
		let email = smtp.email(subject: "Account Validation",
							   to: [.init(address: address)],
							   from: .init(name: smtp.fromName, address: smtp.fromAddress))
		if let emailTemplate = Config.globalConfig.templates?.accountValidationEmail {
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
	
	open func sendEmailPasswordReset(authToken: String, account: Account<MetaType>, alias: AliasBrief) throws {
		guard let smtp = Config.globalConfig.smtp else {
			throw SAuthError(description: "SMTP is not configured.")
		}
		guard let uri = Config.globalConfig.uris.passwordReset else {
			throw SAuthError(description: "Password reset is not configured.")
		}
		let email = smtp.email(subject: "Password Reset",
							   to: [.init(address: alias.address)],
							   from: .init(name: smtp.fromName, address: smtp.fromAddress))
		if let emailTemplate = Config.globalConfig.templates?.passwordResetEmail {
			do {
				let map: [String:Any] = ["fullName":alias.address, "uri":uri, "authToken":authToken]
				let ctx = MustacheEvaluationContext(templatePath: emailTemplate, map: map)
				let collector = MustacheEvaluationOutputCollector()
				email.text = try ctx.formulateResponse(withCollector: collector)
			} catch {
				email.text = plainResetEmailBody(fullName: alias.address, uri: uri, authToken: authToken)
			}
		} else {
			email.text = plainResetEmailBody(fullName: alias.address, uri: uri, authToken: authToken)
		}
		try email.send()
	}
	
	open func plainResetEmailBody(fullName: String, uri: String, authToken: String) -> String {
		return """
		Hello, \(fullName). Here is your requested password reset link:
		\(uri)/\(authToken)
		
		This link will expire in fifteen minutes.
		
		Sincerely,
		Authentication Server
		"""
	}
	
	open func plainValidateAccountBody(address: String, uri: String, authToken: String) -> String {
		return """
		Hello, an account was created for this address "\(address)". Follow this link to validate your account:
		\(uri)/\(authToken)
		
		Sincerely,
		Authentication Server
		"""
	}
	
	open func getDB() throws -> Database<PostgresDatabaseConfiguration> {
		guard let db = try Config.globalConfig.database?.crud() else {
			throw SAuthError(description: "Database is not configured.")
		}
		return db
	}
	open func getServerPublicKey() throws -> PEMKey {
		return Config.globalConfig.server.serverPublicKey
	}
	open func getServerPrivateKey() throws -> PEMKey {
		return Config.globalConfig.server.serverPrivateKey
	}
	open func getPushConfigurationName(forType: String) throws -> String {
		guard let _ = Config.globalConfig.notifications else {
			throw SAuthError(description: "iOS notifications are not configured.")
		}
		return sauthNotificationsConfigurationName
	}
	open func getPushConfigurationTopic(forType: String) throws -> String {
		guard let topic = Config.globalConfig.notifications?.topic else {
			throw SAuthError(description: "iOS notifications are not configured.")
		}
		return topic
	}
	
	open func getTemplatePath(_ key: TemplateKey) throws -> String {
		var path: String?
		switch key {
		case .passwordResetForm:
			path = Config.globalConfig.templates?.passwordResetForm
		case .passwordResetOk:
			path = Config.globalConfig.templates?.passwordResetOk
		case .passwordResetError:
			path = Config.globalConfig.templates?.passwordResetError
		case .passwordResetEmail:
			path = Config.globalConfig.templates?.passwordResetEmail
		case .accountValidationEmail:
			path = Config.globalConfig.templates?.accountValidationEmail
		case .accountValidationError:
			path = Config.globalConfig.templates?.accountValidationError
		case .accountValidationOk:
			path = Config.globalConfig.templates?.accountValidationOk
		case .sauthInitForm:
			path = Config.globalConfig.templates?.sauthInitForm
		}
		guard let p = path else {
			throw SAuthError(description: "The template \(key) is not defined.")
		}
		return "\(templatesDir)\(p)"
	}
	
	open func getURI(_ key: URIKey) throws -> String {
		var path: String?
		switch key {
		case .oauthRedirect:
			path = Config.globalConfig.uris.oauthRedirect
		case .passwordReset:
			path = Config.globalConfig.uris.passwordReset
		case .accountValidate:
			path = Config.globalConfig.uris.accountValidate
		case .profilePicsFSPath:
			path = Config.globalConfig.uris.profilePicsFSPath
		case .profilePicsWebPath:
			path = Config.globalConfig.uris.profilePicsWebPath
		}
		guard let p = path else {
			throw SAuthError(description: "The URI \(key) is not defined.")
		}
		return p
	}
	open func metaFrom(request: AccountRegisterRequest) -> MetaType? {
		var meta = AccountMetaData()
		meta.fullName = request.fullName
		return meta
	}
}
