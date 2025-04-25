//
//  Models.swift
//  Postalgic
//
//  Created by Brad Root on 4/19/25.
//

import Foundation
import SwiftData

@Model
final class Blog {
    var name: String
    var url: String
    var createdAt: Date
    
    // Blog metadata
    var authorName: String?
    var authorUrl: String?
    var tagline: String?

    // AWS Configuration
    var awsRegion: String?
    var awsS3Bucket: String?
    var awsCloudFrontDistId: String?
    var awsAccessKeyId: String?
    var awsSecretAccessKey: String?

    @Relationship(deleteRule: .cascade, inverse: \Post.blog)
    var posts: [Post] = []

    @Relationship(deleteRule: .cascade, inverse: \Category.blog)
    var categories: [Category] = []

    @Relationship(deleteRule: .cascade, inverse: \Tag.blog)
    var tags: [Tag] = []

    init(name: String, url: String, createdAt: Date = Date(), authorName: String? = nil, authorUrl: String? = nil, tagline: String? = nil) {
        self.name = name
        self.url = url
        self.createdAt = createdAt
        self.authorName = authorName
        self.authorUrl = authorUrl
        self.tagline = tagline
    }

    var hasAwsConfigured: Bool {
        return awsRegion != nil && !awsRegion!.isEmpty && awsS3Bucket != nil
            && !awsS3Bucket!.isEmpty && awsCloudFrontDistId != nil
            && !awsCloudFrontDistId!.isEmpty && awsAccessKeyId != nil
            && !awsAccessKeyId!.isEmpty && awsSecretAccessKey != nil
            && !awsSecretAccessKey!.isEmpty
    }
}

@Model
final class Category {
    var name: String
    var categoryDescription: String?
    var createdAt: Date

    var blog: Blog?
    var posts: [Post] = []

    init(
        name: String,
        categoryDescription: String? = nil,
        createdAt: Date = Date()
    ) {
        self.name = name.capitalized
        self.categoryDescription = categoryDescription
        self.createdAt = createdAt
    }
}

@Model
final class Tag {
    var name: String
    var createdAt: Date

    var blog: Blog?
    var posts: [Post] = []

    init(name: String, createdAt: Date = Date()) {
        self.name = name.lowercased()
        self.createdAt = createdAt
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

    var isDraft: Bool = false

    var blog: Blog?

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
        isDraft: Bool = false
    ) {
        self.title = title
        self.content = content
        self.createdAt = createdAt
        self.isDraft = isDraft
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }

    var urlPath: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd/HHmmss"
        return formatter.string(from: createdAt)
    }

    var displayTitle: String {
        return title ?? String(content.prefix(50))
    }

    var tagNames: [String] {
        return tags.map { $0.name }
    }

    var formattedTags: String {
        return tagNames.joined(separator: ", ")
    }
}
