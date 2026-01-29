//
//  TermLinkkyApp.swift
//  TermLinkky
//
//  Server companion app for remote terminal access.
//

import SwiftUI

@main
struct TermLinkkyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, minHeight: 500)
        }
        .windowStyle(.automatic)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Terminal") {
                    NotificationCenter.default.post(name: .newTerminal, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
        
        // Menu bar extra for quick access
        MenuBarExtra("TermLinkky", systemImage: "terminal.fill") {
            MenuBarView()
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure server starts on launch
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false // Keep running in menu bar
    }
}

// MARK: - Menu Bar View

struct MenuBarView: View {
    @StateObject private var serverManager = ServerManager()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Server status
            HStack {
                Circle()
                    .fill(serverManager.isRunning ? .green : .gray)
                    .frame(width: 8, height: 8)
                Text(serverManager.isRunning ? "Server Running" : "Server Stopped")
                    .font(.headline)
            }
            
            if serverManager.isRunning {
                Divider()
                
                // Pairing info
                VStack(alignment: .leading, spacing: 4) {
                    Text("Address")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(serverManager.serverAddress)
                        .font(.system(.body, design: .monospaced))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Pairing Code")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(serverManager.pairingCode)
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundStyle(.green)
                }
                
                Divider()
                
                // Sessions
                Text("\(serverManager.sessions.count) Terminal Sessions")
                    .font(.caption)
                Text("\(serverManager.connectedClients.count) Connected Devices")
                    .font(.caption)
            }
            
            Divider()
            
            // Actions
            Button(serverManager.isRunning ? "Stop Server" : "Start Server") {
                serverManager.toggleServer()
            }
            
            Button("New Terminal") {
                serverManager.openNewTerminal()
            }
            .disabled(!serverManager.isRunning)
            
            Divider()
            
            Button("Open Main Window") {
                NSApplication.shared.activate(ignoringOtherApps: true)
                if let window = NSApplication.shared.windows.first {
                    window.makeKeyAndOrderFront(nil)
                }
            }
            
            Button("Quit") {
                serverManager.stopServer()
                NSApplication.shared.terminate(nil)
            }
        }
        .padding()
        .frame(width: 220)
        .onAppear {
            if !serverManager.isRunning {
                serverManager.startServer()
            }
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let newTerminal = Notification.Name("newTerminal")
}
