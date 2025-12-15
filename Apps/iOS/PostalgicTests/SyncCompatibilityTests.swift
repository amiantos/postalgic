//
//  SyncCompatibilityTests.swift
//  PostalgicTests
//
//  Tests for sync data compatibility between iOS and Self-Hosted apps.
//

import Foundation
import Testing
import SwiftData

@testable import Postalgic

/// Tests to verify sync data generation matches expected structure
/// and is compatible with the Self-Hosted app.
struct SyncCompatibilityTests {

    // MARK: - Test Fixture Loading

    struct CanonicalBlog: Codable {
        let blog: BlogData
        let categories: [CategoryData]
        let tags: [TagData]
        let posts: [PostData]
        let drafts: [PostData]
        let sidebar: [SidebarData]
        let encryption: EncryptionData

        struct BlogData: Codable {
            let name: String
            let url: String
            let tagline: String?
            let authorName: String?
            let authorUrl: String?
            let authorEmail: String?
            let timezone: String
            let colors: ColorData
            let themeIdentifier: String?
        }

        struct ColorData: Codable {
            let accent: String?
            let background: String?
            let text: String?
            let lightShade: String?
            let mediumShade: String?
            let darkShade: String?
        }

        struct CategoryData: Codable {
            let testId: String
            let name: String
            let description: String?
            let stub: String
            let createdAt: String
        }

        struct TagData: Codable {
            let testId: String
            let name: String
            let stub: String
            let createdAt: String
        }

        struct PostData: Codable {
            let testId: String
            let title: String?
            let content: String
            let stub: String
            let isDraft: Bool
            let categoryTestId: String?
            let tagTestIds: [String]
            let embed: EmbedData?
            let createdAt: String
        }

        struct EmbedData: Codable {
            let type: String
            let position: String
            let url: String
            let title: String?
            let description: String?
            let imageUrl: String?
            let imageFilename: String?
            let images: [ImageData]
        }

        struct ImageData: Codable {
            let filename: String
            let order: Int
        }

        struct SidebarData: Codable {
            let testId: String
            let type: String
            let title: String
            let content: String?
            let order: Int
            let links: [LinkData]?
        }

        struct LinkData: Codable {
            let title: String
            let url: String
            let order: Int
        }

        struct EncryptionData: Codable {
            let testPassword: String
            let expectedSalt: String
            let expectedIterations: Int
        }
    }

