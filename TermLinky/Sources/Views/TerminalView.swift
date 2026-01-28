//
//  TerminalView.swift
//  TermLinky
//
//  Terminal output display with command input.
//

import SwiftUI

struct TerminalView: View {
    @EnvironmentObject var connectionManager: ConnectionManager
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var pairingManager: PairingManager
    
    @State private var inputText = ""
    @State private var showingCommandPalette = false
    @FocusState private var inputFocused: Bool
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 0) {
                    ConnectionStatusBar()
                    TerminalOutputView()
                    
                    if connectionManager.isConnected {
                        InputBar(text: $inputText, isFocused: $inputFocused) {
                            sendInput()
                        }
                    }
                }
                
                FloatingCommandButton(
                    showingPalette: $showingCommandPalette,
                    isConnected: connectionManager.isConnected
                )
                .padding(.trailing, 16)
                .padding(.bottom, connectionManager.isConnected ? 70 : 16)
            }
            .navigationTitle("TermLinky")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        if connectionManager.isConnected {
                            Button {
                                connectionManager.clearTerminal()
                            } label: {
                                Label("Clear", systemImage: "xmark.circle")
                            }
                            
                            Button(role: .destructive) {
                                connectionManager.disconnect()
                            } label: {
                                Label("Disconnect", systemImage: "wifi.slash")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingCommandPalette) {
                CommandPaletteView()
            }
        }
    }
    
    private func sendInput() {
        guard !inputText.isEmpty else { return }
        connectionManager.sendCommand(inputText)
        inputText = ""
    }
}

// MARK: - Connection Status Bar

struct ConnectionStatusBar: View {
    @EnvironmentObject var connectionManager: ConnectionManager
    
    var statusColor: Color {
        switch connectionManager.connectionState {
        case .connected: return .green
        case .connecting: return .yellow
        case .disconnected: return .gray
        case .error: return .red
        }
    }
    
    var statusText: String {
        switch connectionManager.connectionState {
        case .connected:
            return "Connected to \(connectionManager.currentDevice?.name ?? "device")"
        case .connecting:
            return "Connecting..."
        case .disconnected:
            return "Not connected"
        case .error(let msg):
            return msg
        }
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            Text(statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
    }
}

// MARK: - Terminal Output

struct TerminalOutputView: View {
    @EnvironmentObject var connectionManager: ConnectionManager
    @EnvironmentObject var settingsManager: SettingsManager
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(connectionManager.terminalLines) { line in
                        TerminalLineView(line: line, fontSize: settingsManager.fontSize)
                            .id(line.id)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .background(Color.black)
            .onChange(of: connectionManager.terminalLines.count) { _, _ in
                if let lastLine = connectionManager.terminalLines.last {
                    withAnimation(.easeOut(duration: 0.1)) {
                        proxy.scrollTo(lastLine.id, anchor: .bottom)
                    }
                }
            }
        }
    }
}

// MARK: - Terminal Line

struct TerminalLineView: View {
    let line: TerminalLine
    let fontSize: CGFloat
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(line.segments.enumerated()), id: \.offset) { _, segment in
                Text(segment.text)
                    .foregroundColor(segment.foreground ?? .white)
                    .fontWeight(segment.bold ? .bold : .regular)
                    .italic(segment.italic)
                    .underline(segment.underline)
            }
            Spacer()
        }
        .font(.system(size: fontSize, design: .monospaced))
    }
}

// MARK: - Input Bar

struct InputBar: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    let onSubmit: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Text("$")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.green)
            
            TextField("Enter command...", text: $text)
                .font(.system(.body, design: .monospaced))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused(isFocused)
                .onSubmit(onSubmit)
            
            Button(action: onSubmit) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
            }
            .disabled(text.isEmpty)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground))
    }
}
