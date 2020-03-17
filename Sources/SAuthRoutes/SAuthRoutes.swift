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

	//	routes.add(TRoute(method: .get, uri: "/api/v1/oauth/upgrade/{provider}/{token}", handler: oauthHandlers.oauthLoginHandler))
	//	routes.add(method: .get, uri: "/api/v1/oauth/return/{provider}", handler: oauthHandlers.oauthReturnHandler)
	let oauthRoutes = try root().GET.oauth.dir(type: HTTPOutput.self) {
		$0.upgrade
			.wild { $1 }
			.wild(OAuthProviderAndToken.init).map(oauthHandlers.oauthLoginHandler).json()
		$0.return
			.wild(name: "provider").map(oauthHandlers.oauthReturnHandler)
	}
	
	let sAuthHandlers = SAuthHandlers(sauth.provider)
	let serverPublicKeyStr = try sauth.provider.getServerPublicKey().publicKeyString!
	let serverPublicKeyJWK = try JWK(key: sauth.provider.getServerPublicKey())
	let serverPublicKeyJWKStr = String(data: try JSONEncoder().encode(serverPublicKeyJWK), encoding: .utf8)
	
	let enable = Config.globalConfig.enable
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
			$0.POST.account.register.decode(AccountRegisterRequest.self, sAuthHandlers.registerUser).json()			
		}
		
		let firstAccountRoutes = try root().initSAuth.statusCheck {
			let db = try sauth.provider.getDB()
			guard try db.table(Account<P.MetaType>.self).count() == 0 else {
				return .notFound
			}
			return .ok
		}.dir(type: HTTPOutput.self) {
			$0.GET.map {
				_ -> HTTPOutput in
				guard let tempForm = try? sauth.provider.getTemplatePath(.sauthInitForm) else {
					return ErrorOutput(status: .badRequest, description: "Templates not configured.")
				}
				return try MustacheOutput(templatePath: tempForm, inputs: [:], contentType: "text/html")
			}
			$0.POST.decode(AccountRegisterRequest.self, sAuthHandlers.initSAuth).json()
		}
		
		if enable?.userSelfRegistration ?? true {
			print("userSelfRegistration true")
			routes.append(userSelfRegistrationRoutes)
		}
		if enable?.userProfileUpdate ?? true {
			print("userSelfRegistration true")
			routes.append(userProfileUpdateRoutes)
		}
		if enable?.adminRoutes ?? false {
			print("adminRoutes true")
			routes.append(authenticatedAdminRoutes)
		}
		if enable?.oauthRoutes ?? true {
			print("oauthRoutes true")
			routes.append(oauthRoutes)
		}
		if enable?.promptFirstAccount ?? true {
			print("promptFirstAccount true")
			routes.append(firstAccountRoutes)
		}
		apiRoutes = try root().dir(routes)
	}
	
	let pwResetWebRoutes = try root().pwreset.dir(type: HTTPOutput.self) {
		$0.GET.wild(name: "token").map(sAuthHandlers.pwResetWeb)
		$0.POST.complete.decode(AuthAPI.PasswordResetCompleteRequest.self, sAuthHandlers.pwResetWebComplete)
	}
	
	let accountValidateRoutes = root().GET.validate.wild(name: "token").map(sAuthHandlers.accountValidateWeb)
	
	let doReadyCheck = enable?.readinessCheck ?? false
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
