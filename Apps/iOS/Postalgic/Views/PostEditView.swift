//
//  PostEditView.swift
//  Postalgic
//
//  Created by Brad Root on 4/21/25.
//

import SwiftUI
import SwiftData

struct PostEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allTags: [Tag]
    @Query private var allCategories: [Category]
    
    var post: Post
    
    private var blog: Blog? {
        return post.blog
    }
    
    private var blogTags: [Tag] {
        guard let blogId = blog?.id else { return [] }
        return allTags.filter { $0.blog?.id == blogId }
    }
    
    private var blogCategories: [Category] {
        guard let blogId = blog?.id else { return [] }
        return allCategories.filter { $0.blog?.id == blogId }
    }
    
    @State private var title: String
    @State private var content: String
    @State private var primaryLink: String
    @State private var tagInput = ""
    @State private var selectedTags: [Tag] = []
    @State private var selectedCategory: Category?
    @State private var isDraft: Bool
    @State private var showingCategoryManagement = false
    @State private var showingSuggestions = false
    
    private var existingTagNames: [String] {
        return blogTags.map { $0.name }
    }
    
    private var filteredTags: [Tag] {
        if tagInput.isEmpty {
            return blogTags.sorted { $0.name.lowercased() < $1.name.lowercased() }
        } else {
            let lowercasedInput = tagInput.lowercased()
            return blogTags.filter { $0.name.lowercased().contains(lowercasedInput) }
                .sorted { $0.name.lowercased() < $1.name.lowercased() }
        }
    }
    
    init(post: Post) {
        self.post = post
        _title = State(initialValue: post.title ?? "")
        _content = State(initialValue: post.content)
        _primaryLink = State(initialValue: post.primaryLink ?? "")
        _isDraft = State(initialValue: post.isDraft)
        _selectedTags = State(initialValue: post.tags)
        _selectedCategory = State(initialValue: post.category)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Post Details") {
                    TextField("Title (optional)", text: $title)
                    TextField("Primary Link (optional)", text: $primaryLink)
                    Toggle("Save as Draft", isOn: $isDraft)
                        .tint(Color("PPink"))
                    
                    HStack {
                        Picker("Category", selection: $selectedCategory) {
                            Text("None").tag(Category?.none)
                            
                            if !blogCategories.isEmpty {
                                Divider()
                                
                                ForEach(blogCategories.sorted { $0.name < $1.name }) { category in
                                    Text(category.name).tag(Optional(category))
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Button(action: {
                            showingCategoryManagement = true
                        }) {
                            Image(systemName: "gear")
                        }
                    }
                }
                
                Section("Content") {
                    TextEditor(text: $content)
                        .frame(minHeight: 200)
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
                                        if !selectedTags.contains(where: { $0.id == tag.id }) {
                                            selectedTags.append(tag)
                                        }
                                        tagInput = ""
                                        showingSuggestions = false
                                    }) {
                                        Text(tag.name)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(Color.secondary.opacity(0.2))
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
                                            selectedTags.removeAll { $0.id == tag.id }
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
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
            .navigationTitle("Edit Post")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        updatePost()
                        dismiss()
                    }
                    .disabled(content.isEmpty)
                }
            }
            .sheet(isPresented: $showingCategoryManagement) {
                if let blog = blog {
                    CategoryManagementView(blog: blog)
                }
            }
        }
    }
    
    private func addTag() {
        let trimmed = tagInput.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !trimmed.isEmpty, let blog = blog {
            // Check if tag already exists for this blog (case insensitive)
            if let existingTag = blogTags.first(where: { $0.name.lowercased() == trimmed }) {
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
        // Update post properties
        post.title = title.isEmpty ? nil : title
        post.content = content
        post.primaryLink = primaryLink.isEmpty ? nil : primaryLink
        post.isDraft = isDraft
        
        // Handle category changes
        if post.category != selectedCategory {
            // Remove post from previous category
            if let oldCategory = post.category {
                if let index = oldCategory.posts.firstIndex(where: { $0.id == post.id }) {
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
}

#Preview {
    PostEditView(post: Post(title: "Test Post", content: "This is a test post with **bold** and *italic* text."))
        .modelContainer(for: [Post.self, Tag.self, Category.self, Blog.self], inMemory: true)
}