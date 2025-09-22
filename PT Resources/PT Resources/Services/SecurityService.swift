//
//  SecurityService.swift
//  PT Resources
//
//  Comprehensive security service with certificate pinning, secure storage, and input validation
//

import Foundation
import Security
import CryptoKit
import CommonCrypto
import OSLog

// MARK: - Security Protocols

@MainActor
protocol SecurityServiceProtocol {
    func validateInput(_ input: String, type: InputValidationType) -> ValidationResult
    func encryptData(_ data: Data, key: String) throws -> Data
    func decryptData(_ data: Data, key: String) throws -> Data
    func storeSecurely(_ data: Data, forKey key: String) throws
    func retrieveSecurely(forKey key: String) throws -> Data?
    func deleteSecurely(forKey key: String) throws
    func hashPassword(_ password: String) -> String
    func verifyPassword(_ password: String, against hash: String) -> Bool
    func generateSecureRandomData(length: Int) -> Data
    func sanitizeHTML(_ html: String) -> String
    func validateURL(_ url: String) -> Bool
    func validateEmail(_ email: String) -> Bool
    func validateCertificatePinning(for challenge: URLAuthenticationChallenge) -> Bool
}

// MARK: - Input Validation Types

enum InputValidationType {
    case email
    case url
    case password
    case username
    case searchQuery
    case text(length: ClosedRange<Int>)
    case alphanumeric
    case numeric
    case phone
}

enum ValidationResult {
    case valid
    case invalid(reason: String)
    case warning(reason: String)
}

// MARK: - Security Service Implementation

@MainActor
final class SecurityService: SecurityServiceProtocol, ObservableObject {

    static let shared = SecurityService()

    // MARK: - Private Properties

    private let keychainService: KeychainServiceProtocol
    private let certificatePinner: CertificatePinnerProtocol

    // MARK: - Initialization

    init(keychainService: KeychainServiceProtocol = KeychainService(),
         certificatePinner: CertificatePinnerProtocol = CertificatePinner()) {
        self.keychainService = keychainService
        self.certificatePinner = certificatePinner
    }

    // MARK: - Input Validation

    func validateInput(_ input: String, type: InputValidationType) -> ValidationResult {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        switch type {
        case .email:
            return validateEmail(trimmed) ? .valid : .invalid(reason: "Invalid email format")

        case .url:
            return validateURL(trimmed) ? .valid : .invalid(reason: "Invalid URL format")

        case .password:
            return validatePassword(trimmed)

        case .username:
            return validateUsername(trimmed)

        case .searchQuery:
            return validateSearchQuery(trimmed)

        case .text(let range):
            return validateTextLength(trimmed, range: range)

        case .alphanumeric:
            return validateAlphanumeric(trimmed)

        case .numeric:
            return validateNumeric(trimmed)

        case .phone:
            return validatePhoneNumber(trimmed)
        }
    }

    // MARK: - Encryption/Decryption

    func encryptData(_ data: Data, key: String) throws -> Data {
        let symmetricKey = SymmetricKey(data: SHA256.hash(data: key.data(using: .utf8)!))
        let sealedBox = try AES.GCM.seal(data, using: symmetricKey)
        return sealedBox.combined!
    }

    func decryptData(_ data: Data, key: String) throws -> Data {
        let symmetricKey = SymmetricKey(data: SHA256.hash(data: key.data(using: .utf8)!))
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(sealedBox, using: symmetricKey)
    }

    // MARK: - Secure Storage

    func storeSecurely(_ data: Data, forKey key: String) throws {
        try keychainService.store(data, forKey: key)
    }

    func retrieveSecurely(forKey key: String) throws -> Data? {
        try keychainService.retrieve(forKey: key)
    }

    func deleteSecurely(forKey key: String) throws {
        try keychainService.delete(forKey: key)
    }

    // MARK: - Password Security

    func hashPassword(_ password: String) -> String {
        let salt = generateSecureRandomData(length: 32)
        let saltedPassword = salt + password.data(using: .utf8)!

        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        _ = saltedPassword.withUnsafeBytes { buffer in
            CC_SHA256(buffer.baseAddress, CC_LONG(buffer.count), &hash)
        }

        return "\(salt.base64EncodedString()).\(Data(hash).base64EncodedString())"
    }

    func verifyPassword(_ password: String, against hash: String) -> Bool {
        let components = hash.split(separator: ".", maxSplits: 1)
        guard components.count == 2,
              let saltData = Data(base64Encoded: String(components[0])),
              let expectedHashData = Data(base64Encoded: String(components[1])) else {
            return false
        }

        let saltedPassword = saltData + password.data(using: .utf8)!

        var actualHash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        _ = saltedPassword.withUnsafeBytes { buffer in
            CC_SHA256(buffer.baseAddress, CC_LONG(buffer.count), &actualHash)
        }

        return Data(actualHash) == expectedHashData
    }

