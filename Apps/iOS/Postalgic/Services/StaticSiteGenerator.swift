//
//  StaticSiteGenerator.swift
//  Postalgic
//
//  Created by Brad Root on 4/19/25.
//

import Foundation
import Ink
import ZIPFoundation

extension String {
    /// Formats a string for use in a URL path, replacing spaces with hyphens and ensuring URL safety
    func urlPathFormatted() -> String {
        return self.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
            ?? self.lowercased()
    }
}

/// StaticSiteGenerator handles the generation of a static site from a Blog model
class StaticSiteGenerator {
    private let blog: Blog
    private var siteDirectory: URL?

    // MARK: - Templates and CSS

    private var cssFile: String = """
        /* Base styles */
        
        /* Add styles for tagline and author info */
        header .tagline {
            color: var(--medium-gray);
            font-size: 1.1rem;
            margin-bottom: 15px;
            font-style: italic;
        }
        
        .post-author {
            color: var(--medium-gray);
            font-size: 0.9rem;
            margin-top: 5px;
        }
        
        :root {
            --primary-color: #4a5568;
            --accent-color: #3182ce;
            --background-color: #ffffff;
            --text-color: #2d3748;
            --light-gray: #edf2f7;
            --medium-gray: #a0aec0;
            --dark-gray: #4a5568;
            --tag-bg: #ebf8ff;
            --tag-color: #2b6cb0;
            --category-bg: #f0fff4;
            --category-color: #2f855a;
        }

        * {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }

        body {
            font-family: system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            line-height: 1.6;
            color: var(--text-color);
            background-color: var(--background-color);
        }

        a {
            color: var(--accent-color);
            text-decoration: none;
        }

        a:hover {
            text-decoration: underline;
        }

        /* Container */
        .container {
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
        }

        @media (min-width: 769px) {
            body {
                background-color: #f7fafc;
            }
            
            .container {
                margin-top: 30px;
                margin-bottom: 30px;
                background-color: var(--background-color);
                border-radius: 8px;
                box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1), 0 1px 3px rgba(0, 0, 0, 0.08);
            }
        }

        /* Header */
        header {
            margin-bottom: 30px;
            border-bottom: 1px solid var(--light-gray);
            padding-bottom: 20px;
        }

        header h1 {
            margin-bottom: 15px;
        }

        header h1 a {
            color: var(--primary-color);
            text-decoration: none;
        }

        nav ul {
            display: flex;
            list-style: none;
            gap: 20px;
        }

        nav a {
            font-weight: 500;
        }

        /* Main */
        main {
            margin-bottom: 30px;
        }

        /* Posts */
        .post-list {
            display: flex;
            flex-direction: column;
            gap: 30px;
        }

        .post-item {
            border-bottom: 1px solid var(--light-gray);
            padding-bottom: 20px;
        }

        .post-item h2 {
            margin-bottom: 5px;
        }

        .post-date {
            color: var(--medium-gray);
            font-size: 0.9rem;
            margin-bottom: 10px;
        }

        .post-date a {
            color: var(--medium-gray);
            text-decoration: none;
            border-bottom: 1px dotted var(--medium-gray);
        }

        .post-date a:hover {
            color: var(--accent-color);
            border-bottom-color: var(--accent-color);
        }

        .post-tags, .post-category {
            margin: 10px 0;
            font-size: 0.9rem;
        }

        .post-summary {
            margin-top: 10px;
        }
        
        .post-summary p, .post-content p {
            margin-top:1.2em;
            margin-bottom:1.2em;
        }

        /* Tags */
        .tag {
            display: inline-block;
            background-color: var(--tag-bg);
            color: var(--tag-color);
            padding: 3px 8px;
            border-radius: 4px;
            font-size: 0.8rem;
            margin-right: 5px;
        }

        .tag:hover {
            background-color: var(--tag-color);
            color: white;
            text-decoration: none;
        }

        .tag-list, .category-list {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(250px, 1fr));
            gap: 20px;
            margin-top: 20px;
        }

        .tag-item, .category-item {
            background-color: var(--light-gray);
            padding: 15px;
            border-radius: 4px;
        }

        .tag-count, .category-count {
            font-size: 0.8rem;
            color: var(--medium-gray);
            font-weight: normal;
        }

        .tag-meta, .category-meta {
            color: var(--medium-gray);
            font-style: italic;
            margin-bottom: 20px;
        }

        /* Categories */
        .post-category a {
            color: var(--category-color);
            background-color: var(--category-bg);
            padding: 3px 8px;
            border-radius: 4px;
        }

        .post-category a:hover {
            background-color: var(--category-color);
            color: white;
            text-decoration: none;
        }

        .category-description {
            margin-top: 10px;
            font-size: 0.9rem;
        }

        /* Article */
        article {
            margin-bottom: 40px;
        }

        article h1 {
            margin-bottom: 15px;
        }

        .post-meta {
            margin-bottom: 20px;
        }

        .post-content {
            line-height: 1.8;
        }

        .post-content p, .post-content ul, .post-content ol {
            margin-bottom: 1.2em;
        }

        /* Archives */
        .archive-year {
            font-size: 1.5rem;
            font-weight: bold;
            margin: 30px 0 10px;
            color: var(--dark-gray);
        }

        .archive-month {
            font-size: 1.2rem;
            margin: 20px 0 10px;
            color: var(--dark-gray);
        }

        .archive-date {
            color: var(--medium-gray);
            display: inline-block;
            width: 100px;
        }

        /* Footer */
        footer {
            border-top: 1px solid var(--light-gray);
            padding-top: 20px;
            color: var(--medium-gray);
            font-size: 0.9rem;
        }

        /* Embeds */
        .embed {
            margin: 1.5em 0;
            border-radius: 8px;
            overflow: hidden;
        }
        
        .youtube-embed {
            position: relative;
            padding-bottom: 56.25%; /* 16:9 ratio */
            height: 0;
            overflow: hidden;
        }
        
        .youtube-embed iframe {
            position: absolute;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            border: 0;
        }
        
        .link-embed {
            border: 1px solid var(--light-gray);
            border-radius: 8px;
            overflow: hidden;
        }
        
        .link-embed a {
            display: grid;
            grid-template-areas: 
                "image title"
                "image description"
                "image url";
            grid-template-columns: 150px 1fr;
            grid-template-rows: auto 1fr auto;
            padding: 0;
            color: var(--text-color);
            text-decoration: none;
        }
        
        .link-embed a:hover {
            background-color: var(--light-gray);
            text-decoration: none;
        }
        
        .link-title {
            grid-area: title;
            font-weight: bold;
            padding: 10px 10px 5px 10px;
        }
        
        .link-description {
            grid-area: description;
            font-size: 0.9em;
            padding: 0 10px;
            color: var(--dark-gray);
        }
        
        .link-url {
            grid-area: url;
            font-size: 0.8em;
            color: var(--medium-gray);
            padding: 5px 10px 10px 10px;
            white-space: nowrap;
            overflow: hidden;
            text-overflow: ellipsis;
        }
        
        .link-image {
            grid-area: image;
            height: 100%;
        }
        
        .link-image img {
            width: 100%;
            height: 100%;
            object-fit: cover;
        }
        
        blockquote {
            color: #666;
            font-style: italic;
            border-left: 2px solid black;
            padding-left: 1.3em;
        }
        
        /* Responsive */
        @media (max-width: 768px) {
            .container {
                padding: 15px;
            }
            
            nav ul {
                flex-direction: column;
                gap: 10px;
            }
            
            .tag-list, .category-list {
                grid-template-columns: 1fr;
            }
            
            .link-embed a {
                grid-template-areas: 
                    "image"
                    "title"
                    "description"
                    "url";
                grid-template-columns: 1fr;
                grid-template-rows: auto auto auto auto;
            }
            
            .link-image {
                height: 200px;
            }
        }
        """

