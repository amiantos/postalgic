//
//  Models.swift
//  Postalgic
//
//  Created by Brad Root on 4/19/25.
//

import Foundation
import SwiftData
import Ink

// Publisher type enum
enum PublisherType: String, Codable, CaseIterable {
    case none = "Manual Download (Zip)"
    case aws = "AWS"
    case ftp = "SFTP"
//    case netlify = "Netlify"
//    case github = "GitHub Pages"
//    case gitlab = "GitLab Pages"
//    case digitalOcean = "DigitalOcean Spaces"
    
    var displayName: String { rawValue }
}


@Model
final class Blog {
    var name: String
    var url: String
    var createdAt: Date

    // Blog metadata
    var authorName: String?
    var authorUrl: String?
    var authorEmail: String?
    var tagline: String?

    // Blog appearance
    var accentColor: String?
    var themeIdentifier: String?

    // Publisher Type
    var publisherType: String?

    // AWS Configuration
    var awsRegion: String?
    var awsS3Bucket: String?
    var awsCloudFrontDistId: String?
    var awsAccessKeyId: String?
    var awsSecretAccessKey: String?

    // FTP Configuration
    var ftpHost: String?
    var ftpPort: Int?
    var ftpUsername: String?
    var ftpPassword: String?
    var ftpPath: String?
    var ftpUseSFTP: Bool?
    
    // Future Netlify Configuration
    // var netlifyToken: String?
    // var netlifySiteId: String?

    @Relationship(deleteRule: .cascade, inverse: \Post.blog)
    var posts: [Post] = []

    @Relationship(deleteRule: .cascade, inverse: \Category.blog)
    var categories: [Category] = []

    @Relationship(deleteRule: .cascade, inverse: \Tag.blog)
    var tags: [Tag] = []
    
    
    @Relationship(deleteRule: .cascade, inverse: \PublishedFiles.blog)
    var publishedFiles: [PublishedFiles] = []
    
    @Relationship(deleteRule: .cascade, inverse: \SidebarObject.blog)
    var sidebarObjects: [SidebarObject] = []

    init(name: String, url: String, createdAt: Date = Date(), authorName: String? = nil, authorEmail: String? = nil, authorUrl: String? = nil, tagline: String? = nil, accentColor: String? = "#FFA100") {
        self.name = name
        self.url = url
        self.createdAt = createdAt
        self.authorName = authorName
        self.authorEmail = authorEmail
        self.authorUrl = authorUrl
        self.tagline = tagline
        self.accentColor = accentColor
        self.publisherType = PublisherType.none.rawValue
        self.themeIdentifier = "default"
    }

    var hasAwsConfigured: Bool {
        return awsRegion != nil && !awsRegion!.isEmpty && awsS3Bucket != nil
            && !awsS3Bucket!.isEmpty && awsCloudFrontDistId != nil
            && !awsCloudFrontDistId!.isEmpty && awsAccessKeyId != nil
            && !awsAccessKeyId!.isEmpty && awsSecretAccessKey != nil
            && !awsSecretAccessKey!.isEmpty
    }
    
    var hasFtpConfigured: Bool {
        return ftpHost != nil && !ftpHost!.isEmpty && ftpUsername != nil
            && !ftpUsername!.isEmpty && ftpPassword != nil
            && !ftpPassword!.isEmpty && ftpPath != nil
            && !ftpPath!.isEmpty && ftpPort != nil
    }
    
    var currentPublisherType: PublisherType {
        return PublisherType(rawValue: publisherType ?? "") ?? .none
    }
    
    // MARK: - Stub Management
    
    /// Returns all used post stubs in this blog
    /// - Returns: Array of post stub strings
    func usedPostStubs() -> [String] {
        return posts.compactMap { $0.stub }
    }

    /// Returns all used post stubs in this blog except for the specified post
    /// - Parameter except: Post to exclude from the stubs list
    /// - Returns: Array of post stub strings
    func usedPostStubs(except: Post) -> [String] {
        return posts.filter { $0.id != except.id }.compactMap { $0.stub }
    }

    /// Returns all used category stubs in this blog
    /// - Returns: Array of category stub strings
    func usedCategoryStubs() -> [String] {
        return categories.compactMap { $0.stub }
    }

