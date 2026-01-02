//
//  StaticSiteGenerator.swift
//  Postalgic
//
//  Created by Brad Root on 4/19/25.
//
//  IMPORTANT: There are TWO separate hash/file tracking systems in Postalgic:
//
//  1. SMART PUBLISHING SYSTEM (`.postalgic/hashes.json`)
//     - Tracks hashes of ALL generated site files (HTML, CSS, images, sync/, etc.)
//     - Used for incremental/smart publishing to avoid re-uploading unchanged files
//     - Stored remotely on the published site in `.postalgic/hashes.json`
//     - Paths include everything: `index.html`, `css/style.css`, `sync/blog.json`, etc.
//
//  2. CROSS-PLATFORM SYNC SYSTEM (`/sync/manifest.json` + local sync state)
//     - Tracks hashes of ONLY sync data files (blog.json, posts/*.json, etc.)
//     - Used for syncing blog data between iOS and Self-Hosted apps
//     - Manifest stored at `/sync/manifest.json` on the published site
//     - Local hashes stored in Blog model's sync properties
//     - Paths are relative to sync folder: `blog.json`, `posts/xxx.json` (NO `sync/` prefix)
//
//  These systems are UNRELATED and should not be confused:
//  - `.postalgic/` = smart publishing hashes (full site)
//  - `/sync/` = cross-platform sync data (blog content only)
//

import Foundation
import Ink
import ZIPFoundation
import SwiftData

extension String {
    /// Formats a string for use in a URL path, replacing spaces with hyphens and ensuring URL safety
    func urlPathFormatted() -> String {
        return self.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
            ?? self.lowercased()
    }
}

extension Notification.Name {
    /// Notification sent when a publish status update is available
    static let publishStatusUpdated = Notification.Name("publishStatusUpdated")
}

/// StaticSiteGenerator handles the generation of a static site from a Blog model
class StaticSiteGenerator {
    private let blog: Blog
    private var siteDirectory: URL?
    private let templateEngine: TemplateEngine
    private let modelContext: ModelContext?
    private var forceFullUpload: Bool = false
    
    // MARK: - Error Handling

    /// Enum representing errors that can occur during site generation
    enum SiteGeneratorError: Error, LocalizedError {
        case noSiteDirectory
        case zipCreationFailed
        case publishingFailed(String)
        case templateRenderingFailed(String)

        var errorDescription: String? {
            switch self {
            case .noSiteDirectory:
                return "Failed to create site directory"
            case .zipCreationFailed:
                return "Failed to create ZIP file of the site"
            case .publishingFailed(let message):
                return "Publishing failed: \(message)"
            case .templateRenderingFailed(let message):
                return "Template rendering failed: \(message)"
            }
        }
    }

    /// Initializes a StaticSiteGenerator with a Blog model
    /// - Parameters:
    ///   - blog: The Blog to generate a site for
    ///   - modelContext: The SwiftData model context for fetching/saving file hashes
    ///   - forceFullUpload: Whether to force a full upload regardless of file changes
    init(blog: Blog, modelContext: ModelContext? = nil, forceFullUpload: Bool = false) {
        self.blog = blog
        self.templateEngine = TemplateEngine(blog: blog)
        self.modelContext = modelContext
        self.forceFullUpload = forceFullUpload
    }
    

    // MARK: - Site Generation Helpers

