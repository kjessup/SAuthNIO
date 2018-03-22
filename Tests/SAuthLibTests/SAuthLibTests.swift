
import XCTest
import Foundation
import PerfectCRUD
import PerfectCrypto
import PerfectPostgreSQL
import SwiftCodables
@testable import SAuthLib

let postgresTestDBName = "testing123"
let postgresInitConnInfo = "host=localhost dbname=postgres"
let postgresTestConnInfo = "host=localhost dbname=testing123"

let privKeyString = """
-----BEGIN RSA PRIVATE KEY-----
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
-----END RSA PRIVATE KEY-----
"""

let pubKeyString = """
-----BEGIN PUBLIC KEY-----
MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAxSE9N9xbtnP+KyCPS9VD
McEoSIS9BMGK7r4p+GisR5z9Y5MA3w7U4PRnp6hwqNvoAKuEmMHsJ/ebh1PFZjzK
6okbi4TFWoB4G3N7nNNa+ZeuS7vIpCXdsDciLSCxHvqyV1BrHtyUvoZHFgcrIx4L
J4lt5/Q9pi1C6mDkUvA0nzA+oYb0mLRkKIRCQfTkM6UMhEfCTecbgoCML0dKRoEM
G/KmTXV53q2IWaLmvTmxOD34HU8VWkN27JcNc/RSjUYmgxyPwZZ4lMtLWfo8bx6c
V43OY0vYofvoqTiLluP5hrtk9hotT2z6kUfSplYPS34oBSuq6HxbMDqSBxCUxBE1
7vFFcxPTjedg1muSfneplu+TT2fcTdMAaVW4wf9E+nTNf0EsfweS5AD75KWz3FxY
LLRAFyoAJ19wFNzKVkMjzpK30g/rMKnIEXH1WaqAPBbhG4b9AWXFp7F7himQb61o
pgboMxAQVA+8k/HUMgwsZuYiSUtpvTZMBx21c6CRlPpi3PVchjhRLVKCTU0fBX3m
t+zDu6qg916F/yZKn0EiWluCeajD8nYZzQHdkGPT5Jv1VSPhVxfjA3l9U7m8F3TT
hORLXx/oFmkXQ8YZB41hKZn828bfBwJxIqeb5PEXKB4zfxWlszvPZ5nYlmKeF+Tx
0S0U39qpwRUYXynmgBAhv6kCAwEAAQ==
-----END PUBLIC KEY-----
"""

struct SAuthTestDBProvider: SAuthConfigProvider {
	func getDB() throws -> Database<PostgresDatabaseConfiguration> {
		return Database(configuration: try PostgresDatabaseConfiguration(postgresTestConnInfo))
	}
	func getServerPrivateKey() throws -> PEMKey {
		return try PEMKey(source: privKeyString)
	}
	func getServerPublicKey() throws -> PEMKey {
		return try PEMKey(source: pubKeyString)
	}
}

class SAuthLibTests: XCTestCase {
	
	override func setUp() {
		super.setUp()
	}
	
	func testSAuth() {
		let un = "badthing@gmail.com"
		let pw = "wqo[kdowqk"
		let un2 = "b.adthing@gmail.com"
		let pw2 = "23oihfqoih"
		let un3 = "ba.dthing@gmail.com"
		do {
			let s = SAuth(SAuthTestDBProvider())
			try s.initialize()
			
			let token = try s.createAccount(address: un, password: pw)
			let alias = try s.validateToken(token.token)
			
			let token2 = try s.logIn(address: un, password: pw)
			let alias1 = try s.validateToken(token2.token)
			XCTAssertEqual(alias.account, alias1.account)
			
			do {
				let newToken = try s.addAlias(token: token.token, address: un2, password: pw2)
				let newAlias = try s.validateToken(newToken.token)
				XCTAssertEqual(alias.account, newAlias.account)
				let token3 = try s.logIn(address: un2, password: pw2)
				let alias2 = try s.validateToken(token3.token)
				XCTAssertEqual(alias.account, alias2.account)
				
				let aliases = try s.listAliases(token: token.token)
				XCTAssertEqual(2, aliases.count)
			}
			do {
				try s.removeAlias(token: token.token, address: un2)
				do {
					_ = try s.logIn(address: un2, password: pw2)
					XCTFail("Should not have logged in")
				} catch {}
				let aliases = try s.listAliases(token: token.token)
				XCTAssertEqual(1, aliases.count)
			}
			
			do {
				let seta = AccountPublicMeta(fullName: "John Doe")
				try s.setMeta(token: token.token, meta: seta)
				let geta = try s.getMeta(token: token.token, for: alias.account)
				XCTAssertEqual(geta?.fullName, seta.fullName)
			}
			
			do {
				let fakeProvider = "FooBar"
				let fakeAccessToken = UUID().uuidString
				let meta = AccountPublicMeta(fullName: "Full Name")
				let token11 = try s.createAccount(provider: fakeProvider, accessToken: fakeAccessToken, address: un3, meta: meta)
				_ = try s.validateToken(token11.token)
				let token22 = try s.logIn(provider: fakeProvider, accessToken: fakeAccessToken, address: un3)
				_ = try s.validateToken(token22.token)
			}
			
			do {
				let fakeProvider = "FooBar"
				let fakeAccessToken = UUID().uuidString
				let token22 = try s.logIn(provider: fakeProvider, accessToken: fakeAccessToken, address: un)
				let alias22 = try s.validateToken(token22.token)
				XCTAssertEqual(alias22.account, alias.account)
			}
			
			
		} catch {
			XCTFail("\(error)")
		}
	}

    static var allTests: [(String, (SAuthLibTests) -> () throws -> Void)] {
        return [
			("testSAuth", testSAuth)
        ]
    }
}
