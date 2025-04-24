//
//  PreviewData.swift
//  Postalgic
//
//  Created by Claude on 4/24/25.
//

import Foundation
import SwiftData
import SwiftUI

/// A centralized place for preview mock data and helpers
struct PreviewData {
    // MARK: - Mock Blog Data
    
    static let blog = Blog(
        name: "Test Blog",
        url: "https://example.com",
        authorName: "John Doe",
        authorUrl: "https://johndoe.com",
        tagline: "Thoughts on technology and design"
    )
    
    static func blogWithContent() -> Blog {
        let blog = Blog(
            name: "Tech Chronicles",
            url: "https://techchronicles.example.com",
            authorName: "Sarah Johnson",
            authorUrl: "https://sarahjohnson.example.com",
            tagline: "Exploring the digital frontier"
        )
        
        // Add AWS configuration
        blog.awsRegion = "us-west-2"
        blog.awsS3Bucket = "techchronicles-blog"
        blog.awsCloudFrontDistId = "E1A2B3C4D5E6F7"
        blog.awsAccessKeyId = "AKIAEXAMPLE"
        blog.awsSecretAccessKey = "examplekey123456789"
        
        // Add categories
        let categories = [
            Category(name: "Technology", categoryDescription: "Latest tech news and reviews"),
            Category(name: "Programming", categoryDescription: "Coding tutorials and tips"),
            Category(name: "Design", categoryDescription: "UI/UX design principles")
        ]
        categories.forEach { category in
            category.blog = blog
            blog.categories.append(category)
        }
        
        // Add tags
        let tags = ["swift", "ios", "swiftui", "development", "mobile"].map { tagName in
            let tag = Tag(name: tagName)
            tag.blog = blog
            return tag
        }
        
        tags.forEach { blog.tags.append($0) }
        
        // Add posts
        let posts = [
            Post(
                title: "Getting Started with SwiftUI",
                content: "SwiftUI is Apple's modern UI framework that enables developers to design and develop user interfaces with a declarative Swift syntax. This post explores the basics of SwiftUI and how to get started with it.\n\nHere are some key concepts:\n\n- **Views**: The basic building blocks\n- **State and Binding**: For managing UI state\n- **Modifiers**: For customizing views\n\nStay tuned for more SwiftUI content!"
            ),
            Post(
                title: "Working with SwiftData",
                content: "SwiftData is Apple's powerful persistence framework introduced at WWDC 2023. It simplifies data persistence with a declarative API that works seamlessly with SwiftUI.\n\nIn this post, we'll explore:\n\n1. Setting up your data model\n2. Performing CRUD operations\n3. Integrating with SwiftUI"
            ),
            Post(
                title: nil,
                content: "Quick thought: I'm really enjoying the simplicity of SwiftData for building database-backed Swift apps. It's dramatically simpler than Core Data while maintaining most of the power.",
                isDraft: true
            )
        ]
        
        // Add post relationships
        for (index, post) in posts.enumerated() {
            post.blog = blog
            blog.posts.append(post)
            
            // Add category to some posts
            if index < categories.count {
                post.category = categories[index]
                categories[index].posts.append(post)
            }
            
            // Add some tags to each post
            for i in 0..<min(3, tags.count) {
                let tagIndex = (index + i) % tags.count
                post.tags.append(tags[tagIndex])
                tags[tagIndex].posts.append(post)
            }
            
            // Add embed to first post
            if index == 0 {
                let embed = Embed(
                    url: "https://www.youtube.com/watch?v=RoSQqtgCZss",
                    type: .youtube,
                    position: .below
                )
                embed.post = post
                post.embed = embed
            }
            
            // Add embed to second post
            if index == 1 {
                let embed = Embed(
                    url: "https://apple.com",
                    type: .link,
                    position: .above,
                    title: "Apple",
                    embedDescription: "Apple Inc. is an American multinational technology company that designs, develops, and sells consumer electronics, computer software, and online services."
                )
                embed.post = post
                post.embed = embed
            }
        }
        
        return blog
    }
    
