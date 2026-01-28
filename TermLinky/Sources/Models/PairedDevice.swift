//
//  PairedDevice.swift
//  TermLinkky
//
//  Represents a paired Mac with its certificate fingerprint.
//

import Foundation

struct PairedDevice: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var hostname: String
    var port: Int
    var certificateFingerprint: String  // SHA-256 of server's cert
    var pairedAt: Date
    var lastConnected: Date?
    var tmuxSession: String?
    
    init(
        id: UUID = UUID(),
        name: String,
        hostname: String,
        port: Int = 8443,
        certificateFingerprint: String,
        pairedAt: Date = Date(),
        lastConnected: Date? = nil,
        tmuxSession: String? = nil
    ) {
        self.id = id
        self.name = name
        self.hostname = hostname
        self.port = port
        self.certificateFingerprint = certificateFingerprint
        self.pairedAt = pairedAt
        self.lastConnected = lastConnected
        self.tmuxSession = tmuxSession
    }
    
    var displayAddress: String {
        "\(hostname):\(port)"
    }
}

// MARK: - Pairing Code

struct PairingCode {
    let code: String  // 6-digit numeric code
    let fingerprint: String  // Full SHA-256 fingerprint
    
    /// Generate pairing code from certificate fingerprint
    /// Takes first 6 hex chars and converts to numeric
    static func from(fingerprint: String) -> PairingCode {
        let cleanFingerprint = fingerprint
            .replacingOccurrences(of: ":", separator: "")
            .lowercased()
        
        // Convert first 6 hex chars to a 6-digit code
        let hexPart = String(cleanFingerprint.prefix(6))
        let numericCode = String(format: "%06d", (Int(hexPart, radix: 16) ?? 0) % 1000000)
        
        return PairingCode(code: numericCode, fingerprint: fingerprint)
    }
    
    /// Verify a user-entered code against fingerprint
    func verify(_ enteredCode: String) -> Bool {
        return code == enteredCode.trimmingCharacters(in: .whitespaces)
    }
}

extension String {
    func replacingOccurrences(of target: String, separator: String) -> String {
        self.replacingOccurrences(of: target, with: separator)
    }
}