    /// Filter and sort posts to get only published posts in descending date order
    private func publishedPostsSorted() -> [Post] {
        return blog.posts
            .filter { !$0.isDraft }
            .sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Embed Helper
    
    /// Saves all embed images to the site directory
    private func saveEmbedImages(to directory: URL) {
        let publishedPosts = blog.posts.filter { !$0.isDraft }

        // Create directory for embed images if it doesn't exist
        let embedsDir = directory.appendingPathComponent("images/embeds")
        if !FileManager.default.fileExists(atPath: embedsDir.path) {
            do {
                try FileManager.default.createDirectory(at: embedsDir, withIntermediateDirectories: true)
                print("📁 Created directory for embed images: \(embedsDir.path)")
            } catch {
                print("⚠️ Error creating embed images directory: \(error)")
            }
        }

        print("🔍 Processing images for \(publishedPosts.count) published posts")

        for post in publishedPosts {
            if let embed = post.embed {
                if embed.embedType == .link, let imageData = embed.imageData {
                    // Create a predictable filename based on URL hash
                    let imageFilename = "embed-\(embed.url.hash).jpg"
                    let imagePath = embedsDir.appendingPathComponent(imageFilename)

                    print("📸 Saving link image to: \(imagePath.path)")

                    // Save the image data
                    do {
                        try imageData.write(to: imagePath)
                    } catch {
                        print("⚠️ Error saving link image: \(error)")
                    }
                }
                else if embed.embedType == .image {
                    // Save all images from the image embed
                    let sortedImages = embed.images.sorted { $0.order < $1.order }

                    print("📸 Saving \(sortedImages.count) images from image embed for post: \(post.title ?? "Untitled")")

                    for (index, image) in sortedImages.enumerated() {
                        let imagePath = embedsDir.appendingPathComponent(image.filename)

                        print("📸 Saving image \(index + 1)/\(sortedImages.count) to: \(imagePath.path)")

                        do {
                            try image.imageData.write(to: imagePath)
                        } catch {
                            print("⚠️ Error saving image: \(error)")
                        }
                    }
                }
            }
        }
    }
    
    /// Saves all static files to the site directory
    private func saveStaticFiles(to directory: URL) {
        print("📁 Processing \(blog.staticFiles.count) static files")
        
        for staticFile in blog.staticFiles {
            // Handle favicon specially to generate multiple sizes
            if staticFile.isSpecialFile && staticFile.fileType == .favicon {
                saveFaviconFiles(staticFile: staticFile, to: directory)
            } else {
                let filename = staticFile.filename
                
                // Create intermediate directories if needed
                let fileURL = directory.appendingPathComponent(filename)
                let directoryPath = fileURL.deletingLastPathComponent()
                
                if !FileManager.default.fileExists(atPath: directoryPath.path) {
                    do {
                        try FileManager.default.createDirectory(at: directoryPath, withIntermediateDirectories: true)
                        print("📁 Created directory: \(directoryPath.path)")
                    } catch {
                        print("⚠️ Error creating directory for static file \(filename): \(error)")
                        continue
                    }
                }
                
                // Write the file data
                do {
                    try staticFile.data.write(to: fileURL)
                    print("📄 Saved static file: \(filename) (\(staticFile.fileSizeString))")
                } catch {
                    print("⚠️ Error saving static file \(filename): \(error)")
                }
            }
        }
    }
    
    /// Saves favicon files in multiple sizes (32x32, 192x192, 180x180 for apple-touch-icon)
    private func saveFaviconFiles(staticFile: StaticFile, to directory: URL) {
        print("🎨 Processing favicon: generating multiple sizes")
        
        guard staticFile.isImage else {
            print("⚠️ Favicon is not an image format, saving as-is")
            do {
                let fileURL = directory.appendingPathComponent(staticFile.filename)
                try staticFile.data.write(to: fileURL)
                print("📄 Saved favicon: \(staticFile.filename)")
            } catch {
                print("⚠️ Error saving favicon: \(error)")
            }
            return
        }
        
        // Generate 32x32 favicon
        if let favicon32Data = Utils.resizeImage(imageData: staticFile.data, to: CGSize(width: 32, height: 32)) {
            do {
                let favicon32URL = directory.appendingPathComponent("favicon-32x32.png")
                try favicon32Data.write(to: favicon32URL)
                print("📄 Generated favicon-32x32.png")
            } catch {
                print("⚠️ Error saving 32x32 favicon: \(error)")
            }
        }
        
        // Generate 192x192 favicon
        if let favicon192Data = Utils.resizeImage(imageData: staticFile.data, to: CGSize(width: 192, height: 192)) {
            do {
                let favicon192URL = directory.appendingPathComponent("favicon-192x192.png")
                try favicon192Data.write(to: favicon192URL)
                print("📄 Generated favicon-192x192.png")
            } catch {
                print("⚠️ Error saving 192x192 favicon: \(error)")
            }
        }
        
        // Generate 180x180 apple-touch-icon
        if let appleTouchIconData = Utils.resizeImage(imageData: staticFile.data, to: CGSize(width: 180, height: 180)) {
            do {
                let appleTouchIconURL = directory.appendingPathComponent("apple-touch-icon.png")
                try appleTouchIconData.write(to: appleTouchIconURL)
                print("📄 Generated apple-touch-icon.png")
            } catch {
                print("⚠️ Error saving apple-touch-icon: \(error)")
            }
        }
    }

    // MARK: - File Tracking and Diffing
    
    /// Calculates hashes for all files in a directory
    /// - Parameter directory: Directory containing the files
    /// - Returns: Dictionary mapping file paths to content hashes
    private func calculateFileHashes(in directory: URL) throws -> [String: String] {
        let fileManager = FileManager.default
        var fileHashes: [String: String] = [:]
        
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw SiteGeneratorError.publishingFailed("Failed to enumerate site directory")
        }
        
        for case let fileURL as URL in enumerator {
            let attributes = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
            guard attributes.isRegularFile == true else { continue }
            
            // Get relative path for consistent keys
            let relativePath = fileURL.path.replacingOccurrences(
                of: directory.path,
                with: ""
            ).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            
            // Calculate hash of file content
            let fileData = try Data(contentsOf: fileURL)
            let hash = fileData.sha256Hash()
            
            fileHashes[relativePath] = hash
        }
        
        return fileHashes
    }
    
