//
//  DevicesView.swift
//  TermLinky
//
//  Manage paired devices and pairing flow.
//

import SwiftUI

struct DevicesView: View {
    @EnvironmentObject var pairingManager: PairingManager
    @EnvironmentObject var connectionManager: ConnectionManager
    
    @State private var showingPairingSheet = false
    
    var body: some View {
        NavigationStack {
            List {
                if !pairingManager.pairedDevices.isEmpty {
                    Section("Paired Devices") {
                        ForEach(pairingManager.pairedDevices) { device in
                            DeviceRow(device: device)
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                pairingManager.removePairedDevice(pairingManager.pairedDevices[index])
                            }
                        }
                    }
                }
                
                Section {
                    Button {
                        showingPairingSheet = true
                    } label: {
                        Label("Pair New Device", systemImage: "plus.circle.fill")
                            .foregroundStyle(.green)
                    }
                } footer: {
                    Text("Pair with your Mac to enable secure terminal access.")
                }
            }
            .navigationTitle("Devices")
            .sheet(isPresented: $showingPairingSheet) {
                PairingView()
            }
            .overlay {
                if pairingManager.pairedDevices.isEmpty {
                    ContentUnavailableView {
                        Label("No Paired Devices", systemImage: "laptopcomputer.and.iphone")
                    } description: {
                        Text("Pair with your Mac to get started")
                    } actions: {
                        Button("Pair Device") {
                            showingPairingSheet = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                    }
                }
            }
        }
    }
}

// MARK: - Device Row

struct DeviceRow: View {
    @EnvironmentObject var connectionManager: ConnectionManager
    @EnvironmentObject var pairingManager: PairingManager
    let device: PairedDevice
    
    var isConnected: Bool {
        connectionManager.currentDevice?.id == device.id && connectionManager.isConnected
    }
    
    var body: some View {
        Button {
            if isConnected {
                connectionManager.disconnect()
            } else {
                Task {
                    await connectionManager.connect(to: device, pairingManager: pairingManager)
                }
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(device.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Text(device.displayAddress)
                        .font(.caption)
                        .fontDesign(.monospaced)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if isConnected {
                    Image(systemName: "wifi")
                        .foregroundStyle(.green)
                } else if connectionManager.currentDevice?.id == device.id {
                    ProgressView().scaleEffect(0.8)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Pairing View

struct PairingView: View {
    @EnvironmentObject var pairingManager: PairingManager
    @Environment(\.dismiss) var dismiss
    
    @State private var manualHost = ""
    @State private var manualPort = "8443"
    @State private var deviceName = "My Mac"
    @State private var pairingCode = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                switch pairingManager.state {
                case .idle, .discovering:
                    manualEntryView
                    
                case .foundDevice(let name, let host, let port):
                    codeEntryView(name: name, host: host, port: port)
                    
                case .awaitingCode:
                    ProgressView("Connecting...")
                    
                case .verifying:
                    ProgressView("Verifying...")
                    
                case .paired:
                    successView
                    
                case .error(let message):
                    errorView(message: message)
                }
            }
            .padding()
            .navigationTitle("Pair Device")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        pairingManager.cancelPairing()
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var manualEntryView: some View {
        VStack(spacing: 20) {
            Image(systemName: "laptopcomputer.and.iphone")
                .font(.system(size: 60))
                .foregroundStyle(.green)
            
            Text("Enter Mac Details")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Enter the IP address shown in the Mac app")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(spacing: 12) {
                TextField("Device Name", text: $deviceName)
                    .textFieldStyle(.roundedBorder)
                
                TextField("IP Address or Hostname", text: $manualHost)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                
                TextField("Port", text: $manualPort)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
            }
            .padding(.vertical)
            
            Button {
                let port = Int(manualPort) ?? 8443
                Task {
                    await pairingManager.startPairing(host: manualHost, port: port, name: deviceName)
                }
            } label: {
                Text("Connect")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .disabled(manualHost.isEmpty)
        }
    }
    
    private func codeEntryView(name: String, host: String, port: Int) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield")
                .font(.system(size: 60))
                .foregroundStyle(.green)
            
            Text("Enter Pairing Code")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Enter the 6-digit code shown on \(name)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            TextField("000000", text: $pairingCode)
                .font(.system(size: 32, weight: .bold, design: .monospaced))
                .multilineTextAlignment(.center)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .frame(width: 200)
            
            Button {
                pairingManager.verifyPairingCode(pairingCode, name: name, host: host, port: port)
            } label: {
                Text("Verify")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .disabled(pairingCode.count != 6)
        }
    }
    
    private var successView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)
            
            Text("Paired!")
                .font(.title2)
                .fontWeight(.semibold)
            
            Button("Done") {
                pairingManager.cancelPairing()
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.red)
            
            Text("Pairing Failed")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Try Again") {
                pairingManager.cancelPairing()
            }
            .buttonStyle(.bordered)
        }
    }
}
