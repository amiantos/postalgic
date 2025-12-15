//
//  SyncChecker.swift
//  Postalgic
//
//  Service for checking sync status and detecting changes
//  between local and remote sync data.
//

import Foundation

/// Result of checking for sync changes
struct SyncCheckResult {
    let hasChanges: Bool
    let localVersion: Int
    let remoteVersion: Int
    let newFiles: [ChangedFile]
    let modifiedFiles: [ChangedFile]
    let deletedFiles: [ChangedFile]
    let manifest: SyncImporter.SyncManifest?

    struct ChangedFile {
        let path: String
        let hash: String
        let size: Int?
        let encrypted: Bool
        let iv: String?
        let oldHash: String?
    }

    /// Check if there are entity-level changes (excluding indexes)
    var hasEntityChanges: Bool {
        let entityChangeCount = newFiles.filter { !$0.path.contains("index.json") }.count +
                                modifiedFiles.filter { !$0.path.contains("index.json") }.count +
                                deletedFiles.filter { !$0.path.contains("index.json") }.count
        return entityChangeCount > 0
    }

    /// Summary of changes for display
    var changeSummary: String {
        var parts: [String] = []
        if !newFiles.isEmpty {
            parts.append("\(newFiles.count) new")
        }
        if !modifiedFiles.isEmpty {
            parts.append("\(modifiedFiles.count) modified")
        }
        if !deletedFiles.isEmpty {
            parts.append("\(deletedFiles.count) deleted")
        }
        if parts.isEmpty {
            return "No changes"
        }
        return parts.joined(separator: ", ")
    }
}

/// Categorized changes by entity type
struct CategorizedChanges {
    var blog: EntityChanges = EntityChanges()
    var categories: EntityChanges = EntityChanges()
    var tags: EntityChanges = EntityChanges()
    var posts: EntityChanges = EntityChanges()
    var drafts: EntityChanges = EntityChanges()
    var sidebar: EntityChanges = EntityChanges()
    var staticFiles: EntityChanges = EntityChanges()
    var embedImages: EntityChanges = EntityChanges()
    var themes: EntityChanges = EntityChanges()

    struct EntityChanges {
        var new: [SyncCheckResult.ChangedFile] = []
        var modified: [SyncCheckResult.ChangedFile] = []
        var deleted: [SyncCheckResult.ChangedFile] = []

        var hasChanges: Bool {
            return !new.isEmpty || !modified.isEmpty || !deleted.isEmpty
        }
    }
}

class SyncChecker {

    enum CheckError: Error, LocalizedError {
        case noSyncUrl
        case networkError(String)
        case manifestNotFound

        var errorDescription: String? {
            switch self {
            case .noSyncUrl:
                return "Blog URL is not configured"
            case .networkError(let message):
                return "Network error: \(message)"
            case .manifestNotFound:
                return "Sync manifest not found. Make sure the site has sync enabled."
            }
        }
    }

    /// Check for changes between local blog and remote sync data
    /// - Parameters:
    ///   - blog: The local blog to check
    /// - Returns: SyncCheckResult with change details
    static func checkForChanges(blog: Blog) async throws -> SyncCheckResult {
        guard let syncUrl = blog.url, !syncUrl.isEmpty else {
            throw CheckError.noSyncUrl
        }

        // Get local sync state
        let localVersion = blog.lastSyncedVersion
        let localHashes = blog.localSyncHashes

        // Fetch remote manifest
        let manifest = try await SyncImporter.fetchManifest(from: syncUrl)
        let remoteVersion = manifest.syncVersion
        let remoteFiles = manifest.files

        // If versions match and we have local hashes, no changes
        if remoteVersion == localVersion && !localHashes.isEmpty {
            return SyncCheckResult(
                hasChanges: false,
                localVersion: localVersion,
                remoteVersion: remoteVersion,
                newFiles: [],
                modifiedFiles: [],
                deletedFiles: [],
                manifest: manifest
            )
        }

        // Compare file hashes
        var newFiles: [SyncCheckResult.ChangedFile] = []
        var modifiedFiles: [SyncCheckResult.ChangedFile] = []
        var deletedFiles: [SyncCheckResult.ChangedFile] = []

        // Check for new and modified files
        for (filePath, fileInfo) in remoteFiles {
            if localHashes[filePath] == nil {
                // New file
                newFiles.append(SyncCheckResult.ChangedFile(
                    path: filePath,
                    hash: fileInfo.hash,
                    size: fileInfo.size,
                    encrypted: fileInfo.encrypted ?? false,
                    iv: fileInfo.iv,
                    oldHash: nil
                ))
            } else if localHashes[filePath] != fileInfo.hash {
                // Modified file
                modifiedFiles.append(SyncCheckResult.ChangedFile(
                    path: filePath,
                    hash: fileInfo.hash,
                    size: fileInfo.size,
                    encrypted: fileInfo.encrypted ?? false,
                    iv: fileInfo.iv,
                    oldHash: localHashes[filePath]
                ))
            }
        }

        // Check for deleted files
        for (filePath, hash) in localHashes {
            if remoteFiles[filePath] == nil {
                deletedFiles.append(SyncCheckResult.ChangedFile(
                    path: filePath,
                    hash: hash,
                    size: nil,
                    encrypted: false,
                    iv: nil,
                    oldHash: hash
                ))
            }
        }

        let hasChanges = !newFiles.isEmpty || !modifiedFiles.isEmpty || !deletedFiles.isEmpty

        return SyncCheckResult(
            hasChanges: hasChanges,
            localVersion: localVersion,
            remoteVersion: remoteVersion,
            newFiles: newFiles,
            modifiedFiles: modifiedFiles,
            deletedFiles: deletedFiles,
            manifest: manifest
        )
    }