    /// Gets the previous PublishedFiles record for this blog and publisher
    /// - Returns: PublishedFiles if found, nil otherwise
    private func getPreviousPublishedFiles() -> PublishedFiles? {
        guard let modelContext = modelContext else {
            return nil
        }
        
        let publisherTypeString = blog.publisherType ?? PublisherType.none.rawValue
        
        // Find an existing record for this blog with the current publisher type
        return blog.publishedFiles.first { $0.publisherType == publisherTypeString }
    }
    
    /// Saves file hashes for this publication
    /// - Parameter hashes: Dictionary of file paths to content hashes
    private func saveFileHashes(_ hashes: [String: String]) {
        guard let modelContext = modelContext else {
            return
        }
        
        let publisherTypeString = blog.publisherType ?? PublisherType.none.rawValue
        
        // Check if a record already exists
        if let existingRecord = getPreviousPublishedFiles() {
            existingRecord.updateHashes(hashes)
        } else {
            // Create a new record
            let newRecord = PublishedFiles(blog: blog, publisherType: publisherTypeString)
            newRecord.updateHashes(hashes)
            modelContext.insert(newRecord)
            blog.publishedFiles.append(newRecord)
        }
        
        // Save changes
        do {
            try modelContext.save()
        } catch {
            print("Error saving published files: \(error)")
        }
    }
    
    // MARK: - Main Generation Methods

