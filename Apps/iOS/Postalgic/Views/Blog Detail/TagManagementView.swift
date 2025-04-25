//
//  TagManagementView.swift
//  Postalgic
//
//  Created by Brad Root on 4/25/25.
//

import SwiftData
import SwiftUI

struct TagManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    var blog: Blog
    
    @Query private var allTags: [Tag]
    
    private var tags: [Tag] {
        return allTags.filter { $0.blog?.id == blog.id }
    }
    
    @State private var showingAddTag = false
    @State private var selectedTag: Tag?
    @State private var isEditing = false
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(tags.sorted { $0.name < $1.name }) { tag in
                    TagRowView(tag: tag)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedTag = tag
                            isEditing = true
                        }
                }
                .onDelete(perform: deleteTags)
            }
            .navigationTitle("Tags")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddTag = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingAddTag) {
                TagFormView(mode: .add, blog: blog).interactiveDismissDisabled()
            }
            .sheet(
                isPresented: $isEditing,
                onDismiss: {
                    selectedTag = nil
                }
            ) {
                if let tag = selectedTag {
                    TagFormView(mode: .edit(tag), blog: blog).interactiveDismissDisabled()
                }
            }
        }
    }
    
    private func deleteTags(at offsets: IndexSet) {
        let sortedTags = tags.sorted { $0.name < $1.name }
        for index in offsets {
            let tagToDelete = sortedTags[index]
            
            // Remove this tag from any posts that use it
            for post in tagToDelete.posts {
                post.tags.removeAll { $0.id == tagToDelete.id }
            }
            
            modelContext.delete(tagToDelete)
        }
    }
}

struct TagRowView: View {
    let tag: Tag
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(tag.name)
                .font(.headline)
            
            Text(
                "\(tag.posts.count) \(tag.posts.count == 1 ? "post" : "posts")"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct TagFormView: View {
    enum Mode {
        case add
        case edit(Tag)
    }
    
    let mode: Mode
    let blog: Blog
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    
    var title: String {
        switch mode {
        case .add:
            return "Add Tag"
        case .edit:
            return "Edit Tag"
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveTag()
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .onAppear {
                if case .edit(let tag) = mode {
                    name = tag.name
                }
            }
        }
    }
    
    private func saveTag() {
        switch mode {
        case .add:
            let newTag = Tag(name: name)
            modelContext.insert(newTag)
            newTag.blog = blog
            blog.tags.append(newTag)
            
        case .edit(let tag):
            tag.name = name.lowercased()
            
            // Ensure tag is associated with blog
            if tag.blog == nil {
                tag.blog = blog
                blog.tags.append(tag)
            }
        }
    }
}

#Preview {
    let modelContainer = PreviewData.previewContainer
    
    return NavigationStack {
        // Fetch the first blog from the container to ensure it's properly in the context
        TagManagementView(blog: try! modelContainer.mainContext.fetch(FetchDescriptor<Blog>()).first!)
    }
    .modelContainer(modelContainer)
}