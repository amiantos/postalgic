//
//  PostSettingsView.swift
//  Postalgic
//
//  Created by Brad Root on 4/23/25.
//

import SwiftData
import SwiftUI
struct PostSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allTags: [Tag]
    @Query private var allCategories: [Category]
    
    var blog: Blog
    var post: Post
    
    private var blogTags: [Tag] {
        return allTags.filter { $0.blog?.id == blog.id }
    }
    
    private var blogCategories: [Category] {
        return allCategories.filter { $0.blog?.id == blog.id }
    }
    
    @State private var tagInput = ""
    @State private var selectedTags: [Tag] = []
    @State private var selectedCategory: Category?
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

    init(post: Post, blog: Blog) {
        self.blog = blog
        self.post = post

        _selectedTags = State(initialValue: post.tags)
        _selectedCategory = State(initialValue: post.category)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Embed") {
                    if let embed = post.embed {
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
                                if let embed = post.embed {
                                    modelContext.delete(embed)
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
            .navigationTitle("Post Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close") {
                        updatePost()
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingCategoryManagement) {
                CategoryManagementView(blog: blog)
            }
            .sheet(isPresented: $showingEmbedForm) {
                EmbedFormView(post: post) { embedTitle in
                    // Update the post title with the embed title
//                    title = embedTitle
                }
            }
        }
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
                let newTag = Tag(blog: blog, name: trimmed)
                modelContext.insert(newTag)
                blog.tags.append(newTag)
                selectedTags.append(newTag)
            }
            tagInput = ""
        }
    }
    
    private func updatePost() {
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
}