    // MARK: - Utility Functions

    func generateSecureRandomData(length: Int) -> Data {
        var data = Data(count: length)
        let result = data.withUnsafeMutableBytes { buffer in
            SecRandomCopyBytes(kSecRandomDefault, length, buffer.baseAddress!)
        }
        guard result == errSecSuccess else {
            fatalError("Failed to generate secure random data")
        }
        return data
    }

    func sanitizeHTML(_ html: String) -> String {
        // Remove dangerous tags and attributes
        var sanitized = html

        // Remove script tags and content
        sanitized = sanitized.replacingOccurrences(of: "<script[^>]*>.*?</script>", with: "", options: .regularExpression, range: nil)

        // Remove potentially dangerous attributes
        let dangerousAttributes = ["onclick", "onload", "onerror", "onmouseover", "onmouseout", "javascript:", "vbscript:", "data:"]
        for attribute in dangerousAttributes {
            let pattern = "\\s*\(attribute)[^\\s]*"
            sanitized = sanitized.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }

        // Remove event handlers
        sanitized = sanitized.replacingOccurrences(of: "on\\w+\\s*=\\s*\"[^\"]*\"", with: "", options: .regularExpression)

        return sanitized
    }

    func validateURL(_ url: String) -> Bool {
        guard let url = URL(string: url) else { return false }

        // Only allow HTTP and HTTPS
        guard url.scheme == "http" || url.scheme == "https" else { return false }

        // Check for suspicious patterns
        let suspiciousPatterns = ["javascript:", "data:", "vbscript:"]
        let urlString = url.absoluteString.lowercased()
        for pattern in suspiciousPatterns {
            if urlString.contains(pattern) { return false }
        }

        return true
    }

    func validateEmail(_ email: String) -> Bool {
        let emailRegex = #"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$"#

        let predicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return predicate.evaluate(with: email)
    }

    func validateCertificatePinning(for challenge: URLAuthenticationChallenge) -> Bool {
        certificatePinner.validateChallenge(challenge)
    }

    // MARK: - Private Validation Methods

    private func validatePassword(_ password: String) -> ValidationResult {
        guard password.count >= 8 else {
            return .invalid(reason: "Password must be at least 8 characters long")
        }

        guard password.count <= 128 else {
            return .invalid(reason: "Password must be no more than 128 characters long")
        }

        let hasUppercase = password.rangeOfCharacter(from: .uppercaseLetters) != nil
        let hasLowercase = password.rangeOfCharacter(from: .lowercaseLetters) != nil
        let hasNumbers = password.rangeOfCharacter(from: .decimalDigits) != nil
        let hasSpecialChars = password.rangeOfCharacter(from: CharacterSet(charactersIn: "!@#$%^&*()_+-=[]{}|;:,.<>?")) != nil

        guard hasUppercase && hasLowercase && hasNumbers else {
            return .warning(reason: "Password should contain uppercase, lowercase, and numeric characters")
        }

        guard hasSpecialChars else {
            return .warning(reason: "Password should contain at least one special character")
        }

        return .valid
    }

    private func validateUsername(_ username: String) -> ValidationResult {
        guard username.count >= 3 && username.count <= 30 else {
            return .invalid(reason: "Username must be between 3 and 30 characters")
        }

        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        guard CharacterSet(charactersIn: username).isSubset(of: allowedCharacters) else {
            return .invalid(reason: "Username can only contain letters, numbers, underscores, and hyphens")
        }

        return .valid
    }

    private func validateSearchQuery(_ query: String) -> ValidationResult {
        guard query.count <= 200 else {
            return .invalid(reason: "Search query is too long")
        }

        // Check for potentially harmful patterns
        let dangerousPatterns = ["<script", "javascript:", "onerror=", "onload="]
        for pattern in dangerousPatterns {
            if query.lowercased().contains(pattern) {
                return .invalid(reason: "Search query contains invalid characters")
            }
        }

        return .valid
    }

    private func validateTextLength(_ text: String, range: ClosedRange<Int>) -> ValidationResult {
        guard range.contains(text.count) else {
            return .invalid(reason: "Text length must be between \(range.lowerBound) and \(range.upperBound) characters")
        }
        return .valid
    }

    private func validateAlphanumeric(_ text: String) -> ValidationResult {
        let allowedCharacters = CharacterSet.alphanumerics
        guard CharacterSet(charactersIn: text).isSubset(of: allowedCharacters) else {
            return .invalid(reason: "Text must contain only letters and numbers")
        }
        return .valid
    }

    private func validateNumeric(_ text: String) -> ValidationResult {
        let allowedCharacters = CharacterSet.decimalDigits
        guard CharacterSet(charactersIn: text).isSubset(of: allowedCharacters) else {
            return .invalid(reason: "Text must contain only numbers")
        }
        return .valid
    }

