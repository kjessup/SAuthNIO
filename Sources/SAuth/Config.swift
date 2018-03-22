//
//  Config.swift
//  SAuth
//
//  Created by Kyle Jessup on 2017-12-18.
//

import Foundation
import PerfectCloudFormation
import PerfectPostgreSQL
import PerfectCRUD
import PerfectCrypto
import PerfectSMTP
import PerfectLib
import SAuthLib

let configDir = "./config/"
let templatesDir = "./templates/"
#if os(macOS) || DEBUG
let configFilePath = "\(configDir)config.dev.json"
#else
let configFilePath = "\(configDir)config.prod.json"
#endif

let sAuthDatabaseName = "sauth"
let sauthNotificationsConfigurationName = "sauth"

struct Config: Codable {
	struct Server: Codable {
		let port: Int
		let name: String
		let privateKeyName: String
		let publicKeyName: String
	}
	struct SMTP: Codable {
		let host: String
		let port: Int
		let user: String
		let password: String
		let fromName: String
		let fromAddress: String
	}
	struct Notifications: Codable {
		let keyName: String
		let keyId: String
		let teamId: String
		let topic: String
		let production: Bool
	}
	struct URIs: Codable {
		let passwordReset: String?
		let oauthRedirect: String?
	}
	struct Database: Codable {
		let host: String
		let port: Int
		let name: String
		let user: String
		let password: String
	}
	struct Templates: Codable {
		let passwordResetForm: String
		let passwordResetOk: String
		let passwordResetError: String
	}
	let server: Server
	let smtp: SMTP?
	let notifications: Notifications?
	let uris: URIs
	var database: Database?
	let templates: Templates?
	
	static func get() throws -> Config {
		let f = File(configFilePath)
		var config = try JSONDecoder().decode(Config.self, from: Data(bytes: Array(f.readString().utf8)))
		if nil == config.database {
			guard let pgsql = CloudFormation.listRDSInstances(type: .postgres)
				.sorted(by: { $0.resourceName < $1.resourceName }).first else {
					throw SAuthError(description: "Database is not configured.")
			}
			config.database = Config.Database(host: pgsql.hostName,
											  port: pgsql.hostPort,
											  name: sAuthDatabaseName,
											  user: pgsql.userName,
											  password: pgsql.password)
		}
		try config.database?.initialize()
		return config
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
		return try PostgresDatabaseConfiguration(database: "postgres", host: host, port: port, username: user, password: password)
	}
	func crud() throws -> Database<PostgresDatabaseConfiguration> {
		return Database(configuration: try configuration())
	}
}
