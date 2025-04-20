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
    @Query private var allPosts: [Post]
    
    var blog: Blog
    
    @State private var title = ""
    @State private var content = ""
    @State private var primaryLink = ""
    @State private var tagInput = ""
    @State private var selectedTags: [String] = []
    @State private var showingSuggestions = false
    
    private var existingTags: [String] {
        // Get unique tags from all posts
        var allTags = Set<String>()
        for post in allPosts {
            for tag in post.tags {
                allTags.insert(tag)
            }
        }
        return Array(allTags).sorted()
    }
    
    private var filteredSuggestions: [String] {
        if tagInput.isEmpty {
            return existingTags
        } else {
            return existingTags.filter { $0.localizedCaseInsensitiveContains(tagInput) }
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
                            .onChange(of: tagInput) {
                                showingSuggestions = !tagInput.isEmpty
                            }
                        
                        Button(action: addTag) {
                            Image(systemName: "plus.circle.fill")
                        }
                        .disabled(tagInput.isEmpty)
                    }
                    
                    if showingSuggestions && !filteredSuggestions.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(filteredSuggestions, id: \.self) { suggestion in
                                    Button(action: {
                                        if !selectedTags.contains(suggestion) {
                                            selectedTags.append(suggestion)
                                        }
                                        tagInput = ""
                                        showingSuggestions = false
                                    }) {
                                        Text(suggestion)
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
                                ForEach(selectedTags, id: \.self) { tag in
                                    HStack(spacing: 5) {
                                        Text(tag)
                                        Button(action: {
                                            selectedTags.removeAll { $0 == tag }
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
        let trimmed = tagInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && !selectedTags.contains(trimmed) {
            selectedTags.append(trimmed)
            tagInput = ""
        }
    }
    
    private func addPost() {
        let newPost = Post(
            title: title.isEmpty ? nil : title,
            content: content,
            primaryLink: primaryLink.isEmpty ? nil : primaryLink,
            tags: selectedTags
        )
        modelContext.insert(newPost)
        blog.posts.append(newPost)
    }
}

#Preview {
    PostFormView(blog: Blog(name: "Test Blog", url: "https://example.com"))
        .modelContainer(for: [Blog.self, Post.self], inMemory: true)
}
