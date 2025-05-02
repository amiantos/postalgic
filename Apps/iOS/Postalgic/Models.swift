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
final class BlogTemplate {
    var type: String      // template type (e.g., "layout", "post", "index")
    var content: String   // template content
    var updatedAt: Date   // date when template was last updated
    
    var blog: Blog?       // the blog this template belongs to
    
    init(type: String, content: String, updatedAt: Date = Date()) {
        self.type = type
        self.content = content
        self.updatedAt = updatedAt
    }
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
    
    @Relationship(deleteRule: .cascade, inverse: \BlogTemplate.blog)
    var templates: [BlogTemplate] = []
    
    @Relationship(deleteRule: .cascade, inverse: \PublishedFiles.blog)
    var publishedFiles: [PublishedFiles] = []
    
    @Relationship(deleteRule: .cascade, inverse: \SidebarObject.blog)
    var sidebarObjects: [SidebarObject] = []

    init(name: String, url: String, createdAt: Date = Date(), authorName: String? = nil, authorEmail: String? = nil, authorUrl: String? = nil, tagline: String? = nil) {
        self.name = name
        self.url = url
        self.createdAt = createdAt
        self.authorName = authorName
        self.authorEmail = authorEmail
        self.authorUrl = authorUrl
        self.tagline = tagline
        self.publisherType = PublisherType.none.rawValue
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
    
    // MARK: - Template Management
    
    /// Get a template of a specific type if it exists
    /// - Parameter type: The type of template to retrieve
    /// - Returns: The template if it exists, nil otherwise
    func template(for type: String) -> BlogTemplate? {
        return templates.first { $0.type == type }
    }
    
    /// Save a template of a specific type
    /// - Parameters:
    ///   - content: The template content
    ///   - type: The template type
    /// - Returns: The created or updated template
    @discardableResult
    func saveTemplate(_ content: String, for type: String) -> BlogTemplate {
        // Check if template already exists
        if let existingTemplate = template(for: type) {
            existingTemplate.content = content
            existingTemplate.updatedAt = Date()
            return existingTemplate
        } else {
            // Create new template
            let newTemplate = BlogTemplate(type: type, content: content)
            newTemplate.blog = self
            templates.append(newTemplate)
            return newTemplate
        }
    }
    
    /// Delete a template of a specific type
    /// - Parameter type: The template type to delete
    func deleteTemplate(for type: String) {
        templates.removeAll { $0.type == type }
    }
}

@Model
final class Category {
    var name: String
    var categoryDescription: String?
    var createdAt: Date
    var stub: String?

    var blog: Blog? {
        didSet {
            // Ensure stub uniqueness when a category is assigned to a blog
            if let blog = blog, let stub = stub {
                self.stub = blog.uniqueCategoryStub(stub)
            }
        }
    }
    var posts: [Post] = []

    init(
        name: String,
        categoryDescription: String? = nil,
        createdAt: Date = Date(),
        stub: String? = nil
    ) {
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

    var blog: Blog? {
        didSet {
            // Ensure stub uniqueness when a tag is assigned to a blog
            if let blog = blog, let stub = stub {
                self.stub = blog.uniqueTagStub(stub)
            }
        }
    }
    var posts: [Post] = []

    init(name: String, createdAt: Date = Date(), stub: String? = nil) {
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
}

enum EmbedPosition: String, Codable {
    case above = "Above"
    case below = "Below"
}

@Model
final class Embed {
    var url: String
    var type: String // EmbedType.rawValue
    var position: String // EmbedPosition.rawValue
    var createdAt: Date
    
    // These properties are for Link type embeds
    var title: String?
    var embedDescription: String?
    var imageUrl: String? // Remote URL for the image
    var imageData: Data? // Actual image data stored in the database
    
    var post: Post?
    
    init(
        url: String,
        type: EmbedType,
        position: EmbedPosition,
        title: String? = nil,
        embedDescription: String? = nil,
        imageUrl: String? = nil,
        imageData: Data? = nil,
        createdAt: Date = Date()
    ) {
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
        }
    }
}

@Model
final class Post {
    var title: String?
    var content: String
    var createdAt: Date
    var stub: String?

    var isDraft: Bool = false

    var blog: Blog? {
        didSet {
            // Ensure stub uniqueness when a post is assigned to a blog
            if let blog = blog, let stub = stub {
                self.stub = blog.uniquePostStub(stub)
            }
        }
    }

    @Relationship(deleteRule: .nullify, inverse: \Category.posts)
    var category: Category?

    @Relationship(deleteRule: .nullify, inverse: \Tag.posts)
    var tags: [Tag] = []
    
    @Relationship(deleteRule: .cascade)
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
        self.stub = stub
        
        // Generate stub if not provided
        if self.stub == nil {
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
    
    /// Returns the full URL path including stub if available
    var urlPath: String {
        let basePath = dateUrlPath
        if let stub = stub, !stub.isEmpty {
            return "\(basePath)/\(stub)"
        }
        return basePath
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
        
        let maxLength = 75
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
    var title: String
    var type: String // SidebarObjectType.rawValue
    var order: Int
    var createdAt: Date
    
    // For text blocks
    var content: String?
    
    // For link lists
    @Relationship(deleteRule: .cascade)
    var links: [LinkItem] = []
    
    var blog: Blog?
    
    init(title: String, type: SidebarObjectType, order: Int, createdAt: Date = Date()) {
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
    var title: String
    var url: String
    var order: Int
    var createdAt: Date
    
    var sidebarObject: SidebarObject?
    
    init(title: String, url: String, order: Int, createdAt: Date = Date()) {
        self.title = title
        self.url = url
        self.order = order
        self.createdAt = createdAt
    }
}
