//
//  PairingManager.swift
//  TermLinkky
//
//  Manages device pairing with certificate pinning.
//

import Foundation
import SwiftUI
import Network

enum PairingState: Equatable {
    case idle
    case discovering
    case foundDevice(name: String, host: String, port: Int)
    case awaitingCode
    case verifying
    case paired
    case error(String)
}

struct DiscoveredServer: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let host: String
    let port: Int
}

@MainActor
class PairingManager: ObservableObject {
    @Published var state: PairingState = .idle
    @Published var pairedDevices: [PairedDevice] = []
    @Published var discoveredServers: [DiscoveredServer] = []
    @Published var pendingFingerprint: String?
    
    private var browser: NWBrowser?
    private let devicesKey = "paired_devices"
    
    init() {
        loadPairedDevices()
    }
    
    // MARK: - Device Storage
    
    private func loadPairedDevices() {
        guard let data = UserDefaults.standard.data(forKey: devicesKey),
              let decoded = try? JSONDecoder().decode([PairedDevice].self, from: data) else {
            return
        }
        pairedDevices = decoded
    }
    
    private func savePairedDevices() {
        guard let encoded = try? JSONEncoder().encode(pairedDevices) else { return }
        UserDefaults.standard.set(encoded, forKey: devicesKey)
    }
    
    func addPairedDevice(_ device: PairedDevice) {
        pairedDevices.removeAll { $0.certificateFingerprint == device.certificateFingerprint }
        pairedDevices.append(device)
        savePairedDevices()
    }
    
    func removePairedDevice(_ device: PairedDevice) {
        pairedDevices.removeAll { $0.id == device.id }
        savePairedDevices()
    }
    
    func updateLastConnected(_ device: PairedDevice) {
        if let index = pairedDevices.firstIndex(where: { $0.id == device.id }) {
            pairedDevices[index].lastConnected = Date()
            savePairedDevices()
        }
    }
    
    // MARK: - Discovery (Bonjour)
    
    func startDiscovery() {
        state = .discovering
        discoveredServers = []
        
        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        
        browser = NWBrowser(for: .bonjour(type: "_termlinkky._tcp", domain: nil), using: parameters)
        
        browser?.stateUpdateHandler = { [weak self] newState in
            Task { @MainActor in
                switch newState {
                case .failed(let error):
                    self?.state = .error("Discovery failed: \(error.localizedDescription)")
                case .cancelled:
                    self?.state = .idle
                default:
                    break
                }
            }
        }
        
        browser?.browseResultsChangedHandler = { [weak self] results, changes in
            Task { @MainActor in
                self?.handleDiscoveryResults(results)
            }
        }
        
        browser?.start(queue: .main)
    }
    
    func stopDiscovery() {
        browser?.cancel()
        browser = nil
        if case .discovering = state {
            state = .idle
        }
    }
    
    private func handleDiscoveryResults(_ results: Set<NWBrowser.Result>) {
        discoveredServers = results.compactMap { result -> DiscoveredServer? in
            guard case .service(let name, _, _, _) = result.endpoint else { return nil }
            // We'll resolve the actual host/port when user selects
            return DiscoveredServer(name: name, host: "", port: 8443)
        }
    }
    
    // MARK: - Pairing Flow
    
    func startPairing(host: String, port: Int, name: String) async {
        state = .awaitingCode
        
        // Fetch server's certificate fingerprint
        do {
            let fingerprint = try await fetchServerFingerprint(host: host, port: port)
            pendingFingerprint = fingerprint
            state = .foundDevice(name: name, host: host, port: port)
        } catch {
            state = .error("Could not connect: \(error.localizedDescription)")
        }
    }
    
    func verifyPairingCode(_ code: String, name: String, host: String, port: Int) {
        guard let fingerprint = pendingFingerprint else {
            state = .error("No pending pairing")
            return
        }
        
        state = .verifying
        
        let pairingCode = PairingCode.from(fingerprint: fingerprint)
        
        if pairingCode.verify(code) {
            let device = PairedDevice(
                name: name,
                hostname: host,
                port: port,
                certificateFingerprint: fingerprint
            )
            addPairedDevice(device)
            state = .paired
            pendingFingerprint = nil
        } else {
            state = .error("Invalid pairing code")
        }
    }
    
    func cancelPairing() {
        pendingFingerprint = nil
        state = .idle
    }
    
    // MARK: - Certificate Operations
    
    private func fetchServerFingerprint(host: String, port: Int) async throws -> String {
        // Create a TLS connection to get the server's certificate
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: NWEndpoint.Port(integerLiteral: UInt16(port)))
        
        let tlsOptions = NWProtocolTLS.Options()
        
        // Use a class to capture the fingerprint from the verify block
        class FingerprintCapture {
            var fingerprint: String?
        }
        let capture = FingerprintCapture()
        
        // Allow self-signed certs for initial pairing and capture fingerprint
        sec_protocol_options_set_verify_block(tlsOptions.securityProtocolOptions, { (_, trust, complete) in
            // Extract fingerprint from the trust during verification
            let secTrust = sec_trust_copy_ref(trust).takeRetainedValue()
            if let certChain = SecTrustCopyCertificateChain(secTrust) as? [SecCertificate],
               let cert = certChain.first {
                let certData = SecCertificateCopyData(cert) as Data
                capture.fingerprint = PairingManager.sha256FingerprintStatic(certData)
            }
            complete(true)  // Accept any cert during pairing
        }, .main)
        
        let parameters = NWParameters(tls: tlsOptions)
        let connection = NWConnection(to: endpoint, using: parameters)
        
        return try await withCheckedThrowingContinuation { continuation in
            var completed = false
            
            connection.stateUpdateHandler = { state in
                guard !completed else { return }
                
                switch state {
                case .ready:
                    // Fingerprint was captured in verify block
                    if let fingerprint = capture.fingerprint {
                        completed = true
                        connection.cancel()
                        continuation.resume(returning: fingerprint)
                    } else {
                        completed = true
                        connection.cancel()
                        continuation.resume(throwing: NSError(domain: "PairingManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not extract certificate"]))
                    }
                    
                case .failed(let error):
                    completed = true
                    connection.cancel()
                    continuation.resume(throwing: error)
                    
                case .cancelled:
                    if !completed {
                        completed = true
                        continuation.resume(throwing: NSError(domain: "PairingManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Connection cancelled"]))
                    }
                    
                default:
                    break
                }
            }
            
            connection.start(queue: .main)
        }
    }
    
    private func sha256Fingerprint(_ data: Data) -> String {
        Self.sha256FingerprintStatic(data)
    }
    
    private static func sha256FingerprintStatic(_ data: Data) -> String {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined(separator: ":")
    }
}

// CommonCrypto import for SHA256
import CommonCrypto