    /// Generates a static site for the blog
    /// - Returns: URL to the generated ZIP file if not publishing to AWS
    /// - Throws: SiteGeneratorError
    func generateSite() async throws -> URL? {
        // Create a temporary directory for the site
        let tempDirectory = FileManager.default.temporaryDirectory
        let siteDirectory = tempDirectory.appendingPathComponent(
            UUID().uuidString
        )

        try FileManager.default.createDirectory(
            at: siteDirectory,
            withIntermediateDirectories: true
        )
        self.siteDirectory = siteDirectory

        print("📝 Generating site in \(siteDirectory.path)")

        // Create CSS directory and file
        let cssDirectory = siteDirectory.appendingPathComponent("css")
        try FileManager.default.createDirectory(
            at: cssDirectory,
            withIntermediateDirectories: true
        )
        try templateEngine.renderCSS().write(
            to: cssDirectory.appendingPathComponent("style.css"),
            atomically: true,
            encoding: .utf8
        )
        
        // Create images/embeds directory for embed images
        let embedImagesDirectory = siteDirectory.appendingPathComponent("images/embeds")
        try FileManager.default.createDirectory(
            at: embedImagesDirectory,
            withIntermediateDirectories: true
        )
        
        // Extract and save all embed images
        saveEmbedImages(to: siteDirectory)
        
        // Save static files
        saveStaticFiles(to: siteDirectory)

        // Generate site content
        try generateIndexPage()
        try generatePostPages()
        try generateArchivesPage()
        try generateMonthlyArchivePages()
        try generateTagPages()
        try generateCategoryPages()
        try generateRSSFeed()
        
        // Generate robots.txt and sitemap.xml
        try generateRobotsTxt()
        try generateSitemap()

        // Generate sync directory if sync is enabled
        if blog.syncEnabled {
            NotificationCenter.default.post(
                name: .publishStatusUpdated,
                object: "Generating sync data..."
            )
            do {
                _ = try SyncDataGenerator.generateSyncDirectory(
                    for: blog,
                    in: siteDirectory
                ) { statusMessage in
                    NotificationCenter.default.post(
                        name: .publishStatusUpdated,
                        object: statusMessage
                    )
                }
            } catch {
                print("⚠️ Failed to generate sync data: \(error)")
                // Don't fail the whole publish - sync is optional
                NotificationCenter.default.post(
                    name: .publishStatusUpdated,
                    object: "Warning: Sync data generation failed: \(error.localizedDescription)"
                )
            }
        }

        // Get the appropriate publisher based on blog configuration
        var publisher: Publisher
        
        switch blog.currentPublisherType {
        case .aws:
            if blog.hasAwsConfigured {
                publisher = AWSPublisher(
                    region: blog.awsRegion!,
                    bucket: blog.awsS3Bucket!,
                    distributionId: blog.awsCloudFrontDistId!,
                    accessKeyId: blog.awsAccessKeyId!,
                    secretAccessKey: blog.getAwsSecretAccessKey()!
                )
            } else {
                // Fall back to manual if AWS is selected but not properly configured
                publisher = ManualPublisher()
            }
        case .ftp:
            if blog.hasFtpConfigured {
                publisher = FTPPublisher(
                    host: blog.ftpHost!,
                    port: blog.ftpPort!,
                    username: blog.ftpUsername!,
                    password: blog.getFtpPassword()!,
                    remotePath: blog.ftpPath!,
                    useSFTP: blog.ftpUseSFTP ?? false
                )
            } else {
                // Fall back to manual if FTP is selected but not properly configured
                publisher = ManualPublisher()
            }
        case .git:
            if blog.hasGitConfigured {
                publisher = GitPublisher(
                    repositoryUrl: blog.gitRepositoryUrl!,
                    username: blog.gitUsername!,
                    password: blog.getGitPassword()!,
                    branch: blog.gitBranch!,
                    commitMessage: blog.gitCommitMessage ?? "Update site content"
                )
            } else {
                // Fall back to manual if Git is selected but not properly configured
                publisher = ManualPublisher()
            }
        case .none:
            publisher = ManualPublisher()
        // Future publisher types would be handled here
        // case .netlify:
        //     publisher = NetlifyPublisher(...)
        default:
            // Use manual publisher by default
            throw SiteGeneratorError.publishingFailed("\(blog.publisherType ?? "Undefined") publishing is not available yet.")
        }
        
        do {
            print("🚀 Publishing site using \(publisher.publisherType.displayName) publisher...")

            // Calculate hashes for the newly generated files
            let newFileHashes = try calculateFileHashes(in: siteDirectory)

            // For Git publisher, write hash file to directory before publish
            if let gitPublisher = publisher as? GitPublisher {
                try gitPublisher.writeHashFile(to: siteDirectory, hashes: newFileHashes)
            }

            // Fetch remote hashes for cross-client change detection
            NotificationCenter.default.post(
                name: .publishStatusUpdated,
                object: "Checking for remote changes..."
            )
            let remoteHashFile = await publisher.fetchRemoteHashes()
            let previousHashes: [String: String]? = remoteHashFile?.fileHashes ?? getPreviousPublishedFiles()?.fileHashes

            // For smart publishing, we need the previous file hashes
            if !forceFullUpload, let previousHashes = previousHashes {
                // Determine which files changed
                let changes = determineChanges(oldHashes: previousHashes, newHashes: newFileHashes)

                if changes.hasChanges {
                    NotificationCenter.default.post(
                        name: .publishStatusUpdated,
                        object: "Smart publishing: \(changes.modified.count) files to update, \(changes.deleted.count) files to delete"
                    )

                    // Selectively publish only changed files
                    let result = try await publisher.smartPublish(
                        directoryURL: siteDirectory,
                        modifiedFiles: changes.modified,
                        deletedFiles: changes.deleted
                    ) { statusMessage in
                        NotificationCenter.default.post(
                            name: .publishStatusUpdated,
                            object: statusMessage
                        )
                    }

                    // Upload hash file to remote (AWS/SFTP - Git already has it in the commit)
                    if !(publisher is GitPublisher) {
                        try await publisher.uploadHashFile(hashes: newFileHashes)
                    }

                    // Save the new file hashes locally after successful publishing
                    saveFileHashes(newFileHashes)

                    return result
                } else {
                    NotificationCenter.default.post(
                        name: .publishStatusUpdated,
                        object: "No changes detected since last publish. Nothing to upload."
                    )
                    return nil
                }
            } else {
                // Full upload (forced or no previous publish data)
                if forceFullUpload {
                    NotificationCenter.default.post(
                        name: .publishStatusUpdated,
                        object: "Performing full site upload as requested"
                    )
                } else {
                    NotificationCenter.default.post(
                        name: .publishStatusUpdated,
                        object: "No previous publish data found. Performing full site upload."
                    )
                }

                let result = try await publisher.publish(directoryURL: siteDirectory) { statusMessage in
                    NotificationCenter.default.post(
                        name: .publishStatusUpdated,
                        object: statusMessage
                    )
                }

                // Upload hash file to remote (AWS/SFTP - Git already has it in the commit)
                if !(publisher is GitPublisher) {
                    try await publisher.uploadHashFile(hashes: newFileHashes)
                }

                // Save the file hashes locally after successful publishing
                saveFileHashes(newFileHashes)

                return result
            }
        } catch {
            throw SiteGeneratorError.publishingFailed("\(publisher.publisherType.displayName) publishing failed: \(error.localizedDescription)")
        }
    }

