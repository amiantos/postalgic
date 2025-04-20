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
    /* Base styles */
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
    
    .post-tags, .post-category {
        margin: 10px 0;
        font-size: 0.9rem;
    }
    
    .post-summary {
        margin-top: 10px;
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