    /// Returns all used tag stubs in this blog
    /// - Returns: Array of tag stub strings
    func usedTagStubs() -> [String] {
        return tags.compactMap { $0.stub }
    }

    /// Ensures a post stub is unique within this blog
    /// - Parameter stub: The stub to make unique
    /// - Returns: A unique stub for the post
    func uniquePostStub(_ stub: String) -> String {
        return Utils.makeStubUnique(stub: stub, existingStubs: usedPostStubs())
    }

    /// Ensures a post stub is unique within this blog, excluding the specified post
    /// - Parameters:
    ///   - stub: The stub to make unique
    ///   - except: Post to exclude from the uniqueness check
    /// - Returns: A unique stub for the post
    func uniquePostStub(_ stub: String, except: Post) -> String {
        return Utils.makeStubUnique(stub: stub, existingStubs: usedPostStubs(except: except))
    }

    /// Ensures a category stub is unique within this blog
    /// - Parameter stub: The stub to make unique
    /// - Returns: A unique stub for the category
    func uniqueCategoryStub(_ stub: String) -> String {
        return Utils.makeStubUnique(stub: stub, existingStubs: usedCategoryStubs())
    }

    /// Ensures a tag stub is unique within this blog
    /// - Parameter stub: The stub to make unique
    /// - Returns: A unique stub for the tag
    func uniqueTagStub(_ stub: String) -> String {
        return Utils.makeStubUnique(stub: stub, existingStubs: usedTagStubs())
    }
    
}

@Model
final class Category {
    var name: String
    var categoryDescription: String?
    var createdAt: Date
    var stub: String?

    var blog: Blog?
    var posts: [Post] = []

    init(
        blog: Blog,
        name: String,
        categoryDescription: String? = nil,
        createdAt: Date = Date(),
        stub: String? = nil
    ) {
        self.blog = blog
        self.name = name.capitalized
        self.categoryDescription = categoryDescription
        self.createdAt = createdAt
        self.stub = stub
        
        // Generate stub if not provided
        if self.stub == nil {
            self.stub = Utils.generateStub(from: name)
        }
    }
    
    /// Returns the URL path for this category
    var urlPath: String {
        if let stub = stub, !stub.isEmpty {
            return stub
        }
        // Fallback to using formatted name
        return name.urlPathFormatted()
    }
}

@Model
final class Tag {
    var name: String
    var createdAt: Date
    var stub: String?

    var blog: Blog?
    var posts: [Post] = []

    init(blog: Blog, name: String, createdAt: Date = Date(), stub: String? = nil) {
        self.blog = blog
        self.name = name.lowercased()
        self.createdAt = createdAt
        self.stub = stub
        
        // Generate stub if not provided
        if self.stub == nil {
            self.stub = Utils.generateStub(from: name)
        }
    }
    
    /// Returns the URL path for this tag
    var urlPath: String {
        if let stub = stub, !stub.isEmpty {
            return stub
        }
        // Fallback to using formatted name
        return name.urlPathFormatted()
    }
}

enum EmbedType: String, Codable {
    case youtube = "YouTube"
    case link = "Link"
    case image = "Image"
}

enum EmbedPosition: String, Codable {
    case above = "Above"
    case below = "Below"
}

@Model
final class Embed {
    var post: Post?

    var url: String
    var type: String // EmbedType.rawValue
    var position: String // EmbedPosition.rawValue
    var createdAt: Date

    // These properties are for Link type embeds
    var title: String?
    var embedDescription: String?
    var imageUrl: String? // Remote URL for the image
    @Attribute(.externalStorage) var imageData: Data? // Actual image data stored in the database

    // These properties are for Image type embeds
    @Relationship(deleteRule: .cascade, inverse: \EmbedImage.embed)
    var images: [EmbedImage] = []

    init(
        post: Post,
        url: String,
        type: EmbedType,
        position: EmbedPosition,
        title: String? = nil,
        embedDescription: String? = nil,
        imageUrl: String? = nil,
        imageData: Data? = nil,
        createdAt: Date = Date()
    ) {
        self.post = post
        self.url = url
        self.type = type.rawValue
        self.position = position.rawValue
        self.title = title
        self.embedDescription = embedDescription
        self.imageUrl = imageUrl
        self.imageData = imageData
        self.createdAt = createdAt
    }
    
