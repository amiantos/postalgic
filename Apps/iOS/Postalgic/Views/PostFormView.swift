//
//  PostFormView.swift
//  Postalgic
//
//  Created by Brad Root on 4/19/25.
//

import SwiftUI
import SwiftData

struct PostFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allTags: [Tag]
    
    var blog: Blog
    
    @State private var title = ""
    @State private var content = ""
    @State private var primaryLink = ""
    @State private var tagInput = ""
    @State private var selectedTags: [Tag] = []
    @State private var showingSuggestions = false
    
    private var existingTagNames: [String] {
        return allTags.map { $0.name }
    }
    
    private var filteredTags: [Tag] {
        if tagInput.isEmpty {
            return allTags.sorted { $0.name.lowercased() < $1.name.lowercased() }
        } else {
            let lowercasedInput = tagInput.lowercased()
            return allTags.filter { $0.name.lowercased().contains(lowercasedInput) }
                .sorted { $0.name.lowercased() < $1.name.lowercased() }
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Post Details") {
                    TextField("Title (optional)", text: $title)
                    TextField("Primary Link (optional)", text: $primaryLink)
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
            .navigationTitle("New Post")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        addPost()
                        dismiss()
                    }
                    .disabled(content.isEmpty)
                }
            }
        }
    }
    
    private func addTag() {
        let trimmed = tagInput.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !trimmed.isEmpty {
            // Check if tag already exists (case insensitive)
            if let existingTag = allTags.first(where: { $0.name.lowercased() == trimmed }) {
                if !selectedTags.contains(where: { $0.id == existingTag.id }) {
                    selectedTags.append(existingTag)
                }
            } else {
                // Create new tag (always lowercase)
                let newTag = Tag(name: trimmed)
                modelContext.insert(newTag)
                selectedTags.append(newTag)
            }
            tagInput = ""
        }
    }
    
    private func addPost() {
        let newPost = Post(
            title: title.isEmpty ? nil : title,
            content: content,
            primaryLink: primaryLink.isEmpty ? nil : primaryLink
        )
        
        // Add tags to post
        for tag in selectedTags {
            newPost.tags.append(tag)
            tag.posts.append(newPost)
        }
        
        modelContext.insert(newPost)
        blog.posts.append(newPost)
    }
}

#Preview {
    PostFormView(blog: Blog(name: "Test Blog", url: "https://example.com"))
        .modelContainer(for: [Blog.self, Post.self, Tag.self], inMemory: true)
}
