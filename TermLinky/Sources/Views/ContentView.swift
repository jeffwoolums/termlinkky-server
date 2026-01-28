//
//  ContentView.swift
//  TermLinkky
//
//  Main tab-based navigation.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var connectionManager: ConnectionManager
    @EnvironmentObject var pairingManager: PairingManager
    @State private var selectedTab: Tab = .terminal
    
    enum Tab {
        case terminal
        case devices
        case settings
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            TerminalView()
                .tabItem {
                    Image(systemName: "terminal.fill")
                    Text("Terminal")
                }
                .tag(Tab.terminal)
            
            DevicesView()
                .tabItem {
                    Image(systemName: "laptopcomputer.and.iphone")
                    Text("Devices")
                }
                .tag(Tab.devices)
                .badge(pairingManager.pairedDevices.isEmpty ? "!" : nil)
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .tag(Tab.settings)
        }
        .tint(.green)
        .onAppear {
            // If no paired devices, go to devices tab
            if pairingManager.pairedDevices.isEmpty {
                selectedTab = .devices
            }
        }
    }
}