    /// Load canonical blog fixture from test-fixtures directory
    static func loadCanonicalBlog() throws -> CanonicalBlog {
        // Find the test-fixtures directory relative to the project
        let bundle = Bundle(for: BundleLocator.self)
        guard let fixturesURL = bundle.url(forResource: "canonical-blog", withExtension: "json", subdirectory: "test-fixtures/sync-compatibility") else {
            // Try loading from project root
            let projectRoot = URL(fileURLWithPath: #file)
                .deletingLastPathComponent()  // PostalgicTests
                .deletingLastPathComponent()  // iOS
                .deletingLastPathComponent()  // Apps
                .deletingLastPathComponent()  // postalgic
            let fixturesPath = projectRoot.appendingPathComponent("test-fixtures/sync-compatibility/canonical-blog.json")

            let data = try Data(contentsOf: fixturesPath)
            return try JSONDecoder().decode(CanonicalBlog.self, from: data)
        }

        let data = try Data(contentsOf: fixturesURL)
        return try JSONDecoder().decode(CanonicalBlog.self, from: data)
    }

    // MARK: - Helper to create test blog

    func createTestBlogFromFixture(_ fixture: CanonicalBlog) -> Blog {
        let blog = Blog(name: fixture.blog.name, url: fixture.blog.url)
        blog.tagline = fixture.blog.tagline
        blog.authorName = fixture.blog.authorName
        blog.authorUrl = fixture.blog.authorUrl
        blog.authorEmail = fixture.blog.authorEmail
        blog.accentColor = fixture.blog.colors.accent
        blog.backgroundColor = fixture.blog.colors.background
        blog.textColor = fixture.blog.colors.text
        blog.lightShade = fixture.blog.colors.lightShade
        blog.mediumShade = fixture.blog.colors.mediumShade
        blog.darkShade = fixture.blog.colors.darkShade
        blog.themeIdentifier = fixture.blog.themeIdentifier

        // Create a map of testId to real model objects
        var categoryMap: [String: Category] = [:]
        var tagMap: [String: Tag] = [:]

        // Create categories
        for catData in fixture.categories {
            let category = Category(blog: blog, name: catData.name, stub: catData.stub)
            category.categoryDescription = catData.description
            blog.categories.append(category)
            categoryMap[catData.testId] = category
        }

        // Create tags
        for tagData in fixture.tags {
            let tag = Tag(blog: blog, name: tagData.name, stub: tagData.stub)
            blog.tags.append(tag)
            tagMap[tagData.testId] = tag
        }

        // Create posts
        for postData in fixture.posts {
            let post = Post(
                title: postData.title,
                content: postData.content,
                createdAt: ISO8601DateFormatter().date(from: postData.createdAt) ?? Date()
            )
            post.stub = postData.stub
            post.isDraft = postData.isDraft
            post.blog = blog

            // Set category
            if let catId = postData.categoryTestId, let category = categoryMap[catId] {
                post.category = category
            }

            // Set tags
            for tagId in postData.tagTestIds {
                if let tag = tagMap[tagId] {
                    post.tags.append(tag)
                }
            }

            blog.posts.append(post)
        }

        // Create drafts
        for draftData in fixture.drafts {
            let draft = Post(
                title: draftData.title,
                content: draftData.content,
                createdAt: ISO8601DateFormatter().date(from: draftData.createdAt) ?? Date()
            )
            draft.stub = draftData.stub
            draft.isDraft = true
            draft.blog = blog

            if let catId = draftData.categoryTestId, let category = categoryMap[catId] {
                draft.category = category
            }

            blog.posts.append(draft)
        }

        // Create sidebar objects
        for sidebarData in fixture.sidebar {
            let objType: SidebarObjectType = sidebarData.type == "text" ? .text : .linkList
            let sidebarObj = SidebarObject(
                blog: blog,
                type: objType,
                title: sidebarData.title,
                order: sidebarData.order
            )
            sidebarObj.content = sidebarData.content

            if let links = sidebarData.links {
                for linkData in links {
                    let link = SidebarLink(
                        sidebarObject: sidebarObj,
                        title: linkData.title,
                        url: linkData.url,
                        order: linkData.order
                    )
                    sidebarObj.links.append(link)
                }
            }

            blog.sidebarObjects.append(sidebarObj)
        }

        return blog
    }

    // MARK: - Tests

    @Test func testSyncDataGeneratorCreatesManifest() async throws {
        let fixture = try Self.loadCanonicalBlog()
        let blog = createTestBlogFromFixture(fixture)

        // Enable sync
        blog.syncEnabled = true
        blog.setSyncPassword(fixture.encryption.testPassword)

        // Generate sync directory
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("sync-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        _ = try SyncDataGenerator.generateSyncDirectory(
            for: blog,
            in: tempDir,
            password: fixture.encryption.testPassword
        ) { _ in }

        // Verify manifest exists
        let manifestPath = tempDir.appendingPathComponent("sync/manifest.json")
        #expect(FileManager.default.fileExists(atPath: manifestPath.path))

        // Verify manifest has required fields
        let manifestData = try Data(contentsOf: manifestPath)
        let manifest = try JSONSerialization.jsonObject(with: manifestData) as? [String: Any]

        #expect(manifest?["version"] != nil)
        #expect(manifest?["syncVersion"] != nil)
        #expect(manifest?["lastModified"] != nil)
        #expect(manifest?["appSource"] != nil)
        #expect(manifest?["blogName"] != nil)
        #expect(manifest?["hasDrafts"] != nil)
        #expect(manifest?["files"] != nil)
    }

    @Test func testSyncDataGeneratorCreatesBlogJson() async throws {
        let fixture = try Self.loadCanonicalBlog()
        let blog = createTestBlogFromFixture(fixture)

        blog.syncEnabled = true
        blog.setSyncPassword(fixture.encryption.testPassword)

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("sync-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        _ = try SyncDataGenerator.generateSyncDirectory(
            for: blog,
            in: tempDir,
            password: fixture.encryption.testPassword
        ) { _ in }

        // Verify blog.json exists and has correct values
        let blogPath = tempDir.appendingPathComponent("sync/blog.json")
        #expect(FileManager.default.fileExists(atPath: blogPath.path))

        let blogData = try Data(contentsOf: blogPath)
        let blogJson = try JSONSerialization.jsonObject(with: blogData) as? [String: Any]

        #expect(blogJson?["name"] as? String == fixture.blog.name)
        #expect(blogJson?["url"] as? String == fixture.blog.url)
        #expect(blogJson?["colors"] != nil)
    }

    @Test func testSyncDataGeneratorCreatesCategories() async throws {
        let fixture = try Self.loadCanonicalBlog()
        let blog = createTestBlogFromFixture(fixture)

        blog.syncEnabled = true
        blog.setSyncPassword(fixture.encryption.testPassword)

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("sync-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        _ = try SyncDataGenerator.generateSyncDirectory(
            for: blog,
            in: tempDir,
            password: fixture.encryption.testPassword
        ) { _ in }

        // Verify categories index exists
        let indexPath = tempDir.appendingPathComponent("sync/categories/index.json")
        #expect(FileManager.default.fileExists(atPath: indexPath.path))

        let indexData = try Data(contentsOf: indexPath)
        let index = try JSONSerialization.jsonObject(with: indexData) as? [String: Any]
        let categories = index?["categories"] as? [[String: Any]]

        #expect(categories?.count == fixture.categories.count)
    }

    @Test func testSyncDataGeneratorCreatesTags() async throws {
        let fixture = try Self.loadCanonicalBlog()
        let blog = createTestBlogFromFixture(fixture)

        blog.syncEnabled = true
        blog.setSyncPassword(fixture.encryption.testPassword)

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("sync-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        _ = try SyncDataGenerator.generateSyncDirectory(
            for: blog,
            in: tempDir,
            password: fixture.encryption.testPassword
        ) { _ in }

        // Verify tags index exists
        let indexPath = tempDir.appendingPathComponent("sync/tags/index.json")
        #expect(FileManager.default.fileExists(atPath: indexPath.path))

        let indexData = try Data(contentsOf: indexPath)
        let index = try JSONSerialization.jsonObject(with: indexData) as? [String: Any]
        let tags = index?["tags"] as? [[String: Any]]

        #expect(tags?.count == fixture.tags.count)
    }

    @Test func testSyncDataGeneratorCreatesPosts() async throws {
        let fixture = try Self.loadCanonicalBlog()
        let blog = createTestBlogFromFixture(fixture)

        blog.syncEnabled = true
        blog.setSyncPassword(fixture.encryption.testPassword)

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("sync-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        _ = try SyncDataGenerator.generateSyncDirectory(
            for: blog,
            in: tempDir,
            password: fixture.encryption.testPassword
        ) { _ in }

        // Verify posts index exists
        let indexPath = tempDir.appendingPathComponent("sync/posts/index.json")
        #expect(FileManager.default.fileExists(atPath: indexPath.path))

        let indexData = try Data(contentsOf: indexPath)
        let index = try JSONSerialization.jsonObject(with: indexData) as? [String: Any]
        let posts = index?["posts"] as? [[String: Any]]

        #expect(posts?.count == fixture.posts.count)
    }

    @Test func testSyncDataGeneratorCreatesEncryptedDrafts() async throws {
        let fixture = try Self.loadCanonicalBlog()
        let blog = createTestBlogFromFixture(fixture)

        blog.syncEnabled = true
        blog.setSyncPassword(fixture.encryption.testPassword)

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("sync-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        _ = try SyncDataGenerator.generateSyncDirectory(
            for: blog,
            in: tempDir,
            password: fixture.encryption.testPassword
        ) { _ in }

        // Verify encrypted drafts index exists
        let indexPath = tempDir.appendingPathComponent("sync/drafts/index.json.enc")
        #expect(FileManager.default.fileExists(atPath: indexPath.path))

        // Verify manifest indicates encryption
        let manifestPath = tempDir.appendingPathComponent("sync/manifest.json")
        let manifestData = try Data(contentsOf: manifestPath)
        let manifest = try JSONSerialization.jsonObject(with: manifestData) as? [String: Any]

        #expect(manifest?["hasDrafts"] as? Bool == true)
        let encryption = manifest?["encryption"] as? [String: Any]
        #expect(encryption?["method"] as? String == "aes-256-gcm")
        #expect(encryption?["iterations"] as? Int == 100000)
    }

    @Test func testSyncDataUsesISO8601DateFormat() async throws {
        let fixture = try Self.loadCanonicalBlog()
        let blog = createTestBlogFromFixture(fixture)

        blog.syncEnabled = true
        blog.setSyncPassword(fixture.encryption.testPassword)

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("sync-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        _ = try SyncDataGenerator.generateSyncDirectory(
            for: blog,
            in: tempDir,
            password: fixture.encryption.testPassword
        ) { _ in }

        // Check manifest lastModified
        let manifestPath = tempDir.appendingPathComponent("sync/manifest.json")
        let manifestData = try Data(contentsOf: manifestPath)
        let manifest = try JSONSerialization.jsonObject(with: manifestData) as? [String: Any]
        let lastModified = manifest?["lastModified"] as? String ?? ""

        // ISO8601 format: 2025-01-15T10:00:00.000Z
        let iso8601Regex = try! Regex(#"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{3})?Z$"#)
        #expect(lastModified.contains(iso8601Regex))
    }

    @Test func testSyncDataHasValidSHA256Hashes() async throws {
        let fixture = try Self.loadCanonicalBlog()
        let blog = createTestBlogFromFixture(fixture)

        blog.syncEnabled = true
        blog.setSyncPassword(fixture.encryption.testPassword)

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("sync-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        _ = try SyncDataGenerator.generateSyncDirectory(
            for: blog,
            in: tempDir,
            password: fixture.encryption.testPassword
        ) { _ in }

        // Check manifest file hashes
        let manifestPath = tempDir.appendingPathComponent("sync/manifest.json")
        let manifestData = try Data(contentsOf: manifestPath)
        let manifest = try JSONSerialization.jsonObject(with: manifestData) as? [String: Any]
        let files = manifest?["files"] as? [String: [String: Any]] ?? [:]

        // SHA-256 produces 64 hex characters
        let sha256Regex = try! Regex(#"^[a-f0-9]{64}$"#)

        for (_, fileInfo) in files {
            let hash = fileInfo["hash"] as? String ?? ""
            #expect(hash.contains(sha256Regex), "Hash should be valid SHA-256: \(hash)")
        }
    }
}

/// Helper class to locate the bundle
private class BundleLocator {}
