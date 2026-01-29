//
//  ServerManager.swift
//  TermLinkky
//
//  Manages the TermLinkky server, terminal sessions, and connected clients.
//

import Foundation
import SwiftUI
import AppKit

// MARK: - Models

struct TerminalSession: Identifiable, Hashable {
    let id: String
    var name: String
    var tmuxSession: String
    var hasActivity: Bool = false
    var lastOutput: String = ""
    var createdAt: Date = Date()
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: TerminalSession, rhs: TerminalSession) -> Bool {
        lhs.id == rhs.id
    }
}

struct ConnectedClient: Identifiable {
    let id: String
    var name: String
    var ipAddress: String
    var isPhone: Bool
    var connectedAt: Date
}

// MARK: - Server Manager

@MainActor
class ServerManager: ObservableObject {
    @Published var isRunning = false
    @Published var serverAddress = ""
    @Published var pairingCode = "------"
    @Published var sessions: [TerminalSession] = []
    @Published var connectedClients: [ConnectedClient] = []
    @Published var selectedSession: TerminalSession?
    
    private var serverProcess: Process?
    private var refreshTimer: Timer?
    
    init() {
        // Initial state
    }
    
    // MARK: - Server Control
    
    func startServer() {
        guard !isRunning else { return }
        
        // Start the Python server
        let serverPath = findServerPath()
        guard let path = serverPath else {
            print("Server not found")
            return
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["python3", path]
        process.currentDirectoryURL = URL(fileURLWithPath: path).deletingLastPathComponent()
        
        do {
            try process.run()
            serverProcess = process
            isRunning = true
            
            // Get server info
            updateServerInfo()
            
            // Start refresh timer
            refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.refreshState()
                }
            }
            
        } catch {
            print("Failed to start server: \(error)")
        }
    }
    
    func stopServer() {
        serverProcess?.terminate()
        serverProcess = nil
        isRunning = false
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    func toggleServer() {
        if isRunning {
            stopServer()
        } else {
            startServer()
        }
    }
    
    // MARK: - Terminal Sessions
    
    func openNewTerminal() {
        let sessionName = "tl-\(Int(Date().timeIntervalSince1970) % 10000)"
        
        // Create tmux session
        let createTmux = Process()
        createTmux.executableURL = URL(fileURLWithPath: "/usr/bin/tmux")
        createTmux.arguments = ["new-session", "-d", "-s", sessionName]
        try? createTmux.run()
        createTmux.waitUntilExit()
        
        // Open Terminal.app and attach to the tmux session
        let script = """
        tell application "Terminal"
            activate
            do script "tmux attach-session -t \(sessionName)"
        end tell
        """
        
        let appleScript = NSAppleScript(source: script)
        var error: NSDictionary?
        appleScript?.executeAndReturnError(&error)
        
        if let error = error {
            print("AppleScript error: \(error)")
        }
        
        // Add to sessions list
        let session = TerminalSession(
            id: sessionName,
            name: "Terminal \(sessions.count + 1)",
            tmuxSession: sessionName
        )
        sessions.append(session)
        selectedSession = session
    }
    
    func closeSession(_ session: TerminalSession) {
        // Kill tmux session
        let killTmux = Process()
        killTmux.executableURL = URL(fileURLWithPath: "/usr/bin/tmux")
        killTmux.arguments = ["kill-session", "-t", session.tmuxSession]
        try? killTmux.run()
        killTmux.waitUntilExit()
        
        // Remove from list
        sessions.removeAll { $0.id == session.id }
        if selectedSession?.id == session.id {
            selectedSession = sessions.first
        }
    }
    
    func focusTerminal(_ session: TerminalSession) {
        // Bring Terminal.app to front and attach to session
        let script = """
        tell application "Terminal"
            activate
            do script "tmux attach-session -t \(session.tmuxSession)"
        end tell
        """
        
        let appleScript = NSAppleScript(source: script)
        appleScript?.executeAndReturnError(nil)
    }
    
    // MARK: - State Updates
    
    private func updateServerInfo() {
        // Get Tailscale IP
        let tailscale = Process()
        tailscale.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        tailscale.arguments = ["tailscale", "ip", "-4"]
        
        let pipe = Pipe()
        tailscale.standardOutput = pipe
        
        do {
            try tailscale.run()
            tailscale.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let ip = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                serverAddress = "\(ip):8443"
            }
        } catch {
            serverAddress = "localhost:8443"
        }
        
        // Get pairing code from certificate
        updatePairingCode()
    }
    
    private func updatePairingCode() {
        let certPath = findServerPath()?.replacingOccurrences(of: "server.py", with: "certs/server.crt") ?? ""
        
        let openssl = Process()
        openssl.executableURL = URL(fileURLWithPath: "/usr/bin/openssl")
        openssl.arguments = ["x509", "-in", certPath, "-noout", "-fingerprint", "-sha256"]
        
        let pipe = Pipe()
        openssl.standardOutput = pipe
        
        do {
            try openssl.run()
            openssl.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8),
               let fingerprint = output.split(separator: "=").last {
                let cleanFP = fingerprint.replacingOccurrences(of: ":", with: "").lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                if cleanFP.count >= 6 {
                    let hexPart = String(cleanFP.prefix(6))
                    if let value = Int(hexPart, radix: 16) {
                        pairingCode = String(format: "%06d", value % 1000000)
                    }
                }
            }
        } catch {
            pairingCode = "------"
        }
    }
    
    private func refreshState() {
        // Refresh tmux sessions
        refreshTmuxSessions()
        
        // Update session output previews
        for i in sessions.indices {
            sessions[i].lastOutput = getTmuxOutput(sessions[i].tmuxSession)
        }
    }
    
    private func refreshTmuxSessions() {
        let tmux = Process()
        tmux.executableURL = URL(fileURLWithPath: "/usr/bin/tmux")
        tmux.arguments = ["list-sessions", "-F", "#{session_name}"]
        
        let pipe = Pipe()
        tmux.standardOutput = pipe
        tmux.standardError = FileHandle.nullDevice
        
        do {
            try tmux.run()
            tmux.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let tmuxSessions = output.split(separator: "\n").map(String.init)
                
                // Add any tmux sessions that start with "tl-" that we don't have
                for tmuxSession in tmuxSessions where tmuxSession.hasPrefix("tl-") {
                    if !sessions.contains(where: { $0.tmuxSession == tmuxSession }) {
                        let session = TerminalSession(
                            id: tmuxSession,
                            name: "Terminal \(sessions.count + 1)",
                            tmuxSession: tmuxSession
                        )
                        sessions.append(session)
                    }
                }
                
                // Remove sessions that no longer exist in tmux
                sessions.removeAll { session in
                    !tmuxSessions.contains(session.tmuxSession)
                }
            }
        } catch {
            // tmux might not be running
        }
    }
    
    private func getTmuxOutput(_ sessionName: String) -> String {
        let tmux = Process()
        tmux.executableURL = URL(fileURLWithPath: "/usr/bin/tmux")
        tmux.arguments = ["capture-pane", "-t", sessionName, "-p", "-S", "-50"]
        
        let pipe = Pipe()
        tmux.standardOutput = pipe
        tmux.standardError = FileHandle.nullDevice
        
        do {
            try tmux.run()
            tmux.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }
    
    private func findServerPath() -> String? {
        // Check common locations
        let paths = [
            NSHomeDirectory() + "/developer/TermLinkky/server/server.py",
            NSHomeDirectory() + "/Developer/TermLinkky/server/server.py",
            Bundle.main.bundlePath + "/Contents/Resources/server/server.py"
        ]
        
        for path in paths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        
        return paths.first // Return first as default
    }
}
