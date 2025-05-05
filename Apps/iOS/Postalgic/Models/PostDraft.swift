import Foundation

/// A non-SwiftData abstraction of a Post used for creating new posts without immediately persisting them
struct PostDraft {
    var title: String?
    var content: String
    var isDraft: Bool
    var tags: [Tag] = []
    var category: Category?
    var embed: EmbedDraft?
    var createdAt: Date
    
    init(
        title: String? = nil,
        content: String = "",
        isDraft: Bool = false,
        createdAt: Date = Date()
    ) {
        self.title = title
        self.content = content
        self.isDraft = isDraft
        self.createdAt = createdAt
    }
    
    /// Convert this draft to a persistent Post object
    func toPost() -> Post {
        let post = Post(
            title: title,
            content: content,
            createdAt: createdAt,
            isDraft: isDraft
        )
        
        // Add category if set
        post.category = category
        if let category = category {
            category.posts.append(post)
        }
        
        // Add tags if set
        for tag in tags {
            post.tags.append(tag)
            tag.posts.append(post)
        }
        
        // Add embed if set
        if let embedDraft = embed {
            let embed = embedDraft.toEmbed()
            post.embed = embed
            embed.post = post
        }
        
        return post
    }
}