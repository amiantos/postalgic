//
//  Utils+Extensions.swift
//  Postalgic
//
//  Created by Brad Root on 4/27/25.
//

import Foundation
import CommonCrypto
import UIKit

struct Utils {
    static func extractYouTubeId(from url: String) -> String? {
        let patterns = [
            // youtu.be URLs
            "youtu\\.be\\/([a-zA-Z0-9_-]{11})",
            // youtube.com/watch?v= URLs
            "youtube\\.com\\/watch\\?v=([a-zA-Z0-9_-]{11})",
            // youtube.com/embed/ URLs
            "youtube\\.com\\/embed\\/([a-zA-Z0-9_-]{11})",
            "youtube\\.com\\/live\\/([a-zA-Z0-9_-]{11})"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: url, range: NSRange(url.startIndex..., in: url)),
               let range = Range(match.range(at: 1), in: url) {
                return String(url[range])
            }
        }
        
        return nil
    }
    
    /// Generates a URL-friendly stub from the given text
    /// - Parameters:
    ///   - text: The source text to generate a stub from
    ///   - maxLength: Maximum length of the stub (default: 60)
    /// - Returns: A URL-friendly slug with only lowercase alphanumeric characters and hyphens
    static func generateStub(from text: String, maxLength: Int = 60) -> String {
        // Start by trimming whitespace and converting to lowercase
        let lowercased = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // Replace spaces with hyphens
        var stub = lowercased.replacingOccurrences(of: " ", with: "-")
        
        // Remove any characters that are not alphanumeric or hyphens
        let allowedCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-")
        stub = stub.unicodeScalars.filter { allowedCharacters.contains($0) }.map { String($0) }.joined()
        
        // Replace multiple consecutive hyphens with a single hyphen
        while stub.contains("--") {
            stub = stub.replacingOccurrences(of: "--", with: "-")
        }
        
        // Trim hyphens from beginning and end
        stub = stub.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        
        // Truncate to max length if needed, ensuring we don't cut in the middle of a word
        if stub.count > maxLength {
            let truncated = String(stub.prefix(maxLength))
            if let lastHyphen = truncated.lastIndex(of: "-") {
                return String(truncated[..<lastHyphen])
            }
            return truncated
        }
        
        return stub
    }
    
    /// Ensures a stub is unique within the given collection of existing stubs
    /// - Parameters:
    ///   - stub: The original stub to check
    ///   - existingStubs: Collection of existing stubs to check against
    /// - Returns: A unique stub, appending -2, -3, etc. if needed
    static func makeStubUnique(stub: String, existingStubs: [String]) -> String {
        if !existingStubs.contains(stub) {
            return stub
        }

        var counter = 2
        var newStub = "\(stub)-\(counter)"

        while existingStubs.contains(newStub) {
            counter += 1
            newStub = "\(stub)-\(counter)"
        }

        return newStub
    }

    /// Optimizes and resizes an image to a maximum width while maintaining aspect ratio
    /// - Parameters:
    ///   - imageData: The original image data
    ///   - maxWidth: Maximum width for the optimized image (default: 1000)
    ///   - quality: JPEG compression quality (0.0 to 1.0, default: 0.8)
    /// - Returns: Optimized image data if successful, nil otherwise
    static func optimizeImage(imageData: Data, maxWidth: CGFloat = 1000, quality: CGFloat = 0.8) -> Data? {
        guard let originalImage = UIImage(data: imageData) else {
            return nil
        }

        // Calculate new dimensions, maintaining aspect ratio
        let originalSize = originalImage.size

        // If the width is already less than or equal to maxWidth, return original image data
        if originalSize.width <= maxWidth {
            // Still compress it for consistency
            return originalImage.jpegData(compressionQuality: quality)
        }

        // Calculate new dimensions maintaining aspect ratio
        let aspectRatio = originalSize.height / originalSize.width
        let newWidth = maxWidth
        let newHeight = maxWidth * aspectRatio
        let newSize = CGSize(width: newWidth, height: newHeight)

        // Create a new renderer for resizing
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        originalImage.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        // Convert to JPEG data with the specified quality
        return resizedImage?.jpegData(compressionQuality: quality)
    }

    /// Generates a unique filename for an embed image
    /// - Parameters:
    ///   - embed: The embed the image belongs to
    ///   - originalFilename: Original filename of the image (optional)
    ///   - order: Order index of the image in the embed
    /// - Returns: A unique filename for the image
    static func generateImageFilename(for embed: Embed, originalFilename: String? = nil, order: Int) -> String {
        let timestamp = Int(Date().timeIntervalSince1970)
        let uuid = UUID().uuidString.prefix(8)
        let orderString = String(format: "%02d", order)

        // Extract extension from original filename or use jpg by default
        let fileExtension: String
        if let originalFilename = originalFilename,
           let ext = originalFilename.components(separatedBy: ".").last,
           !ext.isEmpty {
            fileExtension = ext.lowercased()
        } else {
            fileExtension = "jpg"
        }

        return "embed-\(timestamp)-\(uuid)-\(orderString).\(fileExtension)"
    }
}

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
