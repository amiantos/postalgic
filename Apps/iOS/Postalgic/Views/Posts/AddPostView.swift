import SwiftUI
import UIKit
import SwiftData

struct AddPostView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allTags: [Tag]
    @Query private var allCategories: [Category]
    
    // The blog to add the post to
    let blog: Blog
    
    // Content state
    @State private var title: String = ""
    @State private var content: String = ""
    @State private var isDraft: Bool = true
    
    // Categories and tags
    @State private var selectedCategory: Category? = nil
    @State private var selectedTags: [Tag] = []
    
    // Embed
    @State private var embed: Embed? = nil
    
    // UI State
    @State private var showURLPrompt: Bool = false
    @State private var urlText: String = ""
    @State private var urlLink: String = ""
    @State private var showingFullSettings: Bool = false
    @State private var showingCategoryManagement: Bool = false
    @State private var showingTagManagement: Bool = false
    @State private var showingEmbedForm: Bool = false
    @State private var showPublishView: Bool = false
    @State private var tagInput: String = ""
    @State private var showingSuggestions: Bool = false
    
    // Reference to the created post (only set when saving/publishing)
    @State private var createdPost: Post? = nil
    
    private var blogTags: [Tag] {
        return allTags.filter { $0.blog?.id == blog.id }
    }
    
    private var blogCategories: [Category] {
        return allCategories.filter { $0.blog?.id == blog.id }
    }
    
    private var filteredTags: [Tag] {
        if tagInput.isEmpty {
            return blogTags.sorted {
                $0.name.lowercased() < $1.name.lowercased()
            }
        } else {
            let lowercasedInput = tagInput.lowercased()
            return blogTags.filter {
                $0.name.lowercased().contains(lowercasedInput)
            }
            .sorted { $0.name.lowercased() < $1.name.lowercased() }
        }
    }
    
    var body: some View {
        NavigationStack {
            // Main editing view (when not showing full settings)
            if !showingFullSettings {
                VStack(spacing: 0) {
                    TextField("Title (optional)", text: $title)
                        .font(.title)
                        .padding()
                    
                    Divider()
                    
                    MarkdownTextEditor(text: $content, onShowLinkPrompt: { selectedText, selectedRange in
                        self.handleShowLinkPrompt(selectedText: selectedText, selectedRange: selectedRange)
                    })
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .navigationTitle("New Post")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    // Leading toolbar items
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") {
                            // Clean up created post if we made one
                            if let tempPost = createdPost {
                                modelContext.delete(tempPost)
                                
                                // Also remove from blog's posts array
                                if let index = blog.posts.firstIndex(where: { $0.id == tempPost.id }) {
                                    blog.posts.remove(at: index)
                                }
                            }
                            dismiss()
                        }
                    }
                    
                    // Trailing toolbar items
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button(action: {
                                showingFullSettings = true
                            }) {
                                Label("Post Settings", systemImage: "gear")
                            }.disabled(content.isEmpty)
                            
                            Button(action: {
                                savePost(asDraft: true)
                                dismiss()
                            }) {
                                Label("Save as Draft", systemImage: "square.and.arrow.down")
                            }.disabled(content.isEmpty)
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                    
                    ToolbarItem(placement: .primaryAction) {
                        Button("Publish") {
                            savePost(asDraft: false)
                            showPublishView = true
                        }
                        .disabled(content.isEmpty)
                    }
                }
            }
            // Full settings view
            else {
                Form {
                    Section("Content") {
                        TextField("Title (optional)", text: $title)
                        
                        NavigationLink(destination: 
                            VStack {
                                MarkdownTextEditor(text: $content, onShowLinkPrompt: { selectedText, selectedRange in
                                    self.handleShowLinkPrompt(selectedText: selectedText, selectedRange: selectedRange)
                                })
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                            .navigationTitle("Edit Content")
                        ) {
                            VStack(alignment: .leading) {
                                Text("Content")
                                    .font(.headline)
                                
                                if content.isEmpty {
                                    Text("No content")
                                        .foregroundColor(.secondary)
                                        .italic()
                                } else {
                                    Text(content)
                                        .foregroundColor(.secondary)
                                        .lineLimit(3)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    
                    // Embed Section
                    Section("Embed") {
                        if let embed = embed {
                            VStack(alignment: .leading, spacing: 12) {
                                // Embed info row
                                HStack {
                                    Text("Type:").bold()
                                    Text(embed.embedType.rawValue)
                                        .foregroundColor(.secondary)
                                }
                                
                                HStack {
                                    Text("Position:").bold()
                                    Text(embed.embedPosition.rawValue)
                                        .foregroundColor(.secondary)
                                }
                                
                                HStack {
                                    Text("URL:").bold()
                                    Text(embed.url)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                
                                // Buttons in separate rows for clarity
                                Button(action: {
                                    showingEmbedForm = true
                                }) {
                                    HStack {
                                        Image(systemName: "pencil")
                                        Text("Edit Embed")
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .tint(.blue)
                                
                                Button(action: {
                                    embed = nil
                                }) {
                                    HStack {
                                        Image(systemName: "trash")
                                        Text("Remove Embed")
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .tint(.red)
                            }
                        } else {
                            Button(action: {
                                showingEmbedForm = true
                            }) {
                                Label("Add Embed", systemImage: "plus")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(.blue)
                        }
                    }
                    
                    // Category section
                    Section("Category") {
                        Picker("Category", selection: $selectedCategory) {
                            Text("None").tag(Category?.none)
                            
                            if !blogCategories.isEmpty {
                                Divider()
                                
                                ForEach(
                                    blogCategories.sorted { $0.name < $1.name }
                                ) { category in
                                    Text(category.name).tag(Optional(category))
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Button(action: {
                            showingCategoryManagement = true
                        }) {
                            Text("Manage Categories")
                        }
                    }
                    
                    // Tags section
                    Section("Tags") {
                        HStack {
                            TextField("Add tags...", text: $tagInput)
                                .autocorrectionDisabled()
                                .onSubmit {
                                    addTag()
                                }
                                .onChange(of: tagInput) { _, newValue in
                                    // Keep the input lowercase while typing
                                    let lowercased = newValue.lowercased()
                                    if lowercased != newValue {
                                        tagInput = lowercased
                                    }
                                    showingSuggestions = true
                                }
                            
                            Button(action: addTag) {
                                Image(systemName: "plus.circle.fill")
                            }
                            .disabled(tagInput.isEmpty)
                        }
                        
                        if showingSuggestions && !filteredTags.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack {
                                    ForEach(filteredTags) { tag in
                                        Button(action: {
                                            if !selectedTags.contains(where: {
                                                $0.id == tag.id
                                            }) {
                                                selectedTags.append(tag)
                                            }
                                            tagInput = ""
                                            showingSuggestions = false
                                        }) {
                                            Text(tag.name)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 5)
                                                .background(
                                                    Color.secondary.opacity(0.2)
                                                )
                                                .cornerRadius(8)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.vertical, 5)
                            }
                        }
                        
                        if !selectedTags.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack {
                                    ForEach(selectedTags) { tag in
                                        HStack(spacing: 5) {
                                            Text(tag.name)
                                            Button(action: {
                                                selectedTags.removeAll {
                                                    $0.id == tag.id
                                                }
                                            }) {
                                                Image(
                                                    systemName: "xmark.circle.fill"
                                                )
                                                .font(.caption)
                                            }
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Color.blue.opacity(0.2))
                                        .cornerRadius(8)
                                    }
                                }
                                .padding(.vertical, 5)
                            }
                        }
                    }
                }
                .navigationTitle("Post Settings")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Back") {
                            showingFullSettings = false
                        }
                    }
                    
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            showingFullSettings = false
                        }
                    }
                }
            }
        }
        .alert("Add Link", isPresented: $showURLPrompt) {
            TextField("Text", text: $urlText)
            TextField("URL", text: $urlLink)
            Button("Cancel", role: .cancel) {}
            Button("Add") {
                insertLink()
            }
        } message: {
            Text("Enter link details")
        }
        .sheet(isPresented: $showingCategoryManagement) {
            CategoryManagementView(blog: blog)
        }
        .sheet(isPresented: $showingTagManagement) {
            TagManagementView(blog: blog)
        }
        .sheet(isPresented: $showingEmbedForm) {
            // Create a temporary post to use with EmbedFormView
            let tempPost = Post(title: title, content: content)
            tempPost.embed = embed
            
            EmbedFormView(post: tempPost) { updatedEmbed in 
                // Save the embed
                self.embed = updatedEmbed
            }
        }
        .sheet(isPresented: $showPublishView, onDismiss: {
            dismiss()
        }) {
            PublishBlogView(blog: blog, autoPublish: true)
        }
    }
    
    private func savePost(asDraft: Bool) -> Post {
        // If we already have a post, update it
        if let existingPost = createdPost {
            updatePost(existingPost, asDraft: asDraft)
            return existingPost
        }
        
        // Otherwise create a new one
        let newPost = Post(
            title: title.isEmpty ? nil : title,
            content: content,
            isDraft: asDraft
        )
        
        // Set the blog reference and add to blog's posts
        newPost.blog = blog
        blog.posts.append(newPost)
        
        // Add category if selected
        if let category = selectedCategory {
            newPost.category = category
            category.posts.append(newPost)
        }
        
        // Add tags
        for tag in selectedTags {
            newPost.tags.append(tag)
            tag.posts.append(newPost)
        }
        
        // Add embed if available
        if let embed = embed {
            newPost.embed = embed
            embed.post = newPost
        }
        
        // Insert into model context
        modelContext.insert(newPost)
        newPost.regenerateStub()
        
        // Update reference
        createdPost = newPost
        
        return newPost
    }
    
    private func updatePost(_ post: Post, asDraft: Bool) {
        // Update basic properties
        post.title = title.isEmpty ? nil : title
        post.content = content
        post.isDraft = asDraft
        
        // Update category
        if post.category != selectedCategory {
            // Remove from previous category
            if let oldCategory = post.category {
                if let index = oldCategory.posts.firstIndex(where: { $0.id == post.id }) {
                    oldCategory.posts.remove(at: index)
                }
            }
            
            // Add to new category
            post.category = selectedCategory
            if let newCategory = selectedCategory {
                newCategory.posts.append(post)
            }
        }
        
        // Update tags
        // First remove all existing tag relationships
        for tag in post.tags {
            if let index = tag.posts.firstIndex(where: { $0.id == post.id }) {
                tag.posts.remove(at: index)
            }
        }
        post.tags.removeAll()
        
        // Add new tags
        for tag in selectedTags {
            post.tags.append(tag)
            tag.posts.append(post)
        }
        
        // Update embed
        if post.embed != embed {
            // Delete old embed if it exists
            if let oldEmbed = post.embed {
                modelContext.delete(oldEmbed)
            }
            
            // Assign new embed if available
            post.embed = embed
            if let newEmbed = embed {
                newEmbed.post = post
            }
        }
        
        // Update stub
        post.regenerateStub()
    }
    
    private func addTag() {
        let trimmed = tagInput.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if !trimmed.isEmpty {
            // Check if tag already exists for this blog (case insensitive)
            if let existingTag = blogTags.first(where: {
                $0.name.lowercased() == trimmed
            }) {
                if !selectedTags.contains(where: { $0.id == existingTag.id }) {
                    selectedTags.append(existingTag)
                }
            } else {
                // Create new tag (always lowercase)
                let newTag = Tag(name: trimmed)
                modelContext.insert(newTag)
                newTag.blog = blog
                blog.tags.append(newTag)
                selectedTags.append(newTag)
            }
            tagInput = ""
        }
    }
    
    func handleShowLinkPrompt(selectedText: String?, selectedRange: NSRange?) {
        if let text = selectedText, !text.isEmpty {
            // Text is selected
            urlText = text
            
            // Check clipboard for URL
            if let clipboardString = UIPasteboard.general.string,
               let url = URL(string: clipboardString),
               UIApplication.shared.canOpenURL(url) {
                
                // Use clipboard URL
                urlLink = clipboardString
                insertLink()
            } else {
                // No URL in clipboard, show prompt for URL
                urlLink = ""
                showURLPrompt = true
            }
        } else {
            // No text selected, prompt for both text and URL
            urlText = ""
            urlLink = ""
            showURLPrompt = true
        }
    }
    
    func insertLink() {
        guard !urlText.isEmpty else { return }
        
        let markdownLink = "[\(urlText)](\(urlLink))"
        let notification = Notification(name: Notification.Name("InsertMarkdownLink"), 
                                        object: nil, 
                                        userInfo: ["text": markdownLink])
        NotificationCenter.default.post(notification)
    }
}

#Preview {
    let modelContainer = PreviewData.previewContainer
    let blog = try! modelContainer.mainContext.fetch(FetchDescriptor<Blog>()).first!
    
    return NavigationStack {
        AddPostView(blog: blog)
    }
    .modelContainer(modelContainer)
}