    /// Initializes a StaticSiteGenerator with a Blog model
    /// - Parameter blog: The Blog to generate a site for
    init(blog: Blog) {
        self.blog = blog
    }

    // MARK: - HTML Template Components

    /// Returns the HTML header for a page
    private func htmlHeader(pageTitle: String, customHead: String = "")
        -> String
    {
        return """
            <!DOCTYPE html>
            <html lang="en">
            <head>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <title>\(pageTitle)</title>
                <meta name="description" content="Posts from \(blog.name)">
                <link rel="stylesheet" href="/css/style.css">
                <link rel="alternate" type="application/rss+xml" title="\(blog.name) RSS Feed" href="/rss.xml">
                \(customHead)
            </head>
            <body>
                <div class="container">
                    <header>
                        <h1><a href="/">\(blog.name)</a></h1>
                        \(blog.tagline != nil ? "<p class=\"tagline\">\(blog.tagline!)</p>" : "")
                        <nav>
                            <ul>
                                <li><a href="/">Home</a></li>
                                <li><a href="/archives/">Archives</a></li>
                                <li><a href="/tags/">Tags</a></li>
                                <li><a href="/categories/">Categories</a></li>
                            </ul>
                        </nav>
                    </header>
                    
                    <main>
            """
    }

    /// Returns the HTML footer for a page
    private func htmlFooter() -> String {
        var authorText = ""
        if let authorName = blog.authorName {
            if let authorUrl = blog.authorUrl, !authorUrl.isEmpty {
                authorText = " by <a href=\"\(authorUrl)\">\(authorName)</a>"
            } else {
                authorText = " by \(authorName)"
            }
        }
        
        return """
                    </main>
                    
                    <footer>
                        <p>&copy; \(Calendar.current.component(.year, from: Date())) \(blog.name)\(authorText). Generated with <a href="https://postalgic.app">Postalgic</a>.</p>
                    </footer>
                </div>
            </body>
            </html>
            """
    }

