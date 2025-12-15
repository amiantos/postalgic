//
//  SyncDataGenerator.swift
//  Postalgic
//
//  Created by Claude on 12/14/25.
//

import Foundation
import SwiftData

/// Service for generating sync data directory
class SyncDataGenerator {

    enum SyncError: Error, LocalizedError {
        case noSyncPassword
        case failedToCreateDirectory
        case failedToWriteFile(String)
        case encryptionFailed(String)

        var errorDescription: String? {
            switch self {
            case .noSyncPassword:
                return "No sync password configured"
            case .failedToCreateDirectory:
                return "Failed to create sync directory"
            case .failedToWriteFile(let filename):
                return "Failed to write file: \(filename)"
            case .encryptionFailed(let message):
                return "Encryption failed: \(message)"
            }
        }
    }

    /// Converts a SwiftData persistent model ID to a safe filename-compatible string
    /// The persistentModelID.stringRepresentation() returns URLs like:
    /// "x-coredata://UUID/EntityName/rowID" which contain slashes
    /// This function creates a safe, consistent identifier
    private static func safeId(from persistentModelID: PersistentIdentifier) -> String {
        guard let stringRep = persistentModelID.stringRepresentation() else {
            return UUID().uuidString
        }
        // Replace unsafe characters with dashes to create a valid filename
        // x-coredata://UUID/Entity/p123 -> x-coredata--UUID-Entity-p123
        return stringRep
            .replacingOccurrences(of: "://", with: "--")
            .replacingOccurrences(of: "/", with: "-")
    }

    // MARK: - Sync Data Models

    struct SyncManifest: Codable {
        let version: String
        let syncVersion: Int
        let lastModified: String
        let appSource: String
        let appVersion: String
        let blogName: String
        let hasDrafts: Bool
        let encryption: EncryptionInfo?
        var files: [String: FileInfo]

        struct EncryptionInfo: Codable {
            let method: String
            let salt: String
            let iterations: Int
        }

        struct FileInfo: Codable {
            let hash: String
            var size: Int
            var modified: String?
            var encrypted: Bool?
            var iv: String?
        }
    }

    struct SyncBlog: Codable {
        let name: String
        let url: String
        let tagline: String?
        let authorName: String?
        let authorUrl: String?
        let authorEmail: String?
        let timezone: String
        let colors: ColorSettings
        let themeIdentifier: String?

        struct ColorSettings: Codable {
            let accent: String?
            let background: String?
            let text: String?
            let lightShade: String?
            let mediumShade: String?
            let darkShade: String?
        }
    }

    struct SyncPostIndex: Codable {
        let posts: [PostIndexEntry]

        struct PostIndexEntry: Codable {
            let id: String
            let stub: String?
            let hash: String
            let modified: String
        }
    }

    struct SyncDraftIndex: Codable {
        let drafts: [DraftIndexEntry]

        struct DraftIndexEntry: Codable {
            let id: String
            let hash: String
            let modified: String
        }
    }

    struct SyncPost: Codable {
        let id: String
        let title: String?
        let content: String
        let stub: String?
        let createdAt: String
        let updatedAt: String
        let categoryId: String?
        let tagIds: [String]
        let embed: SyncEmbed?
    }

    struct SyncEmbed: Codable {
        let type: String
        let position: String
        let url: String
        let title: String?
        let description: String?
        let imageUrl: String?
        let imageFilename: String?
        let images: [SyncEmbedImage]
    }

    struct SyncEmbedImage: Codable {
        let filename: String
        let order: Int
    }

    struct SyncCategoryIndex: Codable {
        let categories: [CategoryIndexEntry]

        struct CategoryIndexEntry: Codable {
            let id: String
            let stub: String?
            let hash: String
        }
    }

    struct SyncCategory: Codable {
        let id: String
        let name: String
        let description: String?
        let stub: String?
        let createdAt: String
    }

    struct SyncTagIndex: Codable {
        let tags: [TagIndexEntry]

        struct TagIndexEntry: Codable {
            let id: String
            let stub: String?
            let hash: String
        }
    }

    struct SyncTag: Codable {
        let id: String
        let name: String
        let stub: String?
        let createdAt: String
    }

    struct SyncSidebarIndex: Codable {
        let sidebar: [SidebarIndexEntry]

        struct SidebarIndexEntry: Codable {
            let id: String
            let hash: String
        }
    }

    struct SyncSidebarObject: Codable {
        let id: String
        let type: String
        let title: String
        let content: String?
        let order: Int
        let links: [SyncLink]?
    }

    struct SyncLink: Codable {
        let title: String
        let url: String
        let order: Int
    }

