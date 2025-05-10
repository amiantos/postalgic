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
    
    // MARK: - Template Management
    
    /// Registers a custom template, overriding the default one
    /// - Parameters:
    ///   - template: The template content
    ///   - type: The template type identifier
    func registerCustomTemplate(_ template: String, for type: String) {
        templateManager.registerCustomTemplate(template, for: type)
    }
    
    /// Gets the template string for a specific template type
    /// - Parameter type: The template type
    /// - Returns: The template string
    /// - Throws: Error if the template doesn't exist
    func getTemplateString(for type: String) throws -> String {
        return try templateManager.getTemplateString(for: type)
    }
    
    /// Returns all available template types
    /// - Returns: Array of template type identifiers
    func availableTemplateTypes() -> [String] {
        return templateManager.availableTemplateTypes()
    }
    
    // MARK: - Shared Context Properties
    
    /// Creates the base context with shared properties for all templates
    private func createBaseContext() -> [String: Any] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        var context: [String: Any] = [
            "blogName": blog.name,
            "blogUrl": blog.url,
            "currentYear": Calendar.current.component(.year, from: Date()),
            "buildDate": formatter.string(from: Date())
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
        context["customHead"] = customHead
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
    
    /// Renders the index page with a list of posts
    /// - Parameter posts: The posts to display on the index page
    /// - Returns: The rendered HTML
    /// - Throws: Error if rendering fails
    func renderIndexPage(posts: [Post]) throws -> String {
        let indexTemplate = try templateManager.getTemplate(for: "index")
        
        var context = createBaseContext()
        context["posts"] = posts.map { TemplateDataConverter.convert(post: $0, blog: blog) }
        
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

        let escapedTitle = displayTitle
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")

        // Get the full URL for the post
        let postUrl = "\(blog.url)/\(post.urlPath)"

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
        <meta property="twitter:card" content="summary_large_image">
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
        return try renderLayout(content: content, pageTitle: "Archives - \(blog.name)")
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
        return try renderLayout(content: content, pageTitle: "Tags - \(blog.name)")
    }
    
    /// Renders a single tag page
    /// - Parameters:
    ///   - tag: The tag to display
    ///   - posts: The posts with this tag
    /// - Returns: The rendered HTML
    /// - Throws: Error if rendering fails
    func renderTagPage(tag: Tag, posts: [Post]) throws -> String {
        let tagTemplate = try templateManager.getTemplate(for: "tag")
        
        var context = createBaseContext()
        // Add tag data
        let tagData = TemplateDataConverter.convert(tag: tag, posts: posts)
        for (key, value) in tagData {
            context[key] = value
        }
        
        // Add additional context
        context["tagName"] = tag.name
        context["postCountText"] = posts.count == 1 ? "post" : "posts"
        context["posts"] = posts.map { TemplateDataConverter.convert(post: $0, blog: blog) }
        
        let content = tagTemplate.render(context, library: templateManager.getLibrary())
        return try renderLayout(content: content, pageTitle: "Tag: \(tag.name) - \(blog.name)")
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
        return try renderLayout(content: content, pageTitle: "Categories - \(blog.name)")
    }
    
    /// Renders a single category page
    /// - Parameters:
    ///   - category: The category to display
    ///   - posts: The posts in this category
    /// - Returns: The rendered HTML
    /// - Throws: Error if rendering fails
    func renderCategoryPage(category: Category, posts: [Post]) throws -> String {
        let categoryTemplate = try templateManager.getTemplate(for: "category")
        
        var context = createBaseContext()
        
        // Add category data
        let categoryData = TemplateDataConverter.convert(category: category, posts: posts)
        for (key, value) in categoryData {
            context[key] = value
        }
        
        // Add additional context
        context["categoryName"] = category.name
        context["postCountText"] = posts.count == 1 ? "post" : "posts"
        context["posts"] = posts.map { TemplateDataConverter.convert(post: $0, blog: blog) }
        
        let content = categoryTemplate.render(context, library: templateManager.getLibrary())
        return try renderLayout(content: content, pageTitle: "Category: \(category.name) - \(blog.name)")
    }
    
    /// Renders the RSS feed
    /// - Parameter posts: The posts to include in the feed (usually limited to the most recent ones)
    /// - Returns: The rendered XML
    /// - Throws: Error if rendering fails
    func renderRSSFeed(posts: [Post]) throws -> String {
        let rssTemplate = try templateManager.getTemplate(for: "rss")
        
        var context = createBaseContext()
        context["posts"] = posts.map { TemplateDataConverter.convert(post: $0, blog: blog) }
        
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
    /// - Returns: The rendered XML
    /// - Throws: Error if rendering fails
    func renderSitemap(posts: [Post], tags: [Tag], categories: [Category]) throws -> String {
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
        
        return sitemapTemplate.render(context, library: templateManager.getLibrary())
    }
    
    /// Renders the CSS stylesheet
    /// - Returns: The CSS content
    /// - Throws: Error if rendering fails
    func renderCSS() throws -> String {
        return try templateManager.getTemplateString(for: "css")
    }
}