    private func validatePhoneNumber(_ phone: String) -> ValidationResult {
        // Remove common separators
        let cleanPhone = phone.replacingOccurrences(of: "[\\s\\-()]", with: "", options: .regularExpression)

        guard cleanPhone.count >= 10 && cleanPhone.count <= 15 else {
            return .invalid(reason: "Phone number must be between 10 and 15 digits")
        }

        let allowedCharacters = CharacterSet.decimalDigits.union(CharacterSet(charactersIn: "+"))
        guard CharacterSet(charactersIn: cleanPhone).isSubset(of: allowedCharacters) else {
            return .invalid(reason: "Phone number can only contain digits and +")
        }

        return .valid
    }
}

// MARK: - Keychain Service Protocol

protocol KeychainServiceProtocol {
    func store(_ data: Data, forKey key: String) throws
    func retrieve(forKey key: String) throws -> Data?
    func delete(forKey key: String) throws
    func clearAll() throws
}

// MARK: - Keychain Service Implementation

final class KeychainService: KeychainServiceProtocol {

    enum KeychainError: LocalizedError {
        case duplicateEntry
        case unknown(status: OSStatus)

        var errorDescription: String? {
            switch self {
            case .duplicateEntry:
                return "Keychain item already exists"
            case .unknown(let status):
                return "Keychain error: \(status)"
            }
        }
    }

    func store(_ data: Data, forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        if status == errSecDuplicateItem {
            try update(data, forKey: key)
        } else if status != errSecSuccess {
            throw KeychainError.unknown(status: status)
        }
    }

    func retrieve(forKey key: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        } else if status != errSecSuccess {
            throw KeychainError.unknown(status: status)
        }

        return result as? Data
    }

    func update(_ data: Data, forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]

        let update: [String: Any] = [
            kSecValueData as String: data
        ]

        let status = SecItemUpdate(query as CFDictionary, update as CFDictionary)

        if status != errSecSuccess {
            throw KeychainError.unknown(status: status)
        }
    }

    func delete(forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)

        if status != errSecSuccess && status != errSecItemNotFound {
            throw KeychainError.unknown(status: status)
        }
    }

    func clearAll() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword
        ]

        let status = SecItemDelete(query as CFDictionary)

        if status != errSecSuccess && status != errSecItemNotFound {
            throw KeychainError.unknown(status: status)
        }
    }
}

// MARK: - Certificate Pinner Protocol

protocol CertificatePinnerProtocol {
    func validateChallenge(_ challenge: URLAuthenticationChallenge) -> Bool
}

// MARK: - Certificate Pinner Implementation

final class CertificatePinner: CertificatePinnerProtocol {

    private let pinnedCertificates: [String: [Data]] = [
        "api.proctrust.org.uk": [
            // Add your certificate fingerprints here
            // Example: Data(base64Encoded: "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA...")!
        ],
        "www.proctrust.org.uk": [
            // Add certificate fingerprints here
        ]
    ]

    func validateChallenge(_ challenge: URLAuthenticationChallenge) -> Bool {
        guard let serverTrust = challenge.protectionSpace.serverTrust else {
            return false
        }
        
        let host = challenge.protectionSpace.host

        // Get server certificates
        let certificates: [Data]
        if #available(iOS 15.0, *) {
            if let certificateChain = SecTrustCopyCertificateChain(serverTrust) {
                certificates = (0..<CFArrayGetCount(certificateChain))
                    .compactMap { CFArrayGetValueAtIndex(certificateChain, $0) }
                    .compactMap { Unmanaged<SecCertificate>.fromOpaque($0).takeUnretainedValue() }
                    .compactMap { SecCertificateCopyData($0) as Data }
            } else {
                certificates = []
            }
        } else {
            certificates = (0..<SecTrustGetCertificateCount(serverTrust))
                .compactMap { SecTrustGetCertificateAtIndex(serverTrust, $0) }
                .compactMap { SecCertificateCopyData($0) as Data }
        }

        // Get pinned certificates for this host
        guard let pinnedCerts = pinnedCertificates[host] else {
            PTLogger.security.warning("No pinned certificates for host: \(host)")
            return true // Allow if no pinning configured for this host
        }

        // Check if any server certificate matches our pinned certificates
        for cert in certificates {
            let certHash = SHA256.hash(data: cert).compactMap { String(format: "%02x", $0) }.joined()

            for pinnedCert in pinnedCerts {
                let pinnedHash = SHA256.hash(data: pinnedCert).compactMap { String(format: "%02x", $0) }.joined()

                if certHash == pinnedHash {
                    PTLogger.security.info("Certificate pinning successful for \(host)")
                    return true
                }
            }
        }

        PTLogger.security.error("Certificate pinning failed for \(host)")
        return false
    }
}

// MARK: - Security Logger Extension

