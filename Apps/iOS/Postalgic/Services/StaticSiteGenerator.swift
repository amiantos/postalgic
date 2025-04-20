//
//  StaticSiteGenerator.swift
//  Postalgic
//
//  Created by Brad Root on 4/19/25.
//

import Foundation
import ZIPFoundation

/// StaticSiteGenerator handles the generation of a static site from a Blog model
class StaticSiteGenerator {
    private let blog: Blog
    private var siteDirectory: URL?
    private var cssFile: String = """
    /* Basic reset */
    * {
        margin: 0;
        padding: 0;
        box-sizing: border-box;
    }

    body {
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
        line-height: 1.6;
        color: #333;
        background-color: #f8f8f8;
        padding: 0;
        margin: 0;
    }

    .container {
        max-width: 800px;
        margin: 0 auto;
        padding: 20px;
        background-color: white;
        min-height: 100vh;
        box-shadow: 0 0 10px rgba(0, 0, 0, 0.1);
    }

    /* Header and Navigation */
    header {
        margin-bottom: 30px;
        border-bottom: 1px solid #eee;
        padding-bottom: 20px;
    }

    header h1 {
        font-size: 2em;
        margin-bottom: 10px;
    }

    header h1 a {
        text-decoration: none;
        color: #333;
    }

    nav ul {
        list-style: none;
        display: flex;
        flex-wrap: wrap;
        padding: 0;
        margin: 10px 0 0 0;
    }

    nav ul li {
        margin-right: 20px;
        margin-bottom: 5px;
    }

    nav ul li a {
        text-decoration: none;
        color: #666;
        font-weight: 500;
    }

    nav ul li a:hover {
        color: #000;
    }

    /* Main content */
    main {
        margin-bottom: 40px;
    }
    
    main h1, main h2 {
        margin-bottom: 20px;
    }

    /* Post list */
    .post-list {
        margin-bottom: 30px;
    }

    .post-item {
        margin-bottom: 30px;
        padding-bottom: 20px;
        border-bottom: 1px solid #eee;
    }

    .post-item h2 {
        margin-bottom: 5px;
    }

    .post-item h2 a {
        text-decoration: none;
        color: #333;
    }

    .post-date {
        margin-bottom: 10px;
        color: #666;
        font-size: 0.9em;
    }

    .post-summary {
        margin-top: 10px;
    }

    /* Post content */
    .post-title {
        margin-bottom: 10px;
    }

    .post-content {
        margin-top: 20px;
        line-height: 1.8;
    }
    
    .post-content p, .post-content ul, .post-content ol {
        margin-bottom: 20px;
    }
    
    .post-content h1, .post-content h2, .post-content h3 {
        margin-top: 30px;
        margin-bottom: 15px;
    }
    
    .post-content a {
        color: #0066cc;
        text-decoration: none;
    }
    
    .post-content a:hover {
        text-decoration: underline;
    }
    
    .primary-link {
        margin: 15px 0;
        padding: 10px;
        background-color: #f5f5f5;
        border-radius: 5px;
    }
    
    .primary-link a {
        color: #0066cc;
        text-decoration: none;
        word-break: break-all;
    }
    
    .post-meta {
        margin: 20px 0;
        font-size: 0.9em;
        color: #666;
    }
    
    .post-tags, .post-category {
        margin-top: 5px;
        font-size: 0.9em;
    }
    
    /* Categories styling - green theme */
    .post-category {
        margin: 10px 0;
        color: #666;
    }

    .post-category a {
        display: inline-block;
        padding: 3px 10px;
        margin: 0 4px;
        background-color: #e6f7e6;
        color: #2e8b57;
        border-radius: 4px;
        font-size: 0.9em;
        font-weight: 500;
        text-decoration: none;
    }

    .post-category a:hover {
        background-color: #d4f0d4;
        text-decoration: none;
    }

    .category-list {
        margin: 20px 0;
    }

    .category-item {
        margin-bottom: 25px;
        padding-bottom: 15px;
        border-bottom: 1px solid #eee;
    }

    .category-item h2 {
        margin-bottom: 8px;
    }

    .category-item h2 a {
        text-decoration: none;
        color: #2e8b57;
    }

    .category-count {
        font-size: 0.8em;
        color: #666;
        font-weight: normal;
    }
    
    .category-description {
        color: #666;
        margin-top: 5px;
    }
    
    .category-meta {
        color: #666;
        margin-bottom: 20px;
        font-style: italic;
    }

    /* Tags and tag cloud styling - blue theme */
    .post-tags {
        margin: 10px 0;
        color: #666;
    }

    .tag {
        display: inline-block;
        padding: 2px 8px;
        margin: 0 4px;
        background-color: #e9f3ff;
        color: #0066cc;
        border-radius: 4px;
        font-size: 0.85em;
        text-decoration: none;
    }

    .tag:hover {
        background-color: #d0e5ff;
        text-decoration: none;
    }
    
    .tag-cloud {
        margin: 20px 0 30px 0;
        text-align: center;
        line-height: 2.2;
    }
    
    .tag-cloud.large {
        margin: 30px 0;
        line-height: 2.5;
    }
    
    .tag-item {
        display: inline-block;
        padding: 4px 10px;
        margin: 5px;
        background-color: #e9f3ff;
        color: #0066cc;
        border-radius: 4px;
        text-decoration: none;
        transition: all 0.2s ease;
    }
    
    .tag-item:hover {
        background-color: #d0e5ff;
        transform: translateY(-2px);
    }
    
    .tag-count {
        color: #666;
        font-size: 0.85em;
    }
    
    .tag-description {
        color: #666;
        margin-bottom: 20px;
    }
    
    .tag-list {
        margin-top: 20px;
    }

    /* Archive pages */
    .archive-year {
        margin-top: 30px;
        margin-bottom: 10px;
        font-size: 1.4em;
        font-weight: bold;
    }
    
    .archive-month {
        margin-bottom: 40px;
    }
    
    .archive-month h2 {
        margin-bottom: 15px;
        padding-bottom: 5px;
        border-bottom: 1px solid #eee;
    }
    
    .archive-month ul {
        list-style: none;
    }
    
    .archive-month li {
        margin-bottom: 10px;
        display: flex;
        flex-wrap: wrap;
    }
    
    .archive-month .post-date {
        min-width: 170px;
        margin-right: 10px;
    }
    
    .archive-date {
        display: inline-block;
        width: 120px;
        color: #666;
    }
    
    .archive-month a {
        text-decoration: none;
        color: #333;
    }
    
    .archive-month a:hover {
        text-decoration: underline;
    }
    
    /* Error page styling */
    .error-container {
        text-align: center;
        padding: 50px 0;
    }
    
    .error-code {
        font-size: 6rem;
        font-weight: bold;
        margin-bottom: 10px;
        color: #d9534f;
    }
    
    .error-message {
        font-size: 2rem;
        margin-bottom: 30px;
    }
    
    .back-button {
        display: inline-block;
        padding: 10px 20px;
        background-color: #0275d8;
        color: white;
        text-decoration: none;
        border-radius: 5px;
        font-weight: bold;
        transition: background-color 0.3s;
    }
    
    .back-button:hover {
        background-color: #025aa5;
    }

    /* Footer */
    footer {
        margin-top: 40px;
        padding-top: 20px;
        border-top: 1px solid #eee;
        font-size: 0.9em;
        color: #666;
    }
    
    /* Responsive design with media queries */
    @media (max-width: 768px) {
        .container {
            padding: 15px;
        }
        
        header h1 {
            font-size: 1.8em;
        }
        
        nav ul {
            flex-direction: row;
            flex-wrap: wrap;
        }
        
        nav ul li {
            margin-bottom: 5px;
        }
        
        .archive-month li {
            flex-direction: column;
        }
        
        .archive-month .post-date {
            margin-bottom: 5px;
        }
        
        .tag-cloud {
            line-height: 2.2;
        }
        
        .post-title {
            font-size: 1.8em;
        }
    }
    
    @media (max-width: 480px) {
        .container {
            padding: 10px;
        }
        
        header h1 {
            font-size: 1.6em;
        }
    }
    """
    