    /// Wraps content in a complete HTML page
    private func completePage(
        title: String,
        content: String,
        customHead: String = ""
    ) -> String {
        return htmlHeader(pageTitle: title, customHead: customHead) + content
            + htmlFooter()
    }

    // MARK: - Post Rendering Helpers

    /// Renders HTML for post tags
    private func renderPostTags(_ post: Post) -> String {
        guard !post.tags.isEmpty else { return "" }

        var tagsHTML = """
            <div class="post-tags">
                Tags: 
            """

        for tag in post.tags {
            tagsHTML += """
                <a href="/tags/\(tag.name.urlPathFormatted())/" class="tag">\(tag.name)</a> 
                """
        }

        tagsHTML += "</div>"
        return tagsHTML
    }

    /// Renders HTML for post category
    private func renderPostCategory(_ post: Post) -> String {
        guard let category = post.category else { return "" }

        return """
            <div class="post-category">
                Category: <a href="/categories/\(category.name.urlPathFormatted())/">\(category.name)</a>
            </div>
            """
    }

    /// Renders a post item for list views
    private func renderPostListItem(_ post: Post) -> String {
        let tagsHTML = renderPostTags(post)
        let categoryHTML = renderPostCategory(post)
        let hasTitle = post.title?.isEmpty == false

        // Title HTML with conditional rendering
        let titleHTML =
            hasTitle
            ? """
                <h2><a href="/\(post.urlPath)/index.html">\(post.displayTitle)</a></h2>
            """ : ""

        // Date now links to the post
        var dateHTML = """
            <div class="post-date"><a href="/\(post.urlPath)/index.html">\(post.formattedDate)</a></div>
            """
            
        // Add author if available
        if let authorName = blog.authorName {
            if let authorUrl = blog.authorUrl, !authorUrl.isEmpty {
                dateHTML += """
                <div class="post-author">by <a href="\(authorUrl)">\(authorName)</a></div>
                """
            } else {
                dateHTML += """
                <div class="post-author">by \(authorName)</div>
                """
            }
        }
        
        // Generate post content with embeds
        let postContent = MarkdownParser().html(from: post.content)
        var finalContent = ""
        
        // Handle embeds based on position
        if let embed = post.embed, embed.embedPosition == .above {
            finalContent += embed.generateHtml() + "\n"
        }
        
        finalContent += postContent
        
        if let embed = post.embed, embed.embedPosition == .below {
            finalContent += "\n" + embed.generateHtml()
        }

        return """
            <div class="post-item">
                \(titleHTML)
                \(dateHTML)
                <div class="post-summary">\(finalContent)</div>
                \(categoryHTML)
                \(tagsHTML)
            </div>
            """
    }

