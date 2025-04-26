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
        self.templateManager = templateManager ?? TemplateManager()
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
        return [
            "blogName": blog.name,
            "blogUrl": blog.url,
            "blogTagline": blog.tagline,
            "blogAuthor": blog.authorName,
            "blogAuthorUrl": blog.authorUrl,
            "currentYear": Calendar.current.component(.year, from: Date()),
            "buildDate": ISO8601DateFormatter().string(from: Date())
        ]
    }
    
    // MARK: - Render Methods
    
    /// Renders the layout template with given content and title
    /// - Parameters:
    ///   - content: The HTML content to include in the layout
    ///   - pageTitle: The title for the page
    ///   - customHead: Optional custom HTML to include in the head section
    /// - Returns: The complete HTML page
    /// - Throws: Error if rendering fails
    func renderLayout(content: String, pageTitle: String, customHead: String = "") throws -> String {
        let layoutTemplate = try templateManager.getTemplate(for: "layout")
        
        var context = createBaseContext()
        context["content"] = content
        context["pageTitle"] = pageTitle
        context["customHead"] = customHead
        
        return layoutTemplate.render(context)
    }
    
    /// Renders the index page with a list of posts
    /// - Parameter posts: The posts to display on the index page
    /// - Returns: The rendered HTML
    /// - Throws: Error if rendering fails
    func renderIndexPage(posts: [Post]) throws -> String {
        let indexTemplate = try templateManager.getTemplate(for: "index")
        
        var context = createBaseContext()
        context["posts"] = posts.map { TemplateDataConverter.convert(post: $0, blog: blog) }
        
        let content = indexTemplate.render(context)
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
        let postData = TemplateDataConverter.convert(post: post, blog: blog)
        context["displayTitle"] = postData.displayTitle
        context["hasTitle"] = postData.hasTitle
        context["formattedDate"] = postData.formattedDate
        context["urlPath"] = postData.urlPath
        context["contentHtml"] = postData.contentHtml
        context["hasTags"] = postData.hasTags
        context["tags"] = postData.tags
        context["hasCategory"] = postData.hasCategory
        context["categoryName"] = postData.categoryName
        context["categoryUrlPath"] = postData.categoryUrlPath
        context["blogAuthor"] = postData.blogAuthor
        context["blogAuthorUrl"] = postData.blogAuthorUrl
        
        let content = postTemplate.render(context)
        
        let pageTitle = postData.hasTitle 
            ? "\(postData.displayTitle) - \(blog.name)" 
            : "\(postData.formattedDate) - \(blog.name)"
        
        return try renderLayout(content: content, pageTitle: pageTitle)
    }
    
    /// Renders the archives page
    /// - Parameter posts: The posts to include in the archives
    /// - Returns: The rendered HTML
    /// - Throws: Error if rendering fails
    func renderArchivesPage(posts: [Post]) throws -> String {
        let archivesTemplate = try templateManager.getTemplate(for: "archives")
        
        var context = createBaseContext()
        context["years"] = TemplateDataConverter.createArchiveData(from: posts)
        
        let content = archivesTemplate.render(context)
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
        
        let content = tagsTemplate.render(context)
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
        context["tagName"] = tag.name
        context["postCount"] = posts.count
        context["postCountText"] = posts.count == 1 ? "post" : "posts"
        context["posts"] = posts.map { TemplateDataConverter.convert(post: $0, blog: blog) }
        
        let content = tagTemplate.render(context)
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
        
        let content = categoriesTemplate.render(context)
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
        context["categoryName"] = category.name
        context["hasDescription"] = category.categoryDescription?.isEmpty == false
        context["description"] = category.categoryDescription
        context["postCount"] = posts.count
        context["postCountText"] = posts.count == 1 ? "post" : "posts"
        context["posts"] = posts.map { TemplateDataConverter.convert(post: $0, blog: blog) }
        
        let content = categoryTemplate.render(context)
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
        
        return rssTemplate.render(context)
    }
    
    /// Renders the robots.txt file
    /// - Returns: The rendered text
    /// - Throws: Error if rendering fails
    func renderRobotsTxt() throws -> String {
        let robotsTemplate = try templateManager.getTemplate(for: "robots")
        return robotsTemplate.render(createBaseContext())
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
        context["tags"] = tags.map { tag in
            let formatter = ISO8601DateFormatter()
            return [
                "name": tag.name,
                "urlPath": tag.name.urlPathFormatted(),
                "lastmod": formatter.string(from: Date())
            ]
        }
        
        // Convert categories
        context["categories"] = categories.map { category in
            let formatter = ISO8601DateFormatter()
            return [
                "name": category.name,
                "urlPath": category.name.urlPathFormatted(),
                "lastmod": formatter.string(from: Date())
            ]
        }
        
        return sitemapTemplate.render(context)
    }
    
    /// Renders the CSS stylesheet
    /// - Returns: The CSS content
    /// - Throws: Error if rendering fails
    func renderCSS() throws -> String {
        return try templateManager.getTemplateString(for: "css")
    }
}