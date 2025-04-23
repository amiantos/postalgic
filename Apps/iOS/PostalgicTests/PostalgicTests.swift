//
//  PostalgicTests.swift
//  PostalgicTests
//
//  Created by Brad Root on 4/19/25.
//

import Foundation
import Testing
import ZIPFoundation

@testable import Postalgic

struct PostalgicTests {

    // Helper to create a test blog with posts
    func createTestBlog() -> Blog {
        let blog = Blog(name: "Test Blog", url: "https://example.com")

        let post1 = Post(
            title: "First Post",
            content:
                "This is the first post with some **bold** and *italic* text.",
            createdAt: Date().addingTimeInterval(-86400)  // Yesterday
        )

        let post2 = Post(
            title: nil,  // Test untitled post
            content:
                "This is a post without a title, which should use content as the title.",
            createdAt: Date()
        )

        blog.posts = [post1, post2]
        return blog
    }

    @Test func testStaticSiteGenerator() async throws {
        // Create a test blog with posts
        let blog = createTestBlog()

        // Generate the site
        let generator = StaticSiteGenerator(blog: blog)
        let zipURL = try await generator.generateSite()

        // Verify the zip file exists
        #expect(FileManager.default.fileExists(atPath: zipURL.path))

        // Extract the zip to a temporary location to verify contents
        let extractDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("extract-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: extractDir,
            withIntermediateDirectories: true
        )

        try FileManager.default.unzipItem(at: zipURL, to: extractDir)

        // Get the site directory name (the first subdirectory in the extracted folder)
        let extractedContents = try FileManager.default.contentsOfDirectory(
            at: extractDir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: .skipsHiddenFiles
        )

        let siteDirectories = extractedContents.filter {
            (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory)
                == true
        }

        #expect(
            !siteDirectories.isEmpty,
            "Should have at least one site directory"
        )
        let siteDir = siteDirectories.first!

        // Verify basic structure
        #expect(
            FileManager.default.fileExists(
                atPath: siteDir.appendingPathComponent("index.html").path
            )
        )
        #expect(
            FileManager.default.fileExists(
                atPath: siteDir.appendingPathComponent("archives.html").path
            )
        )
        #expect(
            FileManager.default.fileExists(
                atPath: siteDir.appendingPathComponent("css/style.css").path
            )
        )

        // Verify post directories exist
        for post in blog.posts {
            let postPath = siteDir.appendingPathComponent(post.urlPath)
                .appendingPathComponent("index.html").path
            #expect(FileManager.default.fileExists(atPath: postPath))
        }

        // Clean up
        try? FileManager.default.removeItem(at: extractDir)
        try? FileManager.default.removeItem(at: zipURL)
    }

    @Test func testMarkdownInPostContent() async throws {
        // Create a blog with a post that contains markdown
        let blog = Blog(name: "Markdown Test Blog", url: "https://example.com")

        // Create a post with various markdown elements
        let markdownContent = """
            This is a test post with **bold text**, *italic text*, and a [link](https://example.com).

            This is a new paragraph.
            """

        let post = Post(
            title: "Markdown Test",
            content: markdownContent,
            createdAt: Date()
        )

        blog.posts = [post]

        // Generate the site
        let generator = StaticSiteGenerator(blog: blog)
        let zipURL = try await generator.generateSite()

        // Extract the zip and find the post's HTML
        let extractDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("md-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: extractDir,
            withIntermediateDirectories: true
        )

        try FileManager.default.unzipItem(at: zipURL, to: extractDir)

        // Find the site directory
        let extractedContents = try FileManager.default.contentsOfDirectory(
            at: extractDir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: .skipsHiddenFiles
        )

        let siteDirectories = extractedContents.filter {
            (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory)
                == true
        }

        #expect(!siteDirectories.isEmpty, "Should have a site directory")
        let siteDir = siteDirectories.first!

        // Get the post's HTML file
        let postPath = siteDir.appendingPathComponent(post.urlPath)
            .appendingPathComponent("index.html")

        // Read the HTML content
        let postHtml = try String(contentsOf: postPath)

        // Check for formatted markdown elements
        #expect(
            postHtml.contains("<strong>bold text</strong>"),
            "HTML should contain formatted bold text"
        )
        #expect(
            postHtml.contains("<em>italic text</em>"),
            "HTML should contain formatted italic text"
        )
        #expect(
            postHtml.contains("<a href=\"https://example.com\">link</a>"),
            "HTML should contain formatted link"
        )
        #expect(
            postHtml.contains("<br>This is a new paragraph."),
            "HTML should format paragraphs with line breaks"
        )

        // Clean up
        try? FileManager.default.removeItem(at: extractDir)
        try? FileManager.default.removeItem(at: zipURL)
    }

}