    /// Initializes a StaticSiteGenerator with a Blog model
    /// - Parameter blog: The Blog to generate a site for
    init(blog: Blog) {
        self.blog = blog
    }
    
    /// Enum representing errors that can occur during site generation
    enum SiteGeneratorError: Error, LocalizedError {
        case noSiteDirectory
        case zipCreationFailed
        case awsPublishingFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .noSiteDirectory:
                return "Failed to create site directory"
            case .zipCreationFailed:
                return "Failed to create ZIP file of the site"
            case .awsPublishingFailed(let message):
                return "AWS publishing failed: \(message)"
            }
        }
    }
    
    /// Generates a static site for the blog
    /// - Returns: URL to the generated ZIP file if not publishing to AWS
    /// - Throws: SiteGeneratorError
    func generateSite() async throws -> URL? {
        // Create a temporary directory for the site
        let tempDirectory = FileManager.default.temporaryDirectory
        let siteDirectory = tempDirectory.appendingPathComponent(UUID().uuidString)
        
        try FileManager.default.createDirectory(at: siteDirectory, withIntermediateDirectories: true)
        self.siteDirectory = siteDirectory
        
        print("📝 Generating site in \(siteDirectory.path)")
        
        // Create CSS directory and file
        let cssDirectory = siteDirectory.appendingPathComponent("css")
        try FileManager.default.createDirectory(at: cssDirectory, withIntermediateDirectories: true)
        try self.cssFile.write(to: cssDirectory.appendingPathComponent("style.css"), atomically: true, encoding: .utf8)
        
        // Generate site content
        try generateIndexPage()
        try generatePostPages()
        try generateArchivesPage()
        try generateTagPages()
        try generateCategoryPages()
        
        // If AWS is configured, publish to AWS
        if blog.hasAwsConfigured {
            print("🚀 Publishing to AWS S3...")
            do {
                let publisher = AWSPublisher(
                    region: blog.awsRegion!,
                    bucket: blog.awsS3Bucket!,
                    distributionId: blog.awsCloudFrontDistId!,
                    accessKeyId: blog.awsAccessKeyId!,
                    secretAccessKey: blog.awsSecretAccessKey!
                )
                try publisher.uploadDirectory(siteDirectory)
                
                // Try to invalidate CloudFront cache
                try publisher.invalidateCache()
                
                return nil // No ZIP to return when publishing to AWS
            } catch {
                throw SiteGeneratorError.awsPublishingFailed(error.localizedDescription)
            }
        } else {
            // Create ZIP archive
            let zipURL = tempDirectory.appendingPathComponent("\(blog.name.replacingOccurrences(of: " ", with: "-"))-site.zip")
            
            // Remove existing ZIP if it exists
            if FileManager.default.fileExists(atPath: zipURL.path) {
                try FileManager.default.removeItem(at: zipURL)
            }
            
            do {
                try FileManager.default.zipItem(at: siteDirectory, to: zipURL, shouldKeepParent: false)
                print("📦 Site ZIP created at \(zipURL.path)")
                return zipURL
            } catch {
                print("❌ Failed to create ZIP: \(error.localizedDescription)")
                throw SiteGeneratorError.zipCreationFailed
            }
        }
    }
    
    /// Generates the index page (home page) of the site
    private func generateIndexPage() throws {
        guard let siteDirectory = siteDirectory else { throw SiteGeneratorError.noSiteDirectory }
        
        let indexPath = siteDirectory.appendingPathComponent("index.html")
        let sortedPosts = blog.posts.sorted { $0.createdAt > $1.createdAt }
        
        var postListHTML = ""
        for post in sortedPosts {
            var postTagsHTML = ""
            var postCategoryHTML = ""
            
            if !post.tags.isEmpty {
                postTagsHTML = """
                <div class="post-tags">
                    Tags: 
                """
                for tag in post.tags {
                    postTagsHTML += """
                    <a href="/tags/\(tag.name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? tag.name).html" class="tag">\(tag.name)</a> 
                    """
                }
                postTagsHTML += "</div>"
            }
            
            if let category = post.category {
                postCategoryHTML = """
                <div class="post-category">
                    Category: <a href="/categories/\(category.name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? category.name).html">\(category.name)</a>
                </div>
                """
            }
            
            postListHTML += """
            <div class="post-item">
                <h2><a href="/\(post.urlPath)/index.html">\(post.displayTitle)</a></h2>
                <div class="post-date">\(post.formattedDate)</div>
                \(postCategoryHTML)
                \(postTagsHTML)
                <div class="post-summary">\(String(post.content.prefix(150)))...</div>
            </div>
            """
        }
        
        let indexContent = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>\(blog.name)</title>
            <link rel="stylesheet" href="/css/style.css">
        </head>
        <body>
            <div class="container">
                <header>
                    <h1><a href="/">\(blog.name)</a></h1>
                    <nav>
                        <ul>
                            <li><a href="/">Home</a></li>
                            <li><a href="/archives.html">Archives</a></li>
                            <li><a href="/tags.html">Tags</a></li>
                            <li><a href="/categories.html">Categories</a></li>
                        </ul>
                    </nav>
                </header>
                
                <main>
                    <div class="post-list">
                        \(postListHTML)
                    </div>
                </main>
                
                <footer>
                    <p>&copy; \(Calendar.current.component(.year, from: Date())) \(blog.name). Generated with Postalgic.</p>
                </footer>
            </div>
        </body>
        </html>
        """
        
        try indexContent.write(to: indexPath, atomically: true, encoding: .utf8)
    }
    
    /// Generates individual pages for each post
    private func generatePostPages() throws {
        guard let siteDirectory = siteDirectory else { throw SiteGeneratorError.noSiteDirectory }
        
        for post in blog.posts {
            let postDirectory = siteDirectory.appendingPathComponent(post.urlPath)
            try FileManager.default.createDirectory(at: postDirectory, withIntermediateDirectories: true)
            
            let postPath = postDirectory.appendingPathComponent("index.html")
            
            var postTagsHTML = ""
            var postCategoryHTML = ""
            
            if !post.tags.isEmpty {
                postTagsHTML = """
                <div class="post-tags">
                    Tags: 
                """
                for tag in post.tags {
                    postTagsHTML += """
                    <a href="/tags/\(tag.name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? tag.name).html" class="tag">\(tag.name)</a> 
                    """
                }
                postTagsHTML += "</div>"
            }
            
            if let category = post.category {
                postCategoryHTML = """
                <div class="post-category">
                    Category: <a href="/categories/\(category.name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? category.name).html">\(category.name)</a>
                </div>
                """
            }
            
            let postContent = """
            <!DOCTYPE html>
            <html lang="en">
            <head>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <title>\(post.displayTitle) - \(blog.name)</title>
                <link rel="stylesheet" href="/css/style.css">
            </head>
            <body>
                <div class="container">
                    <header>
                        <h1><a href="/">\(blog.name)</a></h1>
                        <nav>
                            <ul>
                                <li><a href="/">Home</a></li>
                                <li><a href="/archives.html">Archives</a></li>
                                <li><a href="/tags.html">Tags</a></li>
                                <li><a href="/categories.html">Categories</a></li>
                            </ul>
                        </nav>
                    </header>
                    
                    <main>
                        <article>
                            <h1>\(post.displayTitle)</h1>
                            <div class="post-meta">
                                <div class="post-date">\(post.formattedDate)</div>
                                \(postCategoryHTML)
                                \(postTagsHTML)
                            </div>
                            <div class="post-content">
                                \(post.content)
                            </div>
                        </article>
                    </main>
                    
                    <footer>
                        <p>&copy; \(Calendar.current.component(.year, from: Date())) \(blog.name). Generated with Postalgic.</p>
                    </footer>
                </div>
            </body>
            </html>
            """
            
            try postContent.write(to: postPath, atomically: true, encoding: .utf8)
        }
    }
    
    /// Generates an archives page organizing posts by year and month
    private func generateArchivesPage() throws {
        guard let siteDirectory = siteDirectory else { throw SiteGeneratorError.noSiteDirectory }
        
        let archivesPath = siteDirectory.appendingPathComponent("archives.html")
        let sortedPosts = blog.posts.sorted { $0.createdAt > $1.createdAt }
        
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
        var archiveContent = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Archives - \(blog.name)</title>
            <link rel="stylesheet" href="/css/style.css">
        </head>
        <body>
            <div class="container">
                <header>
                    <h1><a href="/">\(blog.name)</a></h1>
                    <nav>
                        <ul>
                            <li><a href="/">Home</a></li>
                            <li><a href="/archives.html">Archives</a></li>
                            <li><a href="/tags.html">Tags</a></li>
                            <li><a href="/categories.html">Categories</a></li>
                        </ul>
                    </nav>
                </header>
                
                <main>
                    <h1>Archives</h1>
        """
        
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
                    archiveContent += """
                            <li>
                                <span class="archive-date">\(String(format: "%02d", day)) \(monthName)</span>
                                <a href="/\(post.urlPath)/index.html">\(post.displayTitle)</a>
                            </li>
                    """
                }
                
                archiveContent += """
                        </ul>
                """
            }
        }
        
        archiveContent += """
                </main>
                
                <footer>
                    <p>&copy; \(Calendar.current.component(.year, from: Date())) \(blog.name). Generated with Postalgic.</p>
                </footer>
            </div>
        </body>
        </html>
        """
        
        try archiveContent.write(to: archivesPath, atomically: true, encoding: .utf8)
    }
    
    /// Generates tag pages for all tags used in posts
    private func generateTagPages() throws {
        guard let siteDirectory = siteDirectory else { throw SiteGeneratorError.noSiteDirectory }
        
        // Get all unique tags used by this blog's posts
        var uniqueTags = Set<Tag>()
        for post in blog.posts {
            for tag in post.tags {
                uniqueTags.insert(tag)
            }
        }
        let sortedTags = Array(uniqueTags).sorted { $0.name < $1.name }
        
        // If no tags, nothing to do
        if sortedTags.isEmpty {
            return
        }
        
        // Create tags directory
        let tagsDirectory = siteDirectory.appendingPathComponent("tags")
        try FileManager.default.createDirectory(at: tagsDirectory, withIntermediateDirectories: true)
        
        // Create tag index page
        let tagsIndexPath = siteDirectory.appendingPathComponent("tags.html")
        var tagIndexContent = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Tags - \(blog.name)</title>
            <link rel="stylesheet" href="/css/style.css">
        </head>
        <body>
            <div class="container">
                <header>
                    <h1><a href="/">\(blog.name)</a></h1>
                    <nav>
                        <ul>
                            <li><a href="/">Home</a></li>
                            <li><a href="/archives.html">Archives</a></li>
                            <li><a href="/tags.html">Tags</a></li>
                            <li><a href="/categories.html">Categories</a></li>
                        </ul>
                    </nav>
                </header>
                
                <main>
                    <h1>All Tags</h1>
                    <div class="tag-list">
        """
        
        for tag in sortedTags {
            let tagPostCount = blog.posts.filter { $0.tags.contains(tag) }.count
            tagIndexContent += """
                        <div class="tag-item">
                            <h2><a href="/tags/\(tag.name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? tag.name).html">\(tag.name)</a> <span class="tag-count">(\(tagPostCount))</span></h2>
                        </div>
            """
        }
        
        tagIndexContent += """
                    </div>
                </main>
                
                <footer>
                    <p>&copy; \(Calendar.current.component(.year, from: Date())) \(blog.name). Generated with Postalgic.</p>
                </footer>
            </div>
        </body>
        </html>
        """
        
        try tagIndexContent.write(to: tagsIndexPath, atomically: true, encoding: .utf8)
        
        // Create individual tag pages
        for tag in sortedTags {
            let tagPosts = blog.posts.filter { $0.tags.contains(tag) }.sorted { $0.createdAt > $1.createdAt }
            let tagPath = tagsDirectory.appendingPathComponent("\(tag.name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? tag.name).html")
            
            var postListHTML = ""
            for post in tagPosts {
                var postTagsHTML = ""
                var postCategoryHTML = ""
                
                if !post.tags.isEmpty {
                    postTagsHTML = """
                    <div class="post-tags">
                        Tags: 
                    """
                    for postTag in post.tags {
                        postTagsHTML += """
                        <a href="/tags/\(postTag.name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? postTag.name).html" class="tag">\(postTag.name)</a> 
                        """
                    }
                    postTagsHTML += "</div>"
                }
                
                if let category = post.category {
                    postCategoryHTML = """
                    <div class="post-category">
                        Category: <a href="/categories/\(category.name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? category.name).html">\(category.name)</a>
                    </div>
                    """
                }
                
                postListHTML += """
                <div class="post-item">
                    <h2><a href="/\(post.urlPath)/index.html">\(post.displayTitle)</a></h2>
                    <div class="post-date">\(post.formattedDate)</div>
                    \(postCategoryHTML)
                    \(postTagsHTML)
                    <div class="post-summary">\(String(post.content.prefix(150)))...</div>
                </div>
                """
            }
            
            let tagPageContent = """
            <!DOCTYPE html>
            <html lang="en">
            <head>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <title>Tag: \(tag.name) - \(blog.name)</title>
                <link rel="stylesheet" href="/css/style.css">
            </head>
            <body>
                <div class="container">
                    <header>
                        <h1><a href="/">\(blog.name)</a></h1>
                        <nav>
                            <ul>
                                <li><a href="/">Home</a></li>
                                <li><a href="/archives.html">Archives</a></li>
                                <li><a href="/tags.html">Tags</a></li>
                                <li><a href="/categories.html">Categories</a></li>
                            </ul>
                        </nav>
                    </header>
                    
                    <main>
                        <h1>Posts tagged with "\(tag.name)"</h1>
                        <p class="tag-meta">\(tagPosts.count) \(tagPosts.count == 1 ? "post" : "posts") with this tag</p>
                        <div class="post-list">
                            \(postListHTML)
                        </div>
                    </main>
                    
                    <footer>
                        <p>&copy; \(Calendar.current.component(.year, from: Date())) \(blog.name). Generated with Postalgic.</p>
                    </footer>
                </div>
            </body>
            </html>
            """
            
            try tagPageContent.write(to: tagPath, atomically: true, encoding: .utf8)
        }
    }
    
    /// Generates category pages for all categories used in posts
    private func generateCategoryPages() throws {
        guard let siteDirectory = siteDirectory else { throw SiteGeneratorError.noSiteDirectory }
        
        // Get all unique categories used by this blog's posts
        var uniqueCategories = Set<Category>()
        for post in blog.posts {
            if let category = post.category {
                uniqueCategories.insert(category)
            }
        }
        let sortedCategories = Array(uniqueCategories).sorted { $0.name < $1.name }
        
        // If no categories, nothing to do
        if sortedCategories.isEmpty {
            return
        }
        
        // Create category index page
        let categoriesIndexPath = siteDirectory.appendingPathComponent("categories.html")
        var categoryIndexContent = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Categories - \(blog.name)</title>
            <link rel="stylesheet" href="/css/style.css">
        </head>
        <body>
            <div class="container">
                <header>
                    <h1><a href="/">\(blog.name)</a></h1>
                    <nav>
                        <ul>
                            <li><a href="/">Home</a></li>
                            <li><a href="/archives.html">Archives</a></li>
                            <li><a href="/tags.html">Tags</a></li>
                            <li><a href="/categories.html">Categories</a></li>
                        </ul>
                    </nav>
                </header>
                
                <main>
                    <h1>All Categories</h1>
                    <div class="category-list">
        """
        
        for category in sortedCategories {
            let categoryPostCount = blog.posts.filter { $0.category?.id == category.id }.count
            categoryIndexContent += """
                        <div class="category-item">
                            <h2><a href="/categories/\(category.name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? category.name).html">\(category.name)</a> <span class="category-count">(\(categoryPostCount))</span></h2>
                            
            """
            
            if let description = category.categoryDescription, !description.isEmpty {
                categoryIndexContent += """
                            <p class="category-description">\(description)</p>
                """
            }
            
            categoryIndexContent += """
                        </div>
            """
        }
        
        categoryIndexContent += """
                    </div>
                </main>
                
                <footer>
                    <p>&copy; \(Calendar.current.component(.year, from: Date())) \(blog.name). Generated with Postalgic.</p>
                </footer>
            </div>
        </body>
        </html>
        """
        
        try categoryIndexContent.write(to: categoriesIndexPath, atomically: true, encoding: .utf8)
        
        // Create individual category pages
        let categoriesDirectory = siteDirectory.appendingPathComponent("categories")
        try FileManager.default.createDirectory(at: categoriesDirectory, withIntermediateDirectories: true)
        
        for category in sortedCategories {
            let categoryPosts = blog.posts.filter { $0.category?.id == category.id }.sorted { $0.createdAt > $1.createdAt }
            let categoryPath = categoriesDirectory.appendingPathComponent("\(category.name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? category.name).html")
            
            var postListHTML = ""
            for post in categoryPosts {
                var postTagsHTML = ""
                if !post.tags.isEmpty {
                    postTagsHTML = """
                    <div class="post-tags">
                        Tags: 
                    """
                    for tag in post.tags {
                        postTagsHTML += """
                        <a href="/tags/\(tag.name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? tag.name).html" class="tag">\(tag.name)</a> 
                        """
                    }
                    postTagsHTML += "</div>"
                }
                
                postListHTML += """
                <div class="post-item">
                    <h2><a href="/\(post.urlPath)/index.html">\(post.displayTitle)</a></h2>
                    <div class="post-date">\(post.formattedDate)</div>
                    \(postTagsHTML)
                    <div class="post-summary">\(String(post.content.prefix(150)))...</div>
                </div>
                """
            }
            
            let categoryPageHTML = """
            <!DOCTYPE html>
            <html lang="en">
            <head>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <title>Category: \(category.name) - \(blog.name)</title>
                <link rel="stylesheet" href="/css/style.css">
            </head>
            <body>
                <div class="container">
                    <header>
                        <h1><a href="/">\(blog.name)</a></h1>
                        <nav>
                            <ul>
                                <li><a href="/">Home</a></li>
                                <li><a href="/archives.html">Archives</a></li>
                                <li><a href="/tags.html">Tags</a></li>
                                <li><a href="/categories.html">Categories</a></li>
                            </ul>
                        </nav>
                    </header>
                    
                    <main>
                        <h1>Posts in category "\(category.name)"</h1>
            """
            
            if let description = category.categoryDescription, !description.isEmpty {
                categoryPageHTML + """
                        <p class="category-description">\(description)</p>
                """
            }
            
            let categoryPageContent = categoryPageHTML + """
                        <p class="category-meta">\(categoryPosts.count) \(categoryPosts.count == 1 ? "post" : "posts") in this category</p>
                        <div class="post-list">
                            \(postListHTML)
                        </div>
                    </main>
                    
                    <footer>
                        <p>&copy; \(Calendar.current.component(.year, from: Date())) \(blog.name). Generated with Postalgic.</p>
                    </footer>
                </div>
            </body>
            </html>
            """
            
            try categoryPageContent.write(to: categoryPath, atomically: true, encoding: .utf8)
        }
    }
}
