//
//  ContentView.swift
//  TermLinkky Server
//
//  Server companion app - manage terminal sessions and remote connections.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var serverManager = ServerManager()
    
    var body: some View {
        NavigationSplitView {
            // Sidebar
            List(selection: $serverManager.selectedSession) {
                Section("Server") {
                    ServerStatusRow(serverManager: serverManager)
                }
                
                Section("Terminal Sessions") {
                    ForEach(serverManager.sessions) { session in
                        SessionRow(session: session)
                            .tag(session)
                    }
                    
                    Button {
                        serverManager.openNewTerminal()
                    } label: {
                        Label("New Terminal", systemImage: "plus.circle")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.green)
                }
                
                Section("Connected Devices") {
                    if serverManager.connectedClients.isEmpty {
                        Text("No devices connected")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    } else {
                        ForEach(serverManager.connectedClients) { client in
                            ClientRow(client: client)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("TermLinkky")
            .toolbar {
                ToolbarItem {
                    Button {
                        serverManager.toggleServer()
                    } label: {
                        Image(systemName: serverManager.isRunning ? "stop.circle.fill" : "play.circle.fill")
                            .foregroundStyle(serverManager.isRunning ? .red : .green)
                    }
                    .help(serverManager.isRunning ? "Stop Server" : "Start Server")
                }
            }
        } detail: {
            // Main content
            if let session = serverManager.selectedSession {
                TerminalDetailView(session: session, serverManager: serverManager)
            } else {
                ServerInfoView(serverManager: serverManager)
            }
        }
        .onAppear {
            serverManager.startServer()
        }
    }
}

// MARK: - Server Status Row

struct ServerStatusRow: View {
    @ObservedObject var serverManager: ServerManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(serverManager.isRunning ? .green : .gray)
                    .frame(width: 10, height: 10)
                Text(serverManager.isRunning ? "Running" : "Stopped")
                    .font(.headline)
            }
            
            if serverManager.isRunning {
                Text(serverManager.serverAddress)
                    .font(.caption)
                    .fontDesign(.monospaced)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Session Row

struct SessionRow: View {
    let session: TerminalSession
    
    var body: some View {
        HStack {
            Image(systemName: "terminal.fill")
                .foregroundStyle(.green)
            
            VStack(alignment: .leading) {
                Text(session.name)
                    .font(.headline)
                Text(session.tmuxSession)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if session.hasActivity {
                Circle()
                    .fill(.blue)
                    .frame(width: 8, height: 8)
            }
        }
    }
}

// MARK: - Client Row

struct ClientRow: View {
    let client: ConnectedClient
    
    var body: some View {
        HStack {
            Image(systemName: client.isPhone ? "iphone" : "laptopcomputer")
                .foregroundStyle(.blue)
            
            VStack(alignment: .leading) {
                Text(client.name)
                    .font(.subheadline)
                Text(client.connectedAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Server Info View (Default detail view)

struct ServerInfoView: View {
    @ObservedObject var serverManager: ServerManager
    
    var body: some View {
        VStack(spacing: 30) {
            // Logo/Icon
            Image(systemName: "terminal.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)
            
            Text("TermLinkky Server")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            if serverManager.isRunning {
                // Pairing Info Card
                GroupBox {
                    VStack(spacing: 16) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Server Address")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(serverManager.serverAddress)
                                    .font(.title3)
                                    .fontDesign(.monospaced)
                            }
                            
                            Spacer()
                            
                            Button {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(serverManager.serverAddress, forType: .string)
                            } label: {
                                Image(systemName: "doc.on.doc")
                            }
                            .buttonStyle(.borderless)
                        }
                        
                        Divider()
                        
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Pairing Code")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(serverManager.pairingCode)
                                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.green)
                            }
                            
                            Spacer()
                            
                            Button {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(serverManager.pairingCode, forType: .string)
                            } label: {
                                Image(systemName: "doc.on.doc")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .padding()
                } label: {
                    Label("Connection Info", systemImage: "qrcode")
                }
                .frame(maxWidth: 400)
                
                // Stats
                HStack(spacing: 40) {
                    VStack {
                        Text("\(serverManager.sessions.count)")
                            .font(.title)
                            .fontWeight(.bold)
                        Text("Sessions")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    VStack {
                        Text("\(serverManager.connectedClients.count)")
                            .font(.title)
                            .fontWeight(.bold)
                        Text("Connected")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top)
                
                // Quick Actions
                HStack {
                    Button {
                        serverManager.openNewTerminal()
                    } label: {
                        Label("New Terminal", systemImage: "plus.rectangle")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }
                .padding(.top)
                
            } else {
                Text("Server is stopped")
                    .foregroundStyle(.secondary)
                
                Button("Start Server") {
                    serverManager.startServer()
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - Terminal Detail View

struct TerminalDetailView: View {
    let session: TerminalSession
    @ObservedObject var serverManager: ServerManager
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "terminal.fill")
                    .foregroundStyle(.green)
                Text(session.name)
                    .font(.headline)
                
                Spacer()
                
                Button {
                    serverManager.focusTerminal(session)
                } label: {
                    Label("Show in Terminal.app", systemImage: "arrow.up.forward.square")
                }
                .buttonStyle(.bordered)
                
                Button {
                    serverManager.closeSession(session)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.borderless)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            // Terminal preview (read-only view of the session)
            ScrollView {
                Text(session.lastOutput)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .background(.black)
            .foregroundStyle(.white)
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .frame(width: 900, height: 600)
}
