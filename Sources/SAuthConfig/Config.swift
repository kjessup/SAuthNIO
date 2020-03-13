//
//  Config.swift
//  SAuth
//
//  Created by Kyle Jessup on 2017-12-18.
//

import Foundation
import PerfectLib
import SAuthNIOLib
import SAuthCodables
import PerfectCrypto

public let configDir = "./config/"
public let templatesDir = "./templates/"
#if os(macOS) || DEBUG
let configFilePath = "\(configDir)config.dev.json"
#else
let configFilePath = "\(configDir)config.prod.json"
#endif

public func initializeConfig() throws {
	let f = File(configFilePath)
	let config: Config
	if f.exists {
		config = try Config.get(from: f)
	} else {
		config = try Config.get()
	}
	Config.globalConfig = config
}
