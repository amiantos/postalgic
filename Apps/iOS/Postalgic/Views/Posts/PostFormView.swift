//
//  PostFormView.swift
//  Postalgic
//
//  Created by Brad Root on 4/23/25.
//

import SwiftData
import SwiftUI
struct PostFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allTags: [Tag]
    @Query private var allCategories: [Category]
    
    // Either blog (for new post) or post (for editing) will be set
    var blog: Blog?
    var post: Post?
    var isEditing: Bool
    
    private var currentBlog: Blog? {
        return isEditing ? post?.blog : blog
    }
    
    private var blogTags: [Tag] {
        guard let blogId = currentBlog?.id else { return [] }
        return allTags.filter { $0.blog?.id == blogId }
    }
    
    private var blogCategories: [Category] {
        guard let blogId = currentBlog?.id else { return [] }
        return allCategories.filter { $0.blog?.id == blogId }
    }
    
    @State private var title: String
    @State private var content: String
    @State private var tagInput = ""
    @State private var selectedTags: [Tag] = []
    @State private var selectedCategory: Category?
    @State private var isDraft: Bool
    @State private var showingCategoryManagement = false
    @State private var showingSuggestions = false
    @State private var showingEmbedForm = false
    @State private var newPost: Post? = nil
    @State private var showingPublishAlert = false
    @State private var showingPublishView = false
    @State private var savedPost: Post? = nil
    
    private var existingTagNames: [String] {
        return blogTags.map { $0.name }
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
    
    // Initialize for new post
    init(blog: Blog) {
        self.blog = blog
        self.post = nil
        self.isEditing = false
        
        _title = State(initialValue: "")
        _content = State(initialValue: "")
        _isDraft = State(initialValue: false)
    }
    
    // Initialize for editing post
    init(post: Post) {
        self.blog = nil
        self.post = post
        self.isEditing = true
        
        _title = State(initialValue: post.title ?? "")
        _content = State(initialValue: post.content)
        _isDraft = State(initialValue: post.isDraft)
        _selectedTags = State(initialValue: post.tags)
        _selectedCategory = State(initialValue: post.category)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Post Content") {
                    TextField("Title (optional)", text: $title)
                    TextEditor(text: $content)
                        .frame(minHeight: 200)
                    Toggle("Save as Draft", isOn: $isDraft)
                }
                
                Section("Embed") {
                    if let postToUse = isEditing ? post : newPost, let embed = postToUse.embed {
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
                                if let embed = postToUse.embed {
                                    modelContext.delete(embed)
                                    postToUse.embed = nil
                                }
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
                            // Create a temporary post if needed for new posts
                            if !isEditing && newPost == nil {
                                newPost = Post(
                                    title: title.isEmpty ? nil : title,
                                    content: content,
                                    isDraft: isDraft
                                )
                                modelContext.insert(newPost!)
                            }
                            showingEmbedForm = true
                        }) {
                            Label("Add Embed", systemImage: "plus")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.blue)
                    }
                }
                
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
            .navigationTitle(isEditing ? "Edit Post" : "Create New Post")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if isEditing {
                            updatePost()
                            if !isDraft {
                                savedPost = post
                                showingPublishAlert = true
                            } else {
                                dismiss()
                            }
                        } else {
                            addPost()
                            if !isDraft {
                                showingPublishAlert = true
                            } else {
                                dismiss()
                            }
                        }
                    }
                    .disabled(content.isEmpty)
                }
            }
            .sheet(isPresented: $showingCategoryManagement) {
                if let blog = currentBlog {
                    CategoryManagementView(blog: blog)
                }
            }
            .sheet(isPresented: $showingEmbedForm) {
                if isEditing, let post = post {
                    EmbedFormView(post: post) { embedTitle in
                        // Update the post title with the embed title
                        title = embedTitle
                    }
                } else if let post = newPost {
                    EmbedFormView(post: post) { embedTitle in
                        // Update the post title with the embed title
                        title = embedTitle
                    }
                }
            }
            .sheet(isPresented: $showingPublishView, onDismiss: {
                dismiss()
            }) {
                if let post = savedPost, let blog = post.blog {
                    PublishBlogView(blog: blog, autoPublish: true)
                }
            }
            .alert("Publish Now?", isPresented: $showingPublishAlert) {
                Button("No", role: .cancel) {
                    dismiss()
                }
                Button("Yes") {
                    showingPublishView = true
                }
            } message: {
                Text("Would you like to publish the blog now?")
            }
        }
    }
    
    private func addTag() {
        let trimmed = tagInput.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if !trimmed.isEmpty, let blog = currentBlog {
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
    
    private func updatePost() {
        guard let post = post else { return }
        
        // Update post properties
        post.title = title.isEmpty ? nil : title
        post.content = content
        post.isDraft = isDraft
        
        // Handle category changes
        if post.category != selectedCategory {
            // Remove post from previous category
            if let oldCategory = post.category {
                if let index = oldCategory.posts.firstIndex(where: {
                    $0.id == post.id
                }) {
                    oldCategory.posts.remove(at: index)
                }
            }
            
            // Add post to new category
            post.category = selectedCategory
            if let newCategory = selectedCategory {
                newCategory.posts.append(post)
            }
        }
        
        // Handle tag changes
        // First, remove all existing tag relationships
        for tag in post.tags {
            if let index = tag.posts.firstIndex(where: { $0.id == post.id }) {
                tag.posts.remove(at: index)
            }
        }
        
        // Clear post's tags array
        post.tags.removeAll()
        
        // Now add all selected tags
        for tag in selectedTags {
            post.tags.append(tag)
            tag.posts.append(post)
        }
    }
    
    private func addPost() {
        guard let blog = blog else { return }
        
        var postToSave: Post
        
        if let existingPost = newPost {
            // Update the temporary post
            existingPost.title = title.isEmpty ? nil : title
            existingPost.content = content
            existingPost.isDraft = isDraft
            postToSave = existingPost
        } else {
            // Create a new post
            postToSave = Post(
                title: title.isEmpty ? nil : title,
                content: content,
                isDraft: isDraft
            )
            modelContext.insert(postToSave)
        }
        
        // Add category to post if selected
        if let category = selectedCategory {
            postToSave.category = category
            category.posts.append(postToSave)
        }
        
        // Add tags to post
        for tag in selectedTags {
            postToSave.tags.append(tag)
            tag.posts.append(postToSave)
        }
        
        // Add to blog
        blog.posts.append(postToSave)
        
        // Save reference to the post for publishing
        savedPost = postToSave
    }
}

#Preview("New Post") {
    let modelContainer = PreviewData.previewContainer
    
    return NavigationStack {
        // Fetch the first blog from the container to ensure it's properly in the context
        PostFormView(blog: try! modelContainer.mainContext.fetch(FetchDescriptor<Blog>()).first!)
    }
    .modelContainer(modelContainer)
}

#Preview("Edit Post") {
    let modelContainer = PreviewData.previewContainer
    let blog = try! modelContainer.mainContext.fetch(FetchDescriptor<Blog>()).first!
    
    return NavigationStack {
        // Use the first post from the blog that's in the context
        PostFormView(post: blog.posts.first!)
    }
    .modelContainer(modelContainer)
}

