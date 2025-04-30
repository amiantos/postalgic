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
                    <div class="hamburger-menu">
                        <div class="hamburger-icon">
                            <span></span>
                            <span></span>
                            <span></span>
                        </div>
                    </div>
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
                
                <div class="content-wrapper">
                    <div class="mobile-sidebar-overlay"></div>
                    <aside class="sidebar">
                        <div class="mobile-nav">
                            <nav class="sidebar-nav">
                                <ul>
                                    <li><a href="/">Home</a></li>
                                    <li><a href="/archives/">Archives</a></li>
                                    <li><a href="/tags/">Tags</a></li>
                                    <li><a href="/categories/">Categories</a></li>
                                </ul>
                            </nav>
                        </div>
                        <div class="sidebar-content">
                            {{{sidebarContent}}}
                        </div>
                    </aside>
                    
                    <main>
                        {{{content}}}
                    </main>
                    
                    <div class="clearfix"></div>
                </div>
                
                <footer>
                    <p>&copy; {{currentYear}} {{blogName}}{{#blogAuthor}} by {{#blogAuthorUrl}}<a href="{{blogAuthorUrl}}">{{blogAuthor}}</a>{{/blogAuthorUrl}}{{^blogAuthorUrl}}{{blogAuthor}}{{/blogAuthorUrl}}{{/blogAuthor}}. Generated with <a href="https://postalgic.app">Postalgic</a>.</p>
                </footer>
            </div>
            
            <script>
                document.addEventListener('DOMContentLoaded', function() {
                    const hamburgerIcon = document.querySelector('.hamburger-icon');
                    const sidebar = document.querySelector('.sidebar');
                    const overlay = document.querySelector('.mobile-sidebar-overlay');
                    
                    function toggleSidebar() {
                        document.body.classList.toggle('sidebar-open');
                    }
                    
                    if (hamburgerIcon) {
                        hamburgerIcon.addEventListener('click', toggleSidebar);
                    }
                    
                    if (overlay) {
                        overlay.addEventListener('click', toggleSidebar);
                    }
                    
                    // Handle page resize events
                    window.addEventListener('resize', function() {
                        if (window.innerWidth > 900 && document.body.classList.contains('sidebar-open')) {
                            document.body.classList.remove('sidebar-open');
                        }
                    });
                });
            </script>
        </body>
        </html>
        """
        
        // Post template (used for both individual post pages and list items)
        defaultTemplates["post"] = """
        <article class="post-item">
            {{#hasTitle}}
                {{#inList}}<h2>{{displayTitle}}</h2>{{/inList}}
                {{^inList}}<h1>{{displayTitle}}</h1>{{/inList}}
            {{/hasTitle}}
        
            <div class="post-date"><a href="/{{urlPath}}/index.html">{{formattedDate}}</a></div>
            
            {{#blogAuthor}}
                <div class="post-author"> by {{#blogAuthorUrl}}<a href="{{blogAuthorUrl}}">{{blogAuthor}}</a>{{/blogAuthorUrl}}{{^blogAuthorUrl}}{{blogAuthor}}{{/blogAuthorUrl}}</div>
            {{/blogAuthor}}
        
            <div class="post-content">
                {{{contentHtml}}}
            </div>

            <div>
            {{#hasCategory}}
                <div class="post-category">
                    <a href="/categories/{{categoryUrlPath}}/">{{categoryName}}</a>
                </div>
            {{/hasCategory}}
        
            {{#hasTags}}
                <div class="post-tags">
                    {{#tags}}
                        <a href="/tags/{{urlPath}}/" class="tag">{{name}}</a> 
                    {{/tags}}
                </div>
            {{/hasTags}}
            </div>

        </article>
        <div class="post-separator"></div>
        """
        
        // Index page template
        defaultTemplates["index"] = """
        {{#posts}}
            {{> post}}
        {{/posts}}
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
                {{> post}}
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
                {{> post}}
            {{/posts}}
        </div>
        """
        
        // Default CSS style
        defaultTemplates["css"] = """
        /* 
         * Blog/Website Theme CSS
         * Table of Contents:
         * 1. CSS Variables & Reset
         * 2. Base Styles
         * 3. Layout & Container
         * 4. Header & Navigation
         * 5. Sidebar
         * 6. Content & Posts
         * 7. Post Elements (tags, categories)
         * 8. Archives
         * 9. Embeds & Media
         * 10. Typography Elements
         * 11. Footer
         * 12. Responsive Styles
         */

        /* ==========================================
           1. CSS Variables & Reset
           ========================================== */
        :root {
            /* Colors */
            --primary-color: #4a5568;
            --accent-color: #FFA100;
            --background-color: #efefef;
            --background-outline-color: #515151;
            --text-color: #2d3748;
            
            /* Grays */
            --light-gray: #dedede;
            --medium-gray: #a0aec0;
            --dark-gray: #4a5568;
            
            /* Tag & Category Colors */
            --tag-bg: #f5e5ef;
            --tag-color: #CB7BAC;
            --category-bg: #fff2db;
            --category-color: #FFA100;
        }

        * {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }

        /* ==========================================
           2. Base Styles
           ========================================== */
        html {
            overflow-y: scroll;
            height: 100%;
            font: 100%/1.5 sans-serif;
            word-wrap: break-word;
            margin: 0 auto;
            padding: 1.5em;
        }

        body {
            font-family: system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            line-height: 1.6;
            color: var(--text-color);
            background-color: var(--background-outline-color);
        }

        a {
            color: var(--accent-color);
            text-decoration: none;
        }

        a:hover {
            text-decoration: underline;
        }

        /* ==========================================
           3. Layout & Container
           ========================================== */
        .container {
            max-width: 1000px;
            margin: 0 auto;
            background-color: var(--background-color);
            position: relative;
            min-height: 100vh;
            display: flex;
            flex-direction: column;
        }

        .content-wrapper {
            display: block;
            flex: 1;
            position: relative;
            overflow: hidden;
        }

        /* Clearfix for floated elements */
        .clearfix {
            clear: both;
            width: 100%;
            display: block;
        }

        /* ==========================================
           4. Header & Navigation
           ========================================== */
        header {
            padding: 2em;
            border-bottom: 1px solid var(--light-gray);
        }

        header h1 a {
            color: var(--primary-color);
            text-decoration: none;
        }

        header .tagline {
            color: var(--medium-gray);
            font-size: 1.2rem;
            font-style: italic;
        }

        /* Main Navigation */
        nav {
            border-bottom: 1px solid var(--light-gray);
            padding: 1em 2em;
        }

        nav ul {
            display: flex;
            list-style: none;
            gap: 20px;
        }

        nav a {
            font-weight: 500;
        }

        /* Hamburger Menu (Mobile) */
        .hamburger-menu {
            display: none;
            cursor: pointer;
            padding: 10px;
        }

        .hamburger-icon span {
            display: block;
            width: 25px;
            height: 3px;
            background-color: var(--dark-gray);
            margin: 5px 0;
            transition: 0.3s;
        }

        .mobile-sidebar-overlay {
            display: none;
            position: fixed;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background-color: rgba(0, 0, 0, 0.5);
            z-index: 998;
        }

        /* ==========================================
           5. Sidebar
           ========================================== */
        aside.sidebar {
            width: 100%;
            padding: 1.5em;
            box-sizing: border-box;
            background-color: var(--background-color);
        }

        /* Mobile Navigation in Sidebar */
        .mobile-nav {
            display: none;
            margin-bottom: 25px;
            border-bottom: 1px solid var(--light-gray);
            padding-bottom: 20px;
        }

        .sidebar-content {
            padding-top: 5px;
        }

        .sidebar-nav ul {
            display: flex;
            flex-direction: column;
            list-style: none;
            padding: 0;
            margin-bottom: 15px;
            font-size: 1rem;
        }

        .sidebar-nav li {
            margin-bottom: 10px;
        }

        .sidebar-nav a {
            display: block;
            padding: 8px 0;
            font-weight: 600;
            font-size: 1.1rem;
            color: var(--primary-color);
        }

        aside h2, 
        .sidebar h2 {
            margin-bottom: 0.3em;
            font-size: 1.2em;
        }

        aside .sidebar-links ul, 
        .sidebar .sidebar-links ul {
            font-size: 0.8em;
            margin-bottom: 15px;
        }

        aside .sidebar-text div, 
        .sidebar .sidebar-text div {
            font-size: 0.8em;
            margin-bottom: 15px;
        }

        aside ul, 
        .sidebar ul {
            padding-left: 1.5em;
            font-size: 0.8em;
        }

        /* ==========================================
           6. Content & Posts
           ========================================== */
        main {
            display: flex;
            flex-direction: column;
            padding: 2em;
            overflow: hidden;
            margin-bottom: 30px;
            flex: 1;
        }

        .post-content a {
            text-decoration: underline;
        }

        .post-date {
            color: var(--medium-gray);
            font-size: 0.9em;
            display: inline-block;
        }

        .post-date a, 
        .post-author a {
            color: var(--medium-gray);
            text-decoration: none;
        }

        .post-date a:hover, 
        .post-author a:hover {
            color: var(--accent-color);
            text-decoration: underline;
        }

        .post-author {
            color: var(--medium-gray);
            font-size: 0.9em;
            display: inline-block;
        }

        .post-summary p, 
        .post-content p {
            margin-top: 1.5em;
        }

        .post-meta {
            margin-bottom: 20px;
        }

        .post-content {
            line-height: 1.8;
        }

        .post-separator {
            height: 30px;
            width: 100%;
            background-color: var(--accent-color);
            --mask:
              radial-gradient(10.96px at 50% calc(100% + 5.6px),#0000 calc(99% - 4px),#000 calc(101% - 4px) 99%,#0000 101%) calc(50% - 14px) calc(50% - 5.5px + .5px)/28px 11px repeat-x,
              radial-gradient(10.96px at 50% -5.6px,#0000 calc(99% - 4px),#000 calc(101% - 4px) 99%,#0000 101%) 50% calc(50% + 5.5px)/28px 11px repeat-x;
            -webkit-mask: var(--mask);
            mask: var(--mask);
            margin-top: 3em;
            margin-bottom: 3em;
        }

        /* ==========================================
           7. Post Elements (tags, categories)
           ========================================== */
        /* Tags */
        .post-tags, 
        .post-category {
            margin-top: 3em;
            font-size: 0.6em;
        }

        .post-tags {
            display: inline-block;
        }

        .tag {
            display: inline-block;
            background-color: var(--tag-bg);
            color: var(--tag-color);
            border: 1px solid var(--tag-color);
            padding: 3px 8px;
            border-radius: 100px;
        }

        .tag:hover {
            background-color: var(--tag-color);
            color: white;
            text-decoration: none;
        }

        .tag-list, 
        .category-list {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(250px, 1fr));
            gap: 20px;
            margin-top: 20px;
        }

        .tag-item, 
        .category-item {
            background-color: var(--light-gray);
            padding: 15px;
            border-radius: 4px;
        }

        .tag-count, 
        .category-count {
            font-size: 0.8rem;
            color: var(--medium-gray);
            font-weight: normal;
        }

        .tag-meta, 
        .category-meta {
            color: var(--medium-gray);
            font-style: italic;
            margin-bottom: 20px;
        }

        /* Categories */
        .post-category {
            display: inline-block;
        }

        .post-category a {
            display: inline-block;
            color: var(--category-color);
            background-color: var(--category-bg);
            border: 1px solid var(--category-color);
            padding: 3px 8px;
            border-radius: 100px;
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

        /* ==========================================
           8. Archives
           ========================================== */
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

        /* ==========================================
           9. Embeds & Media
           ========================================== */
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

        /* ==========================================
           10. Typography Elements
           ========================================== */
        blockquote {
            color: var(--dark-gray);
            font-style: italic;
            border-left: 2px solid var(--accent-color);
            padding-left: 1.3em;
        }

        /* ==========================================
           11. Footer
           ========================================== */
        footer {
            text-align: center;
            padding: 2em;
            color: var(--medium-gray);
            font-size: 0.9rem;
            margin-top: auto;
            width: 100%;
            border-top: 1px solid var(--light-gray);
        }

        /* ==========================================
           12. Responsive Styles
           ========================================== */
        /* Desktop (> 900px) */
        @media (min-width: 901px) {
            body {
                background-color: var(--background-outline-color);
                font-size: 115%;
            }
            
            .container {
                background-color: var(--background-color);
            }
            
            aside.sidebar {
                float: right;
                width: 30%;
                padding: 1.5em;
                margin-left: 1.5em;
                border-left: 1px solid var(--light-gray);
                border-bottom: 1px solid var(--light-gray);
                position: static;
                height: auto;
                right: auto;
                top: auto;
            }
            
            main {
                overflow: auto;
                margin-right: 0;
            }
            
            .mobile-sidebar-overlay {
                display: none !important;
            }
            
            .hamburger-menu {
                display: none !important;
            }
        }

        /* Mobile (≤ 900px) */
        @media (max-width: 900px) {
            html {
                padding: 0.6em;
            }
            
            body {
                background-color: var(--background-outline-color);
            }
            
            .container {
                padding: 15px;
                position: relative;
                overflow-x: hidden;
            }

            header {
                padding: 1em;
            }

            footer {
                padding: 1em;
            }

            /* Hide desktop nav on mobile */
            nav:not(.sidebar-nav) {
                display: none;
            }
            
            /* Show mobile nav in sidebar */
            .mobile-nav {
                display: block;
            }
            
            /* Show hamburger menu on mobile */
            .hamburger-menu {
                display: block;
                position: absolute;
                top: 15px;
                right: 15px;
                z-index: 1000;
            }
            
            /* Transform hamburger to X when sidebar is open */
            body.sidebar-open .hamburger-icon span:nth-child(1) {
                transform: rotate(-45deg) translate(-5px, 6px);
            }
            
            body.sidebar-open .hamburger-icon span:nth-child(2) {
                opacity: 0;
            }
            
            body.sidebar-open .hamburger-icon span:nth-child(3) {
                transform: rotate(45deg) translate(-5px, -6px);
            }
            
            /* Show overlay when sidebar is open */
            body.sidebar-open .mobile-sidebar-overlay {
                display: block;
            }
            
            /* Mobile sidebar styling */
            aside.sidebar {
                position: fixed;
                top: 0;
                right: -85%; /* Start offscreen */
                width: 85%;
                height: 100%;
                background-color: var(--background-color);
                padding: 25px 20px;
                padding-top: 30px;
                margin: 0;
                float: none;
                border: none;
                transition: right 0.3s ease;
                z-index: 999;
                overflow-y: auto;
                box-shadow: -2px 0 5px rgba(0,0,0,0.1);
            }
            
            body.sidebar-open .sidebar {
                right: 0; /* Slide in from right */
            }
            
            /* Hide regular aside on mobile */
            aside:not(.sidebar) {
                display: none;
            }
            
            .tag-list, .category-list {
                grid-template-columns: 1fr;
            }
            
            /* Mobile link embeds */
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

            main {
                padding-left: 1em;
                padding-right: 1em;
                width: 100%; /* Full width when sidebar is hidden */
            }
        }
        """
        
        // Atom Feed template
        defaultTemplates["rss"] = """
        <?xml version="1.0" encoding="UTF-8"?>
        <feed xmlns="http://www.w3.org/2005/Atom" xml:base="{{blogUrl}}/">
            <title>{{blogName}}</title>
            <link href="{{blogUrl}}/" rel="alternate" type="text/html" />
            <link href="{{blogUrl}}/rss.xml" rel="self" type="application/atom+xml" />
            <id>{{blogUrl}}/</id>
            <updated>{{buildDate}}</updated>
            <subtitle>{{#blogTagline}}{{blogTagline}}{{/blogTagline}}{{^blogTagline}}Posts from {{blogName}}{{/blogTagline}}</subtitle>
            {{#blogAuthor}}
            <author>
                <name>{{blogAuthor}}</name>
                {{#blogAuthorUrl}}<uri>{{blogAuthorUrl}}</uri>{{/blogAuthorUrl}}
                {{#blogAuthorEmail}}<email>{{blogAuthorEmail}}</email>{{/blogAuthorEmail}}
            </author>
            {{/blogAuthor}}
            <generator uri="https://postalgic.app/" version="1.0">Postalgic</generator>
            
            {{#posts}}
            <entry>
                <title>{{displayTitle}}</title>
                <link href="{{blogUrl}}/{{urlPath}}/" rel="alternate" type="text/html" />
                <id>{{blogUrl}}/{{urlPath}}/</id>
                <published>{{published}}</published>
                <updated>{{updated}}</updated>
                {{#blogAuthor}}
                <author>
                    <name>{{blogAuthor}}</name>
                    {{#blogAuthorUrl}}<uri>{{blogAuthorUrl}}</uri>{{/blogAuthorUrl}}
                    {{#blogAuthorEmail}}<email>{{blogAuthorEmail}}</email>{{/blogAuthorEmail}}
                </author>
                {{/blogAuthor}}
                {{#hasCategory}}
                <category term="{{categoryName}}" />
                {{/hasCategory}}
                {{#hasTags}}
                {{#tags}}
                <category term="{{name}}" />
                {{/tags}}
                {{/hasTags}}
                <content type="html"><![CDATA[{{{contentHtml}}}]]></content>
            </entry>
            {{/posts}}
        </feed>
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
    
    // Create a library to store all templates for partials
    private lazy var templateLibrary: MustacheLibrary = {
        var library = MustacheLibrary()
        
        // Register all default templates
        for (name, content) in defaultTemplates {
            do {
                try library.register(content, named: name)
            } catch {
                print("Error registering default template \(name): \(error)")
            }
        }
        
        // Register all custom blog templates (these will override defaults with the same name)
        for templateObj in blog.templates {
            do {
                try library.register(templateObj.content, named: templateObj.type)
            } catch {
                print("Error registering custom template \(templateObj.type): \(error)")
            }
        }
        
        return library
    }()
    
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
        
        // Update the template in the library
        do {
            try templateLibrary.register(template, named: type)
        } catch {
            print("Error updating template library for \(type): \(error)")
        }
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
            
            // Refresh the library when a template changes
            let _ = templateLibrary
            
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
    
    /// Returns the template library for use with partials
    /// - Returns: The template library
    func getLibrary() -> MustacheLibrary {
        return templateLibrary
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