    struct SyncStaticFilesIndex: Codable {
        let files: [StaticFileEntry]

        struct StaticFileEntry: Codable {
            let filename: String
            let mimeType: String
            let isSpecialFile: Bool
            let specialFileType: String?
            let hash: String
            let size: Int
        }
    }

    struct SyncTheme: Codable {
        let identifier: String
        let name: String
        let templates: [String: String]
    }

    // MARK: - Date Formatter

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    // MARK: - Main Generation Method

    /// Generates the sync directory for a blog
    /// - Parameters:
    ///   - blog: The blog to generate sync data for
    ///   - siteDirectory: The root site directory
    ///   - password: The sync password for encrypting drafts
    ///   - statusUpdate: Closure for status updates
    /// - Returns: Dictionary of file paths to their hashes
    static func generateSyncDirectory(
        for blog: Blog,
        in siteDirectory: URL,
        password: String,
        statusUpdate: @escaping (String) -> Void
    ) throws -> [String: String] {
        let fileManager = FileManager.default
        let syncDirectory = siteDirectory.appendingPathComponent("sync")

        // Create sync directory structure
        statusUpdate("Creating sync directory structure...")
        try fileManager.createDirectory(at: syncDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: syncDirectory.appendingPathComponent("posts"), withIntermediateDirectories: true)
        try fileManager.createDirectory(at: syncDirectory.appendingPathComponent("drafts"), withIntermediateDirectories: true)
        try fileManager.createDirectory(at: syncDirectory.appendingPathComponent("categories"), withIntermediateDirectories: true)
        try fileManager.createDirectory(at: syncDirectory.appendingPathComponent("tags"), withIntermediateDirectories: true)
        try fileManager.createDirectory(at: syncDirectory.appendingPathComponent("sidebar"), withIntermediateDirectories: true)
        try fileManager.createDirectory(at: syncDirectory.appendingPathComponent("static-files"), withIntermediateDirectories: true)
        try fileManager.createDirectory(at: syncDirectory.appendingPathComponent("embed-images"), withIntermediateDirectories: true)
        try fileManager.createDirectory(at: syncDirectory.appendingPathComponent("themes"), withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        var fileHashes: [String: String] = [:]

        // Generate salt for encryption (will be stored in manifest)
        let salt = SyncEncryption.generateSalt()

        // Build ID maps using SwiftData persistent IDs
        var categoryIdMap: [String: String] = [:]
        var tagIdMap: [String: String] = [:]

        // Generate category IDs
        for category in blog.categories {
            let id = safeId(from: category.persistentModelID)
            categoryIdMap[id] = id
        }

        // Generate tag IDs
        for tag in blog.tags {
            let id = safeId(from: tag.persistentModelID)
            tagIdMap[id] = id
        }

        // MARK: Generate blog.json
        statusUpdate("Generating blog settings...")
        let syncBlog = SyncBlog(
            name: blog.name,
            url: blog.url,
            tagline: blog.tagline,
            authorName: blog.authorName,
            authorUrl: blog.authorUrl,
            authorEmail: blog.authorEmail,
            timezone: "UTC", // TODO: Add timezone support
            colors: SyncBlog.ColorSettings(
                accent: blog.accentColor,
                background: blog.backgroundColor,
                text: blog.textColor,
                lightShade: blog.lightShade,
                mediumShade: blog.mediumShade,
                darkShade: blog.darkShade
            ),
            themeIdentifier: blog.themeIdentifier
        )
        let blogData = try encoder.encode(syncBlog)
        let blogPath = syncDirectory.appendingPathComponent("blog.json")
        try blogData.write(to: blogPath)
        fileHashes["blog.json"] = blogData.sha256Hash()

        // MARK: Generate categories
        statusUpdate("Generating categories...")
        var categoryIndexEntries: [SyncCategoryIndex.CategoryIndexEntry] = []

        for category in blog.categories {
            let id = safeId(from: category.persistentModelID)
            let syncCategory = SyncCategory(
                id: id,
                name: category.name,
                description: category.categoryDescription,
                stub: category.stub,
                createdAt: isoFormatter.string(from: category.createdAt)
            )
            let categoryData = try encoder.encode(syncCategory)
            let categoryPath = syncDirectory.appendingPathComponent("categories/\(id).json")
            try categoryData.write(to: categoryPath)
            let hash = categoryData.sha256Hash()
            fileHashes["categories/\(id).json"] = hash

            categoryIndexEntries.append(SyncCategoryIndex.CategoryIndexEntry(
                id: id,
                stub: category.stub,
                hash: hash
            ))
        }

        let categoryIndex = SyncCategoryIndex(categories: categoryIndexEntries)
        let categoryIndexData = try encoder.encode(categoryIndex)
        let categoryIndexPath = syncDirectory.appendingPathComponent("categories/index.json")
        try categoryIndexData.write(to: categoryIndexPath)
        fileHashes["categories/index.json"] = categoryIndexData.sha256Hash()

        // MARK: Generate tags
        statusUpdate("Generating tags...")
        var tagIndexEntries: [SyncTagIndex.TagIndexEntry] = []

        for tag in blog.tags {
            let id = safeId(from: tag.persistentModelID)
            let syncTag = SyncTag(
                id: id,
                name: tag.name,
                stub: tag.stub,
                createdAt: isoFormatter.string(from: tag.createdAt)
            )
            let tagData = try encoder.encode(syncTag)
            let tagPath = syncDirectory.appendingPathComponent("tags/\(id).json")
            try tagData.write(to: tagPath)
            let hash = tagData.sha256Hash()
            fileHashes["tags/\(id).json"] = hash

            tagIndexEntries.append(SyncTagIndex.TagIndexEntry(
                id: id,
                stub: tag.stub,
                hash: hash
            ))
        }

        let tagIndex = SyncTagIndex(tags: tagIndexEntries)
        let tagIndexData = try encoder.encode(tagIndex)
        let tagIndexPath = syncDirectory.appendingPathComponent("tags/index.json")
        try tagIndexData.write(to: tagIndexPath)
        fileHashes["tags/index.json"] = tagIndexData.sha256Hash()

        // MARK: Generate posts (published only, unencrypted)
        statusUpdate("Generating posts...")
        let publishedPosts = blog.posts.filter { !$0.isDraft }
        var postIndexEntries: [SyncPostIndex.PostIndexEntry] = []

        for post in publishedPosts {
            let id = safeId(from: post.persistentModelID)
            statusUpdate("Generating post: \(post.stub ?? id)...")

            do {
                let syncPost = try createSyncPost(from: post, categoryIdMap: categoryIdMap, tagIdMap: tagIdMap)
                let postData = try encoder.encode(syncPost)
                let postPath = syncDirectory.appendingPathComponent("posts/\(id).json")
                try postData.write(to: postPath)
                let hash = postData.sha256Hash()
                fileHashes["posts/\(id).json"] = hash

                postIndexEntries.append(SyncPostIndex.PostIndexEntry(
                    id: id,
                    stub: post.stub,
                    hash: hash,
                    modified: isoFormatter.string(from: post.createdAt)
                ))
            } catch {
                print("⚠️ Error generating sync data for post \(post.stub ?? id): \(error)")
                throw error
            }
        }

        let postIndex = SyncPostIndex(posts: postIndexEntries)
        let postIndexData = try encoder.encode(postIndex)
        let postIndexPath = syncDirectory.appendingPathComponent("posts/index.json")
        try postIndexData.write(to: postIndexPath)
        fileHashes["posts/index.json"] = postIndexData.sha256Hash()

        // MARK: Generate drafts (encrypted)
        statusUpdate("Generating encrypted drafts...")
        let drafts = blog.posts.filter { $0.isDraft }
        var draftIndexEntries: [SyncDraftIndex.DraftIndexEntry] = []
        var draftIVs: [String: String] = [:] // Store IVs for manifest

        for draft in drafts {
            let id = safeId(from: draft.persistentModelID)
            let syncPost = try createSyncPost(from: draft, categoryIdMap: categoryIdMap, tagIdMap: tagIdMap)
            let postData = try encoder.encode(syncPost)

            // Encrypt the draft
            let (ciphertext, iv) = try SyncEncryption.encryptJSON(syncPost, password: password, salt: salt)
            let draftPath = syncDirectory.appendingPathComponent("drafts/\(id).json.enc")
            try ciphertext.write(to: draftPath)
            let hash = ciphertext.sha256Hash()
            fileHashes["drafts/\(id).json.enc"] = hash
            draftIVs["drafts/\(id).json.enc"] = SyncEncryption.base64Encode(iv)

            draftIndexEntries.append(SyncDraftIndex.DraftIndexEntry(
                id: id,
                hash: hash,
                modified: isoFormatter.string(from: draft.createdAt)
            ))
        }

        // Encrypt draft index
        if !draftIndexEntries.isEmpty {
            let draftIndex = SyncDraftIndex(drafts: draftIndexEntries)
            let (indexCiphertext, indexIV) = try SyncEncryption.encryptJSON(draftIndex, password: password, salt: salt)
            let draftIndexPath = syncDirectory.appendingPathComponent("drafts/index.json.enc")
            try indexCiphertext.write(to: draftIndexPath)
            fileHashes["drafts/index.json.enc"] = indexCiphertext.sha256Hash()
            draftIVs["drafts/index.json.enc"] = SyncEncryption.base64Encode(indexIV)
        }

        // MARK: Generate sidebar objects
        statusUpdate("Generating sidebar content...")
        var sidebarIndexEntries: [SyncSidebarIndex.SidebarIndexEntry] = []

        for sidebarObject in blog.sidebarObjects {
            let id = safeId(from: sidebarObject.persistentModelID)

            var links: [SyncLink]? = nil
            if sidebarObject.objectType == .linkList {
                links = sidebarObject.links.sorted { $0.order < $1.order }.map { link in
                    SyncLink(title: link.title, url: link.url, order: link.order)
                }
            }

            let syncSidebar = SyncSidebarObject(
                id: id,
                type: sidebarObject.type,
                title: sidebarObject.title,
                content: sidebarObject.content,
                order: sidebarObject.order,
                links: links
            )
            let sidebarData = try encoder.encode(syncSidebar)
            let sidebarPath = syncDirectory.appendingPathComponent("sidebar/\(id).json")
            try sidebarData.write(to: sidebarPath)
            let hash = sidebarData.sha256Hash()
            fileHashes["sidebar/\(id).json"] = hash

            sidebarIndexEntries.append(SyncSidebarIndex.SidebarIndexEntry(
                id: id,
                hash: hash
            ))
        }

        let sidebarIndex = SyncSidebarIndex(sidebar: sidebarIndexEntries)
        let sidebarIndexData = try encoder.encode(sidebarIndex)
        let sidebarIndexPath = syncDirectory.appendingPathComponent("sidebar/index.json")
        try sidebarIndexData.write(to: sidebarIndexPath)
        fileHashes["sidebar/index.json"] = sidebarIndexData.sha256Hash()

        // MARK: Generate static files
        statusUpdate("Generating static files...")
        var staticFileEntries: [SyncStaticFilesIndex.StaticFileEntry] = []

        for staticFile in blog.staticFiles {
            // Write the actual file
            let filePath = syncDirectory.appendingPathComponent("static-files/\(staticFile.filename)")
            try staticFile.data.write(to: filePath)
            let hash = staticFile.data.sha256Hash()
            fileHashes["static-files/\(staticFile.filename)"] = hash

            staticFileEntries.append(SyncStaticFilesIndex.StaticFileEntry(
                filename: staticFile.filename,
                mimeType: staticFile.mimeType,
                isSpecialFile: staticFile.isSpecialFile,
                specialFileType: staticFile.specialFileType,
                hash: hash,
                size: staticFile.data.count
            ))
        }

        let staticFilesIndex = SyncStaticFilesIndex(files: staticFileEntries)
        let staticFilesIndexData = try encoder.encode(staticFilesIndex)
        let staticFilesIndexPath = syncDirectory.appendingPathComponent("static-files/index.json")
        try staticFilesIndexData.write(to: staticFilesIndexPath)
        fileHashes["static-files/index.json"] = staticFilesIndexData.sha256Hash()

        // MARK: Generate embed images
        statusUpdate("Generating embed images...")
        var embedImageHashes: [String: String] = [:]

        for post in blog.posts {
            if let embed = post.embed {
                // Save link embed image
                if embed.embedType == .link, let imageData = embed.imageData, !imageData.isEmpty {
                    let imageFilename = "embed-\(embed.url.hash).jpg"
                    let imagePath = syncDirectory.appendingPathComponent("embed-images/\(imageFilename)")
                    try imageData.write(to: imagePath)
                    let hash = imageData.sha256Hash()
                    fileHashes["embed-images/\(imageFilename)"] = hash
                    embedImageHashes[imageFilename] = hash
                }

                // Save image embed images
                if embed.embedType == .image {
                    for image in embed.images {
                        let imagePath = syncDirectory.appendingPathComponent("embed-images/\(image.filename)")
                        try image.imageData.write(to: imagePath)
                        let hash = image.imageData.sha256Hash()
                        fileHashes["embed-images/\(image.filename)"] = hash
                        embedImageHashes[image.filename] = hash
                    }
                }
            }
        }

        // Generate embed images index
        struct EmbedImagesIndex: Codable {
            let images: [ImageEntry]
            struct ImageEntry: Codable {
                let filename: String
                let hash: String
            }
        }

        let embedImagesIndex = EmbedImagesIndex(images: embedImageHashes.map { EmbedImagesIndex.ImageEntry(filename: $0.key, hash: $0.value) })
        let embedImagesIndexData = try encoder.encode(embedImagesIndex)
        let embedImagesIndexPath = syncDirectory.appendingPathComponent("embed-images/index.json")
        try embedImagesIndexData.write(to: embedImagesIndexPath)
        fileHashes["embed-images/index.json"] = embedImagesIndexData.sha256Hash()

        // MARK: Generate custom theme
        if let themeIdentifier = blog.themeIdentifier,
           themeIdentifier != "default",
           let theme = ThemeService.shared.getTheme(identifier: themeIdentifier) {
            statusUpdate("Generating custom theme...")
            let syncTheme = SyncTheme(
                identifier: theme.identifier,
                name: theme.name,
                templates: theme.templates
            )
            let themeData = try encoder.encode(syncTheme)
            let themePath = syncDirectory.appendingPathComponent("themes/\(theme.identifier).json")
            try themeData.write(to: themePath)
            fileHashes["themes/\(theme.identifier).json"] = themeData.sha256Hash()
        }

        // MARK: Generate manifest
        statusUpdate("Generating manifest...")
        let newSyncVersion = blog.lastSyncedVersion + 1

        var manifestFiles: [String: SyncManifest.FileInfo] = [:]
        for (path, hash) in fileHashes {
            var fileInfo = SyncManifest.FileInfo(
                hash: hash,
                size: 0 // We'll update this
            )

            // Add IV for encrypted files
            if let iv = draftIVs[path] {
                fileInfo.encrypted = true
                fileInfo.iv = iv
            }

            manifestFiles[path] = fileInfo
        }

        // Update file sizes
        for path in manifestFiles.keys {
            let filePath = syncDirectory.appendingPathComponent(path)
            if let attributes = try? fileManager.attributesOfItem(atPath: filePath.path),
               let size = attributes[.size] as? Int {
                manifestFiles[path]?.size = size
            }
        }

        let manifest = SyncManifest(
            version: "1.0",
            syncVersion: newSyncVersion,
            lastModified: isoFormatter.string(from: Date()),
            appSource: "ios",
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            blogName: blog.name,
            hasDrafts: !drafts.isEmpty,
            encryption: !drafts.isEmpty ? SyncManifest.EncryptionInfo(
                method: "aes-256-gcm",
                salt: SyncEncryption.base64Encode(salt),
                iterations: Int(SyncEncryption.pbkdf2Iterations)
            ) : nil,
            files: manifestFiles
        )

        let manifestData = try encoder.encode(manifest)
        let manifestPath = syncDirectory.appendingPathComponent("manifest.json")
        try manifestData.write(to: manifestPath)
        fileHashes["manifest.json"] = manifestData.sha256Hash()

        statusUpdate("Sync data generation complete!")
        return fileHashes
    }

    // MARK: - Helper Methods

    private static func createSyncPost(
        from post: Post,
        categoryIdMap: [String: String],
        tagIdMap: [String: String]
    ) throws -> SyncPost {
        let postId = safeId(from: post.persistentModelID)

        // Get category ID if exists
        var categoryId: String? = nil
        if let category = post.category {
            categoryId = safeId(from: category.persistentModelID)
        }

        // Get tag IDs
        let tagIds = post.tags.map { tag in
            safeId(from: tag.persistentModelID)
        }

        // Build embed if exists
        var syncEmbed: SyncEmbed? = nil
        if let embed = post.embed {
            print("📎 Processing embed for post: type=\(embed.type), images count=\(embed.images.count)")

            var imageFilename: String? = nil
            if embed.embedType == .link && embed.imageData != nil {
                imageFilename = "embed-\(embed.url.hashValue).jpg"
            }

            let embedImages = embed.images.sorted { $0.order < $1.order }.map { image in
                print("   📷 Embed image: \(image.filename)")
                return SyncEmbedImage(filename: image.filename, order: image.order)
            }

            syncEmbed = SyncEmbed(
                type: embed.type,
                position: embed.position,
                url: embed.url,
                title: embed.title,
                description: embed.embedDescription,
                imageUrl: embed.imageUrl,
                imageFilename: imageFilename,
                images: embedImages
            )
        }

        return SyncPost(
            id: postId,
            title: post.title,
            content: post.content,
            stub: post.stub,
            createdAt: isoFormatter.string(from: post.createdAt),
            updatedAt: isoFormatter.string(from: post.createdAt), // TODO: Add updatedAt to Post model
            categoryId: categoryId,
            tagIds: tagIds,
            embed: syncEmbed
        )
    }
}
