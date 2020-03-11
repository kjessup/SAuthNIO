//
//  SAuthRoutes.swift
//
//  Created by Kyle Jessup on 2019-12-02.
//

import Foundation
import PerfectNIO
import SAuthNIOLib
import SAuthCodables
import SAuthConfig
import PerfectCrypto

public typealias FullRoute = Routes<HTTPRequest, HTTPOutput>

public func sauthRoutes<P: SAuthNIOLib.SAuthConfigProvider>(_ sauth: SAuth<P>) throws -> FullRoute {
	let oauthHandlers = OAuthHandlers(sauth.provider)
	let sAuthHandlers = SAuthHandlers(sauth.provider)
	let serverPublicKeyStr = try sauth.provider.getServerPublicKey().publicKeyString!
	let serverPublicKeyJWK = try JWK(key: sauth.provider.getServerPublicKey())
	let serverPublicKeyJWKStr = String(data: try JSONEncoder().encode(serverPublicKeyJWK), encoding: .utf8)
	
	let enable = try Config.get().enable ?? Config.Enable.fromEnv()
	let apiRoutes: FullRoute
	do {
		let apiGetRoutes = try root().GET.dir(type: HTTPOutput.self) {
			$0.login.decode(AuthAPI.LoginRequest.self, sAuthHandlers.login).json()
			$0.passreset.decode(AuthAPI.PasswordResetRequest.self, sAuthHandlers.initiatePasswordReset).json()
		}

		let apiPostRoutes = try root().POST.dir(type: HTTPOutput.self) {
			$0.passreset.decode(AuthAPI.PasswordResetCompleteRequest.self, sAuthHandlers.completePasswordReset).json()
		}
		
		let apiPublicKeyRoutes: FullRoute = try root().GET.dir {
			$0.key {
				TextOutput(serverPublicKeyStr) as HTTPOutput
			}
			$0.jwk {
				_ -> HTTPOutput in
				guard let r = serverPublicKeyJWKStr else {
					throw ErrorOutput(status: .notFound)
				}
				return TextOutput(r,
								  headers: [("Content-Type", "application/json")])
			}
		}
		
		let authenticatedRoutes = try root().a(sAuthHandlers.authenticated).dir(type: HTTPOutput.self) {
			$0.GET.mydata(sAuthHandlers.getMeMeta).json()
			$0.GET.me(sAuthHandlers.getMe).json()
			$0.POST.mobile.add.decode(AuthAPI.AddMobileDeviceRequest.self, sAuthHandlers.addMobileDevice).json()
		}
		
		var routes: [FullRoute] = [
			apiGetRoutes,
			apiPostRoutes,
			apiPublicKeyRoutes,
			authenticatedRoutes]
		
		// Routes that can be disabled
		let userSelfRegistrationRoutes = try root().POST.dir(type: HTTPOutput.self) {
			$0.register.decode(AuthAPI.RegisterRequest.self, sAuthHandlers.register).json()
		}
		
		let userProfileUpdateRoutes = try root().POST.a(sAuthHandlers.authenticated).dir(type: HTTPOutput.self) {
			$0.profile.update.decode(UpdateProfilePicRequest.self, sAuthHandlers.updateProfilePic).json()
			$0.mydata.decode(P.MetaType.self, sAuthHandlers.setMeMeta).json()
		}
		
		let authenticatedAdminRoutes = try root().a(sAuthHandlers.authenticated)
			.statusCheck { $0.account.isAdmin ? .ok : .badRequest }.dir(type: HTTPOutput.self) {
		
			$0.GET.account.list(sAuthHandlers.listAccounts).json()
			$0.POST.account.delete.decode(DeleteAccountRequest.self, sAuthHandlers.deleteAccount).json()
			$0.POST.account.register.decode(AccountRegisterRequest.self, sAuthHandlers.registerUser)
				.map(sAuthHandlers.register).json()			
		}
		
		if enable.userSelfRegistration {
			print("userSelfRegistration true")
			routes.append(userSelfRegistrationRoutes)
		}
		if enable.userProfileUpdate {
			print("userSelfRegistration true")
			routes.append(userProfileUpdateRoutes)
		}
		if enable.adminRoutes {
			print("adminRoutes true")
			routes.append(authenticatedAdminRoutes)
		}
		
		apiRoutes = try root().dir(routes)
	}
	
	let pwResetWebRoutes = try root().pwreset.dir(type: HTTPOutput.self) {
		$0.GET.wild(name: "token").map(sAuthHandlers.pwResetWeb)
		$0.POST.complete.decode(AuthAPI.PasswordResetCompleteRequest.self, sAuthHandlers.pwResetWebComplete)
	}
	
	let accountValidateRoutes = root().GET.validate.wild(name: "token").map(sAuthHandlers.accountValidateWeb)
	
	let doReadyCheck = enable.readinessCheck
	let healthRoutes = try root().GET.health.dir(type: HTTPOutput.self) {
		$0.live { _ -> HTTPOutput in TextOutput("ok") }
		$0.ready {
			_ -> HTTPOutput in
			if doReadyCheck {
				let _ = try Config.get().database?.crud()
			}
			return TextOutput("ok")
		}
	}
	let routes = try root().dir(apiRoutes,
								pwResetWebRoutes,
								accountValidateRoutes,
								healthRoutes)
	return routes
}
