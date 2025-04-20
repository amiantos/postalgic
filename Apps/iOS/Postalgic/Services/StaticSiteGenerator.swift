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
    /* Add your custom CSS here */
    body {
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
        line-height: 1.6;
        color: #333;
        max-width: 800px;
        margin: 0 auto;
        padding: 20px;
    }
    
    .container {
        max-width: 800px;
        margin: 0 auto;
        padding: 20px;
    }
    
    header {
        margin-bottom: 30px;
        border-bottom: 1px solid #eee;
        padding-bottom: 10px;
    }
    
    header h1 {
        margin: 0;
    }
    
    header h1 a {
        text-decoration: none;
        color: #333;
    }
    
    nav ul {
        display: flex;
        list-style: none;
        padding: 0;
        margin: 10px 0 0 0;
    }
    
    nav ul li {
        margin-right: 20px;
    }
    
    nav ul li a {
        text-decoration: none;
        color: #0066cc;
    }
    
    footer {
        margin-top: 40px;
        padding-top: 10px;
        border-top: 1px solid #eee;
        font-size: 0.9em;
        color: #666;
    }
    
    a {
        color: #0066cc;
    }
    
    .post-item {
        margin-bottom: 30px;
        border-bottom: 1px solid #eee;
        padding-bottom: 20px;
    }
    
    .post-date {
        font-size: 0.9em;
        color: #666;
    }
    
    .post-summary {
        margin-top: 10px;
    }
    
    .post-content {
        line-height: 1.7;
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
    
    /* Categories */
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
    
    .tag {
        display: inline-block;
        background-color: #f0f0f0;
        padding: 2px 8px;
        margin-right: 5px;
        border-radius: 3px;
        color: #555;
        text-decoration: none;
    }
    
    .tag:hover {
        background-color: #e0e0e0;
    }
    
    .tag-list, .category-list {
        margin-top: 20px;
    }
    
    .tag-item, .category-item {
        margin-bottom: 20px;
    }
    
    .tag-count, .category-count {
        font-size: 0.8em;
        color: #666;
    }
    
    .archive-year {
        margin-top: 30px;
        margin-bottom: 10px;
        font-size: 1.4em;
        font-weight: bold;
    }
    
    .archive-month {
        margin-top: 20px;
        margin-bottom: 10px;
        font-size: 1.2em;
        font-weight: bold;
    }
    
    .archive-date {
        display: inline-block;
        width: 120px;
        color: #666;
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