    /// Renders a full post with header, footer, and content
    private func renderFullPost(_ post: Post) -> String {
        let tagsHTML = renderPostTags(post)
        let categoryHTML = renderPostCategory(post)
        let hasTitle = post.title?.isEmpty == false

        // Title HTML with conditional rendering
        let titleHTML =
            hasTitle
            ? """
                <h1>\(post.displayTitle)</h1>
            """ : ""

        // Date now links to the post
        var dateHTML = """
            <div class="post-date"><a href="/\(post.urlPath)/index.html">\(post.formattedDate)</a></div>
            """
            
        // Add author if available
        if let authorName = blog.authorName {
            if let authorUrl = blog.authorUrl, !authorUrl.isEmpty {
                dateHTML += """
                <div class="post-author">by <a href="\(authorUrl)">\(authorName)</a></div>
                """
            } else {
                dateHTML += """
                <div class="post-author">by \(authorName)</div>
                """
            }
        }
        
        // Generate post content with embeds
        let postContent = MarkdownParser().html(from: post.content)
        var finalContent = ""
        
        // Handle embeds based on position
        if let embed = post.embed, embed.embedPosition == .above {
            finalContent += embed.generateHtml() + "\n"
        }
        
        finalContent += postContent
        
        if let embed = post.embed, embed.embedPosition == .below {
            finalContent += "\n" + embed.generateHtml()
        }

        let content = """
            <article>
                \(titleHTML)
                <div class="post-meta">
                    \(dateHTML)
                </div>
                <div class="post-content">
                    \(finalContent)
                </div>
                <div class="post-meta">
                    \(categoryHTML)
                    \(tagsHTML)
                </div>
            </article>
            """

        let pageTitle =
            hasTitle
            ? "\(post.displayTitle) - \(blog.name)"
            : "\(post.formattedDate) - \(blog.name)"

        return completePage(
            title: pageTitle,
            content: content
        )
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
        
        for post in publishedPosts {
            if let embed = post.embed, embed.embedType == .link, let imageData = embed.imageData {
                // Create a predictable filename based on URL hash
                let imageFilename = "embed-\(embed.url.hash).jpg"
                let imagePath = directory.appendingPathComponent(imageFilename)
                
                // Save the image data
                try? imageData.write(to: imagePath)
            }
        }
    }
    
    // MARK: - Error Handling

    /// Enum representing errors that can occur during site generation
    enum SiteGeneratorError: Error, LocalizedError {
        case noSiteDirectory
        case zipCreationFailed
        case publishingFailed(String)

