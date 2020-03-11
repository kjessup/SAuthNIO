//
//  Config.swift
//  SAuth
//
//  Created by Kyle Jessup on 2017-12-18.
//

import Foundation
import PerfectLib
import SAuthCodables
import PerfectCrypto

public let configDir = "./config/"
public let templatesDir = "./templates/"
#if os(macOS) || DEBUG
let configFilePath = "\(configDir)config.dev.json"
#else
let configFilePath = "\(configDir)config.prod.json"
#endif

fileprivate let env = ProcessInfo.processInfo.environment

public struct Config: Codable {
	public struct Server: Codable {
		public let port: Int
		public let name: String
		public let privateKeyPath: String?
		public let certificateChainPath: String?
		public let privateKeyName: String
		public let publicKeyName: String
		
		public var serverPrivateKey: PEMKey { try! PEMKey(pemPath: "\(privateKeyName)") }
		public var serverPublicKeyStr: String { try! File("\(publicKeyName)").readString() }
		public var serverPublicKey: PEMKey { try! PEMKey(source: serverPublicKeyStr) }
		public var serverPublicKeyJWK: JWK { try! JWK(key: serverPublicKey) }
		public var serverPublicKeyJWKStr: String { String(data: try! JSONEncoder().encode(serverPublicKeyJWK), encoding: .utf8)! }
		
