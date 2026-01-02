//
//  IncrementalSync.swift
//  Postalgic
//
//  Service for performing incremental sync (pull changes from remote).
//

import Foundation
import SwiftData

/// Result of incremental sync operation
struct IncrementalSyncResult {
    let success: Bool
    let updated: Bool
    let message: String
    let changes: ChangeCount

    struct ChangeCount {
        let new: Int
        let modified: Int
        let deleted: Int

        var total: Int { new + modified + deleted }
    }
}

/// Progress update for incremental sync
struct IncrementalSyncProgress {
    let step: String
    let phase: SyncPhase
    let progress: Double // 0.0 to 1.0

    enum SyncPhase {
        case checking
        case applying
        case complete
    }
}

class IncrementalSync {

    enum SyncError: Error, LocalizedError {
        case blogNotFound
        case noSyncUrl
        case networkError(String)
        case importFailed(String)

        var errorDescription: String? {
            switch self {
            case .blogNotFound:
                return "Blog not found"
            case .noSyncUrl:
                return "Blog URL is not configured"
            case .networkError(let message):
                return "Network error: \(message)"
            case .importFailed(let message):
                return "Sync failed: \(message)"
            }
        }
    }

    /// Pull changes from remote to local
    /// - Parameters:
    ///   - blog: The blog to sync
    ///   - modelContext: The SwiftData model context
    ///   - progressUpdate: Progress update closure
    /// - Returns: IncrementalSyncResult
    static func pullChanges(
        blog: Blog,
        modelContext: ModelContext,
        progressUpdate: @escaping (IncrementalSyncProgress) -> Void
    ) async throws -> IncrementalSyncResult {
        let syncUrl = blog.url
        guard !syncUrl.isEmpty else { throw SyncError.noSyncUrl }

        let baseURL = normalizeURL(syncUrl)

        // Step 1: Check for changes
        progressUpdate(IncrementalSyncProgress(step: "Checking for changes...", phase: .checking, progress: 0))

        let checkResult = try await SyncChecker.checkForChanges(blog: blog)

        if !checkResult.hasChanges {
            progressUpdate(IncrementalSyncProgress(step: "Already up to date", phase: .complete, progress: 1))
            return IncrementalSyncResult(
                success: true,
                updated: false,
                message: "Already up to date",
                changes: IncrementalSyncResult.ChangeCount(new: 0, modified: 0, deleted: 0)
            )
        }

        guard let manifest = checkResult.manifest else {
            throw SyncError.importFailed("No manifest available")
        }

        let categorized = SyncChecker.categorizeChanges(checkResult)

        var totalChanges = 0
        var appliedChanges = 0

        // Count total changes (drafts are local-only, not synced)
        totalChanges += categorized.categories.new.count + categorized.categories.modified.count + categorized.categories.deleted.count
        totalChanges += categorized.tags.new.count + categorized.tags.modified.count + categorized.tags.deleted.count
        totalChanges += categorized.posts.new.count + categorized.posts.modified.count + categorized.posts.deleted.count
        totalChanges += categorized.sidebar.new.count + categorized.sidebar.modified.count + categorized.sidebar.deleted.count
        totalChanges += categorized.staticFiles.new.count + categorized.staticFiles.deleted.count
        totalChanges += categorized.blog.new.count + categorized.blog.modified.count
        totalChanges += categorized.themes.new.count + categorized.themes.modified.count

        let decoder = JSONDecoder()

        // Step 2: Process blog changes (handle both new and modified)
        if !categorized.blog.new.isEmpty || !categorized.blog.modified.isEmpty {
            progressUpdate(IncrementalSyncProgress(step: "Updating blog settings...", phase: .applying, progress: Double(appliedChanges) / Double(max(1, totalChanges))))
            let blogData = try await downloadFile(from: "\(baseURL)/sync/blog.json")
            let syncBlog = try decoder.decode(SyncDataGenerator.SyncBlog.self, from: blogData)

            blog.name = syncBlog.name
            blog.url = syncBlog.url ?? ""
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
            blog.timezone = syncBlog.timezone

            appliedChanges += 1
        }

        // Step 2.5: Process theme changes (new and modified)
        print("🎨 IncrementalSync: Processing \(categorized.themes.new.count) new and \(categorized.themes.modified.count) modified themes")
        for file in categorized.themes.new + categorized.themes.modified {
            print("🎨 IncrementalSync: Processing theme file: \(file.path)")
            progressUpdate(IncrementalSyncProgress(step: "Updating theme...", phase: .applying, progress: Double(appliedChanges) / Double(max(1, totalChanges))))
            let themeData = try await downloadFile(from: "\(baseURL)/sync/\(file.path)")
            let syncTheme = try decoder.decode(SyncDataGenerator.SyncTheme.self, from: themeData)
            print("🎨 IncrementalSync: Downloaded theme '\(syncTheme.name)' with \(syncTheme.templates.count) templates")

            // Check if theme already exists
            if let existingTheme = ThemeService.shared.getTheme(identifier: syncTheme.identifier) {
                // Update existing theme's templates
                existingTheme.templates = syncTheme.templates
                print("🎨 IncrementalSync: Updated existing theme '\(syncTheme.identifier)'")
            } else {
                // Create new theme with templates
                let theme = Theme(name: syncTheme.name, identifier: syncTheme.identifier, isCustomized: true)
                theme.templates = syncTheme.templates
                modelContext.insert(theme)
                ThemeService.shared.addTheme(theme)
                print("🎨 IncrementalSync: Created new theme '\(syncTheme.identifier)'")
            }
            appliedChanges += 1
        }

        // Build existing entity maps by syncId
        var categoryMap: [String: Category] = [:]
        var tagMap: [String: Tag] = [:]

        for category in blog.categories {
            if let syncId = category.syncId {
                categoryMap[syncId] = category
            }
        }
        for tag in blog.tags {
            if let syncId = tag.syncId {
                tagMap[syncId] = tag
            }
        }

        // Step 3: Process category changes
        // Note: For "new" categories, we still check categoryMap by syncId to prevent duplicates
        // when syncing back after publishing from another client.
        for file in categorized.categories.new {
            progressUpdate(IncrementalSyncProgress(step: "Adding new categories...", phase: .applying, progress: Double(appliedChanges) / Double(max(1, totalChanges))))
            if let entityId = SyncChecker.extractEntityId(from: file.path) {
                let categoryData = try await downloadFile(from: "\(baseURL)/sync/\(file.path)")
                let syncCategory = try decoder.decode(SyncDataGenerator.SyncCategory.self, from: categoryData)

                if let existingCategory = categoryMap[syncCategory.id] {
                    existingCategory.name = syncCategory.name
                    existingCategory.categoryDescription = syncCategory.description
                    existingCategory.stub = syncCategory.stub
                } else {
                    let category = Category(blog: blog, name: syncCategory.name)
                    category.categoryDescription = syncCategory.description
                    category.stub = syncCategory.stub
                    category.syncId = syncCategory.id
                    modelContext.insert(category)
                    categoryMap[syncCategory.id] = category
                }
            }
            appliedChanges += 1
        }

        for file in categorized.categories.modified {
            progressUpdate(IncrementalSyncProgress(step: "Updating categories...", phase: .applying, progress: Double(appliedChanges) / Double(max(1, totalChanges))))
            if let entityId = SyncChecker.extractEntityId(from: file.path) {
                let categoryData = try await downloadFile(from: "\(baseURL)/sync/\(file.path)")
                let syncCategory = try decoder.decode(SyncDataGenerator.SyncCategory.self, from: categoryData)

                if let existingCategory = categoryMap[syncCategory.id] {
                    existingCategory.name = syncCategory.name
                    existingCategory.categoryDescription = syncCategory.description
                    existingCategory.stub = syncCategory.stub
                } else {
                    let category = Category(blog: blog, name: syncCategory.name)
                    category.categoryDescription = syncCategory.description
                    category.stub = syncCategory.stub
                    category.syncId = syncCategory.id
                    modelContext.insert(category)
                    categoryMap[syncCategory.id] = category
                }
            }
            appliedChanges += 1
        }

        for file in categorized.categories.deleted {
            progressUpdate(IncrementalSyncProgress(step: "Removing deleted categories...", phase: .applying, progress: Double(appliedChanges) / Double(max(1, totalChanges))))
            if let entityId = SyncChecker.extractEntityId(from: file.path),
               let category = categoryMap[entityId] {
                modelContext.delete(category)
                categoryMap.removeValue(forKey: entityId)
            }
            appliedChanges += 1
        }

        // Step 4: Process tag changes
        // Note: For "new" tags, we still check tagMap by syncId to prevent duplicates
        // when syncing back after publishing from another client.
        for file in categorized.tags.new {
            progressUpdate(IncrementalSyncProgress(step: "Adding new tags...", phase: .applying, progress: Double(appliedChanges) / Double(max(1, totalChanges))))
            if let entityId = SyncChecker.extractEntityId(from: file.path) {
                let tagData = try await downloadFile(from: "\(baseURL)/sync/\(file.path)")
                let syncTag = try decoder.decode(SyncDataGenerator.SyncTag.self, from: tagData)

                if let existingTag = tagMap[syncTag.id] {
                    existingTag.name = syncTag.name
                    existingTag.stub = syncTag.stub
                } else {
                    let tag = Tag(blog: blog, name: syncTag.name)
                    tag.stub = syncTag.stub
                    tag.syncId = syncTag.id
                    modelContext.insert(tag)
                    tagMap[syncTag.id] = tag
                }
            }
            appliedChanges += 1
        }

        for file in categorized.tags.modified {
            progressUpdate(IncrementalSyncProgress(step: "Updating tags...", phase: .applying, progress: Double(appliedChanges) / Double(max(1, totalChanges))))
            if let entityId = SyncChecker.extractEntityId(from: file.path) {
                let tagData = try await downloadFile(from: "\(baseURL)/sync/\(file.path)")
                let syncTag = try decoder.decode(SyncDataGenerator.SyncTag.self, from: tagData)

                if let existingTag = tagMap[syncTag.id] {
                    existingTag.name = syncTag.name
                    existingTag.stub = syncTag.stub
                } else {
                    let tag = Tag(blog: blog, name: syncTag.name)
                    tag.stub = syncTag.stub
                    tag.syncId = syncTag.id
                    modelContext.insert(tag)
                    tagMap[syncTag.id] = tag
                }
            }
            appliedChanges += 1
        }

        for file in categorized.tags.deleted {
            progressUpdate(IncrementalSyncProgress(step: "Removing deleted tags...", phase: .applying, progress: Double(appliedChanges) / Double(max(1, totalChanges))))
            if let entityId = SyncChecker.extractEntityId(from: file.path),
               let tag = tagMap[entityId] {
                modelContext.delete(tag)
                tagMap.removeValue(forKey: entityId)
            }
            appliedChanges += 1
        }

        // Step 5: Download embed images (before posts)
        progressUpdate(IncrementalSyncProgress(step: "Downloading images...", phase: .applying, progress: Double(appliedChanges) / Double(max(1, totalChanges))))
        var embedImageData: [String: Data] = [:]
        for file in categorized.embedImages.new + categorized.embedImages.modified {
            let filename = file.path.replacingOccurrences(of: "embed-images/", with: "")
            let imageData = try await downloadFile(from: "\(baseURL)/sync/\(file.path)")
            embedImageData[filename] = imageData
        }

        // Build post map by syncId
        var postMap: [String: Post] = [:]
        for post in blog.posts {
            if let syncId = post.syncId {
                postMap[syncId] = post
            }
        }

        // Step 6: Process post changes
        // Note: For "new" posts, we still check postMap by syncId because if a post was created
        // locally and published, it won't be in localSyncHashes but will exist with that syncId.
        // This prevents duplicate posts when syncing back after publishing from another client.
        for file in categorized.posts.new {
            progressUpdate(IncrementalSyncProgress(step: "Adding new posts...", phase: .applying, progress: Double(appliedChanges) / Double(max(1, totalChanges))))
            if let entityId = SyncChecker.extractEntityId(from: file.path) {
                let postData = try await downloadFile(from: "\(baseURL)/sync/\(file.path)")
                let syncPost = try decoder.decode(SyncDataGenerator.SyncPost.self, from: postData)
                let existingPost = postMap[syncPost.id]
                try createOrUpdatePost(syncPost, blog: blog, categoryMap: categoryMap, tagMap: tagMap, embedImageData: embedImageData, isDraft: false, modelContext: modelContext, existingPost: existingPost)
            }
            appliedChanges += 1
        }

        for file in categorized.posts.modified {
            progressUpdate(IncrementalSyncProgress(step: "Updating posts...", phase: .applying, progress: Double(appliedChanges) / Double(max(1, totalChanges))))
            if let entityId = SyncChecker.extractEntityId(from: file.path) {
                let postData = try await downloadFile(from: "\(baseURL)/sync/\(file.path)")
                let syncPost = try decoder.decode(SyncDataGenerator.SyncPost.self, from: postData)
                let existingPost = postMap[syncPost.id]
                try createOrUpdatePost(syncPost, blog: blog, categoryMap: categoryMap, tagMap: tagMap, embedImageData: embedImageData, isDraft: false, modelContext: modelContext, existingPost: existingPost)
            }
            appliedChanges += 1
        }

        for file in categorized.posts.deleted {
            progressUpdate(IncrementalSyncProgress(step: "Removing deleted posts...", phase: .applying, progress: Double(appliedChanges) / Double(max(1, totalChanges))))
            if let entityId = SyncChecker.extractEntityId(from: file.path),
               let post = postMap[entityId] {
                modelContext.delete(post)
            }
            appliedChanges += 1
        }

        // Step 7: Process sidebar changes
        var sidebarMap: [String: SidebarObject] = [:]
        for sidebar in blog.sidebarObjects {
            if let syncId = sidebar.syncId {
                sidebarMap[syncId] = sidebar
            }
        }

        // Note: For "new" sidebar objects, we still check sidebarMap by syncId to prevent duplicates
        // when syncing back after publishing from another client.
        for file in categorized.sidebar.new {
            progressUpdate(IncrementalSyncProgress(step: "Adding sidebar content...", phase: .applying, progress: Double(appliedChanges) / Double(max(1, totalChanges))))
            if let entityId = SyncChecker.extractEntityId(from: file.path) {
                let sidebarData = try await downloadFile(from: "\(baseURL)/sync/\(file.path)")
                let syncSidebar = try decoder.decode(SyncDataGenerator.SyncSidebarObject.self, from: sidebarData)

                if let existingSidebar = sidebarMap[syncSidebar.id] {
                    // Update existing sidebar
                    existingSidebar.title = syncSidebar.title
                    existingSidebar.content = syncSidebar.content
                    existingSidebar.order = syncSidebar.order

                    // Update links
                    for link in existingSidebar.links {
                        modelContext.delete(link)
                    }
                    if let links = syncSidebar.links {
                        for syncLink in links {
                            let link = LinkItem(sidebarObject: existingSidebar, title: syncLink.title, url: syncLink.url, order: syncLink.order)
                            modelContext.insert(link)
                        }
                    }
                } else {
                    let sidebarType: SidebarObjectType = syncSidebar.type == "linkList" ? .linkList : .text
                    let sidebar = SidebarObject(blog: blog, title: syncSidebar.title, type: sidebarType, order: syncSidebar.order)
                    sidebar.content = syncSidebar.content
                    sidebar.syncId = syncSidebar.id
                    modelContext.insert(sidebar)
                    sidebarMap[syncSidebar.id] = sidebar

                    if let links = syncSidebar.links {
                        for syncLink in links {
                            let link = LinkItem(sidebarObject: sidebar, title: syncLink.title, url: syncLink.url, order: syncLink.order)
                            modelContext.insert(link)
                        }
                    }
                }
            }
            appliedChanges += 1
        }

        for file in categorized.sidebar.modified {
            progressUpdate(IncrementalSyncProgress(step: "Updating sidebar content...", phase: .applying, progress: Double(appliedChanges) / Double(max(1, totalChanges))))
            if let entityId = SyncChecker.extractEntityId(from: file.path) {
                let sidebarData = try await downloadFile(from: "\(baseURL)/sync/\(file.path)")
                let syncSidebar = try decoder.decode(SyncDataGenerator.SyncSidebarObject.self, from: sidebarData)

                if let existingSidebar = sidebarMap[syncSidebar.id] {
                    existingSidebar.title = syncSidebar.title
                    existingSidebar.content = syncSidebar.content
                    existingSidebar.order = syncSidebar.order

                    // Update links
                    for link in existingSidebar.links {
                        modelContext.delete(link)
                    }
                    if let links = syncSidebar.links {
                        for syncLink in links {
                            let link = LinkItem(sidebarObject: existingSidebar, title: syncLink.title, url: syncLink.url, order: syncLink.order)
                            modelContext.insert(link)
                        }
                    }
                }
            }
            appliedChanges += 1
        }

        for file in categorized.sidebar.deleted {
            progressUpdate(IncrementalSyncProgress(step: "Removing deleted sidebar content...", phase: .applying, progress: Double(appliedChanges) / Double(max(1, totalChanges))))
            if let entityId = SyncChecker.extractEntityId(from: file.path),
               let sidebar = sidebarMap[entityId] {
                modelContext.delete(sidebar)
            }
            appliedChanges += 1
        }

        // Step 8: Process static file changes
        var staticFileMap: [String: StaticFile] = [:]
        for staticFile in blog.staticFiles {
            if let syncId = staticFile.syncId {
                staticFileMap[syncId] = staticFile
            }
        }

        // Note: For "new" static files, we still check staticFileMap by syncId to prevent duplicates
        // when syncing back after publishing from another client.
        for file in categorized.staticFiles.new {
            progressUpdate(IncrementalSyncProgress(step: "Downloading static files...", phase: .applying, progress: Double(appliedChanges) / Double(max(1, totalChanges))))
            let filename = file.path.replacingOccurrences(of: "static-files/", with: "")

            // Check if static file already exists locally
            if let existingStaticFile = staticFileMap[filename] {
                // Update existing static file
                let fileData = try await downloadFile(from: "\(baseURL)/sync/\(file.path)")
                existingStaticFile.data = fileData
            } else {
                let fileData = try await downloadFile(from: "\(baseURL)/sync/\(file.path)")

                // Get file info from static files index
                let staticIndexData = try await downloadFile(from: "\(baseURL)/sync/static-files/index.json")
                let staticIndex = try decoder.decode(SyncDataGenerator.SyncStaticFilesIndex.self, from: staticIndexData)
                let fileEntry = staticIndex.files.first { $0.filename == filename }

                let staticFile = StaticFile(
                    blog: blog,
                    filename: filename,
                    data: fileData,
                    mimeType: fileEntry?.mimeType ?? "application/octet-stream"
                )
                staticFile.isSpecialFile = fileEntry?.isSpecialFile ?? false
                staticFile.specialFileType = fileEntry?.specialFileType
                staticFile.syncId = filename
                modelContext.insert(staticFile)
                staticFileMap[filename] = staticFile
            }

            appliedChanges += 1
        }

        for file in categorized.staticFiles.deleted {
            progressUpdate(IncrementalSyncProgress(step: "Removing deleted static files...", phase: .applying, progress: Double(appliedChanges) / Double(max(1, totalChanges))))
            let filename = file.path.replacingOccurrences(of: "static-files/", with: "")
            if let staticFile = staticFileMap[filename] {
                modelContext.delete(staticFile)
            }
            appliedChanges += 1
        }

        // Step 9: Update sync state
        blog.lastSyncedVersion = manifest.contentVersion
        blog.lastSyncedAt = Date()

        // Store file hashes for incremental sync change detection
        var newHashes: [String: String] = [:]
        for (path, fileInfo) in manifest.files {
            newHashes[path] = fileInfo.hash
        }
        blog.localSyncHashes = newHashes

        // Save changes
        try modelContext.save()

        progressUpdate(IncrementalSyncProgress(step: "Sync complete!", phase: .complete, progress: 1))

        return IncrementalSyncResult(
            success: true,
            updated: true,
            message: "Synced \(appliedChanges) changes",
            changes: IncrementalSyncResult.ChangeCount(
                new: checkResult.newFiles.count,
                modified: checkResult.modifiedFiles.count,
                deleted: checkResult.deletedFiles.count
            )
        )
    }

