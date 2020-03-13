//
//  Notifications.swift
//  SAuth
//
//  Created by Kyle Jessup on 2018-02-28.
//

import Foundation
import PerfectNotifications
import SAuthNIOLib
import SAuthConfig

func initializeNotifications() throws {
	guard let notifications = Config.globalConfig.notifications else {
		return
	}
	NotificationPusher.addConfigurationAPNS(
		name: "Prod",
		production: true,
		keyId: notifications.keyId,
		teamId: notifications.teamId,
		privateKeyPath: "\(configDir)\(notifications.keyName)")
	NotificationPusher.addConfigurationAPNS(
		name: "Dev",
		production: false,
		keyId: notifications.keyId,
		teamId: notifications.teamId,
		privateKeyPath: "\(configDir)\(notifications.keyName)")
}
