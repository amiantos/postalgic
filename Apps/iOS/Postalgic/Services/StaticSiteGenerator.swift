//
//  StaticSiteGenerator.swift
//  Postalgic
//
//  Created by Brad Root on 4/19/25.
//

import Foundation
import SwiftData
import ZIPFoundation

class StaticSiteGenerator {
    private let blog: Blog
    private let fileManager = FileManager.default
    private var siteDirectory: URL?
    
    init(blog: Blog) {
        self.blog = blog
    }
    
    func generateSite() async throws -> URL {
        // Create temporary directory for site
        let tempDirectory = fileManager.temporaryDirectory
        let siteDirectoryName = "\(blog.name.filter { $0.isLetter || $0.isNumber })-\(Date().timeIntervalSince1970)"
        let siteDirectory = tempDirectory.appendingPathComponent(siteDirectoryName)
        
        self.siteDirectory = siteDirectory
        
        try fileManager.createDirectory(at: siteDirectory, withIntermediateDirectories: true)
        
        // Create site structure
        try createSiteStructure()
        
        // Generate index page
        try generateIndexPage()
        
        // Generate post pages
        try generatePostPages()
        
        // Generate archive pages
        try generateArchivePages()
        
        // Generate CSS
        try generateCSS()
        
        // If AWS is configured, publish to S3 and invalidate CloudFront
        if blog.hasAwsConfigured {
            try publishToAWS()
            return siteDirectory // Return the directory to indicate AWS was used
        } else {
            // Otherwise, zip the site for local sharing
            let zipURL = tempDirectory.appendingPathComponent("\(siteDirectoryName).zip")
            try zipSite(to: zipURL)
            return zipURL
        }
    }
    
    private func publishToAWS() throws {
        guard let siteDirectory = siteDirectory else { throw SiteGeneratorError.noSiteDirectory }
        guard let region = blog.awsRegion,
              let bucket = blog.awsS3Bucket,
              let distId = blog.awsCloudFrontDistId,
              let identityPoolId = blog.awsIdentityPoolId else {
            throw SiteGeneratorError.missingAWSCredentials
        }
        
        let publisher = AWSPublisher(
            region: region,
            bucket: bucket,
            distributionId: distId,
            identityPoolId: identityPoolId
        )
        
        try publisher.uploadDirectory(siteDirectory)
        try publisher.invalidateCache()
    }
    
    private func createSiteStructure() throws {
        guard let siteDirectory = siteDirectory else { throw SiteGeneratorError.noSiteDirectory }
        
        // Create main site directory if it doesn't exist
        if !fileManager.fileExists(atPath: siteDirectory.path) {
            try fileManager.createDirectory(at: siteDirectory, withIntermediateDirectories: true)
        }
        
        // Create CSS directory
        let cssDirectory = siteDirectory.appendingPathComponent("css")
        if !fileManager.fileExists(atPath: cssDirectory.path) {
            try fileManager.createDirectory(at: cssDirectory, withIntermediateDirectories: true)
        }
        
        // We'll create the actual post directories in the generatePostPages method
        // to ensure all directories exist before writing to them
    }
    
