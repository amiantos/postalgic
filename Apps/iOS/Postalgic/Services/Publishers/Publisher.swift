//
//  Publisher.swift
//  Postalgic
//
//  Created by Brad Root on 4/25/25.
//

import Foundation

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
}

// Default implementation that calls full publish for backward compatibility
extension Publisher {
    func smartPublish(directoryURL: URL, modifiedFiles: [String], deletedFiles: [String], statusUpdate: @escaping (String) -> Void) async throws -> URL? {
        // By default, if publisher doesn't implement smart publishing, fall back to full publish
        statusUpdate("Smart publishing not implemented for this publisher type, falling back to full publish")
        return try await publish(directoryURL: directoryURL, statusUpdate: statusUpdate)
    }
}
