//
//  Codables.swift
//  SAuthLib
//
//  Created by Kyle Jessup on 2018-03-22.
//

import Foundation

public struct EmptyReply: Codable {
	public init() {}
}

public struct HealthCheckResponse: Codable {
	public let health: String
	public init(health h: String) {
		health = h
	}
}

public struct AccessToken: Codable {
	public let aliasId: String
	public let provider: String
	public let token: String
	public let expiration: Int?
}

public struct SAuthError: Error, Codable, CustomStringConvertible {
	public let description: String
	public init(description d: String) {
		description = d
	}
}

public enum AuthAPI {
	public struct TokenAcquiredResponse: Codable {
		public let token: String
		public let account: Account?
		public init(token: String, account: Account?) {
			self.token = token
			self.account = account
		}
	}
	
	public struct RegisterRequest: Codable {
		public let email: String
		public let password: String
		public init(email e: String, password p: String) {
			email = e
			password = p
		}
	}
	
	public typealias LoginRequest = RegisterRequest
	
	public struct AddMobileDeviceRequest: Codable {
		public let deviceId: String
		public let deviceType: String
		public init(deviceId: String, deviceType: String) {
			self.deviceId = deviceId
			self.deviceType = deviceType
		}
	}
	
	public struct PasswordResetRequest: Codable {
		public let address: String
		public let deviceId: String?
		public init(address: String, deviceId: String?) {
			self.address = address
			self.deviceId = deviceId
		}
	}
	
	public struct PasswordResetCompleteRequest: Codable {
		public let address: String
		public let password: String
		public let authToken: String
		public init(address: String, password: String, authToken: String) {
			self.address = address
			self.password = password
			self.authToken = authToken
		}
	}
}

public typealias TokenAcquiredResponse = AuthAPI.TokenAcquiredResponse

public struct TokenClaim: Codable {
	enum CodingKeys: String, CodingKey {
		case issuer = "iss", subject = "sub", expiration = "exp",
		issuedAt = "iat", accountId = "accountId",
		oauthProvider = "oauthProvider", oauthAccessToken = "oauthAccessToken"
	}
	public let issuer: String?
	public let subject: String?
	public let expiration: Int?
	public let issuedAt: Int?
	public let accountId: UUID?
	public let oauthProvider: String?
	public let oauthAccessToken: String?
	public init(issuer: String? = nil,
				subject: String? = nil,
				expiration: Int? = nil,
				issuedAt: Int? = nil,
				accountId: UUID? = nil,
				oauthProvider: String? = nil,
				oauthAccessToken: String? = nil) {
		self.issuer = issuer
		self.subject = subject
		self.expiration = expiration
		self.issuedAt = issuedAt
		self.accountId = accountId
		self.oauthProvider = oauthProvider
		self.oauthAccessToken = oauthAccessToken
	}
	
}

public struct AccountPublicMeta: Codable {
	public let fullName: String?
	public init(fullName: String? = nil) {
		self.fullName = fullName
	}
}

public struct Account: Codable {
	public let id: UUID
	public let flags: UInt
	public let createdAt: Int
	public let meta: AccountPublicMeta?
	public init(id: UUID,
				flags: UInt,
				createdAt: Int,
				meta: AccountPublicMeta? = nil) {
		self.id = id
		self.flags = flags
		self.createdAt = createdAt
		self.meta = meta
	}
}

public struct Alias: Codable {
	public let address: String
	public let account: UUID
	public let priority: Int
	public let flags: UInt
	public let pwSalt: String?
	public let pwHash: String?
	public init(address: String,
				account: UUID,
				priority: Int,
				flags: UInt,
				pwSalt: String?,
				pwHash: String?) {
		self.address = address
		self.account = account
		self.priority = priority
		self.flags = flags
		self.pwSalt = pwSalt
		self.pwHash = pwHash
	}
}

public struct AliasBrief: Codable {
	public let address: String
	public let account: UUID
	public let priority: Int
	public let flags: UInt
	public init(address: String,
				account: UUID,
				priority: Int,
				flags: UInt) {
		self.address = address
		self.account = account
		self.priority = priority
		self.flags = flags
	}
}