    // MARK: - Helper Methods

    private static func normalizeURL(_ urlString: String) -> String {
        var url = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !url.hasPrefix("http://") && !url.hasPrefix("https://") {
            url = "https://\(url)"
        }
        while url.hasSuffix("/") {
            url.removeLast()
        }
        return url
    }

    private static func downloadFile(from urlString: String) async throws -> Data {
        guard let url = URL(string: urlString) else {
            throw SyncError.networkError("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw SyncError.networkError("HTTP error for \(urlString)")
        }

        return data
    }

    private static func createOrUpdatePost(
        _ syncPost: SyncDataGenerator.SyncPost,
        blog: Blog,
        categoryMap: [String: Category],
        tagMap: [String: Tag],
        embedImageData: [String: Data],
        isDraft: Bool,
        modelContext: ModelContext,
        existingPost: Post?
    ) throws {
        let post: Post
        if let existing = existingPost {
            post = existing
            post.content = syncPost.content
            post.title = syncPost.title
            post.stub = syncPost.stub
            post.isDraft = isDraft

            // Clear existing tags
            post.tags = []

            // Remove existing embed
            if let oldEmbed = post.embed {
                modelContext.delete(oldEmbed)
            }
        } else {
            post = Post(content: syncPost.content)
            post.blog = blog
            post.title = syncPost.title
            post.stub = syncPost.stub
            post.isDraft = isDraft
            post.syncId = syncPost.id
            modelContext.insert(post)
        }

        // Parse created date
        if let createdAt = parseDate(syncPost.createdAt) {
            post.createdAt = createdAt
        }

        // Parse updated date
        if let updatedAt = parseDate(syncPost.updatedAt) {
            post.updatedAt = updatedAt
        }

        // Set category
        if let categoryId = syncPost.categoryId, let category = categoryMap[categoryId] {
            post.category = category
        } else {
            post.category = nil
        }

        // Set tags
        for tagId in syncPost.tagIds {
            if let tag = tagMap[tagId] {
                post.tags.append(tag)
            }
        }

        // Create embed if present
        if let syncEmbed = syncPost.embed {
            let embedType: EmbedType
            switch syncEmbed.type.lowercased() {
            case "youtube": embedType = .youtube
            case "link": embedType = .link
            case "image": embedType = .image
            default: embedType = .link
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

            // Set the relationship first, then insert if needed
            post.embed = embed

            // Only explicitly insert for new posts; for existing posts the relationship handles it
            if existingPost == nil {
                modelContext.insert(embed)
            }

            // Create embed images for image type
            if embedType == .image {
                for syncImage in syncEmbed.images {
                    if let imageData = embedImageData[syncImage.filename] {
                        let embedImage = EmbedImage(embed: embed, imageData: imageData, order: syncImage.order, filename: syncImage.filename)
                        modelContext.insert(embedImage)
                    }
                }
            }
        }
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let isoFormatterNoFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let dateFormatterNoTimezone: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private static let dateFormatterNoTimezoneFractional: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private static let dateFormatterDateOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private static func parseDate(_ dateString: String) -> Date? {
        if let date = isoFormatter.date(from: dateString) {
            return date
        }
        if let date = isoFormatterNoFractional.date(from: dateString) {
            return date
        }
        if let date = dateFormatterNoTimezoneFractional.date(from: dateString) {
            return date
        }
        if let date = dateFormatterNoTimezone.date(from: dateString) {
            return date
        }
        if let date = dateFormatterDateOnly.date(from: dateString) {
            return date
        }
        return nil
    }
}

