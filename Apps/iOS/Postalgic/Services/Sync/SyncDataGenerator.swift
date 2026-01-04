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
        case failedToCreateDirectory
        case failedToWriteFile(String)

        var errorDescription: String? {
            switch self {
            case .failedToCreateDirectory:
                return "Failed to create sync directory"
            case .failedToWriteFile(let filename):
                return "Failed to write file: \(filename)"
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

    /// Gets the stable sync ID for an entity.
    /// Uses syncId if available (preserves ID from import), otherwise generates from persistentModelID.
    /// This ensures entity IDs remain stable across all copies of a synced blog.
    private static func getStableSyncId(for category: Category) -> String {
        return category.syncId ?? safeId(from: category.persistentModelID)
    }

    private static func getStableSyncId(for tag: Tag) -> String {
        return tag.syncId ?? safeId(from: tag.persistentModelID)
    }

    private static func getStableSyncId(for post: Post) -> String {
        return post.syncId ?? safeId(from: post.persistentModelID)
    }

    private static func getStableSyncId(for sidebarObject: SidebarObject) -> String {
        return sidebarObject.syncId ?? safeId(from: sidebarObject.persistentModelID)
    }

    private static func getStableSyncId(for staticFile: StaticFile) -> String {
        return staticFile.syncId ?? safeId(from: staticFile.persistentModelID)
    }

    // MARK: - Sync Data Models

    struct SyncManifest: Codable {
        let version: String
        let contentVersion: String
        let lastModified: String
        let appSource: String
        let appVersion: String
        let blogName: String
        let fileCount: Int?
        var files: [String: FileInfo]

        struct FileInfo: Codable {
            let hash: String
            var size: Int
            var modified: String?

            // Explicitly encode nil as null to match self-hosted output
            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(hash, forKey: .hash)
                try container.encode(modified, forKey: .modified)
                try container.encode(size, forKey: .size)
            }
        }

        // Explicitly encode nil as null to match self-hosted output
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(appSource, forKey: .appSource)
            try container.encode(appVersion, forKey: .appVersion)
            try container.encode(blogName, forKey: .blogName)
            try container.encode(contentVersion, forKey: .contentVersion)
            try container.encode(fileCount, forKey: .fileCount)
            try container.encode(files, forKey: .files)
            try container.encode(lastModified, forKey: .lastModified)
            try container.encode(version, forKey: .version)
        }
    }

    struct SyncBlog: Codable {
        let name: String
        let url: String?
        let tagline: String?
        let authorName: String?
        let authorUrl: String?
        let authorEmail: String?
        let timezone: String
        let colors: ColorSettings
        let themeIdentifier: String?
        let simpleAnalyticsEnabled: Bool
        let simpleAnalyticsDomain: String?

        struct ColorSettings: Codable {
            let accent: String?
            let background: String?
            let text: String?
            let lightShade: String?
            let mediumShade: String?
            let darkShade: String?

            // Explicitly encode nil as null to match self-hosted output
            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(accent, forKey: .accent)
                try container.encode(background, forKey: .background)
                try container.encode(darkShade, forKey: .darkShade)
                try container.encode(lightShade, forKey: .lightShade)
                try container.encode(mediumShade, forKey: .mediumShade)
                try container.encode(text, forKey: .text)
            }
        }

        // Explicitly encode nil as null to match self-hosted output
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(authorEmail, forKey: .authorEmail)
            try container.encode(authorName, forKey: .authorName)
            try container.encode(authorUrl, forKey: .authorUrl)
            try container.encode(colors, forKey: .colors)
            try container.encode(name, forKey: .name)
            try container.encode(simpleAnalyticsDomain, forKey: .simpleAnalyticsDomain)
            try container.encode(simpleAnalyticsEnabled, forKey: .simpleAnalyticsEnabled)
            try container.encode(tagline, forKey: .tagline)
            try container.encode(themeIdentifier, forKey: .themeIdentifier)
            try container.encode(timezone, forKey: .timezone)
            try container.encode(url, forKey: .url)
        }
    }

    struct SyncPostIndex: Codable {
        let posts: [PostIndexEntry]

        struct PostIndexEntry: Codable {
            let id: String
            let stub: String?
            let hash: String
            let modified: String

            // Explicitly encode nil as null to match self-hosted output
            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(hash, forKey: .hash)
                try container.encode(id, forKey: .id)
                try container.encode(modified, forKey: .modified)
                try container.encode(stub, forKey: .stub)
            }
        }
    }

    struct SyncPost: Codable {
        let id: String
        let title: String?
        let content: String
        let contentHtml: String?  // Pre-rendered HTML from markdown
        let stub: String?
        let createdAt: String
        let updatedAt: String
        let categoryId: String?
        let tagIds: [String]
        let embed: SyncEmbed?

        // Explicitly encode nil as null to match self-hosted output
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(categoryId, forKey: .categoryId)
            try container.encode(content, forKey: .content)
            try container.encode(contentHtml, forKey: .contentHtml)
            try container.encode(createdAt, forKey: .createdAt)
            try container.encode(embed, forKey: .embed)
            try container.encode(id, forKey: .id)
            try container.encode(stub, forKey: .stub)
            try container.encode(tagIds, forKey: .tagIds)
            try container.encode(title, forKey: .title)
            try container.encode(updatedAt, forKey: .updatedAt)
        }
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

        // Explicitly encode nil as null to match self-hosted output
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(description, forKey: .description)
            try container.encode(imageFilename, forKey: .imageFilename)
            try container.encode(imageUrl, forKey: .imageUrl)
            try container.encode(images, forKey: .images)
            try container.encode(position, forKey: .position)
            try container.encode(title, forKey: .title)
            try container.encode(type, forKey: .type)
            try container.encode(url, forKey: .url)
        }
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

            // Explicitly encode nil as null to match self-hosted output
            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(hash, forKey: .hash)
                try container.encode(id, forKey: .id)
                try container.encode(stub, forKey: .stub)
            }
        }
    }

    struct SyncCategory: Codable {
        let id: String
        let name: String
        let description: String?
        let stub: String?
        let createdAt: String

        // Explicitly encode nil as null to match self-hosted output
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(createdAt, forKey: .createdAt)
            try container.encode(description, forKey: .description)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(stub, forKey: .stub)
        }
    }

    struct SyncTagIndex: Codable {
        let tags: [TagIndexEntry]

        struct TagIndexEntry: Codable {
            let id: String
            let stub: String?
            let hash: String

            // Explicitly encode nil as null to match self-hosted output
            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(hash, forKey: .hash)
                try container.encode(id, forKey: .id)
                try container.encode(stub, forKey: .stub)
            }
        }
    }

    struct SyncTag: Codable {
        let id: String
        let name: String
        let stub: String?
        let createdAt: String

        // Explicitly encode nil as null to match self-hosted output
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(createdAt, forKey: .createdAt)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(stub, forKey: .stub)
        }
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
        let contentHtml: String?  // Pre-rendered HTML from markdown
        let order: Int
        let links: [SyncLink]?
        let createdAt: String  // ISO8601 formatted date for sync parity

        // Explicitly encode nil as null to match self-hosted output
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(content, forKey: .content)
            try container.encode(contentHtml, forKey: .contentHtml)
            try container.encode(createdAt, forKey: .createdAt)
            try container.encode(id, forKey: .id)
            try container.encode(links, forKey: .links)
            try container.encode(order, forKey: .order)
            try container.encode(title, forKey: .title)
            try container.encode(type, forKey: .type)
        }
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

            // Explicitly encode nil as null to match self-hosted output
            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(filename, forKey: .filename)
                try container.encode(hash, forKey: .hash)
                try container.encode(isSpecialFile, forKey: .isSpecialFile)
                try container.encode(mimeType, forKey: .mimeType)
                try container.encode(size, forKey: .size)
                try container.encode(specialFileType, forKey: .specialFileType)
            }
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

    /// Calculate the latest modification date from all content entities.
    /// Returns the most recent updatedAt/createdAt from posts, categories, tags.
    private static func getLatestModificationDate(blog: Blog) -> Date {
        var latest = Date(timeIntervalSince1970: 0)

        // Check posts (use updatedAt if available, otherwise createdAt)
        for post in blog.posts where !post.isDraft {
            let postDate = post.updatedAt ?? post.createdAt
            if postDate > latest {
                latest = postDate
            }
        }

        // Check categories
        for category in blog.categories {
            if category.createdAt > latest {
                latest = category.createdAt
            }
        }

        // Check tags
        for tag in blog.tags {
            if tag.createdAt > latest {
                latest = tag.createdAt
            }
        }

        // If no content exists, return current date as fallback
        if latest == Date(timeIntervalSince1970: 0) {
            return Date()
        }

        return latest
    }

    // MARK: - Main Generation Method

    /// Generates the sync directory for a blog
    /// - Parameters:
    ///   - blog: The blog to generate sync data for
    ///   - siteDirectory: The root site directory
    ///   - statusUpdate: Closure for status updates
    /// - Returns: Dictionary of file paths to their hashes
    static func generateSyncDirectory(
        for blog: Blog,
        in siteDirectory: URL,
        statusUpdate: @escaping (String) -> Void
    ) throws -> [String: String] {
        let fileManager = FileManager.default
        let syncDirectory = siteDirectory.appendingPathComponent("sync")

        // Create sync directory structure (drafts stay local, not synced)
        statusUpdate("Creating sync directory structure...")
        try fileManager.createDirectory(at: syncDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: syncDirectory.appendingPathComponent("posts"), withIntermediateDirectories: true)
        try fileManager.createDirectory(at: syncDirectory.appendingPathComponent("categories"), withIntermediateDirectories: true)
        try fileManager.createDirectory(at: syncDirectory.appendingPathComponent("tags"), withIntermediateDirectories: true)
        try fileManager.createDirectory(at: syncDirectory.appendingPathComponent("sidebar"), withIntermediateDirectories: true)
        try fileManager.createDirectory(at: syncDirectory.appendingPathComponent("static-files"), withIntermediateDirectories: true)
        try fileManager.createDirectory(at: syncDirectory.appendingPathComponent("embed-images"), withIntermediateDirectories: true)
        try fileManager.createDirectory(at: syncDirectory.appendingPathComponent("themes"), withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        // Use compact JSON (sorted keys only, no pretty printing) for cross-platform consistency
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]

        var fileHashes: [String: String] = [:]

        // Build ID maps: local persistent ID -> stable sync ID
        // This allows us to look up the stable ID when we have a reference to the local entity
        var categoryIdMap: [PersistentIdentifier: String] = [:]
        var tagIdMap: [PersistentIdentifier: String] = [:]

        // Build category ID map
        for category in blog.categories {
            let stableId = getStableSyncId(for: category)
            categoryIdMap[category.persistentModelID] = stableId
        }

        // Build tag ID map
        for tag in blog.tags {
            let stableId = getStableSyncId(for: tag)
            tagIdMap[tag.persistentModelID] = stableId
        }

        // MARK: Generate blog.json
        statusUpdate("Generating blog settings...")
        let syncBlog = SyncBlog(
            name: blog.name,
            url: blog.url.isEmpty ? nil : blog.url,
            tagline: blog.tagline,
            authorName: blog.authorName,
            authorUrl: blog.authorUrl,
            authorEmail: blog.authorEmail,
            timezone: blog.timezone,
            colors: SyncBlog.ColorSettings(
                accent: blog.accentColor,
                background: blog.backgroundColor,
                text: blog.textColor,
                lightShade: blog.lightShade,
                mediumShade: blog.mediumShade,
                darkShade: blog.darkShade
            ),
            themeIdentifier: blog.themeIdentifier,
            simpleAnalyticsEnabled: blog.simpleAnalyticsEnabled,
            simpleAnalyticsDomain: blog.simpleAnalyticsDomain
        )
        let blogData = try encoder.encode(syncBlog)
        let blogPath = syncDirectory.appendingPathComponent("blog.json")
        try blogData.write(to: blogPath)
        fileHashes["blog.json"] = blogData.sha256Hash()

        // MARK: Generate categories
        statusUpdate("Generating categories...")
        var categoryIndexEntries: [SyncCategoryIndex.CategoryIndexEntry] = []

        for category in blog.categories {
            let stableId = getStableSyncId(for: category)
            let syncCategory = SyncCategory(
                id: stableId,
                name: category.name,
                description: category.categoryDescription,
                stub: category.stub,
                createdAt: isoFormatter.string(from: category.createdAt)
            )
            let categoryData = try encoder.encode(syncCategory)
            let categoryPath = syncDirectory.appendingPathComponent("categories/\(stableId).json")
            try categoryData.write(to: categoryPath)
            let hash = categoryData.sha256Hash()
            fileHashes["categories/\(stableId).json"] = hash

            categoryIndexEntries.append(SyncCategoryIndex.CategoryIndexEntry(
                id: stableId,
                stub: category.stub,
                hash: hash
            ))
        }

        // Sort by id for deterministic output
        let categoryIndex = SyncCategoryIndex(categories: categoryIndexEntries.sorted { $0.id < $1.id })
        let categoryIndexData = try encoder.encode(categoryIndex)
        let categoryIndexPath = syncDirectory.appendingPathComponent("categories/index.json")
        try categoryIndexData.write(to: categoryIndexPath)
        fileHashes["categories/index.json"] = categoryIndexData.sha256Hash()

        // MARK: Generate tags
        statusUpdate("Generating tags...")
        var tagIndexEntries: [SyncTagIndex.TagIndexEntry] = []

        for tag in blog.tags {
            let stableId = getStableSyncId(for: tag)
            let syncTag = SyncTag(
                id: stableId,
                name: tag.name,
                stub: tag.stub,
                createdAt: isoFormatter.string(from: tag.createdAt)
            )
            let tagData = try encoder.encode(syncTag)
            let tagPath = syncDirectory.appendingPathComponent("tags/\(stableId).json")
            try tagData.write(to: tagPath)
            let hash = tagData.sha256Hash()
            fileHashes["tags/\(stableId).json"] = hash

            tagIndexEntries.append(SyncTagIndex.TagIndexEntry(
                id: stableId,
                stub: tag.stub,
                hash: hash
            ))
        }

        // Sort by id for deterministic output
        let tagIndex = SyncTagIndex(tags: tagIndexEntries.sorted { $0.id < $1.id })
        let tagIndexData = try encoder.encode(tagIndex)
        let tagIndexPath = syncDirectory.appendingPathComponent("tags/index.json")
        try tagIndexData.write(to: tagIndexPath)
        fileHashes["tags/index.json"] = tagIndexData.sha256Hash()

        // MARK: Generate posts (published only, unencrypted)
        statusUpdate("Generating posts...")
        let publishedPosts = blog.posts.filter { !$0.isDraft }
        var postIndexEntries: [SyncPostIndex.PostIndexEntry] = []

        for post in publishedPosts {
            let stableId = getStableSyncId(for: post)
            statusUpdate("Generating post: \(post.stub ?? stableId)...")

            do {
                let syncPost = try createSyncPost(from: post, stableId: stableId, categoryIdMap: categoryIdMap, tagIdMap: tagIdMap)
                let postData = try encoder.encode(syncPost)
                let postPath = syncDirectory.appendingPathComponent("posts/\(stableId).json")
                try postData.write(to: postPath)
                let hash = postData.sha256Hash()
                fileHashes["posts/\(stableId).json"] = hash

                postIndexEntries.append(SyncPostIndex.PostIndexEntry(
                    id: stableId,
                    stub: post.stub,
                    hash: hash,
                    modified: isoFormatter.string(from: post.updatedAt ?? post.createdAt)
                ))
            } catch {
                Log.warn("Error generating sync data for post \(post.stub ?? stableId): \(error)")
                throw error
            }
        }

        // Sort by id for deterministic output
        let postIndex = SyncPostIndex(posts: postIndexEntries.sorted { $0.id < $1.id })
        let postIndexData = try encoder.encode(postIndex)
        let postIndexPath = syncDirectory.appendingPathComponent("posts/index.json")
        try postIndexData.write(to: postIndexPath)
        fileHashes["posts/index.json"] = postIndexData.sha256Hash()

        // MARK: Generate sidebar objects
        statusUpdate("Generating sidebar content...")
        var sidebarIndexEntries: [SyncSidebarIndex.SidebarIndexEntry] = []

        for sidebarObject in blog.sidebarObjects {
            let stableId = getStableSyncId(for: sidebarObject)

            var links: [SyncLink]? = nil
            if sidebarObject.objectType == .linkList {
                links = sidebarObject.links.sorted { $0.order < $1.order }.map { link in
                    SyncLink(title: link.title, url: link.url, order: link.order)
                }
            }

            // Convert iOS type format to self-hosted format
            let syncType = sidebarObject.objectType == .linkList ? "linkList" : "text"
            let syncSidebar = SyncSidebarObject(
                id: stableId,
                type: syncType,
                title: sidebarObject.title,
                content: sidebarObject.content,
                contentHtml: sidebarObject.contentHtml,
                order: sidebarObject.order,
                links: links,
                createdAt: isoFormatter.string(from: sidebarObject.createdAt)
            )
            let sidebarData = try encoder.encode(syncSidebar)
            let sidebarPath = syncDirectory.appendingPathComponent("sidebar/\(stableId).json")
            try sidebarData.write(to: sidebarPath)
            let hash = sidebarData.sha256Hash()
            fileHashes["sidebar/\(stableId).json"] = hash

            sidebarIndexEntries.append(SyncSidebarIndex.SidebarIndexEntry(
                id: stableId,
                hash: hash
            ))
        }

        // Sort by id for deterministic output
        let sidebarIndex = SyncSidebarIndex(sidebar: sidebarIndexEntries.sorted { $0.id < $1.id })
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

        // Sort by filename for deterministic output
        let staticFilesIndex = SyncStaticFilesIndex(files: staticFileEntries.sorted { $0.filename < $1.filename })
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
                if embed.embedType == .link, let imageData = embed.imageData, !imageData.isEmpty,
                   let imageFilename = embed.deterministicImageFilename {
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

        // Sort by filename for deterministic output (dictionary iteration order is non-deterministic)
        let sortedEmbedImages = embedImageHashes.keys.sorted().map { filename in
            EmbedImagesIndex.ImageEntry(filename: filename, hash: embedImageHashes[filename]!)
        }
        let embedImagesIndex = EmbedImagesIndex(images: sortedEmbedImages)
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

        var manifestFiles: [String: SyncManifest.FileInfo] = [:]
        for (path, hash) in fileHashes {
            var fileInfo = SyncManifest.FileInfo(
                hash: hash,
                size: 0 // We'll update this
            )
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

        // Compute contentVersion as SHA256 of all file hashes (sorted for consistency)
        // Format: "filePath:hash\n" to match self-hosted sync generator
        let sortedHashEntries = fileHashes.keys.sorted().map { "\($0):\(fileHashes[$0]!)" }
        let combinedHashes = sortedHashEntries.joined(separator: "\n")
        let contentVersion = combinedHashes.data(using: .utf8)?.sha256Hash() ?? UUID().uuidString

        let manifest = SyncManifest(
            version: "1.0",
            contentVersion: contentVersion,
            lastModified: isoFormatter.string(from: getLatestModificationDate(blog: blog)),
            appSource: "ios",
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            blogName: blog.name,
            fileCount: fileHashes.count,
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
        stableId: String,
        categoryIdMap: [PersistentIdentifier: String],
        tagIdMap: [PersistentIdentifier: String]
    ) throws -> SyncPost {
        // Get stable category ID if exists (use the ID map to translate)
        var categoryId: String? = nil
        if let category = post.category {
            categoryId = categoryIdMap[category.persistentModelID] ?? getStableSyncId(for: category)
        }

        // Get stable tag IDs (use the ID map to translate)
        // Sort tag IDs for deterministic output
        let tagIds = post.tags.map { tag in
            tagIdMap[tag.persistentModelID] ?? getStableSyncId(for: tag)
        }.sorted()

        // Build embed if exists
        var syncEmbed: SyncEmbed? = nil
        if let embed = post.embed {
            Log.verbose("Processing embed for post: type=\(embed.type), images count=\(embed.images.count)")

            // Use deterministicImageFilename which uses SHA256 hash for cross-platform compatibility
            let imageFilename = embed.deterministicImageFilename

            let embedImages = embed.images.sorted { $0.order < $1.order }.map { image in
                Log.verbose("   Embed image: \(image.filename)")
                return SyncEmbedImage(filename: image.filename, order: image.order)
            }

            syncEmbed = SyncEmbed(
                type: embed.type,
                position: embed.position.lowercased(),  // Self-hosted uses lowercase positions
                url: embed.url,
                title: embed.title,
                description: embed.embedDescription,
                imageUrl: embed.imageUrl,
                imageFilename: imageFilename,
                images: embedImages
            )
        }

        return SyncPost(
            id: stableId,
            title: post.title,
            content: post.content,
            contentHtml: post.contentHtml,
            stub: post.stub,
            createdAt: isoFormatter.string(from: post.createdAt),
            updatedAt: isoFormatter.string(from: post.updatedAt ?? post.createdAt),
            categoryId: categoryId,
            tagIds: tagIds,
            embed: syncEmbed
        )
    }
}
