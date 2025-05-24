//
//  StaticSiteGenerator.swift
//  Postalgic
//
//  Created by Brad Root on 4/19/25.
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
        try generateTagPages()
        try generateCategoryPages()
        try generateRSSFeed()
        
        // Generate robots.txt and sitemap.xml
        try generateRobotsTxt()
        try generateSitemap()

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
            
            // For smart publishing, we need the previous file hashes
            if !forceFullUpload, let previousFiles = getPreviousPublishedFiles() {
                // Determine which files changed
                let changes = previousFiles.determineChanges(with: newFileHashes)
                
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
                    
                    // Save the new file hashes after successful publishing
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
                
                // Save the file hashes after successful publishing
                saveFileHashes(newFileHashes)
                
                return result
            }
        } catch {
            throw SiteGeneratorError.publishingFailed("\(publisher.publisherType.displayName) publishing failed: \(error.localizedDescription)")
        }
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

        do {
            let pageContent = try templateEngine.renderIndexPage(posts: sortedPosts)
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

        // Always create tags directory
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

        // Create individual tag pages
        for tag in sortedTags {
            let tagPosts = publishedPosts.filter { $0.tags.contains(tag) }
                .sorted { $0.createdAt > $1.createdAt }
            
            // Use the tag's urlPath property
            let tagPathComponent = tag.urlPath
            let tagDirectory = tagsDirectory.appendingPathComponent(
                tagPathComponent
            )
            try FileManager.default.createDirectory(
                at: tagDirectory,
                withIntermediateDirectories: true
            )
            let tagPath = tagDirectory.appendingPathComponent("index.html")

            do {
                let tagPageContent = try templateEngine.renderTagPage(tag: tag, posts: tagPosts)
                try tagPageContent.write(
                    to: tagPath,
                    atomically: true,
                    encoding: .utf8
                )
            } catch {
                throw SiteGeneratorError.templateRenderingFailed("Tag page generation failed for \(tag.name): \(error.localizedDescription)")
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

        // Always create categories directory
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

        // Create individual category pages
        for category in sortedCategories {
            let categoryPosts = publishedPosts.filter {
                $0.category?.id == category.id
            }.sorted { $0.createdAt > $1.createdAt }
            
            // Use the category's urlPath property
            let categoryPathComponent = category.urlPath
            let categoryDirectory = categoriesDirectory.appendingPathComponent(
                categoryPathComponent
            )
            try FileManager.default.createDirectory(
                at: categoryDirectory,
                withIntermediateDirectories: true
            )
            let categoryPath = categoryDirectory.appendingPathComponent(
                "index.html"
            )

            do {
                let categoryPageContent = try templateEngine.renderCategoryPage(category: category, posts: categoryPosts)
                try categoryPageContent.write(
                    to: categoryPath,
                    atomically: true,
                    encoding: .utf8
                )
            } catch {
                throw SiteGeneratorError.templateRenderingFailed("Category page generation failed for \(category.name): \(error.localizedDescription)")
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
        
        do {
            let sitemapContent = try templateEngine.renderSitemap(
                posts: sortedPosts,
                tags: tags,
                categories: categories
            )
            try sitemapContent.write(to: sitemapPath, atomically: true, encoding: .utf8)
        } catch {
            throw SiteGeneratorError.templateRenderingFailed("Sitemap generation failed: \(error.localizedDescription)")
        }
    }
}