    var embedType: EmbedType {
        return EmbedType(rawValue: type) ?? .link
    }
    
    var embedPosition: EmbedPosition {
        return EmbedPosition(rawValue: position) ?? .below
    }
    
    // Generate HTML for the embed based on type
    func generateHtml() -> String {
        switch embedType {
        case .youtube:
            // Extract YouTube video ID from URL
            if let videoId = Utils.extractYouTubeId(from: url) {
                return """
                <div class="embed youtube-embed">
                    <iframe width="560" height="315" src="https://www.youtube.com/embed/\(videoId)" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>
                </div>
                """
            } else {
                return "<!-- Invalid YouTube URL: \(url) -->"
            }
        case .link:
            var html = "<div class=\"embed link-embed\">"
            html += "<a href=\"\(url)\" target=\"_blank\" rel=\"noopener noreferrer\">"

            if let title = title {
                html += "<div class=\"link-title\">\(title)</div>"
            }

            if let _ = imageData {
                // When we have image data, we'll create a unique filename for the image
                // based on a hash of the URL to ensure stability across generations
                let imageFilename = "embed-\(url.hash).jpg"
                let imagePath = "/images/embeds/\(imageFilename)"
                html += "<div class=\"link-image\"><img src=\"\(imagePath)\" alt=\"\(title ?? "Link preview")\" /></div>"
            } else if let imageUrl = imageUrl {
                // Fallback to direct URL if we don't have image data stored
                html += "<div class=\"link-image\"><img src=\"\(imageUrl)\" alt=\"\(title ?? "Link preview")\" /></div>"
            }

            if let description = embedDescription {
                html += "<div class=\"link-description\">\(description)</div>"
            }

            html += "<div class=\"link-url\">\(url)</div>"
            html += "</a></div>"

            return html

        case .image:
            let sortedImages = images.sorted { $0.order < $1.order }

            // Single image display
            if sortedImages.count == 1, let image = sortedImages.first {
                return """
                <div class="embed image-embed single-image">
                    <a href="/images/embeds/\(image.filename)" class="lightbox-trigger" data-lightbox="embed-\(self.hashValue)" data-title="">
                        <img src="/images/embeds/\(image.filename)" alt="Image" class="embed-image" />
                    </a>
                </div>
                """
            }
            // Multiple images gallery
            else if sortedImages.count > 1 {
                var html = """
                <div class="embed image-embed gallery" id="gallery-\(self.hashValue)">
                    <div class="gallery-container">
                """

                // Add all images
                for image in sortedImages {
                    html += """
                        <div class="gallery-slide">
                            <a href="/images/embeds/\(image.filename)" class="lightbox-trigger" data-lightbox="embed-\(self.hashValue)" data-title="">
                                <img src="/images/embeds/\(image.filename)" alt="Image \(image.order + 1)" class="embed-image" />
                            </a>
                        </div>
                    """
                }

                // Add navigation arrows if more than one image
                html += """
                        <div class="gallery-nav">
                            <button class="gallery-prev" onclick="prevSlide('gallery-\(self.hashValue)')">❮</button>
                            <button class="gallery-next" onclick="nextSlide('gallery-\(self.hashValue)')">❯</button>
                        </div>
                    </div>
                    <div class="gallery-dots">
                """

                // Add indicator dots
                for i in 0..<sortedImages.count {
                    html += """
                        <span class="gallery-dot" onclick="showSlide('gallery-\(self.hashValue)', \(i))"></span>
                    """
                }

                html += """
                    </div>
                </div>
                <script>
                    initGallery('gallery-\(self.hashValue)');
                </script>
                """

                return html
            }
            else {
                return "<!-- No images available for this embed -->"
            }
        }
    }
}

@Model
final class Post {
    var blog: Blog? {
        didSet {
            // Ensure stub uniqueness when a post is assigned to a blog
            if let blog = blog, let stub = stub {
                self.stub = blog.uniquePostStub(stub)
            }
        }
    }
    
