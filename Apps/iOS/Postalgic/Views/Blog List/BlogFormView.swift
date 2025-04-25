//
//  BlogFormView.swift
//  Postalgic
//
//  Created by Brad Root on 4/19/25.
//

import SwiftData
import SwiftUI
struct BlogFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // Determines if we're creating a new blog or editing an existing one
    private var isEditing: Bool
    
    // Optional blog for editing mode
    private var blog: Blog?
    
    @State private var name: String
    @State private var url: String
    @State private var authorName: String
    @State private var authorUrl: String
    @State private var tagline: String
    
    // Initialize for creating a new blog
    init() {
        self.isEditing = false
        self.blog = nil
        _name = State(initialValue: "")
        _url = State(initialValue: "")
        _authorName = State(initialValue: "")
        _authorUrl = State(initialValue: "")
        _tagline = State(initialValue: "")
    }
    
    // Initialize for editing an existing blog
    init(blog: Blog) {
        self.isEditing = true
        self.blog = blog
        _name = State(initialValue: blog.name)
        _url = State(initialValue: blog.url)
        _authorName = State(initialValue: blog.authorName ?? "")
        _authorUrl = State(initialValue: blog.authorUrl ?? "")
        _tagline = State(initialValue: blog.tagline ?? "")
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Blog Info") {
                    TextField("Name", text: $name)
                    TextField("Tagline (optional)", text: $tagline)
                }
                
                Section("Blog URL") {
                    TextField("URL", text: $url)
                        .autocapitalization(.none)
                        .autocorrectionDisabled(true)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                }

                Section {
                    TextField("Author Name (optional)", text: $authorName)
                    TextField("Author URL (optional)", text: $authorUrl)
                        .autocapitalization(.none)
                        .autocorrectionDisabled(true)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                } header: {
                    Text("Author Information")
                } footer: {
                    Text("If provided, this name (with a link to the URL) will be added as a byline to every post. You can provide a URL to a website, or a `mailto:` prefix with your email address to allow others to contact you.")
                }
            }
            .navigationTitle(isEditing ? "Edit Blog" : "New Blog")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if isEditing {
                            updateBlog()
                        } else {
                            addBlog()
                        }
                        dismiss()
                    }
                    .disabled(name.isEmpty || url.isEmpty)
                }
            }
        }
    }
    
    private func addBlog() {
        let newBlog = Blog(
            name: name, 
            url: url, 
            authorName: authorName.isEmpty ? nil : authorName,
            authorUrl: authorUrl.isEmpty ? nil : authorUrl,
            tagline: tagline.isEmpty ? nil : tagline
        )
        modelContext.insert(newBlog)
    }
    
    private func updateBlog() {
        if let blogToUpdate = blog {
            blogToUpdate.name = name
            blogToUpdate.url = url
            blogToUpdate.authorName = authorName.isEmpty ? nil : authorName
            blogToUpdate.authorUrl = authorUrl.isEmpty ? nil : authorUrl
            blogToUpdate.tagline = tagline.isEmpty ? nil : tagline
        }
    }
}

#Preview("New Blog") {
    BlogFormView()
        .modelContainer(PreviewData.previewContainer)
}

#Preview("Edit Blog") {
    BlogFormView(blog: PreviewData.blogWithContent())
        .modelContainer(PreviewData.previewContainer)
}
