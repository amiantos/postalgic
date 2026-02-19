//
//  RemoteModels.swift
//  Postalgic
//
//  Created by Claude on 2/18/26.
//

import Foundation

// MARK: - Remote Blog

struct RemoteBlog: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let url: String
    let tagline: String?
    let authorName: String?
    let authorUrl: String?
    let authorEmail: String?
    let themeIdentifier: String?
    let accentColor: String?
    let backgroundColor: String?
    let textColor: String?
    let lightShade: String?
    let mediumShade: String?
    let darkShade: String?
    let timezone: String?
    let simpleAnalyticsEnabled: Bool?
    let simpleAnalyticsDomain: String?
    let createdAt: String?

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: RemoteBlog, rhs: RemoteBlog) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Remote Blog Stats

struct RemoteBlogStats: Codable {
    let totalPosts: Int
    let publishedPosts: Int
    let draftPosts: Int
    let totalCategories: Int
    let totalTags: Int
}

// MARK: - Remote Post

struct RemotePost: Codable, Identifiable, Hashable {
    let id: String
    let title: String?
    let content: String
    let contentHtml: String?
    let stub: String?
    let isDraft: Bool
    let createdAt: String
    let updatedAt: String?
    let categoryId: String?
    let tagIds: [String]?

    // Enriched properties from API
    let urlPath: String?
    let displayTitle: String?
    let excerpt: String?
    let formattedDate: String?
    let shortFormattedDate: String?
    let category: RemotePostCategory?
    let tags: [RemotePostTag]?

    // Embed
    let embed: RemoteEmbed?

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: RemotePost, rhs: RemotePost) -> Bool {
        lhs.id == rhs.id
    }
}

struct RemotePostCategory: Codable, Hashable {
    let id: String
    let name: String
    let stub: String?
}

struct RemotePostTag: Codable, Hashable {
    let id: String
    let name: String
    let stub: String?
}

// MARK: - Remote Embed

struct RemoteEmbed: Codable, Hashable {
    let type: String
    let url: String?
    let position: String?
    let title: String?
    let description: String?
    let imageUrl: String?
    let imageFilename: String?
    let videoId: String?
    let images: [RemoteEmbedImage]?
}

struct RemoteEmbedImage: Codable, Hashable {
    let filename: String
    let order: Int?
}

// MARK: - Remote Category

struct RemoteCategory: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let description: String?
    let stub: String?
    let postCount: Int?
    let urlPath: String?
    let createdAt: String?

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: RemoteCategory, rhs: RemoteCategory) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Remote Tag

struct RemoteTag: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let stub: String?
    let postCount: Int?
    let urlPath: String?
    let createdAt: String?

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: RemoteTag, rhs: RemoteTag) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Paginated Posts Response

struct RemotePostsResponse: Codable {
    let posts: [RemotePost]
    let total: Int
    let publishedCount: Int
    let draftCount: Int
    let page: Int
    let limit: Int
    let hasMore: Bool
}

// MARK: - Publish Status

struct RemotePublishStatus: Codable {
    let publisherType: String
    let lastPublishedDate: String?
    let syncVersion: String?
}
