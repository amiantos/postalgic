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
        url: "",
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
        blog.publisherType = "AWS"
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
                    post: post,
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
                    post: post,
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
        post: post,
        url: "https://www.youtube.com/watch?v=RoSQqtgCZss",
        type: .youtube,
        position: .above
    )
    
    static let linkEmbed = Embed(
        post: post,
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
            
            // Create a blog with categories for our previews
            let blog = Blog(
                name: "Preview Blog", 
                url: "https://example.com",
                authorName: "John Doe"
            )
            context.insert(blog)
            
            let blog2 = Blog(
                name: "Preview Blog",
                url: "",
                authorName: "John Doe"
            )
            context.insert(blog2)
            
            // Add 3 categories with proper relationships
            let categoryNames = ["Technology", "Programming", "Design"]
            let categories = categoryNames.map { name -> Category in
                let category = Category(name: name, categoryDescription: "Description for \(name.lowercased())")
                context.insert(category)
                
                // Set up bi-directional relationship
                category.blog = blog
                blog.categories.append(category)
                
                return category
            }
            
            // Add tags
            let tagNames = ["swift", "ios", "swiftui"]
            let tags = tagNames.map { name -> Tag in
                let tag = Tag(name: name)
                context.insert(tag)
                
                // Set up bi-directional relationship
                tag.blog = blog
                blog.tags.append(tag)
                
                return tag
            }
            
            // Add a few posts with categories and tags
            for i in 1...3 {
                let post = Post(
                    title: "Post \(i)", 
                    content: "Content for post \(i). SwiftUI is Apple's modern UI framework that enables developers to design and develop user interfaces with a declarative Swift syntax. This post explores the basics of SwiftUI and how to get started with it.\n\nHere are some key concepts:\n\n- **Views**: The basic building blocks\n- **State and Binding**: For managing UI state\n- **Modifiers**: For customizing views\n\nStay tuned for more SwiftUI content!"
                )
                context.insert(post)
                
                // Set blog relationship
                post.blog = blog
                blog.posts.append(post)
                
                // Set category (if available) with circular reference
                if i <= categories.count {
                    post.category = categories[i-1]
                    categories[i-1].posts.append(post)
                }
                
                // Add some tags
                for j in 0..<min(2, tags.count) {
                    let tagIndex = (i + j) % tags.count
                    post.tags.append(tags[tagIndex])
                    tags[tagIndex].posts.append(post)
                }
            }
            
            try? context.save()
            
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
}
