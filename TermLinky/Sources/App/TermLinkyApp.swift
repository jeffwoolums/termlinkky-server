//
//  TermLinkkyApp.swift
//  TermLinkky
//
//  Remote terminal access for developers.
//

import SwiftUI

@main
struct TermLinkkyApp: App {
    @StateObject private var connectionManager = ConnectionManager()
    @StateObject private var settingsManager = SettingsManager()
    @StateObject private var pairingManager = PairingManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(connectionManager)
                .environmentObject(settingsManager)
                .environmentObject(pairingManager)
        }
    }
}
