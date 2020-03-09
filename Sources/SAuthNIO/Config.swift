//
//  Config.swift
//  SAuth
//
//  Created by Kyle Jessup on 2017-12-18.
//

import Foundation
import PerfectLib
import SAuthCodables

let configDir = "./config/"
let templatesDir = "./templates/"
#if os(macOS) || DEBUG
let configFilePath = "\(configDir)config.dev.json"
#else
let configFilePath = "\(configDir)config.prod.json"
#endif

fileprivate let env = ProcessInfo.processInfo.environment

struct Config: Codable {
	struct Server: Codable {
		let port: Int
		let name: String
		let privateKeyPath: String?
		let certificateChainPath: String?
		let privateKeyName: String
		let publicKeyName: String
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
	struct URIs: Codable {
		let passwordReset: String?
		let accountValidate: String?
		let oauthRedirect: String?
		let profilePicsFSPath: String?
		let profilePicsWebPath: String?
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
	struct SMTP: Codable {
		let host: String
		let port: Int
		let user: String
		let password: String
		let fromName: String
		let fromAddress: String
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
	struct Notifications: Codable {
		let keyName: String
		let keyId: String
		let teamId: String
		let topic: String
		let production: Bool
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
	struct Database: Codable {
		let host: String
		let port: Int
		let name: String
		let user: String
		let password: String
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
	struct Templates: Codable {
		let passwordResetForm: String
		let passwordResetOk: String
		let passwordResetError: String
		let passwordResetEmail: String?
		let accountValidationEmail: String?
		let accountValidationError: String?
		let accountValidationOk: String?
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
	struct Redis: Codable {
		let host: String
		let port: Int?
		static func fromEnv() -> Redis? {
			guard let redishost = env["redis_host"] else {
					return nil
			}
			let p = env["redis_port"]
			print("\(type(of: self)) from env")
			return Redis(host: redishost, port: p != nil ? Int(p ?? "") : nil)
		}
	}
	struct Enable: Codable {
		let userSelfRegistration: Bool
		let adminRoutes: Bool
		let userProfileUpdate: Bool
		let promptFirstAccount: Bool
		let readinessCheck: Bool
		let onDevicePWReset: Bool
		static func fromEnv() -> Self {
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
	let server: Server
	let uris: URIs
	
	let smtp: SMTP?
	let notifications: Notifications?
	var database: Database?
	let templates: Templates?
	var databaseName: String?
	let redis: Redis?
	var enable: Enable?
	static func get() throws -> Config {
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