        var errorDescription: String? {
            switch self {
            case .noSiteDirectory:
                return "Failed to create site directory"
            case .zipCreationFailed:
                return "Failed to create ZIP file of the site"
            case .publishingFailed(let message):
                return "Publishing failed: \(message)"
            }
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
        try self.cssFile.write(
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
        saveEmbedImages(to: embedImagesDirectory)

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
                    secretAccessKey: blog.awsSecretAccessKey!
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
                    password: blog.ftpPassword!,
                    remotePath: blog.ftpPath!,
                    useSFTP: blog.ftpUseSFTP ?? false
                )
            } else {
                // Fall back to manual if FTP is selected but not properly configured
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
            let result = try await publisher.publish(directoryURL: siteDirectory)
            return result
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

        let dateFormatter = ISO8601DateFormatter()

        var rssContent = """
            <?xml version="1.0" encoding="UTF-8" ?>
            <rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">
            <channel>
                <title>\(blog.name)</title>
                <link>\(blog.url)</link>
                <description>\(blog.tagline ?? "Recent posts from \(blog.name)")</description>
                <language>en-us</language>
                <lastBuildDate>\(dateFormatter.string(from: Date()))</lastBuildDate>
                <atom:link href="\(blog.url)/rss.xml" rel="self" type="application/rss+xml" />
        """
        
        // Add author element if author name is available
        if let authorName = blog.authorName {
            if let authorUrl = blog.authorUrl, !authorUrl.isEmpty {
                rssContent += """
                <managingEditor>\(authorName) (\(authorUrl))</managingEditor>
                <webMaster>\(authorName) (\(authorUrl))</webMaster>
                """
            } else {
                rssContent += """
                <managingEditor>\(authorName)</managingEditor>
                <webMaster>\(authorName)</webMaster>
                """
            }
        }

        for post in limitedPosts {
            let postTitle = post.displayTitle
            let postDate = dateFormatter.string(from: post.createdAt)
            let postLink = "\(blog.url)/\(post.urlPath)/"
            
            // Generate post content with embeds for RSS
            let postContent = MarkdownParser().html(from: post.content)
            var finalContent = ""
            
            // Handle embeds based on position
            if let embed = post.embed, embed.embedPosition == .above {
                finalContent += embed.generateHtml() + "\n"
            }
            
            finalContent += postContent
            
            if let embed = post.embed, embed.embedPosition == .below {
                finalContent += "\n" + embed.generateHtml()
            }

            rssContent += """

                <item>
                    <title>\(postTitle)</title>
                    <link>\(postLink)</link>
                    <guid>\(postLink)</guid>
                    <pubDate>\(postDate)</pubDate>
        """
            
            // Add author to individual posts if available
            if let authorName = blog.authorName {
                if let authorUrl = blog.authorUrl, !authorUrl.isEmpty {
                    rssContent += "<author>\(authorName) (\(authorUrl))</author>\n                "
                } else {
                    rssContent += "<author>\(authorName)</author>\n                "
                }
            }
            
            rssContent += """
                    <description><![CDATA[\(finalContent)]]></description>
                </item>
                """
        }

        rssContent += """

            </channel>
            </rss>
            """

        try rssContent.write(to: rssPath, atomically: true, encoding: .utf8)
    }

    /// Generates the index page (home page) of the site
    private func generateIndexPage() throws {
        guard let siteDirectory = siteDirectory else {
            throw SiteGeneratorError.noSiteDirectory
        }

        let indexPath = siteDirectory.appendingPathComponent("index.html")
        let sortedPosts = publishedPostsSorted()

        var postListHTML = ""
        for post in sortedPosts {
            postListHTML += renderPostListItem(post)
        }

        let content = """
            <div class="post-list">
                \(postListHTML)
            </div>
            """

        let customHead = "<link rel=\"sitemap\" type=\"application/xml\" title=\"Sitemap\" href=\"/sitemap.xml\" />"

        let pageContent = completePage(
            title: blog.name,
            content: content,
            customHead: customHead
        )

        try pageContent.write(to: indexPath, atomically: true, encoding: .utf8)
    }

