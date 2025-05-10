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
    /// - Returns: The complete HTML page
    /// - Throws: Error if rendering fails
    func renderLayout(content: String, pageTitle: String, customHead: String = "") throws -> String {
        let layoutTemplate = try templateManager.getTemplate(for: "layout")

        var context = createBaseContext()
        context["content"] = content
        context["pageTitle"] = pageTitle

        // Add gallery and lightbox JavaScript to the custom head
        var enhancedCustomHead = customHead

        // Add lightbox CSS and JS if not already present
        if !enhancedCustomHead.contains("lightbox.css") {
            enhancedCustomHead += """
            <link rel="stylesheet" href="/css/lightbox.css">
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
            """
        }

        context["customHead"] = enhancedCustomHead

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
        
        // We need to extract these values for the page title
        let hasTitle = post.title?.isEmpty == false
        let displayTitle = post.displayTitle
        let formattedDate = post.formattedDate
        
        let pageTitle = hasTitle 
            ? "\(displayTitle) - \(blog.name)" 
            : "\(formattedDate) - \(blog.name)"
        
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
