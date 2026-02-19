//
//  RemoteServer.swift
//  Postalgic
//
//  Created by Claude on 2/18/26.
//

import Foundation
import SwiftData
import Security

@Model
final class RemoteServer {
    var name: String
    var url: String
    var username: String
    var createdAt: Date

    init(name: String, url: String, username: String, createdAt: Date = Date()) {
        self.name = name
        self.url = url.hasSuffix("/") ? String(url.dropLast()) : url
        self.username = username
        self.createdAt = createdAt
    }

    /// Normalized base URL (no trailing slash)
    var baseURL: String {
        url.hasSuffix("/") ? String(url.dropLast()) : url
    }

    /// Basic Auth header for authenticated requests
    var authHeader: String {
        let password = getPassword() ?? ""
        let credentials = "\(username):\(password)"
        let data = Data(credentials.utf8)
        return "Basic \(data.base64EncodedString())"
    }

    // MARK: - Keychain Password Management

    /// Stores the password in the Keychain
    func setPassword(_ password: String) {
        RemoteServerKeychain.store(password: password, for: keychainKey)
    }

    /// Retrieves the password from the Keychain
    func getPassword() -> String? {
        RemoteServerKeychain.retrieve(for: keychainKey)
    }

    /// Deletes the password from the Keychain
    func deletePassword() {
        RemoteServerKeychain.delete(for: keychainKey)
    }

    /// Whether a password is stored
    var hasPassword: Bool {
        RemoteServerKeychain.exists(for: keychainKey)
    }

    /// Unique keychain key derived from the server's persistent model ID
    private var keychainKey: String {
        persistentModelID.stringRepresentation() ?? "\(url):\(username)"
    }
}

// MARK: - Keychain Helper for Remote Servers

enum RemoteServerKeychain {
    private static let service = "com.postalgic.remoteserver"

    static func store(password: String, for account: String) {
        guard let data = password.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        // Try to update first
        var existing: CFTypeRef?
        let searchStatus = SecItemCopyMatching(query as CFDictionary, &existing)

        if searchStatus == errSecSuccess {
            let update: [String: Any] = [kSecValueData as String: data]
            SecItemUpdate(query as CFDictionary, update as CFDictionary)
        } else {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    static func retrieve(for account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let password = String(data: data, encoding: .utf8) else {
            return nil
        }
        return password
    }

    static func delete(for account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }

    static func exists(for account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: false
        ]
        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }
}
