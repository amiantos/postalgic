//
//  KeychainService.swift
//  Postalgic
//
//  Created by Claude on 5/14/25.
//

import Foundation
import Security
import SwiftData

/// Service for securely storing and retrieving sensitive data in the Keychain
class KeychainService {
    
    enum KeychainError: Error {
        case duplicateItem
        case itemNotFound
        case unexpectedStatus(OSStatus)
    }
    
    // MARK: - Password Types
    
    /// Types of passwords that can be stored in the keychain
    enum PasswordType: String {
        case aws = "awsSecretAccessKey"
        case ftp = "ftpPassword"
        case git = "gitPassword"
    }
    
    // MARK: - Private Helpers
    
    /// Creates a keychain query dictionary for the specified blog and password type
    private static func keychainQuery(for blogId: PersistentIdentifier, type: PasswordType) -> [String: Any] {
        let serviceIdentifier = "com.postalgic.blog.\(type.rawValue)"
        guard let blogIdString = blogId.stringRepresentation() else { return [:] }
        
        return [
            kSecClass as String: kSecClassGenericPassword as String,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: blogIdString
        ]
    }
    
    // MARK: - Public Methods
    
    /// Stores a password in the keychain
    static func storePassword(_ password: String, for blogId: PersistentIdentifier, type: PasswordType) throws {
        guard let passwordData = password.data(using: .utf8) else {
            throw KeychainError.unexpectedStatus(errSecParam)
        }
        
        var query = keychainQuery(for: blogId, type: type)
        
        // First, check if the item already exists
        var existingItem: CFTypeRef?
        let searchStatus = SecItemCopyMatching(query as CFDictionary, &existingItem)
        
        if searchStatus == errSecSuccess {
            // Update existing item
            let attributesToUpdate: [String: Any] = [
                kSecValueData as String: passwordData
            ]
            
            let updateStatus = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
            guard updateStatus == errSecSuccess else {
                print("error update")
                throw KeychainError.unexpectedStatus(updateStatus)
            }
        } else if searchStatus == errSecItemNotFound {
            // Add new item
            query[kSecValueData as String] = passwordData
            
            let addStatus = SecItemAdd(query as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                print("error add")
                throw KeychainError.unexpectedStatus(addStatus)
            }
        } else {
            print("error search")
            throw KeychainError.unexpectedStatus(searchStatus)
        }
    }
    
    /// Retrieves a password from the keychain
    static func retrievePassword(for blogId: PersistentIdentifier, type: PasswordType) throws -> String {
        var query = keychainQuery(for: blogId, type: type)
        query[kSecReturnData as String] = kCFBooleanTrue
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status != errSecItemNotFound else {
            throw KeychainError.itemNotFound
        }
        
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
        
        guard let passwordData = result as? Data, 
              let password = String(data: passwordData, encoding: .utf8) else {
            throw KeychainError.unexpectedStatus(errSecDecode)
        }
        
        return password
    }
    
    /// Deletes a password from the keychain
    static func deletePassword(for blogId: PersistentIdentifier, type: PasswordType) throws {
        let query = keychainQuery(for: blogId, type: type)
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
    
    /// Deletes all passwords for a blog
    static func deleteAllPasswords(for blogId: PersistentIdentifier) throws {
        try deletePassword(for: blogId, type: .aws)
        try deletePassword(for: blogId, type: .ftp)
        try deletePassword(for: blogId, type: .git)
    }
    
    /// Checks if a password exists in the keychain
    static func passwordExists(for blogId: PersistentIdentifier, type: PasswordType) -> Bool {
        var query = keychainQuery(for: blogId, type: type)
        query[kSecReturnData as String] = kCFBooleanFalse
        
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
}

// MARK: - Blog Extension

extension Blog {
    /// Gets the AWS secret key from keychain
    func getAwsSecretAccessKey() -> String? {
        do {
            return try KeychainService.retrievePassword(for: persistentModelID, type: .aws)
        } catch {
            return nil
        }
    }
    
    /// Gets the FTP password from keychain
    func getFtpPassword() -> String? {
        do {
            return try KeychainService.retrievePassword(for: persistentModelID, type: .ftp)
        } catch {
            return nil
        }
    }
    
    /// Gets the Git password from keychain
    func getGitPassword() -> String? {
        do {
            return try KeychainService.retrievePassword(for: persistentModelID, type: .git)
        } catch {
            return nil
        }
    }
    
    /// Sets the AWS secret key in keychain
    func setAwsSecretAccessKey(_ password: String) {
        do {
            try KeychainService.storePassword(password, for: persistentModelID, type: .aws)
        } catch {
            print("Failed to store AWS secret key in keychain: \(error)")
        }
    }
    
    /// Sets the FTP password in keychain
    func setFtpPassword(_ password: String) {
        do {
            try KeychainService.storePassword(password, for: persistentModelID, type: .ftp)
        } catch {
            print("Failed to store FTP password in keychain: \(error)")
        }
    }
    
    /// Sets the Git password in keychain
    func setGitPassword(_ password: String) {
        do {
            try KeychainService.storePassword(password, for: persistentModelID, type: .git)
        } catch {
            print("Failed to store Git password in keychain: \(error)")
        }
    }

    /// Updates the property checks to use the new keychain-based methods
    var hasAwsConfiguredSecurely: Bool {
        return awsRegion != nil && !awsRegion!.isEmpty && awsS3Bucket != nil
            && !awsS3Bucket!.isEmpty && awsCloudFrontDistId != nil
            && !awsCloudFrontDistId!.isEmpty && awsAccessKeyId != nil
            && !awsAccessKeyId!.isEmpty && (getAwsSecretAccessKey() != nil)
    }
    
    var hasFtpConfiguredSecurely: Bool {
        return ftpHost != nil && !ftpHost!.isEmpty && ftpUsername != nil
            && !ftpUsername!.isEmpty && (getFtpPassword() != nil)
            && ftpPath != nil && !ftpPath!.isEmpty && ftpPort != nil
    }
    
    var hasGitConfiguredSecurely: Bool {
        return gitRepositoryUrl != nil && !gitRepositoryUrl!.isEmpty 
            && gitUsername != nil && !gitUsername!.isEmpty 
            && (getGitPassword() != nil)
            && gitBranch != nil && !gitBranch!.isEmpty
    }
}
