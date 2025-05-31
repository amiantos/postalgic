//
//  Utils+Extensions.swift
//  Postalgic
//
//  Created by Brad Root on 4/27/25.
//

import Foundation
import CommonCrypto
import UIKit
import SwiftData
import ImageIO

enum ImageFormat {
    case png
    case jpeg
    case gif
    case webp
    case unknown
}

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
    ///   - maxLength: Maximum length of the stub (default: 40)
    /// - Returns: A URL-friendly slug with only lowercase alphanumeric characters and hyphens
    static func generateStub(from text: String, maxLength: Int = 50) -> String {
        // Start by trimming whitespace and converting to lowercase
        let lowercased = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // Normalize the string to decompose accented characters
        let normalized = lowercased.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        
        // Define allowed characters and create an inverted set for non-allowed characters
        let allowedCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-")
        let nonAllowedCharacters = allowedCharacters.inverted
        
        // Replace non-allowed characters with hyphens, including spaces and slashes
        var stub = normalized.components(separatedBy: nonAllowedCharacters).joined(separator: "-")
        
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

    /// Resizes an image to specific dimensions
    /// - Parameters:
    ///   - imageData: The original image data
    ///   - targetSize: The target size for the resized image
    ///   - quality: JPEG compression quality (0.0 to 1.0, default: 0.8)
    /// - Returns: Resized image data if successful, nil otherwise
    static func resizeImage(imageData: Data, to targetSize: CGSize, quality: CGFloat = 0.8) -> Data? {
        guard let originalImage = UIImage(data: imageData) else {
            return nil
        }
        
        // Create a new renderer for resizing
        UIGraphicsBeginImageContextWithOptions(targetSize, false, 1.0)
        originalImage.draw(in: CGRect(origin: .zero, size: targetSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        // Convert to PNG data for better quality with icons
        return resizedImage?.pngData()
    }
    
    /// Optimizes and resizes an image to a maximum dimension of 1024 pixels while preserving format and transparency
    /// - Parameters:
    ///   - imageData: The original image data
    ///   - maxDimension: Maximum dimension (width or height) for the optimized image (default: 1024)
    ///   - quality: JPEG compression quality (0.0 to 1.0, default: 0.8)
    /// - Returns: Optimized image data if successful, nil otherwise
    static func optimizeImage(imageData: Data, maxDimension: CGFloat = 1024, quality: CGFloat = 0.8) -> Data? {
        guard let originalImage = UIImage(data: imageData) else {
            return nil
        }

        // Detect original format by checking the data signature
        let originalFormat = detectImageFormat(from: imageData)
        
        // Strip metadata first to remove EXIF/location data
        let cleanedData = stripImageMetadata(from: imageData) ?? imageData

        // Calculate new dimensions, maintaining aspect ratio
        let originalSize = originalImage.size

        // If both dimensions are already smaller than maxDimension, just strip metadata and preserve format
        if originalSize.width <= maxDimension && originalSize.height <= maxDimension {
            // For already-small images, preserve original format
            if originalFormat == .png {
                return cleanedData
            } else if originalFormat == .gif {
                // For GIFs that don't need resizing, keep original to preserve animation
                return imageData // Return original data to preserve animation
            } else {
                // For JPEG and other formats, apply compression
                return originalImage.jpegData(compressionQuality: quality)
            }
        }

        // Determine which dimension is larger to constrain properly
        var newWidth: CGFloat
        var newHeight: CGFloat

        if originalSize.width > originalSize.height {
            // Width-constrained
            newWidth = maxDimension
            newHeight = (maxDimension / originalSize.width) * originalSize.height
        } else {
            // Height-constrained
            newHeight = maxDimension
            newWidth = (maxDimension / originalSize.height) * originalSize.width
        }

        let newSize = CGSize(width: newWidth, height: newHeight)

        // For GIF files, we can't easily preserve animation during resize, so convert to PNG to maintain transparency
        if originalFormat == .gif {
            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
            originalImage.draw(in: CGRect(origin: .zero, size: newSize))
            let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            return resizedImage?.pngData()
        }
        
        // For PNG files, preserve transparency
        if originalFormat == .png {
            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
            originalImage.draw(in: CGRect(origin: .zero, size: newSize))
            let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            return resizedImage?.pngData()
        }

        // For all other formats (JPEG, WEBP, etc.), use JPEG with compression
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        originalImage.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return resizedImage?.jpegData(compressionQuality: quality)
    }
    
    /// Detects the format of an image from its data signature
    /// - Parameter imageData: The image data to analyze
    /// - Returns: The detected image format
    private static func detectImageFormat(from imageData: Data) -> ImageFormat {
        guard imageData.count >= 4 else { return .unknown }
        
        let bytes = imageData.prefix(4).map { $0 }
        
        // PNG signature: 89 50 4E 47
        if bytes.count >= 4 && bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47 {
            return .png
        }
        
        // JPEG signature: FF D8
        if bytes.count >= 2 && bytes[0] == 0xFF && bytes[1] == 0xD8 {
            return .jpeg
        }
        
        // GIF signature: 47 49 46
        if bytes.count >= 3 && bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 {
            return .gif
        }
        
        // WEBP signature: check for "WEBP" at offset 8
        if imageData.count >= 12 {
            let webpBytes = imageData.subdata(in: 8..<12).map { $0 }
            if webpBytes[0] == 0x57 && webpBytes[1] == 0x45 && webpBytes[2] == 0x42 && webpBytes[3] == 0x50 {
                return .webp
            }
        }
        
        return .unknown
    }
    
    /// Strips metadata (EXIF, location, etc.) from image data
    /// - Parameter imageData: The original image data
    /// - Returns: Image data with metadata stripped, or nil if processing failed
    private static func stripImageMetadata(from imageData: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let imageType = CGImageSourceGetType(source) else {
            return nil
        }
        
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(mutableData, imageType, 1, nil) else {
            return nil
        }
        
        // Create options to strip metadata
        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: 0.8,
            kCGImageDestinationMetadata: [:] // Empty metadata dictionary removes all metadata
        ]
        
        CGImageDestinationAddImageFromSource(destination, source, 0, options as CFDictionary)
        
        if CGImageDestinationFinalize(destination) {
            return mutableData as Data
        }
        
        return nil
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
    
    /// Generates a unique filename for an embed image based on image data format
    /// - Parameters:
    ///   - embed: The embed the image belongs to
    ///   - imageData: The image data to detect format from
    ///   - order: Order index of the image in the embed
    /// - Returns: A unique filename with appropriate extension for the image format
    static func generateImageFilename(for embed: Embed, imageData: Data, order: Int) -> String {
        let timestamp = Int(Date().timeIntervalSince1970)
        let uuid = UUID().uuidString.prefix(8)
        let orderString = String(format: "%02d", order)

        // Detect format and use appropriate extension
        let format = detectImageFormat(from: imageData)
        let fileExtension: String
        
        // Determine final format based on processing logic
        switch format {
        case .png:
            fileExtension = "png"
        case .gif:
            // Check if GIF will need resizing
            if let originalImage = UIImage(data: imageData) {
                let originalSize = originalImage.size
                if originalSize.width <= 1024 && originalSize.height <= 1024 {
                    fileExtension = "gif" // Keep as GIF if no resizing needed
                } else {
                    fileExtension = "png" // Convert to PNG if resizing needed
                }
            } else {
                fileExtension = "gif" // Default to GIF if we can't read the image
            }
        case .jpeg:
            fileExtension = "jpg"
        case .webp:
            fileExtension = "jpg" // WEBP converted to JPEG
        case .unknown:
            fileExtension = "jpg" // Default fallback
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

extension PersistentIdentifier {

    public func stringRepresentation() -> String? {
        if let encoded = try? JSONEncoder().encode(self),
           let dictionary = try? JSONSerialization.jsonObject(with: encoded) as? [String: Any],
           let implementation = dictionary["implementation"] as? [String: Any],
           let uriRepresentation = implementation["uriRepresentation"] as? String {
            return uriRepresentation as String
        } else {
            return  nil
        }
    } }
