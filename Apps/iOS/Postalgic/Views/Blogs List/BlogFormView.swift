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
    @State private var authorName: String
    @State private var authorEmail: String
    @State private var authorUrl: String
    @State private var tagline: String
    
    // Initialize for creating a new blog
    init() {
        self.isEditing = false
        self.blog = nil
        _name = State(initialValue: "")
        _authorName = State(initialValue: "")
        _authorEmail = State(initialValue: "")
        _authorUrl = State(initialValue: "")
        _tagline = State(initialValue: "")
    }
    
    // Initialize for editing an existing blog
    init(blog: Blog) {
        self.isEditing = true
        self.blog = blog
        _name = State(initialValue: blog.name)
        _authorName = State(initialValue: blog.authorName ?? "")
        _authorEmail = State(initialValue: blog.authorEmail ?? "")
        _authorUrl = State(initialValue: blog.authorUrl ?? "")
        _tagline = State(initialValue: blog.tagline ?? "")
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Blog Title and Tagline") {
                    TextField("Title", text: $name)
                    TextField("Tagline (optional)", text: $tagline)
                }

                Section {
                    TextField("Author Name (optional)", text: $authorName)
                    TextField("Author Email (optional)", text: $authorEmail)
                        .autocapitalization(.none)
                        .autocorrectionDisabled(true)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                    TextField("Author URL (optional)", text: $authorUrl)
                        .autocapitalization(.none)
                        .autocorrectionDisabled(true)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                } header: {
                    Text("Author Information")
                } footer: {
                    Text("If provided, author information will be added to posts and included in the RSS feed.")
                }
            }
            .navigationTitle(isEditing ? "Metadata" : "New Blog")
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
                    .disabled(name.isEmpty)
                }
            }
        }
    }
    
    private func addBlog() {
        let newBlog = Blog(
            name: name, 
            url: "",
            authorName: authorName.isEmpty ? nil : authorName,
            authorEmail: authorEmail.isEmpty ? nil : authorEmail,
            authorUrl: authorUrl.isEmpty ? nil : authorUrl,
            tagline: tagline.isEmpty ? nil : tagline
        )
        modelContext.insert(newBlog)
        try? modelContext.save()
    }
    
    private func updateBlog() {
        if let blogToUpdate = blog {
            blogToUpdate.name = name
            blogToUpdate.authorName = authorName.isEmpty ? nil : authorName
            blogToUpdate.authorEmail = authorEmail.isEmpty ? nil : authorEmail
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