    /// Determines which files have changed between old and new hashes
    private func determineChanges(oldHashes: [String: String], newHashes: [String: String]) -> (hasChanges: Bool, modified: [String], deleted: [String]) {
        var modified: [String] = []
        var deleted: [String] = []

        // Check for new and modified files
        for (path, hash) in newHashes {
            if oldHashes[path] != hash {
                modified.append(path)
            }
        }

        // Check for deleted files
        for path in oldHashes.keys {
            if newHashes[path] == nil {
                deleted.append(path)
            }
        }

        return (hasChanges: !modified.isEmpty || !deleted.isEmpty, modified: modified, deleted: deleted)
    }

    /// Generates an RSS feed for the blog posts
    /// - Throws: SiteGeneratorError
    private func generateRSSFeed() throws {
        guard let siteDirectory = siteDirectory else {
            throw SiteGeneratorError.noSiteDirectory
        }

        let rssPath = siteDirectory.appendingPathComponent("rss.xml")
        let sortedPosts = publishedPostsSorted()
        let limitedPosts = Array(sortedPosts.prefix(20))  // Get only the 20 most recent posts

        do {
            let rssContent = try templateEngine.renderRSSFeed(posts: limitedPosts)
            try rssContent.write(to: rssPath, atomically: true, encoding: .utf8)
        } catch {
            throw SiteGeneratorError.templateRenderingFailed("RSS feed generation failed: \(error.localizedDescription)")
        }
    }

    /// Generates the index page (home page) of the site
    private func generateIndexPage() throws {
        guard let siteDirectory = siteDirectory else {
            throw SiteGeneratorError.noSiteDirectory
        }

        let indexPath = siteDirectory.appendingPathComponent("index.html")
        let sortedPosts = publishedPostsSorted()
        
        // Limit to 10 posts on index page
        let indexPosts = Array(sortedPosts.prefix(10))
        let hasMorePosts = sortedPosts.count > 10

        do {
            let pageContent = try templateEngine.renderIndexPage(posts: indexPosts, hasMorePosts: hasMorePosts)
            try pageContent.write(to: indexPath, atomically: true, encoding: .utf8)
        } catch {
            throw SiteGeneratorError.templateRenderingFailed("Index page generation failed: \(error.localizedDescription)")
        }
    }

    /// Generates individual pages for each post
    private func generatePostPages() throws {
        guard let siteDirectory = siteDirectory else {
            throw SiteGeneratorError.noSiteDirectory
        }

        let publishedPosts = blog.posts.filter { !$0.isDraft }
        for post in publishedPosts {
            // Ensure post has a stub before generating pages
            if post.stub == nil || post.stub!.isEmpty {
                post.regenerateStub()
            }

            // Create directory structure based on post's urlPath
            let postPath = post.urlPath
            let postDirectory = siteDirectory.appendingPathComponent(postPath)
            try FileManager.default.createDirectory(
                at: postDirectory,
                withIntermediateDirectories: true
            )

            // Generate the post content
            let postFilePath = postDirectory.appendingPathComponent("index.html")

            do {
                let postContent = try templateEngine.renderPostPage(post: post)
                try postContent.write(
                    to: postFilePath,
                    atomically: true,
                    encoding: .utf8
                )
            } catch {
                throw SiteGeneratorError.templateRenderingFailed("Post page generation failed for \(post.displayTitle): \(error.localizedDescription)")
            }
        }
    }

    /// Generates an archives page organizing posts by year and month
    private func generateArchivesPage() throws {
        guard let siteDirectory = siteDirectory else {
            throw SiteGeneratorError.noSiteDirectory
        }

        // Create archives directory
        let archivesDirectory = siteDirectory.appendingPathComponent("archives")
        try FileManager.default.createDirectory(
            at: archivesDirectory,
            withIntermediateDirectories: true
        )

        let archivesPath = archivesDirectory.appendingPathComponent(
            "index.html"
        )
        let sortedPosts = publishedPostsSorted()

        do {
            let archivesContent = try templateEngine.renderArchivesPage(posts: sortedPosts)
            try archivesContent.write(
                to: archivesPath,
                atomically: true,
                encoding: .utf8
            )
        } catch {
            throw SiteGeneratorError.templateRenderingFailed("Archives page generation failed: \(error.localizedDescription)")
        }
    }
    