    /// Generates individual pages for each post
    private func generatePostPages() throws {
        guard let siteDirectory = siteDirectory else {
            throw SiteGeneratorError.noSiteDirectory
        }

        let publishedPosts = blog.posts.filter { !$0.isDraft }
        for post in publishedPosts {
            let postDirectory = siteDirectory.appendingPathComponent(
                post.urlPath
            )
            try FileManager.default.createDirectory(
                at: postDirectory,
                withIntermediateDirectories: true
            )

            let postPath = postDirectory.appendingPathComponent("index.html")
            let postContent = renderFullPost(post)

            try postContent.write(
                to: postPath,
                atomically: true,
                encoding: .utf8
            )
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

        let calendar = Calendar.current
        var yearMonthPosts: [Int: [Int: [Post]]] = [:]

        // Group posts by year and month
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

        // Generate HTML for archives
        var archiveContent = "<h1>Archives</h1>"

        let years = yearMonthPosts.keys.sorted(by: >)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM"

        for year in years {
            archiveContent += """
                <div class="archive-year">\(year)</div>
                """

            let months = yearMonthPosts[year]?.keys.sorted(by: >) ?? []

            for month in months {
                let monthName = dateFormatter.monthSymbols[month - 1]

                archiveContent += """
                    <div class="archive-month">\(monthName)</div>
                    <ul>
                    """

                for post in yearMonthPosts[year]?[month] ?? [] {
                    let day = calendar.component(.day, from: post.createdAt)
                    let hasTitle = post.title?.isEmpty == false
                    let postLink = "/\(post.urlPath)/index.html"
                    let displayText =
                        hasTitle ? post.displayTitle : post.formattedDate

                    archiveContent += """
                        <li>
                            <span class="archive-date">\(String(format: "%02d", day)) \(monthName)</span>
                            <a href="\(postLink)">\(displayText)</a>
                        </li>
                        """
                }

                archiveContent += """
                    </ul>
                    """
            }
        }

        let pageContent = completePage(
            title: "Archives - \(blog.name)",
            content: archiveContent
        )

        try pageContent.write(
            to: archivesPath,
            atomically: true,
            encoding: .utf8
        )
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
        var tagListContent = """
            <h1>All Tags</h1>
            <div class="tag-list">
            """

        for tag in sortedTags {
            let tagPostCount = blog.posts.filter { $0.tags.contains(tag) }.count
            tagListContent += """
                <div class="tag-item">
                    <h2><a href="/tags/\(tag.name.urlPathFormatted())/">\(tag.name)</a> <span class="tag-count">(\(tagPostCount))</span></h2>
                </div>
                """
        }

        tagListContent += "</div>"

        let tagIndexPage = completePage(
            title: "Tags - \(blog.name)",
            content: tagListContent
        )

        try tagIndexPage.write(
            to: tagsIndexPath,
            atomically: true,
            encoding: .utf8
        )

        // Create individual tag pages
        for tag in sortedTags {
            let tagPosts = publishedPosts.filter { $0.tags.contains(tag) }
                .sorted { $0.createdAt > $1.createdAt }
            let tagNameEncoded = tag.name.urlPathFormatted()
            let tagDirectory = tagsDirectory.appendingPathComponent(
                tagNameEncoded
            )
            try FileManager.default.createDirectory(
                at: tagDirectory,
                withIntermediateDirectories: true
            )
            let tagPath = tagDirectory.appendingPathComponent("index.html")

            var postListHTML = ""
            for post in tagPosts {
                postListHTML += renderPostListItem(post)
            }

            let tagContent = """
                <h1>Posts tagged with "\(tag.name)"</h1>
                <p class="tag-meta">\(tagPosts.count) \(tagPosts.count == 1 ? "post" : "posts") with this tag</p>
                <div class="post-list">
                    \(postListHTML)
                </div>
                """

            let tagPageContent = completePage(
                title: "Tag: \(tag.name) - \(blog.name)",
                content: tagContent
            )

            try tagPageContent.write(
                to: tagPath,
                atomically: true,
                encoding: .utf8
            )
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
        var categoryListContent = """
            <h1>All Categories</h1>
            <div class="category-list">
            """

        for category in sortedCategories {
            let categoryPostCount = blog.posts.filter {
                $0.category?.id == category.id
            }.count
            categoryListContent += """
                <div class="category-item">
                    <h2><a href="/categories/\(category.name.urlPathFormatted())/">\(category.name)</a> <span class="category-count">(\(categoryPostCount))</span></h2>
                """

            if let description = category.categoryDescription,
                !description.isEmpty
            {
                categoryListContent += """
                    <p class="category-description">\(description)</p>
                    """
            }

            categoryListContent += """
                </div>
                """
        }

        categoryListContent += "</div>"

        let categoryIndexPage = completePage(
            title: "Categories - \(blog.name)",
            content: categoryListContent
        )

        try categoryIndexPage.write(
            to: categoriesIndexPath,
            atomically: true,
            encoding: .utf8
        )

        // Create individual category pages
        for category in sortedCategories {
            let categoryPosts = publishedPosts.filter {
                $0.category?.id == category.id
            }.sorted { $0.createdAt > $1.createdAt }
            let categoryNameEncoded = category.name.urlPathFormatted()
            let categoryDirectory = categoriesDirectory.appendingPathComponent(
                categoryNameEncoded
            )
            try FileManager.default.createDirectory(
                at: categoryDirectory,
                withIntermediateDirectories: true
            )
            let categoryPath = categoryDirectory.appendingPathComponent(
                "index.html"
            )

            var postListHTML = ""
            for post in categoryPosts {
                postListHTML += renderPostListItem(post)
            }

            var categoryContent = """
                <h1>Posts in category "\(category.name)"</h1>
                """

            if let description = category.categoryDescription,
                !description.isEmpty
            {
                categoryContent += """
                    <p class="category-description">\(description)</p>
                    """
            }

            categoryContent += """
                <p class="category-meta">\(categoryPosts.count) \(categoryPosts.count == 1 ? "post" : "posts") in this category</p>
                <div class="post-list">
                    \(postListHTML)
                </div>
                """

            let categoryPageContent = completePage(
                title: "Category: \(category.name) - \(blog.name)",
                content: categoryContent
            )

            try categoryPageContent.write(
                to: categoryPath,
                atomically: true,
                encoding: .utf8
            )
        }
    }
    
    /// Generates a robots.txt file for the site
    private func generateRobotsTxt() throws {
        guard let siteDirectory = siteDirectory else {
            throw SiteGeneratorError.noSiteDirectory
        }
        
        let robotsPath = siteDirectory.appendingPathComponent("robots.txt")
        
        // Use default permissive content
        let content = """
        User-agent: *
        Allow: /
        
        Sitemap: \(blog.url)/sitemap.xml
        """
        
        try content.write(to: robotsPath, atomically: true, encoding: .utf8)
    }
    
    /// Generates a sitemap.xml file for the site
    private func generateSitemap() throws {
        guard let siteDirectory = siteDirectory else {
            throw SiteGeneratorError.noSiteDirectory
        }
        
        let sitemapPath = siteDirectory.appendingPathComponent("sitemap.xml")
        let sortedPosts = publishedPostsSorted()
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]
        
        var sitemapContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
        """
        
        // Add home page
        sitemapContent += """
            <url>
                <loc>\(blog.url)/</loc>
                <lastmod>\(dateFormatter.string(from: Date()))</lastmod>
                <changefreq>weekly</changefreq>
                <priority>1.0</priority>
            </url>
        """
        
        // Add archive page
        sitemapContent += """
            <url>
                <loc>\(blog.url)/archives/</loc>
                <lastmod>\(dateFormatter.string(from: Date()))</lastmod>
                <changefreq>weekly</changefreq>
                <priority>0.8</priority>
            </url>
        """
        
        // Add tags page
        sitemapContent += """
            <url>
                <loc>\(blog.url)/tags/</loc>
                <lastmod>\(dateFormatter.string(from: Date()))</lastmod>
                <changefreq>weekly</changefreq>
                <priority>0.7</priority>
            </url>
        """
        
        // Add categories page
        sitemapContent += """
            <url>
                <loc>\(blog.url)/categories/</loc>
                <lastmod>\(dateFormatter.string(from: Date()))</lastmod>
                <changefreq>weekly</changefreq>
                <priority>0.7</priority>
            </url>
        """
        
        // Add individual posts
        for post in sortedPosts {
            let postLink = "\(blog.url)/\(post.urlPath)/"
            let lastmod = dateFormatter.string(from: post.createdAt)
            
            sitemapContent += """
            <url>
                <loc>\(postLink)</loc>
                <lastmod>\(lastmod)</lastmod>
                <changefreq>monthly</changefreq>
                <priority>0.6</priority>
            </url>
            """
        }
        
        // Add individual tag pages
        for tag in blog.tags {
            let tagLink = "\(blog.url)/tags/\(tag.name.urlPathFormatted())/"
            let lastmod = dateFormatter.string(from: Date())
            
            sitemapContent += """
            <url>
                <loc>\(tagLink)</loc>
                <lastmod>\(lastmod)</lastmod>
                <changefreq>monthly</changefreq>
                <priority>0.5</priority>
            </url>
            """
        }
        
        // Add individual category pages
        for category in blog.categories {
            let categoryLink = "\(blog.url)/categories/\(category.name.urlPathFormatted())/"
            let lastmod = dateFormatter.string(from: Date())
            
            sitemapContent += """
            <url>
                <loc>\(categoryLink)</loc>
                <lastmod>\(lastmod)</lastmod>
                <changefreq>monthly</changefreq>
                <priority>0.5</priority>
            </url>
            """
        }
        
        sitemapContent += """
        </urlset>
        """
        
        try sitemapContent.write(to: sitemapPath, atomically: true, encoding: .utf8)
    }
}
