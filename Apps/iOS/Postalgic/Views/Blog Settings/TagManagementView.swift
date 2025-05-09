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
    
    @Query(sort: \Tag.name) private var tags: [Tag]
    
    @State private var showingAddTag = false
    
    init(blog: Blog) {
        self.blog = blog
        
        // Configure the query to fetch all tags for this blog (without sorting)
        let id = blog.persistentModelID
        let catPredicate = #Predicate<Tag> { tag in
            tag.blog?.persistentModelID == id
        }
        
        // Use a simple query without specific sorting
        self._tags = Query(filter: catPredicate)
    }
    
    var body: some View {
        NavigationStack {
            List {
                if tags.isEmpty {
                    Text("No tags yet. Add some to help organize your blog's content.")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical)
                } else {
                    ForEach(tags.sorted { $0.name < $1.name }) { tag in
                        NavigationLink(destination: EditTagView(tag: tag, blog: blog)) {
                            TagRowView(tag: tag)
                        }
                    }
                    .onDelete(perform: deleteTags)
                }
            }
            .navigationTitle("Tags")
            .toolbar {
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
                AddTagView(blog: blog).interactiveDismissDisabled()
            }
        }
    }
    
    private func deleteTags(at offsets: IndexSet) {
        let sortedTags = tags.sorted { $0.name < $1.name }
        for index in offsets {
            let tagToDelete = sortedTags[index]
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

struct AddTagView: View {
    let blog: Blog
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                }
            }
            .navigationTitle("Add Tag")
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
        }
    }
    
    private func saveTag() {
        let newTag = Tag(blog: blog, name: name)
        modelContext.insert(newTag)
        blog.tags.append(newTag)
    }
}

struct EditTagView: View {
    let blog: Blog
    @Bindable var tag: Tag
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentationMode) private var presentationMode
    
    @State private var name: String
    @State private var hasChanges = false
    
    init(tag: Tag, blog: Blog) {
        self.tag = tag
        self.blog = blog
        _name = State(initialValue: tag.name)
    }
    
    var body: some View {
        Form {
            Section {
                TextField("Name", text: $name)
                    .onChange(of: name) { _, _ in
                        checkForChanges()
                    }
            }
        }
        .navigationTitle("Edit Tag")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    saveTag()
                    dismiss()
                }
                .disabled(name.isEmpty || !hasChanges)
            }
        }
        .interactiveDismissDisabled(hasChanges)
        .onChange(of: presentationMode.wrappedValue.isPresented) { wasPresented, isPresented in
            if wasPresented && !isPresented && hasChanges {
                // The view is being dismissed, but we have unsaved changes
                // This is handled by interactiveDismissDisabled now
            }
        }
    }
    
    private func checkForChanges() {
        hasChanges = name != tag.name
    }
    
    private func saveTag() {
        tag.name = name.lowercased()
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