    var title: String? {
        didSet {
            updateStub()
        }
    }
    var content: String {
        didSet {
            updateStub()
        }
    }
    var createdAt: Date
    var stub: String?

    var isDraft: Bool = false
    
    /// Updates the stub based on current title or content
    private func updateStub() {
        // Don't regenerate stub if we're in the middle of being initialized
        // This is a workaround for when SwiftData is restoring objects from persistence
        guard !content.isEmpty || (title != nil && !title!.isEmpty) else { return }

        let sourceText: String

        if let title = title, !title.isEmpty {
            sourceText = title
        } else if !content.isEmpty {
            // Use the content, but strip Markdown formatting first
            sourceText = stripMarkdown(from: content)
        } else {
            // This should not happen due to the guard above, but providing a fallback
            sourceText = "post-\(Int(Date().timeIntervalSince1970))"
        }

        let newStub = Utils.generateStub(from: sourceText)

        // Always generate a new stub, even if the current one is nil
        if let blog = blog {
            // Use the method that excludes this post from uniqueness check
            self.stub = blog.uniquePostStub(newStub, except: self)
        } else {
            self.stub = newStub
        }
    }
    
    /// Public method to force regeneration of the post's stub
    public func regenerateStub() {
        updateStub()
    }

    @Relationship(deleteRule: .nullify, inverse: \Category.posts)
    var category: Category?

    @Relationship(deleteRule: .nullify, inverse: \Tag.posts)
    var tags: [Tag] = []
    
    @Relationship(deleteRule: .cascade, inverse: \Embed.post)
    var embed: Embed?

    init(
        title: String? = nil,
        content: String,
        createdAt: Date = Date(),
        isDraft: Bool = false,
        stub: String? = nil
    ) {
        self.title = title
        self.content = content
        self.createdAt = createdAt
        self.isDraft = isDraft
        
        // Generate stub if not provided
        if let providedStub = stub, !providedStub.isEmpty {
            self.stub = providedStub
        } else {
            let sourceText: String
            
            if let title = title, !title.isEmpty {
                sourceText = title
            } else {
                // Use the content, but strip Markdown formatting first
                sourceText = stripMarkdown(from: content)
            }
            
            self.stub = Utils.generateStub(from: sourceText)
        }
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }

    /// Returns the date-based portion of the URL path (without the stub)
    var dateUrlPath: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter.string(from: createdAt)
    }
    
    var dateTimeUrlPath: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd/HHmmss"
        return formatter.string(from: createdAt)
    }
    
    /// Returns the full URL path including stub if available
    var urlPath: String {
        if let stub = stub, !stub.isEmpty {
            return "\(dateUrlPath)/\(stub)"
        }
        return dateTimeUrlPath
    }
    
    var plainContent: String {
        return stripMarkdown(from: content)
    }

    var displayTitle: String {
        if let title = title {
            return title
        }
        
        // Strip Markdown syntax from content
        let plainContent = stripMarkdown(from: content)
        
        let maxLength = 50
        if plainContent.count <= maxLength {
            return plainContent
        }
        
        // Find the last space within the maximum length
        let truncated = plainContent.prefix(maxLength)
        if let lastSpace = truncated.lastIndex(of: " ") {
            let wordBoundaryIndex = plainContent.index(lastSpace, offsetBy: 0)
            return String(plainContent[..<wordBoundaryIndex]) + "..."
        } else {
            return String(truncated) + "..."
        }
    }
    
    /// Strips common Markdown syntax from text
    private func stripMarkdown(from text: String) -> String {
        var result = text
        
        // Regular expressions for common Markdown patterns
        let patterns = [
            // Links: [text](url) -> text
            "\\[([^\\]]+)\\]\\([^)]+\\)": "$1",
            // Bold: **text** or __text__ -> text
            "\\*\\*([^*]+)\\*\\*|__([^_]+)__": "$1$2",
            // Italic: *text* or _text_ -> text
            "\\*([^*]+)\\*|_([^_]+)_": "$1$2",
            // Headers: #+ text -> text
            "^#+\\s+(.+)$": "$1",
            // Code blocks: `text` -> text
            "`([^`]+)`": "$1",
            // Strikethrough: ~~text~~ -> text
            "~~([^~]+)~~": "$1",
            // Images: ![alt](url) -> alt
            "!\\[([^\\]]+)\\]\\([^)]+\\)": "$1"
        ]
        
        for (pattern, replacement) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(location: 0, length: result.utf16.count)
                result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: replacement)
            }
        }
        
        // Remove any remaining Markdown characters
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return result
    }

    var tagNames: [String] {
        return tags.map { $0.name }
    }

    var formattedTags: String {
        return tagNames.joined(separator: ", ")
    }
}

