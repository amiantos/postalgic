//
//  ManualPublisher.swift
//  Postalgic
//
//  Created by Brad Root on 4/26/25.
//

import Foundation
import ZIPFoundation

/// A publisher that creates a ZIP file for manual download
class ManualPublisher: Publisher {
    var publisherType: PublisherType = .none
    
    /// Zip the site directory and return the path to the zip file
    /// - Parameters:
    ///   - directoryURL: URL of the directory to zip
    ///   - statusUpdate: Closure to call with status updates during publishing
    /// - Returns: URL to the zip file
    /// - Throws: Error if zipping fails
    func publish(directoryURL: URL, statusUpdate: @escaping (String) -> Void) async throws -> URL? {
        statusUpdate("Creating ZIP file...")
        print("📝 Creating ZIP file from site directory: \(directoryURL.path)")
        
        // Create a temporary file URL for the zip file with a unique timestamp
        let timestamp = Int(Date().timeIntervalSince1970)
        let zipFileName = "site_\(timestamp).zip"
        let zipFilePath = FileManager.default.temporaryDirectory.appendingPathComponent(zipFileName)
        
        // Remove existing file if it exists
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: zipFilePath.path) {
            try fileManager.removeItem(at: zipFilePath)
            print("🗑️ Removed existing ZIP file at path: \(zipFilePath.path)")
        }
        
        // Make sure the directory exists
        try fileManager.createDirectory(
            at: zipFilePath.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        do {
            print("📦 Adding directory contents: \(directoryURL.path) to ZIP")
            statusUpdate("Adding files to ZIP...")
            
            // Zip the directory contents
            try fileManager.zipItem(at: directoryURL, to: zipFilePath, shouldKeepParent: false)
            
            print("✅ ZIP file created successfully at: \(zipFilePath.path)")
            statusUpdate("ZIP file created successfully")
            return zipFilePath
        } catch {
            print("❌ Error creating ZIP file: \(error.localizedDescription)")
            throw StaticSiteGenerator.SiteGeneratorError.publishingFailed("Failed to create ZIP file: \(error.localizedDescription)")
        }
    }
}