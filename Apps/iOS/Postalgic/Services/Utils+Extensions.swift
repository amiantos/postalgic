//
//  Utils+Extensions.swift
//  Postalgic
//
//  Created by Brad Root on 4/27/25.
//

import Foundation
import CommonCrypto

extension Data {
    /// Calculate the SHA-256 hash of the data
    func sha256Hash() -> String {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        self.withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(buffer.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}