		static func fromEnv() throws -> Self {
			guard let serverports = env["server_port"],
				let serverport = Int(serverports),
				let servername = env["server_name"],
				let serverprivateKeyName = env["server_privateKeyName"],
				let serverpublicKeyName = env["server_publicKeyName"] else {
					throw SAuthError(description: "Invalid keys for Server. \(env)")
			}
			print("\(type(of: self)) from env")
			return Server(port: serverport, name: servername,
							privateKeyPath: env["server_privateKeyPath"] ?? nil,
							certificateChainPath: env["server_certificateChainPath"] ?? nil,
							privateKeyName: serverprivateKeyName,
							publicKeyName: serverpublicKeyName)
		}
	}
	public struct URIs: Codable {
		public let passwordReset: String?
		public let accountValidate: String?
		public let oauthRedirect: String?
		public let profilePicsFSPath: String?
		public let profilePicsWebPath: String?
		static func fromEnv() throws -> Self {
			guard let urisPasswordReset = env["uris_passwordReset"],
				let urisAccountValidate = env["uris_accountValidate"],
				let urisOauthRedirect = env["uris_oauthRedirect"],
				let urisProfilePicsFSPath = env["uris_profilePicsFSPath"],
				let urisProfilePicsWebPath = env["uris_profilePicsWebPath"] else {
					throw SAuthError(description: "Invalid keys for URIs.")
			}
			print("\(type(of: self)) from env")
			return URIs(passwordReset: urisPasswordReset, accountValidate: urisAccountValidate,
						oauthRedirect: urisOauthRedirect, profilePicsFSPath: urisProfilePicsFSPath,
						profilePicsWebPath: urisProfilePicsWebPath)
		}
	}
	public struct SMTP: Codable {
		public let host: String
		public let port: Int
		public let user: String
		public let password: String
		public let fromName: String
		public let fromAddress: String
		static func fromEnv() -> SMTP? {
			guard let smtphost = env["smtp_host"],
				let smtpports = env["smtp_port"],
				let smtpport = Int(smtpports),
				let smtpuser = env["smtp_user"],
				let smtppassword = env["smtp_password"],
				let smtpfromName = env["smtp_fromName"],
				let smtpfromAddress = env["smtp_fromAddress"] else {
					return nil
			}
			print("\(type(of: self)) from env")
			return SMTP(host: smtphost, port: smtpport,
						 user: smtpuser, password: smtppassword,
						 fromName: smtpfromName, fromAddress: smtpfromAddress)
		}
	}
	public struct Notifications: Codable {
		public let keyName: String
		public let keyId: String
		public let teamId: String
		public let topic: String
		public let production: Bool
		static func fromEnv() -> Notifications? {
			guard let notificationskeyName = env["notifications_keyName"],
				let notificationskeyId = env["notifications_keyId"],
				let notificationsteamId = env["notifications_teamId"],
				let notificationstopic = env["notifications_topic"],
				let notificationsproduction = Bool(env["notifications_production"] ?? "false") else {
					return nil
			}
			print("\(type(of: self)) from env")
			return Notifications(keyName: notificationskeyName, keyId: notificationskeyId,
								 teamId: notificationsteamId, topic: notificationstopic,
								 production: notificationsproduction)
		}
	}
	public struct Database: Codable {
		public let host: String
		public let port: Int
		public let name: String
		public let user: String
		public let password: String
		static func fromEnv() -> Database? {
			guard let databaseports = env["database_port"],
				let databaseport = Int(databaseports),
				let databasename = env["database_name"],
				let databaseuser = env["database_user"],
				let databasepassword = env["database_password"],
				let databasehost = env["database_host"] else {
					return nil
			}
			print("\(type(of: self)) from env")
			return Database(host: databasehost, port: databaseport,
							name: databasename, user: databaseuser,
							password: databasepassword)
		}
	}
	public struct Templates: Codable {
		public let passwordResetForm: String
		public let passwordResetOk: String
		public let passwordResetError: String
		public let passwordResetEmail: String?
		public let accountValidationEmail: String?
		public let accountValidationError: String?
		public let accountValidationOk: String?
		static func fromEnv() -> Templates? {
			guard let templatespasswordResetForm = env["templates_passwordResetForm"],
				let templatespasswordResetOk = env["templates_passwordResetOk"],
				let templatespasswordResetError = env["templates_passwordResetError"] else {
					return nil
			}
			print("\(type(of: self)) from env")
			return Templates(passwordResetForm: templatespasswordResetForm,
							 passwordResetOk: templatespasswordResetOk,
							 passwordResetError: templatespasswordResetError,
							 passwordResetEmail: env["templates_passwordResetEmail"],
							 accountValidationEmail: env["templates_accountValidationEmail"],
							 accountValidationError: env["templates_accountValidationError"],
							 accountValidationOk: env["templates_accountValidationOk"])
		}
	}
	public struct Redis: Codable {
		public let host: String
		public let port: Int?
		static func fromEnv() -> Redis? {
			guard let redishost = env["redis_host"] else {
					return nil
			}
			let p = env["redis_port"]
			print("\(type(of: self)) from env")
			return Redis(host: redishost, port: p != nil ? Int(p ?? "") : nil)
		}
	}
	public struct Enable: Codable {
		public let userSelfRegistration: Bool
		public let adminRoutes: Bool
		public let userProfileUpdate: Bool
		public let promptFirstAccount: Bool
		public let readinessCheck: Bool
		public let onDevicePWReset: Bool
		public static func fromEnv() -> Self {
			let userSelfRegistration = Bool(env["enable_userSelfRegistration"] ?? "true") ?? false
			let adminRoutes = Bool(env["enable_adminRoutes"] ?? "true") ?? false
			let userProfileUpdate = Bool(env["enable_userProfileUpdate"] ?? "true") ?? false
			let promptFirstAccount = Bool(env["enable_promptFirstAccount"] ?? "true") ?? false
			let readinessCheck = Bool(env["enable_readinessCheck"] ?? "true") ?? false
			
			// !FIX! not implimented. not checked in sauthlib
			let onDevicePWReset = Bool(env["enable_onDevicePWReset"] ?? "false") ?? false
			
			print("\(type(of: self)) from env")
			return Enable(userSelfRegistration: userSelfRegistration,
						  adminRoutes: adminRoutes,
						  userProfileUpdate: userProfileUpdate,
						  promptFirstAccount: promptFirstAccount,
						  readinessCheck: readinessCheck,
						  onDevicePWReset: onDevicePWReset)
		}
	}
	public let server: Server
	public let uris: URIs
	
	public let smtp: SMTP?
	public let notifications: Notifications?
	public var database: Database?
	public let templates: Templates?
	public let redis: Redis?
	public var enable: Enable?
	
	public static func get() throws -> Config {
		do {
			let f = File(configFilePath)
			var config = try JSONDecoder().decode(Config.self, from: Data(Array(f.readString().utf8)))
			try config.database?.initialize()
			if nil == config.enable {
				config.enable = Enable.fromEnv()
			}
			return config
		} catch {
			let server = try Server.fromEnv()
			let uris = try URIs.fromEnv()
			let smtp = SMTP.fromEnv()
			let notifications = Notifications.fromEnv()
			let database = Database.fromEnv()
			let templates = Templates.fromEnv()
			let redis = Redis.fromEnv()
			let enable = Enable.fromEnv()
			return Config(server: server,
						  uris: uris, smtp: smtp,
						  notifications: notifications,
						  database: database,
						  templates: templates,
						  redis: redis,
						  enable: enable)
		}
	}
}