    /// Categorize changes by entity type
    /// - Parameter checkResult: The sync check result
    /// - Returns: CategorizedChanges with changes grouped by type
    static func categorizeChanges(_ checkResult: SyncCheckResult) -> CategorizedChanges {
        var categories = CategorizedChanges()

        func categorizeFile(_ file: SyncCheckResult.ChangedFile, list: inout [SyncCheckResult.ChangedFile]) {
            list.append(file)
        }

        func processFile(_ file: SyncCheckResult.ChangedFile, type: String) {
            let path = file.path

            if path == "blog.json" {
                switch type {
                case "new": categories.blog.new.append(file)
                case "modified": categories.blog.modified.append(file)
                case "deleted": categories.blog.deleted.append(file)
                default: break
                }
            } else if path.hasPrefix("categories/") && path != "categories/index.json" {
                switch type {
                case "new": categories.categories.new.append(file)
                case "modified": categories.categories.modified.append(file)
                case "deleted": categories.categories.deleted.append(file)
                default: break
                }
            } else if path.hasPrefix("tags/") && path != "tags/index.json" {
                switch type {
                case "new": categories.tags.new.append(file)
                case "modified": categories.tags.modified.append(file)
                case "deleted": categories.tags.deleted.append(file)
                default: break
                }
            } else if path.hasPrefix("posts/") && path != "posts/index.json" {
                switch type {
                case "new": categories.posts.new.append(file)
                case "modified": categories.posts.modified.append(file)
                case "deleted": categories.posts.deleted.append(file)
                default: break
                }
            } else if path.hasPrefix("drafts/") && path != "drafts/index.json.enc" {
                switch type {
                case "new": categories.drafts.new.append(file)
                case "modified": categories.drafts.modified.append(file)
                case "deleted": categories.drafts.deleted.append(file)
                default: break
                }
            } else if path.hasPrefix("sidebar/") && path != "sidebar/index.json" {
                switch type {
                case "new": categories.sidebar.new.append(file)
                case "modified": categories.sidebar.modified.append(file)
                case "deleted": categories.sidebar.deleted.append(file)
                default: break
                }
            } else if path.hasPrefix("static-files/") && path != "static-files/index.json" {
                switch type {
                case "new": categories.staticFiles.new.append(file)
                case "modified": categories.staticFiles.modified.append(file)
                case "deleted": categories.staticFiles.deleted.append(file)
                default: break
                }
            } else if path.hasPrefix("embed-images/") && path != "embed-images/index.json" {
                switch type {
                case "new": categories.embedImages.new.append(file)
                case "modified": categories.embedImages.modified.append(file)
                case "deleted": categories.embedImages.deleted.append(file)
                default: break
                }
            } else if path.hasPrefix("themes/") {
                switch type {
                case "new": categories.themes.new.append(file)
                case "modified": categories.themes.modified.append(file)
                case "deleted": categories.themes.deleted.append(file)
                default: break
                }
            }
        }

        for file in checkResult.newFiles {
            processFile(file, type: "new")
        }

        for file in checkResult.modifiedFiles {
            processFile(file, type: "modified")
        }

        for file in checkResult.deletedFiles {
            processFile(file, type: "deleted")
        }

        return categories
    }

    /// Extract entity ID from file path
    /// - Parameter filePath: The file path (e.g., 'posts/abc-123.json')
    /// - Returns: The entity ID or nil
    static func extractEntityId(from filePath: String) -> String? {
        // Match patterns like 'posts/abc-123.json' or 'drafts/xyz.json.enc'
        let pattern = #"/([^/]+)\.(json|json\.enc)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: filePath, range: NSRange(filePath.startIndex..., in: filePath)),
              let idRange = Range(match.range(at: 1), in: filePath) else {
            return nil
        }

        let id = String(filePath[idRange])
        return id != "index" ? id : nil
    }
}
