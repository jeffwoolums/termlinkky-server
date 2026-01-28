//
//  ConnectionManager.swift
//  TermLinky
//
//  Manages secure connections to paired Mac servers.
//

import Foundation
import SwiftUI
import Network

enum ConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
    case error(String)
}

enum ConnectionError: LocalizedError {
    case invalidURL
    case certificateMismatch
    case connectionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid server URL"
        case .certificateMismatch: return "Certificate fingerprint mismatch - possible security issue"
        case .connectionFailed(let reason): return "Connection failed: \(reason)"
        }
    }
}

@MainActor
class ConnectionManager: ObservableObject {
    @Published var currentDevice: PairedDevice?
    @Published var connectionState: ConnectionState = .disconnected
    @Published var terminalLines: [TerminalLine] = []
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    
    var isConnected: Bool {
        connectionState == .connected
    }
    
    // MARK: - Connection
    
    func connect(to device: PairedDevice, pairingManager: PairingManager) async {
        guard connectionState != .connecting else { return }
        
        connectionState = .connecting
        currentDevice = device
        terminalLines = []
        
        do {
            try await establishSecureConnection(to: device)
            connectionState = .connected
            pairingManager.updateLastConnected(device)
            startReceiving()
        } catch {
            connectionState = .error(error.localizedDescription)
            currentDevice = nil
        }
    }
    
    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
        currentDevice = nil
        connectionState = .disconnected
    }
    
    // MARK: - Secure Connection with Certificate Pinning
    
    private func establishSecureConnection(to device: PairedDevice) async throws {
        let urlString = "wss://\(device.hostname):\(device.port)/terminal"
        guard let url = URL(string: urlString) else {
            throw ConnectionError.invalidURL
        }
        
        let delegate = CertificatePinningDelegate(expectedFingerprint: device.certificateFingerprint)
        urlSession = URLSession(
            configuration: .default,
            delegate: delegate,
            delegateQueue: nil
        )
        
        webSocketTask = urlSession?.webSocketTask(with: url)
        webSocketTask?.resume()
        
        // Wait for connection with timeout
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            webSocketTask?.sendPing { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
    
    // MARK: - Send Commands
    
    func sendCommand(_ command: String) {
        guard connectionState == .connected else { return }
        
        // Add to terminal as input
        let inputLine = TerminalLine(text: "$ \(command)")
        terminalLines.append(inputLine)
        
        let message = URLSessionWebSocketTask.Message.string(command + "\n")
        webSocketTask?.send(message) { [weak self] error in
            if let error = error {
                Task { @MainActor in
                    self?.connectionState = .error(error.localizedDescription)
                }
            }
        }
    }
    
    func sendRawInput(_ text: String) {
        guard connectionState == .connected else { return }
        
        let message = URLSessionWebSocketTask.Message.string(text)
        webSocketTask?.send(message) { _ in }
    }
    
    // MARK: - Receive Output
    
    private func startReceiving() {
        receiveNextMessage()
    }
    
    private func receiveNextMessage() {
        webSocketTask?.receive { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success(let message):
                    self?.handleMessage(message)
                    self?.receiveNextMessage()
                    
                case .failure(let error):
                    if self?.connectionState == .connected {
                        self?.connectionState = .error(error.localizedDescription)
                    }
                }
            }
        }
    }
    
    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            let lines = text.components(separatedBy: "\n")
            for line in lines where !line.isEmpty {
                terminalLines.append(TerminalLine(text: line))
            }
            
        case .data(let data):
            if let text = String(data: data, encoding: .utf8) {
                terminalLines.append(TerminalLine(text: text))
            }
            
        @unknown default:
            break
        }
        
        // Keep buffer reasonable
        if terminalLines.count > 1000 {
            terminalLines.removeFirst(100)
        }
    }
    
    func clearTerminal() {
        terminalLines = []
    }
}

// MARK: - Certificate Pinning Delegate

class CertificatePinningDelegate: NSObject, URLSessionDelegate {
    let expectedFingerprint: String
    
    init(expectedFingerprint: String) {
        self.expectedFingerprint = expectedFingerprint
    }
    
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        // Get server certificate
        guard let serverCert = SecTrustGetCertificateAtIndex(serverTrust, 0) else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        // Calculate fingerprint
        let certData = SecCertificateCopyData(serverCert) as Data
        let fingerprint = sha256Fingerprint(certData)
        
        // Compare with expected (case-insensitive)
        if fingerprint.lowercased() == expectedFingerprint.lowercased() {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
    
    private func sha256Fingerprint(_ data: Data) -> String {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined(separator: ":")
    }
}

import CommonCrypto
