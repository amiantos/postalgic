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

    init(name: String, url: String, createdAt: Date = Date()) {
        self.name = name
        self.url = url
        self.createdAt = createdAt
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

@Model
final class Post {
    var title: String?
    var content: String
    var primaryLink: String?
    var createdAt: Date

    var isDraft: Bool = false

    var blog: Blog?

    @Relationship(deleteRule: .nullify, inverse: \Category.posts)
    var category: Category?

    @Relationship(deleteRule: .nullify, inverse: \Tag.posts)
    var tags: [Tag] = []

    init(
        title: String? = nil,
        content: String,
        primaryLink: String? = nil,
        createdAt: Date = Date(),
        isDraft: Bool = false
    ) {
        self.title = title
        self.content = content
        self.primaryLink = primaryLink
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