    private func generateIndexPage() throws {
        guard let siteDirectory = siteDirectory else { throw SiteGeneratorError.noSiteDirectory }
        
        let indexPath = siteDirectory.appendingPathComponent("index.html")
        let sortedPosts = blog.posts.sorted { $0.createdAt > $1.createdAt }
        
        var postListHTML = ""
        for post in sortedPosts.prefix(10) {
            postListHTML += """
            <div class="post-item">
                <h2><a href="/\(post.urlPath)/index.html">\(post.displayTitle)</a></h2>
                <div class="post-date">\(post.formattedDate)</div>
                <div class="post-summary">\(String(post.content.prefix(150)))...</div>
            </div>
            """
        }
        
        let indexHTML = """
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
        
        try indexHTML.write(to: indexPath, atomically: true, encoding: .utf8)
    }
    
    private func generatePostPages() throws {
        guard let siteDirectory = siteDirectory else { throw SiteGeneratorError.noSiteDirectory }
        
        let sortedPosts = blog.posts.sorted { $0.createdAt > $1.createdAt }
        
        for post in sortedPosts {
            let postDirectory = siteDirectory.appendingPathComponent(post.urlPath)
            
            // Make sure the post directory exists
            try fileManager.createDirectory(at: postDirectory, withIntermediateDirectories: true)
            
            let postPath = postDirectory.appendingPathComponent("index.html")
            
            let formattedContent = formatMarkdown(post.content)
            
            var primaryLinkHTML = ""
            if let primaryLink = post.primaryLink {
                primaryLinkHTML = """
                <div class="primary-link">
                    <a href="\(primaryLink)" target="_blank">Link: \(primaryLink)</a>
                </div>
                """
            }
            
            let postHTML = """
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
                            </ul>
                        </nav>
                    </header>
                    
                    <main>
                        <article class="post">
                            <h1 class="post-title">\(post.title ?? "")</h1>
                            <div class="post-date">\(post.formattedDate)</div>
                            \(primaryLinkHTML)
                            <div class="post-content">
                                \(formattedContent)
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
            
            try postHTML.write(to: postPath, atomically: true, encoding: .utf8)
        }
    }
    
    private func generateArchivePages() throws {
        guard let siteDirectory = siteDirectory else { throw SiteGeneratorError.noSiteDirectory }
        
        let archivesPath = siteDirectory.appendingPathComponent("archives.html")
        let sortedPosts = blog.posts.sorted { $0.createdAt > $1.createdAt }
        
        // Group posts by year and month
        var postsByYearMonth: [String: [Post]] = [:]
        
        for post in sortedPosts {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM"
            let yearMonth = dateFormatter.string(from: post.createdAt)
            
            if postsByYearMonth[yearMonth] == nil {
                postsByYearMonth[yearMonth] = []
            }
            
            postsByYearMonth[yearMonth]?.append(post)
        }
        
        // Sort year-months in descending order
        let sortedYearMonths = postsByYearMonth.keys.sorted(by: >)
        
        var archiveHTML = ""
        for yearMonth in sortedYearMonths {
            let components = yearMonth.components(separatedBy: "-")
            let year = components[0]
            let month = components[1]
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMMM yyyy"
            let date = dateFormatter.date(from: "\(month) \(year)") ?? Date()
            let monthYear = dateFormatter.string(from: date)
            
            archiveHTML += """
            <div class="archive-month">
                <h2>\(monthYear)</h2>
                <ul>
            """
            
            guard let posts = postsByYearMonth[yearMonth] else { continue }
            
            for post in posts {
                archiveHTML += """
                    <li>
                        <span class="post-date">\(post.formattedDate)</span>
                        <a href="/\(post.urlPath)/index.html">\(post.displayTitle)</a>
                    </li>
                """
            }
            
            archiveHTML += """
                </ul>
            </div>
            """
            
            // Create individual month archive pages
            let yearPath = siteDirectory.appendingPathComponent(year)
            
            // Ensure the year directory exists
            if !fileManager.fileExists(atPath: yearPath.path) {
                try fileManager.createDirectory(at: yearPath, withIntermediateDirectories: true)
            }
            
            let monthArchivePath = yearPath.appendingPathComponent("\(month).html")
            
            let monthArchiveHTML = """
            <!DOCTYPE html>
            <html lang="en">
            <head>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <title>Archive: \(monthYear) - \(blog.name)</title>
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
                            </ul>
                        </nav>
                    </header>
                    
                    <main>
                        <h1>Archive: \(monthYear)</h1>
                        <div class="archive-month">
                            <ul>
            """
            
            var monthPageContent = monthArchiveHTML
            
            for post in posts {
                monthPageContent += """
                                <li>
                                    <span class="post-date">\(post.formattedDate)</span>
                                    <a href="/\(post.urlPath)/index.html">\(post.displayTitle)</a>
                                </li>
                """
            }
            
            monthPageContent += """
                            </ul>
                        </div>
                    </main>
                    
                    <footer>
                        <p>&copy; \(Calendar.current.component(.year, from: Date())) \(blog.name). Generated with Postalgic.</p>
                    </footer>
                </div>
            </body>
            </html>
            """
            
            try monthPageContent.write(to: monthArchivePath, atomically: true, encoding: .utf8)
        }
        
        let fullArchiveHTML = """
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
                        </ul>
                    </nav>
                </header>
                
                <main>
                    <h1>Archives</h1>
                    \(archiveHTML)
                </main>
                
                <footer>
                    <p>&copy; \(Calendar.current.component(.year, from: Date())) \(blog.name). Generated with Postalgic.</p>
                </footer>
            </div>
        </body>
        </html>
        """
        
        try fullArchiveHTML.write(to: archivesPath, atomically: true, encoding: .utf8)
    }
    
    private func generateCSS() throws {
        guard let siteDirectory = siteDirectory else { throw SiteGeneratorError.noSiteDirectory }
        
        let cssDirectory = siteDirectory.appendingPathComponent("css")
        
        // Ensure the CSS directory exists
        if !fileManager.fileExists(atPath: cssDirectory.path) {
            try fileManager.createDirectory(at: cssDirectory, withIntermediateDirectories: true)
        }
        
        let cssPath = cssDirectory.appendingPathComponent("style.css")
        
        let css = """
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

        /* Header */
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
        }

        nav ul li {
            margin-right: 20px;
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

        /* Post */
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

        /* Archives */
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

        .archive-month a {
            text-decoration: none;
            color: #333;
        }

        .archive-month a:hover {
            text-decoration: underline;
        }

        /* Footer */
        footer {
            padding-top: 20px;
            border-top: 1px solid #eee;
            color: #666;
            font-size: 0.9em;
        }

        /* Responsive */
        @media (max-width: 768px) {
            .container {
                padding: 15px;
            }
            
            .archive-month li {
                flex-direction: column;
            }
            
            .archive-month .post-date {
                margin-bottom: 5px;
            }
        }
        """
        
        try css.write(to: cssPath, atomically: true, encoding: .utf8)
    }
    
    private func formatMarkdown(_ content: String) -> String {
        // This is a very simple Markdown formatter
        // You would want to use a proper Markdown library in a real app
        var html = content
        
        // Replace line breaks with <br>
        html = html.replacingOccurrences(of: "\n", with: "<br>")
        
        // Bold
        let boldRegex = try! NSRegularExpression(pattern: "\\*\\*(.*?)\\*\\*", options: [])
        html = boldRegex.stringByReplacingMatches(in: html, options: [], range: NSRange(location: 0, length: html.utf16.count), withTemplate: "<strong>$1</strong>")
        
        // Italic
        let italicRegex = try! NSRegularExpression(pattern: "\\*(.*?)\\*", options: [])
        html = italicRegex.stringByReplacingMatches(in: html, options: [], range: NSRange(location: 0, length: html.utf16.count), withTemplate: "<em>$1</em>")
        
        // Links (simple format: [text](url))
        let linkRegex = try! NSRegularExpression(pattern: "\\[(.*?)\\]\\((.*?)\\)", options: [])
        html = linkRegex.stringByReplacingMatches(in: html, options: [], range: NSRange(location: 0, length: html.utf16.count), withTemplate: "<a href=\"$2\">$1</a>")
        
        return html
    }
    
    private func zipSite(to zipURL: URL) throws {
        guard let siteDirectory = siteDirectory else { throw SiteGeneratorError.noSiteDirectory }
        
        try fileManager.zipItem(at: siteDirectory, to: zipURL)
    }
    
    enum SiteGeneratorError: Error {
        case noSiteDirectory
        case missingAWSCredentials
        case awsUploadFailed(String)
        case awsInvalidationFailed(String)
    }
}
