//
//  SyncEncryption.swift
//  Postalgic
//
//  Created by Claude on 12/14/25.
//

import Foundation
import CryptoKit
import CommonCrypto

/// Service for encrypting and decrypting sync data
class SyncEncryption {

    enum EncryptionError: Error, LocalizedError {
        case invalidPassword
        case encryptionFailed
        case decryptionFailed
        case invalidData

        var errorDescription: String? {
            switch self {
            case .invalidPassword:
                return "Invalid password provided"
            case .encryptionFailed:
                return "Failed to encrypt data"
            case .decryptionFailed:
                return "Failed to decrypt data"
            case .invalidData:
                return "Invalid data format"
            }
        }
    }

    /// Number of PBKDF2 iterations for key derivation
    static let pbkdf2Iterations: UInt32 = 100_000

    /// Salt size in bytes
    static let saltSize = 16

    /// IV/Nonce size in bytes (12 bytes for AES-GCM)
    static let ivSize = 12

    // MARK: - Key Derivation

    /// Derives a symmetric key from a password using PBKDF2
    /// - Parameters:
    ///   - password: The password to derive the key from
    ///   - salt: The salt to use (16 bytes)
    /// - Returns: A 256-bit symmetric key
    static func deriveKey(password: String, salt: Data) -> SymmetricKey {
        var derivedKey = Data(count: 32) // 256 bits

        derivedKey.withUnsafeMutableBytes { derivedKeyBytes in
            password.data(using: .utf8)!.withUnsafeBytes { passwordBytes in
                salt.withUnsafeBytes { saltBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes.baseAddress?.assumingMemoryBound(to: Int8.self),
                        password.utf8.count,
                        saltBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        pbkdf2Iterations,
                        derivedKeyBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        32
                    )
                }
            }
        }

        return SymmetricKey(data: derivedKey)
    }

    /// Generates a random salt for key derivation
    /// - Returns: 16 random bytes
    static func generateSalt() -> Data {
        var salt = Data(count: saltSize)
        _ = salt.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, saltSize, bytes.baseAddress!)
        }
        return salt
    }

    /// Generates a random IV/nonce for encryption
    /// - Returns: 12 random bytes (standard AES-GCM nonce size)
    static func generateIV() -> Data {
        var iv = Data(count: ivSize)
        _ = iv.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, ivSize, bytes.baseAddress!)
        }
        return iv
    }

    // MARK: - Encryption

    /// Encrypts data using AES-256-GCM
    /// - Parameters:
    ///   - data: The data to encrypt
    ///   - key: The symmetric key to use
    /// - Returns: A tuple containing the ciphertext (including auth tag) and the IV used
    /// - Throws: EncryptionError if encryption fails
    static func encrypt(data: Data, key: SymmetricKey) throws -> (ciphertext: Data, iv: Data) {
        do {
            let nonce = AES.GCM.Nonce()
            let sealedBox = try AES.GCM.seal(data, using: key, nonce: nonce)

            // Combine ciphertext and tag
            let ciphertext = sealedBox.ciphertext + sealedBox.tag

            return (ciphertext, Data(nonce))
        } catch {
            throw EncryptionError.encryptionFailed
        }
    }

    /// Encrypts data using AES-256-GCM with a specific IV
    /// - Parameters:
    ///   - data: The data to encrypt
    ///   - key: The symmetric key to use
    ///   - iv: The IV/nonce to use
    /// - Returns: The ciphertext (including auth tag)
    /// - Throws: EncryptionError if encryption fails
    static func encrypt(data: Data, key: SymmetricKey, iv: Data) throws -> Data {
        do {
            let nonce = try AES.GCM.Nonce(data: iv)
            let sealedBox = try AES.GCM.seal(data, using: key, nonce: nonce)

            // Combine ciphertext and tag
            return sealedBox.ciphertext + sealedBox.tag
        } catch {
            throw EncryptionError.encryptionFailed
        }
    }

    // MARK: - Decryption

    /// Decrypts data using AES-256-GCM
    /// - Parameters:
    ///   - ciphertext: The encrypted data (ciphertext + auth tag)
    ///   - iv: The IV/nonce that was used for encryption
    ///   - key: The symmetric key to use
    /// - Returns: The decrypted data
    /// - Throws: EncryptionError if decryption fails
    static func decrypt(ciphertext: Data, iv: Data, key: SymmetricKey) throws -> Data {
        do {
            let nonce = try AES.GCM.Nonce(data: iv)

            // Separate ciphertext and tag (tag is last 16 bytes)
            guard ciphertext.count > 16 else {
                throw EncryptionError.invalidData
            }

            let encryptedData = ciphertext.dropLast(16)
            let tag = ciphertext.suffix(16)

            let sealedBox = try AES.GCM.SealedBox(nonce: nonce, ciphertext: encryptedData, tag: tag)
            return try AES.GCM.open(sealedBox, using: key)
        } catch let error as EncryptionError {
            throw error
        } catch {
            throw EncryptionError.decryptionFailed
        }
    }

    // MARK: - Convenience Methods

    /// Encrypts JSON-encodable data
    /// - Parameters:
    ///   - value: The value to encrypt
    ///   - password: The password to use
    ///   - salt: The salt for key derivation
    /// - Returns: A tuple containing the ciphertext and IV
    /// - Throws: EncryptionError if encoding or encryption fails
    static func encryptJSON<T: Encodable>(_ value: T, password: String, salt: Data) throws -> (ciphertext: Data, iv: Data) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        let jsonData = try encoder.encode(value)
        let key = deriveKey(password: password, salt: salt)

        return try encrypt(data: jsonData, key: key)
    }

    /// Decrypts data to a JSON-decodable type
    /// - Parameters:
    ///   - ciphertext: The encrypted data
    ///   - iv: The IV used for encryption
    ///   - password: The password to use
    ///   - salt: The salt for key derivation
    ///   - type: The type to decode to
    /// - Returns: The decoded value
    /// - Throws: EncryptionError if decryption or decoding fails
    static func decryptJSON<T: Decodable>(_ ciphertext: Data, iv: Data, password: String, salt: Data, as type: T.Type) throws -> T {
        let key = deriveKey(password: password, salt: salt)
        let jsonData = try decrypt(ciphertext: ciphertext, iv: iv, key: key)

        let decoder = JSONDecoder()
        return try decoder.decode(type, from: jsonData)
    }

    // MARK: - Base64 Helpers

    /// Encodes data to URL-safe base64
    /// - Parameter data: The data to encode
    /// - Returns: Base64-encoded string
    static func base64Encode(_ data: Data) -> String {
        return data.base64EncodedString()
    }

    /// Decodes URL-safe base64 to data
    /// - Parameter string: The base64 string to decode
    /// - Returns: Decoded data, or nil if invalid
    static func base64Decode(_ string: String) -> Data? {
        return Data(base64Encoded: string)
    }
}
