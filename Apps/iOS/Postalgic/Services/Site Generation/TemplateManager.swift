//
//  TemplateManager.swift
//  Postalgic
//
//  Created by Brad Root on 4/26/25.
//

import Foundation
import Mustache

/// Manages and provides access to Mustache templates for the static site generator
class TemplateManager {
    // Default templates
    private var defaultTemplates = [String: String]()
    
    // Compiled templates
    private var compiledTemplates = [String: MustacheTemplate]()
    
    // Reference to the blog
    private let blog: Blog
    
    // MARK: - Initialization
    
    init(blog: Blog) {
        self.blog = blog
        setupDefaultTemplates()
    }
    
    // MARK: - Template Setup
    
    /// Sets up the default templates
    private func setupDefaultTemplates() {
        // Main layout template
        defaultTemplates["layout"] = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>{{pageTitle}}</title>
            <meta name="description" content="{{#blogTagline}}{{blogTagline}}{{/blogTagline}}{{^blogTagline}}Posts from {{blogName}}{{/blogTagline}}">
            <link rel="stylesheet" href="/css/style.css">
            <link rel="alternate" type="application/rss+xml" title="{{blogName}} RSS Feed" href="/rss.xml">
            {{{customHead}}}
        </head>
        <body>
            <div class="container">
                <header>
                    <h1><a href="/">{{blogName}}</a></h1>
                    {{#blogTagline}}<p class="tagline">{{blogTagline}}</p>{{/blogTagline}}
                </header>
        
                <nav>
                    <ul>
                        <li><a href="/">Home</a></li>
                        <li><a href="/archives/">Archives</a></li>
                        <li><a href="/tags/">Tags</a></li>
                        <li><a href="/categories/">Categories</a></li>
                    </ul>
                </nav>
        
                <aside>
                    <h2>About</h2>
                    <div class="about-text">
                        My name is <b><a href="https://bradroot.me">Brad Root</a></b> and I'm an artist, software engineer, tech enthusiast, music aficionado, video game junkie, weird coffee person, and occasional unicyclist. Find out more about me at <a href="https://bradroot.me">my portfolio site</a>.
                    </div>
        
                    <h2>My Sites</h2>
                    <ul>
                        <li><a href="https://amiantos.net">amiantos.net</a></li>
                        <li><a href="https://bradroot.me">bradroot.me</a></li>
                        <li><a href="https://staires.org">staires.org</a></li>
                    </ul>
                </aside>
                
                <main>
                    {{{content}}}
                </main>
                
                <footer>
                    <p>&copy; {{currentYear}} {{blogName}}{{#blogAuthor}} by {{#blogAuthorUrl}}<a href="{{blogAuthorUrl}}">{{blogAuthor}}</a>{{/blogAuthorUrl}}{{^blogAuthorUrl}}{{blogAuthor}}{{/blogAuthorUrl}}{{/blogAuthor}}. Generated with <a href="https://postalgic.app">Postalgic</a>.</p>
                </footer>
            </div>
        </body>
        </html>
        """
        
        // Index page template
        defaultTemplates["index"] = """
        <div class="post-list">
            {{#posts}}
                <div class="post-item">
                    {{#hasTitle}}<h2>{{displayTitle}}</h2>{{/hasTitle}}
                    <div class="post-date"><a href="/{{urlPath}}/index.html">{{formattedDate}}</a></div>
                    {{#blogAuthor}}<div class="post-author"> by {{#blogAuthorUrl}}<a href="{{blogAuthorUrl}}">{{blogAuthor}}</a>{{/blogAuthorUrl}}{{^blogAuthorUrl}}{{blogAuthor}}{{/blogAuthorUrl}}</div>{{/blogAuthor}}
                    <div class="post-summary">{{{contentHtml}}}</div>
                    {{#hasCategory}}
                    <div class="post-category">
                        Category: <a href="/categories/{{categoryUrlPath}}/">{{categoryName}}</a>
                    </div>
                    {{/hasCategory}}
                    {{#hasTags}}
                    <div class="post-tags">
                        Tags: 
                        {{#tags}}
                            <a href="/tags/{{urlPath}}/" class="tag">{{name}}</a> 
                        {{/tags}}
                    </div>
                    {{/hasTags}}
                </div>
            {{/posts}}
        </div>
        """
        
        // Post template
        defaultTemplates["post"] = """
        <article>
            {{#hasTitle}}<h1>{{displayTitle}}</h1>{{/hasTitle}}
            <div class="post-meta">
                <div class="post-date"><a href="/{{urlPath}}/index.html">{{formattedDate}}</a></div>
                {{#blogAuthor}}<div class="post-author"> by {{#blogAuthorUrl}}<a href="{{blogAuthorUrl}}">{{blogAuthor}}</a>{{/blogAuthorUrl}}{{^blogAuthorUrl}}{{blogAuthor}}{{/blogAuthorUrl}}</div>{{/blogAuthor}}
            </div>
            <div class="post-content">
                {{{contentHtml}}}
            </div>
            <div class="post-meta">
                {{#hasCategory}}
                <div class="post-category">
                    Category: <a href="/categories/{{categoryUrlPath}}/">{{categoryName}}</a>
                </div>
                {{/hasCategory}}
                {{#hasTags}}
                <div class="post-tags">
                    Tags: 
                    {{#tags}}
                        <a href="/tags/{{urlPath}}/" class="tag">{{name}}</a> 
                    {{/tags}}
                </div>
                {{/hasTags}}
            </div>
        </article>
        """
        
        // Archives template
        defaultTemplates["archives"] = """
        <h1>Archives</h1>
        {{#years}}
            <div class="archive-year">{{year}}</div>
            {{#months}}
                <div class="archive-month">{{monthName}}</div>
                <ul>
                    {{#posts}}
                        <li>
                            <span class="archive-date">{{dayPadded}} {{monthName}}</span>
                            <a href="/{{urlPath}}/index.html">{{displayTitle}}</a>
                        </li>
                    {{/posts}}
                </ul>
            {{/months}}
        {{/years}}
        """
        
        // Tags list template
        defaultTemplates["tags"] = """
        <h1>All Tags</h1>
        <div class="tag-list">
            {{#tags}}
                <div class="tag-item">
                    <h2><a href="/tags/{{urlPath}}/">{{name}}</a> <span class="tag-count">({{postCount}})</span></h2>
                </div>
            {{/tags}}
        </div>
        """
        
        // Single tag template
        defaultTemplates["tag"] = """
        <h1>Posts tagged with "{{tagName}}"</h1>
        <p class="tag-meta">{{postCount}} {{postCountText}} with this tag</p>
        <div class="post-list">
            {{#posts}}
                <div class="post-item">
                    {{#hasTitle}}<h2>{{displayTitle}}</h2>{{/hasTitle}}
                    <div class="post-date"><a href="/{{urlPath}}/index.html">{{formattedDate}}</a></div>
                    {{#blogAuthor}}<div class="post-author"> by {{#blogAuthorUrl}}<a href="{{blogAuthorUrl}}">{{blogAuthor}}</a>{{/blogAuthorUrl}}{{^blogAuthorUrl}}{{blogAuthor}}{{/blogAuthorUrl}}</div>{{/blogAuthor}}
                    <div class="post-summary">{{{contentHtml}}}</div>
                    {{#hasCategory}}
                    <div class="post-category">
                        Category: <a href="/categories/{{categoryUrlPath}}/">{{categoryName}}</a>
                    </div>
                    {{/hasCategory}}
                    {{#hasTags}}
                    <div class="post-tags">
                        Tags: 
                        {{#tags}}
                            <a href="/tags/{{urlPath}}/" class="tag">{{name}}</a> 
                        {{/tags}}
                    </div>
                    {{/hasTags}}
                </div>
            {{/posts}}
        </div>
        """
        
        // Categories list template
        defaultTemplates["categories"] = """
        <h1>All Categories</h1>
        <div class="category-list">
            {{#categories}}
                <div class="category-item">
                    <h2><a href="/categories/{{urlPath}}/">{{name}}</a> <span class="category-count">({{postCount}})</span></h2>
                    {{#hasDescription}}<p class="category-description">{{description}}</p>{{/hasDescription}}
                </div>
            {{/categories}}
        </div>
        """
        
        // Single category template
        defaultTemplates["category"] = """
        <h1>Posts in category "{{categoryName}}"</h1>
        {{#hasDescription}}<p class="category-description">{{description}}</p>{{/hasDescription}}
        <p class="category-meta">{{postCount}} {{postCountText}} in this category</p>
        <div class="post-list">
            {{#posts}}
                <div class="post-item">
                    {{#hasTitle}}<h2>{{displayTitle}}</h2>{{/hasTitle}}
                    <div class="post-date"><a href="/{{urlPath}}/index.html">{{formattedDate}}</a></div>
                    {{#blogAuthor}}<div class="post-author"> by {{#blogAuthorUrl}}<a href="{{blogAuthorUrl}}">{{blogAuthor}}</a>{{/blogAuthorUrl}}{{^blogAuthorUrl}}{{blogAuthor}}{{/blogAuthorUrl}}</div>{{/blogAuthor}}
                    <div class="post-summary">{{{contentHtml}}}</div>
                    {{#hasCategory}}
                    <div class="post-category">
                        Category: <a href="/categories/{{categoryUrlPath}}/">{{categoryName}}</a>
                    </div>
                    {{/hasCategory}}
                    {{#hasTags}}
                    <div class="post-tags">
                        Tags: 
                        {{#tags}}
                            <a href="/tags/{{urlPath}}/" class="tag">{{name}}</a> 
                        {{/tags}}
                    </div>
                    {{/hasTags}}
                </div>
            {{/posts}}
        </div>
        """
        
        // Default CSS style
        defaultTemplates["css"] = """
        /* Base styles */
        
        /* Add styles for tagline and author info */
        header .tagline {
            color: var(--medium-gray);
            font-size: 1.1rem;
            margin-bottom: 15px;
            font-style: italic;
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
            max-width: 1000px;
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
            margin-bottom: 15px;
            border-bottom: 1px solid var(--light-gray);
        }

        header h1 {

        }

        header h1 a {
            color: var(--primary-color);
            text-decoration: none;
        }
        
        nav {
            border-bottom: 1px solid var(--light-gray);
            padding-bottom: 15px;
        }

        nav ul {
            display: flex;
            list-style: none;
            gap: 20px;
        }

        nav a {
            font-weight: 500;
        }
        
        aside {
            width: 30%;
            padding-left: 15px;
            margin-left: 15px;
            float: right;
            border-left: 1px solid var(--light-gray);
            border-bottom: 1px solid var(--light-gray);
            padding-top: 15px;
            padding-bottom: 15px;
        }
        
        aside h2 {
            margin-bottom: 5px;
            font-size: 1.2em;
        }
        
        aside .about-text {
            font-size: 0.85em;
            margin-bottom: 15px;
        }
        
        aside ul {
            padding-left: 20px;
            font-size: 0.85em;
        }

        /* Main */
        main {
            margin-bottom: 30px;
        }

        /* Posts */
        .post-list {
            display: flex;
            flex-direction: column;
        }

        .post-item {
            border-bottom: 1px solid var(--light-gray);
            padding-top:20px;
            padding-bottom: 20px;
        }

        .post-item h2 {
            margin-bottom: 5px;
        }

        .post-date {
            color: var(--medium-gray);
            font-size: 0.9rem;
            display:inline-block;
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

        .post-author {
            color: var(--medium-gray);
            font-size: 0.9rem;
            display:inline-block;
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
        
            aside {
                display:none;
            }
        }
        """
        
        // RSS Feed template
        defaultTemplates["rss"] = """
        <?xml version="1.0" encoding="UTF-8" ?>
        <rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">
        <channel>
            <title>{{blogName}}</title>
            <link>{{blogUrl}}</link>
            <description>{{#blogTagline}}{{blogTagline}}{{/blogTagline}}{{^blogTagline}}Recent posts from {{blogName}}{{/blogTagline}}</description>
            <language>en-us</language>
            <lastBuildDate>{{buildDate}}</lastBuildDate>
            <atom:link href="{{blogUrl}}/rss.xml" rel="self" type="application/rss+xml" />
            {{#blogAuthor}}
            <managingEditor>{{blogAuthor}}{{#blogAuthorUrl}} ({{blogAuthorUrl}}){{/blogAuthorUrl}}</managingEditor>
            <webMaster>{{blogAuthor}}{{#blogAuthorUrl}} ({{blogAuthorUrl}}){{/blogAuthorUrl}}</webMaster>
            {{/blogAuthor}}
            
            {{#posts}}
            <item>
                <title>{{displayTitle}}</title>
                <link>{{blogUrl}}/{{urlPath}}/</link>
                <guid>{{blogUrl}}/{{urlPath}}/</guid>
                <pubDate>{{pubDate}}</pubDate>
                {{#blogAuthor}}
                <author>{{blogAuthor}}{{#blogAuthorUrl}} ({{blogAuthorUrl}}){{/blogAuthorUrl}}</author>
                {{/blogAuthor}}
                <description><![CDATA[{{{contentHtml}}}]]></description>
            </item>
            {{/posts}}
            
        </channel>
        </rss>
        """
        
        // Robots.txt template
        defaultTemplates["robots"] = """
        User-agent: *
        Allow: /
        
        Sitemap: {{blogUrl}}/sitemap.xml
        """
        
        // Sitemap template
        defaultTemplates["sitemap"] = """
        <?xml version="1.0" encoding="UTF-8"?>
        <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
            <url>
                <loc>{{blogUrl}}/</loc>
                <lastmod>{{buildDate}}</lastmod>
                <changefreq>weekly</changefreq>
                <priority>1.0</priority>
            </url>
            <url>
                <loc>{{blogUrl}}/archives/</loc>
                <lastmod>{{buildDate}}</lastmod>
                <changefreq>weekly</changefreq>
                <priority>0.8</priority>
            </url>
            <url>
                <loc>{{blogUrl}}/tags/</loc>
                <lastmod>{{buildDate}}</lastmod>
                <changefreq>weekly</changefreq>
                <priority>0.7</priority>
            </url>
            <url>
                <loc>{{blogUrl}}/categories/</loc>
                <lastmod>{{buildDate}}</lastmod>
                <changefreq>weekly</changefreq>
                <priority>0.7</priority>
            </url>
            
            {{#posts}}
            <url>
                <loc>{{blogUrl}}/{{urlPath}}/</loc>
                <lastmod>{{lastmod}}</lastmod>
                <changefreq>monthly</changefreq>
                <priority>0.6</priority>
            </url>
            {{/posts}}
            
            {{#tags}}
            <url>
                <loc>{{blogUrl}}/tags/{{urlPath}}/</loc>
                <lastmod>{{lastmod}}</lastmod>
                <changefreq>monthly</changefreq>
                <priority>0.5</priority>
            </url>
            {{/tags}}
            
            {{#categories}}
            <url>
                <loc>{{blogUrl}}/categories/{{urlPath}}/</loc>
                <lastmod>{{lastmod}}</lastmod>
                <changefreq>monthly</changefreq>
                <priority>0.5</priority>
            </url>
            {{/categories}}
        </urlset>
        """
    }
    
    // MARK: - Template Compilation
    
    /// Compiles a template for the specified template type
    private func compileTemplate(for templateType: String) throws -> MustacheTemplate {
        // First check if the blog has a saved template of this type
        if let blogTemplate = blog.template(for: templateType) {
            return try MustacheTemplate(string: blogTemplate.content)
        } 
        // Otherwise use the default template
        else if let defaultTemplate = defaultTemplates[templateType] {
            return try MustacheTemplate(string: defaultTemplate)
        } 
        // If no template exists for this type, throw an error
        else {
            throw TemplateError.templateNotFound(templateType)
        }
    }
    
    // MARK: - Template Access
    
    /// Registers a custom template for the blog and handles saving it to the database
    /// - Parameters:
    ///   - template: The template content
    ///   - type: The template type identifier
    func registerCustomTemplate(_ template: String, for type: String) {
        // If the template content is empty, delete the template from the blog
        if template.isEmpty {
            blog.deleteTemplate(for: type)
        } else {
            // Save the template to the blog
            blog.saveTemplate(template, for: type)
        }
        
        // Remove from cache to ensure it's recompiled next time
        compiledTemplates[type] = nil
    }
    
    /// Gets the compiled template for the specified type
    /// - Parameter type: The type of template to retrieve
    /// - Returns: A compiled template
    /// - Throws: TemplateError if the template doesn't exist or can't be compiled
    func getTemplate(for type: String) throws -> MustacheTemplate {
        // Check if we already have a compiled template for this type
        if let template = compiledTemplates[type] {
            return template
        }
        
        do {
            // Otherwise compile and cache it
            let template = try compileTemplate(for: type)
            compiledTemplates[type] = template
            return template
        } catch {
            throw TemplateError.compilationFailed(type, error)
        }
    }
    
    /// Gets the default or custom template string content for the specified type
    /// - Parameter type: The type of template to retrieve
    /// - Returns: The template string
    /// - Throws: TemplateError if the template doesn't exist
    func getTemplateString(for type: String) throws -> String {
        // First check if the blog has a saved template of this type
        if let blogTemplate = blog.template(for: type) {
            return blogTemplate.content
        }
        // Otherwise use the default template
        else if let defaultTemplate = defaultTemplates[type] {
            return defaultTemplate
        } 
        // If no template exists for this type, throw an error
        else {
            throw TemplateError.templateNotFound(type)
        }
    }
    
    /// Returns all available template types
    /// - Returns: Array of template type identifiers
    func availableTemplateTypes() -> [String] {
        // Get the default template types
        let defaultTypes = Set(defaultTemplates.keys)
        
        // Get blog-specific templates
        let blogTemplateTypes = Set(blog.templates.map { $0.type })
        
        // Combine and sort
        return Array(defaultTypes.union(blogTemplateTypes)).sorted()
    }
    
    // MARK: - Errors
    
    enum TemplateError: Error, LocalizedError {
        case templateNotFound(String)
        case compilationFailed(String, Error)
        
        var errorDescription: String? {
            switch self {
            case .templateNotFound(let type):
                return "Template not found: \(type)"
            case .compilationFailed(let type, let error):
                return "Failed to compile template \(type): \(error.localizedDescription)"
            }
        }
    }
}
