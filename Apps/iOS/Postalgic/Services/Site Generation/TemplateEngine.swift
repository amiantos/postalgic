//
//  TemplateEngine.swift
//  Postalgic
//
//  Created by Brad Root on 4/26/25.
//

import Foundation
import Mustache
import Ink

/// A templating engine that uses Mustache to render HTML templates
class TemplateEngine {
    private let templateManager: TemplateManager
    private let markdownParser: MarkdownParser
    private let blog: Blog
    
    /// Initializes a new template engine
    /// - Parameters:
    ///   - blog: The blog model to use for rendering
    ///   - templateManager: The template manager to use (creates a new one if not provided)
    init(blog: Blog, templateManager: TemplateManager? = nil) {
        self.blog = blog
        self.templateManager = templateManager ?? TemplateManager(blog: blog)
        self.markdownParser = MarkdownParser()
    }
    
    
    // MARK: - Shared Context Properties
    
    /// Creates the base context with shared properties for all templates
    private func createBaseContext() -> [String: Any] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        // Check if there are any published posts with tags or categories
        let publishedPosts = blog.posts.filter { !$0.isDraft }
        let hasTags = !Set(publishedPosts.flatMap { $0.tags }).isEmpty
        let hasCategories = !Set(publishedPosts.compactMap { $0.category }).isEmpty

        // Check if social share image exists
        let hasSocialShareImage = blog.socialShareImage != nil

        var context: [String: Any] = [
            "blogName": blog.name,
            "blogUrl": blog.url,
            "currentYear": Calendar.current.component(.year, from: Date()),
            "buildDate": formatter.string(from: Date()),
            "accentColor": blog.accentColor ?? "#FFA100",
            "backgroundColor": blog.backgroundColor ?? "#efefef",
            "textColor": blog.textColor ?? "#2d3748",
            "lightShade": blog.lightShade ?? "#dedede",
            "mediumShade": blog.mediumShade ?? "#a0aec0",
            "darkShade": blog.darkShade ?? "#4a5568",
            "hasTags": hasTags,
            "hasCategories": hasCategories,
            "hasSocialShareImage": hasSocialShareImage
        ]

        // Add optional values only if they exist
        if let tagline = blog.tagline {
            context["blogTagline"] = tagline
        }

        if let authorName = blog.authorName {
            context["blogAuthor"] = authorName
        }

        if let authorUrl = blog.authorUrl {
            context["blogAuthorUrl"] = authorUrl
        }

