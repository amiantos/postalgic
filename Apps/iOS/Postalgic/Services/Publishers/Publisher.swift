//
//  Publisher.swift
//  Postalgic
//
//  Created by Brad Root on 4/25/25.
//

import Foundation

/// Remote hash file structure for cross-client change detection
/// Stored at `.postalgic/hashes.json` on the published site
struct RemoteHashFile: Codable {
    let version: Int
    let lastPublishedDate: String
    let publishedBy: String
    let fileHashes: [String: String]

    init(publishedBy: String = "ios", fileHashes: [String: String]) {
        self.version = 1
        self.publishedBy = publishedBy
        self.lastPublishedDate = ISO8601DateFormatter().string(from: Date())
        self.fileHashes = fileHashes
    }
}

/// Protocol that all publishers must conform to
protocol Publisher {
    /// Publishes the entire site
    /// - Parameters:
    ///   - directoryURL: URL of the directory containing the site
    ///   - statusUpdate: Closure for providing status updates
    /// - Returns: Optional URL (for Manual publisher that returns a zip file)
    func publish(directoryURL: URL, statusUpdate: @escaping (String) -> Void) async throws -> URL?

    /// Publishes only modified files and removes deleted files
    /// - Parameters:
    ///   - directoryURL: URL of the directory containing the site
    ///   - modifiedFiles: List of file paths that have been modified or added
    ///   - deletedFiles: List of file paths that should be deleted
    ///   - statusUpdate: Closure for providing status updates
    /// - Returns: Optional URL (for Manual publisher that returns a zip file)
    func smartPublish(directoryURL: URL, modifiedFiles: [String], deletedFiles: [String], statusUpdate: @escaping (String) -> Void) async throws -> URL?

    /// The type of publisher
    var publisherType: PublisherType { get }

    /// Fetches remote hash file for cross-client change detection
    /// - Returns: RemoteHashFile if available, nil if not found
    func fetchRemoteHashes() async -> RemoteHashFile?

    /// Uploads hash file after successful publish
    /// - Parameter hashes: Dictionary of file paths to their SHA256 hashes
    func uploadHashFile(hashes: [String: String]) async throws
}

// Default implementations for backward compatibility
extension Publisher {
    func smartPublish(directoryURL: URL, modifiedFiles: [String], deletedFiles: [String], statusUpdate: @escaping (String) -> Void) async throws -> URL? {
        // By default, if publisher doesn't implement smart publishing, fall back to full publish
        statusUpdate("Smart publishing not implemented for this publisher type, falling back to full publish")
        return try await publish(directoryURL: directoryURL, statusUpdate: statusUpdate)
    }

    func fetchRemoteHashes() async -> RemoteHashFile? {
        // Default: no remote hashes available
        return nil
    }

    func uploadHashFile(hashes: [String: String]) async throws {
        // Default: no-op for publishers that don't support remote hash storage
    }
}
