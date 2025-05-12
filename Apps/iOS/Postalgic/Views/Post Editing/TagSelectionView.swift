//
//  TagSelectionView.swift
//  Postalgic
//
//  Created by Claude on 5/11/25.
//

import SwiftData
import SwiftUI

struct TagSelectionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    var blog: Blog
    var post: Post
    
    @Query(sort: \Tag.name) private var tags: [Tag]
    
    @State private var showingAddTag = false
    @State private var selectedTags: [Tag] = []
    @State private var tagInput = ""
    @State private var showingSuggestions = false
    
    // Filtered tags for the search input
    private var filteredTags: [Tag] {
        if tagInput.isEmpty {
            return tags.sorted { $0.name.lowercased() < $1.name.lowercased() }
        } else {
            let lowercasedInput = tagInput.lowercased()
            return tags.filter { $0.name.lowercased().contains(lowercasedInput) }
                .sorted { $0.name.lowercased() < $1.name.lowercased() }
        }
    }
    
    init(blog: Blog, post: Post) {
        self.blog = blog
        self.post = post
        self._selectedTags = State(initialValue: post.tags)
        
        // Configure the query to fetch all tags for this blog
        let id = blog.persistentModelID
        let tagPredicate = #Predicate<Tag> { tag in
            tag.blog?.persistentModelID == id
        }
        
        self._tags = Query(filter: tagPredicate)
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                // Tag search/input field
                HStack {
                    TextField("Add tags...", text: $tagInput)
                        .autocorrectionDisabled()
                        .padding(.horizontal)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .padding(.trailing, 8)
                        .onSubmit {
                            addTag()
                        }
                        .onChange(of: tagInput) { _, newValue in
                            // Keep the input lowercase while typing
                            let lowercased = newValue.lowercased()
                            if lowercased != newValue {
                                tagInput = lowercased
                            }
                            showingSuggestions = !newValue.isEmpty
                        }
                    
                    Button(action: addTag) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                    .disabled(tagInput.isEmpty)
                }
                .padding(.horizontal)
                .padding(.top)
                
                // Selected tags section
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
                        .padding(.horizontal)
                    }
                    .frame(height: 40)
                }
                
                // Main tag list
                List {
                    if showingSuggestions && !filteredTags.isEmpty {
                        Section("Suggestions") {
                            ForEach(filteredTags) { tag in
                                Button(action: {
                                    if !selectedTags.contains(where: { $0.id == tag.id }) {
                                        selectedTags.append(tag)
                                    }
                                    tagInput = ""
                                    showingSuggestions = false
                                }) {
                                    HStack {
                                        Text(tag.name)
                                        Spacer()
                                        if selectedTags.contains(where: { $0.id == tag.id }) {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.blue)
                                        }
                                    }
                                }
                                .foregroundColor(.primary)
                            }
                        }
                    }
                    
                    Section("All Tags") {
                        if tags.isEmpty {
                            Text("No tags yet. Add some to help organize your blog's content.")
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical)
                        } else {
                            ForEach(tags.sorted { $0.name < $1.name }) { tag in
                                Button {
                                    toggleTagSelection(tag)
                                } label: {
                                    HStack {
                                        TagRowView(tag: tag)
                                        Spacer()
                                        if selectedTags.contains(where: { $0.id == tag.id }) {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.blue)
                                        }
                                    }
                                }
                                .foregroundColor(.primary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Tags")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddTag = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddTag) {
                AddTagView(blog: blog)
                    .interactiveDismissDisabled()
                    .onDisappear {
                        // Force refresh the View to see the new tag
                        // This happens automatically due to the @Query property wrapper
                    }
            }
        }
    }
    
    private func toggleTagSelection(_ tag: Tag) {
        if let index = selectedTags.firstIndex(where: { $0.id == tag.id }) {
            selectedTags.remove(at: index)
        } else {
            selectedTags.append(tag)
        }
        // Automatically apply the change
        updatePostTags()
    }
    
    private func addTag() {
        let trimmed = tagInput.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !trimmed.isEmpty {
            // Check if tag already exists for this blog (case insensitive)
            if let existingTag = tags.first(where: { $0.name.lowercased() == trimmed }) {
                if !selectedTags.contains(where: { $0.id == existingTag.id }) {
                    selectedTags.append(existingTag)
                    // Apply change immediately
                    updatePostTags()
                }
            } else {
                // Create new tag (always lowercase)
                let newTag = Tag(blog: blog, name: trimmed)
                modelContext.insert(newTag)
                blog.tags.append(newTag)
                selectedTags.append(newTag)
                // Apply change immediately
                updatePostTags()
            }
            tagInput = ""
            showingSuggestions = false
        }
    }
    
    private func updatePostTags() {
        // Remove all existing tag relationships
        for tag in post.tags {
            if let index = tag.posts.firstIndex(where: { $0.id == post.id }) {
                tag.posts.remove(at: index)
            }
        }
        
        // Clear post's tags array
        post.tags.removeAll()
        
        // Add all selected tags
        for tag in selectedTags {
            post.tags.append(tag)
            tag.posts.append(post)
        }
        
        try? modelContext.save()
    }
}

#Preview {
    let modelContainer = PreviewData.previewContainer
    let blog = try! modelContainer.mainContext.fetch(FetchDescriptor<Blog>()).first!
    let post = Post(content: "Test content", isDraft: true)
    post.blog = blog
    
    return TagSelectionView(blog: blog, post: post)
        .modelContainer(modelContainer)
}
