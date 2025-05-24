//
//  TemplateManager.swift
//  Postalgic
//
//  Created by Brad Root on 4/26/25.
//

import Foundation
import Mustache
import SwiftData

/// Manages and provides access to Mustache templates for the static site generator
class TemplateManager {
    // Default templates
    private var defaultTemplates = [String: String]()
    
    // Custom theme templates
    private var customTemplates = [String: String]()
    
    // Compiled templates
    private var compiledTemplates = [String: MustacheTemplate]()
    
    // Reference to the blog
    private let blog: Blog
    
    // The theme to use for templates
    private var theme: Theme?
    
    // MARK: - Initialization
    
    init(blog: Blog) {
        self.blog = blog
        setupDefaultTemplates()
        loadCustomTheme()
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
            <!-- Meta tags: custom for posts, default for other pages -->
            {{^hasCustomMeta}}
            <meta name="description" content="{{#blogTagline}}{{blogTagline}}{{/blogTagline}}{{^blogTagline}}Posts from {{blogName}}{{/blogTagline}}">
            <meta property="og:title" content="{{pageTitle}}">
            <meta property="og:description" content="{{#blogTagline}}{{blogTagline}}{{/blogTagline}}{{^blogTagline}}Posts from {{blogName}}{{/blogTagline}}">
            <meta property="og:type" content="website">
            <meta property="og:url" content="{{blogUrl}}">

            <meta property="twitter:card" content="summary">
            <meta property="twitter:title" content="{{pageTitle}}">
            <meta property="twitter:description" content="{{#blogTagline}}{{blogTagline}}{{/blogTagline}}{{^blogTagline}}Posts from {{blogName}}{{/blogTagline}}">
            {{/hasCustomMeta}}

            <link rel="stylesheet" href="/css/style.css">
            <link rel="alternate" type="application/rss+xml" title="{{blogName}} RSS Feed" href="/rss.xml">
            {{{customHead}}}
            <script>
            // Gallery functionality for image embeds
            function initGallery(galleryId) {
                const gallery = document.getElementById(galleryId);
                if (!gallery) return;

                const slides = gallery.querySelectorAll('.gallery-slide');
                const dots = gallery.querySelectorAll('.gallery-dot');

                // Initialize the first slide
                showSlide(galleryId, 0);

                // Add active class to first dot
                if (dots.length > 0) {
                    dots[0].classList.add('active');
                }
            }

            function showSlide(galleryId, slideIndex) {
                const gallery = document.getElementById(galleryId);
                if (!gallery) return;

                const slides = gallery.querySelectorAll('.gallery-slide');
                const dots = gallery.querySelectorAll('.gallery-dot');

                // Hide all slides
                for (let i = 0; i < slides.length; i++) {
                    slides[i].style.display = 'none';
                    if (dots[i]) dots[i].classList.remove('active');
                }

                // Show the selected slide and activate dot
                slides[slideIndex].style.display = 'block';
                if (dots[slideIndex]) dots[slideIndex].classList.add('active');
            }

            function nextSlide(galleryId) {
                const gallery = document.getElementById(galleryId);
                if (!gallery) return;

                const slides = gallery.querySelectorAll('.gallery-slide');
                const dots = gallery.querySelectorAll('.gallery-dot');

                // Find active slide
                let activeIndex = 0;
                for (let i = 0; i < slides.length; i++) {
                    if (slides[i].style.display === 'block') {
                        activeIndex = i;
                        break;
                    }
                }

                // Calculate next slide index
                const nextIndex = (activeIndex + 1) % slides.length;
                showSlide(galleryId, nextIndex);
            }

            function prevSlide(galleryId) {
                const gallery = document.getElementById(galleryId);
                if (!gallery) return;

                const slides = gallery.querySelectorAll('.gallery-slide');
                const dots = gallery.querySelectorAll('.gallery-dot');

                // Find active slide
                let activeIndex = 0;
                for (let i = 0; i < slides.length; i++) {
                    if (slides[i].style.display === 'block') {
                        activeIndex = i;
                        break;
                    }
                }

                // Calculate previous slide index
                const prevIndex = (activeIndex - 1 + slides.length) % slides.length;
                showSlide(galleryId, prevIndex);
            }

            // Lightbox functionality
            document.addEventListener('DOMContentLoaded', function() {
                // Initialize lightbox
                const lightbox = document.createElement('div');
                lightbox.id = 'lightbox';
                lightbox.innerHTML = `
                    <div class="lightbox-content">
                        <button class="lightbox-close">&times;</button>
                        <div class="lightbox-image-container">
                            <img id="lightbox-image" src="" alt="Lightbox image">
                        </div>
                        <div class="lightbox-nav">
                            <button class="lightbox-prev">❮</button>
                            <button class="lightbox-next">❯</button>
                        </div>
                    </div>
                `;
                document.body.appendChild(lightbox);

                // Track current image group and index
                let currentGroup = '';
                let currentIndex = 0;
                let groupImages = [];

                // Handle lightbox trigger clicks
                document.querySelectorAll('.lightbox-trigger').forEach(trigger => {
                    trigger.addEventListener('click', function(e) {
                        e.preventDefault();

                        // Get the image group and build the array of images in this group
                        const group = this.getAttribute('data-lightbox');
                        groupImages = Array.from(document.querySelectorAll(`[data-lightbox="${group}"]`));
                        currentGroup = group;
                        currentIndex = groupImages.indexOf(this);

                        // Show the lightbox with the selected image
                        openLightbox(this.getAttribute('href'), this.getAttribute('data-title'));
                    });
                });

                // Close lightbox when clicking the close button or outside the image
                document.querySelector('.lightbox-close').addEventListener('click', closeLightbox);
                lightbox.addEventListener('click', function(e) {
                    if (e.target === lightbox) {
                        closeLightbox();
                    }
                });

                // Navigation buttons
                document.querySelector('.lightbox-prev').addEventListener('click', function() {
                    if (groupImages.length <= 1) return;

                    currentIndex = (currentIndex - 1 + groupImages.length) % groupImages.length;
                    const prevTrigger = groupImages[currentIndex];
                    openLightbox(prevTrigger.getAttribute('href'), prevTrigger.getAttribute('data-title'));
                });

                document.querySelector('.lightbox-next').addEventListener('click', function() {
                    if (groupImages.length <= 1) return;

                    currentIndex = (currentIndex + 1) % groupImages.length;
                    const nextTrigger = groupImages[currentIndex];
                    openLightbox(nextTrigger.getAttribute('href'), nextTrigger.getAttribute('data-title'));
                });

                // Keyboard navigation
                document.addEventListener('keydown', function(e) {
                    if (!lightbox.classList.contains('active')) return;

                    if (e.key === 'Escape') {
                        closeLightbox();
                    } else if (e.key === 'ArrowLeft') {
                        document.querySelector('.lightbox-prev').click();
                    } else if (e.key === 'ArrowRight') {
                        document.querySelector('.lightbox-next').click();
                    }
                });

                // Helper functions
                function openLightbox(imageSrc, imageTitle) {
                    const lightboxImage = document.getElementById('lightbox-image');
                    lightboxImage.src = imageSrc;
                    lightboxImage.alt = imageTitle || 'Image';

                    // Show/hide navigation based on group size
                    const navButtons = document.querySelectorAll('.lightbox-nav button');
                    navButtons.forEach(btn => {
                        btn.style.display = groupImages.length > 1 ? 'block' : 'none';
                    });

                    lightbox.classList.add('active');
                    document.body.style.overflow = 'hidden'; // Prevent scrolling when lightbox is open
                }

                function closeLightbox() {
                    lightbox.classList.remove('active');
                    document.body.style.overflow = '';
                }

                // Initialize all galleries on the page
                document.querySelectorAll('[id^="gallery-"]').forEach(gallery => {
                    initGallery(gallery.id);
                });
            });
            </script>
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
                    <div class="header-separator"></div>
                </header>

                <div class="content-wrapper">
                    <div class="mobile-sidebar-overlay"></div>
                    <aside class="sidebar">
                        <div class="mobile-nav">
                            <nav class="sidebar-nav">
                                <ul>
                                    <li><a href="/">Home</a></li>
                                    <li><a href="/archives/">Archives</a></li>
                                    <li><a href="/categories/">Categories</a></li>
                                    <li><a href="/tags/">Tags</a></li>
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
        
            <div class="post-date"><a href="/{{urlPath}}/">{{formattedDate}}</a></div>
            
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
                        <a href="/tags/{{urlPath}}/" class="tag">#{{name}}</a> 
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
        {{#hasMorePosts}}
        <div class="archives-link">
            <a href="/archives">View all posts in archives →</a>
        </div>
        {{/hasMorePosts}}
        """
        
        // Archives template
        defaultTemplates["archives"] = """
        <h1>Archives</h1>
        {{#years}}
            <div class="archive-year">{{year}}</div>
            {{#months}}
                <div class="archive-month">
                    <a href="/{{year}}/{{monthPadded}}/">{{monthName}}</a>
                </div>
                <ul class="archive-posts">
                    {{#posts}}
                        <li>
                            <span class="archive-date">{{dayPadded}} {{monthAbbr}}</span>
                            <a href="/{{urlPath}}/">{{displayTitle}}</a>
                        </li>
                    {{/posts}}
                </ul>
            {{/months}}
        {{/years}}
        """
        
        // Monthly archive template
        defaultTemplates["monthly-archive"] = """
        <h1>{{monthName}} {{year}}</h1>
        <p class="archive-meta">{{postCount}} {{postCountText}} in this month</p>
        
        <div class="post-list">
            {{#posts}}
                {{> post}}
            {{/posts}}
        </div>
        
        {{#hasPreviousMonth}}{{#hasNextMonth}}
        <nav class="month-navigation">
            <div class="nav-previous">
                <a href="{{previousMonthUrl}}">&larr; {{previousMonthName}} {{previousYear}}</a>
            </div>
            <div class="nav-next">
                <a href="{{nextMonthUrl}}">{{nextMonthName}} {{nextYear}} &rarr;</a>
            </div>
        </nav>
        {{/hasNextMonth}}{{/hasPreviousMonth}}
        
        {{#hasPreviousMonth}}{{^hasNextMonth}}
        <nav class="month-navigation">
            <div class="nav-previous">
                <a href="{{previousMonthUrl}}">&larr; {{previousMonthName}} {{previousYear}}</a>
            </div>
        </nav>
        {{/hasNextMonth}}{{/hasPreviousMonth}}
        
        {{^hasPreviousMonth}}{{#hasNextMonth}}
        <nav class="month-navigation">
            <div class="nav-next">
                <a href="{{nextMonthUrl}}">{{nextMonthName}} {{nextYear}} &rarr;</a>
            </div>
        </nav>
        {{/hasNextMonth}}{{/hasPreviousMonth}}
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
         * 12. Lightbox
         * 13. Responsive Styles
         */

        /* ==========================================
           1. CSS Variables & Reset
           ========================================== */
        :root {
            /* Colors */
            --primary-color: #4a5568;
            --accent-color: {{accentColor}};
            --background-color: #efefef;
            --background-outline-color: #efefef;
            --text-color: #2d3748;

            /* Grays */
            --light-gray: #dedede;
            --medium-gray: #a0aec0;
            --dark-gray: #4a5568;

            /* Tag & Category Colors */
            --tag-bg: #f5e5ef;
            --tag-color: #CB7BAC;
            --category-bg: #faf4eb;
            --category-color: {{accentColor}};
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
            padding-bottom: 1em;
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

        .header-separator {
            height: 28px;
            width: 100%;
            background-color: var(--accent-color);
            --mask:
              radial-gradient(10.96px at 50% calc(100% + 5.6px),#0000 calc(99% - 4px),#000 calc(101% - 4px) 99%,#0000 101%) calc(50% - 14px) calc(50% - 5.5px + .5px)/28px 11px repeat-x,
              radial-gradient(10.96px at 50% -5.6px,#0000 calc(99% - 4px),#000 calc(101% - 4px) 99%,#0000 101%) 50% calc(50% + 5.5px)/28px 11px repeat-x;
            -webkit-mask: var(--mask);
            mask: var(--mask);
            margin-top: 2em;
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
            padding: 0;
        }

        .sidebar-nav li {
            
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
            font-weight: 600;
            font-size: 1.1rem;
            color: var(--primary-color);
        }

        .sidebar-links {
            margin-bottom: 1.5em;
        }

        .sidebar-text {
            margin-bottom: 1.5em;
        }

        aside .sidebar-links ul, 
        .sidebar .sidebar-links ul {
            font-size: 0.8em;
            margin-bottom: 15px;
            padding-left: 1.5em;
            font-size: 0.8em;
        }

        aside .sidebar-text div, 
        .sidebar .sidebar-text div {
            font-size: 0.8em;
            margin-bottom: 15px;
        }

        aside .sidebar-text div p, 
        .sidebar .sidebar-text div p {
            margin-bottom: 15px;
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
            height: 28px;
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
            background-color: var(--category-bg);
            color: var(--category-color);
            border: 1px solid var(--category-color);
            padding: 3px 8px;
            border-radius: 1em;
        }

        .tag:hover {
            background-color: var(--category-color);
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
            color: white;
            background-color: var(--category-color);
            border: 1px solid var(--category-color);
            padding: 3px 8px;
            border-radius: 1em;
        }

        .post-category a:hover {
            background-color: var(--category-bg);
            color: var(--category-color);
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

        .archive-month a {
            color: inherit;
            text-decoration: none;
        }

        .archive-month a:hover {
            color: var(--accent-color);
            text-decoration: underline;
        }

        .archive-posts {
            list-style: none;
            padding-left: 0;
        }

        .archive-date {
            color: var(--medium-gray);
            display: inline-block;
            width: 70px;
        }

        /* Monthly Archive Pages */
        .archive-meta {
            color: var(--medium-gray);
            font-style: italic;
            margin-bottom: 30px;
        }

        .month-navigation {
            display: flex;
            justify-content: space-between;
            margin-top: 40px;
            padding-top: 20px;
            border-top: 1px solid var(--light-gray);
        }

        .month-navigation .nav-previous,
        .month-navigation .nav-next {
            flex: 1;
        }

        .month-navigation .nav-next {
            text-align: right;
        }

        .month-navigation a {
            color: var(--accent-color);
            text-decoration: none;
            font-weight: 500;
        }

        .month-navigation a:hover {
            text-decoration: underline;
        }

        /* ==========================================
           9. Embeds & Media
           ========================================== */
        .embed {
            margin: 1.5em 0;
            overflow: hidden;
        }

        .youtube-embed {
            position: relative;
            padding-bottom: 56.25%; /* 16:9 ratio */
            height: 0;
            overflow: hidden;
            border-radius: 8px;
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
           12. Lightbox
           ========================================== */
        
        #lightbox {
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            background: rgba(0, 0, 0, 0.9);
            display: none;
            align-items: center;
            justify-content: center;
            z-index: 1000;
            overflow: hidden;
        }

        #lightbox.active {
            display: flex;
        }

        .lightbox-content {
            position: relative;
            max-width: 90%;
            max-height: 90%;
            display: flex;
            flex-direction: column;
            align-items: center;
        }

        .lightbox-image-container {
            display: flex;
            align-items: center;
            justify-content: center;
        }

        #lightbox-image {
            max-width: 100%;
            max-height: 80vh;
            object-fit: contain;
        }

        .lightbox-close {
            position: absolute;
            top: -40px;
            right: 0;
            background: transparent;
            border: none;
            color: white;
            font-size: 30px;
            cursor: pointer;
            z-index: 1001;
        }

        .lightbox-nav {
            width: 100%;
            display: flex;
            justify-content: space-between;
            margin-top: 20px;
        }

        .lightbox-prev, .lightbox-next {
            background: rgba(255, 255, 255, 0.2);
            border: none;
            color: white;
            font-size: 24px;
            padding: 10px 15px;
            border-radius: 50%;
            cursor: pointer;
            margin: 0 20px;
        }

        /* Image gallery styles */
        .embed.image-embed {
            margin: 20px 0;
        }

        .embed.image-embed img.embed-image {
            max-width: 100%;
            height: auto;
            cursor: pointer;
            border-radius: 8px;
        }

        /* Style for the single image display - full width */
        .embed.image-embed.single-image {
            width: 100%;
            margin: 20px 0;
            text-align: center;
        }

        .embed.image-embed.single-image a {
            display: block;
            width: 100%;
        }

        .embed.image-embed.single-image img.embed-image {
            max-width: 100%;
            height: auto;
            display: inline-block;
            margin: 0 auto;
        }

        .gallery-container {
            position: relative;
            width: 100%;
            /* Create fixed aspect ratio container using padding-bottom technique */
            padding-bottom: 75%; /* 4:3 aspect ratio (75% = 3/4) */
            overflow: hidden;
        }

        .gallery-slide {
            display: none;
            text-align: center;
            position: absolute;
            width: 100%;
            height: 100%;
            top: 0;
            left: 0;
        }

        .gallery-slide a {
            position: absolute;
            width: 100%;
            height: 100%;
            display: flex;
            align-items: center;
            justify-content: center;
            top: 0;
            left: 0;
        }

        .gallery-slide img {
            max-width: 100%;
            max-height: 100%;
            object-fit: contain; /* Maintains aspect ratio while fitting in the container */
            display: block;
        }

        .gallery-nav {
            display: flex;
            justify-content: space-between;
            position: absolute;
            top: 50%;
            width: 100%;
            transform: translateY(-50%);
            z-index: 1;
        }

        .gallery-prev, .gallery-next {
            background: rgba(0, 0, 0, 0.5);
            color: white;
            border: none;
            border-radius: 50%;
            width: 40px;
            height: 40px;
            font-size: 18px;
            cursor: pointer;
            margin: 0 10px;
        }

        .gallery-dots {
            display: flex;
            justify-content: center;
            margin-top: 10px;
        }

        .gallery-dot {
            width: 10px;
            height: 10px;
            margin: 0 5px;
            background-color: #bbb;
            border-radius: 50%;
            cursor: pointer;
        }

        .gallery-dot.active {
            background-color: var(--accent-color);
        }

        /* ==========================================
           13. Responsive Styles
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
                padding: 0;
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


            aside .sidebar-text div, 
            .sidebar .sidebar-text div {
                font-size: 1em;
                margin-bottom: 15px;
            }

            aside .sidebar-links ul, 
            .sidebar .sidebar-links ul {
                font-size: 1em;
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
            
            {{#monthlyArchives}}
            <url>
                <loc>{{blogUrl}}{{url}}</loc>
                <lastmod>{{lastmod}}</lastmod>
                <changefreq>monthly</changefreq>
                <priority>0.6</priority>
            </url>
            {{/monthlyArchives}}
        </urlset>
        """
    }
    
    // MARK: - Template Compilation
    
    // Create a library to store all templates for partials
    private lazy var templateLibrary: MustacheLibrary = {
        var library = MustacheLibrary()
        
        // First register default templates
        for (name, content) in defaultTemplates {
            do {
                try library.register(content, named: name)
            } catch {
                print("Error registering default template \(name): \(error)")
            }
        }
        
        // Then register custom templates (overriding defaults if names match)
        for (name, content) in customTemplates {
            do {
                try library.register(content, named: name)
            } catch {
                print("Error registering custom template \(name): \(error)")
            }
        }
        
        return library
    }()
    
    /// Compiles a template for the specified template type
    private func compileTemplate(for templateType: String) throws -> MustacheTemplate {
        // Check if we have a custom template for this type
        if let customTemplate = customTemplates[templateType] {
            return try MustacheTemplate(string: customTemplate)
        }
        // Fall back to the default template
        else if let defaultTemplate = defaultTemplates[templateType] {
            return try MustacheTemplate(string: defaultTemplate)
        } 
        // If no template exists for this type, throw an error
        else {
            throw TemplateError.templateNotFound(templateType)
        }
    }
    
    // MARK: - Template Access
    
    /// Loads the custom theme if one is specified in the blog's themeIdentifier
    private func loadCustomTheme() {
        guard let themeIdentifier = blog.themeIdentifier, themeIdentifier != "default" else {
            // Use default templates
            print("Using default theme")
            return
        }
        
        // Try to find the custom theme using the model context
        guard let modelContext = blog.modelContext else {
            print("No model context available for blog, using default theme")
            return
        }
        
        // Try to find the theme
        let descriptor = FetchDescriptor<Theme>()
        
        do {
            let allThemes = try modelContext.fetch(descriptor)
            
            // Find the theme with matching identifier
            if let customTheme = allThemes.first(where: { $0.identifier == themeIdentifier }) {
                print("Found theme: \(customTheme.name)")
                
                // Load all templates from the dictionary
                customTemplates = customTheme.templates
                
                print("Loaded \(customTemplates.count) templates from theme")
            } else {
                print("Theme with ID \(themeIdentifier) not found, using default theme")
            }
        } catch {
            print("Error loading custom theme: \(error)")
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
    
    /// Gets the template string content for the specified type
    /// - Parameter type: The type of template to retrieve
    /// - Returns: The template string
    /// - Throws: TemplateError if the template doesn't exist
    func getTemplateString(for type: String) throws -> String {
        // Check if we have a custom template for this type
        if let customTemplate = customTemplates[type] {
            return customTemplate
        }
        // Fall back to the default template
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
        // Combine default and custom template types, with defaults taking precedence
        let allTemplateTypes = Set(defaultTemplates.keys)
        return Array(allTemplateTypes).sorted()
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