    /// Generates monthly archive pages for each year/month combination
    private func generateMonthlyArchivePages() throws {
        guard let siteDirectory = siteDirectory else {
            throw SiteGeneratorError.noSiteDirectory
        }

        let sortedPosts = publishedPostsSorted()
        let calendar = Calendar.current
        
        // Group posts by year and month
        var yearMonthPosts: [Int: [Int: [Post]]] = [:]
        
        for post in sortedPosts {
            let year = calendar.component(.year, from: post.createdAt)
            let month = calendar.component(.month, from: post.createdAt)
            
            if yearMonthPosts[year] == nil {
                yearMonthPosts[year] = [:]
            }
            
            if yearMonthPosts[year]?[month] == nil {
                yearMonthPosts[year]?[month] = []
            }
            
            yearMonthPosts[year]?[month]?.append(post)
        }
        
        // Generate archive pages for each year/month combination
        for (year, months) in yearMonthPosts {
            for (month, posts) in months {
                // Create directory structure: /yyyy/MM/
                let yearDirectory = siteDirectory.appendingPathComponent(String(format: "%04d", year))
                let monthDirectory = yearDirectory.appendingPathComponent(String(format: "%02d", month))
                
                try FileManager.default.createDirectory(
                    at: monthDirectory,
                    withIntermediateDirectories: true
                )
                
                let monthlyArchivePath = monthDirectory.appendingPathComponent("index.html")
                
                // Sort posts within the month chronologically (newest first)
                let sortedMonthPosts = posts.sorted { $0.createdAt > $1.createdAt }
                
                // Get previous and next month info for navigation
                let navInfo = getMonthNavigationInfo(currentYear: year, currentMonth: month, allYearMonths: yearMonthPosts)
                
                do {
                    let monthlyArchiveContent = try templateEngine.renderMonthlyArchivePage(
                        year: year,
                        month: month,
                        posts: sortedMonthPosts,
                        previousMonth: navInfo.previous,
                        nextMonth: navInfo.next
                    )
                    try monthlyArchiveContent.write(
                        to: monthlyArchivePath,
                        atomically: true,
                        encoding: .utf8
                    )
                } catch {
                    throw SiteGeneratorError.templateRenderingFailed("Monthly archive page generation failed for \(year)/\(month): \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Helper to get navigation info for a given year/month
    private func getMonthNavigationInfo(currentYear: Int, currentMonth: Int, allYearMonths: [Int: [Int: [Post]]]) -> (previous: (year: Int, month: Int)?, next: (year: Int, month: Int)?) {
        // Get all year/month combinations sorted chronologically
        var allMonths: [(year: Int, month: Int)] = []
        
        for (year, months) in allYearMonths {
            for month in months.keys {
                allMonths.append((year: year, month: month))
            }
        }
        
        allMonths.sort { first, second in
            if first.year != second.year {
                return first.year < second.year
            }
            return first.month < second.month
        }
        
        // Find current month index
        guard let currentIndex = allMonths.firstIndex(where: { $0.year == currentYear && $0.month == currentMonth }) else {
            return (previous: nil, next: nil)
        }
        
        let previousMonth = currentIndex > 0 ? allMonths[currentIndex - 1] : nil
        let nextMonth = currentIndex < allMonths.count - 1 ? allMonths[currentIndex + 1] : nil
        
        return (previous: previousMonth, next: nextMonth)
    }

    /// Generates tag pages for all tags used in posts
    private func generateTagPages() throws {
        guard let siteDirectory = siteDirectory else {
            throw SiteGeneratorError.noSiteDirectory
        }

        // Get tags that have published posts
        let publishedPosts = blog.posts.filter { !$0.isDraft }
        let tagsWithPublishedPosts = Set(publishedPosts.flatMap { $0.tags })
        let sortedTags = Array(tagsWithPublishedPosts).sorted {
            $0.name < $1.name
        }

        // Skip tag page generation if no tags exist
        guard !sortedTags.isEmpty else {
            return
        }

        // Create tags directory
        let tagsDirectory = siteDirectory.appendingPathComponent("tags")
        try FileManager.default.createDirectory(
            at: tagsDirectory,
            withIntermediateDirectories: true
        )

        // Create tag index page
        let tagsIndexPath = tagsDirectory.appendingPathComponent("index.html")
        
        do {
            // Create array of (tag, posts) tuples for the template
            let tagPostsPairs = sortedTags.map { tag in
                return (tag, publishedPosts.filter { $0.tags.contains(tag) })
            }
            
            let tagIndexPage = try templateEngine.renderTagsPage(tags: tagPostsPairs)
            try tagIndexPage.write(
                to: tagsIndexPath,
                atomically: true,
                encoding: .utf8
            )
        } catch {
            throw SiteGeneratorError.templateRenderingFailed("Tag index page generation failed: \(error.localizedDescription)")
        }

        // Create individual tag pages with pagination
        for tag in sortedTags {
            let tagPosts = publishedPosts.filter { $0.tags.contains(tag) }
                .sorted { $0.createdAt > $1.createdAt }
            
            try generatePaginatedTagPages(tag: tag, posts: tagPosts, tagsDirectory: tagsDirectory)
        }
    }
    
    /// Generates paginated pages for a specific tag
    private func generatePaginatedTagPages(tag: Tag, posts: [Post], tagsDirectory: URL) throws {
        let postsPerPage = 10
        let totalPages = max(1, Int(ceil(Double(posts.count) / Double(postsPerPage))))
        
        // Use the tag's urlPath property
        let tagPathComponent = tag.urlPath
        let tagDirectory = tagsDirectory.appendingPathComponent(tagPathComponent)
        try FileManager.default.createDirectory(
            at: tagDirectory,
            withIntermediateDirectories: true
        )
        
        for page in 1...totalPages {
            let startIndex = (page - 1) * postsPerPage
            let endIndex = min(startIndex + postsPerPage, posts.count)
            let postsForPage = Array(posts[startIndex..<endIndex])
            
            // Determine the file path for this page
            let pageDirectory: URL
            let pagePath: URL
            
            if page == 1 {
                // First page goes to /tags/tag-name/index.html
                pageDirectory = tagDirectory
                pagePath = pageDirectory.appendingPathComponent("index.html")
            } else {
                // Other pages go to /tags/tag-name/page/2/index.html, etc.
                pageDirectory = tagDirectory.appendingPathComponent("page").appendingPathComponent("\(page)")
                try FileManager.default.createDirectory(at: pageDirectory, withIntermediateDirectories: true)
                pagePath = pageDirectory.appendingPathComponent("index.html")
            }
            
            do {
                let tagPageContent = try templateEngine.renderTagPage(
                    tag: tag,
                    posts: postsForPage,
                    currentPage: page,
                    totalPages: totalPages,
                    totalPosts: posts.count
                )
                try tagPageContent.write(
                    to: pagePath,
                    atomically: true,
                    encoding: .utf8
                )
            } catch {
                throw SiteGeneratorError.templateRenderingFailed("Tag page generation failed for \(tag.name) page \(page): \(error.localizedDescription)")
            }
        }
    }

    /// Generates category pages for all categories used in posts
    private func generateCategoryPages() throws {
        guard let siteDirectory = siteDirectory else {
            throw SiteGeneratorError.noSiteDirectory
        }

        // Get categories that have published posts
        let publishedPosts = blog.posts.filter { !$0.isDraft }
        let categoriesWithPublishedPosts = Set(
            publishedPosts.compactMap { $0.category }
        )
        let sortedCategories = Array(categoriesWithPublishedPosts).sorted {
            $0.name < $1.name
        }

        // Skip category page generation if no categories exist
        guard !sortedCategories.isEmpty else {
            return
        }

        // Create categories directory
        let categoriesDirectory = siteDirectory.appendingPathComponent(
            "categories"
        )
        try FileManager.default.createDirectory(
            at: categoriesDirectory,
            withIntermediateDirectories: true
        )

        // Create category index page
        let categoriesIndexPath = categoriesDirectory.appendingPathComponent(
            "index.html"
        )

        do {
            // Create array of (category, posts) tuples for the template
            let categoryPostsPairs = sortedCategories.map { category in
                return (category, publishedPosts.filter { $0.category?.id == category.id })
            }
            
            let categoryIndexPage = try templateEngine.renderCategoriesPage(categories: categoryPostsPairs)
            try categoryIndexPage.write(
                to: categoriesIndexPath,
                atomically: true,
                encoding: .utf8
            )
        } catch {
            throw SiteGeneratorError.templateRenderingFailed("Category index page generation failed: \(error.localizedDescription)")
        }

        // Create individual category pages with pagination
        for category in sortedCategories {
            let categoryPosts = publishedPosts.filter {
                $0.category?.id == category.id
            }.sorted { $0.createdAt > $1.createdAt }
            
            try generatePaginatedCategoryPages(category: category, posts: categoryPosts, categoriesDirectory: categoriesDirectory)
        }
    }
    
    /// Generates paginated pages for a specific category
    private func generatePaginatedCategoryPages(category: Category, posts: [Post], categoriesDirectory: URL) throws {
        let postsPerPage = 10
        let totalPages = max(1, Int(ceil(Double(posts.count) / Double(postsPerPage))))
        
        // Use the category's urlPath property
        let categoryPathComponent = category.urlPath
        let categoryDirectory = categoriesDirectory.appendingPathComponent(categoryPathComponent)
        try FileManager.default.createDirectory(
            at: categoryDirectory,
            withIntermediateDirectories: true
        )
        
        for page in 1...totalPages {
            let startIndex = (page - 1) * postsPerPage
            let endIndex = min(startIndex + postsPerPage, posts.count)
            let postsForPage = Array(posts[startIndex..<endIndex])
            
            // Determine the file path for this page
            let pageDirectory: URL
            let pagePath: URL
            
            if page == 1 {
                // First page goes to /categories/category-name/index.html
                pageDirectory = categoryDirectory
                pagePath = pageDirectory.appendingPathComponent("index.html")
            } else {
                // Other pages go to /categories/category-name/page/2/index.html, etc.
                pageDirectory = categoryDirectory.appendingPathComponent("page").appendingPathComponent("\(page)")
                try FileManager.default.createDirectory(at: pageDirectory, withIntermediateDirectories: true)
                pagePath = pageDirectory.appendingPathComponent("index.html")
            }
            
            do {
                let categoryPageContent = try templateEngine.renderCategoryPage(
                    category: category,
                    posts: postsForPage,
                    currentPage: page,
                    totalPages: totalPages,
                    totalPosts: posts.count
                )
                try categoryPageContent.write(
                    to: pagePath,
                    atomically: true,
                    encoding: .utf8
                )
            } catch {
                throw SiteGeneratorError.templateRenderingFailed("Category page generation failed for \(category.name) page \(page): \(error.localizedDescription)")
            }
        }
    }
    
    /// Generates a robots.txt file for the site
    private func generateRobotsTxt() throws {
        guard let siteDirectory = siteDirectory else {
            throw SiteGeneratorError.noSiteDirectory
        }
        
        let robotsPath = siteDirectory.appendingPathComponent("robots.txt")
        
        do {
            let robotsContent = try templateEngine.renderRobotsTxt()
            try robotsContent.write(to: robotsPath, atomically: true, encoding: .utf8)
        } catch {
            throw SiteGeneratorError.templateRenderingFailed("Robots.txt generation failed: \(error.localizedDescription)")
        }
    }
    
    /// Generates a sitemap.xml file for the site
    private func generateSitemap() throws {
        guard let siteDirectory = siteDirectory else {
            throw SiteGeneratorError.noSiteDirectory
        }
        
        let sitemapPath = siteDirectory.appendingPathComponent("sitemap.xml")
        let sortedPosts = publishedPostsSorted()
        
        // Get all tags and categories used in published posts
        let tags = Array(Set(sortedPosts.flatMap { $0.tags }))
        let categories = Array(Set(sortedPosts.compactMap { $0.category }))
        
        // Generate monthly archive info for sitemap
        let calendar = Calendar.current
        var yearMonthCombos: [(year: Int, month: Int)] = []
        
        let groupedPosts = Dictionary(grouping: sortedPosts) { post in
            let year = calendar.component(.year, from: post.createdAt)
            let month = calendar.component(.month, from: post.createdAt)
            return "\(year)-\(month)"
        }
        
        for posts in groupedPosts.values {
            if let firstPost = posts.first {
                let year = calendar.component(.year, from: firstPost.createdAt)
                let month = calendar.component(.month, from: firstPost.createdAt)
                yearMonthCombos.append((year: year, month: month))
            }
        }
        
        do {
            let sitemapContent = try templateEngine.renderSitemap(
                posts: sortedPosts,
                tags: tags,
                categories: categories,
                monthlyArchives: yearMonthCombos
            )
            try sitemapContent.write(to: sitemapPath, atomically: true, encoding: .utf8)
        } catch {
            throw SiteGeneratorError.templateRenderingFailed("Sitemap generation failed: \(error.localizedDescription)")
        }
    }
}