        return context
    }
    
    // MARK: - Render Methods
    
    /// Renders the layout template with given content and title
    /// - Parameters:
    ///   - content: The HTML content to include in the layout
    ///   - pageTitle: The title for the page
    ///   - customHead: Optional custom HTML to include in the head section
    ///   - hasCustomMeta: Indicates if the page has custom meta tags
    /// - Returns: The complete HTML page
    /// - Throws: Error if rendering fails
    func renderLayout(content: String, pageTitle: String, customHead: String = "", hasCustomMeta: Bool = false) throws -> String {
        let layoutTemplate = try templateManager.getTemplate(for: "layout")

        var context = createBaseContext()
        context["content"] = content
        context["pageTitle"] = pageTitle
        
        // Generate custom head with static file meta tags
        let staticFileHead = generateStaticFilesHead()
        let combinedHead = staticFileHead + (customHead.isEmpty ? "" : "\n" + customHead)
        context["customHead"] = combinedHead
        context["hasCustomMeta"] = hasCustomMeta

        // Generate sidebar content
        let sidebarContent = generateSidebarContent()
        context["sidebarContent"] = sidebarContent

        return layoutTemplate.render(context, library: templateManager.getLibrary())
    }
    
    /// Generates the HTML content for the sidebar based on the blog's sidebar objects
    /// - Returns: HTML content for the sidebar
    private func generateSidebarContent() -> String {
        // Sort sidebar objects by order
        let sortedObjects = blog.sidebarObjects.sorted { $0.order < $1.order }
        var sidebarHtml = ""
        
        for object in sortedObjects {
            sidebarHtml += object.generateHtml()
        }
        
        return sidebarHtml
    }
    
    /// Generates HTML head content for static files (favicon and social share image)
    /// - Returns: HTML meta tags for special static files
    private func generateStaticFilesHead() -> String {
        var headContent = "<meta name=\"apple-mobile-web-app-title\" content=\"\(blog.name)\"/>"

        // Always add favicon links for cross-platform consistency
        // These may point to default favicons if no custom one is set
        if let favicon = blog.favicon, !favicon.isImage {
            // For ICO files, use the original file
            headContent += "<link rel=\"icon\" href=\"/\(favicon.filename)\" type=\"\(favicon.mimeType)\" sizes=\"any\">"
        } else {
            // Generate multiple favicon link tags for different sizes (matches self-hosted)
            headContent += "<link rel=\"icon\" href=\"/favicon-32x32.png\" sizes=\"32x32\" type=\"image/png\">"
            headContent += "\n<link rel=\"icon\" href=\"/favicon-192x192.png\" sizes=\"192x192\" type=\"image/png\">"
            headContent += "\n<link rel=\"apple-touch-icon\" href=\"/apple-touch-icon.png\" sizes=\"180x180\">"
        }

        // Add social share image meta tags if it exists
        if let socialShareImage = blog.socialShareImage {
            headContent += "\n"
            headContent += "<meta property=\"og:image\" content=\"\(blog.url.hasSuffix("/") ? blog.url : blog.url + "/")\(socialShareImage.filename)\">"
            headContent += "\n<meta name=\"twitter:image\" content=\"\(blog.url.hasSuffix("/") ? blog.url : blog.url + "/")\(socialShareImage.filename)\">"
        }

        return headContent
    }
    
    /// Renders the index page with a list of posts
    /// - Parameters:
    ///   - posts: The posts to display on the index page
    ///   - hasMorePosts: Whether there are more posts available (to show archives link)
    /// - Returns: The rendered HTML
    /// - Throws: Error if rendering fails
    func renderIndexPage(posts: [Post], hasMorePosts: Bool = false) throws -> String {
        let indexTemplate = try templateManager.getTemplate(for: "index")
        
        var context = createBaseContext()
        context["posts"] = posts.map { TemplateDataConverter.convert(post: $0, blog: blog) }
        context["hasMorePosts"] = hasMorePosts
        
        // Add most recent month's archive URL
        if hasMorePosts {
            let publishedPosts = blog.posts.filter { !$0.isDraft }.sorted { $0.createdAt > $1.createdAt }
            if let mostRecentPost = publishedPosts.first {
                let calendar = Calendar.current
                let year = calendar.component(.year, from: mostRecentPost.createdAt)
                let month = calendar.component(.month, from: mostRecentPost.createdAt)
                context["recentArchiveUrl"] = "/\(String(format: "%04d", year))/\(String(format: "%02d", month))/"
            }
        }
        
        let content = indexTemplate.render(context, library: templateManager.getLibrary())
        return try renderLayout(
            content: content,
            pageTitle: blog.name,
            customHead: "<link rel=\"sitemap\" type=\"application/xml\" title=\"Sitemap\" href=\"/sitemap.xml\" />"
        )
    }
    
    /// Renders a single post page
    /// - Parameter post: The post to render
    /// - Returns: The rendered HTML
    /// - Throws: Error if rendering fails
    func renderPostPage(post: Post) throws -> String {
        let postTemplate = try templateManager.getTemplate(for: "post")

        var context = createBaseContext()
        let postData = TemplateDataConverter.convert(post: post, blog: blog, inList: false)

        // Merge the post data into the context
        for (key, value) in postData {
            context[key] = value
        }

        let content = postTemplate.render(context, library: templateManager.getLibrary())

        // Use the displayTitle for the page title, which already handles fallback logic
        let displayTitle = post.displayTitle

        // Always use displayTitle for the page title
        let pageTitle = "\(displayTitle) - \(blog.name)"

        // Create a post-specific meta description
        let plainContent = post.plainContent
        let metaDescription = plainContent.count > 160
            ? String(plainContent.prefix(157)) + "..."
            : plainContent

        // Clean the content and title for safe HTML use
        let escapedDescription = metaDescription
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")

        // Create a properly formatted title with blog name
        let fullTitle = "\(displayTitle) - \(blog.name)"
        let escapedTitle = fullTitle
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")

        // Get the full URL for the post
        let postUrl = "\(blog.url)/\(post.urlPath)"

        // Determine twitter card type based on social share image
        let twitterCardType = blog.socialShareImage != nil ? "summary_large_image" : "summary"

        // Create comprehensive meta tags for SEO and social sharing
        let customHead = """
        <!-- Primary Meta Tags -->
        <meta name="description" content="\(escapedDescription)">

        <!-- Open Graph / Facebook -->
        <meta property="og:type" content="article">
        <meta property="og:url" content="\(postUrl)">
        <meta property="og:title" content="\(escapedTitle)">
        <meta property="og:description" content="\(escapedDescription)">

        <!-- Twitter -->
        <meta property="twitter:card" content="\(twitterCardType)">
        <meta property="twitter:url" content="\(postUrl)">
        <meta property="twitter:title" content="\(escapedTitle)">
        <meta property="twitter:description" content="\(escapedDescription)">
        """

        return try renderLayout(content: content, pageTitle: pageTitle, customHead: customHead, hasCustomMeta: true)
    }
    
    /// Renders the archives page
    /// - Parameter posts: The posts to include in the archives
    /// - Returns: The rendered HTML
    /// - Throws: Error if rendering fails
    func renderArchivesPage(posts: [Post]) throws -> String {
        let archivesTemplate = try templateManager.getTemplate(for: "archives")
        
        var context = createBaseContext()
        context["years"] = TemplateDataConverter.createArchiveData(from: posts)
        
        let content = archivesTemplate.render(context, library: templateManager.getLibrary())
        return try renderLayout(
            content: content,
            pageTitle: "Archives - \(blog.name)",
            customHead: "<link rel=\"sitemap\" type=\"application/xml\" title=\"Sitemap\" href=\"/sitemap.xml\" />"
        )
    }
    
    /// Renders a monthly archive page
    /// - Parameters:
    ///   - year: The year for this archive
    ///   - month: The month for this archive
    ///   - posts: The posts to include in this monthly archive
    ///   - previousMonth: Previous month navigation info (year, month)
    ///   - nextMonth: Next month navigation info (year, month)
    /// - Returns: The rendered HTML
    /// - Throws: Error if rendering fails
    func renderMonthlyArchivePage(year: Int, month: Int, posts: [Post], previousMonth: (year: Int, month: Int)?, nextMonth: (year: Int, month: Int)?) throws -> String {
        let monthlyArchiveTemplate = try templateManager.getTemplate(for: "monthly-archive")
        
        var context = createBaseContext()
        
        // Add month/year info
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM"
        let monthName = dateFormatter.monthSymbols[month - 1]
        
        context["year"] = year
        context["month"] = month
        context["monthName"] = monthName
        context["postCount"] = posts.count
        context["postCountText"] = posts.count == 1 ? "post" : "posts"
        
        // Add posts
        context["posts"] = posts.map { TemplateDataConverter.convert(post: $0, blog: blog) }
        
        // Add navigation
        context["hasPreviousMonth"] = previousMonth != nil
        context["hasNextMonth"] = nextMonth != nil
        
        if let prev = previousMonth {
            let prevMonthName = dateFormatter.monthSymbols[prev.month - 1]
            context["previousMonthUrl"] = "/\(String(format: "%04d", prev.year))/\(String(format: "%02d", prev.month))/"
            context["previousMonthName"] = prevMonthName
            context["previousYear"] = prev.year
        }
        
        if let next = nextMonth {
            let nextMonthName = dateFormatter.monthSymbols[next.month - 1]
            context["nextMonthUrl"] = "/\(String(format: "%04d", next.year))/\(String(format: "%02d", next.month))/"
            context["nextMonthName"] = nextMonthName
            context["nextYear"] = next.year
        }
        
        let content = monthlyArchiveTemplate.render(context, library: templateManager.getLibrary())
        return try renderLayout(
            content: content,
            pageTitle: "\(monthName) \(year) - \(blog.name)",
            customHead: "<link rel=\"sitemap\" type=\"application/xml\" title=\"Sitemap\" href=\"/sitemap.xml\" />"
        )
    }
    
    /// Renders the tags index page
    /// - Parameter tags: The tags to include, with corresponding posts
    /// - Returns: The rendered HTML
    /// - Throws: Error if rendering fails
    func renderTagsPage(tags: [(Tag, [Post])]) throws -> String {
        let tagsTemplate = try templateManager.getTemplate(for: "tags")
        
        var context = createBaseContext()
        context["tags"] = tags.map { tag, posts in
            return TemplateDataConverter.convert(tag: tag, posts: posts)
        }
        
        let content = tagsTemplate.render(context, library: templateManager.getLibrary())
        return try renderLayout(
            content: content,
            pageTitle: "Tags - \(blog.name)",
            customHead: "<link rel=\"sitemap\" type=\"application/xml\" title=\"Sitemap\" href=\"/sitemap.xml\" />"
        )
    }
    
    /// Renders a single tag page
    /// - Parameters:
    ///   - tag: The tag to display
    ///   - posts: The posts with this tag
    ///   - currentPage: The current page number (default: 1)
    ///   - totalPages: The total number of pages (default: 1)
    ///   - totalPosts: The total number of posts (default: posts.count)
    /// - Returns: The rendered HTML
    /// - Throws: Error if rendering fails
    func renderTagPage(tag: Tag, posts: [Post], currentPage: Int = 1, totalPages: Int = 1, totalPosts: Int? = nil) throws -> String {
        let tagTemplate = try templateManager.getTemplate(for: "tag")
        
        var context = createBaseContext()
        // Add tag data
        let tagData = TemplateDataConverter.convert(tag: tag, posts: Array(posts))
        for (key, value) in tagData {
            context[key] = value
        }
        
        let actualTotalPosts = totalPosts ?? posts.count
        
        // Add additional context
        context["tagName"] = tag.name
        context["postCountText"] = actualTotalPosts == 1 ? "post" : "posts"
        context["posts"] = posts.map { TemplateDataConverter.convert(post: $0, blog: blog) }
        
        // Add pagination context
        context["currentPage"] = currentPage
        context["totalPages"] = totalPages
        context["totalPosts"] = actualTotalPosts
        context["hasPagination"] = totalPages > 1
        context["hasPreviousPage"] = currentPage > 1
        context["hasNextPage"] = currentPage < totalPages
        
        if currentPage > 1 {
            context["previousPageUrl"] = currentPage == 2 ? "/tags/\(tag.urlPath)/" : "/tags/\(tag.urlPath)/page/\(currentPage - 1)/"
        }
        
        if currentPage < totalPages {
            context["nextPageUrl"] = "/tags/\(tag.urlPath)/page/\(currentPage + 1)/"
        }
        
        let content = tagTemplate.render(context, library: templateManager.getLibrary())
        let pageTitle = currentPage == 1 ? "Tag: \(tag.name) - \(blog.name)" : "Tag: \(tag.name) (Page \(currentPage)) - \(blog.name)"
        return try renderLayout(content: content, pageTitle: pageTitle)
    }
    
    /// Renders the categories index page
    /// - Parameter categories: The categories to include, with corresponding posts
    /// - Returns: The rendered HTML
    /// - Throws: Error if rendering fails
    func renderCategoriesPage(categories: [(Category, [Post])]) throws -> String {
        let categoriesTemplate = try templateManager.getTemplate(for: "categories")
        
        var context = createBaseContext()
        context["categories"] = categories.map { category, posts in
            return TemplateDataConverter.convert(category: category, posts: posts)
        }
        
        let content = categoriesTemplate.render(context, library: templateManager.getLibrary())
        return try renderLayout(
            content: content,
            pageTitle: "Categories - \(blog.name)",
            customHead: "<link rel=\"sitemap\" type=\"application/xml\" title=\"Sitemap\" href=\"/sitemap.xml\" />"
        )
    }
    
    /// Renders a single category page
    /// - Parameters:
    ///   - category: The category to display
    ///   - posts: The posts in this category
    ///   - currentPage: The current page number (default: 1)
    ///   - totalPages: The total number of pages (default: 1)
    ///   - totalPosts: The total number of posts (default: posts.count)
    /// - Returns: The rendered HTML
    /// - Throws: Error if rendering fails
    func renderCategoryPage(category: Category, posts: [Post], currentPage: Int = 1, totalPages: Int = 1, totalPosts: Int? = nil) throws -> String {
        let categoryTemplate = try templateManager.getTemplate(for: "category")
        
        var context = createBaseContext()
        
        // Add category data
        let categoryData = TemplateDataConverter.convert(category: category, posts: Array(posts))
        for (key, value) in categoryData {
            context[key] = value
        }
        
        let actualTotalPosts = totalPosts ?? posts.count
        
        // Add additional context
        context["categoryName"] = category.name
        context["postCountText"] = actualTotalPosts == 1 ? "post" : "posts"
        context["posts"] = posts.map { TemplateDataConverter.convert(post: $0, blog: blog) }
        
        // Add pagination context
        context["currentPage"] = currentPage
        context["totalPages"] = totalPages
        context["totalPosts"] = actualTotalPosts
        context["hasPagination"] = totalPages > 1
        context["hasPreviousPage"] = currentPage > 1
        context["hasNextPage"] = currentPage < totalPages
        
        if currentPage > 1 {
            context["previousPageUrl"] = currentPage == 2 ? "/categories/\(category.urlPath)/" : "/categories/\(category.urlPath)/page/\(currentPage - 1)/"
        }
        
        if currentPage < totalPages {
            context["nextPageUrl"] = "/categories/\(category.urlPath)/page/\(currentPage + 1)/"
        }
        
        let content = categoryTemplate.render(context, library: templateManager.getLibrary())
        let pageTitle = currentPage == 1 ? "Category: \(category.name) - \(blog.name)" : "Category: \(category.name) (Page \(currentPage)) - \(blog.name)"
        return try renderLayout(content: content, pageTitle: pageTitle)
    }
    
    /// Renders the RSS feed
    /// - Parameter posts: The posts to include in the feed (usually limited to the most recent ones)
    /// - Returns: The rendered XML
    /// - Throws: Error if rendering fails
    func renderRSSFeed(posts: [Post]) throws -> String {
        let rssTemplate = try templateManager.getTemplate(for: "rss")
        
        var context = createBaseContext()
        context["posts"] = posts.map { TemplateDataConverter.convertForRSS(post: $0, blog: blog) }
        
        return rssTemplate.render(context, library: templateManager.getLibrary())
    }
    
    /// Renders the robots.txt file
    /// - Returns: The rendered text
    /// - Throws: Error if rendering fails
    func renderRobotsTxt() throws -> String {
        let robotsTemplate = try templateManager.getTemplate(for: "robots")
        return robotsTemplate.render(createBaseContext(), library: templateManager.getLibrary())
    }
    
    /// Renders the sitemap.xml file
    /// - Parameters:
    ///   - posts: All published posts
    ///   - tags: All tags used in published posts
    ///   - categories: All categories used in published posts
    ///   - monthlyArchives: All monthly archive year/month combinations
    /// - Returns: The rendered XML
    /// - Throws: Error if rendering fails
    func renderSitemap(posts: [Post], tags: [Tag], categories: [Category], monthlyArchives: [(year: Int, month: Int)] = []) throws -> String {
        let sitemapTemplate = try templateManager.getTemplate(for: "sitemap")
        
        var context = createBaseContext()
        context["posts"] = posts.map { TemplateDataConverter.convert(post: $0, blog: blog) }
        
        // Convert tags
        context["tags"] = tags.map { tag -> [String: Any] in
            // Create dummy TagTemplateData
            let emptyPosts: [Post] = []
            return TemplateDataConverter.convert(tag: tag, posts: emptyPosts)
        }
        
        // Convert categories
        context["categories"] = categories.map { category -> [String: Any] in
            // Create dummy CategoryTemplateData
            let emptyPosts: [Post] = []
            return TemplateDataConverter.convert(category: category, posts: emptyPosts)
        }
        
        // Add monthly archives
        let formatter = ISO8601DateFormatter()
        context["monthlyArchives"] = monthlyArchives.map { yearMonth in
            return [
                "url": "/\(String(format: "%04d", yearMonth.year))/\(String(format: "%02d", yearMonth.month))/",
                "lastmod": formatter.string(from: Date())
            ]
        }
        
        return sitemapTemplate.render(context, library: templateManager.getLibrary())
    }
    
    /// Renders the CSS stylesheet
    /// - Returns: The CSS content
    /// - Throws: Error if rendering fails
    func renderCSS() throws -> String {
        let cssTemplate = try templateManager.getTemplate(for: "css")
        let context = createBaseContext()
        let rendered = cssTemplate.render(context, library: templateManager.getLibrary())
        // Strip trailing whitespace from each line to match self-hosted output
        return rendered.split(separator: "\n", omittingEmptySubsequences: false)
            .map { line in
                var s = String(line)
                while s.hasSuffix(" ") || s.hasSuffix("\t") {
                    s.removeLast()
                }
                return s
            }
            .joined(separator: "\n")
    }
}
