//
//  SyncImporter.swift
//  Postalgic
//
//  Created by Claude on 12/14/25.
//

import Foundation
import SwiftData

/// Service for importing a blog from a sync URL
class SyncImporter {

    enum ImportError: Error, LocalizedError {
        case invalidURL
        case networkError(String)
        case manifestNotFound
        case invalidManifest
        case decryptionFailed
        case passwordRequired
        case importFailed(String)

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid URL provided"
            case .networkError(let message):
                return "Network error: \(message)"
            case .manifestNotFound:
                return "Sync manifest not found at this URL. Make sure the site has sync enabled."
            case .invalidManifest:
                return "Invalid sync manifest format"
            case .decryptionFailed:
                return "Failed to decrypt data. Check your password."
            case .passwordRequired:
                return "This blog has drafts that require a password to import"
            case .importFailed(let message):
                return "Import failed: \(message)"
            }
        }
    }

    // MARK: - Manifest Structure

    struct SyncManifest: Codable {
        let version: String
        let syncVersion: Int
        let lastModified: String
        let appSource: String
        let appVersion: String
        let blogName: String
        let hasDrafts: Bool
        let encryption: EncryptionInfo?
        let files: [String: FileInfo]

        struct EncryptionInfo: Codable {
            let method: String
            let salt: String
            let iterations: Int
        }

        struct FileInfo: Codable {
            let hash: String
            let size: Int
            let modified: String?
            let encrypted: Bool?
            let iv: String?
            let contentHash: String?  // Hash of plaintext before encryption (for drafts)
        }
    }

    // MARK: - Import Progress

    struct ImportProgress {
        var currentStep: String
        var filesDownloaded: Int
        var totalFiles: Int
        var isComplete: Bool

        var progressFraction: Double {
            guard totalFiles > 0 else { return 0 }
            return Double(filesDownloaded) / Double(totalFiles)
        }
    }

    // MARK: - Main Import Methods

    /// Fetches the manifest from a sync URL to check if import is possible
    /// - Parameter urlString: The base URL of the published site
    /// - Returns: The sync manifest
    static func fetchManifest(from urlString: String) async throws -> SyncManifest {
        let baseURL = normalizeURL(urlString)
        let manifestURL = URL(string: "\(baseURL)/sync/manifest.json")!

        var request = URLRequest(url: manifestURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw ImportError.networkError("Invalid response")
            }

            guard httpResponse.statusCode == 200 else {
                if httpResponse.statusCode == 404 {
                    throw ImportError.manifestNotFound
                }
                throw ImportError.networkError("HTTP \(httpResponse.statusCode)")
            }

            let decoder = JSONDecoder()
            return try decoder.decode(SyncManifest.self, from: data)
        } catch let error as ImportError {
            throw error
        } catch let error as DecodingError {
            print("Manifest decoding error: \(error)")
            throw ImportError.invalidManifest
        } catch {
            throw ImportError.networkError(error.localizedDescription)
        }
    }

    /// Imports a blog from a sync URL
    /// - Parameters:
    ///   - urlString: The base URL of the published site
    ///   - password: The sync password (required if blog has drafts)
    ///   - modelContext: The SwiftData model context
    ///   - progressUpdate: Closure for progress updates
    /// - Returns: The imported blog
    static func importBlog(
        from urlString: String,
        password: String?,
        modelContext: ModelContext,
        progressUpdate: @escaping (ImportProgress) -> Void
    ) async throws -> Blog {
        let baseURL = normalizeURL(urlString)

        // Step 1: Fetch manifest
        progressUpdate(ImportProgress(currentStep: "Fetching manifest...", filesDownloaded: 0, totalFiles: 0, isComplete: false))
        let manifest = try await fetchManifest(from: baseURL)

        // Check if password is required
        if manifest.hasDrafts && (password == nil || password!.isEmpty) {
            throw ImportError.passwordRequired
        }

        let totalFiles = manifest.files.count
        var filesDownloaded = 0

        // Prepare encryption key if needed
        var encryptionKey: SymmetricKey? = nil
        if manifest.hasDrafts, let password = password, let encInfo = manifest.encryption {
            guard let saltData = SyncEncryption.base64Decode(encInfo.salt) else {
                throw ImportError.decryptionFailed
            }
            encryptionKey = SyncEncryption.deriveKey(password: password, salt: saltData)
        }

        // Step 2: Download blog.json
        progressUpdate(ImportProgress(currentStep: "Downloading blog settings...", filesDownloaded: filesDownloaded, totalFiles: totalFiles, isComplete: false))
        let blogData = try await downloadFile(from: "\(baseURL)/sync/blog.json")
        filesDownloaded += 1

        let decoder = JSONDecoder()
        let syncBlog = try decoder.decode(SyncDataGenerator.SyncBlog.self, from: blogData)

        // Step 3: Create the blog
        let blog = Blog(name: syncBlog.name, url: syncBlog.url)
        blog.tagline = syncBlog.tagline
        blog.authorName = syncBlog.authorName
        blog.authorUrl = syncBlog.authorUrl
        blog.authorEmail = syncBlog.authorEmail
        blog.accentColor = syncBlog.colors.accent
        blog.backgroundColor = syncBlog.colors.background
        blog.textColor = syncBlog.colors.text
        blog.lightShade = syncBlog.colors.lightShade
        blog.mediumShade = syncBlog.colors.mediumShade
        blog.darkShade = syncBlog.colors.darkShade
        blog.themeIdentifier = syncBlog.themeIdentifier

        // Enable sync and store sync info
        blog.syncEnabled = true
        blog.lastSyncedVersion = manifest.syncVersion
        blog.lastSyncedAt = Date()

        modelContext.insert(blog)

        // Store sync password if provided
        if let password = password {
            blog.setSyncPassword(password)
        }

        // Step 4: Download and create categories
        progressUpdate(ImportProgress(currentStep: "Downloading categories...", filesDownloaded: filesDownloaded, totalFiles: totalFiles, isComplete: false))
        var categoryMap: [String: Category] = [:]
        let categoryIndexData = try await downloadFile(from: "\(baseURL)/sync/categories/index.json")
        filesDownloaded += 1
        let categoryIndex = try decoder.decode(SyncDataGenerator.SyncCategoryIndex.self, from: categoryIndexData)

        for entry in categoryIndex.categories {
            let categoryData = try await downloadFile(from: "\(baseURL)/sync/categories/\(entry.id).json")
            filesDownloaded += 1
            let syncCategory = try decoder.decode(SyncDataGenerator.SyncCategory.self, from: categoryData)

            let category = Category(blog: blog, name: syncCategory.name)
            category.categoryDescription = syncCategory.description
            category.stub = syncCategory.stub
            category.syncId = syncCategory.id  // Store remote ID for incremental sync matching
            if let createdAt = parseDate(syncCategory.createdAt) {
                category.createdAt = createdAt
            }
            modelContext.insert(category)
            categoryMap[syncCategory.id] = category
        }

        // Step 5: Download and create tags
        progressUpdate(ImportProgress(currentStep: "Downloading tags...", filesDownloaded: filesDownloaded, totalFiles: totalFiles, isComplete: false))
        var tagMap: [String: Tag] = [:]
        let tagIndexData = try await downloadFile(from: "\(baseURL)/sync/tags/index.json")
        filesDownloaded += 1
        let tagIndex = try decoder.decode(SyncDataGenerator.SyncTagIndex.self, from: tagIndexData)

        for entry in tagIndex.tags {
            let tagData = try await downloadFile(from: "\(baseURL)/sync/tags/\(entry.id).json")
            filesDownloaded += 1
            let syncTag = try decoder.decode(SyncDataGenerator.SyncTag.self, from: tagData)

            let tag = Tag(blog: blog, name: syncTag.name)
            tag.stub = syncTag.stub
            tag.syncId = syncTag.id  // Store remote ID for incremental sync matching
            if let createdAt = parseDate(syncTag.createdAt) {
                tag.createdAt = createdAt
            }
            modelContext.insert(tag)
            tagMap[syncTag.id] = tag
        }

        // Step 6: Download embed images first (needed for posts)
        progressUpdate(ImportProgress(currentStep: "Downloading images...", filesDownloaded: filesDownloaded, totalFiles: totalFiles, isComplete: false))
        var embedImageData: [String: Data] = [:]
        let embedIndexData = try await downloadFile(from: "\(baseURL)/sync/embed-images/index.json")
        filesDownloaded += 1

        struct EmbedImagesIndex: Codable {
            let images: [ImageEntry]
            struct ImageEntry: Codable {
                let filename: String
                let hash: String
            }
        }

        let embedIndex = try decoder.decode(EmbedImagesIndex.self, from: embedIndexData)
        for imageEntry in embedIndex.images {
            let imageData = try await downloadFile(from: "\(baseURL)/sync/embed-images/\(imageEntry.filename)")
            filesDownloaded += 1
            embedImageData[imageEntry.filename] = imageData
            progressUpdate(ImportProgress(currentStep: "Downloading images...", filesDownloaded: filesDownloaded, totalFiles: totalFiles, isComplete: false))
        }

        // Step 7: Download and create posts
        progressUpdate(ImportProgress(currentStep: "Downloading posts...", filesDownloaded: filesDownloaded, totalFiles: totalFiles, isComplete: false))
        let postIndexData = try await downloadFile(from: "\(baseURL)/sync/posts/index.json")
        filesDownloaded += 1
        let postIndex = try decoder.decode(SyncDataGenerator.SyncPostIndex.self, from: postIndexData)

        for entry in postIndex.posts {
            let postData = try await downloadFile(from: "\(baseURL)/sync/posts/\(entry.id).json")
            filesDownloaded += 1
            let syncPost = try decoder.decode(SyncDataGenerator.SyncPost.self, from: postData)

            try createPost(from: syncPost, blog: blog, categoryMap: categoryMap, tagMap: tagMap, embedImageData: embedImageData, isDraft: false, modelContext: modelContext)
            progressUpdate(ImportProgress(currentStep: "Downloading posts...", filesDownloaded: filesDownloaded, totalFiles: totalFiles, isComplete: false))
        }

        // Step 8: Download and create drafts (encrypted)
        if manifest.hasDrafts, let key = encryptionKey {
            progressUpdate(ImportProgress(currentStep: "Downloading drafts...", filesDownloaded: filesDownloaded, totalFiles: totalFiles, isComplete: false))

            // Download encrypted draft index
            let draftIndexEncData = try await downloadFile(from: "\(baseURL)/sync/drafts/index.json.enc")
            filesDownloaded += 1

            guard let draftIndexIV = manifest.files["drafts/index.json.enc"]?.iv,
                  let ivData = SyncEncryption.base64Decode(draftIndexIV) else {
                throw ImportError.decryptionFailed
            }

            let draftIndexData = try SyncEncryption.decrypt(ciphertext: draftIndexEncData, iv: ivData, key: key)
            let draftIndex = try decoder.decode(SyncDataGenerator.SyncDraftIndex.self, from: draftIndexData)

            for entry in draftIndex.drafts {
                let draftEncData = try await downloadFile(from: "\(baseURL)/sync/drafts/\(entry.id).json.enc")
                filesDownloaded += 1

                guard let draftIV = manifest.files["drafts/\(entry.id).json.enc"]?.iv,
                      let draftIVData = SyncEncryption.base64Decode(draftIV) else {
                    throw ImportError.decryptionFailed
                }

                let draftData = try SyncEncryption.decrypt(ciphertext: draftEncData, iv: draftIVData, key: key)
                let syncDraft = try decoder.decode(SyncDataGenerator.SyncPost.self, from: draftData)

                try createPost(from: syncDraft, blog: blog, categoryMap: categoryMap, tagMap: tagMap, embedImageData: embedImageData, isDraft: true, modelContext: modelContext)
                progressUpdate(ImportProgress(currentStep: "Downloading drafts...", filesDownloaded: filesDownloaded, totalFiles: totalFiles, isComplete: false))
            }
        }

        // Step 9: Download and create sidebar objects
        progressUpdate(ImportProgress(currentStep: "Downloading sidebar content...", filesDownloaded: filesDownloaded, totalFiles: totalFiles, isComplete: false))
        let sidebarIndexData = try await downloadFile(from: "\(baseURL)/sync/sidebar/index.json")
        filesDownloaded += 1
        let sidebarIndex = try decoder.decode(SyncDataGenerator.SyncSidebarIndex.self, from: sidebarIndexData)

        for entry in sidebarIndex.sidebar {
            let sidebarData = try await downloadFile(from: "\(baseURL)/sync/sidebar/\(entry.id).json")
            filesDownloaded += 1
            let syncSidebar = try decoder.decode(SyncDataGenerator.SyncSidebarObject.self, from: sidebarData)

            let sidebarType: SidebarObjectType = syncSidebar.type == "linkList" ? .linkList : .text
            let sidebar = SidebarObject(blog: blog, title: syncSidebar.title, type: sidebarType, order: syncSidebar.order)
            sidebar.content = syncSidebar.content
            sidebar.syncId = syncSidebar.id  // Store remote ID for incremental sync matching
            modelContext.insert(sidebar)

            // Create links if it's a link list
            if let links = syncSidebar.links {
                for syncLink in links {
                    let link = LinkItem(sidebarObject: sidebar, title: syncLink.title, url: syncLink.url, order: syncLink.order)
                    modelContext.insert(link)
                }
            }
        }

        // Step 10: Download and create static files
        progressUpdate(ImportProgress(currentStep: "Downloading static files...", filesDownloaded: filesDownloaded, totalFiles: totalFiles, isComplete: false))
        let staticFilesIndexData = try await downloadFile(from: "\(baseURL)/sync/static-files/index.json")
        filesDownloaded += 1
        let staticFilesIndex = try decoder.decode(SyncDataGenerator.SyncStaticFilesIndex.self, from: staticFilesIndexData)

        for fileEntry in staticFilesIndex.files {
            let fileData = try await downloadFile(from: "\(baseURL)/sync/static-files/\(fileEntry.filename)")
            filesDownloaded += 1

            let staticFile = StaticFile(blog: blog, filename: fileEntry.filename, data: fileData, mimeType: fileEntry.mimeType)
            staticFile.isSpecialFile = fileEntry.isSpecialFile
            staticFile.specialFileType = fileEntry.specialFileType
            staticFile.syncId = fileEntry.filename  // Use filename as sync ID for static files
            modelContext.insert(staticFile)
            progressUpdate(ImportProgress(currentStep: "Downloading static files...", filesDownloaded: filesDownloaded, totalFiles: totalFiles, isComplete: false))
        }

        // Step 11: Download custom theme if present
        if let themeId = syncBlog.themeIdentifier, themeId != "default" {
            let themePath = "themes/\(themeId).json"
            if manifest.files[themePath] != nil {
                progressUpdate(ImportProgress(currentStep: "Downloading theme...", filesDownloaded: filesDownloaded, totalFiles: totalFiles, isComplete: false))
                let themeData = try await downloadFile(from: "\(baseURL)/sync/\(themePath)")
                filesDownloaded += 1
                let syncTheme = try decoder.decode(SyncDataGenerator.SyncTheme.self, from: themeData)

                // Check if theme already exists
                if ThemeService.shared.getTheme(identifier: syncTheme.identifier) == nil {
                    let theme = Theme(name: syncTheme.name, identifier: syncTheme.identifier)
                    modelContext.insert(theme)
                }
            }
        }

        // Save all changes
        try modelContext.save()

        // Store local file hashes for future sync
        var localHashes: [String: String] = [:]
        var localContentHashes: [String: String] = [:]
        for (path, fileInfo) in manifest.files {
            localHashes[path] = fileInfo.hash
            // Store contentHash for encrypted files (allows change detection without IV false positives)
            if let contentHash = fileInfo.contentHash {
                localContentHashes[path] = contentHash
            }
        }
        blog.localSyncHashes = localHashes
        blog.localContentHashes = localContentHashes

        progressUpdate(ImportProgress(currentStep: "Import complete!", filesDownloaded: totalFiles, totalFiles: totalFiles, isComplete: true))

        return blog
    }

    // MARK: - Helper Methods

    private static func normalizeURL(_ urlString: String) -> String {
        var url = urlString.trimmingCharacters(in: .whitespacesAndNewlines)

        // Add https:// if no scheme
        if !url.hasPrefix("http://") && !url.hasPrefix("https://") {
            url = "https://\(url)"
        }

        // Remove trailing slash
        while url.hasSuffix("/") {
            url.removeLast()
        }

        return url
    }

    private static func downloadFile(from urlString: String) async throws -> Data {
        guard let url = URL(string: urlString) else {
            throw ImportError.invalidURL
        }

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw ImportError.networkError("Invalid response")
            }

            guard httpResponse.statusCode == 200 else {
                throw ImportError.networkError("HTTP \(httpResponse.statusCode) for \(urlString)")
            }

            return data
        } catch let error as ImportError {
            throw error
        } catch {
            throw ImportError.networkError(error.localizedDescription)
        }
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static func parseDate(_ dateString: String) -> Date? {
        return isoFormatter.date(from: dateString)
    }

    private static func createPost(
        from syncPost: SyncDataGenerator.SyncPost,
        blog: Blog,
        categoryMap: [String: Category],
        tagMap: [String: Tag],
        embedImageData: [String: Data],
        isDraft: Bool,
        modelContext: ModelContext
    ) throws {
        let post = Post(content: syncPost.content)
        post.blog = blog
        post.title = syncPost.title
        post.stub = syncPost.stub
        post.isDraft = isDraft
        post.syncId = syncPost.id  // Store remote ID for incremental sync matching

        if let createdAt = parseDate(syncPost.createdAt) {
            post.createdAt = createdAt
        }

        // Set category
        if let categoryId = syncPost.categoryId, let category = categoryMap[categoryId] {
            post.category = category
        }

        // Set tags
        for tagId in syncPost.tagIds {
            if let tag = tagMap[tagId] {
                post.tags.append(tag)
            }
        }

        modelContext.insert(post)

        // Create embed if present
        if let syncEmbed = syncPost.embed {
            let embedType: EmbedType
            switch syncEmbed.type.lowercased() {
            case "youtube":
                embedType = .youtube
            case "link":
                embedType = .link
            case "image":
                embedType = .image
            default:
                embedType = .link
            }

            let embedPosition: EmbedPosition = syncEmbed.position.lowercased() == "below" ? .below : .above
            let embed = Embed(post: post, url: syncEmbed.url, type: embedType, position: embedPosition)
            embed.title = syncEmbed.title
            embed.embedDescription = syncEmbed.description
            embed.imageUrl = syncEmbed.imageUrl

            // Load link embed image data
            if embedType == .link, let imageFilename = syncEmbed.imageFilename {
                embed.imageData = embedImageData[imageFilename]
            }

            modelContext.insert(embed)

            // Create embed images for image type
            if embedType == .image {
                for syncImage in syncEmbed.images {
                    if let imageData = embedImageData[syncImage.filename] {
                        let embedImage = EmbedImage(embed: embed, imageData: imageData, order: syncImage.order, filename: syncImage.filename)
                        modelContext.insert(embedImage)
                    }
                }
            }

            post.embed = embed
        }
    }
}

// MARK: - CryptoKit Import
import CryptoKit

