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
        
        // Create a temporary file URL for the zip file
        let zipFileName = "site_\(Int(Date().timeIntervalSince1970)).zip"
        let zipFilePath = FileManager.default.temporaryDirectory.appendingPathComponent(zipFileName)
        
        // Create the zip file
        guard let archive = Archive(url: zipFilePath, accessMode: .create) else {
            throw StaticSiteGenerator.SiteGeneratorError.zipCreationFailed
        }
        
        let directoryContents = try FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        
        // Get total count of items to add to the archive
        var totalItems = directoryContents.count
        
        // Add special directories that might not be counted in directoryContents
        if FileManager.default.fileExists(atPath: directoryURL.appendingPathComponent("css").path) {
            totalItems += 1
        }
        
        // Add each file and directory to the zip file
        var itemsProcessed = 0
        for fileURL in directoryContents {
            let relativePath = fileURL.lastPathComponent
            let isDirectory = (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            
            if isDirectory {
                try self.addDirectoryToArchive(
                    archive: archive,
                    directoryURL: fileURL,
                    relativePath: relativePath,
                    statusUpdate: { message in
                        statusUpdate("\(message) (\(itemsProcessed)/\(totalItems))")
                    }
                )
            } else {
                try archive.addEntry(
                    with: relativePath,
                    relativeTo: directoryURL,
                    compressionMethod: .deflate
                )
            }
            
            itemsProcessed += 1
            statusUpdate("Added \(relativePath) to ZIP (\(itemsProcessed)/\(totalItems))")
        }
        
        statusUpdate("ZIP file created successfully")
        return zipFilePath
    }
    
    /// Recursively add a directory and its contents to the zip archive
    /// - Parameters:
    ///   - archive: The zip archive
    ///   - directoryURL: The directory to add
    ///   - relativePath: The relative path within the zip file
    ///   - statusUpdate: Closure to call with status updates
    private func addDirectoryToArchive(
        archive: Archive,
        directoryURL: URL,
        relativePath: String,
        statusUpdate: @escaping (String) -> Void
    ) throws {
        let fileManager = FileManager.default
        let directoryContents = try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        
        for fileURL in directoryContents {
            let fileRelativePath = relativePath + "/" + fileURL.lastPathComponent
            let isDirectory = (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            
            if isDirectory {
                try self.addDirectoryToArchive(
                    archive: archive,
                    directoryURL: fileURL,
                    relativePath: fileRelativePath,
                    statusUpdate: statusUpdate
                )
            } else {
                try archive.addEntry(
                    with: fileRelativePath,
                    relativeTo: directoryURL.deletingLastPathComponent(),
                    compressionMethod: .deflate
                )
                statusUpdate("Added \(fileRelativePath) to ZIP")
            }
        }
    }
}