// MARK: - Sidebar Models

enum SidebarObjectType: String, Codable {
    case text = "Text"
    case linkList = "Link List"
}

@Model
final class SidebarObject {
    var blog: Blog?
    
    var title: String
    var type: String // SidebarObjectType.rawValue
    var order: Int
    var createdAt: Date
    
    // For text blocks
    var content: String?
    
    // For link lists
    @Relationship(deleteRule: .cascade, inverse: \LinkItem.sidebarObject)
    var links: [LinkItem] = []
    
    init(blog: Blog, title: String, type: SidebarObjectType, order: Int, createdAt: Date = Date()) {
        self.blog = blog
        self.title = title
        self.type = type.rawValue
        self.order = order
        self.createdAt = createdAt
    }
    
    var objectType: SidebarObjectType {
        return SidebarObjectType(rawValue: type) ?? .text
    }
    
    func generateHtml() -> String {
        switch objectType {
        case .text:
            if let content = content {
                let markdownParser = MarkdownParser()
                let contentHtml = markdownParser.html(from: content)
                
                return """
                <div class="sidebar-text">
                    <h2>\(title)</h2>
                    <div class="sidebar-text-content">
                        \(contentHtml)
                    </div>
                </div>
                """
            } else {
                return "<!-- Empty text block -->"
            }
            
        case .linkList:
            let sortedLinks = links.sorted { $0.order < $1.order }
            var linksHtml = ""
            
            for link in sortedLinks {
                linksHtml += "<li><a href=\"\(link.url)\">\(link.title)</a></li>\n"
            }
            
            return """
            <div class="sidebar-links">
                <h2>\(title)</h2>
                <ul>
                    \(linksHtml)
                </ul>
            </div>
            """
        }
    }
}

@Model
final class LinkItem {
    var sidebarObject: SidebarObject?
    
    var title: String
    var url: String
    var order: Int
    var createdAt: Date
    
    init(sidebarObject: SidebarObject, title: String, url: String, order: Int, createdAt: Date = Date()) {
        self.sidebarObject = sidebarObject
        self.title = title
        self.url = url
        self.order = order
        self.createdAt = createdAt
    }
}

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

@Model
final class Theme {
    var name: String
    var identifier: String
    var createdAt: Date
    var isCustomized: Bool
    
    @Relationship(deleteRule: .cascade, inverse: \ThemeFile.theme)
    var files: [ThemeFile] = []
    
    init(name: String, identifier: String, isCustomized: Bool = false, createdAt: Date = Date()) {
        self.name = name
        self.identifier = identifier
        self.isCustomized = isCustomized
        self.createdAt = createdAt
    }
}

@Model
final class ThemeFile {
    var theme: Theme?
    
    var name: String // Template type like "layout", "post", "css", etc.
    var content: String
    var createdAt: Date
    var lastModified: Date
    
    init(theme: Theme, name: String, content: String, createdAt: Date = Date()) {
        self.theme = theme
        self.name = name
        self.content = content
        self.createdAt = createdAt
        self.lastModified = createdAt
    }
}

@Model
final class EmbedImage {
    var embed: Embed?

    var order: Int // To maintain the order of images
    var filename: String // For referencing in the generated static site
    @Attribute(.externalStorage) var imageData: Data // The optimized image data
    var createdAt: Date

    init(embed: Embed, imageData: Data, order: Int, filename: String, createdAt: Date = Date()) {
        self.embed = embed
        self.imageData = imageData
        self.order = order
        self.filename = filename
        self.createdAt = createdAt
    }
}
