//
//  PublishedFiles.swift
//  Postalgic
//
//  Created by Brad Root on 4/27/25.
//

import Foundation
import SwiftData

/// Stores information about files published for a blog
@Model
final class PublishedFiles {
    var publisherType: String
    var lastPublishedDate: Date
    var fileHashes: [String: String] // path: contentHash
    
    var blog: Blog?
    
    init(blog: Blog, publisherType: String) {
        self.blog = blog
        self.publisherType = publisherType
        self.lastPublishedDate = Date()
        self.fileHashes = [:]
    }
    
    func updateHashes(_ newHashes: [String: String]) {
        self.fileHashes = newHashes
        self.lastPublishedDate = Date()
    }
    
    func determineChanges(with newHashes: [String: String]) -> FileChanges {
        let existingPaths = Set(fileHashes.keys)
        let newPaths = Set(newHashes.keys)
        
        // New or changed files
        var modified: [String] = []
        
        for path in newPaths {
            if let existingHash = fileHashes[path] {
                if existingHash != newHashes[path] {
                    modified.append(path)
                }
            } else {
                modified.append(path)
            }
        }
        
        let deleted = existingPaths.subtracting(newPaths).sorted()
        
        // If the only changes are rss.xml and/or sitemap.xml, ignore them
        // as they don't need updates unless other content has changed
        if modified.count <= 2 && deleted.isEmpty {
            let nonEssentialFiles = Set(["rss.xml", "sitemap.xml"])
            let modifiedSet = Set(modified)
            
            // Check if all modified files are just rss.xml and/or sitemap.xml
            if modifiedSet.isSubset(of: nonEssentialFiles) {
                // No real changes, so clear the modified list
                modified = []
            }
        }
        
        return FileChanges(
            modified: modified,
            deleted: Array(deleted)
        )
    }
}

struct FileChanges {
    let modified: [String]
    let deleted: [String]
    
    var hasChanges: Bool {
        return !modified.isEmpty || !deleted.isEmpty
    }
}