    // MARK: - Individual Mock Entities
    
    static let post = Post(
        title: "Test Post",
        content: "This is a test post with **bold** and *italic* text."
    )
    
    static let draftPost = Post(
        title: nil,
        content: "This is a draft post without a title, showing how we handle untitled posts.",
        isDraft: true
    )
    
    static let categoryWithDescription = Category(
        name: "Technology",
        categoryDescription: "Posts about technology and innovation"
    )
    
    static let category = Category(name: "Programming")
    
    static let tag = Tag(name: "swift")
    
    static let youtubeEmbed = Embed(
        url: "https://www.youtube.com/watch?v=RoSQqtgCZss",
        type: .youtube,
        position: .above
    )
    
    static let linkEmbed = Embed(
        url: "https://apple.com",
        type: .link,
        position: .below,
        title: "Apple",
        embedDescription: "Apple Inc. is an American multinational technology company that designs, develops, and sells consumer electronics, computer software, and online services.",
        imageUrl: "https://www.apple.com/ac/structured-data/images/open_graph_logo.png"
    )
    
    // MARK: - SwiftData Preview Container
    
    /// A reusable SwiftData container for previews
    @MainActor
    static var previewContainer: ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        
        do {
            // Create the container
            let container = try ModelContainer(
                for: Blog.self, Post.self, Tag.self, Category.self, Embed.self,
                configurations: configuration
            )
            
            // Add sample data to container
            let context = container.mainContext
            
            // Create a blog with the same content as blogWithContent()
            let blog = Blog(
                name: "Tech Chronicles",
                url: "https://techchronicles.example.com",
                authorName: "Sarah Johnson",
                authorUrl: "https://sarahjohnson.example.com",
                tagline: "Exploring the digital frontier"
            )
            
            // Insert the blog into the context
            context.insert(blog)
            
            // Add AWS configuration
            blog.awsRegion = "us-west-2"
            blog.awsS3Bucket = "techchronicles-blog"
            blog.awsCloudFrontDistId = "E1A2B3C4D5E6F7"
            blog.awsAccessKeyId = "AKIAEXAMPLE"
            blog.awsSecretAccessKey = "examplekey123456789"
            
            // Add categories
            let categories = [
                Category(name: "Technology", categoryDescription: "Latest tech news and reviews"),
                Category(name: "Programming", categoryDescription: "Coding tutorials and tips"),
                Category(name: "Design", categoryDescription: "UI/UX design principles")
            ]
            
            // Insert categories and set up relationships
            for category in categories {
                context.insert(category)
                category.blog = blog
                blog.categories.append(category)
            }
            
            // Add tags
            let tagNames = ["swift", "ios", "swiftui", "development", "mobile"]
            let tags = tagNames.map { name -> Tag in
                let tag = Tag(name: name)
                context.insert(tag)
                tag.blog = blog
                blog.tags.append(tag)
                return tag
            }
            
            // Add posts
            let postData = [
                (
                    "Getting Started with SwiftUI",
                    "SwiftUI is Apple's modern UI framework that enables developers to design and develop user interfaces with a declarative Swift syntax. This post explores the basics of SwiftUI and how to get started with it.\n\nHere are some key concepts:\n\n- **Views**: The basic building blocks\n- **State and Binding**: For managing UI state\n- **Modifiers**: For customizing views\n\nStay tuned for more SwiftUI content!"
                ),
                (
                    "Working with SwiftData",
                    "SwiftData is Apple's powerful persistence framework introduced at WWDC 2023. It simplifies data persistence with a declarative API that works seamlessly with SwiftUI.\n\nIn this post, we'll explore:\n\n1. Setting up your data model\n2. Performing CRUD operations\n3. Integrating with SwiftUI"
                ),
                (
                    nil as String?,
                    "Quick thought: I'm really enjoying the simplicity of SwiftData for building database-backed Swift apps. It's dramatically simpler than Core Data while maintaining most of the power."
                )
            ]
            
            // Create and insert posts
            var posts: [Post] = []
            for (index, (title, content)) in postData.enumerated() {
                let post = Post(
                    title: title,
                    content: content,
                    isDraft: index == 2 // Mark the third post as a draft
                )
                
                context.insert(post)
                post.blog = blog
                blog.posts.append(post)
                posts.append(post)
                
                // Add category to post if available
                if index < categories.count {
                    post.category = categories[index]
                    categories[index].posts.append(post)
                }
                
                // Add tags to post
                for i in 0..<min(3, tags.count) {
                    let tagIndex = (index + i) % tags.count
                    post.tags.append(tags[tagIndex])
                    tags[tagIndex].posts.append(post)
                }
            }
            
            // Create and add embeds
            let youtubeEmbed = Embed(
                url: "https://www.youtube.com/watch?v=RoSQqtgCZss",
                type: .youtube,
                position: .below
            )
            context.insert(youtubeEmbed)
            youtubeEmbed.post = posts[0]
            posts[0].embed = youtubeEmbed
            
            let linkEmbed = Embed(
                url: "https://apple.com",
                type: .link,
                position: .above,
                title: "Apple",
                embedDescription: "Apple Inc. is an American multinational technology company that designs, develops, and sells consumer electronics, computer software, and online services."
            )
            context.insert(linkEmbed)
            linkEmbed.post = posts[1]
            posts[1].embed = linkEmbed
            
            return container
        } catch {
            fatalError("Failed to create model container: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Preview Helpers
    
    /// Wrap content in a NavigationStack for consistent previews
    static func withNavigationStack<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        NavigationStack {
            content()
        }
    }
    
    /// A wrapper view that provides a model container and entities for previews
    struct ContainerPreview<Entity, Content: View>: View {
        @ViewBuilder let content: (Entity) -> Content
        let entityProvider: (ModelContainer) -> Entity
        
        var body: some View {
            let container = previewContainer
            content(entityProvider(container))
                .modelContainer(container)
        }
    }
    
    /// Helper for creating container previews with navigation
    static func navStackPreview<Entity, Content: View>(
        entity: @escaping (ModelContainer) -> Entity,
        @ViewBuilder content: @escaping (Entity) -> Content
    ) -> some View {
        ContainerPreview(content: { entity in
            NavigationStack {
                content(entity)
            }
        }, entityProvider: entity)
    }
    
    /// Get the blog from the container for previews
    @MainActor
    static var previewBlog: Blog {
        do {
            return try previewContainer.mainContext.fetch(FetchDescriptor<Blog>()).first!
        } catch {
            fatalError("Failed to fetch preview blog: \(error)")
        }
    }
    
    /// Get a post from the container for previews
    @MainActor
    static func previewPost(at index: Int = 0) -> Post {
        do {
            let blog = try previewContainer.mainContext.fetch(FetchDescriptor<Blog>()).first!
            return blog.posts[index]
        } catch {
            fatalError("Failed to fetch preview post: \(error)")
        }
    }
    
    /// Get an embed from a post
    @MainActor
    static func previewEmbed(at postIndex: Int = 0) -> Embed? {
        previewPost(at: postIndex).embed
    }
}

/// Builder for creating consistent previews
struct PreviewBuilder {
    /// Create a preview with a standalone entity
    static func entityPreview<Entity, Content: View>(
        entity: Entity,
        @ViewBuilder content: @escaping (Entity) -> Content
    ) -> some View {
        content(entity)
    }
    
    /// Create a preview with a container-based entity
    static func containerPreview<Entity, Content: View>(
        entity: @escaping () -> Entity,
        @ViewBuilder content: @escaping (Entity) -> Content
    ) -> some View {
        NavigationStack {
            content(entity())
        }
        .modelContainer(PreviewData.previewContainer)
    }
}